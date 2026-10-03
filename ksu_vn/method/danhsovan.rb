class KSU::Danhsovan
  include KSU::Preset
  tool_key "danh_so_van"
  def initialize
    KSU::Gannhan.check_license
    KSU::Chongbay.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.map.with_index { |b, i| b ^ (0x3D + 0x57 * i) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
    @tien_to = get("tien_to", "").to_s
    @hau_to = get("hau_to", "").to_s
    @them_so_dem = !!get("them_so_dem", true)
    @xep_tu_duoi_len = !!get("xep_tu_duoi_len", false)
    load_overlay_settings
    @presets = get("presets", nil)
    @nesting = KSU::Nesting.find_nesting(notify: false)
    @arr20 = @nesting ? KSU::Nesting.overlap_polys(@nesting) : []
    @arr11 = @nesting ? KSU::Nesting.error_points(@nesting) : []
    @_x_bi_lan_polys = nil
    if Sketchup.active_model.tools.active_tool == self
      @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    else
      @label_section_hidden ||= []
    end
    rebuild_plan
  end
  def activate
    KSU::Gannhan.check_license
    KSU::Chongbay.assert_license
    nesting = KSU::Nesting.find_nesting
    unless nesting
      KSU.select_tool(nil)
      return
    end
    @prev_perspective = KSU::View.enter_top_view(nesting)
    KSU::View.load_colors
    KSU::Preset.load_cfg
    reload
    setup_fields(
      "Số đệm" => {
        them_so_dem: [:switch, "Thêm số đệm"]
      },
      "Thứ tự" => {
        xep_tu_duoi_len: [:switch, "Xếp từ dưới lên"]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nesting, @an_nhan_tiet_dien, @label_section_hidden)
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nil, false, @label_section_hidden)
    KSU::View.restore_perspective(@prev_perspective)
    view&.invalidate
  end
  def apply_preset(s)
    apply_settings(s)
    @tien_to = s["tien_to"].to_s if s.key?("tien_to")
    @hau_to = s["hau_to"].to_s if s.key?("hau_to")
    rebuild_plan
  end
  def draw(view)
    KSU::View.draw_faces(normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    if @danh_dau_tam_bi_lan && @arr20 && @arr20.any?
      KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false)
    end
    draw_overlay(view, @nesting)
    if @plan
      @plan.each { |fld| KSU::View.draw_label(fld[:label], fld[:point], shape: :pill) }
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
      rebuild_plan
      view.invalidate
      return
    end
    click_outside(x, y, view)
  end
  def onKeyDown(key, rep, kflags, view)
    if key == 192
      KSU::Settings.open_settings("danh_so_van")
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
  def update_status
    KSU.set_status("Nhấn Enter để xác nhận đánh lại số ván.")
  end
  def rebuild_plan
    data = @nesting ? KSU::Sheet.number_plan(@nesting, @tien_to, @hau_to, @them_so_dem, @xep_tu_duoi_len) : nil
    @plan = data ? data[:plan] : nil
  end
  def apply_numbering
    return unless @nesting && @nesting.valid?
    begin
      KSU.start(false)
      KSU::Sheet.apply_numbers(@nesting, @tien_to, @hau_to, @them_so_dem, @xep_tu_duoi_len)
      KSU.commit
    rescue StandardError
      KSU.abort_op
    end
    KSU.select_tool(nil)
  end
end
class KSU::Danhsovan
  def self.online?
    return true if KSU::Nesting.warm_up_network == 0
    begin
      Socket.tcp("8.8.8.8", 53, connect_timeout: 2).close
      true
    rescue
      UI.messagebox("Không thể kết nối tới Internet!")
      false
    end
  end
end
class KSU::Danhsovan
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
