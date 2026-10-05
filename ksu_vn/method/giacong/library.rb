require "json"
require "digest"
require "date"
require "securerandom"
require "fileutils"
module KSU
  module Cnc
    module Library
      module_function
      SKIP_LAYER = "skip".freeze
      class ConfigError < StandardError; end
      def config_path
        File.join(::KSU::Settings::SETTINGS_DIR, "tools.json")
      end
      def read_json(path)
        h = JSON.parse(File.read(path, encoding: "bom|utf-8")) if File.file?(path)
        h if h.is_a?(Hash)
      rescue StandardError
        nil
      end
      def write_json(path, _c85b78dd)
        @config = nil
        str = "#{path}.tmp.#{Process.pid}.#{rand(1_000_000)}"
        FileUtils.mkdir_p(File.dirname(path))
        File.open(str, "wb") do |file|
          file.write(JSON.pretty_generate(_c85b78dd).encode("UTF-8"))
          file.flush
          file.fsync rescue nil
        end
        6.times do |_60708811|
          break File.rename(str, path)
        rescue Errno::EACCES, Errno::EBUSY, Errno::EPERM
          raise if _60708811 == 5
          sleep(0.04)
        end
        true
      rescue StandardError
        FileUtils.rm_f(str)
        raise
      end
      def default_cutters
        [
          [1, "Dao 6", "end_mill", 6.0, "#dd4132"], [2, "Dao 8", "end_mill", 8.0, "#0f4c81"], [3, "Dao 5", "drill_bit", 5.0, "#009473"],
          [4, "Dao 15", "drill_bit", 15.0, "#5b5ea6"], [5, "Dao 8", "drill_bit", 8.0, "#a67c52"]
        ].map do |number, name, sheet_type, diameter, color|
          {
            "id" => tool_id(number), "number" => number, "name" => name, "type" => sheet_type, "diameter" => diameter,
            "diameter_2" => 0.0, "angle" => 0.0, "pass_depth" => 20.0, "step_pct" => 50.0, "rpm" => 18_000,
            "feed" => 10_000.0, "plunge" => 5000.0, "color" => color
          }
        end
      end
      def cutters
        Marshal.load(Marshal.dump(config["cutters"]))
      end
      def tools
        Marshal.load(Marshal.dump(config["tools"]))
      end
      def default_tools
        glyph_len = normalize_cutters(default_cutters)
        [
          ["Khoan 15", 4, "drill", 13.5, "center"], ["Khoan 8", 5, "drill", 13.5, "center"], ["Khoan 5", 3, "drill", 13.5, "center"],
          ["Khoan thủng 5", 3, "drill", 17.2, "center"], ["Cam U 4.5", 2, "end_mill", 4.5, "center"],
          ["Cam U 9.3", 2, "end_mill", 9.3, "center"], ["Đánh dấu", 1, "end_mill", 0.7, "inside"], ["Cắt cuối", 1, "end_mill", 17.2, "auto"]
        ].each_with_index.map do |(name, number, sheet_type, cut_depth, cut_side), idx|
          build_tool(glyph_len[number - 1], name, sheet_type, cut_depth, cut_side).merge("id" => tool_id(idx + 1))
        end
      end
      def build_tool(arr, name, sheet_type, cut_depth, cut_side)
        normalize_tool({
          "config_name" => name, "cutter_id" => arr["id"], "type" => sheet_type, "cut_depth" => cut_depth,
          "cut_side" => cut_side, "cut_direction" => sheet_type == "drill" ? "auto" : "ccw"
        }, [arr])
      end
      def default_layer_map
        {
          "layer_map" => { "ABF_cuttingLines" => tool_id(8), "ABF_sheetBorder" => SKIP_LAYER },
          "layer_order" => %w[ABF_cuttingLines ABF_sheetBorder],
          "layer_notes" => { "ABF_cuttingLines" => "Nét cắt phôi chính mặc định.", "ABF_sheetBorder" => "Nét viền ván, không xử lý." }
        }
      end
      def default_layer_colors
        { "ABF_cuttingLines" => "#000000", "ABF_sheetBorder" => "#000000" }
      end
      def tool_id(number)
        format("KSU-%02d", number)
      end
      def renumber(arr)
        h2 = {}
        arr["cutters"].each_with_index do |arr2, idx|
          h2[arr2["id"].to_s] = arr2["id"] = tool_id(idx + 1)
        end
        h = { SKIP_LAYER => SKIP_LAYER }
        arr["tools"].each_with_index do |tool, idx|
          h[tool["id"].to_s] = tool["id"] = tool_id(idx + 1)
          tool["cutter_id"] = h2[tool["cutter_id"].to_s]
        end
        arr["layer_map"] = Hash(arr["layer_map"]).each_with_object({}) do |(str, id), arr3|
          arr3[str.to_s] = h[id.to_s] if h.key?(id.to_s)
        end
        arr
      end
      def normalize_cutters(entries)
        rows = Array(entries)
        raise ConfigError, Text.t(:dao, :chua_co_dao) if rows.empty?
        h2 = {}
        h = {}
        rows.each_with_index.map do |boundary, idx|
          raise ConfigError, Text.t(:dao, :dong_dao_sai, dong: idx + 1) unless boundary.is_a?(Hash)
          arr = normalize_cutter(boundary)
          arr["id"] = "KSU-#{SecureRandom.uuid}" if h2.key?(arr["id"])
          h2[arr["id"]] = true
          number = arr["number"].to_i
          _5707bd90 = h[number]
          raise ConfigError, Text.t(:dao, :trung_so, so: number, a: _5707bd90, b: arr["name"]) if _5707bd90
          h[number] = arr["name"]
          arr
        end.sort_by { |arr| [arr["number"].to_i, arr["name"].to_s.downcase] }
      end
      def normalize_cutter(boundary)
        number = clamp_int(boundary["number"], 999, 1)
        name = boundary["name"].to_s.strip
        name = "Dao T#{number}" if name.empty?
        diameter = Util.clamp_float(boundary["diameter"], 0.01, 500.0, 6.0)
        id = boundary["id"].to_s.strip
        {
          "id" => id.empty? ? "KSU-#{SecureRandom.uuid}" : id, "number" => number, "name" => name,
          "type" => cutter_type(boundary["type"]), "diameter" => diameter,
          "diameter_2" => Util.clamp_float(boundary["diameter_2"], 0.0, diameter, 0.0),
          "angle" => Util.clamp_float(boundary["angle"], 0.0, 180.0, 0.0),
          "pass_depth" => Util.clamp_float(boundary["pass_depth"], 0.01, 500.0, 3.0),
          "step_pct" => Util.clamp_float(boundary["step_pct"], 1.0, 100.0, 60.0),
          "rpm" => clamp_int(boundary["rpm"], 100_000, 18_000), "feed" => Util.clamp_float(boundary["feed"], 1.0, 100_000.0, 3000.0),
          "plunge" => Util.clamp_float(boundary["plunge"], 1.0, 100_000.0, 1000.0), "color" => hex_color(boundary["color"])
        }
      end
      def cutter_type(val)
        choice(val, %w[end_mill v_bit drill_bit form_tool], "end_mill")
      end
      def latch_role(str2)
        str = str2.to_s.strip.downcase
        str = { "trai" => "left", "phai" => "right", "tren" => "top", "duoi" => "bottom" }.fetch(str, str)
        str = "latch_#{str}" if %w[left right top bottom].include?(str)
        %w[latch_left latch_right latch_top latch_bottom].include?(str) ? str : ''
      end
      def hex_color(str)
        text = str.to_s.strip
        text = "##{text}" unless text.start_with?("#")
        text.match?(/\A#\h{6}\z/) ? text.downcase : "#e53935"
      end
      def normalize_tools(entries, glyph_len, flag = false)
        rows = Array(entries)
        raise ConfigError, Text.t(:dao, :chua_co_cau_hinh) if rows.empty?
        h2 = {}
        h = {}
        h3 = {}
        arr = rows.each_with_index.map do |boundary, idx|
          raise ConfigError, Text.t(:dao, :dong_cau_hinh_sai, dong: idx + 1) unless boundary.is_a?(Hash)
          str = boundary["id"].to_s.strip
          tool = normalize_tool(boundary, glyph_len)
          tool["id"] = "XNC-#{SecureRandom.uuid}" if h2.key?(tool["id"])
          h3[str] ||= tool["id"] unless str.empty?
          h2[tool["id"]] = true
          name = tool["config_name"].to_s.strip
          if h.key?(name.downcase)
            raise ConfigError, Text.t(:dao, :trung_ten, ten: name) unless flag
            suffix = 2
            suffix += 1 while h.key?("#{name} (#{suffix})".downcase)
            name = "#{name} (#{suffix})"
          end
          tool["config_name"] = tool["name"] = name
          h[name.downcase] = true
          tool
        end
        [arr, h3]
      end
      def clamp_int(val, hi, default)
        Util.clamp_float(val, 1, hi, default).round
      end
      def choice(str, arr, default)
        id_str = str.to_s.strip
        arr.include?(id_str) ? id_str : default
      end
      def normalize_tool(boundary, glyph_len)
        arr = cutter_for(boundary, glyph_len)
        arr2 = boundary["config_name"].to_s.strip
        arr2 = boundary["name"].to_s.strip if arr2.empty?
        flag2 = arr2.empty? ? Text.term(:chua_dat_ten) : arr2
        raise ConfigError, Text.t(:dao, :chua_chon_dao, ten: flag2) unless arr
        fallback = { "drill_bit" => "drill", "v_bit" => "v_bit" }.fetch(arr["type"].to_s, "end_mill")
        sheet_type = choice(boundary["type"], %w[end_mill drill v_bit rim_pocket area_clear groove], fallback)
        sheet_type = "drill" if arr["type"] == "drill_bit"
        _41d91dd9 = { "area_clear" => "pocket", "rim_pocket" => "between_edges", "groove" => "center" }[sheet_type]
        sheet_type = "end_mill" if sheet_type == "groove"
        name = arr2.empty? ? arr["name"].to_s : arr2
        latch_role_value = latch_role(boundary["operation_role"])
        cut_depth = Util.clamp_float(boundary["cut_depth"], 0.01, 500.0, 17.0)
        _5a8ed5f1 = %w[inside outside center pocket between_edges auto flip_side follow_dir]
        cut_side = _41d91dd9 || choice(boundary["cut_side"], _5a8ed5f1, "center")
        cut_direction = choice(boundary["cut_direction"], %w[auto cw ccw], "auto")
        scr = %w[auto top_left top_center top_right middle_right bottom_right bottom_center bottom_left middle_left]
        entry_corner = choice(boundary["entry_corner"], scr, "auto")
        flag5 = sheet_type == "drill" ? "single" : choice(boundary["pass_mode"], %w[single multiple count], "multiple")
        pass_count = clamp_int(boundary["pass_count"], 200, 1)
        entry_mode = choice(boundary["entry_mode"], %w[vertical ramp_line helix], "vertical")
        ramp_kind = choice(boundary["ramp_kind"], %w[smooth zigzag spiral], "smooth")
        drill_mode = choice(boundary["drill_mode"], %w[simple peck], "simple")
        flag = entry_mode == "helix" ? 0.01 : 0.0
        flag3 = entry_mode == "ramp_line" && ramp_kind != "spiral" ? 0.01 : 0.0
        ramp_len = Util.clamp_float(boundary["ramp_len_mm"], flag3, 10_000.0, 0.0)
        ramp_deg = Util.clamp_float(boundary["ramp_deg"], 0.0, 30.0, 0.0)
        flag4 = Util.clamp_float(boundary["peck_mm"], drill_mode == "peck" ? 0.01 : 0.0, 500.0, 0.0)
        helix_r = Util.clamp_float(boundary["helix_r_mm"], flag, 500.0, 0.0)
        helix_step = Util.clamp_float(boundary["helix_step_mm"], flag, 500.0, 0.0)
        ramp_corner = Util.clamp_float(boundary["ramp_corner_mm"], 0.0, 10_000.0, 0.0)
        ramp_auto_pos = Util.bool_or(boundary["ramp_auto_pos"], false)
        id = boundary["id"].to_s.strip
        {
          "id" => id.empty? ? "XNC-#{SecureRandom.uuid}" : id, "config_name" => name, "name" => name,
          "operation_role" => latch_role_value, "cutter_id" => arr["id"], "cutter_name" => arr["name"],
          "number" => arr["number"], "cutter_type" => arr["type"], "type" => sheet_type,
          "diameter" => arr["diameter"], "diameter_2" => arr["diameter_2"], "angle" => arr["angle"],
          "rpm" => arr["rpm"], "feed" => arr["feed"], "plunge" => arr["plunge"],
          "stepdown" => arr["pass_depth"], "step_pct" => arr["step_pct"],
          "draw_color" => arr["color"], "cut_depth" => cut_depth, "cut_side" => cut_side,
          "cut_direction" => cut_direction, "entry_corner" => entry_corner, "pass_mode" => flag5, "pass_count" => pass_count,
          "entry_mode" => entry_mode, "ramp_len_mm" => ramp_len, "ramp_kind" => ramp_kind, "ramp_deg" => ramp_deg,
          "drill_mode" => drill_mode, "peck_mm" => flag4, "helix_r_mm" => helix_r,
          "helix_step_mm" => helix_step, "ramp_corner_mm" => ramp_corner, "ramp_auto_pos" => ramp_auto_pos,
          "pocket_step_mm" => arr["diameter"].to_f * arr["step_pct"].to_f / 100.0
        }
      end
      def cutter_for(boundary, glyph_len)
        id = boundary["cutter_id"].to_s.strip
        str = glyph_len.find { |tool| tool["id"].to_s == id } unless id.empty?
        str || glyph_len.find { |tool| tool["number"].to_i == boundary["number"].to_i }
      end
      def config
        path = config_path
        text = File.file?(path) ? File.read(path, encoding: "bom|utf-8") : "{}" rescue nil
        stamp = [path, text]
        return @config[1] if @config && (@config[0] == stamp || (text.nil? && @config[0][0] == path))
        arr = JSON.parse(text) rescue nil
        raise ConfigError, Text.t(:dao, :file_hong, file: path) unless arr.is_a?(Hash)
        arr2 = arr["cutters"]
        glyph_len = normalize_cutters(arr2.is_a?(Array) && !arr2.empty? ? arr2 : default_cutters)
        tools = arr["tools"]
        flag = tools.is_a?(Array) && !tools.empty?
        arr = default_layer_map.merge(arr) unless flag
        _12a2c19b, = normalize_tools(flag ? tools : default_tools, glyph_len)
        renumber(
          "cutters" => glyph_len, "tools" => _12a2c19b, "layer_map" => arr["layer_map"].is_a?(Hash) ? arr["layer_map"] : {},
          "layer_order" => clean_layer_order(arr["layer_order"]), "layer_notes" => clean_layer_notes(arr["layer_notes"]),
          "layer_colors" => clean_layer_colors(arr["layer_colors"])
        ).tap { |_d5362565| @config = [stamp, _d5362565] }
      end
      def config_copy
        Marshal.load(Marshal.dump(config))
      end
      def normalize_config(arr, flag = false)
        glyph_len = normalize_cutters(arr["cutters"])
        _12a2c19b, _396b7090 = normalize_tools(arr["tools"], glyph_len, flag)
        renumber(
          "cutters" => glyph_len, "tools" => _12a2c19b, "layer_map" => remap_layer_map(arr["layer_map"], _12a2c19b, _396b7090),
          "layer_order" => clean_layer_order(arr["layer_order"]), "layer_notes" => clean_layer_notes(arr["layer_notes"]),
          "layer_colors" => clean_layer_colors(arr["layer_colors"])
        )
      end
      def remap_layer_map(layer_map, arr2, h)
        arr = arr2.map { |tool| tool["id"] }
        Hash(layer_map).each_with_object({}) do |(str, str2), arr3|
          id = h.fetch(str2.to_s, str2.to_s)
          arr3[str.to_s] = id if (arr.include?(id) || id == SKIP_LAYER) && !str.to_s.strip.empty?
        end
      end
      def clean_layer_order(entries)
        Array(entries).map { |name| name.to_s.strip }.reject(&:empty?).uniq
      end
      def clean_layer_notes(arr31)
        Hash(arr31).each_with_object({}) do |(str, text), arr|
          arr[str.to_s] = text.to_s unless str.to_s.strip.empty? || text.to_s.strip.empty?
        end
      end
      def clean_layer_colors(colors)
        Hash(colors).each_with_object({}) do |(str, color), arr|
          arr[str.to_s] = color.to_s.downcase if !str.to_s.strip.empty? && color.to_s.match?(/\A#\h{6}\z/)
        end
      end
      def save_config(_ff4b2a52, layer_map, _81b5f876 = nil, _6ae82dff = nil, notes: nil, colors: nil)
        arr = read_json(config_path) || {}
        normalize_config(
          "cutters" => _6ae82dff || cutters, "tools" => _ff4b2a52, "layer_map" => layer_map,
          "layer_order" => _81b5f876.nil? ? arr["layer_order"] : _81b5f876,
          "layer_notes" => notes.nil? ? arr["layer_notes"] : notes,
          "layer_colors" => colors.nil? ? arr["layer_colors"] : colors
        ).tap { |_d5362565| write_json(config_path, _d5362565) }
      end
      def import_config
        path = ::UI.openpanel(Text.t(:giao_dien, :nhap_cau_hinh), '', Text.t(:giao_dien, :loc_cau_hinh))
        return unless path
        arr = read_json(path) || {}
        raise ConfigError, Text.t(:dao, :file_sai) unless arr["cutters"].is_a?(Array) && arr["tools"].is_a?(Array)
        normalize_config(arr, true).tap { |_d5362565| write_json(config_path, _d5362565) }
      end
      def export_config(request)
        path = ::UI.savepanel(Text.t(:giao_dien, :xuat_cau_hinh), '', "tools.json")
        return unless path
        path += ".json" if File.extname(path).empty?
        File.binwrite(path, JSON.pretty_generate(normalize_config(request)))
      end
    end
    module Post
      class PostFileError < StandardError; end
      module_function
      FORMAT_TOKENS = {
        "X" => "X_POSITION", "Y" => "Y_POSITION", "Z" => "Z_POSITION",
        "I" => "ARC_CENTRE_I_INC_POSITION", "J" => "ARC_CENTRE_J_INC_POSITION",
        "F" => "FEED_RATE", "S" => "SPINDLE_SPEED", "N" => "LINE_NUMBER",
        "XH" => "X_HOME_POSITION", "YH" => "Y_HOME_POSITION", "ZH" => "Z_HOME_POSITION",
        "SAFEZ" => "SAFE_Z_HEIGHT", "T" => "TOOL_NUMBER",
        "TOOL_NUMBER" => "TOOL_NUMBER", "SPINDLE_SPEED" => "SPINDLE_SPEED"
      }.freeze
      WINDOWS_1258_HIGH = (
        [
          0x20AC, nil, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
          0x02C6, 0x2030, nil, 0x2039, 0x0152, nil, nil, nil,
          nil, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
          0x02DC, 0x2122, nil, 0x203A, 0x0153, nil, nil, 0x0178
        ] + (0xA0..0xFF).map do |_438de1e4|
          { 0xC3 => 0x0102, 0xCC => 0x0300, 0xD0 => 0x0110, 0xD2 => 0x0309, 0xD5 => 0x01A0, 0xDD => 0x01AF,
            0xDE => 0x0303, 0xE3 => 0x0103, 0xEC => 0x0301, 0xF0 => 0x0111, 0xF2 => 0x0323, 0xF5 => 0x01A1,
            0xFD => 0x01B0, 0xFE => 0x20AB }.fetch(_438de1e4, _438de1e4)
        end
      ).freeze
      @h29 = {}
      def cur
        stored_post || blank_post
      rescue StandardError
        blank_post
      end
      def require_post
        post = stored_post
        raise PostFileError, Text.t(:post, :chua_nap) unless post
        validate_post(post)
      rescue PostFileError
        raise
      rescue StandardError
        raise PostFileError, Text.t(:post, :bi_hong)
      end
      def import_config
        path = ::UI.openpanel(Text.t(:giao_dien, :chon_post), nil, Text.t(:giao_dien, :loc_post))
        return { "ok" => false, "cancelled" => true } unless path
        { "ok" => true, "post_processor" => store_post(validate_post(load_post_file(path)), path) }
      rescue StandardError => err
        ::UI.messagebox(err.is_a?(PostFileError) ? Text.error_text(err.message) : Text.t(:post, :khong_nap_duoc))
        { "ok" => false }
      end
      def free_at
        Dialog.save_settings("post_processor" => nil)
        { "ok" => true, "post_processor" => cur }
      rescue StandardError
        ::UI.messagebox(Text.t(:post, :khong_xoa_duoc))
        { "ok" => false }
      end
      def preview_text(post)
        tool = Library.tools.first
        vars = {
          "DATE" => Date.today.strftime("%d/%m/%Y"), "TIME" => Time.now.strftime("%H:%M:%S"),
          "TP_FILENAME" => "KSU_GIACONG_TEST", "PROJECT_NAME" => "KSU_GIACONG_TEST",
          "MATERIAL_NAME" => "MDF 17", "TOOLPATH_NAME" => "TEST_LAYER", "TOOLNAME" => tool["name"].to_s,
          "TOOL_DIAMETER" => tool["diameter"].to_f, "TOOL_DIAMETER_2" => tool["diameter_2"].to_f,
          "TOOL_ANGLE" => tool["angle"].to_f, "TOOL_PASS" => tool["stepdown"].to_f,
          "TOOL_STEPOVER_PERCENT" => tool["step_pct"].to_f,
          "T" => tool["number"].to_i, "TOOL_NUMBER" => tool["number"].to_i, "SPINDLE_SPEED" => tool["rpm"].to_i,
          "S" => tool["rpm"].to_i, "F" => tool["feed"].to_f,
          "X" => 100.0, "Y" => 100.0, "Z" => -2.0, "I" => 25.0, "J" => 0.0,
          "ZH" => post["home_z"].to_f, "XH" => post["park_x"].to_f, "YH" => post["park_y"].to_f,
          "SAFEZ" => [Dialog.normalized_settings["cao_an_toan"], 0.1].max,
          "WORK_OFFSET" => post["work_offset"].to_s.upcase.strip
        }
        %w[HEADER RAPID_MOVE FIRST_FEED_MOVE FEED_MOVE FIRST_CW_ARC_MOVE CW_ARC_MOVE
           FIRST_CCW_ARC_MOVE CCW_ARC_MOVE TOOLCHANGE NEW_SEGMENT FOOTER].flat_map do |block|
          arr = render_block(post, block, vars)
          arr.empty? ? [] : ["// ===== #{block} =====", *arr]
        end.join("\n")
      end
      def stored_post
        arr = Dialog.setting("post_processor", nil)
        return nil unless arr.is_a?(Hash) && !arr.empty?
        post = deep_copy(arr)
        boundary = post["source_path"].to_s
        if post["line_ending"].to_s.strip.empty? && !boundary.strip.empty? && File.file?(boundary)
          _eb89de03 = File.binread(boundary)
          str = post["source_sha256"].to_s.strip
          if !str.empty? && Digest::SHA256.hexdigest(_eb89de03) != str
            raise PostFileError, Text.t(:post, :da_bi_sua, file: boundary)
          end
          detect_line_ending(post, _eb89de03)
        end
        post.update("configured" => true)
      end
      def blank_post
        {
          "configured" => false, "post_name" => Text.t(:post, :chua_nap_ten), "file_extension" => '', "units" => '', "machine_type" => '',
          "tool_change_mode" => '', "max_tool_number" => 0, "blocks" => {}, "formats" => {}
        }
      end
      def validate_post(post)
        name = post["post_name"].to_s.strip
        raise PostFileError, Text.t(:post, :thieu_khoa, khoa: "POST_NAME") if name.empty?
        entity = post["file_extension"].to_s.strip
        raise PostFileError, Text.t(:post, :thieu_khoa, khoa: "FILE_EXTENSION") if entity.empty?
        str = post["units"].to_s.strip
        raise PostFileError, Text.t(:post, :thieu_khoa, khoa: "UNITS") if str.empty?
        raise PostFileError, Text.t(:post, :don_vi_mm) unless %w[mm millimeter millimeters millimetre millimetres].include?(str.downcase)
        line_ending = post["line_ending"].to_s.strip
        raise PostFileError, Text.t(:post, :xuong_dong) if line_ending.empty?
        unless %w[[10] [13] [13][10]].include?(line_ending)
          raise PostFileError, Text.t(:post, :xuong_dong_la, post: name, gia_tri: line_ending)
        end
        arr = post["blocks"]
        raise PostFileError, Text.t(:post, :khong_co_block) unless arr.is_a?(Hash) && !arr.empty?
        arr28 = %w[HEADER RAPID_MOVE FOOTER].reject { |key| Array(arr[key]).any? }
        arr28 << "FEED_MOVE/FIRST_FEED_MOVE" unless Array(arr["FEED_MOVE"]).any? || Array(arr["FIRST_FEED_MOVE"]).any?
        raise PostFileError, Text.t(:post, :thieu_block, post: name, block: arr28.join(", ")) unless arr28.empty?
        text = arr.values.flatten.map(&:to_s).join("\n")
        { "WORK_OFFSET" => "work_offset", "ZH" => "home_z", "XH" => "park_x", "YH" => "park_y" }.each do |th_txt, key|
          next unless text.match?(/\[#{th_txt}\]/i) && post[key].to_s.strip.empty?
          raise PostFileError, Text.t(:post, :thieu_khai_bao, post: name, token: th_txt, khoa: key.upcase)
        end
        FORMAT_TOKENS.each do |th_txt, _8776d6f1|
          next if %w[T TOOL_NUMBER SPINDLE_SPEED].include?(th_txt) || !text.match?(/\[#{th_txt}\]/i)
          fmt_spec = post.dig("formats", _8776d6f1)
          next if fmt_spec.is_a?(Hash) && !fmt_spec["format"].to_s.strip.empty?
          raise PostFileError, Text.t(:post, :thieu_var, post: name, token: th_txt, var: _8776d6f1)
        end
        post.update(
          "post_name" => name, "file_extension" => entity.sub(/^\./, ''), "units" => str, "line_ending" => line_ending,
          "post_id" => post["post_id"].to_s.strip, "machine_type" => post["machine_type"].to_s.strip,
          "tool_change_mode" => post["tool_change_mode"].to_s.strip,
          "allow_spindle_reverse" => flag_value(post["allow_spindle_reverse"]),
          "max_tool_number" => post["max_tool_number"].to_i
        )
      end
      def deep_copy(post)
        outer_loop = JSON.parse(JSON.generate(post))
        outer_loop["file_extension"] = outer_loop["file_extension"].to_s.sub(/^\./, '') unless outer_loop["file_extension"].nil?
        outer_loop
      end
      def store_post(post, path)
        arr = deep_copy(post).update("configured" => true)
        arr["source_path"] = path.to_s if path
        Dialog.save_settings("post_processor" => arr)
        arr
      end
      def load_post_file(path)
        raise PostFileError, Text.t(:post, :khong_thay_file, file: path) unless File.file?(path)
        id_str = File.binread(path)
        text = id_str.dup.force_encoding("UTF-8")
        post = parse_post(text.valid_encoding? ? text : decode_cp1258(id_str), File.basename(path))
        if post["line_ending"].to_s.strip.empty?
          detect_line_ending(post, id_str)
        else
          post["eol_source"] = "from_post"
        end
        post.update("source_sha256" => Digest::SHA256.hexdigest(id_str))
      end
      def decode_cp1258(id_str)
        arr = id_str.bytes.map { |_438de1e4| _438de1e4 < 0x80 ? _438de1e4 : WINDOWS_1258_HIGH[_438de1e4 - 0x80] }.compact.pack("U*")
        arr.unicode_normalize(:nfc)
      rescue StandardError, LoadError
        arr
      end
      def detect_line_ending(post, id_str)
        th_txt = { "\r\n" => "[13][10]", "\n" => "[10]", "\r" => "[13]" }.find { |_0ef686d4, _| id_str.include?(_0ef686d4) }&.last
        post.update("line_ending" => th_txt, "eol_source" => "post_bytes") if th_txt
      end
      def parse_post(text, source_name)
        text = text.gsub("\r\n", "\n").gsub("\r", "\n")
        {
          "source_name" => source_name, "post_id" => read_string(text, "POST_ID"),
          "post_name" => read_string(text, "POST_NAME") || File.basename(source_name, ".*"),
          "machine_type" => read_string(text, "MACHINE_TYPE"), "tool_change_mode" => read_string(text, "TOOL_CHANGE_MODE"),
          "allow_spindle_reverse" => read_flag(text, "ALLOW_SPINDLE_REVERSE"),
          "max_tool_number" => read_int(text, "MAX_TOOL_NUMBER", 0),
          "file_extension" => read_string(text, "FILE_EXTENSION")&.sub(/^\./, ''), "units" => read_string(text, "UNITS"),
          "work_offset" => read_string(text, "WORK_OFFSET"), "home_z" => read_float(text, "HOME_Z"),
          "park_x" => read_float(text, "PARK_X"), "park_y" => read_float(text, "PARK_Y"),
          "park_z" => read_float(text, "PARK_Z"), "line_ending" => read_string(text, "LINE_ENDING"),
          "line_number_start" => read_int(text, "LINE_NUMBER_START", 1),
          "line_number_increment" => read_int(text, "LINE_NUMBER_INCREMENT", 1),
          "line_number_maximum" => read_int(text, "LINE_NUMBER_MAXIMUM", 9_999_999),
          "formats" => parse_formats(text), "blocks" => parse_blocks(text)
        }
      end
      def read_string(text, key)
        text[/^\s*#{Regexp.escape(key)}\s*=\s*"([^"]*)"/i, 1]
      end
      def read_flag(text, key)
        flag_value(text[/^\s*#{Regexp.escape(key)}\s*=\s*"?([A-Za-z0-9_]+)"?/i, 1])
      end
      def flag_value(str)
        return str if str == true || str == false
        %w[1 true yes on enabled].include?(str.to_s.strip.downcase)
      end
      def read_float(text, key)
        text[/^\s*#{Regexp.escape(key)}\s*=\s*"?(-?\d+(?:\.\d+)?)"?/i, 1]&.to_f
      end
      def read_int(text, key, fallback)
        text[/^\s*#{Regexp.escape(key)}\s*=\s*(\d+)/i, 1]&.to_i || fallback
      end
      def parse_formats(text)
        text.scan(/^\s*VAR\s+([A-Z0-9_]+)\s*=\s*\[([^\]]+)\]/i).each_with_object({}) do |(name, obj), ok|
          arr29 = obj.split("|")
          ok[name] = { "prefix" => arr29[2].to_s, "format" => arr29[3].to_s, "raw" => obj }
        end
      end
      def parse_blocks(text)
        cur = nil
        text.each_line.with_object({}) do |axis, arr2|
          if (arr3 = axis.match(/^\s*begin\s+([A-Z0-9_]+)/i))
            cur = arr3[1].upcase
            arr2[cur] = []
            next
          end
          next unless cur
          arr = axis.match(/^\s*"(.*)"\s*$/)
          obj = arr ? arr[1] : axis.strip
          next if !arr && (obj.empty? || obj.start_with?("+") || obj.match?(/\A(?:VAR\s+)?[A-Z0-9_]+\s*=/i))
          arr2[cur] << obj.gsub("[13][10]", "\r\n").gsub("[10]", "\n").gsub("[13]", "\r")
        end
      end
      def render_block(post, block, vars, arr28 = nil)
        Array(post["blocks"][block]).map do |axis|
          head_off, arr = @h29[axis] ||= split_tokens(axis)
          out = head_off.dup
          arr.each do |th_txt, id_str, tail_pt|
            flag = vars.key?(th_txt)
            arr28 << id_str if arr28 && !flag
            out << (flag ? format_token(post, th_txt, vars[th_txt]) : id_str) << tail_pt
          end
          out
        end
      end
      def split_tokens(axis)
        head_off, *arr = axis.split(/(\[[A-Z0-9_]+\])/i, -1)
        [head_off || axis.dup, arr.each_slice(2).map { |id_str, tail_pt| [id_str[1..-2].upcase, id_str, tail_pt] }]
      end
      def format_token(post, th_txt, num2)
        return num2.to_s unless num2.is_a?(Numeric)
        @token_format_memo = [post, {}] unless @token_format_memo && @token_format_memo[0].equal?(post)
        prefix, _90b597bc, _98a1729e = @token_format_memo[1][th_txt] ||= token_format(post, th_txt)
        num = num2.to_f
        num = 0.0 if num.abs < _90b597bc
        "#{prefix}#{_98a1729e ? format(_98a1729e, num) : num.to_i.to_s}"
      end
      def token_format(post, th_txt)
        _b71f2fbe = FORMAT_TOKENS[th_txt]
        fmt_spec = _b71f2fbe && post.dig("formats", _b71f2fbe)
        prefix = fmt_spec ? fmt_spec["prefix"].to_s : (%w[X Y Z I J F S N].include?(th_txt) ? th_txt : '')
        digits = fmt_spec && fmt_spec["format"].to_s[/\.(\d+)\z/, 1]&.to_i
        digits ||= %w[X Y Z I J XH YH ZH SAFEZ].include?(th_txt) ? 4 : (th_txt == "F" ? 1 : 0)
        [prefix, 0.5 * (10.0**(-digits)), digits.zero? ? nil : "%.#{digits}f"]
      end
      def line_ending(post)
        { "[10]" => "\n", "[13]" => "\r", "[13][10]" => "\r\n" }.fetch(post["line_ending"]) do
          raise PostFileError, Text.t(:post, :xuong_dong)
        end
      end
      def numbered_lines?(post)
        post["blocks"].values.flatten.any? { |axis| axis.include?("[N]") }
      end
      def fill_tokens(axis, vars)
        axis.gsub(/\[([A-Z0-9_]+)\]/i) { |th_txt| vars.fetch(Regexp.last_match(1).upcase, th_txt) }
      end
    end
  end
end
