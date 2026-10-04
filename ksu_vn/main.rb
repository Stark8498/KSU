Sketchup.require "ksu_vn/clibs"
Sketchup.require "ksu_vn/system"
Sketchup.require "ksu_vn/utils"
Sketchup.require "ksu_vn/method"
KSU::Addon.import
module KSU
  TOL = KSU::Const::EPS unless defined?(TOL)
  def self.reload
    prev_verbose = $VERBOSE
    $VERBOSE = nil
    layers = { "utils" => 0, "system" => 1, "method" => 2 }
    str = Dir[File.join(__dir__, "{system,utils,method}/**/*.rb")]
    str.sort_by! { |f| [layers[f.sub("#{__dir__}/", "").split("/").first] || 9, f] }
    arr = []
    str.each do |f|
      begin
        load f
      rescue ScriptError, StandardError => ent
        arr << "#{f.sub("#{__dir__}/", "")}: #{ent.message}"
      end
    end
    KSU::Addon.import
    $VERBOSE = prev_verbose
    if arr.empty?
      puts "[KSU.reload] OK (#{str.size} file)"
      UI.start_timer(0) { SKETCHUP_CONSOLE.clear } if defined?(SKETCHUP_CONSOLE)
    else
      puts "[KSU.reload] #{arr.size} lỗi:\n  " + arr.join("\n  ")
    end
  end
  TOOL_LABELS = {
    xep_tam: ["Xếp tấm", "Sắp xếp lại các tấm trong kết quả nesting hiện tại."],
    chon_tam: ["Chọn tấm", "Chọn tấm nhanh từ sơ đồ cắt."],
    them_tam: ["Thêm tấm", "Thêm tấm vào sơ đồ nesting."],
    xep_hang: ["Xếp hàng", "Giới hạn độ dài hàng, chia hàng dài thành nhiều hàng ngắn."],
    danh_so_van: ["Đánh số ván", "Đánh số lại cho các ván."],
    gan_nhan: ["Gắn nhãn", "Thêm mới, chỉnh sửa và kiểm nhãn."],
    chong_bay: ["Chống bay", "Gán layer chỉ định thứ tự cắt cho các tấm để chống bay khi gia công."],
    net_cat_cuoi: ["Nét cắt cuối", "Tạo nét cắt cuối để lưu kho ván dư."],
    toi_uu_van: ["Tối ưu ván", "Tối ưu sơ đồ nesting."],
    nesting: ["Nesting", "Trải các khối 3D đã gắn nhãn thành sơ đồ cắt."],
    thong_ke: ["Thống kê", "Thống kê ván, phụ kiện và dán cạnh."],
    in_tem: ["In tem", "In tem nhãn cho các tấm trong sơ đồ cắt."],
    xuat_dxf: ["Xuất DXF", "Xuất sơ đồ nesting ra file DXF."],
    cai_dat: ["Cài đặt", "Mở bảng cài đặt."],
  }.freeze
  TOOL_DATA = {
    xep_tam: ["xeptam", -> { KSU.with_license { KSU.select_tool(Xeptam) if defined?(Xeptam) } }, Xeptam],
    chon_tam: ["chontam", -> { KSU.with_license { KSU.select_tool(KSU::Chontam) if defined?(KSU::Chontam) } }, KSU::Chontam],
    them_tam: ["themtam", -> { KSU.with_license { KSU.select_tool(KSU::Themtam) if defined?(KSU::Themtam) } }, KSU::Themtam],
    xep_hang: ["xephang", -> { KSU.with_license { KSU.select_tool(KSU::Xephang) if defined?(KSU::Xephang) } }, KSU::Xephang],
    danh_so_van: ["danhsovan", -> { KSU.with_license { KSU.select_tool(KSU::Danhsovan) if defined?(KSU::Danhsovan) } }, KSU::Danhsovan],
    gan_nhan: ["gannhan", -> { KSU.with_license { KSU.select_tool(KSU::Gannhan) if defined?(KSU::Gannhan) } }, KSU::Gannhan],
    chong_bay: ["chongbay", -> { KSU.with_license { KSU.select_tool(KSU::Chongbay) if defined?(KSU::Chongbay) } }, KSU::Chongbay],
    net_cat_cuoi: ["netcatcuoi", -> { KSU.with_license { KSU.select_tool(KSU::Netcatcuoi) if defined?(KSU::Netcatcuoi) } }, KSU::Netcatcuoi],
    toi_uu_van: ["toiuuvan", -> { KSU.with_license { KSU.select_tool(KSU::Toiuuvan) if defined?(KSU::Toiuuvan) } }, KSU::Toiuuvan],
    nesting: ["nesting", -> { KSU.with_license { KSU::Nest.open if defined?(KSU::Nest) } }, KSU::Nest::Progress],
    thong_ke: ["thongke", -> { KSU.with_license { KSU::Thongke.open if defined?(KSU::Thongke) } }],
    in_tem: ["intem", -> { KSU.with_license { KSU::Intem.open if defined?(KSU::Intem) } }],
    xuat_dxf: ["xuatdxf", -> { KSU.with_license { KSU::Xuatdxf.open if defined?(KSU::Xuatdxf) } }],
    cai_dat: ["caidat", -> { KSU.with_license { KSU::Settings.open_settings("cai_dat", nil, true) if defined?(KSU::Settings) } }],
  }.freeze
  def self.merge_before_last(normal, addon_data)
    return normal if addon_data.empty?
    arr = normal.keys.last
    head_off = normal.reject { |k, _part| k == arr }
    head_off.merge(addon_data).merge(arr => normal[arr])
  end
  def self.labels
    merge_before_last(TOOL_LABELS, KSU::Addon.labels)
  end
  def self.data
    addon_data = KSU::Addon.keys.each_with_object({}) do |k, h|
      h[k] = [nil, -> { KSU.with_license { KSU::Addon.launch(k) } }]
    end
    merge_before_last(TOOL_DATA, addon_data)
  end
  def self.with_license(&_5e0c1b8d)
    KSU::Flip.prompt_activate unless KSU::Drag.licensed?
    _5e0c1b8d.call if KSU::Drag.licensed?
  end
  def self.icon_path(icon, key = nil)
    arr = key && KSU::Addon.icon_of(key)
    return arr if arr && !arr.empty?
    File.join(__dir__, "icons", "#{icon}.svg")
  end
  def self.active?(key)
    kind2 = key.to_s
    return KSU::Addon.visible?(key) if KSU::Addon.known?(key)
    if KSU::Settings::TOOL_WINDOWS.include?(kind2)
      dlg = KSU::Settings.tool_windows[kind2]
      return !!(dlg && dlg.visible?)
    end
    return false unless KSU::Settings.dialog_open?
    return true if key == :cai_dat
    KSU::Settings.open_tab == kind2
  end
  def self.build_command(key)
    name, tip = labels[key]
    icon, launch, klass = data[key]
    cmd = UI::Command.new(name) { launch.call }
    cmd.tooltip = name
    cmd.status_bar_text = tip
    icon_of = icon_path(icon, key)
    cmd.small_icon = cmd.large_icon = icon_of
    if key == :nesting
      cmd.set_validation_proc do
        lock_open = active?(:nesting) || Sketchup.active_model.tools.active_tool.is_a?(klass)
        lock_open ? MF_CHECKED : MF_ENABLED
      end
    elsif klass
      cmd.set_validation_proc { Sketchup.active_model.tools.active_tool.is_a?(klass) ? MF_CHECKED : MF_ENABLED }
    elsif [:cai_dat, :in_tem, :xuat_dxf, :thong_ke].include?(key) || KSU::Addon.known?(key)
      cmd.set_validation_proc { active?(key) ? MF_CHECKED : MF_ENABLED }
    end
    cmd
  end
  def self.order_tools(materials)
    h = data
    keys = h.keys
    return keys unless materials.is_a?(Array)
    ordered = materials.map { |k| k.to_s.to_sym }.select { |k| h.key?(k) }.uniq
    ordered + (keys - ordered)
  end
  def self.build_ui
    bar = UI::Toolbar.new("KSU")
    menu2 = UI.menu("Extensions").add_submenu("KSU")
    flags2 = KSU::Settings.startup_flags
    materials = KSU::Settings.get_raw("thu_tu_cong_cu", nil, "cai_dat")
    keys = order_tools(materials).select { |k| flags2.fetch(k.to_s, true) }
    keys.each { |k| bar.add_item(build_command(k)) }
    arr = labels
    arr2 = data
    keys.each do |k|
      name, = arr[k]
      menu2.add_item(name) { arr2[k][1].call }
    end
    bar.show
  end
  unless file_loaded?(__FILE__)
    KSU::Settings.ensure_file
    Sketchup.platform == :platform_osx ? UI.messagebox("Plugin chỉ hỗ trợ Windows.") : build_ui
    file_loaded(__FILE__)
  end
end
