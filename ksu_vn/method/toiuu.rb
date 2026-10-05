class KSU::Toiuu
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
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i3| b ^ (61 + 87 * i3) }.pack("C*")
    arr = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    return unless arr =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @nesting = nil
    @sheets = []
    @sel = []
    @btn_plan = []
    @mx = @my = nil
    @hover_del = nil
    @hover_corner = nil
    @pressed = false
    @shift = false
    @hover_edge = nil
    @down_x = @down_y = @drag_x = @drag_y = nil
    @pressing = false
    @banding = false
    @band_add = false
    @tu_dong_hau_ky = !!get("tu_dong_hau_ky", true)
    @goc_don_van = get("goc_don_van", "trai_duoi")
    @thu_tu_don = get("thu_tu_don", "mac_dinh")
    @tach_nhom_2_mat = !!get("tach_nhom_2_mat", true)
    @don_ve_dau_hang = !!get("don_ve_dau_hang", true)
    @tam_cach_nhau = get("tam_cach_nhau", 6.5).mm
    @tam_cach_le   = get("tam_cach_le", 3.5).mm
    edge          = @tam_cach_le.to_mm
    @tach_cach_le  = !!get("tach_cach_le", false)
    load_side_margins(edge)
    @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", edge).mm
    @cho_phep_xoay = !!get("cho_phep_xoay", false)
    @xoay_theo_tu_khoa = !!get("xoay_theo_tu_khoa", false)
    @danh_sach_tu_khoa = get("danh_sach_tu_khoa", "XƯƠNG, XÀ, GIẰNG, CHẶN")
    @xoay_theo_vat_lieu = !!get("xoay_theo_vat_lieu", false)
    @danh_sach_vat_lieu = get("danh_sach_vat_lieu", "TRƠN, TRẮNG, XANH, HỒNG")
    load_overlay_settings
    @presets = get("presets", nil)
    @arr6 = []
    @arr38 = []
    @_x_bi_lan_polys = nil
    @progress = @str = nil
    @postpass_timer = nil
    @flag7 = false
    @postpass_rows = nil
    @row_ix = 0
    @src_ix = 0
    @flag47 = nil
    @done_count = 0
    @num4 = 0
    @sheet_cache = nil
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
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    stop_timer
    save_selected_preset
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
      track_handles(view, true)
    when VK_LEFT, VK_RIGHT
      return if @sel.empty?
      jump = (rot & CONSTRAIN_MODIFIER_MASK) != 0
      step_selection(key == VK_LEFT ? (jump ? :first : :prev) : (jump ? :last : :next))
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
    track_handles(view, false)
  end
  def onReturn(view)
    return if @sel.empty?
    start_optimize(@shift)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @mx, @my = x, y
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
    track_handles(view, (rot & MK_SHIFT) != 0)
  end
  def update_hover_sheets(ctrl, view)
    return unless @mx && @my
    prev_key = @btn_plan
    sheet = sheet_under(view, @mx, @my)
    @btn_plan = sheet && ctrl ? same_stock_sheets(sheet) : (sheet ? [sheet] : [])
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
    %i[corner edge].each do |mode|
      hit = handle_at(view, x, y, mode)
      next unless hit
      pack_handle(hit[:sheet], hit[:idx], (rot & MK_SHIFT) != 0, mode)
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
        ctrl ? select_group(sheet, additive: additive) : select_sheet(sheet, additive)
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
    _124c7bd3 = same_stock_sheets(sheet)
    @sel = additive ? (@sel + _124c7bd3).uniq : _124c7bd3
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr6, color: KSU::View.warn_color, line: false) if @arr6 && @arr6.any?
    draw_overlay(view, @nesting)
    @sel.each do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      KSU::View.draw_outline(rec[:top_corners], KSU::View.main_face_color) if rec
    end
    @btn_plan.each do |sheet|
      next if @sel.include?(sheet)
      rec = KSU::Sheet.record_for(@sheets, sheet)
      KSU::View.draw_outline(rec[:top_corners], KSU::View.face_color) if rec
    end
    @sel.each do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      next unless rec
      KSU::View.draw_brackets(view, rec[:top_corners]) { |i| handle_color(sheet, i, @hover_corner, @pressed) }
      KSU::View.draw_corner_handles(view, rec[:top_corners]) { |i| handle_color(sheet, i, @hover_edge, @pressed) }
    end
    draw_rect2d(view) if @banding
    draw_empty_marks(view)
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@progress}%") if @progress
    draw_mode_hint(view, "Đang hậu kỳ... #{percent}%") if @num4 && @num4 > 0
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
    @arr6 = KSU::Nesting.overlap_polys(@nesting)
    @arr38 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
  end
  def sheet_recs
    @sheets
  end
  alias reload_sheets sheet_list
  def sheet_under(view, x, y)
    partner = @sheets.find { |rec| KSU::View.hit_sheet_top?(view, x, y, rec) }
    partner && partner[:instance]
  end
  def same_stock_sheets(sheet)
    key = KSU::Sheet.stock_key(sheet)
    @sheets.select { |rec| KSU::Sheet.stock_key(rec[:instance]) == key }.map { |rec| rec[:instance] }
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
  def draw_empty_marks(view)
    @sheets.each do |rec|
      next unless KSU::Sheet.empty?(rec[:instance])
      KSU::View.draw_warn_button(view, KSU::View.center_of(rec[:top_corners]), hover: @hover_del == rec[:instance])
    end
  end
  def track_handles(view, ctrl)
    return unless @mx && @my
    p_corner, p_pressed, p_edge = @hover_corner, @pressed, @hover_edge
    @hover_corner = handle_at(view, @mx, @my, :corner)
    @hover_edge = @hover_corner ? nil : handle_at(view, @mx, @my, :edge)
    @pressed = ctrl
    view.invalidate if @hover_corner != p_corner || @pressed != p_pressed || @hover_edge != p_edge
  end
  def handle_at(view, x, y, kind)
    @sel.each do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      next unless rec
      ix = kind == :corner ? KSU::View.bracket_hit(view, rec[:top_corners], x, y) : KSU::View.edge_hit(view, rec[:top_corners], x, y)
      return { sheet: sheet, idx: ix } if ix
    end
    nil
  end
  def handle_color(sheet, i, hover, ctrl)
    return false unless hover
    ctrl ? (hover[:idx] == i && @sel.include?(sheet)) : (hover[:sheet] == sheet && hover[:idx] == i)
  end
  def pack_handle(sheet, ix, ctrl, mode)
    arr = (ctrl ? @sel.dup : [sheet]).select { |s| s && s.valid? }
    return if arr.empty?
    KSU.start
    arr.each do |s|
      rec = KSU::Sheet.record_for(@sheets, s)
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
    arr3 = @sel.select { |s| s && s.valid? }
    return if arr3.empty?
    arr4 = []
    arr5 = []
    arr3.each do |sheet|
      next if arr5.include?(sheet)
      arr = KSU::Sheet.row_of(sheet, @sheets)
      arr2 = arr.each_index.select { |i| arr3.include?(arr[i]) }
      next if arr2.empty?
      arr5.concat(arr2.map { |i| arr[i] })
      materials = reorder_cycle(arr.length, arr2, dir)
      arr4 << [arr, arr2, materials] if materials
    end
    return if arr4.empty?
    KSU.start
    _0cbf65d2, arr6 = [], []
    arr4.each do |arr, arr2, materials|
      apply_order(arr, materials)
      arr2.each do |src|
        _0cbf65d2 << arr[src]
        arr6 << arr[materials.index(src)]
      end
    end
    KSU.commit
    @sel = ((arr3 - _0cbf65d2) + arr6).select { |s| s && s.valid? }.uniq
    sheet_list
    KSU::View.clear_cache
  rescue StandardError
    KSU.abort_op
  end
  def reorder_cycle(n, arr, dir)
    materials = (0...n).to_a
    flag2 = Array.new(n) { |i| arr.include?(i) }
    flag = (dir == :prev || dir == :first) ? :prev : :next
    repeat = dir == :first || dir == :last
    bbox = false
    loop do
      ok2 = step_order(materials, flag2, flag)
      bbox ||= ok2
      break if !ok2 || !repeat
    end
    bbox ? materials : nil
  end
  def step_order(materials, arr, _5d951b22)
    n = materials.length
    bbox = false
    len2d = _5d951b22 == :next ? 1 : -1
    (_5d951b22 == :next ? (n - 2).downto(0) : 1.upto(n - 1)).each do |i|
      ix = i + len2d
      next unless arr[i] && !arr[ix]
      materials[i], materials[ix] = materials[ix], materials[i]
      arr[i], arr[ix] = arr[ix], arr[i]
      bbox = true
    end
    bbox
  end
  def apply_order(arr, materials)
    panels = arr.map { |s| s.definition.entities.to_a.select { |e| KSU::Nesting.nest_panel?(e) } }
    arr2 = arr.map { |s| KSU::Sheet.bottom_for(s, @nesting) }
    _28783aa8 = arr.map { |s| s.transformation.origin }
    materials.each_with_index do |src, inst2|
      next if src == inst2
      panels[src].each { |vec| KSU::Nesting.clone_panel_into(vec, arr[inst2]) if vec && vec.valid? }
      bot = arr2[src]
      next unless bot && bot.valid?
      delta = _28783aa8[inst2] - _28783aa8[src]
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
  def sheets_in_rect(view, x1, y1, x2, y2)
    rect = KSU::Quet.rect([x1, y1], [x2, y2])
    strict = x2 >= x1
    @sheets.each_with_object([]) do |rec, entries|
      pt = (0..7).map { |i| view.screen_coords(rec[:bbox].corner(i)) }
      arr2 = pt.map(&:x)
      arr = pt.map(&:y)
      next unless KSU::Quet.rect_hit?([arr2.min, arr.min, arr2.max, arr.max], rect, strict)
      entries << rec[:instance]
    end
  end
  def draw_rect2d(view)
    return unless @down_x && @drag_x
    KSU::View.draw_rect2d(view, @down_x, @down_y, @drag_x, @drag_y)
    sheets_in_rect(view, @down_x, @down_y, @drag_x, @drag_y).each do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      KSU::View.draw_outline(rec[:top_corners], KSU::View.face_color) if rec
    end
  end
end
class KSU::Toiuu
  def self.drop_id_cache
    KSU::Reorder.id_cache[0] = nil
  end
end
class KSU::Toiuu
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
