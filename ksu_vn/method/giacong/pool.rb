%w[json digest fileutils].each { |name| require name }
%w[etc rbconfig].each do |name|
  require name
rescue LoadError
end
module KSU
  module Cnc
    module Store
      @stamp = nil
      module_function
      def get(key)
        path = entry_path(key)
        return nil unless File.file?(path)
        data = JSON.parse(File.read(path, mode: "rb:UTF-8"))
        return nil unless valid_entry?(data, key)
        Pool.swallow { File.utime(nil, nil, path) }
        from_json_row(data)
      rescue StandardError
      end
      def set(key, slot)
        FileUtils.mkdir_p(dir)
        path = entry_path(key)
        grp = "#{path}.#{Process.pid}.part"
        File.binwrite(grp, JSON.generate(to_json_row(slot)))
        File.rename(grp, path)
        @num8 = @num8.to_i + 1
        sweep if @num8 % 100 == 1
      rescue StandardError
        FileUtils.rm_f(grp) if grp
      end
      def valid_entry?(data, key)
        row = data.is_a?(Hash) && data["key"] == key && data["row"]
        return false unless row.is_a?(Hash) && row["warnings"].is_a?(Array) && row["source"].is_a?(Array)
        data["paths"].nil? || data["paths"].is_a?(Array)
      end
      def to_json_row(slot)
        tools, idx, arr = [], {}, {}.compare_by_identity
        paths = slot[:paths]&.map do |path|
          tool = path[:tool]
          path.merge(tool: arr[tool] ||= idx[JSON.generate(tool)] ||= (tools << tool).length - 1)
        end
        { "key" => slot[:key], "names" => slot[:names], "row" => slot[:row], "tools" => tools, "paths" => paths,
          "ops" => slot[:ops], "base" => slot[:base] }
      end
      def from_json_row(data)
        arr = data["row"].transform_keys(&:to_sym)
        arr[:source] = arr[:source].map { |fld| fld.transform_keys(&:to_sym) }
        arr[:toolpaths] = []
        tools = data["tools"]
        paths = data["paths"]&.map { |fld| fld.transform_keys(&:to_sym).merge!(tool: tools.fetch(fld["tool"])) }
        { key: data["key"], names: data["names"], row: arr, paths: paths, ops: data["ops"], base: data["base"] }
      end
      def reset_stamp
        @stamp = nil
      end
      def dir
        File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"] || ENV["TEMP"] || Dir.pwd, "KSU", "giacong_cache")
      end
      def sweep
        per_row = Time.now - 600
        Dir.glob(File.join(dir, "*.part")).each { |path| Pool.swallow { File.delete(path) if File.mtime(path) < per_row } }
        rows = Dir.glob(File.join(dir, "*.json")).filter_map do |path|
          [path, File.stat(path)]
        rescue StandardError
        end
        total = rows.inject(0) { |acc2, arr| acc2 + arr[1].size }
        return if total <= (200 * 1024 * 1024)
        rows.sort_by { |arr| arr[1].mtime }.each do |path, stat|
          break if total <= (200 * 1024 * 1024)
          File.delete(path)
          total -= stat.size
        rescue StandardError
        end
      end
      def stamp
        @stamp ||= ::Digest::SHA256.hexdigest("#{RUBY_VERSION}|#{Worker.code_stamp}")
      end
      def entry_path(key)
        File.join(dir, ::Digest::SHA256.hexdigest("#{stamp}|#{key}") + ".json")
      end
    end
    module Pool
      JOB_TIMEOUT_S = 30.0
      BOOT_TIMEOUT_S = 20.0
      module_function
      def workers
        @workers ||= []
      end
      def queue
        @queue ||= []
      end
      def failed
        @failed ||= {}
      end
      def retries
        @retries ||= {}
      end
      def parallel?
        !@flag2 && Util.bool_or(Dialog.settings["tien_trinh_song_song"], true) && spare_cpus >= 2
      end
      def usable?
        !@flag2 && workers.any?
      end
      def labelling
        workers.any? { |w| !w[:ready] } || !queue.empty? || running_count.positive? || !@run_state.nil?
      end
      def start_workers(arr2, lo = 8)
        return false unless arr2.length >= lo && parallel? && Util.bool_or(Dialog.settings["hien_duong_dao"], true)
        db = Dialog.active_database
        meta = db && child_meta(true)
        return false unless meta
        sheets = Canvas.sheet_rows(db)
        idx = Canvas.sheet_index(db)
        arr = arr2.filter_map do |id|
          key = id.to_s
          index = idx[key]
          next if index.nil? || failed[key] || queue_index(key) || running?(key)
          next if !needs_run?(sheets[index], meta) || !retry_or_fail(key)
          { id: key, index: index, sheet: sheets[index] }
        end
        return false if arr.length < lo && workers.empty?
        queue.concat(arr)
        touch
        on_fail = worker_script
        while workers.length < rsz(queue.length + running_count) && (w = spawn_worker(on_fail))
          workers << w
        end
        start_timer if workers.any?
        usable?
      rescue StandardError => err
        disable_parallel("#{err.class}: #{err.message}")
        false
      end
      def drop_jobs(arr)
        queue.reject! { |job| arr.include?(job[:id]) }
      end
      def enqueue(keys, moves, handle_job, dlg2)
        entries = keys.uniq
        arr = plan(entries, true) || []
        return Dialog.run_many(keys, moves, arr) if arr.empty? || arr.length != entries.length
        @run_state = { keys: keys, moves: moves, reply: handle_job, dialog: dlg2, since: Util.now }
        start_timer
        nil
      rescue StandardError => err
        disable_parallel("#{err.class}: #{err.message}")
        Dialog.run_many(keys, moves)
      end
      def tick
        return if @flag37
        @flag37 = true
        at = Util.now
        workers.each { |w| read_worker(w, at) }
        return disable_parallel(@one_group) if @one_group
        reap_dead
        dispatch
        flush_batch
        last_ix if at - @num2.to_f > 30.0 && !labelling
      rescue StandardError => err
        disable_parallel("#{err.class}: #{err.message}")
      ensure
        @flag37 = false
      end
      def last_ix
        workers.each { |w| close_worker(w) }
        [workers, queue, failed, retries].each(&:clear)
        @run_state = @one_group = @meta = nil
        @num6 = 0
        swallow do
          Dir.glob(File.join(worker_dir, "giacong_worker_*.log")).each { |path| swallow { File.delete(path) if File.zero?(path) } }
        end
        ::UI.stop_timer(@timer_id) if @timer_id
        @timer_id = nil
      end
      def cpu_count
        @cpu_count ||= defined?(::Etc) ? ::Etc.nprocessors : ENV["NUMBER_OF_PROCESSORS"].to_i
      rescue StandardError
        @cpu_count = ENV["NUMBER_OF_PROCESSORS"].to_i
      end
      def worker_cap
        8
      end
      def spare_cpus
        [cpu_count / 2 - 1, 0].max
      end
      def rsz(want)
        [spare_cpus, worker_cap, want].min
      end
      def plan(entries, flag = false)
        return nil unless usable?
        unless workers.any? { |w| w[:ready] }
          queue.reject! { |job| entries.include?(job[:id]) }
          return []
        end
        db = Dialog.active_database
        meta = db && child_meta(flag)
        return nil unless meta
        sheets = Canvas.sheet_rows(db)
        idx = Canvas.sheet_index(db)
        arr = []
        entries.reverse_each do |key|
          index = idx[key]
          next if index.nil? || failed[key]
          _6441cd49 = queue_index(key)
          queue.unshift(queue.delete_at(_6441cd49)) if _6441cd49
          unless _6441cd49 || running?(key)
            next if !needs_run?(sheets[index], meta) || !retry_or_fail(key)
            queue.unshift({ id: key, index: index, sheet: sheets[index] })
          end
          arr.unshift(key)
        end
        touch unless arr.empty?
        arr
      end
      def child_meta(flag2 = false)
        at = Util.now
        return @meta[:canvas] if !flag2 && @meta && at - @meta[:at] < 0.5
        model = Canvas.build_meta(::Sketchup.active_model, Export.cnc_settings)
        _c85b78dd = Worker.meta
        resp = JSON.generate(_c85b78dd)
        flag = @meta ? @meta[:gen] : 0
        flag += 1 unless @meta && @meta[:json] == resp
        @meta = { canvas: model, payload: _c85b78dd, json: resp, gen: flag, at: at }
        model
      rescue Export::UnsafeCutError
      end
      def cached_meta
        @meta ? @meta[:canvas] : child_meta(true)
      end
      def needs_run?(sheet, meta)
        !already_done?(sheet, meta) && !Canvas.slot_ready?(sheet, meta)
      rescue StandardError
        false
      end
      def already_done?(arr, meta)
        key = Canvas.slot_key(arr, meta)
        slot = Canvas.slots[arr[:path_key].to_s]
        Canvas.slot_fresh?(slot, key, Canvas.tool_names(arr, meta)) || File.file?(Store.entry_path(key))
      end
      def queue_index(key)
        queue.index { |job| job[:id] == key }
      end
      def running?(key)
        workers.any? { |w| w[:jobs].any? { |job| job[:id] == key } }
      end
      def running_count
        workers.inject(0) { |acc2, w| acc2 + w[:jobs].length }
      end
      def retry_or_fail(key)
        return true if retries[key].to_i < 3
        failed[key] = true
        false
      end
      def spawn_worker(on_fail)
        exe_path, exe_args = worker_command(on_fail)
        return disable_parallel("không tìm thấy host.exe hoặc DLL Ruby của SketchUp") unless exe_path
        _45db677b, _aec9a3e4 = IO.pipe(binmode: true)
        _6fa57ca9, _44edb09b = IO.pipe(binmode: true)
        @num10 = @num10.to_i + 1
        str = File.join(worker_dir, "giacong_worker_#{Process.pid}_#{@num10}.log")
        pid = Process.spawn(exe_args, *exe_path, in: _45db677b, out: _44edb09b, err: [str, "w"])
        [_45db677b, _44edb09b].each(&:close)
        { pid: pid, in: _aec9a3e4, out: _6fa57ca9, buf: String.new, jobs: [], ready: false, since: Util.now }
      rescue StandardError => arr
        [_45db677b, _aec9a3e4, _6fa57ca9, _44edb09b].compact.each { |_54b2ba86| swallow { _54b2ba86.close } }
        disable_parallel("#{arr.class}: #{arr.message}")
      end
      def worker_command(on_fail)
        dll_name = ruby_dll
        if dll_name && (host = host_exe)
          dir = File.dirname(dll_name)
          str = File.join(dir, "Tools", "RubyStdLib")
          return [[host, dir, dll_name, on_fail], { "RUBYLIB" => "#{File.join(str, "platform_specific")};#{str}", "RUBYOPT" => nil }]
        end
        str2 = defined?(::RbConfig) ? ::RbConfig.ruby.to_s : ""
        File.file?(str2) ? [[str2, on_fail], { "RUBYOPT" => nil }] : nil
      end
      def ruby_dll
        name = ::RbConfig::CONFIG["LIBRUBY_SO"].to_s if defined?(::RbConfig)
        return nil if name.to_s.empty?
        str = [File.dirname(::RbConfig::CONFIG["prefix"].to_s)]
        $LOAD_PATH.each do |fld|
          nesting, str2 = fld.to_s.tr("\\", "/").partition("/Tools/RubyStdLib")
          str << nesting unless str2.empty?
        end
        str.uniq.map { |nesting| File.join(nesting, name) }.find { |path| File.file?(path) }
      end
      def host_exe
        flag = ::KSU.clib_path(:host) if ::KSU.respond_to?(:clib_path)
        [flag, Worker.clib_file("host.exe")].compact.find { |path| File.file?(path) }
      end
      def worker_script
        @worker_script = Worker.write_worker(worker_dir) unless @worker_script && File.file?(@worker_script)
        @worker_script
      end
      def worker_dir
        (::KSU.const_defined?(:CLIB_DIR) ? ::KSU.const_get(:CLIB_DIR) : Worker.work_dir).tap { |dir| FileUtils.mkdir_p(dir) }
      end
      def start_timer
        @timer_id ||= ::UI.start_timer(0, true) { tick }
      end
      def read_worker(w, at)
        while (flag10 = w[:out].read_nonblock(65_536, @flag10 ||= String.new, exception: false)).is_a?(String)
          w[:buf] << flag10
        end
        w[:dead] = true if flag10.nil?
        while (_6441cd49 = w[:buf].index("\n"))
          axis = w[:buf].slice!(0, _6441cd49 + 1).chomp
          handle_message(w, axis) unless axis.empty?
        end
        w[:dead] = true if !w[:ready] && at - w[:since] > BOOT_TIMEOUT_S
        w.merge!(cause: :timeout, dead: true) if w[:jobs].any? { |job| at - job[:sent] > JOB_TIMEOUT_S }
        w[:exited] = w[:dead] = true if !w[:dead] && Process.waitpid(w[:pid], Process::WNOHANG)
      rescue SystemCallError, IOError
        w[:dead] = true
      end
      def handle_message(w, axis)
        data = JSON.parse(axis.force_encoding("UTF-8"))
        unless w[:ready]
          w[:ready] = data["hello"] == Worker.code_stamp
          @one_group = "bản engine của tiến trình con khác bản đang chạy" unless w[:ready]
          return
        end
        job = w[:jobs].shift
        return unless job
        failed[job[:id]] = true unless handle_result(job, data)
        touch
      rescue StandardError
        failed[job[:id]] = true if job
        w.merge!(cause: :garbage, dead: true)
      end
      def handle_result(job, data)
        return false unless data["id"] == job[:id]
        meta = cached_meta
        return false unless meta && Store.valid_entry?(data["cache"], Canvas.slot_key(job[:sheet], meta))
        slot = Store.from_json_row(data["cache"])
        Canvas.slots[job[:id]] = slot unless Canvas.no_toolpath?(slot)
      end
      def reap_dead
        arr = workers.select { |w| w[:dead] }
        return if arr.empty?
        arr.each do |w|
          w[:jobs].each do |job|
            next failed[job[:id]] = true if w[:cause]
            next blk(job) if job[:died]
            job[:died] = true
            queue.unshift(job)
          end
          close_worker(w)
        end
        workers.reject! { |w| w[:dead] }
        touch
        arr.length.times do
          break if @num6.to_i >= 2 || queue.empty? || !(w = spawn_worker(worker_script))
          workers << w
          @num6 = @num6.to_i + 1
        end
        return unless workers.empty?
        queue.each { |job| job[:died] ? blk(job) : (failed[job[:id]] = true) }
        queue.clear
      end
      def blk(job)
        meta = cached_meta
        return failed[job[:id]] = true unless meta
        arr = job[:sheet]
        warnings = [Text.t(:mo_phong, :khong_dung_duong_dao)]
        str = { id: job[:id], name: arr[:name].to_s, source: [], toolpaths: [], blocked: true, warnings: warnings }
        key = Canvas.slot_key(arr, meta)
        Canvas.slots[job[:id]] = { key: key, names: Canvas.tool_names(arr, meta), row: str, paths: nil }
      end
      def close_worker(w)
        w.values_at(:in, :out).each { |_54b2ba86| swallow { _54b2ba86.close } }
        return if w[:exited]
        swallow { Process.kill("KILL", w[:pid]) }
        swallow { Process.detach(w[:pid]) }
      end
      def dispatch
        workers.each do |w|
          next if w[:dead] || !w[:ready] || !w[:jobs].empty?
          break unless (job = queue.shift)
          next unless (text = send_job(w, job))
          w[:in].write(text)
          w[:cgen] = @meta[:gen]
          job[:sent] = Util.now
          retries[job[:id]] = retries[job[:id]].to_i + 1
          w[:jobs] << job
        rescue SystemCallError, IOError
          w.merge!(cause: :pipe, dead: true)
          queue.unshift(job)
        end
      end
      def send_job(w, job)
        arr = job[:sheet]
        _c85b78dd = { "id" => job[:id], "sheet_id" => job[:id], "index" => job[:index], "name" => arr[:name].to_s,
                       "nesting_name" => arr[:nesting_name].to_s, "moves" => false, "cache_only" => true }
        _c85b78dd["context"] = @meta[:payload] if w[:cgen] != @meta[:gen]
        _c85b78dd["sheet"] = Worker.dump_database(arr, ::Sketchup.active_model)
        JSON.generate(_c85b78dd) << "\n"
      rescue StandardError
        failed[job[:id]] = true
        nil
      end
      def flush_batch
        return unless (state = @run_state)
        entries = state[:keys].uniq
        arr = plan(entries) || []
        return if !entries.empty? && arr.length == entries.length && Util.now - state[:since] < 20.0
        @run_state = nil
        run_batch(state, arr)
      end
      def run_batch(state, arr = [])
        ok = begin
            Dialog.run_many(state[:keys], state[:moves], arr)
          rescue StandardError
            { ok: false, message: Text.t(:mo_phong, :khong_dung_duong_dao) }
          end
        Dialog.send_to_page("simBuilt", ok.merge(state[:reply]), state[:dialog])
      end
      def disable_parallel(reason)
        state = @run_state
        last_ix
        @flag2 = true
        axis = "KSU Gia công: tắt tính song song của Mô phỏng trong phiên này: #{reason}"
        puts axis
        swallow { File.open(File.join(worker_dir, "giacong_pool.log"), "a") { |file| file.puts("#{Time.now.strftime("%F %T")} #{axis}") } }
        run_batch(state) if state
        nil
      end
      def swallow
        yield
      rescue StandardError
      end
      def touch
        @num2 = Util.now
      end
      last_ix if defined?(@timer_id) && @timer_id
      @worker_script = nil
    end
  end
end
