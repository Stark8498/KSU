require "json"
module KSU::Giacong
  def self.open
    ::KSU::Settings.check_license
    ::KSU::Xeptam.assert_license
    ::KSU::Settings.open_window("gia_cong")
  end
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (61 + i * 87) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
module KSU
  module Cnc
    module Dialog
      class SettingsError < StandardError; end
      module_function
      def on_fail(host)
        ::KSU::Cnc.set_run(@reader = nil)
        unless @dlg2 && @dlg2.host.equal?(host)
          wire_callbacks(@dlg2 = Relay.new(host))
          ::Sketchup.add_observer(@observer = ModelWatch.new) unless @observer
        end
        resp = JSON.generate(boot_payload(@reader)).gsub(/[\u2028\u2029]/) { |_af91c14b| format("\\u%04x", _af91c14b.ord) }
        host.execute_script("window.xncBoot && window.xncBoot(#{resp});")
      rescue ScriptError, StandardError
        ::UI.messagebox(Text.t(:giao_dien, :khong_mo))
        host.execute_script("window.xncBootFailed && window.xncBootFailed();")
      end
      def nesting_busy?
        return false unless defined?(::KSU::Nest) && ::KSU::Nest.labelling
        ::UI.messagebox(Text.t(:giao_dien, :dang_nesting))
        true
      end
      def handle_action(host, action, payload)
        return on_fail(host) if action == "boot"
        @dlg2.start2(action, payload) if @dlg2 && @dlg2.host.equal?(host)
      end
      def closed(host)
        return unless @dlg2 && @dlg2.host.equal?(host)
        @dlg2 = nil
        Pool.last_ix
      end
      def shutdown
        ::KSU::Cnc.set_run(@reader = nil)
        Pool.last_ix
        Canvas.reset2
        on_fail(@dlg2.host) if @dlg2 && @dlg2.host.visible?
      end
      def send_to_page(name, _c85b78dd, target)
        target.execute_script("window.xncReceive && window.xncReceive(#{JSON.generate(name)}, #{JSON.generate(_c85b78dd)});")
        true
      rescue StandardError
        false
      end
      def show_error(text, err)
        _c2a4afd5 = err.is_a?(Library::ConfigError) || err.is_a?(SettingsError) || err.is_a?(Abf::EditActive)
        ::UI.messagebox(_c2a4afd5 ? Text.error_text(err.message) : text)
      end
      def settings
        ::KSU::Settings.load["gia_cong"] || {}
      end
      def setting(key, default, key2 = settings)
        key2.key?(key) ? ::KSU::Settings.coerce(key2[key], default) : default
      end
      def save_settings(vars)
        data = ::KSU::Settings.load
        data["gia_cong"] = (data["gia_cong"] || {}).merge(vars)
        raise SettingsError, Text.t(:cai_dat, :khong_ghi_file) unless ::KSU::Settings.save_all(data)
      end
      def normalized_settings(key = settings)
        lead_shift_mm = Util.clamp_float(setting("khoang_cach_xuong_dao", 0.0, key), -10_000.0, 10_000.0, 0.0)
        {
          "ghi_de_do_day_van" => Util.bool_or(key["ghi_de_do_day_van"], false),
          "do_day_van" => Util.clamp_float(setting("do_day_van", 18.0, key), 3.0, 500.0, 18.0),
          "goc_cao_do" => setting("goc_cao_do", "top", key) == "bottom" ? "bottom" : "top",
          "cao_an_toan" => Util.clamp_float(setting("cao_an_toan", 10.0, key), 1.1, 500.0, 10.0),
          "tu_dong_giam_toc" => Util.bool_or(key["tu_dong_giam_toc"], false),
          "khoang_cach_giam_toc" => Util.clamp_float(setting("khoang_cach_giam_toc", 0.0, key), 0.0, 10_000.0, 0.0),
          "toc_do_giam_toc" => Util.clamp_float(setting("toc_do_giam_toc", 1200.0, key), 1.0, 100_000.0, 1200.0),
          "toi_uu_xuong_dao" => Util.bool_or(key["toi_uu_xuong_dao"], lead_shift_mm.abs > 0.0001),
          "khoang_cach_xuong_dao" => lead_shift_mm,
        }
      end
      def preview_settings(h)
        vars = normalized_settings(normalized_settings.merge(h))
        vars.delete("toi_uu_xuong_dao") unless h.key?("toi_uu_xuong_dao")
        save_settings(vars)
        normalized_settings
      end
      def parse_request(str)
        request = JSON.parse(str.to_s)
        request.is_a?(Hash) ? request : {}
      rescue StandardError
        {}
      end
      def save_tools(request)
        Library.save_config(request["tools"], request["layer_map"], request["layer_order"], request["cutters"],
                         notes: request["layer_notes"], colors: request["layer_colors"])
      end
      def tools_payload
        Library.config_copy.transform_keys(&:to_sym)
      rescue ScriptError, StandardError
        h5 = Library.default_layer_map
        { cutters: Library.default_cutters, tools: Library.default_tools, layer_map: h5["layer_map"],
          layer_order: h5["layer_order"], layer_notes: h5["layer_notes"], layer_colors: {} }
      end
      def parse_rows
        model = ::Sketchup.active_model
        side_names = model.layers.map { |grp| grp.name == "Layer0" ? "Untagged" : grp.name }
        side_names.to_h { |name| [name, Canvas.layer_color_hex(model, name)] }
      end
      def select_layer(layer)
        return nil if layer.empty?
        model = ::Sketchup.active_model
        unless Canvas.layer_of(model, layer)
          ::KSU.start(false)
          model.layers.add(layer)
          ::KSU.commit
        end
        { layer: layer, color: Canvas.layer_color_hex(model, layer) }
      rescue StandardError
        ::KSU.abort_op
        ::UI.messagebox(Text.t(:giao_dien, :khong_tao_layer, layer: layer))
        nil
      end
      def active_database
        @reader&.database || ::KSU::Cnc.database
      end
      def canvas_payload(only_index: nil, with_toolpaths: false, moves: true)
        arr = active_database
        return { ok: false } unless arr && arr.count.positive?
        ok = Canvas.to_segments(arr, ::Sketchup.active_model, only_index: only_index, with_toolpaths: with_toolpaths, moves: moves)
        merge_sheet_rows(arr, ok[:sheets]) if ok[:ok]
        ok
      end
      def merge_sheet_rows(db, rows)
        sheets = Canvas.sheet_rows(db)
        rows.each do |arr|
          vectors = sheets[arr[:index]][:vectors]
          arr[:source].each do |fld|
            entity = vectors[fld[:v]]&.entity
            if entity && entity.valid? && entity.respond_to?(:faces) && !entity.faces.empty?
              fld[:face] = true
            else
              fld.delete(:face)
            end
          end
        end
      end
      def sheet_by_key(key)
        db = active_database
        db && Canvas.sheet_index(db)[key.to_s]
      end
      def slot_report_now
        arr = active_database
        return { valid: [], stale: [] } unless arr && arr.count.positive?
        Canvas.slot_report(arr, ::Sketchup.active_model)
      end
      def set_excluded(request)
        arr3 = Array(request["ids"]).map(&:to_s)
        table_off = Array(request["off"]).map(&:to_s)
        db = active_database
        return arr3 if table_off.empty? || db.nil?
        keys = Canvas.sheet_rows(db).select { |arr| table_off.include?(Canvas.material_key(arr)) }
        arr3 | keys.map { |arr| arr[:path_key].to_s }
      end
      def run_one(key, moves)
        idx = sheet_by_key(key)
        return { ok: false, message: Text.t(:mo_phong, :khong_thay_van) } unless idx
        canvas_payload(only_index: idx, with_toolpaths: true, moves: moves)
      end
      def run_many(keys, moves, arr = [])
        _502c66f2 = Util.now
        rows, fail, pending, ok = {}, {}, [], { ok: true }
        keys.uniq.each do |key|
          idx = sheet_by_key(key)
          if idx.nil?
            fail[key] = Text.t(:mo_phong, :khong_thay_van)
          elsif ok[:ok] && (arr.include?(key) || (!rows.empty? && Util.now - _502c66f2 > 0.3))
            pending << key
          else
            ok = canvas_payload(only_index: idx, with_toolpaths: true, moves: moves) if ok[:ok]
            row = ok[:ok] && ok[:sheets].first
            (row ? rows : fail)[key] = row || ok[:message] || Text.t(:mo_phong, :khong_dung_duong_dao)
          end
        end
        ok.slice(:thickness, :top).merge(ok: true, sheets: rows.values, failed: fail, pending: pending, keys: keys)
      end
      def boot_payload(reader)
        data = reader ? scan(reader.database) : { scanned: false, layers: [], statistics: { sheets: 0 } }
        data.merge!(tools_payload)
        style_ix = ::KSU::View.load_colors
        font, edge = style_ix.values_at(:face_color, :edge_color)
        key = settings
        data.merge!(
          mau_mat_xem_truoc: [font.red, font.green, font.blue], do_dam_mat_xem_truoc: style_ix[:face_percent],
          mau_net_xem_truoc: [edge.red, edge.green, edge.blue], do_dam_net_xem_truoc: style_ix[:edge_px],
          post_processor: Post.cur, base_settings: normalized_settings(key), tag_colors: parse_rows, locked_colors: Library.default_layer_colors,
          tab_trai: setting("tab_trai", "set", key),
          an_layer_trong: setting("an_layer_trong", true, key), text: Text.gi,
          hien_duong_dao: setting("hien_duong_dao", true, key),
          ty_le_duong_dao: Util.clamp_float(setting("ty_le_duong_dao", 100.0, key), 10.0, 500.0, 100.0),
          ty_le_mui_dao: Util.clamp_float(setting("ty_le_mui_dao", 100.0, key), 10.0, 500.0, 100.0),
          thong_bao_mo: ::KSU::Settings.get("thong_bao_mo", false, "cai_dat").to_s != "false"
        )
      end
      def scan(db)
        h = layer_tags(db)
        h5 = db.layer_stats.map do |name, arr|
          { name: name, total: arr[:total], board_count: arr[:board_count],
            visible: h.fetch(name.to_s, true),
            latch: db.by_layer(name).any? { |rec| Latch.latched?(rec) },
            border: Export.border_layer?(name) }
        end
        { scanned: true, statistics: { sheets: sheet_summary(db) }, layers: h5 }
      end
      def sheet_summary(db)
        db.vectors.map do |rec|
          str = rec.root_sheet_id.to_s.strip
          if str.empty?
            str2 = rec.root_sheet_name.to_s.strip
            str2 = rec.sheet_name.to_s.strip if str2.empty?
            str = str2.sub(/(?:[-_](?:bottom|back|mat[-_ ]?sau|top|front|mat[-_ ]?truoc))\z/i, '')
          end
          [rec.nesting_id.to_s, str]
        end.uniq.count { |arr, sheet_ix| !arr.empty? || !sheet_ix.empty? }
      end
      def layer_tags(db)
        db.each_layer.to_h do |name, _ed7038d7|
          tag = tag_for_layer(name.to_s, _ed7038d7)
          [name.to_s, (tag.nil? || tag.visible?) && any_latched?(_ed7038d7)]
        end
      end
      def any_latched?(arr)
        partner = false
        arr.each do |rec|
          entities_in(rec).each do |entity|
            next unless entity.valid?
            return true unless entity.hidden?
            partner = true
          end
        end
        !partner
      end
      def tag_for_layer(layer, arr)
        tag = Canvas.layer_of(::Sketchup.active_model, layer)
        tag unless tag.nil? || tag.name == "Layer0" || arr.any? { |rec| Latch.latched?(rec) }
      end
      def all_entities(arr)
        arr.flat_map { |rec| entities_in(rec) }.select(&:valid?).uniq
      end
      def entities_in(rec)
        entity = rec.entity
        return [] unless entity && entity.valid?
        lp = entity.curve
        lp ? lp.edges : [entity]
      end
      def highlight_layer(layer, _f5d51bb8)
        return unless @reader
        _ed7038d7 = @reader.database.by_layer(layer)
        tag = tag_for_layer(layer, _ed7038d7)
        arr = tag && !_f5d51bb8 ? [] : all_entities(_ed7038d7).select { |entity| entity.hidden? == _f5d51bb8 }
        flag = tag && tag.visible? != _f5d51bb8
        return if arr.empty? && !flag
        ::KSU.start(false)
        tag.visible = _f5d51bb8 if flag
        arr.each { |entity| entity.hidden = !_f5d51bb8 }
        ::KSU.commit
        ::Sketchup.active_model.active_view.invalidate
      rescue StandardError
        ::KSU.abort_op
        ::UI.messagebox(Text.t(:giao_dien, :khong_an_hien, layer: layer))
      end
      def select_layer_entities(layer, flag16)
        return unless @reader
        model = ::Sketchup.active_model
        arr2 = @reader.database.by_layer(layer).select { |rec| rec.board_entity && rec.board_entity.valid? }
        arr = arr2.map(&:board_entity).uniq
        return if arr.empty?
        model.selection.clear unless flag16
        return if add_to_selection(model, arr).positive?
        groups = arr2.group_by { |rec| rec.board_chain.map(&:entityID) }
        best = groups.values.max_by { |items| items.map(&:board_entity).uniq.length }
        arr3 = best.first.board_chain.select(&:valid?)
        (model.active_path = arr3.empty? ? nil : arr3) rescue nil
        model.selection.clear unless flag16
        add_to_selection(model, best.map(&:board_entity).uniq)
      rescue StandardError
        ::UI.messagebox(Text.t(:giao_dien, :khong_chon_phoi, layer: layer))
      end
      def add_to_selection(model, arr)
        arr.count do |board|
          num = model.selection.length
          model.selection.add(board)
          model.selection.length > num
        rescue StandardError
          false
        end
      end
      def scan_model(dlg2, keep_existing = false)
        return send_to_page("scanDone", { ok: false }, dlg2) if nesting_busy?
        model = ::Sketchup.active_model
        model.select_tool(nil) unless keep_existing
        ::KSU::Cnc.set_run(@reader = Reader.new(model).tap(&:scan))
        Pool.last_ix
        Canvas.reset_stamp
        ok = { ok: true, data: boot_payload(@reader) }
        ok[:keep] = true if keep_existing
        send_to_page("scanDone", ok, dlg2)
      rescue StandardError => err
        send_to_page("scanDone", { ok: false }, dlg2)
        show_error(Text.t(:quet, :khong_quet_duoc), err)
      end
      def apply_edits(items)
        db = @reader.database
        idx = Canvas.sheet_index(db)
        sheets = Canvas.sheet_rows(db)
        arr = items.flat_map do |fld|
          index = idx[fld["sheet"].to_s]
          next [] unless index
          vectors = sheets[index][:vectors]
          Array(fld["v"]).filter_map { |val| vectors[val] if val.is_a?(Integer) && val >= 0 }
        end
        all_entities(arr)
      end
      def on_export_dxf(request)
        items = Array(request["items"]).select { |fld| fld.is_a?(Hash) && !Array(fld["v"]).empty? }
        return false if items.empty?
        container = apply_edits(items)
        if container.empty?
          ::UI.messagebox(Text.t(:giao_dien, :khong_sua_net))
          return false
        end
        model = ::Sketchup.active_model
        name = request["layer"]
        ::KSU.start(false)
        if name.nil?
          container.group_by(&:parent).each { |defn, entries| defn.entities.erase_entities(entries) }
        else
          tag = Canvas.layer_of(model, name.to_s) || model.layers.add(name.to_s)
          container.each { |entity| entity.layer = tag }
        end
        ::KSU.commit
        true
      rescue StandardError
        ::KSU.abort_op
        ::UI.messagebox(Text.t(:giao_dien, :khong_sua_net))
        false
      end
      def show_dxf_result(ok)
        return ::UI.openURL("file:///" + ok[:dir].tr("\\", "/")) if ok[:ok]
        lines = ok[:failed].map { |path| Text.t(:xuat, :khong_ghi_dxf, file: File.basename(path)) }
        lines = lines.first(9) << "..." if lines.length > 9
        ::UI.messagebox(lines.join("\n")) unless lines.empty?
      end
      def wire_callbacks(dlg2)
        dlg2.add_action_callback("scan_sheets") { |_943f1db3, _e9c50b97| scan_model(dlg2) }
        dlg2.add_action_callback("edit_vectors") do |_943f1db3, str|
          next if !@reader || nesting_busy?
          scan_model(dlg2, true) if on_export_dxf(parse_request(str))
        end
        dlg2.add_action_callback("undo_edit") do |_943f1db3, _e9c50b97|
          next if !@reader || nesting_busy?
          ::Sketchup.undo
          ::UI.start_timer(0, false) { scan_model(dlg2, true) }
        end
        dlg2.add_action_callback("sim_sheets") do |_943f1db3, str|
          request = parse_request(str)
          ::UI.start_timer(0.05, false) do
            ok = canvas_payload
            _925b31fd = ok[:ok] ? slot_report_now : nil
            send_to_page("simSheets", _925b31fd ? ok.merge(valid: _925b31fd[:valid]) : ok, dlg2)
            Pool.start_workers(_925b31fd[:stale] - set_excluded(request)) if _925b31fd
          rescue ScriptError, StandardError
            send_to_page("simSheets", { ok: false }, dlg2)
            ::UI.messagebox(Text.t(:mo_phong, :khong_dung))
          end
        end
        dlg2.add_action_callback("sim_keys") do |_943f1db3, str|
          _925b31fd = slot_report_now
          send_to_page("simKeys", { ok: true }.merge(_925b31fd), dlg2)
          excluded = set_excluded(parse_request(str))
          Pool.drop_jobs(excluded)
          Pool.start_workers(_925b31fd[:stale] - excluded)
        rescue StandardError
          send_to_page("simKeys", { ok: false }, dlg2)
        end
        dlg2.add_action_callback("sim_build") do |_943f1db3, str|
          ::UI.start_timer(0.02, false) do
            request = parse_request(str)
            handle_job = { key: request["key"].to_s, gen: request["gen"], rid: request["rid"] }
            keys = request["keys"]
            moves = request["moves"] != false
            ok = keys.is_a?(Array) ? Pool.enqueue(keys.map(&:to_s), moves, handle_job, dlg2) : run_one(handle_job[:key], moves)
            send_to_page("simBuilt", ok.merge(handle_job), dlg2) if ok
          rescue StandardError
            send_to_page("simBuilt", handle_job.merge(ok: false, message: Text.t(:mo_phong, :khong_dung_duong_dao)), dlg2)
          end
        end
        dlg2.add_action_callback("sim_sections") do |_943f1db3, str|
          request = parse_request(str)
          ::UI.start_timer(0, false) do
            db = active_database
            arr3 = Array(request["ids"]).map(&:to_s)
            rows = db ? ::KSU::Giacong.scan_cached(db, arr3, Util.now) : { sheets: {}, pending: [] }
            send_to_page("simSections", rows.merge(ok: !db.nil?, gen: request["gen"]), dlg2)
          rescue StandardError
            send_to_page("simSections", { ok: false, gen: request["gen"], sheets: {}, pending: [] }, dlg2)
          end
        end
        dlg2.add_action_callback("select_layer") do |_943f1db3, str|
          request = parse_request(str)
          select_layer_entities(request["layer"].to_s, request["additive"] == true)
        end
        dlg2.add_action_callback("layer_visible") do |_943f1db3, str|
          request = parse_request(str)
          highlight_layer(request["layer"].to_s, request["visible"] == true)
          send_to_page("layerShown", { layer: request["layer"].to_s }, dlg2)
        end
        dlg2.add_action_callback("add_layer") do |_943f1db3, str|
          ok = select_layer(parse_request(str)["layer"].to_s.strip)
          send_to_page("layerAdded", ok, dlg2) if ok
        end
        dlg2.add_action_callback("save_setting") do |_943f1db3, str|
          key, str2 = str.to_s.split("@", 2)
          next ::KSU::Settings.set("thong_bao_mo", ::KSU::Settings.parse_value(str2), "cai_dat") if key == "thong_bao_mo"
          next unless %w[tab_trai an_layer_trong hien_duong_dao ty_le_duong_dao ty_le_mui_dao].include?(key)
          save_settings(key => ::KSU::Settings.parse_value(str2))
        rescue StandardError => err
          show_error(Text.t(:cai_dat, :khong_luu), err)
        end
        dlg2.add_action_callback("save_cut_settings") do |_943f1db3, str|
          preview_settings(parse_request(str))
        rescue StandardError => err
          show_error(Text.t(:cai_dat, :khong_luu), err)
        end
        dlg2.add_action_callback("store_tools") do |_943f1db3, str|
          save_tools(parse_request(str))
        rescue StandardError => err
          show_error(Text.t(:dao, :khong_luu), err)
        end
        dlg2.add_action_callback("load_tools_file") do |_943f1db3, _e9c50b97|
          _d5362565 = Library.import_config
          send_to_page("toolsFileLoaded", _d5362565, dlg2) if _d5362565
        rescue StandardError => err
          show_error(Text.t(:dao, :khong_nhap), err)
        end
        dlg2.add_action_callback("save_tools_file") do |_943f1db3, str|
          Library.export_config(parse_request(str))
        rescue StandardError => err
          show_error(Text.t(:dao, :khong_xuat), err)
        end
        dlg2.add_action_callback("load_post") do |_943f1db3, _e9c50b97|
          send_to_page("postLoaded", Post.import_config, dlg2)
        end
        dlg2.add_action_callback("drop_post") do |_943f1db3, _e9c50b97|
          send_to_page("postDropped", Post.free_at, dlg2)
        end
        dlg2.add_action_callback("post_sample") do |_943f1db3, _e9c50b97|
          post = Post.validate_post(Post.cur)
          send_to_page("postSampled", { ok: true, preview: Post.preview_text(post) }, dlg2)
        rescue StandardError => err
          error = err.is_a?(Post::PostFileError) ? Text.error_text(err.message) : Text.t(:post, :khong_dung_mau)
          send_to_page("postSampled", { ok: false, message: error }, dlg2)
        end
        dlg2.add_action_callback("export_nc") do |_943f1db3, str|
          @pending_nc = nil
          next ::UI.messagebox(Text.t(:quet, :khong_du_lieu)) unless @reader && @reader.database.count.positive?
          request = parse_request(str)
          begin
            save_tools(request) if request["tools"]
          rescue StandardError => err
            next show_error(Text.t(:dao, :khong_luu), err)
          end
          preview_settings(request["base_settings"]) if request["base_settings"]
          excluded = set_excluded("ids" => request["excluded"], "off" => request["off"])
          next ::UI.messagebox(Text.t(:xuat, :khong_con_van)) if Export.included_sheets(@reader.database, excluded).empty?
          next unless Export.confirm_export(@reader.database, ::Sketchup.active_model, excluded)
          folder = ::UI.select_directory(title: Text.t(:giao_dien, :chon_thu_muc))
          next unless folder
          th_txt = [Process.pid, Time.now.to_f, rand(1_000_000_000)].join("-")
          @pending_nc = { token: th_txt, folder: folder, reader: @reader, excluded: excluded }
          send_to_page("ncFolderPicked", { token: th_txt }, dlg2)
        rescue StandardError => err
          show_error(Text.t(:xuat, :khong_xuat_duoc), err)
        end
        dlg2.add_action_callback("export_nc_go") do |_943f1db3, str|
          arr = parse_request(str)
          pending, @pending_nc = @pending_nc, nil
          next send_to_page("ncDone", { ok: false }, dlg2) unless pending && arr["token"] == pending[:token]
          request = arr["request"] || {}
          model = ::Sketchup.active_model
          begin
            save_tools(request) if request["tools"]
          rescue StandardError => err
            send_to_page("ncDone", { ok: false }, dlg2)
            next show_error(Text.t(:dao, :khong_luu), err)
          end
          preview_settings(request["base_settings"]) if request["base_settings"]
          model.select_tool(nil)
          ents = Export.freeze_model(pending[:reader].database, model)
          progress = proc { |_925b31fd| send_to_page("ncProgress", _925b31fd, dlg2) }
          ok = Export.export_file(ents.database, pending[:folder], ents.model, progress: progress, excluded: pending[:excluded])
          send_to_page("ncDone", { ok: ok[:ok] == true }, dlg2)
          Export.show_result(ok)
        rescue StandardError => err
          send_to_page("ncDone", { ok: false }, dlg2)
          show_error(Text.t(:xuat, :khong_xuat_duoc), err)
        end
        dlg2.add_action_callback("export_dxf") do |_943f1db3, str|
          @pending_dxf = nil
          next ::UI.messagebox(Text.t(:quet, :khong_du_lieu)) unless @reader && @reader.database.count.positive?
          request = parse_request(str)
          begin
            save_tools(request) if request["tools"]
          rescue StandardError => err
            next show_error(Text.t(:dao, :khong_luu), err)
          end
          preview_settings(request["base_settings"]) if request["base_settings"]
          table_off = Array(request["off"]).map(&:to_s)
          excluded = set_excluded("ids" => request["excluded"], "off" => table_off)
          partner = ::KSU::Giacong.collect_sheets(@reader.database, excluded, table_off)
          next ::UI.messagebox(Text.t(:quet, :khong_du_lieu)) unless partner
          next ::UI.messagebox(Text.t(:xuat, :khong_con_van)) if partner[1].empty?
          _e625691b = { title: Text.t(:giao_dien, :chon_thu_muc_dxf), directory: ::KSU.model_dir }.compact
          folder = ::UI.select_directory(**_e625691b)
          next unless folder
          th_txt = [Process.pid, Time.now.to_f, rand(1_000_000_000)].join("-")
          @pending_dxf = { token: th_txt, folder: folder, reader: @reader, excluded: excluded, off: table_off, found: partner }
          send_to_page("dxfFolderPicked", { token: th_txt }, dlg2)
        rescue StandardError => err
          show_error(Text.t(:xuat, :khong_xuat_duoc), err)
        end
        dlg2.add_action_callback("export_dxf_go") do |_943f1db3, str|
          arr = parse_request(str)
          pending, @pending_dxf = @pending_dxf, nil
          next send_to_page("dxfDone", { ok: false }, dlg2) unless pending && arr["token"] == pending[:token]
          progress = proc { |percent| send_to_page("dxfProgress", { percent: percent }, dlg2) }
          ok = ::KSU::Giacong.export_dxf(pending[:folder], pending[:reader].database, pending[:excluded], pending[:off],
                                                   progress: progress, found: pending[:found])
          send_to_page("dxfDone", { ok: ok[:ok] }, dlg2)
          show_dxf_result(ok)
        rescue StandardError => err
          send_to_page("dxfDone", { ok: false }, dlg2)
          show_error(Text.t(:xuat, :khong_xuat_duoc), err)
        end
      end
    end
    class Relay
      attr_reader :host
      def initialize(host)
        @host = host
        @h23 = {}
      end
      def add_action_callback(name, &blk)
        @h23[name] = blk
      end
      def execute_script(err_code)
        @host.execute_script(err_code)
      end
      def start2(name, payload)
        blk = @h23[name]
        blk.call(nil, payload) if blk
      end
    end
    class ModelWatch < ::Sketchup::AppObserver
      def onNewModel(model)
        Dialog.shutdown
      end
      alias onOpenModel onNewModel
    end
  end
end
