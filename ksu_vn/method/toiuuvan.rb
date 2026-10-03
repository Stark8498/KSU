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
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, _a4ab9a59| b ^ (61 + 87 * _a4ab9a59) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @nesting = nil
    @sheets = []
    @arr27 = []
    @arr64 = []
    @_3e453efd = nil
    @_096c8c23 = nil
    @_e14ef301 = nil
    @flag39 = nil
    @flag13 = false
    @flag23 = false
    @flag51 = nil
    @_3a930069 = @_0b246bc2 = @_86277c8a = @_e76905aa = nil
    @flag10 = false
    @flag46 = false
    @flag34 = false
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
    @num12 = nil
    @str = nil
    @_a16ac17e = nil
    @flag53 = false
    @arr44 = nil
    @num15 = 0
    @num17 = 0
    @flag57 = nil
    @num18 = 0
    @num5 = 0
    @h19 = nil
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
      @flag23 = true
      _37011ad2(true, view)
      _92d864e9(view, true)
    when VK_LEFT, VK_RIGHT
      return if @arr27.empty?
      _b5af8dbf = (rot & CONSTRAIN_MODIFIER_MASK) != 0
      _c04fb39c = if key == VK_LEFT
          _b5af8dbf ? :first : :prev
        else
          _b5af8dbf ? :last : :next
        end
      _d0431df5(_c04fb39c)
      view&.invalidate
    when 192 then KSU::Settings.open_settings("toi_uu_van")
    when 27, 32
      KSU.select_tool(nil)
      view&.invalidate
    end
  end
  def onKeyUp(key, rep, kflags, view)
    return unless key == CONSTRAIN_MODIFIER_KEY
    @flag23 = false
    _37011ad2(false, view)
    _92d864e9(view, false)
  end
  def onReturn(view)
    return if @arr27.empty?
    _28a699c9(@flag23)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @_3e453efd = x
    @_096c8c23 = y
    @flag23 = (rot & MK_SHIFT) != 0
    if @flag46
      @_86277c8a, @_e76905aa = x, y
      view.invalidate
      return
    end
    if @flag10
      if (x - @_3a930069).abs > 3 || (y - @_0b246bc2).abs > 3
        @flag46 = true
        @_86277c8a, @_e76905aa = x, y
        @arr64 = []
        @_e14ef301 = nil
        view.invalidate
      end
      return
    end
    hover_preset(x, y, view)
    return if hover_field(x, y, view)
    _37011ad2((rot & MK_SHIFT) != 0, view)
    _f27128bc(view, x, y)
    _92d864e9(view, (rot & MK_SHIFT) != 0)
  end
  def _37011ad2(ctrl, view)
    return unless @_3e453efd && @_096c8c23
    prev_key = @arr64
    _73dc38ac = _0fe26c5f(view, @_3e453efd, @_096c8c23)
    @arr64 = if _73dc38ac && ctrl
                      key = KSU::Sheet._7b0a38ee(_73dc38ac)
                      @sheets
                        .select { |arr| KSU::Sheet._7b0a38ee(arr[:instance]) == key }
                        .map { |arr| arr[:instance] }
                    else
                      _73dc38ac ? [_73dc38ac] : []
                    end
    view.invalidate if prev_key != @arr64
  end
  def _f27128bc(view, x, y)
    prev_key = @_e14ef301
    @_e14ef301 = hit_delete_button(view, x, y)
    view.invalidate if prev_key != @_e14ef301
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    arr = _8c688891(view, x, y, :corner)
    if arr
      _c211b5aa(arr[:sheet], arr[:idx], (rot & MK_SHIFT) != 0, :corner)
      view.invalidate
      return
    end
    edge = _8c688891(view, x, y, :edge)
    if edge
      _c211b5aa(edge[:sheet], edge[:idx], (rot & MK_SHIFT) != 0, :edge)
      view.invalidate
      return
    end
    target = hit_delete_button(view, x, y)
    if target
      _256cdef5(target)
      view.invalidate
      return
    end
    @_3a930069, @_0b246bc2 = x, y
    @_86277c8a, @_e76905aa = x, y
    @flag10 = true
    @flag46 = false
    @flag34 = (rot & MK_CONTROL) != 0 || (rot & MK_SHIFT) != 0
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    if @flag46
      sheets = _ce5c626c(view, @_3a930069, @_0b246bc2, x, y)
      @arr27 = @flag34 ? (@arr27 + sheets).uniq : sheets
    elsif @flag10
      additive = (rot & MK_CONTROL) != 0
      ctrl = (rot & MK_SHIFT) != 0
      _73dc38ac = _0fe26c5f(view, x, y)
      if _73dc38ac
        if ctrl
          _fb7c57bd(_73dc38ac, additive: additive)
        else
          _164a615b(_73dc38ac, additive)
        end
      elsif !additive && !ctrl
        @arr27 = []
      end
    end
    @flag10 = false
    @flag46 = false
    @_3a930069 = @_0b246bc2 = @_86277c8a = @_e76905aa = nil
    view.invalidate
  end
  def onLButtonDoubleClick(rot, x, y, view)
    additive = (rot & MK_CONTROL) != 0
    _73dc38ac = _0fe26c5f(view, x, y)
    return unless _73dc38ac
    _fb7c57bd(_73dc38ac, additive: additive)
    view.invalidate
  end
  def _fb7c57bd(_73dc38ac, additive:)
    key = KSU::Sheet._7b0a38ee(_73dc38ac)
    node = @sheets
      .select { |arr| KSU::Sheet._7b0a38ee(arr[:instance]) == key }
      .map { |arr| arr[:instance] }
    @arr27 = additive ? (@arr27 + node).uniq : node
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false) if @arr20 && @arr20.any?
    draw_overlay(view, @nesting)
    @arr27.each do |_73dc38ac|
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      KSU::View.draw_outline(arr[:top_corners], KSU::View.main_face_color) if arr
    end
    @arr64.each do |_73dc38ac|
      next if @arr27.include?(_73dc38ac)
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      KSU::View.draw_outline(arr[:top_corners], KSU::View.face_color) if arr
    end
    @arr27.each do |_73dc38ac|
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      next unless arr
      KSU::View.draw_brackets(view, arr[:top_corners]) { |_a4ab9a59| _4ada6475(_73dc38ac, _a4ab9a59, @flag39, @flag13) }
      KSU::View._2873a79b(view, arr[:top_corners]) { |_a4ab9a59| _4ada6475(_73dc38ac, _a4ab9a59, @flag51, @flag13) }
    end
    draw_rect2d(view) if @flag46
    _a42dd0f4(view)
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@num12}%") if @num12
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
  def _0fe26c5f(view, x, y)
    partner = @sheets.find { |_9dcbc6c4| KSU::View._919af578(view, x, y, _9dcbc6c4) }
    partner && partner[:instance]
  end
  def _164a615b(_73dc38ac, additive)
    if additive
      @arr27.include?(_73dc38ac) ? @arr27.delete(_73dc38ac) : @arr27 << _73dc38ac
    else
      @arr27 = @arr27 == [_73dc38ac] ? [] : [_73dc38ac]
    end
  end
  def hit_delete_button(view, x, y)
    @sheets.each do |arr|
      next unless KSU::Sheet.empty?(arr[:instance])
      return arr[:instance] if KSU::View.button_hit?(view, KSU::View.center_of(arr[:top_corners]), x, y)
    end
    nil
  end
  def _a42dd0f4(view)
    @sheets.each do |arr|
      next unless KSU::Sheet.empty?(arr[:instance])
      KSU::View.draw_warn_button(view, KSU::View.center_of(arr[:top_corners]), hover: @_e14ef301 == arr[:instance])
    end
  end
  def _92d864e9(view, ctrl)
    return unless @_3e453efd && @_096c8c23
    _8734f930 = @flag39
    _c3288067 = @flag13
    _522da39c = @flag51
    @flag39 = _8c688891(view, @_3e453efd, @_096c8c23, :corner)
    @flag51 = @flag39 ? nil : _8c688891(view, @_3e453efd, @_096c8c23, :edge)
    @flag13 = ctrl
    view.invalidate if @flag39 != _8734f930 || @flag13 != _c3288067 || @flag51 != _522da39c
  end
  def _8c688891(view, x, y, joint)
    @arr27.each do |_73dc38ac|
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      next unless arr
      ix = if joint == :corner
                 KSU::View._c5f21c57(view, arr[:top_corners], x, y)
               else
                 KSU::View._ec07b26f(view, arr[:top_corners], x, y)
               end
      return { sheet: _73dc38ac, idx: ix } if ix
    end
    nil
  end
  def _4ada6475(_73dc38ac, _a4ab9a59, hover, ctrl)
    return false unless hover
    if ctrl
      hover[:idx] == _a4ab9a59 && @arr27.include?(_73dc38ac)
    else
      hover[:sheet] == _73dc38ac && hover[:idx] == _a4ab9a59
    end
  end
  def _c211b5aa(_73dc38ac, ix, ctrl, num11)
    arr = (ctrl ? @arr27.dup : [_73dc38ac]).select { |s| s && s.valid? }
    return if arr.empty?
    KSU.start
    arr.each do |s|
      _9dcbc6c4 = @sheets.find { |arr2| arr2[:instance] == s }
      next unless _9dcbc6c4
      if num11 == :corner
        KSU::Nesting.pack_to_corner(@nesting, s, _9dcbc6c4, ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
      else
        KSU::Nesting.pack_to_edge(@nesting, s, _9dcbc6c4, ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
      end
    end
    KSU.commit
    sheet_list
    KSU::View.clear_cache
  rescue StandardError
    KSU.abort_op
  end
  def _d0431df5(_c04fb39c)
    _9535dc0b = @arr27.select { |s| s && s.valid? }
    return if _9535dc0b.empty?
    arr3 = []
    arr4 = []
    _9535dc0b.each do |_73dc38ac|
      next if arr4.include?(_73dc38ac)
      arr = KSU::Sheet.row_of(_73dc38ac, @sheets)
      arr2 = arr.each_index.select { |_a4ab9a59| _9535dc0b.include?(arr[_a4ab9a59]) }
      next if arr2.empty?
      arr4.concat(arr2.map { |_a4ab9a59| arr[_a4ab9a59] })
      materials = _ea9e841c(arr.length, arr2, _c04fb39c)
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
    @arr27 = ((_9535dc0b - arr6) + arr5).select { |s| s && s.valid? }.uniq
    sheet_list
    KSU::View.clear_cache
  rescue StandardError
    KSU.abort_op
  end
  def _ea9e841c(n, arr, _c04fb39c)
    materials = (0...n).to_a
    _9535dc0b = Array.new(n, false)
    arr.each { |_a4ab9a59| _9535dc0b[_a4ab9a59] = true }
    flag = (_c04fb39c == :prev || _c04fb39c == :first) ? :prev : :next
    _4ce596b6 = _c04fb39c == :first || _c04fb39c == :last
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
      (n - 2).downto(0) do |_a4ab9a59|
        next unless _9535dc0b[_a4ab9a59] && !_9535dc0b[_a4ab9a59 + 1]
        materials[_a4ab9a59], materials[_a4ab9a59 + 1] = materials[_a4ab9a59 + 1], materials[_a4ab9a59]
        _9535dc0b[_a4ab9a59], _9535dc0b[_a4ab9a59 + 1] = _9535dc0b[_a4ab9a59 + 1], _9535dc0b[_a4ab9a59]
        bbox = true
      end
    else
      1.upto(n - 1) do |_a4ab9a59|
        next unless _9535dc0b[_a4ab9a59] && !_9535dc0b[_a4ab9a59 - 1]
        materials[_a4ab9a59], materials[_a4ab9a59 - 1] = materials[_a4ab9a59 - 1], materials[_a4ab9a59]
        _9535dc0b[_a4ab9a59], _9535dc0b[_a4ab9a59 - 1] = _9535dc0b[_a4ab9a59 - 1], _9535dc0b[_a4ab9a59]
        bbox = true
      end
    end
    bbox
  end
  def _687e1def(arr, materials)
    panels = arr.map { |s| s.definition.entities.to_a.select { |ent| KSU::Nesting._88f4d2bb(ent) } }
    arr2 = arr.map { |s| KSU::Sheet.bottom_for(s, @nesting) }
    pt = arr.map { |s| s.transformation.origin }
    materials.each_with_index do |src, instance|
      next if src == instance
      panels[src].each { |vec| KSU::Nesting._d78e0ff0(vec, arr[instance]) if vec && vec.valid? }
      bot = arr2[src]
      next unless bot && bot.valid?
      delta = pt[instance] - pt[src]
      bot.transformation = Geom::Transformation.translation(delta) * bot.transformation
      bot.name = arr[instance].name.to_s + "-bottom"
      str = KSU::Sheet.sheet_no(arr[instance].name.to_s)
      bot.set_attribute("ABF", "sheet-id", str) if str
    end
  end
  def _256cdef5(_73dc38ac)
    return unless KSU::Sheet.remove_sheet(_73dc38ac, @nesting, @sheets)
    @arr27.delete(_73dc38ac)
    @arr64.delete(_73dc38ac)
    @_e14ef301 = nil
    sheet_list
    KSU::View.clear_cache
  end
  def _ce5c626c(view, x218, _60000b16, x2, y2)
    rect = KSU::Quet.rect([x218, _60000b16], [x2, y2])
    strict = x2 >= x218
    @sheets.each_with_object([]) do |arr, out|
      pts = (0..7).map { |_a4ab9a59| view.screen_coords(arr[:bbox].corner(_a4ab9a59)) }
      arr3 = pts.map(&:x)
      arr2 = pts.map(&:y)
      next unless KSU::Quet.rect_hit?([arr3.min, arr2.min, arr3.max, arr2.max], rect, strict)
      out << arr[:instance]
    end
  end
  def draw_rect2d(view)
    return unless @_3a930069 && @_86277c8a
    KSU::View.draw_rect2d(view, @_3a930069, @_0b246bc2, @_86277c8a, @_e76905aa)
    _ce5c626c(view, @_3a930069, @_0b246bc2, @_86277c8a, @_e76905aa).each do |_73dc38ac|
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      KSU::View.draw_outline(arr[:top_corners], KSU::View.face_color) if arr
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
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, _a4ab9a59| b ^ (0x3D + _a4ab9a59 * 0x57) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, _a4ab9a59| b ^ (_a4ab9a59 * 0x57 + 0x3D) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
