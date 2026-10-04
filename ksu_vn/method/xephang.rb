class KSU::Xephang
  include KSU::Preset
  tool_key "xep_hang"
  SO_VAN_MOI_HANG = 10
  def initialize
    KSU::Danhsovan.check_license
    KSU::Gannhan.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (61 + i * 87) }.pack("C*")
    k = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @gioi_han_do_dai_hang = !!get("gioi_han_do_dai_hang", false)
    @so_van_moi_hang = get("so_van_moi_hang", SO_VAN_MOI_HANG).to_i
    @hau_to_phan_manh = get("hau_to_phan_manh", "P").to_s
    @tuy_chinh_khoang_cach = !!get("tuy_chinh_khoang_cach", true)
    @giua_cac_hang = get("giua_cac_hang", 700).to_i
    @giua_cac_mat = get("giua_cac_mat", 350).to_i
    @giua_cac_phan = get("giua_cac_phan", 500).to_i
    @xep_lai_thu_tu_hang = !!get("xep_lai_thu_tu_hang", false)
    @xep_tu_duoi_len = !!get("xep_tu_duoi_len", false)
    @thu_tu_theo = get("thu_tu_theo", "ten_van").to_s
    @hien_do_day = !!get("hien_do_day", false)
    @hien_so_van = !!get("hien_so_van", false)
    @cho_phep_xuong_dong = !!get("cho_phep_xuong_dong", true)
    @xoa_nhan_mat_sau = !!get("xoa_nhan_mat_sau", true)
    @presets = get("presets", nil)
    @nesting = KSU::Nesting.find_nesting(notify: false)
    @groups = group_rows
  end
  def activate
    KSU::Danhsovan.check_license
    KSU::Gannhan.assert_license
    @nesting = KSU::Nesting.find_nesting
    unless @nesting
      KSU.select_tool(nil)
      return
    end
    @prev_perspective = KSU::View.enter_top_view(@nesting)
    KSU::View.load_colors
    KSU::Preset.load_cfg
    reload
    setup_fields(
      "Chia hàng" => {
        gioi_han_do_dai_hang: [:switch, "Giới hạn độ dài hàng"],
        so_van_moi_hang: [nil, "Số ván mỗi hàng", "gioi_han_do_dai_hang", 1, 100]
      },
      "Khoảng cách" => {
        tuy_chinh_khoang_cach: [:switch, "Tùy chỉnh khoảng cách"],
        giua_cac_hang: [nil, "Giữa các hàng", "tuy_chinh_khoang_cach", 0, 2000],
        giua_cac_mat: [nil, "Giữa các mặt", "tuy_chinh_khoang_cach", 0, 2000],
        giua_cac_phan: [nil, "Giữa các phần", "tuy_chinh_khoang_cach", 0, 2000]
      },
      "Thứ tự hàng" => {
        xep_lai_thu_tu_hang: [:switch, "Xếp lại thứ tự hàng"],
        xep_tu_duoi_len: [:switch, "Xếp từ dưới lên", "xep_lai_thu_tu_hang"],
        thu_tu_theo: [:select, "Thứ tự theo", { "ten_van" => "Tên ván", "do_day" => "Độ dày" }, "xep_lai_thu_tu_hang"]
      },
      "Nhãn hàng" => {
        hien_do_day: [:switch, "Hiển thị độ dày ván"],
        hien_so_van: [:switch, "Hiển thị số lượng ván"],
        cho_phep_xuong_dong: [:switch, "Cho phép xuống dòng", -> { @hien_do_day || @hien_so_van }],
        xoa_nhan_mat_sau: [:switch, "Xóa nhãn mặt sau"]
      }
    )
    load_presets(@presets)
    restore_selected_preset
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    KSU::View.restore_perspective(@prev_perspective)
    view&.invalidate
  end
  def resume(view)
    reload
    update_status
    view&.invalidate
  end
  def apply_preset(s)
    apply_settings(s)
    @hau_to_phan_manh = s["hau_to_phan_manh"].to_s if s.key?("hau_to_phan_manh")
    @thu_tu_theo = s["thu_tu_theo"].to_s if s.key?("thu_tu_theo")
    @hien_do_day = !!s["hien_do_day"] if s.key?("hien_do_day")
    @hien_so_van = !!s["hien_so_van"] if s.key?("hien_so_van")
    @cho_phep_xuong_dong = !!s["cho_phep_xuong_dong"] if s.key?("cho_phep_xuong_dong")
    @xoa_nhan_mat_sau = !!s["xoa_nhan_mat_sau"] if s.key?("xoa_nhan_mat_sau")
    redraw_rows
    @groups = group_rows
  end
  def draw(view)
    if @groups && @groups.any?
      color = KSU::View.face_color
      @groups.each { |g| KSU::View.draw_poly(g[:corners], color: color, line: false) }
      @groups.each { |g| KSU::View.draw_label(g[:label], g[:center], shape: :pill, pad_x: 10) }
    end
    draw_presets(view)
    draw_fields(view)
  end
  def onMouseMove(kflags, x, y, view)
    hover_preset(x, y, view)
    hover_field(x, y, view)
  end
  def onLButtonDown(kflags, x, y, view)
    if click_field(x, y, view)
      @groups = group_rows
      view.invalidate
      return
    end
    click_outside(x, y, view)
  end
  def commit_field_input(view)
    answer = super
    @groups = group_rows
    view.invalidate
    answer
  end
  def onKeyDown(key, rep, kflags, view)
    if key == 192
      KSU::Settings.open_settings("xep_hang")
      return
    end
    if key == 13
      apply_numbering
      return
    end
    return unless key == 27
    KSU.select_tool(nil)
    true
  end
  private
  def group_rows
    groups = []
    return groups unless @nesting && @nesting.valid?
    return groups unless @gioi_han_do_dai_hang
    per_row = @so_van_moi_hang.to_i
    return groups unless per_row > 0
    arr, = KSU::Sheet.sheet_maps(@nesting)
    return groups if arr.empty?
    arr5 = arr.keys.sort
    suffix = KSU::Sheet.part_suffix
    part_re2 = KSU::Sheet.part_re
    h = {}
    materials = []
    arr5.each do |id|
      normal = KSU::Sheet.base_type(arr[id], part_re2)
      unless h[normal]
        h[normal] = []
        materials << normal
      end
      h[normal] << id
    end
    materials.each do |normal|
      arr2 = h[normal].each_slice(per_row).to_a
      next if arr2.size <= 1
      arr2.each_with_index do |arr4, ri|
        name = "#{normal}-#{suffix}#{ri + 1}"
        segments = {}
        arr3 = []
        arr4.each do |id|
          str = arr[id].get_attribute("ABF", "sheet-type").to_s
          unless segments[str]
            segments[str] = []
            arr3 << str
          end
          segments[str] << id
        end
        arr3.each do |str|
          box = Geom::BoundingBox.new
          segments[str].each do |id|
            bbox = KSU::Sheet.world_bbox(arr[id], @nesting)
            box.add(bbox) if bbox
          end
          next if box.empty?
          top4 = KSU::View.bbox_top(box)
          groups << { corners: KSU::View.expand_corners(top4), label: name, center: KSU::View.center_of(top4) }
        end
      end
    end
    groups
  end
  def redraw_rows
    set("gioi_han_do_dai_hang", @gioi_han_do_dai_hang)
    set("so_van_moi_hang", @so_van_moi_hang)
    set("hau_to_phan_manh", @hau_to_phan_manh)
    set("tuy_chinh_khoang_cach", @tuy_chinh_khoang_cach)
    set("giua_cac_hang", @giua_cac_hang)
    set("giua_cac_mat", @giua_cac_mat)
    set("giua_cac_phan", @giua_cac_phan)
    set("xep_lai_thu_tu_hang", @xep_lai_thu_tu_hang)
    set("xep_tu_duoi_len", @xep_tu_duoi_len)
    set("thu_tu_theo", @thu_tu_theo)
    set("hien_do_day", @hien_do_day)
    set("hien_so_van", @hien_so_van)
    set("cho_phep_xuong_dong", @cho_phep_xuong_dong)
    set("xoa_nhan_mat_sau", @xoa_nhan_mat_sau)
  end
  def update_status
    KSU.set_status("Nhấn Enter để xác nhận xếp lại hàng.")
  end
  def apply_numbering
    return unless @nesting && @nesting.valid?
    begin
      KSU.start(false)
      if @gioi_han_do_dai_hang
        KSU::Sheet.layout_rows(@nesting, @so_van_moi_hang.to_i)
      else
        KSU::Sheet.renumber_all(@nesting)
      end
      if @xep_lai_thu_tu_hang
        KSU::Sheet.sort_sheets(@nesting, by: @thu_tu_theo, bottom_up: @xep_tu_duoi_len)
      end
      KSU.commit
    rescue StandardError
      KSU.abort_op
    end
    KSU.select_tool(nil)
  end
end
class KSU::Xephang
  def self.normalize_id(id)
    return nil unless id
    id.to_s.strip.gsub(/\s+/, " ")
  end
end
class KSU::Xephang
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
