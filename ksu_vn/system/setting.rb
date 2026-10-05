require "json"
require "fileutils"
module KSU::Settings
  SETTINGS_DIR = File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU")
  SETTINGS_FILE = File.join(SETTINGS_DIR, "settings.json")
  STARTUP_KEYS = %w[xep_tam chon_tam them_tam xep_hang danh_so_van net_cat_cuoi gan_nhan chong_bay toi_uu_van nesting thong_ke in_tem gia_cong cai_dat].freeze
  @dlg3 = nil
  SETTINGS_VERSION = 1
  def self.ensure_file
    FileUtils.mkdir_p(SETTINGS_DIR)
    if File.exist?(SETTINGS_FILE)
      txt3 = File.read(SETTINGS_FILE) rescue nil
      data = parse_json(txt3) if txt3
      if !data.is_a?(Hash)
        File.rename(SETTINGS_FILE, File.join(SETTINGS_DIR, "settings_backup.json")) rescue nil
        File.write(SETTINGS_FILE, JSON.generate("version" => SETTINGS_VERSION))
      elsif data["version"].to_i != SETTINGS_VERSION
        data["version"] = SETTINGS_VERSION
        File.write(SETTINGS_FILE, JSON.pretty_generate(data)) rescue nil
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
    txt3 = File.read(SETTINGS_FILE) rescue nil
    data = parse_json(txt3) if txt3
    if data.nil?
      data = {}
      File.write(SETTINGS_FILE, "{}") rescue nil
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
    data = JSON.parse(File.read(path))
    unless data.is_a?(Hash)
      UI.messagebox("File không hợp lệ!")
      return false
    end
    return false unless UI.messagebox("Cài đặt hiện tại sẽ bị xóa. Bạn có chắc muốn phục hồi cài đặt?", MB_YESNO) == IDYES
    ensure_file
    data["version"] = SETTINGS_VERSION
    File.write(SETTINGS_FILE, JSON.pretty_generate(data))
    true
  rescue JSON::ParserError
    UI.messagebox("File không hợp lệ!")
    false
  end
  def self.reset2
    return false unless UI.messagebox("Bạn có chắc muốn đặt tất cả cài đặt về mặc định?", MB_YESNO) == IDYES
    close_dialogs
    File.delete(SETTINGS_FILE) if File.exist?(SETTINGS_FILE)
    tools = KSU::Cnc::Library.config_path
    File.delete(tools) if File.exist?(tools)
    ensure_file
    true
  end
  def self.export_online
    key = KSU::Gannhan.license_field("k")
    if key.to_s.empty?
      UI.messagebox("Chưa kích hoạt phần mềm!")
      return false
    end
    return false unless UI.messagebox("Cài đặt trên máy chủ sẽ bị ghi đè bởi cài đặt hiện tại.\nBạn có chắc muốn tải cài đặt lên?", MB_YESNO) == IDYES
    ensure_file
    url = "https://ksu.vn/wp-json/ksu/v1/settings?key=#{URI.encode_www_form_component(key)}"
    ok = curl_get("-X POST -H \"Content-Type: application/json\" --data-binary @\"#{SETTINGS_FILE.gsub("/", "\\")}\" ", url, File.join(ENV["TEMP"], "ksu_upload_#{Process.pid}.tmp"))
    unless ok
      UI.messagebox("Không thể kết nối đến máy chủ!")
      return false
    end
    resp = JSON.parse(ok) rescue nil
    if resp && resp["success"]
      UI.messagebox("Đã tải cài đặt lên máy chủ thành công!")
      return true
    end
    UI.messagebox("Sao lưu thất bại: #{resp&.dig("message") || "Lỗi không xác định"}")
    false
  end
  def self.import_online
    key = KSU::Gannhan.license_field("k")
    if key.to_s.empty?
      UI.messagebox("Chưa kích hoạt phần mềm!")
      return false
    end
    return false unless UI.messagebox("Cài đặt hiện tại sẽ bị ghi đè bởi cài đặt từ máy chủ.\nBạn có chắc muốn đồng bộ cài đặt?", MB_YESNO) == IDYES
    url = "https://ksu.vn/wp-json/ksu/v1/settings?key=#{URI.encode_www_form_component(key)}"
    txt3 = curl_get("", url, File.join(ENV["TEMP"], "ksu_download_#{Process.pid}.tmp"))
    unless txt3
      UI.messagebox("Không thể kết nối đến máy chủ!")
      return false
    end
    resp = JSON.parse(txt3) rescue nil
    unless resp && resp["success"] && resp["settings"]
      UI.messagebox(resp&.dig("message") || "Chưa có bản sao lưu nào trên máy chủ!")
      return false
    end
    flag = resp["settings"].is_a?(String) ? resp["settings"] : JSON.pretty_generate(resp["settings"])
    unless parse_json(flag)
      UI.messagebox("Dữ liệu tải về không hợp lệ!")
      return false
    end
    ensure_file
    File.write(SETTINGS_FILE, flag)
    true
  end
  def self.curl_get(topts, url, _5dd4b8e2)
    wsh = WIN32OLE.new("WScript.Shell")
    str = File.join(ENV["SystemRoot"], "System32", "curl.exe")
    rc = wsh.Run("\"#{str}\" -s -k --connect-timeout 15 #{topts}-o \"#{_5dd4b8e2}\" \"#{url}\"", 0, true)
    obj = File.read(_5dd4b8e2) if rc == 0 && File.exist?(_5dd4b8e2)
    File.delete(_5dd4b8e2) rescue nil
    obj
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
    tmp = SETTINGS_FILE + ".tmp"
    begin
      File.write(tmp, JSON.pretty_generate(data))
    rescue
      return false
    end
    begin
      File.rename(tmp, SETTINGS_FILE)
    rescue
      File.delete(tmp) rescue nil
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
  def self.coerce(num, default)
    return num if default.nil?
    case default
    when String
      num.is_a?(Array) ? num.join(",") : num.to_s
    when Integer
      num.to_i
    when Float
      num.to_f
    else
      num
    end
  rescue
    default
  end
  def self.startup_flags
    JSON.parse(File.read(File.join(SETTINGS_DIR, "startup.json")))
  rescue
    {}
  end
  def self.set_startup_flag(key, val)
    data = startup_flags
    data[key] = val
    File.write(File.join(SETTINGS_DIR, "startup.json"), JSON.generate(data))
  end
  def self.set(key, val, sec2 = nil)
    data = load
    if sec2.nil?
      data[key] = val
    else
      data[sec2] ||= {}
      data[sec2][key] = val
    end
    save_all(data)
    KSU::Avail.reset3 if defined?(KSU::Avail) && key.to_s.start_with?("tam_cach_le", "tach_cach_le")
  end
  def self.parse_value(num)
    return true if num == "true"
    return false if num == "false"
    return nil if num == "null" || num.nil?
    if num =~ /^\-?\d+\.?\d*$/
      return num.include?(".") ? num.to_f : num.to_i
    end
    JSON.parse(num)
  rescue JSON::ParserError
    num
  end
  def self.push_presets(dlg2, section)
    data = load
    presets2 = (data[section] && data[section]["presets"]) || []
    collapsed2 = (data[section] && data[section]["collapsed_groups"]) || {}
    dlg2.execute_script("if (window.sendPresetsToIframe) { window.sendPresetsToIframe('#{section}', #{presets2.to_json}, #{collapsed2.to_json}); }")
  end
  def self.save_preset(section, pname, settings)
    data = load
    data[section] ||= {}
    data[section]["presets"] ||= []
    found = data[section]["presets"].find { |arr| arr["name"] == pname }
    if found
      found["settings"] = settings
    else
      data[section]["presets"] << { "name" => pname, "settings" => settings }
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
    preset2 = (data[section]["presets"] || []).find { |arr| arr["name"] == pname }
    return nil unless preset2
    preset2["settings"].each { |key, val| data[section][key] = val }
    save_all(data)
    reload_tool
    preset2["settings"]
  end
  def self.load_all
    settings = load
    settings["cai_dat"] ||= {}
    edge = settings["cai_dat"]["tam_cach_le"] || 3.5
    %w[tam_cach_le_trai tam_cach_le_phai tam_cach_le_tren tam_cach_le_duoi tam_cach_le_hai_mat].each { |k| settings["cai_dat"][k] ||= edge }
    settings["cai_dat"].merge!(startup_flags)
    settings.to_json
  end
  def self.new_dialog(preferences_key, row_w = 640)
    dlg2 = UI::HtmlDialog.new(
      {
        dialog_title: "KSU " + KSU::VERSION + " - SketchUp " + (Sketchup.version.split(".").first.to_i + 2000).to_s,
        preferences_key: preferences_key,
        scrollable: false,
        resizable: true,
        width: row_w,
        height: 640,
        min_width: row_w,
        min_height: 640
      }
    )
    @arr33 = (@arr33 || []).select(&:visible?) << dlg2
    dlg2
  end
  def self.close_dialogs
    (@arr33 || []).each { |len2d| len2d.close if len2d.visible? }
    @arr33 = []
  end
  def self.select_preset(dlg2, pname)
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
    select_preset(dlg2, pname)
    dlg2.set_on_closed {
      @dlg3 = nil
      @open_tab = nil
      KSU::Preset.load_cfg
      KSU::View.refresh
    }
    @dlg3 = dlg2
    dlg2.center
    dlg2.show
  end
  def self.reopen_with_message(dlg2, msg2, kind2 = "cai_dat")
    dlg2.close
    KSU.select_tool(nil)
    KSU::View.refresh
    UI.messagebox(msg2)
    open_settings(kind2)
  end
  def self.bind_callbacks(dlg2)
    dlg2.add_action_callback("tab_changed") do |_item, kind2|
      if dlg2.equal?(@tool_windows)
        on_tab_shown(dlg2, kind2.to_s)
      else
        @open_tab = kind2.to_s
      end
    end
    dlg2.add_action_callback("tool_call") do |_item, payload2|
      kind2, action, payload = payload2.to_s.split("@", 3)
      on_dialog_action(dlg2, kind2.to_s, action.to_s, payload.to_s)
    end
    dlg2.add_action_callback("save_setting") do |_item, payload2|
      section2, key, _1d9db542 = payload2.split("@", 3)
      val = parse_value(_1d9db542)
      if section2 == "cai_dat" && (STARTUP_KEYS.include?(key) || KSU::Addon.known?(key))
        set_startup_flag(key, val)
      else
        set(key, val, section2)
      end
      if section2 == "cai_dat"
        KSU::Preset.load_cfg
        if KSU::Preset.global_key?(key)
          tool = Sketchup.active_model.tools.active_tool
          tool.reload_settings if tool.respond_to?(:reload_settings) && !(defined?(KSU::Nest::Progress) && tool.is_a?(KSU::Nest::Progress))
        end
        KSU::View.refresh
      else
        reload_tool
      end
    end
    dlg2.add_action_callback("export_settings") do |_item|
      KSU::Settings.export_file
    end
    dlg2.add_action_callback("import_settings") do |_item|
      reopen_with_message(dlg2, "Đã phục hồi cài đặt thành công!") if KSU::Settings.import_file
    end
    dlg2.add_action_callback("reset_settings") do |_item|
      reopen_with_message(dlg2, "Đã đặt lại cài đặt thành công!") if KSU::Settings.reset2
    end
    dlg2.add_action_callback("reset_section") do |_item, key4|
      name = (KSU::TOOL_LABELS[key4.to_s.to_sym] || [])[0] || key4
      if UI.messagebox("Bạn có chắc muốn đặt cài đặt của #{name} về mặc định?", MB_YESNO) == IDYES
        KSU::Settings.reset_section(key4)
        reopen_with_message(dlg2, "Đã đặt lại cài đặt thành công!", key4)
      end
    end
    dlg2.add_action_callback("load_presets") do |_item, payload2|
      push_presets(dlg2, payload2.to_s)
    end
    dlg2.add_action_callback("save_preset") do |_item, payload2|
      arr29 = payload2.split("@")
      section2 = arr29[0]
      settings = JSON.parse(arr29[2..-1].join("@"))
      save_preset(section2, arr29[1], settings)
      push_presets(dlg2, section2)
      reload_tool
    end
    dlg2.add_action_callback("delete_preset") do |_item, payload2|
      section2, pname2 = payload2.split("@")
      delete_preset(section2, pname2)
      push_presets(dlg2, section2)
      reload_tool
    end
    dlg2.add_action_callback("load_preset") do |_item, payload2|
      section2, pname2 = payload2.split("@")
      settings = apply_preset(section2, pname2)
      if settings
        dlg2.execute_script("if (window.sendSettingsToIframe) { window.sendSettingsToIframe('#{section2}', #{settings.to_json}); }")
      end
      settings ? settings.to_json : "null"
    end
    dlg2.add_action_callback("save_presets_order") do |_item, payload2|
      section2, json_presets = payload2.split("@", 2)
      presets2 = JSON.parse(json_presets)
      data = load
      data[section2] ||= {}
      data[section2]["presets"] = presets2
      save_all(data)
      reload_tool
    end
    dlg2.add_action_callback("save_collapsed_groups") do |_item, payload2|
      section2, json_collapsed2 = payload2.split("@", 2)
      collapsed2 = JSON.parse(json_collapsed2)
      data = load
      data[section2] ||= {}
      data[section2]["collapsed_groups"] = collapsed2
      save_all(data)
    end
    dlg2.add_action_callback("export_online") do |_item|
      KSU::Settings.export_online
    end
    dlg2.add_action_callback("import_online") do |_item|
      reopen_with_message(dlg2, "Đã đồng bộ cài đặt thành công!") if KSU::Settings.import_online
    end
    dlg2.add_action_callback("view_hardware_id") do |_item|
      id = KSU::Mirror.machine_id
      if id.to_s.empty?
        UI.messagebox("Không lấy được mã phần cứng của máy!")
      else
        UI.messagebox("Mã phần cứng: #{id[0, 9]}")
      end
    end
    dlg2.add_action_callback("remove_activation") do |_item|
      if KSU::Postproc.confirm_deactivate
        dlg2.close
      end
    end
    dlg2.add_action_callback("check_update_version") do |_item|
      KSU::Update.check_update
    end
    dlg2.add_action_callback("restore_from_backup") do |_item|
      KSU::Update.restore_from_backup
    end
    dlg2.add_action_callback("uninstall") do |_item|
      key = KSU::Gannhan.license_field("k")
      KSU::Cutting.deactivate_key(key) unless key.to_s.empty?
      KSU::Store.set_binding("k", "")
      KSU::Store.set_binding("i", "")
      KSU::Store.set_binding("t", "")
      KSU::Update.uninstall
    end
  end
  TOOL_WINDOWS = %w[nesting thong_ke in_tem gia_cong].freeze
  def self.tool_windows
    @tool_windows if @tool_windows && @tool_windows.visible?
  end
  def self.active_tab
    tool_windows ? @active_tab.to_s : ""
  end
  def self.open_window(kind2, pname = nil)
    kind2 = kind2.to_s
    return unless TOOL_WINDOWS.include?(kind2)
    dlg = tool_windows
    return push_presets2(kind2, pname) unless dlg
    return dlg.close if pname.nil? && @active_tab == kind2
    dlg.execute_script("switchToTab('#{kind2}', true);")
    select_preset(dlg, pname)
    dlg.bring_to_front
  end
  def self.mark_stale(_df1a824b = TOOL_WINDOWS - %w[nesting])
    dlg = tool_windows
    dlg.execute_script("window.markStale && markStale(#{_df1a824b.to_json});") if dlg
  end
  def self.on_tab_shown(dlg2, kind2)
    @active_tab = kind2
    assert_license
  rescue StandardError
    dlg2.close
  end
  def self.push_presets2(kind2, pname = nil)
    dlg2 = new_dialog("ksu_tools_dialog", 960)
    dlg2.set_html(KSU::Caidat.build_html(kind2, load_all, true))
    bind_callbacks(dlg2)
    select_preset(dlg2, pname)
    dlg2.set_on_closed {
      @tool_windows = nil if @tool_windows.equal?(dlg2)
      KSU::Cnc::Dialog.closed(dlg2) if defined?(KSU::Cnc::Dialog)
      KSU::Nest.cancel_labelling if defined?(KSU::Nest)
      KSU::Preset.load_cfg
      KSU::View.refresh
    }
    @tool_windows = dlg2
    @active_tab = kind2
    dlg2.center
    dlg2.show
  end
  def self.on_dialog_action(dlg2, kind2, action, payload)
    case kind2
    when "nesting"
      KSU::Nest.handle_action(dlg2, action, payload) if defined?(KSU::Nest)
    when "in_tem"
      KSU::Intem.handle_action(dlg2, action, payload) if defined?(KSU::Intem)
    when "thong_ke"
      KSU::Thongke.handle_action(dlg2, action, payload) if defined?(KSU::Thongke)
    when "gia_cong"
      KSU::Cnc::Dialog.handle_action(dlg2, action, payload) if defined?(KSU::Cnc::Dialog)
    when "cai_dat"
      if dialog_open?
        @dlg3.bring_to_front
      else
        KSU.with_license { open_settings("cai_dat") }
      end
    else
      KSU::Addon.dispatch(dlg2, kind2, action, payload)
    end
  end
  def self.send_to_dialog(dlg2, kind2, action, resp)
    dlg2.execute_script("if (window.callTabFn) { window.callTabFn('#{kind2}', '#{action}', #{resp}); }")
  end
  def self.open_tab
    @open_tab.to_s
  end
  def self.dialog_open?
    @dlg3 && @dlg3.visible?
  end
  def self.dlg3
    dialog_open? ? @dlg3 : nil
  end
  def self.push_to_dialog(key5, key, val)
    return unless dialog_open?
    @dlg3.execute_script("if (window.sendSettingsToIframe) { window.sendSettingsToIframe('#{key5}', #{{ key => val }.to_json}); }")
  end
  def self.open_settings(section = "cai_dat", pname = nil, switch_tab = false)
    KSU::Xeptam.check_license
    KSU::Chontam.assert_license
    return open_window(section.to_s, pname) if TOOL_WINDOWS.include?(section.to_s)
    if dialog_open?
      if pname
        @dlg3.execute_script("switchToTab('#{section}');")
        UI.start_timer(0.1, false) do
          @dlg3.execute_script("if (window.selectPresetByName) { window.selectPresetByName('#{pname}'); }")
        end
      elsif switch_tab && @open_tab.to_s != section.to_s
        @open_tab = section.to_s
        @dlg3.execute_script("switchToTab('#{section}', true);")
      else
        @dlg3.close
      end
      return
    end
    open_dialog(section, pname)
  end
  def self.close_dialog
    data = load
    h = (data["cai_dat"] ||= {})
    src = data["xep_tam"] || {}
    flag = false
    %w[tam_cach_nhau tam_cach_le].each do |k|
      next if h.key?(k) || !src.key?(k)
      h[k] = src[k]
      flag = true
    end
    save_all(data) if flag
  end
end
begin
  KSU::Settings.close_dialog
rescue StandardError
end
require "uri"
module KSU::Settings
  def self.data_dir
    File.join(ENV["LOCALAPPDATA"], "KSU")
  end
  def self.activate_key(serial_key)
    KSU::Const.fetch_json(KSU::Loop.license_url(serial_key, "activate") + "&instance=" + URI.encode_www_form_component(KSU::Mirror.machine_id))
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
