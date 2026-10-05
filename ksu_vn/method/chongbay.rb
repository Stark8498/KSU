require "json"
class KSU::Chongbay
  include KSU::Preset
  tool_key "chong_bay"
  def initialize
    KSU::Catcuoi.check_license
    KSU::Toiuu.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    return unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @che_do = get("che_do", 0).clamp(0, 1)
    @kieu_chon_tam = get("kieu_chon_tam", 0).clamp(0, 2)
    @che_do_chon = get("che_do_chon", 0).clamp(0, 1)
    @cho_phep_ghi_de = !!get("cho_phep_ghi_de", true)
    @gioi_han_kich_thuoc = !!get("gioi_han_kich_thuoc", false)
    @chieu_rong_toi_da = get("chieu_rong_toi_da", 200.0).mm
    @sheets = []
    @arr29 = []
    @plane_z = 0.0
    @cur_pt = @screen_pt = @auto_hover = @editing = nil
    @dest, @btn_joint, @btn_plan, @hover_sheet = nil, nil, [], nil
    reset_state
    @clearing = false
    @side = :tren
    @danh_so_thu_tu = !!get("danh_so_thu_tu", true)
    @so_layer_tu  = [get("so_layer_tu", 1), 1].max
    @so_layer_den = [get("so_layer_den", 30), @so_layer_tu].max
    @kc_tren = get("kc_tren", 600.0).mm
    @kc_duoi = get("kc_duoi", 600.0).mm
    @kc_trai = get("kc_trai", 600.0).mm
    @kc_phai = get("kc_phai", 600.0).mm
    @layer_theo_vung = !!get("layer_theo_vung", true)
    @ten_tren = get("ten_tren", "TREN").strip
    @ten_duoi = get("ten_duoi", "DUOI").strip
    @ten_trai = get("ten_trai", "TRAI").strip
    @ten_phai = get("ten_phai", "PHAI").strip
    @ten_chung = get("ten_chung", "LAYER").strip
    @mau_tren = KSU::View.parse_color(get("mau_tren", [212, 133, 94]))
    @mau_duoi = KSU::View.parse_color(get("mau_duoi", [212, 94, 94]))
    @mau_trai = KSU::View.parse_color(get("mau_trai", [94, 212, 94]))
    @mau_phai = KSU::View.parse_color(get("mau_phai", [94, 153, 212]))
    @mau_chung = KSU::View.parse_color(get("mau_chung", [94, 153, 212]))
    @tu_dong_don_layer = !!get("tu_dong_don_layer", true)
    @hien_bang_mau = !!get("hien_bang_mau", true)
    @co_bang_mau = [get("co_bang_mau", 16), 1].max
    @hien_so_thu_tu = !!get("hien_so_thu_tu", true)
    @co_so_thu_tu = [get("co_so_thu_tu", 8), 1].max
    load_overlay_settings
    @arr38 = []
    @_x_bi_lan_polys = nil
    @presets = get("presets", nil)
    if Sketchup.active_model.tools.active_tool == self
      @arr38 = KSU::Nesting.error_points(@nesting)
      update_status
    else
      @nesting = nil
    end
  end
  def apply_preset(s)
    _f4f1e862 = ->(v) { !!v }
    num = ->(v) { v.to_f.mm }
    num2 = ->(v) { [v.to_i, 1].max }
    text = ->(v) { v.to_s.strip }
    color = ->(v) { KSU::View.parse_color(v) }
    { che_do: ->(v) { v.to_i.clamp(0, 1) }, kieu_chon_tam: ->(v) { v.to_i.clamp(0, 2) },
      che_do_chon: ->(v) { v.to_i.clamp(0, 1) }, cho_phep_ghi_de: _f4f1e862, gioi_han_kich_thuoc: _f4f1e862,
      chieu_rong_toi_da: num, danh_so_thu_tu: _f4f1e862, so_layer_tu: num2, so_layer_den: num2,
      kc_tren: num, kc_duoi: num, kc_trai: num, kc_phai: num, layer_theo_vung: _f4f1e862,
      ten_tren: text, ten_duoi: text, ten_trai: text, ten_phai: text, ten_chung: text,
      mau_tren: color, mau_duoi: color, mau_trai: color, mau_phai: color, mau_chung: color,
      tu_dong_don_layer: _f4f1e862, hien_bang_mau: _f4f1e862, co_bang_mau: num2, hien_so_thu_tu: _f4f1e862, co_so_thu_tu: num2 }
      .each { |k, f| load_ivar(k, s, &f) }
    reset_state
    KSU::View.view&.invalidate
  end
  def activate
    KSU::Catcuoi.check_license
    KSU::Toiuu.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    part_list
    load_ranks
    @arr38 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    KSU::View.on_change(self) { on_model_change }
    setup_fields(
      "Giới hạn" => {
        gioi_han_kich_thuoc: [:switch, "Giới hạn kích thước"],
        chieu_rong_toi_da: [:mm, "Chiều rộng tối đa", -> { @gioi_han_kich_thuoc }, 0, 3000]
      },
      "Phương pháp" => {
        kieu_chon_tam: [:select, "Kiểu chọn tấm", { 0 => "Vùng", 1 => "Nét", 2 => "Tự do" }, -> { @che_do == 0 }],
        che_do_chon: [:select, "Chế độ chọn", { 0 => "Chạm", 1 => "Cắt" }, -> { @che_do == 0 }],
        cho_phep_ghi_de: [:switch, "Cho phép ghi đè"]
      },
      "Chống bay" => {
        danh_so_thu_tu: [:switch, "Đánh số thứ tự"],
        so_layer_tu:  [nil, "Layer bắt đầu", -> { @danh_so_thu_tu }, 1, 99],
        so_layer_den: [nil, "Layer kết thúc", -> { @danh_so_thu_tu }, 1]
      },
      "Layer" => {
        layer_theo_vung: [:switch, "Layer theo vùng"]
      },
      "Khoảng cách" => {
        kc_tren: [:mm, "Khoảng cách trên", -> { @che_do == 1 }, 0, 3000],
        kc_duoi: [:mm, "Khoảng cách dưới", -> { @che_do == 1 }, 0, 3000],
        kc_trai: [:mm, "Khoảng cách trái", -> { @che_do == 1 }, 0, 3000],
        kc_phai: [:mm, "Khoảng cách phải", -> { @che_do == 1 }, 0, 3000]
      },
      "Hiển thị" => {
        hien_bang_mau: [:switch, "Hiển thị bảng màu", -> { @che_do == 0 }],
        hien_so_thu_tu: [:switch, "Hiển thị số thứ tự", -> { @danh_so_thu_tu }],
        co_bang_mau: [nil, "Cỡ bảng màu", -> { @che_do == 0 && @hien_bang_mau }, 8, 100],
        co_so_thu_tu: [nil, "Cỡ số thứ tự", -> { @danh_so_thu_tu && @hien_so_thu_tu }, 4, 40]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    init_modes(
      ["Thủ công", "Tự động"],
      active_proc: -> { @che_do },
      on_click: ->(i) {
        set_mode(i)
        KSU::View.view&.invalidate
      }
    )
    load_presets(@presets)
    restore_selected_preset
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    save_selected_preset
    KSU::View.off_change(self)
    commit_changes(@arr29.select { |arr| arr[:changed] })
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def set_side(side, view)
    return unless side_mode?
    return if @side == side
    @side = side
    update_status
    view&.invalidate
  end
  def side_mode?
    @che_do == 0 && @layer_theo_vung && @kieu_chon_tam != 0
  end
  def set_mode(v)
    v = v.to_i.clamp(0, 1)
    return if v == @che_do
    @che_do = v
    set("che_do", v)
    reset_state
    @auto_hover = nil
    cancel_edit
    update_status
  end
  def onKeyDown(key, rep, kflags, view)
    return true if @editing && edit_key(key, view)
    case key
    when 192
      KSU::Settings.open_settings("chong_bay")
    when 9
      set_mode((@che_do + 1) % 2)
      view&.invalidate
    when 13
      if @kieu_chon_tam == 2 && @lasso_pts.any?
        rank_lasso
        view&.invalidate
      elsif !@clearing && !(@sweeping || !@rank_a.nil? || @lasso_pts.any?)
        KSU.select_tool(nil)
        view&.invalidate
      end
    when 27
      reset_state
      view&.invalidate
    when 32
      KSU.select_tool(nil)
      view&.invalidate
    when VK_LEFT then set_side(:trai, view)
    when VK_UP then set_side(:tren, view)
    when VK_RIGHT then set_side(:phai, view)
    when VK_DOWN then set_side(:duoi, view)
    when CONSTRAIN_MODIFIER_KEY
      update_preview(true, view)
    when ALT_MODIFIER_KEY
      unless @clearing
        @clearing = true
        reset_state unless @sweeping
        view&.invalidate
      end
    end
    true
  end
  def onKeyUp(key, rep, kflags, view)
    case key
    when CONSTRAIN_MODIFIER_KEY
      update_preview(false, view)
    when ALT_MODIFIER_KEY
      if @clearing
        @clearing = false
        reset_state unless @sweeping
        view&.invalidate
      end
    end
    true
  end
  def update_preview(ctrl, view)
    return unless @dest
    steps = plan_for(@dest, @btn_joint, ctrl)
    return if steps == @btn_plan
    @btn_plan = steps
    view&.invalidate
  end
  def onCancel(reason, view)
    reset_state
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    hover_preset(x, y, view)
    if hover_field(x, y, view) || hover_mode(x, y, view)
      set_hover(nil, view)
      return
    end
    @cur_pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    @screen_pt = Geom::Point3d.new(x, y, 0)
    if !@sweeping && !@rank_a && @lasso_pts.empty?
      @hover_sheet = sheet_under_header(x, y)
      @dest, @btn_joint = hit_button(view, x, y)
      @btn_plan = plan_for(@dest, @btn_joint, (rot & MK_SHIFT) != 0)
      set_hover(hit_at(x, y), view)
    else
      set_hover(nil, view)
    end
    if @che_do == 1
      @auto_hover = @dest ? nil : sheet_at(@cur_pt)
    else
      case pick_mode
      when 0
        @sweep_b = @cur_pt if @sweeping
      when 1
        @rank_b = @cur_pt if @rank_a
      when 2
        @rank_b = @cur_pt if @lasso_pts.any?
      end
    end
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_mode(x, y, view)
    return if click_outside(x, y, view)
    if !@sweeping && @rank_a.nil? && @lasso_pts.empty?
      _93f9844e = hit_at(x, y)
      begin_edit(_93f9844e, view)
      return if _93f9844e
    end
    sheet, kind = hit_button(view, x, y)
    if sheet
      hit_header(sheet, kind, plan_for(sheet, kind, (rot & MK_SHIFT) != 0))
      view.invalidate
      return
    end
    pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    return unless pt
    if @che_do == 1
      _143e75e9 = sheet_at(pt)
      apply_ranks(latch_rows_of(*_143e75e9)) if _143e75e9
      @auto_hover = nil
      view.invalidate
      return
    end
    case pick_mode
    when 0
      @sweeping = true
      @sweep_a = @sweep_b = pt
      @sweep_memo = nil
      @track_ids = []
    when 1
      if @rank_a.nil?
        @rank_a = @rank_b = pt
      else
        @rank_b = pt
        finish_drag_rank
      end
    when 2
      @lasso_pts << pt
      @rank_b = pt
    end
    view.invalidate
  end
  def pick_mode
    @clearing ? 0 : @kieu_chon_tam
  end
  def onLButtonUp(kflags, x, y, view)
    return unless pick_mode == 0 && @sweeping
    end_drag2
    @sweeping = false
    @sweep_a = @sweep_b = nil
    view.invalidate
  end
  def draw(view)
    KSU::View.refresh_now
    refresh_fill_colors
    @plan_preview = preview_plan
    @in_plan = @plan_preview.to_h { |arr| [arr[:part][:part], true] }
    @in_clear = clear_preview2.to_h { |arr2| [arr2[:part], true] }
    draw_overlay_fills if @phu_mau_tam || @phu_mau_tam_hai_mat
    draw_overlay(view, @nesting)
    group_by_rank
    draw_plan_preview
    if @che_do == 1
      draw_side_line(view)
    else
      draw_pick(view)
    end
    view.line_stipple = ""
    draw_sheet_buttons(view)
    draw_presets(view)
    draw_fields(view)
    draw_modes(view)
    draw_order_numbers
    draw_color_chip(view)
  end
  def refresh_fill_colors
    return if @fill_colors_for == @danh_so_thu_tu
    @fill_colors_for = @danh_so_thu_tu
    @arr29.each { |arr| arr[:fill_color] = fill_color_of(arr) }
  end
  def draw_order_numbers
    return unless @hien_so_thu_tu && @danh_so_thu_tu
    @arr29.each do |arr|
      next if !arr[:rank] || @in_plan[arr[:part]] || @in_clear[arr[:part]] || arr.equal?(@editing)
      KSU::View.draw_label(arr[:rank].to_s, arr[:center], shape: :circle, size: size2(arr))
    end
    @plan_preview.each do |arr2|
      KSU::View.draw_label(arr2[:rank].to_s, arr2[:part][:center], shape: :circle, size: @co_so_thu_tu)
    end
    draw_editing_rank
  end
  def draw_editing_rank
    arr = @editing
    return unless arr && arr[:rank]
    return if @in_plan[arr[:part]] || @in_clear[arr[:part]]
    lbl = @typed.empty? ? arr[:rank].to_s : @typed
    KSU::View.draw_label(lbl, arr[:center], shape: :circle, size: size2(arr), line_width: 2)
  end
  def size2(pt3)
    pt3.equal?(@editing) || pt3.equal?(@hover_rec) ? @co_so_thu_tu * 1.5 : @co_so_thu_tu
  end
  def hit_at(x, y)
    return nil unless @hien_so_thu_tu && @danh_so_thu_tu
    @arr29.reverse_each.find do |arr|
      arr[:rank] && KSU::View.draw_label_at(arr[:rank].to_s, arr[:center], x, y, size: size2(arr))
    end
  end
  def begin_edit(pt3, view)
    @typed = ""
    return if @editing.equal?(pt3)
    @editing = pt3
    update_status
    view&.invalidate
  end
  def edit_key(key, view)
    case key
    when 48..57 then type_digit((key - 48).to_s)
    when 96..105 then type_digit((key - 96).to_s)
    when 8
      return false if @typed.empty?
      @typed = @typed[0...-1]
    when 13
      commit_edit(view)
      return true
    else
      return false
    end
    update_status
    view&.invalidate
    true
  end
  def type_digit(ch)
    @typed += ch if @typed.length < 3
  end
  def commit_edit(view)
    arr = @editing
    layers = @typed.to_i
    set_rank(arr, layers) if arr && arr[:rank] && layers >= 1
    begin_edit(nil, view)
  end
  def set_hover(pt3, view)
    return if @hover_rec.equal?(pt3)
    @hover_rec = pt3
    view&.invalidate
  end
  def draw_overlay_fills
    arr3, arr2 = [], []
    @arr29.each do |arr|
      next if @in_plan[arr[:part]] || (arr[:rank] && !@in_clear[arr[:part]])
      if arr[:two_sided] && @phu_mau_tam_hai_mat
        arr2 << overlay_of(arr)
      elsif @phu_mau_tam
        arr3 << overlay_of(arr)
      end
    end
    KSU::View.draw_polys(arr3, color: KSU::View.panel_normal_color, line: false) unless arr3.empty?
    KSU::View.draw_polys(arr2, color: KSU::View.panel_two_color, line: false) unless arr2.empty?
  end
  def overlay_of(arr)
    holes = arr[:overlay_holes]
    holes && !holes.empty? ? { outer: arr[:overlay_polygon], holes: holes } : arr[:overlay_polygon]
  end
  def draw_sheet_buttons(view)
    arr = @btn_plan.dup
    arr << @hover_sheet if @hover_sheet && !arr.include?(@hover_sheet)
    return if arr.empty?
    @sheets.each do |rec|
      sheet = rec[:instance]
      next unless arr.include?(sheet)
      hover = @btn_plan.include?(sheet)
      center = KSU::View.button_center(rec)
      if assigned?(sheet)
        KSU::View.draw_outline(rec[:top_corners], KSU::View.warn_color)
        KSU::View.draw_warn_button(view, center, hover: hover)
      else
        KSU::View.draw_outline(rec[:top_corners], KSU::View.main_face_color)
        KSU::View.draw_button(view, center, hover: hover)
      end
    end
  end
  def header_rect(rec)
    text, x1, y0, y1, z = KSU::View.extents(rec[:top_corners])
    y1 += 400.mm
    [[text, y0], [x1, y0], [x1, y1], [text, y1]].map { |trai, duoi| Geom::Point3d.new(trai, duoi, z) }
  end
  def assigned?(sheet)
    @arr29.any? { |arr| arr[:sheet] == sheet && arr[:rank] }
  end
  def hit_button(view, x, y)
    rec = @sheets.find { |i| KSU::View.button_hit?(view, KSU::View.button_center(i), x, y) }
    return [nil, nil] unless rec
    [rec[:instance], assigned?(rec[:instance]) ? :delete : :plus]
  end
  def sheet_under_header(x, y)
    rec = @sheets.find { |i| KSU::View.in_poly?(x, y, KSU::View.to_screen(header_rect(i))) }
    rec && rec[:instance]
  end
  def hit_header(sheet, kind, arr)
    (arr.empty? ? [sheet] : arr).each do |s|
      kind == :delete ? clear_ranks(@arr29.select { |arr2| arr2[:sheet] == s }) : apply_ranks(latch_rows_of(s))
    end
    @dest, @btn_joint, @btn_plan, @hover_sheet = nil, nil, [], nil
  end
  def plan_for(sheet, kind, ctrl)
    return [] unless sheet
    return [sheet] unless ctrl
    sig = sheet_sig(sheet)
    return [sheet] unless sig
    @sheets.map { |rec| rec[:instance] }.select do |s|
      sheet_sig(s) == sig && assigned?(s) == (kind == :delete)
    end
  end
  def sheet_sig(sheet)
    _26ca0c07 = sheet.respond_to?(:attribute_dictionary) && sheet.attribute_dictionary("ABF")
    [_26ca0c07["sheet-thickness"], _26ca0c07["sheet-type"]] if _26ca0c07
  end
  def latch_rows_of(sheet, side = nil)
    rec = KSU::Sheet.record_for(@sheets, sheet)
    return [] unless rec
    arr29 = @arr29.select { |arr| arr[:sheet] == sheet }
    return plan_all_sides(arr29, rec[:bbox]) unless side
    plan_side(arr29, rec[:bbox], side)
  end
  def plan_all_sides(arr29, _02e5d8f8)
    rest = arr29.dup
    arr2 = []
    layers = @so_layer_tu
    [:trai, :tren, :phai, :duoi].each do |side|
      arr = plan_side(rest, _02e5d8f8, side, layers)
      next if arr.empty?
      arr2.concat(arr)
      rest -= arr.map { |arr3| arr3[:part] }
      layers = arr.last[:rank] + 1 unless @layer_theo_vung
    end
    arr2
  end
  def plan_side(arr29, _02e5d8f8, side, layers2 = @so_layer_tu)
    gap2 = gap_for_side(side)
    name = layer_for_side(side)
    return [] if gap2.to_f <= 0 || name.to_s.empty?
    arr29 = eligible(arr29)
    items = arr29.select { |arr| near_side?(arr[:bbox], _02e5d8f8, side, gap2) }
                       .map { |arr| { part: arr, threshold: threshold(arr[:bbox], _02e5d8f8, side) } }
    flag = (side == :tren || side == :duoi) ?
              ->(i) { i[:part][:center].x.to_f } : ->(i) { i[:part][:center].y.to_f }
    items.sort_by! { |i| [i[:threshold], flag.call(i)] }
    number_parts(items.map { |i| i[:part] }, side, layers2)
  end
  def gap_for_side(side)
    { tren: @kc_tren, duoi: @kc_duoi, trai: @kc_trai, phai: @kc_phai }[side]
  end
  def sheet_at(segs_for_ray)
    return nil unless segs_for_ray
    trai, duoi = segs_for_ray.x.to_f, segs_for_ray.y.to_f
    @sheets.each do |rec|
      bbox = rec[:bbox]
      next unless trai >= bbox.min.x.to_f && trai <= bbox.max.x.to_f &&
                  duoi >= bbox.min.y.to_f && duoi <= bbox.max.y.to_f
      side = nearest_side(trai, duoi, bbox)
      return [rec[:instance], side] if side
    end
    nil
  end
  def depths(trai, duoi, bbox)
    { tren: bbox.max.y.to_f - duoi, duoi: duoi - bbox.min.y.to_f, phai: bbox.max.x.to_f - trai, trai: trai - bbox.min.x.to_f }
  end
  def nearest_side(trai, duoi, bbox)
    depths(trai, duoi, bbox).select do |side, depth|
      gap_for_side(side).to_f > 0 && !layer_for_side(side).to_s.empty? && depth >= 0
    end.min_by { |_item, depth| depth }&.first
  end
  def draw_plan_preview
    @plan_preview.each do |arr|
      color = KSU::View.shade(side_color(arr[:side]), arr[:rank] - 1)
      KSU::View.draw_poly_holes(arr[:part][:overlay_polygon], arr[:part][:overlay_holes], color: color, line: false)
    end
  end
  def draw_side_line(view)
    return unless @auto_hover
    sheet, side = @auto_hover
    rec = KSU::Sheet.record_for(@sheets, sheet)
    return unless rec
    bbox = rec[:bbox]
    x1, _614e963e, y1, _d67f3cec, z = bbox.min.x.to_f, bbox.max.x.to_f, bbox.min.y.to_f, bbox.max.y.to_f, bbox.max.z.to_f
    pts2 = case side
             when :tren then [Geom::Point3d.new(x1, _d67f3cec, z), Geom::Point3d.new(_614e963e, _d67f3cec, z)]
             when :duoi then [Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(_614e963e, y1, z)]
             when :trai then [Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x1, _d67f3cec, z)]
             when :phai then [Geom::Point3d.new(_614e963e, y1, z), Geom::Point3d.new(_614e963e, _d67f3cec, z)]
             end
    view.line_stipple = ""
    view.line_width = 5
    view.drawing_color = side_color(side)
    view.draw(GL_LINES, pts2)
  end
  def near_side?(rect4, bb, side, gap2)
    case side
    when :tren then rect4.min.y >= bb.max.y - gap2
    when :duoi then rect4.max.y <= bb.min.y + gap2
    when :phai then rect4.min.x >= bb.max.x - gap2
    when :trai then rect4.max.x <= bb.min.x + gap2
    end
  end
  def threshold(rect4, bb, side)
    case side
    when :tren then bb.max.y - rect4.max.y
    when :duoi then rect4.min.y - bb.min.y
    when :phai then bb.max.x - rect4.max.x
    when :trai then rect4.min.x - bb.min.x
    end
  end
  def preview_plan
    return [] if @clearing
    return button_plan if @dest && @btn_joint == :plus
    return auto_plan if @che_do == 1
    case @kieu_chon_tam
    when 0 then rect_plan
    when 1 then line_plan
    when 2 then lasso_plan
    else []
    end
  end
  def clear_preview2
    @clearing && @sweeping ? band_parts : []
  end
  def auto_plan
    @auto_hover ? latch_rows_of(*@auto_hover) : []
  end
  def button_plan
    (@btn_plan.empty? ? [@dest] : @btn_plan).flat_map { |sheet| latch_rows_of(sheet) }
  end
  def rect_plan
    sweep = @sweeping && sweep_dir
    sweep ? rank_plan(sweep) : []
  end
  def line_plan
    return [] unless @rank_a && @rank_b
    rank_drag(parts_between(@rank_a, @rank_b))
  end
  def lasso_plan
    rank_free(parts_along(lasso_path))
  end
  private
  def update_status
    if @editing
      KSU.set_status("Nhập số layer rồi nhấn Enter. Nhấn Enter hoặc bấm ra chỗ trống để bỏ chọn số.")
      KSU.set_vcb("Số layer", @typed.empty? ? @editing[:rank].to_s : @typed)
      return
    end
    KSU.set_vcb("", "")
    if @che_do == 1
      KSU.set_status("Bấm vào vùng để thêm chống bay. Bấm dấu + để thêm cả 4 vùng. Nhấn Tab để đổi chế độ.")
    elsif side_mode?
      KSU.set_status("Nhấn Tab để đổi chế độ. Giữ Alt để tẩy. Nhấn Mũi tên để chọn hướng layer.")
    else
      KSU.set_status("Nhấn Tab để đổi chế độ. Giữ Alt để chuyển sang chế độ tẩy.")
    end
  end
  def draw_color_chip(view)
    return if @che_do != 0 || @clearing || @screen_pt.nil? || !@hien_bang_mau || busy? || @kieu_chon_tam == 0
    num2 = @co_bang_mau.to_f
    text = @screen_pt.x.to_f + 14.0
    num = @screen_pt.y.to_f + 14.0
    x1 = text + num2
    y1 = num + num2
    view.line_stipple = ""
    if @layer_theo_vung
      t = num2 / 4.0
      case @side
      when :phai then fill_rect2d(view, x1 - t, num, x1, y1, @mau_phai)
      when :trai then fill_rect2d(view, text, num, text + t, y1, @mau_trai)
      when :tren then fill_rect2d(view, text, num, x1, num + t, @mau_tren)
      when :duoi then fill_rect2d(view, text, y1 - t, x1, y1, @mau_duoi)
      end
    else
      fill_rect2d(view, text, num, x1, y1, @mau_chung)
    end
    view.drawing_color = KSU::View.edge_color
    view.line_width = 1
    view.draw2d(GL_LINE_LOOP, [
      Geom::Point3d.new(text, num, 0), Geom::Point3d.new(x1, num, 0),
      Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(text, y1, 0)
    ])
  end
  def fill_rect2d(view, text, y0, x1, y1, color)
    view.drawing_color = color
    view.draw2d(GL_TRIANGLES, [
      Geom::Point3d.new(text, y0, 0), Geom::Point3d.new(x1, y0, 0), Geom::Point3d.new(x1, y1, 0),
      Geom::Point3d.new(text, y0, 0), Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(text, y1, 0)
    ])
  end
  def reset_state
    @sweeping = false
    @sweep_a = @sweep_b = @sweep_memo = @rank_a = @rank_b = @hover_rec = nil
    @track_ids = []
    @lasso_pts = []
    @typed = ""
    if @editing
      @editing = nil
      update_status
    end
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting)
    @plane_z = @sheets.empty? ? 0.0 : @sheets.first[:bbox].center.z.to_f
  end
  def part_list
    @arr29 = []
    two_sided_flags = KSU::Nesting.two_sided_set(@nesting)
    @sheets.each do |arr|
      grp = arr[:instance]
      transform = arr[:transform]
      grp.definition.entities.each do |panel|
        next unless KSU::Sheet.part_group?(panel)
        next if skip_panel?(panel)
        panel_tr = transform * panel.transformation
        bbox = KSU::Geom.world_box(panel.definition.bounds, panel_tr)
        fill = KSU::Cutting.outline(panel, panel_tr)
        polygon = fill[:outer]
        holes = fill[:holes] || []
        if polygon.nil? || polygon.length < 3
          polygon = KSU::View.bbox_top(bbox)
          holes = []
        end
        z = (-0.1).mm
        overlay_polygon = polygon.map { |segs_for_ray| Geom::Point3d.new(segs_for_ray.x, segs_for_ray.y, z) }
        overlay_holes = holes.map { |elem| elem.map { |segs_for_ray| Geom::Point3d.new(segs_for_ray.x, segs_for_ray.y, z) } }
        @arr29 << {
          part: panel,
          sheet: grp,
          cutting: KSU::Cutting.cutting_group(panel),
          bbox: bbox,
          polygon: polygon,
          holes: holes,
          overlay_polygon: overlay_polygon,
          overlay_holes: overlay_holes,
          center: bbox.center,
          rank: nil,
          theo_vung: true,
          changed: false,
          two_sided: !(ix = panel.get_attribute("ABF", "board-index")).nil? && !!two_sided_flags[ix]
        }
      end
    end
  end
  def skip_panel?(panel)
    return true if KSU::Sheet.mark?(panel)
    panel.name.to_s.include?("ABF_axisOfSymmetry") || panel.layer&.name.to_s.include?("ABF_axisOfSymmetry")
  end
  def on_model_change
    return unless @nesting && @nesting.valid?
    sheet_list
    part_list
    load_ranks
    reset_state
    @dest, @btn_joint, @btn_plan, @hover_sheet = nil, nil, [], nil
  end
end
class KSU::Chongbay
  def self.read_bindings
    data = {}
    ["k", "i", "t"].each do |key|
      str = Sketchup.read_default("KSU", key, "")
      data[key] = str unless str.to_s.empty?
    end
    data
  end
end
class KSU::Chongbay
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
