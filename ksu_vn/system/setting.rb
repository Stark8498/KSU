require "json"
require "fileutils"
module KSU::Settings
  SETTINGS_DIR = File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU")
  SETTINGS_FILE = File.join(SETTINGS_DIR, "settings.json")
  SETTINGS_BACKUP = File.join(SETTINGS_DIR, "settings_backup.json")
  STARTUP_FILE = File.join(SETTINGS_DIR, "startup.json")
  STARTUP_KEYS = %w[xep_tam chon_tam them_tam xep_hang danh_so_van net_cat_cuoi gan_nhan chong_bay toi_uu_van nesting thong_ke in_tem xuat_dxf cai_dat].freeze
  @_0dc41cf2 = nil
  SETTINGS_VERSION = 1
  def self.ensure_file
    FileUtils.mkdir_p(SETTINGS_DIR)
    if File.exist?(SETTINGS_FILE)
      txt3 = begin
        File.read(SETTINGS_FILE)
      rescue StandardError
        nil
      end
      data = parse_json(txt3) if txt3
      if !data.is_a?(Hash)
        begin
          File.rename(SETTINGS_FILE, SETTINGS_BACKUP)
        rescue StandardError
        end
        File.write(SETTINGS_FILE, JSON.generate("version" => SETTINGS_VERSION))
      elsif data["version"].to_i != SETTINGS_VERSION
        data["version"] = SETTINGS_VERSION
        begin
          File.write(SETTINGS_FILE, JSON.pretty_generate(data))
        rescue StandardError
        end
      end
    else
      File.write(SETTINGS_FILE, JSON.generate("version" => SETTINGS_VERSION))
    end
  end
  def self.parse_json(txt3)
    return {} if txt3.nil? || txt3.strip.empty?
    JSON.parse(txt3)
  rescue JSON::ParserError
    nil
  end
  def self.load
    ensure_file
    txt3 = begin
      File.read(SETTINGS_FILE)
    rescue StandardError
      nil
    end
    data = parse_json(txt3) if txt3
    if data.nil?
      data = {}
      begin
        File.write(SETTINGS_FILE, "{}")
      rescue StandardError
      end
    end
    data
  end
  def self.export_file
    path = UI.savepanel("Xuất cài đặt", SETTINGS_DIR, "settings.json")
    return false unless path
    path += ".json" unless path.downcase.end_with?(".json")
    ensure_file
    FileUtils.cp(SETTINGS_FILE, path)
    UI.messagebox("Đã xuất cài đặt thành công!")
    true
  end
  def self.import_file
    path = UI.openpanel("Nhập cài đặt", "", "JSON Files|*.json||")
    return false unless path
    begin
      data = JSON.parse(File.read(path))
      unless data.is_a?(Hash)
        UI.messagebox("File không hợp lệ!")
        return false
      end
      answer = UI.messagebox("Cài đặt hiện tại sẽ bị xóa. Bạn có chắc muốn phục hồi cài đặt?", MB_YESNO)
      return false unless answer == IDYES
      ensure_file
      data["version"] = SETTINGS_VERSION
      File.write(SETTINGS_FILE, JSON.pretty_generate(data))
      true
    rescue JSON::ParserError
      UI.messagebox("File không hợp lệ!")
      false
    end
  end
  def self.reset2
    answer = UI.messagebox("Bạn có chắc muốn đặt tất cả cài đặt về mặc định?", MB_YESNO)
    return false unless answer == IDYES
    File.delete(SETTINGS_FILE) if File.exist?(SETTINGS_FILE)
    ensure_file
    true
  end
  def self.export_online
    key = KSU::Gannhan.license_field("k")
    if key.to_s.empty?
      UI.messagebox("Chưa kích hoạt phần mềm!")
      return false
    end
    answer = UI.messagebox("Cài đặt trên máy chủ sẽ bị ghi đè bởi cài đặt hiện tại.\nBạn có chắc muốn tải cài đặt lên?", MB_YESNO)
    return false unless answer == IDYES
    ensure_file
    key_enc = URI.encode_www_form_component(key)
    url = "https://ksu.vn/wp-json/ksu/v1/settings?key=#{key_enc}"
    win_path = SETTINGS_FILE.gsub("/", "\\")
    str = File.join(ENV["TEMP"], "ksu_upload_#{Process.pid}.tmp")
    wsh = WIN32OLE.new("WScript.Shell")
    str4 = File.join(ENV["SystemRoot"], "System32", "curl.exe")
    cmd = "\"#{str4}\" -s -k --connect-timeout 15 -X POST -H \"Content-Type: application/json\" --data-binary @\"#{win_path}\" -o \"#{str}\" \"#{url}\""
    rc = wsh.Run(cmd, 0, true)
    if rc == 0 && File.exist?(str)
      answer = File.read(str)
      begin
        File.delete(str)
      rescue StandardError
      end
      resp = begin
        JSON.parse(answer)
      rescue StandardError
        nil
      end
      if resp && resp["success"]
        UI.messagebox("Đã tải cài đặt lên máy chủ thành công!")
        return true
      else
        msg2 = resp&.dig("message") || "Lỗi không xác định"
        UI.messagebox("Sao lưu thất bại: #{msg2}")
        return false
      end
    else
      begin
        File.delete(str)
      rescue StandardError
      end
      UI.messagebox("Không thể kết nối đến máy chủ!")
      return false
    end
  end
  def self.import_online
    key = KSU::Gannhan.license_field("k")
    if key.to_s.empty?
      UI.messagebox("Chưa kích hoạt phần mềm!")
      return false
    end
    answer = UI.messagebox("Cài đặt hiện tại sẽ bị ghi đè bởi cài đặt từ máy chủ.\nBạn có chắc muốn đồng bộ cài đặt?", MB_YESNO)
    return false unless answer == IDYES
    key_enc = URI.encode_www_form_component(key)
    url = "https://ksu.vn/wp-json/ksu/v1/settings?key=#{key_enc}"
    str = File.join(ENV["TEMP"], "ksu_download_#{Process.pid}.tmp")
    wsh = WIN32OLE.new("WScript.Shell")
    str4 = File.join(ENV["SystemRoot"], "System32", "curl.exe")
    cmd = "\"#{str4}\" -s -k --connect-timeout 15 -o \"#{str}\" \"#{url}\""
    rc = wsh.Run(cmd, 0, true)
    if rc == 0 && File.exist?(str)
      txt3 = File.read(str)
      begin
        File.delete(str)
      rescue StandardError
      end
      resp = begin
        JSON.parse(txt3)
      rescue StandardError
        nil
      end
      if resp && resp["success"] && resp["settings"]
        flag = resp["settings"].is_a?(String) ? resp["settings"] : JSON.pretty_generate(resp["settings"])
        resp3 = parse_json(flag)
        if resp3
          ensure_file
          File.write(SETTINGS_FILE, flag)
          return true
        else
          UI.messagebox("Dữ liệu tải về không hợp lệ!")
          return false
        end
      else
        msg2 = resp&.dig("message") || "Chưa có bản sao lưu nào trên máy chủ!"
        UI.messagebox(msg2)
        return false
      end
    else
      begin
        File.delete(str)
      rescue StandardError
      end
      UI.messagebox("Không thể kết nối đến máy chủ!")
      return false
    end
  end
  def self.reset_section(key)
    return false unless key && !key.empty?
    data = load
    return false unless data.key?(key)
    data.delete(key)
    save_all(data)
    true
  end
  def self.save_all(data)
    ensure_file
    data["version"] = SETTINGS_VERSION
    begin
      json_str = JSON.pretty_generate(data)
    rescue
      return false
    end
    tmp = SETTINGS_FILE + ".tmp"
    begin
      File.write(tmp, json_str)
    rescue
      return false
    end
    begin
      File.rename(tmp, SETTINGS_FILE)
    rescue
      begin
        File.delete(tmp)
      rescue StandardError
      end
      return false
    end
    true
  end
  def self.get_raw(key, default = nil, sec2 = nil)
    data = load
    if sec2.nil?
      data.key?(key) ? coerce(data[key], default) : default
    else
      data[sec2]&.key?(key) ? coerce(data[sec2][key], default) : default
    end
  end
  def self.get(key, default = nil, sec2 = nil)
    data = load
    begin
      if sec2.nil?
        if data.key?(key)
          coerce(data[key], default)
        else
          data[key] = default
          save_all(data)
          default
        end
      else
        data[sec2] ||= {}
        if data[sec2].key?(key)
          coerce(data[sec2][key], default)
        else
          data[sec2][key] = default
          save_all(data)
          default
        end
      end
    rescue
      default
    end
  end
  def self.coerce(value, default)
    return value if default.nil?
    begin
      case default
      when String
        value.is_a?(Array) ? value.join(",") : value.to_s
      when Integer
        value.to_i
      when Float
        value.to_f
      else
        value
      end
    rescue
      default
    end
  end
  def self.startup_flags
    JSON.parse(File.read(STARTUP_FILE))
  rescue
    {}
  end
  def self.set_startup_flag(key, value)
    data = startup_flags
    data[key] = value
    File.write(STARTUP_FILE, JSON.generate(data))
  end
  def self.set(key, value, sec2 = nil)
    data = load
    if sec2.nil?
      data[key] = value
    else
      data[sec2] ||= {}
      data[sec2][key] = value
    end
    save_all(data)
    KSU::Avail.reset3 if defined?(KSU::Avail) && key.to_s.start_with?("tam_cach_le", "tach_cach_le")
  end
  def self.parse_value(raw_str)
    return true if raw_str == "true"
    return false if raw_str == "false"
    return nil if raw_str == "null" || raw_str.nil?
    if raw_str =~ /^\-?\d+\.?\d*$/
      return raw_str.include?(".") ? raw_str.to_f : raw_str.to_i
    end
    begin
      return JSON.parse(raw_str)
    rescue JSON::ParserError
      return raw_str
    end
  end
  def self.presets_of(section)
    data = load
    data[section] ||= {}
    data[section]["presets"] ||= []
    data[section]["presets"]
  end
  def self.push_presets(dlg2, section)
    data = load
    presets2 = (data[section] && data[section]["presets"]) || []
    collapsed2 = (data[section] && data[section]["collapsed_groups"]) || {}
    str = "if (window.sendPresetsToIframe) { window.sendPresetsToIframe('#{section}', #{presets2.to_json}, #{collapsed2.to_json}); }"
    dlg2.execute_script(str)
  end
  def self.save_preset(section, pname, settings)
    data = load
    data[section] ||= {}
    data[section]["presets"] ||= []
    found = data[section]["presets"].find { |arr| arr["name"] == pname }
    if found
      found["settings"] = settings
    else
      data[section]["presets"] << {
        "name" => pname,
        "settings" => settings
      }
    end
    save_all(data)
    true
  end
  def self.delete_preset(section, pname)
    data = load
    data[section] ||= {}
    data[section]["presets"] ||= []
    data[section]["presets"].reject! { |arr| arr["name"] == pname }
    save_all(data)
    true
  end
  def self.reload_tool
    tool = Sketchup.active_model.tools.active_tool
    return unless tool.respond_to?(:reload)
    tool.reload
    KSU::View.refresh
  end
  def self.apply_preset(section, pname)
    data = load
    data[section] ||= {}
    presets2 = data[section]["presets"] || []
    preset2 = presets2.find { |arr| arr["name"] == pname }
    return nil unless preset2
    preset2["settings"].each do |key, value|
      data[section][key] = value
    end
    save_all(data)
    reload_tool
    preset2["settings"]
  end
  def self.load_all
    settings = load
    settings["cai_dat"] ||= {}
    edge = settings["cai_dat"]["tam_cach_le"] || 3.5
    %w[tam_cach_le_trai tam_cach_le_phai tam_cach_le_tren tam_cach_le_duoi tam_cach_le_hai_mat].each do |k|
      settings["cai_dat"][k] ||= edge
    end
    settings["cai_dat"].merge!(startup_flags)
    settings.to_json
  end
  def self.new_dialog(preferences_key)
    UI::HtmlDialog.new(
      {
        dialog_title: "KSU " + KSU::VERSION + " - SketchUp " + (Sketchup.version.split(".").first.to_i + 2000).to_s,
        preferences_key: preferences_key,
        scrollable: false,
        resizable: true,
        width: 640,
        height: 640,
        min_width: 640,
        min_height: 640
      }
    )
  end
  def self.select_preset_later(dlg2, pname)
    return unless pname
    name = pname.dup
    UI.start_timer(0.3, false) do
      dlg2.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{name}'); }")
    end
  end
  def self.open_dialog(section = "cai_dat", pname = nil)
    dlg2 = new_dialog("ksu_settings_dialog")
    dlg2.set_html(KSU::Caidat.build_html(section, load_all))
    @open_tab = section.to_s
    bind_callbacks(dlg2)
    select_preset_later(dlg2, pname)
    dlg2.set_on_closed {
      @_0dc41cf2 = nil
      @open_tab = nil
      KSU::Preset.load_cfg
      KSU::View.refresh
    }
    @_0dc41cf2 = dlg2
    dlg2.center
    dlg2.show
  end
  def self.reopen_with_message(dlg2, msg2, str = "cai_dat")
    dlg2.close
    KSU.select_tool(nil)
    KSU::View.refresh
    UI.messagebox(msg2)
    open_settings(str)
  end
  def self.bind_callbacks(dlg2)
    dlg2.add_action_callback("tab_changed") do |_part, str3|
      @open_tab = str3.to_s
    end
    dlg2.add_action_callback("tool_call") do |_part, payload2|
      str3, action, id = payload2.to_s.split("@", 3)
      _74f2aab3(dlg2, str3.to_s, action.to_s, id.to_s)
    end
    dlg2.add_action_callback("save_setting") do |_part, payload2|
      parts = payload2.split("@", 3)
      _081c2f3e = parts[0]
      key2 = parts[1]
      raw_str = parts[2]
      value = parse_value(raw_str)
      if _081c2f3e == "cai_dat" && (STARTUP_KEYS.include?(key2) || KSU::Addon.known?(key2))
        set_startup_flag(key2, value)
      else
        set(key2, value, _081c2f3e)
      end
      if _081c2f3e == "cai_dat"
        KSU::Preset.load_cfg
        if KSU::Preset.global_key?(key2)
          tool = Sketchup.active_model.tools.active_tool
          tool.reload_settings if tool.respond_to?(:reload_settings)
        end
        KSU::View.refresh
      else
        reload_tool
      end
    end
    dlg2.add_action_callback("export_settings") do |_part|
      KSU::Settings.export_file
    end
    dlg2.add_action_callback("import_settings") do |_part|
      reopen_with_message(dlg2, "Đã phục hồi cài đặt thành công!") if KSU::Settings.import_file
    end
    dlg2.add_action_callback("reset_settings") do |_part|
      reopen_with_message(dlg2, "Đã đặt lại cài đặt thành công!") if KSU::Settings.reset2
    end
    dlg2.add_action_callback("reset_section") do |_part, key|
      name = (KSU::TOOL_LABELS[key.to_s.to_sym] || [])[0] || key
      answer = UI.messagebox("Bạn có chắc muốn đặt cài đặt của #{name} về mặc định?", MB_YESNO)
      if answer == IDYES
        KSU::Settings.reset_section(key)
        reopen_with_message(dlg2, "Đã đặt lại cài đặt thành công!", key)
      end
    end
    dlg2.add_action_callback("load_presets") do |_part, payload2|
      push_presets(dlg2, payload2.to_s)
    end
    dlg2.add_action_callback("save_preset") do |_part, payload2|
      parts = payload2.split("@")
      _081c2f3e = parts[0]
      _538a3d28 = parts[1]
      str5 = parts[2..-1].join("@")
      settings = JSON.parse(str5)
      save_preset(_081c2f3e, _538a3d28, settings)
      push_presets(dlg2, _081c2f3e)
      reload_tool
    end
    dlg2.add_action_callback("delete_preset") do |_part, payload2|
      parts = payload2.split("@")
      _081c2f3e = parts[0]
      _538a3d28 = parts[1]
      delete_preset(_081c2f3e, _538a3d28)
      push_presets(dlg2, _081c2f3e)
      reload_tool
    end
    dlg2.add_action_callback("load_preset") do |_part, payload2|
      parts = payload2.split("@")
      _081c2f3e = parts[0]
      _538a3d28 = parts[1]
      settings = apply_preset(_081c2f3e, _538a3d28)
      if settings
        json_all = settings.to_json
        str2 = "if (window.sendSettingsToIframe) { window.sendSettingsToIframe('#{_081c2f3e}', #{json_all}); }"
        dlg2.execute_script(str2)
      end
      settings ? settings.to_json : "null"
    end
    dlg2.add_action_callback("save_presets_order") do |_part, payload2|
      parts = payload2.split("@", 2)
      _081c2f3e = parts[0]
      json_presets = parts[1]
      presets2 = JSON.parse(json_presets)
      data = load
      data[_081c2f3e] ||= {}
      data[_081c2f3e]["presets"] = presets2
      save_all(data)
      reload_tool
    end
    dlg2.add_action_callback("save_collapsed_groups") do |_part, payload2|
      parts = payload2.split("@", 2)
      _081c2f3e = parts[0]
      json_collapsed2 = parts[1]
      collapsed2 = JSON.parse(json_collapsed2)
      data = load
      data[_081c2f3e] ||= {}
      data[_081c2f3e]["collapsed_groups"] = collapsed2
      save_all(data)
    end
    dlg2.add_action_callback("pick_file") do |_part, payload2|
      parts = payload2.split("@")
      _081c2f3e = parts[0]
      sec4 = parts[1]
      _3b7dc41a = parts[2]
      path = UI.openpanel("Chọn file", "", "SketchUp Files|*.skp||")
      str4 = "iframe_#{_081c2f3e}"
      if path && File.exist?(path)
        path2 = path.gsub("\\", "/")
        set(_3b7dc41a, path2, _081c2f3e)
        str2 = "var iframe = document.getElementById('#{str4}'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'file_picked', shapeKey: '#{sec4}', pathKey: '#{_3b7dc41a}', path: '#{path2}' }, '*'); }"
        dlg2.execute_script(str2)
      else
        str2 = "var iframe = document.getElementById('#{str4}'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage({ action: 'file_picked', shapeKey: '#{sec4}', pathKey: '#{_3b7dc41a}', path: null }, '*'); }"
        dlg2.execute_script(str2)
      end
      reload_tool
    end
    dlg2.add_action_callback("export_online") do |_part|
      KSU::Settings.export_online
    end
    dlg2.add_action_callback("import_online") do |_part|
      reopen_with_message(dlg2, "Đã đồng bộ cài đặt thành công!") if KSU::Settings.import_online
    end
    dlg2.add_action_callback("view_hardware_id") do |_part|
      id2 = KSU::Mirror._4b6ac4b0
      if id2.to_s.empty?
        UI.messagebox("Không lấy được mã phần cứng của máy!")
      else
        UI.messagebox("Mã phần cứng: #{id2[0, 9]}")
      end
    end
    dlg2.add_action_callback("remove_activation") do |_part|
      if KSU::Postproc._7b2b347d
        dlg2.close
      end
    end
    dlg2.add_action_callback("check_update_version") do |_part|
      KSU::Update.check_update
    end
    dlg2.add_action_callback("restore_from_backup") do |_part|
      KSU::Update.restore_from_backup
    end
    dlg2.add_action_callback("uninstall") do |_part|
      key2 = KSU::Gannhan.license_field("k")
      KSU::Cutting.deactivate_key(key2) unless key2.to_s.empty?
      KSU::Store.set_binding("k", "")
      KSU::Store.set_binding("i", "")
      KSU::Store.set_binding("t", "")
      KSU::Update.uninstall
    end
  end
  TOOL_WINDOWS = %w[nesting in_tem xuat_dxf thong_ke].freeze
  def self.tool_windows
    @tool_windows ||= {}
  end
  def self.open_window(str, pname = nil)
    str = str.to_s
    return unless TOOL_WINDOWS.include?(str)
    dlg = tool_windows[str]
    if dlg && dlg.visible?
      if pname
        dlg.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{pname}'); }")
      else
        dlg.close
      end
      return
    end
    _a249f8a6(str, pname)
  end
  def self._a249f8a6(_a40b0a8b, pname = nil)
    dlg2 = new_dialog("ksu_tool_" + _a40b0a8b)
    dlg2.set_html(KSU::Caidat.build_html(_a40b0a8b, load_all, true))
    bind_callbacks(dlg2)
    select_preset_later(dlg2, pname)
    dlg2.set_on_closed {
      tool_windows.delete(_a40b0a8b)
      KSU::Preset.load_cfg
      KSU::View.refresh
    }
    tool_windows[_a40b0a8b] = dlg2
    dlg2.center
    dlg2.show
  end
  def self._74f2aab3(dlg2, _a40b0a8b, action, id)
    case _a40b0a8b
    when "nesting"
      KSU::Nest.handle_action(dlg2, action, id) if defined?(KSU::Nest)
    when "in_tem"
      KSU::Intem.handle_action(dlg2, action, id) if defined?(KSU::Intem)
    when "xuat_dxf"
      KSU::Xuatdxf.handle_action(dlg2, action, id) if defined?(KSU::Xuatdxf)
    when "thong_ke"
      KSU::Thongke.handle_action(dlg2, action, id) if defined?(KSU::Thongke)
    else
      KSU::Addon.dispatch(dlg2, _a40b0a8b, action, id)
    end
  end
  def self.send_to_dialog(dlg2, _a40b0a8b, action, resp)
    dlg2.execute_script("if (window.callTabFn) { window.callTabFn('#{_a40b0a8b}', '#{action}', #{resp}); }")
  end
  def self.open_tab
    @open_tab.to_s
  end
  def self.dialog_open?
    @_0dc41cf2 && @_0dc41cf2.visible?
  end
  def self._0dc41cf2
    dialog_open? ? @_0dc41cf2 : nil
  end
  def self.push_to_dialog(key, key3, value)
    return unless dialog_open?
    resp = { key3 => value }.to_json
    str = "if (window.sendSettingsToIframe) {" \
      " window.sendSettingsToIframe('#{key}', #{resp}); }"
    @_0dc41cf2.execute_script(str)
  end
  def self.open_settings(section = "cai_dat", pname = nil, switch_tab = false)
    KSU::Xeptam.check_license
    KSU::Chontam.assert_license
    return open_window(section.to_s, pname) if TOOL_WINDOWS.include?(section.to_s)
    if dialog_open?
      if pname
        @_0dc41cf2.execute_script("switchToTab('#{section}');")
        UI.start_timer(0.1, false) do
          @_0dc41cf2.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{pname}'); }")
        end
        return
      end
      if switch_tab
        if @open_tab.to_s == section.to_s
          @_0dc41cf2.close
        else
          @open_tab = section.to_s
          @_0dc41cf2.execute_script("switchToTab('#{section}', true);")
        end
        return
      end
      @_0dc41cf2.close
      return
    end
    open_dialog(section, pname)
  end
  def self._7314dc1a
    data = load
    h = (data["cai_dat"] ||= {})
    src = data["xep_tam"] || {}
    flag = false
    %w[tam_cach_nhau tam_cach_le].each do |k|
      next if h.key?(k)
      next unless src.key?(k)
      h[k] = src[k]
      flag = true
    end
    save_all(data) if flag
  end
end
begin
  KSU::Settings._7314dc1a
rescue StandardError
end
require "uri"
module KSU::Settings
  def self.data_dir
    File.join(ENV["LOCALAPPDATA"], "KSU")
  end
  def self.activate_key(serial_key)
    KSU::Const.fetch_json(KSU::Loop.license_url(serial_key, "activate") + "&instance=" + URI.encode_www_form_component(KSU::Mirror._4b6ac4b0))
  end
end
module KSU::Settings
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
