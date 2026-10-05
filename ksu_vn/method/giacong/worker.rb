require "json"
require "digest"
module KSU
  module Cnc
    module Worker
      TEXT_KEYS = %w[nesting_id sheet_id board_id part_id nesting_name sheet_name board_name part_name layer_name
                     root_sheet_name root_sheet_id latch_side latch_row]
                  .map { |key| [key.freeze, key.to_sym, :"#{key}="] }.freeze
      Color = Struct.new(:red, :green, :blue)
      class Named
        attr_reader :name
        def initialize(name)
          @name = name.to_s
        end
      end
      class Dictionary
        attr_reader :name
        def initialize(name, h7)
          @name = name.to_s
          @h7 = h7
        end
        def each_pair(&blk)
          @h7.each_pair(&blk)
        end
      end
      class Entity
        attr_reader :entityID, :persistent_id, :name, :layer, :definition, :attribute_dictionaries
        def initialize(arr)
          @entityID = arr["id"].to_i
          @persistent_id = arr["pid"].to_i
          @name = arr["name"].to_s
          @layer = arr.key?("layer") ? Named.new(arr["layer"]) : nil
          @definition = arr.key?("definition") ? Named.new(arr["definition"]) : nil
          arr45 = (arr["attrs"] || {}).map { |_28ffb46e, h7| Dictionary.new(_28ffb46e, h7) }
          @attribute_dictionaries = arr45.empty? ? nil : arr45
        end
      end
      class Layer
        attr_reader :name, :color
        def initialize(name, color)
          @name = name.to_s
          text = color.to_s
          @color = Color.new(text[1, 2].to_i(16), text[3, 2].to_i(16), text[5, 2].to_i(16))
        end
      end
      class Layers
        def initialize(colors)
          @items = colors.to_h { |name, color| [name.to_s, Layer.new(name, color)] }
        end
        def [](name)
          key = name.to_s
          @items[key] || @items[{ "Layer0" => "Untagged", "Untagged" => "Layer0" }[key]]
        end
      end
      class Model
        attr_reader :path, :title, :layers
        def initialize(arr)
          @path = arr["path"].to_s
          @title = arr["title"].to_s
          @layers = Layers.new(arr["layers"] || {})
        end
      end
      module Tools
        def config
          Worker.config
        end
      end
      @clib_paths = nil
      @code_stamp = nil
      module_function
      def clib_file(name)
        File.join(ROOT_DIR, "clibs", (RUBY_VERSION >= "3.0" ? "3.2" : "2.7"), name)
      end
      def work_dir
        File.join(ENV["TEMP"] || ENV["TMP"] || Dir.pwd, "ksu_worker")
      end
      def clib_paths
        return @clib_paths if @clib_paths
        entries = %w[ksu nc].map { |name| ::KSU.clib_path(name) if ::KSU.respond_to?(:clib_path) }
        return @clib_paths = entries if entries.all? { |path| path && File.file?(path) }
        @clib_paths = %w[ksu.so nc.so].filter_map { |name| $LOADED_FEATURES.find { |path| File.basename(path) == name } }
      end
      def code_stamp
        @code_stamp ||= stamp_of(clib_paths)
      end
      def stamp_of(clib_paths)
        _ec0da59d = ::Digest::SHA256.new
        (source_paths + clib_paths).each { |path| _ec0da59d << File.basename(path) << "|" << File.binread(path) << "|" }
        _ec0da59d.hexdigest
      end
      def source_list
        entries = %w[worker text calc core topology clip arc library planner export chain profile rescue motion gcode canvas pool]
        entries.map { |name| "method/giacong/#{name}" } << "method/giacong"
      end
      def source_paths
        source_list.filter_map do |_542d0b2a|
          %w[.rb .rbx].map { |entity| File.join(ROOT_DIR, _542d0b2a + entity) }.find { |path| File.file?(path) }
        end
      end
      def loader_path
        $LOADED_FEATURES.find do |path|
          File.basename(path) == "loader.so" && File.basename(File.dirname(path)).start_with?("ksu_loader_")
        end || [clib_file("loader.so")].find { |path| File.file?(path) }
      end
      def worker_source(load_root, loader_so, clib_paths)
        lines = ["$LOAD_PATH.unshift(#{load_root.inspect})", "module Sketchup", "  def self.require(path)",
                    "    Kernel.require(path)", "  end", "end"]
        lines << "require #{loader_so.inspect}" if loader_so
        clib_paths.each { |path| lines << "require #{path.inspect}" }
        source_list.each { |_542d0b2a| lines << "Sketchup.require #{"ksu_vn/#{_542d0b2a}".inspect}" }
        lines.push("KSU::Cnc::Worker.serve(#{clib_paths.inspect})", '').join("\n")
      end
      def write_worker(dir, clib_paths = Worker.clib_paths, loader_so = loader_path, load_root = File.dirname(ROOT_DIR))
        boundary = worker_source(load_root, loader_so, clib_paths)
        path = File.join(dir, "giacong_worker_#{::Digest::SHA256.hexdigest(boundary)[0, 12]}.rb")
        File.binwrite(path, boundary) unless File.file?(path) && File.binread(path) == boundary
        path
      end
      def meta
        arr = ::KSU::Settings.load
        { "settings" => { "gia_cong" => arr["gia_cong"] || {}, "chong_bay" => arr["chong_bay"] || {} }, "tools" => Library.config_copy }
      end
      def dump_database(arr, model)
        container = {}
        keys = {}.compare_by_identity
        vectors = arr[:vectors].map { |vec| dump_record(vec, container, keys) }
        { "vectors" => vectors, "entities" => container, "model" => dump_layers(model) }
      end
      def dump_layers(model)
        h5 = model.layers.to_h do |grp|
          color = grp.color
          [text(grp.name), format("#%02x%02x%02x", color.red, color.green, color.blue)]
        end
        { "path" => text(safe_send(model, :path)), "title" => text(safe_send(model, :title)), "layers" => h5 }
      end
      def dump_record(bb, container, keys)
        h = {}
        TEXT_KEYS.each do |key, _ee07a6d0|
          val = bb.public_send(_ee07a6d0)
          h[key] = text(val) unless val.nil?
        end
        h["vector_type"] = bb.vector_type.to_s
        h["operation_type"] = bb.operation_type.to_s
        h["work_face"] = bb.work_face.to_s
        h["closed"] = bb.closed ? true : false
        h["points"] = bb.points.map { |pt| [pt.x.to_f, pt.y.to_f, pt.z.to_f] }
        center = bb.center
        h["center"] = [center.x.to_f, center.y.to_f, center.z.to_f] if center
        h["radius"] = number(bb.radius) unless bb.radius.nil?
        h["diameter_mm"] = number(bb.diameter_mm) unless bb.diameter_mm.nil?
        h["latch_seq"] = bb.latch_seq unless bb.latch_seq.nil?
        h["source_path"] = bb.source_path.map { |fld| text(fld) }
        h["src_path_ids"] = bb.src_path_ids.map { |fld| text(fld) }
        h["sheet_entity"] = entity_ref(bb.sheet_entity, container, keys) if bb.sheet_entity
        h["board_entity"] = entity_ref(bb.board_entity, container, keys) if bb.board_entity
        h["part_entity"] = entity_ref(bb.part_entity, container, keys) if bb.part_entity
        h
      end
      def entity_ref(entity, container, keys)
        keys[entity] ||= entity.entityID.to_s.tap { |key| container[key] ||= dump_entity(entity) }
      end
      def dump_entity(entity)
        arr = { "id" => entity.entityID, "pid" => safe_send(entity, :persistent_id), "name" => text(safe_send(entity, :name)) }
        arr["pid"] = entity.entityID unless arr["pid"].is_a?(Integer)
        grp2 = safe_send(entity, :layer)
        arr["layer"] = text(grp2.name) if grp2
        grp = safe_send(entity, :definition)
        arr["definition"] = text(grp.name) if grp
        arr2 = safe_send(entity, :attribute_dictionaries).to_a.to_h do |h|
          h7 = {}
          h.each_pair { |key, val| h7[text(key)] = read_string(val) }
          [text(h.name), h7]
        end
        arr["attrs"] = arr2 unless arr2.empty?
        arr
      end
      def safe_send(entity, method_name)
        entity.respond_to?(method_name) ? entity.public_send(method_name) : nil
      rescue StandardError
        nil
      end
      def read_string(arr)
        case arr
        when Hash then arr.each_with_object({}) { |(key, fld), out| out[text(key)] = read_string(fld) }
        when Array then arr.map { |fld| read_string(fld) }
        when nil, true, false, Integer then arr
        when Float then arr.finite? ? arr : arr.to_s
        else text(arr)
        end
      end
      def number(num)
        num.is_a?(Integer) ? num : num.to_f
      end
      def text(str2)
        str = str2.to_s
        str = str.dup.force_encoding("UTF-8") unless str.encoding == ::Encoding::UTF_8
        str.valid_encoding? ? str : str.scrub("?")
      end
      def outside_sketchup?
        !(defined?(::Sketchup) && ::Sketchup.respond_to?(:active_model))
      end
      def stub_sketchup
        flag = defined?(::Sketchup) ? ::Sketchup : Object.const_set(:Sketchup, Module.new)
        flag.const_set(:AppObserver, Class.new) unless flag.const_defined?(:AppObserver, false)
        flag.define_singleton_method(:active_model) { Worker.model }
        flag2 = defined?(::Geom) ? ::Geom : Object.const_set(:Geom, Module.new)
        flag2.const_set(:Point3d, point3d_class) unless flag2.const_defined?(:Point3d, false)
        gi = defined?(::UI) ? ::UI : Object.const_set(:UI, Module.new)
        gi.define_singleton_method(:messagebox) { |*_15940371| 1 } unless gi.respond_to?(:messagebox)
        ::KSU.const_set(:Settings, settings_module) unless ::KSU.const_defined?(:Settings, false)
      end
      def model
        @model
      end
      def settings
        @settings || "{}"
      end
      def config
        @config || {}
      end
      def point3d_class
        Class.new do
          attr_accessor :x, :y, :z
          def initialize(x = 0.0, y = 0.0, z = 0.0)
            @x = x.to_f
            @y = y.to_f
            @z = z.to_f
          end
          def to_a
            [@x, @y, @z]
          end
          def [](idx)
            to_a[idx]
          end
          def hash
            [@x, @y, @z].hash
          end
          def eql?(panel)
            panel.is_a?(self.class) && @x == panel.x && @y == panel.y && @z == panel.z
          end
          def distance(panel)
            dx = @x - panel.x
            dy = @y - panel.y
            dz = @z - panel.z
            Math.sqrt(dx * dx + dy * dy + dz * dz)
          end
          def ==(panel)
            panel.respond_to?(:x) && @x == panel.x && @y == panel.y && @z == panel.z
          end
          def inspect
            format("Point3d(%.6f, %.6f, %.6f)", @x, @y, @z)
          end
          alias to_s inspect
        end
      end
      def settings_module
        Module.new do
          const_set(:SETTINGS_DIR, Worker.work_dir)
          def self.load
            JSON.parse(Worker.settings)
          end
          def self.coerce(num, default)
            return num if default.nil?
            case default
            when String then num.is_a?(Array) ? num.join(",") : num.to_s
            when Integer then num.to_i
            when Float then num.to_f
            else num
            end
          rescue StandardError
            default
          end
          def self.get_raw(key, default = nil, sec2 = nil)
            key3 = sec2.nil? ? load : load[sec2]
            key3&.key?(key) ? coerce(key3[key], default) : default
          end
        end
      end
      def serve(clib_paths)
        @clib_paths = clib_paths
        @code_stamp = nil
        $stdin.binmode
        $stdout.binmode.sync = true
        Library.singleton_class.prepend(Tools)
        $stdout.write(JSON.generate(hello_message(clib_paths)) + "\n")
        while (axis = $stdin.gets)
          error = axis.strip
          $stdout.write(handle_job(error) + "\n") unless error.empty?
        end
      end
      def hello_message(clib_paths)
        { "hello" => stamp_of(clib_paths), "ruby" => RUBY_VERSION, "platform" => RUBY_PLATFORM, "native" => Calc::NATIVE, "pid" => Process.pid }
      end
      def handle_job(axis)
        job = JSON.parse(axis.force_encoding("UTF-8"))
        if (arr = job["context"])
          @settings = JSON.generate(arr["settings"] || {})
          @config = arr["tools"] || {}
          Latch.reset
        end
        ok = to_segments(job)
        slot = Canvas.slots[job["sheet_id"].to_s]
        cache = Store.to_json_row(slot) unless slot.nil? || Canvas.no_toolpath?(slot)
        JSON.generate("id" => job["id"], "row" => job["cache_only"] ? nil : ok, "cache" => cache)
      rescue StandardError => err
        JSON.generate("id" => job ? job["id"] : nil, "error" => "#{err.class}: #{err.message}")
      end
      def to_segments(job)
        db, @model = load_database(job["sheet"])
        Canvas.reset2
        arr2 = Canvas.sheet_rows(db).first
        if arr2 && job.key?("sheet_id")
          arr2[:path_key] = job["sheet_id"].to_s
          arr2[:name] = job["name"].to_s if job.key?("name")
          arr2[:nesting_name] = job["nesting_name"].to_s if job.key?("nesting_name")
        end
        ok = Canvas.to_segments(db, @model, only_index: 0, with_toolpaths: true, moves: job["moves"] != false)
        arr = ok[:ok] && ok[:sheets].first
        arr[:id] = job["sheet_id"].to_s if arr && job.key?("sheet_id")
        arr[:index] = job["index"].to_i if arr && job.key?("index")
        ok
      end
      def load_database(data)
        eb_spec = (data["entities"] || {}).transform_values { |row| Entity.new(row) }
        bb = Database.new
        Array(data["vectors"]).each { |row| bb.add(load_record(row, eb_spec)) }
        [bb, Model.new(data["model"] || {})]
      end
      def load_record(h, eb_spec)
        rec = Record.new
        TEXT_KEYS.each { |key, _77a49615, _d5362565| rec.public_send(_d5362565, h[key]) if h.key?(key) }
        rec.vector_type = h["vector_type"].to_sym
        rec.operation_type = h["operation_type"].to_sym
        rec.work_face = h["work_face"].to_sym
        rec.closed = h["closed"] ? true : false
        rec.points = h["points"].map { |pt| ::Geom::Point3d.new(*pt) }
        rec.center = ::Geom::Point3d.new(*h["center"]) if h["center"]
        rec.radius = h["radius"] if h.key?("radius")
        rec.diameter_mm = h["diameter_mm"] if h.key?("diameter_mm")
        rec.latch_seq = h["latch_seq"] if h.key?("latch_seq")
        rec.source_path = Array(h["source_path"])
        rec.src_path_ids = Array(h["src_path_ids"])
        rec.sheet_entity = eb_spec[h["sheet_entity"]] if h["sheet_entity"]
        rec.board_entity = eb_spec[h["board_entity"]] if h["board_entity"]
        rec.part_entity = eb_spec[h["part_entity"]] if h["part_entity"]
        rec
      end
      begin
        code_stamp unless outside_sketchup?
      rescue StandardError
        @code_stamp = nil
      end
      stub_sketchup if outside_sketchup?
    end
  end
end
