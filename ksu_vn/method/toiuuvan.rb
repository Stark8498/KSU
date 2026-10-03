class KSU::Toiuuvan
  include KSU::Preset
  include KSU::Nesting
  tool_key "toi_uu_van"
  def initialize
    KSU::Nest.check_license
    KSU::Intem.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (61 + 87 * i) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @nesting = nil
    @sheets = []
    @sel = []
    @btn_plan = []
    @mx = nil
    @my = nil
    @hover_del = nil
    @hover_corner = nil
    @pressed = false
    @shift = false
    @hover_edge = nil
    @down_x = @down_y = @drag_x = @drag_y = nil
    @pressing = false
    @banding = false
    @band_add = false
    @tu_dong_hau_ky = !!KSU::Settings.get("tu_dong_hau_ky", true, "toi_uu_van")
    @goc_don_van = KSU::Settings.get("goc_don_van", "trai_duoi", "toi_uu_van").to_s
    @thu_tu_don = KSU::Settings.get("thu_tu_don", "mac_dinh", "toi_uu_van").to_s
    @tach_nhom_2_mat = !!KSU::Settings.get("tach_nhom_2_mat", true, "toi_uu_van")
    @don_ve_dau_hang = !!KSU::Settings.get("don_ve_dau_hang", true, "toi_uu_van")
    @tu_dong_sua_vi_tri = true
    @tam_cach_nhau = get("tam_cach_nhau", 6.5).to_f.mm
    @tam_cach_le   = get("tam_cach_le", 3.5).to_f.mm
    edge          = @tam_cach_le.to_mm
    @tach_cach_le  = !!get("tach_cach_le", false)
    load_side_margins(edge)
    @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", edge).to_f.mm
    @cho_phep_xoay = !!KSU::Settings.get("cho_phep_xoay", false, "toi_uu_van")
    @xoay_theo_tu_khoa = !!KSU::Settings.get("xoay_theo_tu_khoa", false, "toi_uu_van")
    @danh_sach_tu_khoa = KSU::Settings.get("danh_sach_tu_khoa", "XƯƠNG, XÀ, GIẰNG, CHẶN", "toi_uu_van").to_s
    @xoay_theo_vat_lieu = !!KSU::Settings.get("xoay_theo_vat_lieu", false, "toi_uu_van")
    @danh_sach_vat_lieu = KSU::Settings.get("danh_sach_vat_lieu", "TRƠN, TRẮNG, XANH, HỒNG", "toi_uu_van").to_s
    load_overlay_settings
    @presets = get("presets", nil)
    @label_section_hidden = []
    @arr20 = []
    @arr11 = []
    @_x_bi_lan_polys = nil
    @progress = nil
    @str = nil
    @postpass_timer = nil
    @flag53 = false
    @postpass_rows = nil
    @row_ix = 0
    @src_ix = 0
    @repacked_once = nil
    @done_count = 0
    @num5 = 0
    @sheet_cache = nil
    if Sketchup.active_model.tools.active_tool == self
      @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    end
  end
  def activate
    KSU::Nest.check_license
    KSU::Intem.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    setup_fields(
      "Hậu kỳ" => {
        tu_dong_hau_ky: [:switch, "Tự động hậu kỳ"]
      },
      "Góc dồn ván" => {
        goc_don_van: [:select, "Góc dồn ván", {
          "trai_duoi" => "Trái dưới", "trai_tren" => "Trái trên",
          "phai_duoi" => "Phải dưới", "phai_tren" => "Phải trên"
        }],
        thu_tu_don: [:select, "Thứ tự dồn", {
          "mac_dinh" => "Mặc định", "theo_ten" => "Theo tên"
        }]
      },
      "Tách nhóm" => {
        tach_nhom_2_mat: [:switch, "Tách nhóm hai mặt"],
        don_ve_dau_hang: [:switch, "Dồn về đầu hàng", :tach_nhom_2_mat]
      },
      "Xoay" => {
        cho_phep_xoay: [:switch, "Cho phép xoay tấm"],
        xoay_theo_vat_lieu: [:switch, "Theo tên vật liệu", :cho_phep_xoay],
        xoay_theo_tu_khoa: [:switch, "Theo tên tấm", :cho_phep_xoay]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS,
      "Khoảng cách" => {
        tam_cach_nhau: [:mm, "Tấm cách nhau", nil, 0, 100]
      }.merge(margin_rows(nil, -> { @tach_cach_le }, "", true))
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    stop_timer
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def enableVCB?
    true
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onKeyDown(key, rep, rot, view)
    case key
    when CONSTRAIN_MODIFIER_KEY
      @shift = true
      update_hover_sheets(true, view)
      _92d864e9(view, true)
    when VK_LEFT, VK_RIGHT
      return if @sel.empty?
      _b5af8dbf = (rot & CONSTRAIN_MODIFIER_MASK) != 0
      dir = if key == VK_LEFT
          _b5af8dbf ? :first : :prev
        else
          _b5af8dbf ? :last : :next
        end
      step_selection(dir)
      view&.invalidate
    when 192 then KSU::Settings.open_settings("toi_uu_van")
    when 27, 32
      KSU.select_tool(nil)
      view&.invalidate
    end
  end
  def onKeyUp(key, rep, kflags, view)
    return unless key == CONSTRAIN_MODIFIER_KEY
    @shift = false
    update_hover_sheets(false, view)
    _92d864e9(view, false)
  end
  def onReturn(view)
    return if @sel.empty?
    start_optimize(@shift)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @mx = x
    @my = y
    @shift = (rot & MK_SHIFT) != 0
    if @banding
      @drag_x, @drag_y = x, y
      view.invalidate
      return
    end
    if @pressing
      if (x - @down_x).abs > 3 || (y - @down_y).abs > 3
        @banding = true
        @drag_x, @drag_y = x, y
        @btn_plan = []
        @hover_del = nil
        view.invalidate
      end
      return
    end
    hover_preset(x, y, view)
    return if hover_field(x, y, view)
    update_hover_sheets((rot & MK_SHIFT) != 0, view)
    update_hover_delete(view, x, y)
    _92d864e9(view, (rot & MK_SHIFT) != 0)
  end
  def update_hover_sheets(ctrl, view)
    return unless @mx && @my
    prev_key = @btn_plan
    sheet = sheet_under(view, @mx, @my)
    @btn_plan = if sheet && ctrl
                      key = KSU::Sheet.stock_key(sheet)
                      @sheets
                        .select { |rec| KSU::Sheet.stock_key(rec[:instance]) == key }
                        .map { |rec| rec[:instance] }
                    else
                      sheet ? [sheet] : []
                    end
    view.invalidate if prev_key != @btn_plan
  end
  def update_hover_delete(view, x, y)
    prev_key = @hover_del
    @hover_del = hit_delete_button(view, x, y)
    view.invalidate if prev_key != @hover_del
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    arr = handle_at(view, x, y, :corner)
    if arr
      pack_handle(arr[:sheet], arr[:idx], (rot & MK_SHIFT) != 0, :corner)
      view.invalidate
      return
    end
    edge = handle_at(view, x, y, :edge)
    if edge
      pack_handle(edge[:sheet], edge[:idx], (rot & MK_SHIFT) != 0, :edge)
      view.invalidate
      return
    end
    target = hit_delete_button(view, x, y)
    if target
      drop_sheet(target)
      view.invalidate
      return
    end
    @down_x, @down_y = x, y
    @drag_x, @drag_y = x, y
    @pressing = true
    @banding = false
    @band_add = (rot & MK_CONTROL) != 0 || (rot & MK_SHIFT) != 0
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    if @banding
      sheets = sheets_in_rect(view, @down_x, @down_y, x, y)
      @sel = @band_add ? (@sel + sheets).uniq : sheets
    elsif @pressing
      additive = (rot & MK_CONTROL) != 0
      ctrl = (rot & MK_SHIFT) != 0
      sheet = sheet_under(view, x, y)
      if sheet
        if ctrl
          select_group(sheet, additive: additive)
        else
          select_sheet(sheet, additive)
        end
      elsif !additive && !ctrl
        @sel = []
      end
    end
    @pressing = false
    @banding = false
    @down_x = @down_y = @drag_x = @drag_y = nil
    view.invalidate
  end
  def onLButtonDoubleClick(rot, x, y, view)
    additive = (rot & MK_CONTROL) != 0
    sheet = sheet_under(view, x, y)
    return unless sheet
    select_group(sheet, additive: additive)
    view.invalidate
  end
  def select_group(sheet, additive:)
    key = KSU::Sheet.stock_key(sheet)
    node = @sheets
      .select { |rec| KSU::Sheet.stock_key(rec[:instance]) == key }
      .map { |rec| rec[:instance] }
    @sel = additive ? (@sel + node).uniq : node
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false) if @arr20 && @arr20.any?
    draw_overlay(view, @nesting)
    @sel.each do |sheet|
      rec = @sheets.find { |s| s[:instance] == sheet }
      KSU::View.draw_outline(rec[:top_corners], KSU::View.main_face_color) if rec
    end
    @btn_plan.each do |sheet|
      next if @sel.include?(sheet)
      rec = @sheets.find { |s| s[:instance] == sheet }
      KSU::View.draw_outline(rec[:top_corners], KSU::View.face_color) if rec
    end
    @sel.each do |sheet|
      rec = @sheets.find { |s| s[:instance] == sheet }
      next unless rec
      KSU::View.draw_brackets(view, rec[:top_corners]) { |i| handle_color(sheet, i, @hover_corner, @pressed) }
      KSU::View._2873a79b(view, rec[:top_corners]) { |i| handle_color(sheet, i, @hover_edge, @pressed) }
    end
    draw_rect2d(view) if @banding
    _a42dd0f4(view)
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@progress}%") if @progress
    draw_mode_hint(view, "Đang hậu kỳ... #{percent}%") if @num5 && @num5 > 0
  end
  private
  def update_status
    KSU.set_status(
      "Nhấn Enter để tối ưu, giữ Shift để chỉ hậu kỳ. " \
      "Nhấn Mũi tên để đổi vị trí ván trên hàng, giữ Shift để dồn về đầu hoặc cuối hàng."
    )
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting)
    @arr20 = KSU::Nesting.overlap_polys(@nesting)
    @arr11 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
  end
  def sheet_recs
    @sheets
  end
  def reload_sheets
    sheet_list
  end
  def sheet_under(view, x, y)
    partner = @sheets.find { |rec| KSU::View._919af578(view, x, y, rec) }
    partner && partner[:instance]
  end
  def select_sheet(sheet, additive)
    if additive
      @sel.include?(sheet) ? @sel.delete(sheet) : @sel << sheet
    else
      @sel = @sel == [sheet] ? [] : [sheet]
    end
  end
  def hit_delete_button(view, x, y)
    @sheets.each do |rec|
      next unless KSU::Sheet.empty?(rec[:instance])
      return rec[:instance] if KSU::View.button_hit?(view, KSU::View.center_of(rec[:top_corners]), x, y)
    end
    nil
  end
  def _a42dd0f4(view)
    @sheets.each do |rec|
      next unless KSU::Sheet.empty?(rec[:instance])
      KSU::View.draw_warn_button(view, KSU::View.center_of(rec[:top_corners]), hover: @hover_del == rec[:instance])
    end
  end
  def _92d864e9(view, ctrl)
    return unless @mx && @my
    _8734f930 = @hover_corner
    _c3288067 = @pressed
    _522da39c = @hover_edge
    @hover_corner = handle_at(view, @mx, @my, :corner)
    @hover_edge = @hover_corner ? nil : handle_at(view, @mx, @my, :edge)
    @pressed = ctrl
    view.invalidate if @hover_corner != _8734f930 || @pressed != _c3288067 || @hover_edge != _522da39c
  end
  def handle_at(view, x, y, joint)
    @sel.each do |sheet|
      rec = @sheets.find { |s| s[:instance] == sheet }
      next unless rec
      ix = if joint == :corner
                 KSU::View.bracket_hit(view, rec[:top_corners], x, y)
               else
                 KSU::View.edge_hit(view, rec[:top_corners], x, y)
               end
      return { sheet: sheet, idx: ix } if ix
    end
    nil
  end
  def handle_color(sheet, i, hover, ctrl)
    return false unless hover
    if ctrl
      hover[:idx] == i && @sel.include?(sheet)
    else
      hover[:sheet] == sheet && hover[:idx] == i
    end
  end
  def pack_handle(sheet, ix, ctrl, mode)
    arr = (ctrl ? @sel.dup : [sheet]).select { |s| s && s.valid? }
    return if arr.empty?
    KSU.start
    arr.each do |s|
      rec = @sheets.find { |i| i[:instance] == s }
      next unless rec
      if mode == :corner
        KSU::Nesting.pack_to_corner(@nesting, s, rec, ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
      else
        KSU::Nesting.pack_to_edge(@nesting, s, rec, ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
      end
    end
    KSU.commit
    sheet_list
    KSU::View.clear_cache
  rescue StandardError
    KSU.abort_op
  end
  def step_selection(dir)
    _9535dc0b = @sel.select { |s| s && s.valid? }
    return if _9535dc0b.empty?
    arr3 = []
    arr4 = []
    _9535dc0b.each do |sheet|
      next if arr4.include?(sheet)
      arr = KSU::Sheet.row_of(sheet, @sheets)
      arr2 = arr.each_index.select { |i| _9535dc0b.include?(arr[i]) }
      next if arr2.empty?
      arr4.concat(arr2.map { |i| arr[i] })
      materials = _ea9e841c(arr.length, arr2, dir)
      arr3 << [arr, arr2, materials] if materials
    end
    return if arr3.empty?
    KSU.start
    arr6 = []
    arr5 = []
    arr3.each do |arr, arr2, materials|
      _687e1def(arr, materials)
      arr2.each do |src|
        arr6 << arr[src]
        arr5 << arr[materials.index(src)]
      end
    end
    KSU.commit
    @sel = ((_9535dc0b - arr6) + arr5).select { |s| s && s.valid? }.uniq
    sheet_list
    KSU::View.clear_cache
  rescue StandardError
    KSU.abort_op
  end
  def _ea9e841c(n, arr, dir)
    materials = (0...n).to_a
    _9535dc0b = Array.new(n, false)
    arr.each { |i| _9535dc0b[i] = true }
    flag = (dir == :prev || dir == :first) ? :prev : :next
    _4ce596b6 = dir == :first || dir == :last
    bbox = false
    loop do
      _8bb0188d = _44a5d1aa(materials, _9535dc0b, flag)
      bbox ||= _8bb0188d
      break if !_8bb0188d || !_4ce596b6
    end
    bbox ? materials : nil
  end
  def _44a5d1aa(materials, _9535dc0b, _89bad203)
    n = materials.length
    bbox = false
    if _89bad203 == :next
      (n - 2).downto(0) do |i|
        next unless _9535dc0b[i] && !_9535dc0b[i + 1]
        materials[i], materials[i + 1] = materials[i + 1], materials[i]
        _9535dc0b[i], _9535dc0b[i + 1] = _9535dc0b[i + 1], _9535dc0b[i]
        bbox = true
      end
    else
      1.upto(n - 1) do |i|
        next unless _9535dc0b[i] && !_9535dc0b[i - 1]
        materials[i], materials[i - 1] = materials[i - 1], materials[i]
        _9535dc0b[i], _9535dc0b[i - 1] = _9535dc0b[i - 1], _9535dc0b[i]
        bbox = true
      end
    end
    bbox
  end
  def _687e1def(arr, materials)
    panels = arr.map { |s| s.definition.entities.to_a.select { |ent| KSU::Nesting._88f4d2bb(ent) } }
    arr2 = arr.map { |s| KSU::Sheet.bottom_for(s, @nesting) }
    pt = arr.map { |s| s.transformation.origin }
    materials.each_with_index do |src, inst2|
      next if src == inst2
      panels[src].each { |vec| KSU::Nesting.clone_panel_into(vec, arr[inst2]) if vec && vec.valid? }
      bot = arr2[src]
      next unless bot && bot.valid?
      delta = pt[inst2] - pt[src]
      bot.transformation = Geom::Transformation.translation(delta) * bot.transformation
      bot.name = arr[inst2].name.to_s + "-bottom"
      str = KSU::Sheet.sheet_no(arr[inst2].name.to_s)
      bot.set_attribute("ABF", "sheet-id", str) if str
    end
  end
  def drop_sheet(sheet)
    return unless KSU::Sheet.remove_sheet(sheet, @nesting, @sheets)
    @sel.delete(sheet)
    @btn_plan.delete(sheet)
    @hover_del = nil
    sheet_list
    KSU::View.clear_cache
  end
  def sheets_in_rect(view, x218, _60000b16, x2, y2)
    rect = KSU::Quet.rect([x218, _60000b16], [x2, y2])
    strict = x2 >= x218
    @sheets.each_with_object([]) do |rec, out|
      pts = (0..7).map { |i| view.screen_coords(rec[:bbox].corner(i)) }
      arr3 = pts.map(&:x)
      arr2 = pts.map(&:y)
      next unless KSU::Quet.rect_hit?([arr3.min, arr2.min, arr3.max, arr2.max], rect, strict)
      out << rec[:instance]
    end
  end
  def draw_rect2d(view)
    return unless @down_x && @drag_x
    KSU::View.draw_rect2d(view, @down_x, @down_y, @drag_x, @drag_y)
    sheets_in_rect(view, @down_x, @down_y, @drag_x, @drag_y).each do |sheet|
      rec = @sheets.find { |s| s[:instance] == sheet }
      KSU::View.draw_outline(rec[:top_corners], KSU::View.face_color) if rec
    end
  end
end
class KSU::Toiuuvan
  def self._e899e740
    KSU::Reorder._f9ff0de9[0] = nil
  end
end
class KSU::Toiuuvan
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
