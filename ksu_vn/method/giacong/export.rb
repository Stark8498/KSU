require "fileutils"
require "digest"
module KSU
  module Cnc
    module Export
      class UnsafeCutError < StandardError
        attr_accessor :xy
      end
      module_function
      def export_file(db, folder, model = ::Sketchup.active_model, progress: nil, excluded: [])
        progress&.call(stage: "initializing", percent: 4)
        str = File.join(folder, ".ksu_giacong_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{Process.pid}_#{rand(1_000_000)}.tmp")
        FileUtils.mkdir_p(str)
        arr = { progress: progress, model: model, folder: folder, temp_root: str, staged: [], committed: [], backups: {}, spared: [] }
        begin
          prepare_job(db, arr)
          set_aside_excluded(arr, excluded) unless excluded.empty?
          arr[:sheets].each_with_index { |sheet, idx| export_sheet(arr, sheet, idx) }
          ok = commit(arr)
        rescue StandardError => err
          progress&.call(stage: "error", percent: 100)
          flag = [UnsafeCutError, Post::PostFileError, Library::ConfigError].any? { |kind| err.is_a?(kind) }
          { ok: false, message: flag ? Text.t(:xuat, :khong_xuat_vi, ly_do: err.message) : Text.t(:xuat, :khong_xuat_duoc), fatal: true }
        ensure
          rollback(arr) unless ok
          FileUtils.rm_rf(str)
          clear_sheet_map if @arr5 && @arr5[0].equal?(db.sheets)
        end
      end
      def prepare_job(db, arr)
        @arr17 = []
        settings = cnc_settings
        arr2 = Library.config_copy
        tools = arr2["tools"].map { |tool| merge_tool_settings(tool, settings) }
        post = Post.require_post
        sheets = order_sheets(sheet_map(db).values, arr[:model])
        rects = layout_rects(sheets, arr[:model])
        thickness, _53e651f8 = thickness_map(sheets, rects, settings)
        arr.merge!(
          tool_index: tools.to_h { |tool| [tool["id"].to_s, tool] },
          tool_order: tools.each_with_index.to_h { |tool, idx| [tool["id"].to_s, idx] },
          layer_map: arr2["layer_map"],
          layer_order: arr2["layer_order"].each_with_index.to_h { |name, idx| [name.to_s, idx] },
          post: post, extension: post["file_extension"].to_s.then { |text| text.empty? ? "nc" : text },
          thickness: thickness, thickness_issues: _53e651f8, sheets: sheets, total: sheets.length, layout: rects,
          fronts: front_of(sheets, rects),
          group_count: rects.values.uniq { |arr3| arr3[:group_label] }.length,
          prefixes: {}, reserved: {}, skipped_layers: [], blocked_sheets: [], repair_stats: {}, pass_warnings: [], logs: {}
        )
        report(arr, "sheets", 5)
      end
      def export_sheet(arr, arr2, idx)
        arr3 = []
        report(arr, "sheet_begin", 5 + (idx.to_f / arr[:total] * 88.0).floor, idx + 1)
        vectors = arr2[:vectors].reject { |vec| reference?(vec) }
        font = work_face(vectors)
        tag = sheet_label(arr, arr2, font)
        safe_filename, prefix, _d854c351 = output_names(arr, arr2, font)
        str = File.join(arr[:folder], safe_filename)
        box2 = Frame.to_segments(vectors, back_face: font == :back)
        anchor = box2&.dig(:origin)
        return block_sheet(arr, tag, Text.t(:van, :khong_goc)) unless anchor
        begin
          Frame.assert_in_sheet(vectors, box2)
        rescue UnsafeCutError => err
          return block_sheet(arr, tag, err.message)
        end
        _f68f66d8 = arr[:thickness_issues][arr2.object_id]
        return block_sheet(arr, tag, _f68f66d8) if _f68f66d8
        arr3.concat(check_back_face(arr, arr2, box2)) if font == :back
        _9f00578a = arr[:thickness][arr2.object_id]
        arr9 = vectors.select { |vec| part_border?(vec.layer_name) }
        arr4 = vectors.reject { |vec| border_layer?(vec.layer_name) }
        layer_map = arr[:layer_map]
        _6f1fcc2b = tool_index_for(arr, _9f00578a, font == :back)
        arr6 = operations_for(arr4, layer_map, _6f1fcc2b, arr[:tool_order], arr[:layer_order])
        arr8, arr7 = split_unmapped(arr4, _6f1fcc2b, layer_map)
        return block_sheet(arr, tag, Text.t(:chong_bay, :chua_gan, layer: arr8.join(", "))) unless arr8.empty?
        arr7.each { |layer_name| arr[:skipped_layers] << "#{arr2[:name]} / #{layer_name}" }
        arr3 << Text.t(:xuat, :layer_bo_qua, layer: arr7.join(", ")) unless arr7.empty?
        tools_too_deep(arr2, _6f1fcc2b, layer_map, _9f00578a, arr4).each do |tool|
          arr3 << Text.t(:mo_phong, :qua_day, ten: ten(tool), sau: Text.num(tool["cut_depth"].to_f.abs), day: Text.num(_9f00578a))
        end
        arr3 << Text.t(:mo_phong, :bi_chan_trong) if arr6.empty? && !all_skipped?(arr4, layer_map)
        return if arr6.empty?
        arr5 = materials_of(arr2)
        return block_sheet(arr, tag, Text.t(:van, :nhieu_vat_lieu, vat_lieu: arr5.join(", "))) if arr5.length > 1
        unless (arr[:prefixes][str] ||= prefix) == prefix
          raise UnsafeCutError, Text.t(:van, :trung_thu_muc, thu_muc: safe_filename)
        end
        file = "#{_d854c351}.#{arr[:extension]}"
        path = unique_path(str, file, arr[:reserved])
        str2 = File.join(arr[:temp_root], File.join(safe_filename, file).tr("\\", "/"))
        begin
          plan = Planner::Builder.to_segments(vectors: vectors, origin: anchor, operations: arr6,
                                              references: arr9, repair_stats: (h = {}))
          h.each { |key, want| arr[:repair_stats][key] = arr[:repair_stats].fetch(key, 0) + want }
          arr3.concat(plan.warnings).concat(repair_notes(h))
          if plan.paths.empty? && plan.hard_issues.empty? && plan.shape_report[:ok]
            arr3 << Text.t(:mo_phong, :bi_chan_trong)
            return
          end
          Check.assert_plan_ok(plan)
          Frame.assert_plan_in_sheet(plan, box2)
          txt3 = render_program(
            "#{_d854c351}_#{font == :back ? 'MAT_SAU' : "MAT_TRUOC"}", arr[:post], File.basename(path, ".*"),
            (depth = []), { name: arr5.first || "CHUA_XAC_DINH", thickness: _9f00578a }, plan
          )
          arr[:pass_warnings].concat(depth)
          arr3.concat(depth)
          if font == :back
            txt3, bnds = Frame.shift_program(txt3, box2)
            Frame.assert_moves_in_sheet(txt3, box2, bnds)
          end
          assert_not_g90_1(txt3, arr[:post])
          assert_cuts(txt3, path)
          data = txt3.encode("UTF-8")
          FileUtils.mkdir_p(File.dirname(str2))
          File.binwrite(str2, data)
          arr[:staged] << [str2, path, Digest::SHA256.hexdigest(data)]
        rescue UnsafeCutError => err
          block_sheet(arr, tag, err.message)
        end
      ensure
        lines = arr3.compact.uniq
        (arr[:logs][str] ||= []) << [sheet_label(arr, arr2, font, false), lines] unless lines.empty?
        report(arr, "sheet_end", 5 + ((idx + 1).to_f / arr[:total] * 88.0).floor, idx + 1)
      end
      def commit(arr)
        arr3 = arr[:blocked_sheets]
        raise UnsafeCutError, Text.t(:xuat, :van_loi, danh_sach: arr3.uniq.join("\n")) unless arr3.empty?
        raise UnsafeCutError, Text.t(:van, :khong_duong_dao) if arr[:staged].empty?
        total = arr[:total]
        arr2 = arr[:staged].map { |arr4| arr4[1] }
        report(arr, "metadata", 94, total)
        arr5 = (arr2 + arr[:spared]).to_h { |path| [[File.dirname(path), File.basename(path).upcase], true] }
        num = 0
        arr[:prefixes].each do |folder, prefix|
          Dir.glob(File.join(folder, "#{prefix}_Sheet_*.#{arr[:extension]}")).each do |path|
            next if arr5[[folder, File.basename(path).upcase]]
            stash_existing(arr, path, format("stale_%04d_%s", num, File.basename(path)))
            num += 1
          end
        end
        report(arr, "commit", 97, total)
        arr[:staged].each_with_index do |(_6df7ac1d, path), idx|
          FileUtils.mkdir_p(File.dirname(path))
          stash_existing(arr, path, format("%04d_%s", idx, File.basename(path))) if File.exist?(path)
          FileUtils.mv(_6df7ac1d, path)
          arr[:committed] << path
        end
        report(arr, "verify", 99, total)
        arr[:staged].each do |_7636052c, path, _9ba72318|
          next if File.file?(path) && Digest::SHA256.hexdigest(File.binread(path)) == _9ba72318
          raise UnsafeCutError, Text.t(:van, :ghi_loi, file: File.basename(path))
        end
        arr[:prefixes].each_key do |folder|
          rows = Array(arr[:logs][folder]).flat_map do |head_off, lines|
            [Text.t(:xuat, :log_van, van: head_off)] + lines.map { |axis| Text.t(:xuat, :log_dong, loi: axis) }
          end
          rows = [Text.t(:xuat, :log_trong)] if rows.empty?
          File.binwrite(File.join(folder, "logs.txt"), "#{rows.join("\r\n")}\r\n".encode("UTF-8")) rescue nil
        end
        begin
          target = arr[:folder].tr("\\", "/").gsub(/[^\-_.!~*'()a-zA-Z\d;\/?:@&=+$,\[\]]/) do |str|
            str.bytes.map { |_438de1e4| format("%%%02X", _438de1e4) }.join
          end
          ::UI.openURL("file:///#{target}")
        rescue StandardError
        end
        report(arr, "complete", 100, total)
        arr31 = final_notes(arr)
        {
          ok: true, blocked: false, message: ([Text.t(:xuat, :da_xuat, so: arr2.length, thu_muc: arr[:folder])] + arr31).join("\n"),
          notes: arr31, files: arr2, skipped_layers: arr[:skipped_layers], skipped_sheets: [], unticked_sheets: [], blocked_sheets: []
        }
      end
      def confirm_export(db, model, excluded)
        arr, lines = precheck(db, model, excluded)
        unless arr.empty?
          show_result(ok: false, message: Text.t(:xuat, :khong_xuat_vi, ly_do: Text.t(:xuat, :van_loi, danh_sach: arr.join("\n"))))
          return false
        end
        lines.empty? || ::UI.messagebox((lines + ['', Text.t(:xuat, :hoi_tiep)]).join("\n"), ::MB_YESNO) == ::IDYES
      end
      def precheck(db, model, excluded = [])
        _13b63df0, _b86d3bd7 = scan_issues(db, model, excluded)
        arr = Library.config_copy
        str = arr["tools"].to_h { |tool| [tool["id"].to_s, true] }
        layer_map = arr["layer_map"]
        arr4 = included_sheets(db, excluded).flat_map { |arr3| arr3[:vectors] }.reject do |vec|
          name = vec.layer_name
          reference?(vec) || border_layer?(name) || latch_tag(vec) || str.key?(layer_map[name.strip].to_s) ||
            skip_layer?(layer_map, name)
        end
        side_names = arr4.map(&:layer_name).uniq.sort_by { |name| Natural.key(name) }
        lines = side_names.empty? ? _b86d3bd7 : _b86d3bd7 << Text.t(:xuat, :layer_bo_qua, layer: side_names.join(", "))
        arr2 = simulated_sheet_labels(db, model, excluded)
        lines.unshift(Text.t(:xuat, :van_mo_phong, van: arr2.join(", "))) unless arr2.empty?
        [_13b63df0, lines.length > 8 ? lines.first(8) << Text.t(:xuat, :con_canh_bao, so: lines.length - 8) : lines]
      end
      def simulated_sheet_labels(db, model, excluded)
        return [] if Canvas.slots.none? { |_b18aa2f0, slot| slot[:row][:blocked] }
        meta = Canvas.build_meta(model, cnc_settings)
        Canvas.sheet_rows(db).filter_map do |arr|
          id = arr[:path_key].to_s
          slot = Canvas.slots[id]
          next unless slot && slot[:row][:blocked] && !excluded.include?(id)
          next unless Canvas.slot_fresh?(slot, Canvas.slot_key(arr, meta), Canvas.tool_names(arr, meta))
          fields = Canvas.sheet_fields(arr, meta)
          "#{fields[:label]}#{fields[:bottom] ? Text.t(:van, :mat) : ''}"
        end
      rescue UnsafeCutError
        []
      end
      def scan_issues(db, model, excluded = [])
        settings = cnc_settings
        arr5 = Library.config_copy
        sheets = order_sheets(sheet_map(db).values, model)
        rects = layout_rects(sheets, model)
        thickness, arr7 = thickness_map(sheets, rects, settings)
        arr3 = { layout: rects, group_count: rects.values.uniq { |arr8| arr8[:group_label] }.length }
        str = arr5["tools"].to_h { |tool| [tool["id"].to_s, tool] }
        layer_map = arr5["layer_map"]
        _13b63df0, arr4, arr6 = [], {}, {}
        sheets.each do |arr|
          next if excluded.include?(arr[:path_key].to_s)
          font = work_face(arr[:vectors])
          _f68f66d8 = arr7[arr.object_id]
          next _13b63df0 << Text.t(:van, :dong, van: sheet_label(arr3, arr, font), loi: _f68f66d8) if _f68f66d8
          _9f00578a = thickness[arr.object_id]
          _124c7bd3 = group_suffix(arr3, arr)
          tag = sheet_label(arr3, arr, font, false)
          arr2 = arr[:vectors].reject { |vec| reference?(vec) || border_layer?(vec.layer_name) }
          tools_too_deep(arr, str, layer_map, _9f00578a, arr2).each do |tool|
            (arr4[[ten(tool), Text.num(tool["cut_depth"].to_f.abs), Text.num(_9f00578a), _124c7bd3]] ||= []) << tag
          end
          next if arr2.any? { |vec| latch_tag(vec) || str.key?(layer_map[vec.layer_name.strip].to_s) }
          next if all_skipped?(arr2, layer_map)
          (arr6[_124c7bd3] ||= []) << tag
        end
        lines = arr4.map do |(lbl, depth, val, _124c7bd3), van|
          Text.t(:xuat, :qua_day, ten: lbl, sau: depth, day: val, van: van.join(", ") + _124c7bd3)
        end
        [_13b63df0, lines + arr6.map { |_124c7bd3, van| Text.t(:xuat, :van_bo_qua, van: van.join(", ") + _124c7bd3) }]
      rescue UnsafeCutError
        [[], []]
      end
      def thickness_map(sheets, rects, settings)
        thickness = sheets.to_h { |sheet| [sheet.object_id, thickness_of(sheet, settings)] }
        h = {}
        sheets.each { |sheet| h[sheet.object_id] = thickness_problem(sheet) unless thickness[sheet.object_id] }
        sheets.group_by { |sheet| rects[sheet.object_id].values_at(:group_label, :sheet_number) }.each_value do |src|
          vars = src.filter_map { |sheet| thickness[sheet.object_id] }.uniq
          next if vars.length < 2
          reason = Text.t(:van, :lech_do_day, a: Text.num(vars[0]), b: Text.num(vars[1]))
          src.each { |sheet| h[sheet.object_id] ||= reason }
        end
        [thickness, h]
      end
      def skip_layer?(layer_map, name)
        layer_map[name.to_s.strip] == Library::SKIP_LAYER
      end
      def tools_too_deep(arr3, arr2, layer_map, _9f00578a, arr = nil)
        arr ||= arr3[:vectors].reject { |vec| reference?(vec) || border_layer?(vec.layer_name) }
        tools = arr.map(&:layer_name).uniq.filter_map { |name| arr2[layer_map[name.strip].to_s] }.uniq
        tools.select { |tool| tool["cut_depth"].to_f.abs - _9f00578a > 1.0 + 1.0e-6 }
      end
      def split_unmapped(arr3, h, layer_map)
        arr2 = arr3.reject do |vec|
          h.key?(layer_map[vec.layer_name.strip].to_s) || skip_layer?(layer_map, vec.layer_name)
        end
        arr = arr2.select { |vec| latch_tag(vec) }.map(&:layer_name).uniq
        [arr, arr2.map(&:layer_name).uniq - arr]
      end
      def all_skipped?(arr, layer_map)
        arr.any? && arr.all? { |vec| skip_layer?(layer_map, vec.layer_name) }
      end
      def show_result(ok)
        lines = ok[:ok] ? Array(ok[:notes]) : ok[:message].to_s.lines.map(&:chomp)
        lines = lines.first(9) << "..." if !ok[:ok] && lines.length > 9
        ::UI.messagebox(lines.join("\n")) unless lines.empty?
      end
      def rollback(arr)
        arr[:committed].reverse_each { |path| FileUtils.rm_f(path) }
        arr[:backups].each do |path, _741b09c7|
          next unless File.exist?(_741b09c7)
          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.mv(_741b09c7, path, force: true)
        rescue StandardError
        end
      end
      def stash_existing(arr, path, name)
        str = File.join(arr[:temp_root], ".previous_outputs", name)
        FileUtils.mkdir_p(File.dirname(str))
        FileUtils.mv(path, str)
        arr[:backups][path] = str
      end
      def included_sheets(db, excluded)
        sheet_map(db).values.reject { |arr| excluded.include?(arr[:path_key].to_s) }
      end
      def set_aside_excluded(arr, excluded)
        arr4, arr[:sheets] = arr[:sheets].partition { |arr2| excluded.include?(arr2[:path_key].to_s) }
        arr[:total] = arr[:sheets].length
        arr[:spared] = arr4.map do |arr2|
          safe_filename, _a6f0205b, arr3 = output_names(arr, arr2, work_face(arr2[:vectors].reject { |vec| reference?(vec) }))
          File.join(arr[:folder], safe_filename, "#{arr3}.#{arr[:extension]}")
        end
      end
      def output_names(arr, sheet, font)
        rects = arr[:layout].fetch(sheet.object_id)
        lbl = rects[:group_label]
        prefix = file_prefix(Naming.strip_thickness(lbl))
        [folder_name(lbl), prefix, format("%s_Sheet_%02d%s", prefix, rects[:sheet_number], font == :back ? "_MAT_SAU" : '')]
      end
      def sheet_label(arr, sheet, font, flag = true)
        number = arr[:layout].fetch(sheet.object_id)[:sheet_number]
        Text.t(:van, :ten_van, so: number, mat: font == :back ? Text.t(:van, :mat) : '', nhom: flag ? group_suffix(arr, sheet) : '')
      end
      def group_suffix(arr, sheet)
        arr[:group_count] > 1 ? Text.t(:van, :nhom, nhom: arr[:layout].fetch(sheet.object_id)[:group_label]) : ''
      end
      def block_sheet(arr, tag, error)
        error.each_line { |axis| arr[:blocked_sheets] << Text.t(:van, :dong, van: tag, loi: axis.chomp) }
      end
      def check_back_face(arr, sheet, box2)
        van = sheet_label(arr, sheet, :back)
        _05b497c8 = arr[:fronts][sheet.object_id]
        lines = [(Text.t(:mat_sau, :thieu_khung, van: van) unless box2[:full_sheet]),
                    _05b497c8 && back_mismatch_note(sheet, _05b497c8, van)].compact
        lines.each { |error| add_warning(error) }
      end
      def back_mismatch_note(arr3, arr4, van)
        arr = Frame.face_mismatches(arr3[:vectors].reject { |vec| reference?(vec) },
                                       arr4[:vectors].reject { |vec| reference?(vec) })
        return if arr.empty?
        arr2 = arr.first(5).map { |x, y| Text.t(:mat_sau, :diem, x: Text.num(x, 1), y: Text.num(y, 1)) }
        arr2 << "..." if arr.length > 5
        Text.t(:mat_sau, :lech_mat_truoc, van: van, vi_tri: arr2.join(", "))
      end
      def front_of(sheets, rects)
        sheets.group_by { |arr| rects[arr.object_id].values_at(:group_label, :sheet_number) }.each_value.with_object({}) do |src, arr37|
          _05b497c8 = src.find { |arr| work_face(arr[:vectors]) == :front }
          src.each { |arr| arr37[arr.object_id] = _05b497c8 } if _05b497c8
        end
      end
      def add_warning(error)
        (@arr17 ||= []) << error
      end
      def final_notes(arr)
        warnings = (@arr17 + arr[:pass_warnings]).uniq
        lines = warnings.length > 8 ? warnings.first(8) << Text.t(:xuat, :con_canh_bao, so: warnings.length - 8) : warnings
        lines.concat(repair_notes(arr[:repair_stats]))
      end
      def repair_notes(arr)
        _e71d2c44 = { noi_kin: :gaps_shut, bo_trung: :dupes_cut, bo_khong: :zero_segs_cut }
        arr29 = _e71d2c44.filter_map { |key, stat| Text.t(:xuat, key, so: arr[stat].to_i) if arr[stat].to_i.positive? }
        arr29.empty? ? [] : [Text.t(:xuat, :da_sua_ban_ve, viec: arr29.join(", "))]
      end
      def report(arr, _107291da, percent, idx = 0)
        arr[:progress]&.call(stage: _107291da, percent: percent, sheet_index: idx, sheet_total: arr[:total])
      end
      def cnc_settings
        Dialog.normalized_settings
      end
      def merge_tool_settings(tool, settings)
        tool.merge(
          "goc_cao_do" => settings["goc_cao_do"], "do_day_van" => settings["do_day_van"], "cao_an_toan" => settings["cao_an_toan"],
          "tu_dong_giam_toc" => settings["tu_dong_giam_toc"] == true, "toc_do_giam_toc" => settings["toc_do_giam_toc"],
          "khoang_cach_giam_toc" => settings["khoang_cach_giam_toc"],
          "khoang_cach_xuong_dao" => settings["toi_uu_xuong_dao"] == true ? settings["khoang_cach_xuong_dao"] : 0.0
        )
      end
      def tool_index_for(arr, _9f00578a, back)
        arr2 = (arr[:tool_sets] ||= {})
        addon_data = back ? { "do_day_van" => _9f00578a, "khoang_cach_xuong_dao" => 0.0 } : { "do_day_van" => _9f00578a }
        arr2[[_9f00578a, back]] ||= arr[:tool_index].transform_values { |tool| tool.merge(addon_data) }
      end
      def pass_limit_note(tool)
        return [] if tool["type"] == "drill" || pass_depths(tool).length <= PASS_LIMIT
        [Text.t(:dao, :qua_nhieu_luot, ten: ten(tool), max: PASS_LIMIT, sau: Text.num(tool["cut_depth"].to_f.abs, 2))]
      end
      def latch_tag(vec)
        layer = vec.layer_name.to_s
        side = vec.latch_side.to_s.downcase
        return if layer != vec.latch_row.to_s || Latch.side_of(layer) != side
        [side, [vec.latch_seq.to_i, 0].max]
      end
      def sim_view?
        Thread.current[RUN_SCOPE_KEY] == true
      end
      def with_run_scope(saved_sel)
        _1b553836 = Thread.current[RUN_SCOPE_KEY]
        Thread.current[RUN_SCOPE_KEY] = saved_sel.to_s == "sim_view"
        yield
      ensure
        Thread.current[RUN_SCOPE_KEY] = _1b553836
      end
      def reset_path_cache
        @h31 = {}
      end
      def path_cache_limit(want = nil)
        @path_cache_limit = [want.to_i, 1024].max if want
        @path_cache_limit || 1024
      end
      def tool_cut_keys(tool)
        tool.reject { |key, _| DISPLAY_TOOL_KEYS.include?(key.to_s) }
      end
      def cached_path(vec, out, tool, anchor, nested)
        return build_path(vec, out, tool, anchor, nested) if out.length < 2
        _ec0da59d = ::Digest::SHA256.new
        _ec0da59d << "#{nested ? 1 : 0}|#{anchor[0].to_f.round(6)},#{anchor[1].to_f.round(6)}|#{canonical(tool_cut_keys(tool)).inspect}|"
        _ec0da59d << "#{vec.operation_type}|#{vec.closed ? 'closed' : "open"}|"
        out.each { |pt| _ec0da59d << format("%.6f,%.6f;", pt[0], pt[1]) }
        key = _ec0da59d.hexdigest
        cache = (@h31 ||= {})
        return cache[key] if cache.key?(key)
        ok = cache[key] = build_path(vec, out, tool, anchor, nested)
        128.times { cache.shift } if cache.length > path_cache_limit
        ok
      end
      def nesting_label(arr, model)
        vectors = arr[:vectors]
        flag = arr[:nesting_name]
        flag = first_attr(vectors, :nesting_name) if flag.empty?
        str2 = first_attr(vectors, :root_sheet_name)[/\A_*(.+?)-\d+(?:[.,]\d+)?\s*mm-sheet-\d+/i, 1].to_s.strip
        str = first_sheet_layer(vectors).sub(/[\s\-_]*\d+(?:[.,]\d+)?\s*mm\z/i, '').strip
        [str2, str].each { |name| flag = name if generic_nesting_name?(flag) && !name.empty? }
        flag = common_parent_name(vectors).then { |name| name.empty? ? flag : name } if generic_nesting_name?(flag)
        if generic_nesting_name?(flag)
          name = File.basename(model.path, File.extname(model.path)).strip
          name = model.title.strip if name.empty?
          flag = name unless name.empty?
        end
        flag.empty? ? "ABF Nesting" : flag
      end
      def first_attr(vectors, attr)
        vectors.each do |vec|
          text = vec.public_send(attr).to_s.strip
          return text unless text.empty?
        end
        ''
      end
      def first_sheet_layer(vectors)
        vectors.each do |vec|
          name = vec.sheet_entity&.layer&.name.to_s.strip
          return name unless name.empty? || name == "Layer0" || name.casecmp?("Untagged")
        end
        ''
      end
      def nesting_key(arr, _361efed0)
        arr2 = common_path_key(arr[:vectors])
        return "PATH:#{arr2}" unless arr2.empty?
        id = arr[:nesting_id]
        id = first_attr(arr[:vectors], :nesting_id) if id.empty?
        id.empty? ? "NAME:#{file_prefix(_361efed0)}" : "ID:#{id}"
      end
      def order_sheets(sheets, model)
        h = sheets.each_with_object({}) do |arr, groups|
          name = nesting_label(arr, model)
          (groups[nesting_key(arr, name)] ||= { name: name, sheets: [] })[:sheets] << arr
        end
        arr3 = sheets.to_h { |arr| [arr.object_id, min_xy(arr[:vectors])] }
        rows = h.values.sort_by do |arr2|
          partner = arr2[:sheets].filter_map { |arr| arr3[arr.object_id] }
          anchor = partner.empty? ? [Float::INFINITY, Float::INFINITY] : [partner.map(&:first).min, partner.map(&:last).min]
          [anchor[1], anchor[0], Natural.key(arr2[:name])]
        end
        rows.flat_map do |arr2|
          arr2[:sheets].sort_by do |arr|
            anchor = arr3[arr.object_id] || [Float::INFINITY, Float::INFINITY]
            [anchor[1], anchor[0], Natural.key(arr[:name]), arr[:path_key]]
          end
        end
      end
      def min_xy(vectors)
        out = vectors.flat_map(&:points).compact
        return if out.empty?
        [out.map { |pt| pt.x.to_f * MM_PER_INCH }.min, out.map { |pt| pt.y.to_f * MM_PER_INCH }.min]
      end
      def generic_nesting_name?(name)
        ['', "ABFNESTING", "NESTING"].include?(layer_key(name))
      end
      def common_parent_name(vectors)
        side_names = vectors.filter_map do |vec|
          path = clean_path(vec)
          idx = sheet_depth(path)
          path[idx - 1] if idx
        end
        most_common(side_names)
      end
      def common_path_key(vectors)
        keys = vectors.filter_map do |vec|
          side_names = clean_path(vec)
          idx = sheet_depth(side_names)
          next unless idx
          arr = vec.src_path_ids
          arr.length == side_names.length ? "IDS:#{arr[0...idx].join(' > ')}" : side_names[0...idx].map(&:upcase).join(" > ")
        end
        most_common(keys)
      end
      def clean_path(vec)
        vec.source_path.map { |fld| fld.to_s.strip }.reject(&:empty?)
      end
      def sheet_depth(side_names)
        idx = side_names.rindex { |fld| sheet_token?(fld) }
        return unless idx&.positive?
        name = side_names[idx - 1]
        return if generic_nesting_name?(name) || %w[_ABF_CUTTINGLINES ABF_CUTTINGLINES].include?(name.upcase)
        idx unless name.match?(/\A(?:BOARD|PART)(?:\b|[-_])/i)
      end
      def most_common(vars)
        vars.tally.max_by { |_37805536, want| want }&.first.to_s
      end
      def root_sheet_key(arr)
        str = arr[:vectors].find { |row| !row.root_sheet_id.to_s.strip.empty? }
        str ? str.root_sheet_id.to_s : arr[:name].sub(/_MAT_(?:TRUOC|SAU)\z/i, '').upcase
      end
      def layout_key(arr)
        arr[:layout_key] ||= [nesting_key(arr, arr[:nesting_name]), root_sheet_key(arr)].join("::")
      end
      def work_face(vectors)
        vectors.any? { |vec| vec.work_face == :back } ? :back : :front
      end
      def mark_square?(layer)
        layer_key(layer) == "ABFMARKSQUARE"
      end
      def clear_sheet_map
        @arr5 = nil
      end
      def sheet_map(db)
        sheets = db.sheets
        return @arr5[1] if @arr5 && @arr5[0].equal?(sheets)
        groups = sheets.each_with_object({}) do |arr2, partner|
          vectors = arr2[:vectors]
          _3bcc699b = first_attr(vectors, :nesting_id)
          name = arr2[:name].strip
          partner[[_3bcc699b, arr2[:id]]] = {
            name: name.empty? ? "TAM_KHONG_TEN" : name, nesting_name: first_attr(vectors, :nesting_name),
            nesting_id: _3bcc699b, path_key: arr2[:id], vectors: vectors, boards: arr2[:boards]
          }
        end
        pair_faces(groups)
        groups.values.group_by { |arr| arr[:path_key] }.each_value do |rows|
          next if rows.uniq { |arr| arr[:nesting_id] }.length < 2
          rows.each { |arr| arr[:path_key] = [arr[:nesting_id], arr[:path_key]].reject(&:empty?).join(" > ") }
        end
        (@arr5 = [sheets, groups])[1]
      end
      def sheet_token?(name)
        name.match?(/(?:\A|[-_])sheet(?:[-_]|\z)/i)
      end
      def border_layer?(layer)
        %w[ABFPARTBORDER ABFSHEETBORDER].include?(layer_key(layer))
      end
      def part_border?(layer)
        layer_key(layer) == "ABFPARTBORDER"
      end
      def layer_key(layer)
        return Util.alnum_upper(layer) unless layer.instance_of?(String)
        keys = (@layer_key_cache ||= {})
        keys.clear if keys.length > 20_000
        keys[layer] ||= Util.alnum_upper(layer).freeze
      end
      def reference?(vec)
        arr = %w[ABFEDGEBANDING ABFLABEL PTLARROW ABFSHEETID ABFSHEETMATERIAL]
        arr.include?(layer_key(vec.layer_name)) ||
          vec.source_path.any? { |val| arr.include?(layer_key(val)) }
      end
      def pair_faces(groups)
        rows = groups.filter_map do |key, arr3|
          number = Naming.sheet_number(root_sheet_names(arr3), arr3[:name])
          { key: key, sheet: arr3, vectors: arr3[:vectors], face: work_face(arr3[:vectors]), number: number } if number
        end
        return if rows.none? { |arr| arr[:face] == :back }
        rows.each do |arr|
          arr3 = arr[:sheet]
          arr.merge!(label: sheet_group_label(arr3, arr3[:nesting_name]), nesting_id: arr3[:nesting_id],
                        frame_key: frame_key(arr[:vectors]), lineage: lineage(arr[:vectors]))
        end
        arr9, arr11 = rows.partition { |arr| arr[:face] == :front }
        arr11.each do |back|
          arr6 = arr9.select do |arr2|
            arr2[:number] == back[:number] && arr2[:frame_key] && arr2[:frame_key] == back[:frame_key] &&
              (label_match?(arr2[:label], back[:label]) || prefix_match?(arr2[:lineage], back[:lineage]))
          end
          if arr6.empty?
            arr6 = arr9.select do |arr2|
              arr2[:number] == back[:number] && !back[:nesting_id].empty? && arr2[:nesting_id] == back[:nesting_id] &&
                label_match?(arr2[:label], back[:label]) && prefix_match?(arr2[:lineage], back[:lineage])
            end
          end
          _70dfea41 = arr6.first if arr6.length == 1
          back[:holder_label], back[:holder_key] = _70dfea41[:label], layout_key(_70dfea41[:sheet]) if _70dfea41
        end
        arr11.select { |arr| arr[:frame_key] }.group_by { |arr| [arr[:number], arr[:frame_key]] }.each_value do |_c6fd4069|
          cluster_by_label(_c6fd4069).each do |arr4|
            arr10 = arr4.map { |arr| arr[:holder_label].to_s.strip }.reject(&:empty?).uniq
            arr8 = arr4.map { |arr| arr[:holder_key].to_s.strip }.reject(&:empty?).uniq
            num = arr10.first if arr10.length == 1
            num ||= arr4.map { |arr| arr[:label] }
                                         .max_by { |lbl| [Naming.label_fingerprint(lbl).length, lbl.length] }
            arr7 = arr4.max_by do |arr|
              [arr[:label] == num ? 1 : 0, Naming.label_fingerprint(arr[:label]).length, arr[:vectors].length]
            end
            arr5 = arr7[:sheet]
            arr5.merge!(label_override: num, number_override: arr7[:number])
            arr5[:physical_override] = arr8.first if arr8.length == 1
            next if arr4.length == 1
            arr5[:vectors] = arr4.flat_map { |arr| arr[:sheet][:vectors] }
            arr5[:boards] = arr4.each_with_object({}) do |arr, arr12|
              arr[:sheet][:boards].each { |key, board| arr12[key] ||= board }
            end
            arr4.each { |arr| groups.delete(arr[:key]) unless arr[:key] == arr7[:key] }
          end
        end
      end
      def cluster_by_label(rows)
        pending, ok = rows.dup, []
        until pending.empty?
          arr, rsz = [pending.shift], 0
          until rsz == arr.length
            rsz = arr.length
            pending.dup.each do |path|
              flag = arr.any? do |arr2|
                label_match?(arr2[:label], path[:label]) || prefix_match?(arr2[:lineage], path[:lineage])
              end
              arr << pending.delete(path) if flag
            end
          end
          ok << arr
        end
        ok
      end
      def frame_key(vectors)
        box2 = Frame.to_segments(vectors, back_face: true)
        box2[:global_bounds].map { |val| (val * 100.0).round }.join(":") if box2&.dig(:full_sheet)
      end
      def lineage(vectors)
        vectors.each do |vec|
          side_names = vec.source_path.map { |fld| fld.to_s.strip }
          idx = side_names.rindex { |fld| sheet_token?(fld) }
          next unless idx
          arr2 = vec.src_path_ids
          arr = arr2.length == side_names.length ? arr2[0...idx].map(&:to_s) : side_names[0...idx].map(&:upcase)
          arr = arr.drop(1) if generic_nesting_name?(side_names.first)
          return arr.reject(&:empty?)
        end
        []
      end
      def prefix_match?(row0, arr)
        return false if row0.empty? || arr.empty?
        arr2, num = row0.length <= arr.length ? [row0, arr] : [arr, row0]
        num[0, arr2.length] == arr2
      end
      def label_match?(row0, _55d3a52b)
        arr, b = Naming.label_fingerprint(row0), Naming.label_fingerprint(_55d3a52b)
        return false if arr.empty? || b.empty?
        arr == b || (arr.length >= 4 && b.length >= 4 && (arr.include?(b) || b.include?(arr)))
      end
      def sheet_group_label(arr, str)
        side_names = root_sheet_names(arr)
        labels = (@label_cache ||= {})
        labels.clear if labels.length > 4096
        labels[[side_names.tally.to_a, arr[:name].to_s.dup, str.to_s.dup]] ||=
          Naming.lbl(root_sheet_names: side_names, sheet_name: arr[:name], nesting_name: str).freeze
      end
      def root_sheet_names(arr)
        arr[:vectors].map { |vec| vec.root_sheet_name.to_s.strip }.reject(&:empty?)
      end
      def folder_name(_32919b81)
        str = strip_accents(Naming.safe_filename(_32919b81)).gsub(/[^A-Z0-9._-]+/, " ").squeeze("-").strip
        cut_to_max_len(str.empty? ? "NESTING" : str.sub(/MM\z/i, "mm")).strip
      end
      def layout_rects(sheet_rows, model)
        rows = sheet_rows.map do |arr|
          _361efed0 = nesting_label(arr, model)
          _32919b81 = arr[:label_override] || sheet_group_label(arr, _361efed0)
          str = arr[:physical_override] || [nesting_key(arr, _361efed0), root_sheet_key(arr)].join("::")
          number = arr[:number_override] || Naming.sheet_number(root_sheet_names(arr), arr[:name])
          { sheet: arr, group_label: _32919b81, group_key: Naming.label_fingerprint(_32919b81), real_key: str, number: number }
        end
        rows.group_by { |arr2| arr2[:group_key] }.each_value.with_object({}) do |arr3, rects|
          h3, h2, h = {}, {}, 1
          arr3.each do |arr2|
            next unless (number = arr2[:number])
            _86048f49 = (h2[number] ||= arr2[:real_key])
            raise UnsafeCutError, Text.t(:van, :trung_so_van, nhom: arr2[:group_label], so: number) unless _86048f49 == arr2[:real_key]
            h3[arr2[:real_key]] = number
          end
          arr3.each do |arr2|
            number = h3.fetch(arr2[:real_key]) do |_3002cc70|
              h += 1 while h2.key?(h)
              h2[h] = _3002cc70
              h3[_3002cc70] = h
            end
            rects[arr2[:sheet].object_id] = { group_label: arr3.first[:group_label], sheet_number: number }
          end
        end
      end
      def unique_path(folder, file, arr)
        arr29 = File.join(folder.tr("\\", "/").split("/").last, file).tr("\\", "/").split("/")
        raise UnsafeCutError, Text.t(:van, :ten_file_sai, file: file) if arr29.include?("..") || arr29.include?(".")
        path = File.join(folder, file)
        key = File.expand_path(path).tr("\\", "/").upcase
        raise UnsafeCutError, Text.t(:van, :trung_file, file: file) if arr[key]
        arr[key] = true
        path
      end
      def strip_accents(text)
        text.upcase.tr("ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴĐÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ",
                       "AAAAAAAAAAAAAAAAADEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYY")
      end
      def file_prefix(name)
        arr = strip_accents(name).gsub(/[^A-Z0-9]+/, "_").gsub(/\A_|_\z/, '')
        cut_to_max_len(arr.empty? ? "TAM_KHONG_TEN" : arr)
      end
      def cut_to_max_len(arr2)
        return arr2 if arr2.length <= FILENAME_MAX_LENGTH
        arr = arr2[0, FILENAME_MAX_LENGTH]
        _bcf5767b = arr.rindex("_")
        flag = (_bcf5767b && _bcf5767b >= (FILENAME_MAX_LENGTH * 0.4) ? arr[0, _bcf5767b] : arr).gsub(/_+\z/, '')
        flag.empty? ? arr : flag
      end
      def materials_of(arr)
        container = arr[:vectors].flat_map { |vec| [vec.sheet_entity, vec.board_entity, vec.part_entity] }.compact
        side_names = container.uniq(&:persistent_id).filter_map { |entity| material_of(entity) }
        side_names = arr[:boards].each_value.filter_map { |board| material_name(board[:name]) } if side_names.empty?
        side_names = [material_name(arr[:name])].compact if side_names.empty?
        side_names.group_by { |name| name.upcase.tr("Đ", "D").gsub(/[^A-Z0-9]+/, '') }.values.map(&:first)
      end
      def thickness_of(sheet, settings)
        settings["ghi_de_do_day_van"] == true ? settings["do_day_van"] : sheet_thickness(sheet)
      end
      def sheet_thickness(arr)
        container = arr[:vectors].filter_map(&:sheet_entity).uniq
        vars = container.map { |entity| Float(all_attributes(entity).to_h["ABF.sheet-thickness"], exception: false) }.uniq
        num = vars.first
        num if vars.length == 1 && num&.finite? && num.positive?
      end
      def thickness_problem(arr)
        flag = arr[:vectors].any? { |vec| vec.sheet_entity.respond_to?(:deleted?) && vec.sheet_entity.deleted? }
        Text.t(:van, flag ? :da_xoa : :khong_do_day)
      end
      def material_of(entity)
        arr = all_attributes(entity).find do |key, str|
          !str.to_s.strip.empty? &&
            !key.match?(/(?:thickness|do[_ -]?day|độ[_ -]?dày|panel[_ -]?thickness|board[_ -]?thickness)/i) &&
            key.match?(/(?:material|vat[_ -]?lieu|vật[_ -]?liệu|board[_ -]?material|panel[_ -]?material|decor|surface|code)/i)
        end
        return arr[1].to_s.strip if arr
        name = entity.name.to_s
        name = entity.definition.name.to_s if name.empty? && entity.definition
        material_name(name)
      end
      def all_attributes(entity)
        h7 = []
        entity.attribute_dictionaries&.each do |h|
          h.each_pair { |key, val| h7 << ["#{h.name}.#{key}", val] }
        end
        h7
      rescue StandardError
        []
      end
      def material_name(name)
        text = name.strip
        return unless text.match?(/MDF|HDF|PLY|PLYWOOD|VÁN|VAN|WOOD|ACRYLIC|PVC|MFC|MELAMINE|LAMINATE/i)
        str = text.gsub(/(?:^|[_ -])\d+(?:[.,]\d+)?\s*MM(?=$|[_ -])/i, " ").gsub(/\s+/, " ").strip
        str.empty? ? text : str
      end
      def num_text(num)
        number = num.to_f
        (number - number.round).abs < 0.001 ? number.round.to_s : format("%.2f", number).sub(/0+\z/, '').sub(/\.\z/, '')
      end
      def material_label(material)
        "#{ascii_label(material[:name])} #{num_text(material[:thickness])}MM"
      end
      def to_model_point(arr, anchor)
        ::Geom::Point3d.new((arr[0].to_f + anchor[0].to_f) / MM_PER_INCH, (arr[1].to_f + anchor[1].to_f) / MM_PER_INCH, 0)
      end
      def to_mm(pt, anchor)
        [pt.x.to_f * MM_PER_INCH - anchor[0].to_f, pt.y.to_f * MM_PER_INCH - anchor[1].to_f]
      end
      def origin_of(vectors)
        Frame.to_segments(vectors, back_face: work_face(vectors) == :back)&.dig(:origin)
      end
      @layer_key_cache = @label_cache = nil
    end
  end
end
