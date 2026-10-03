require "json"
class KSU::Chongbay
  include KSU::Preset
  tool_key "chong_bay"
  def initialize
    KSU::Netcatcuoi.check_license
    KSU::Toiuuvan.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @che_do = get("che_do", 0).to_i.clamp(0, 1)
    @kieu_chon_tam = get("kieu_chon_tam", 0).to_i.clamp(0, 2)
    @che_do_chon = get("che_do_chon", 0).to_i.clamp(0, 1)
    @cho_phep_ghi_de = !!get("cho_phep_ghi_de", true)
    @gioi_han_kich_thuoc = !!get("gioi_han_kich_thuoc", false)
    @chieu_rong_toi_da = get("chieu_rong_toi_da", 200.0).to_f.mm
    @sheets = []
    @parts = []
    @plane_z = 0.0
    @cur_pt = nil
    @screen_pt = nil
    @sweeping = false
    @sweep_a = nil
    @sweep_b = nil
    @sweep_memo = nil
    @track_ids = []
    @rank_a = nil
    @rank_b = nil
    @lasso_pts = []
    @dest = nil
    @btn_joint = nil
    @btn_plan = []
    @auto_hover = nil
    @hover_sheet = nil
    @editing = nil
    @hover_rec = nil
    @typed = ""
    @plan_preview = []
    @clear_plan = []
    @in_plan = {}
    @in_clear = {}
    @clearing = false
    @side = :tren
    @danh_so_thu_tu = !!get("danh_so_thu_tu", true)
    @so_layer_tu  = [get("so_layer_tu", 1).to_i, 1].max
    @so_layer_den = [get("so_layer_den", 30).to_i, @so_layer_tu].max
    @kc_tren = get("kc_tren", 600.0).to_f.mm
    @kc_duoi = get("kc_duoi", 600.0).to_f.mm
    @kc_trai = get("kc_trai", 600.0).to_f.mm
    @kc_phai = get("kc_phai", 600.0).to_f.mm
    @layer_theo_vung = !!get("layer_theo_vung", true)
    @ten_tren = get("ten_tren", "TREN").to_s.strip
    @ten_duoi = get("ten_duoi", "DUOI").to_s.strip
    @ten_trai = get("ten_trai", "TRAI").to_s.strip
    @ten_phai = get("ten_phai", "PHAI").to_s.strip
    @ten_chung = get("ten_chung", "LAYER").to_s.strip
    @mau_tren = KSU::View.parse_color(get("mau_tren", [212, 133, 94]))
    @mau_duoi = KSU::View.parse_color(get("mau_duoi", [212, 94, 94]))
    @mau_trai = KSU::View.parse_color(get("mau_trai", [94, 212, 94]))
    @mau_phai = KSU::View.parse_color(get("mau_phai", [94, 153, 212]))
    @mau_chung = KSU::View.parse_color(get("mau_chung", [94, 153, 212]))
    @tu_dong_don_layer = !!get("tu_dong_don_layer", true)
    @hien_bang_mau = !!get("hien_bang_mau", true)
    @co_bang_mau = [get("co_bang_mau", 16).to_i, 1].max
    @hien_so_thu_tu = !!get("hien_so_thu_tu", true)
    @co_so_thu_tu = [get("co_so_thu_tu", 8).to_i, 1].max
    load_overlay_settings
    @label_section_hidden = []
    @err_pts = []
    @_x_bi_lan_polys = nil
    @presets = get("presets", nil)
    if Sketchup.active_model.tools.active_tool == self
      reset_state
      @err_pts = KSU::Nesting.error_points(@nesting)
      @label_section_hidden = KSU::Cutting.apply_label_hiding(
        @nesting, @an_nhan_tiet_dien, @label_section_hidden
      )
      update_status
    else
      @nesting = nil
    end
  end
  def apply_preset(s)
    load_ivar(:che_do, s) { |v| v.to_i.clamp(0, 1) }
    load_ivar(:kieu_chon_tam, s) { |v| v.to_i.clamp(0, 2) }
    load_ivar(:che_do_chon, s) { |v| v.to_i.clamp(0, 1) }
    load_ivar(:cho_phep_ghi_de, s) { |v| !!v }
    load_ivar(:gioi_han_kich_thuoc, s) { |v| !!v }
    load_ivar(:chieu_rong_toi_da, s) { |v| v.to_f.mm }
    load_ivar(:danh_so_thu_tu, s) { |v| !!v }
    load_ivar(:so_layer_tu, s) { |v| [v.to_i, 1].max }
    load_ivar(:so_layer_den, s) { |v| [v.to_i, 1].max }
    load_ivar(:kc_tren, s) { |v| v.to_f.mm }
    load_ivar(:kc_duoi, s) { |v| v.to_f.mm }
    load_ivar(:kc_trai, s) { |v| v.to_f.mm }
    load_ivar(:kc_phai, s) { |v| v.to_f.mm }
    load_ivar(:layer_theo_vung, s) { |v| !!v }
    load_ivar(:ten_tren, s) { |v| v.to_s.strip }
    load_ivar(:ten_duoi, s) { |v| v.to_s.strip }
    load_ivar(:ten_trai, s) { |v| v.to_s.strip }
    load_ivar(:ten_phai, s) { |v| v.to_s.strip }
    load_ivar(:ten_chung, s) { |v| v.to_s.strip }
    load_ivar(:mau_tren, s) { |v| KSU::View.parse_color(v) }
    load_ivar(:mau_duoi, s) { |v| KSU::View.parse_color(v) }
    load_ivar(:mau_trai, s) { |v| KSU::View.parse_color(v) }
    load_ivar(:mau_phai, s) { |v| KSU::View.parse_color(v) }
    load_ivar(:mau_chung, s) { |v| KSU::View.parse_color(v) }
    load_ivar(:tu_dong_don_layer, s) { |v| !!v }
    load_ivar(:hien_bang_mau, s) { |v| !!v }
    load_ivar(:co_bang_mau, s) { |v| [v.to_i, 1].max }
    load_ivar(:hien_so_thu_tu, s) { |v| !!v }
    load_ivar(:co_so_thu_tu, s) { |v| [v.to_i, 1].max }
    reset_state
    KSU::View.view&.invalidate
  end
  def activate
    KSU::Netcatcuoi.check_license
    KSU::Toiuuvan.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    part_list
    load_ranks
    @err_pts = KSU::Nesting.error_points(@nesting)
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
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    save_selected_preset
    KSU::View.off_change(self)
    commit_changes(@parts.select { |arr| arr[:changed] })
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
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
    plan = plan_for(@dest, @btn_joint, ctrl)
    return if plan == @btn_plan
    @btn_plan = plan
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
      prev_hover, cur_sheet, prev_joint, prev_plan = @hover_sheet, @dest, @btn_joint, @btn_plan
      @hover_sheet = hit_header(view, x, y)
      sheet, joint = hit_button(view, x, y)
      ctrl = (rot & MK_SHIFT) != 0
      @dest, @btn_joint = sheet, joint
      @btn_plan = plan_for(sheet, joint, ctrl)
      view.invalidate if prev_hover != @hover_sheet || cur_sheet != @dest || prev_joint != @btn_joint || prev_plan != @btn_plan
      set_hover(hit_at(x, y), view)
    else
      set_hover(nil, view)
    end
    if @che_do == 1
      prev_auto = @auto_hover
      @auto_hover = @dest ? nil : sheet_at(@cur_pt)
      view.invalidate if prev_auto != @auto_hover
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
      hit = hit_at(x, y)
      if hit
        begin_edit(hit, view)
        return
      end
      begin_edit(nil, view)
    end
    sheet, joint = hit_button(view, x, y)
    if sheet
      ctrl = (rot & MK_SHIFT) != 0
      plan = plan_for(sheet, joint, ctrl)
      apply_action(sheet, joint, plan)
      view.invalidate
      return
    end
    pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    return unless pt
    if @che_do == 1
      arr = sheet_at(pt)
      assign_side(arr[0], arr[1]) if arr
      @auto_hover = nil
      view.invalidate
      return
    end
    case pick_mode
    when 0
      @sweeping = true
      @sweep_a = pt
      @sweep_b = pt
      @sweep_memo = nil
      @track_ids = []
    when 1
      if @rank_a.nil?
        @rank_a = pt
        @rank_b = pt
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
    @sweep_a = nil
    @sweep_b = nil
    view.invalidate
  end
  def draw(view)
    KSU::View.refresh_now
    refresh_fill_colors
    @plan_preview = preview_plan
    @clear_plan = clear_preview2
    @in_plan = @plan_preview.each_with_object({}) { |arr, h| h[arr[:part][:part]] = true }
    @in_clear = @clear_plan.each_with_object({}) { |arr2, h| h[arr2[:part]] = true }
    draw_overlay_fills if @phu_mau_tam || @phu_mau_tam_hai_mat
    draw_overlay(view, @nesting)
    draw_ranked(view)
    draw_assigned(view)
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
    draw_ranks(view)
    draw_color_chip(view)
  end
  def refresh_fill_colors
    return if @fill_colors_for == @danh_so_thu_tu
    @fill_colors_for = @danh_so_thu_tu
    @parts.each { |arr| arr[:fill_color] = fill_color_of(arr) }
  end
  def draw_ranks(view)
    return unless @hien_so_thu_tu && @danh_so_thu_tu
    arr4 = @in_plan
    arr3 = @in_clear
    @parts.each do |arr|
      next unless arr[:rank]
      next if arr4[arr[:part]]
      next if arr3[arr[:part]]
      next if arr.equal?(@editing)
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
  def size2(_23505ef9)
    return @co_so_thu_tu * 1.5 if _23505ef9.equal?(@editing) || _23505ef9.equal?(@hover_rec)
    @co_so_thu_tu
  end
  def hit_at(x, y)
    return nil unless @hien_so_thu_tu && @danh_so_thu_tu
    @parts.reverse_each do |arr|
      next unless arr[:rank]
      next unless KSU::View._6ced5498(arr[:rank].to_s, arr[:center], x, y, size: size2(arr))
      return arr
    end
    nil
  end
  def begin_edit(_23505ef9, view)
    @typed = ""
    return if @editing.equal?(_23505ef9)
    @editing = _23505ef9
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
    view&.invalidate
  end
  def set_hover(_23505ef9, view)
    return if @hover_rec.equal?(_23505ef9)
    @hover_rec = _23505ef9
    view&.invalidate
  end
  def draw_overlay_fills
    return if @parts.empty?
    ref_p1 = @in_plan
    arr4 = @in_clear
    arr3 = []
    arr2 = []
    @parts.each do |arr|
      next if ref_p1[arr[:part]]
      next if arr[:rank] && !arr4[arr[:part]]
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
    node = @btn_plan || []
    arr2 = node.dup
    arr2 << @hover_sheet if @hover_sheet && !arr2.include?(@hover_sheet)
    return if arr2.empty?
    @sheets.each do |rec|
      sheet = rec[:instance]
      next unless arr2.include?(sheet)
      hover = node.include?(sheet)
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
    pts = rec[:top_corners]
    arr2 = pts.map(&:x)
    arr3 = pts.map(&:y)
    z = pts.map(&:z).max
    y1 = arr3.min
    y2 = arr3.max + 400.mm
    [
      Geom::Point3d.new(arr2.min, y1, z),
      Geom::Point3d.new(arr2.max, y1, z),
      Geom::Point3d.new(arr2.max, y2, z),
      Geom::Point3d.new(arr2.min, y2, z)
    ]
  end
  def assigned?(sheet)
    @parts.any? { |arr| arr[:sheet] == sheet && arr[:rank] }
  end
  def hit_button(view, x, y)
    @sheets.each do |rec|
      sheet = rec[:instance]
      next unless KSU::View.button_hit?(view, KSU::View.button_center(rec), x, y)
      return [sheet, assigned?(sheet) ? :delete : :plus]
    end
    [nil, nil]
  end
  def hit_header(view, x, y)
    @sheets.each do |rec|
      arr2 = KSU::View.to_screen(header_rect(rec))
      next if arr2.empty?
      return rec[:instance] if KSU::View.in_poly?(x, y, arr2)
    end
    nil
  end
  def apply_action(sheet, joint, arr = nil)
    arr = [sheet] if arr.nil? || arr.empty?
    if joint == :delete
      arr.each { |s| clear_ranks(@parts.select { |arr2| arr2[:sheet] == s }) }
    else
      arr.each { |s| assign_all(s) }
    end
    @dest = nil
    @btn_joint = nil
    @btn_plan = []
    @hover_sheet = nil
  end
  def plan_for(sheet, joint, ctrl)
    return [] unless sheet
    return [sheet] unless ctrl && (joint == :plus || joint == :delete)
    sig = sheet_sig(sheet)
    return [sheet] unless sig
    want_assigned = (joint == :delete)
    @sheets.each_with_object([]) do |rec, out|
      s = rec[:instance]
      next unless sheet_sig(s) == sig
      next if assigned?(s) != want_assigned
      out << s
    end
  end
  def sheet_sig(sheet)
    return nil unless sheet && sheet.respond_to?(:attribute_dictionary)
    arr = sheet.attribute_dictionary("ABF")
    return nil unless arr
    [arr["sheet-thickness"], arr["sheet-type"]]
  end
  def assign_all(sheet)
    rec = KSU::Sheet.record_for(@sheets, sheet)
    return unless rec
    parts = @parts.select { |arr2| arr2[:sheet] == sheet }
    apply_ranks(plan_all_sides(parts, rec[:bbox]))
  end
  def assign_side(sheet, side)
    rec = KSU::Sheet.record_for(@sheets, sheet)
    return unless rec
    parts = @parts.select { |arr2| arr2[:sheet] == sheet }
    apply_ranks(plan_side(parts, rec[:bbox], side))
  end
  def plan_all_sides(parts, bbox)
    rest = parts.dup
    arr2 = []
    layers = @so_layer_tu
    [:trai, :tren, :phai, :duoi].each do |side|
      arr = plan_side(rest, bbox, side, layers)
      next if arr.empty?
      arr2.concat(arr)
      rest -= arr.map { |arr3| arr3[:part] }
      layers = arr.last[:rank] + 1 unless @layer_theo_vung
    end
    arr2
  end
  def plan_side(parts, bbox, side, layers2 = @so_layer_tu)
    gap2 = gap_for_side(side)
    name = layer_for_side(side)
    return [] if gap2.to_f <= 0 || name.to_s.empty?
    parts = eligible(parts)
    items = parts.each_with_object([]) do |arr2, out|
      next unless near_side?(arr2[:bbox], bbox, side, gap2)
      out << { part: arr2, threshold: threshold(arr2[:bbox], bbox, side) }
    end
    return [] if items.empty?
    flag = (side == :tren || side == :duoi) ?
              ->(i) { i[:part][:center].x.to_f } : ->(i) { i[:part][:center].y.to_f }
    items.sort_by! { |i| [i[:threshold], flag.call(i)] }
    number_parts(items.map { |i| i[:part] }, side, layers2)
  end
  def gap_for_side(side)
    case side
    when :tren then @kc_tren
    when :duoi then @kc_duoi
    when :trai then @kc_trai
    when :phai then @kc_phai
    end
  end
  def sheet_at(pt)
    return nil unless pt
    trai = pt.x.to_f
    duoi = pt.y.to_f
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
    {
      tren: bbox.max.y.to_f - duoi,
      duoi: duoi - bbox.min.y.to_f,
      phai: bbox.max.x.to_f - trai,
      trai: trai - bbox.min.x.to_f
    }
  end
  def nearest_side(trai, duoi, bbox)
    arr = depths(trai, duoi, bbox).select do |side, depth|
      gap_for_side(side).to_f > 0 && !layer_for_side(side).to_s.empty? && depth >= 0
    end
    return nil if arr.empty?
    arr.min_by { |_part, depth| depth }.first
  end
  def draw_assigned(view)
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
    x1 = bbox.min.x.to_f
    x2 = bbox.max.x.to_f
    y1 = bbox.min.y.to_f
    y2 = bbox.max.y.to_f
    z = bbox.max.z.to_f
    pts = case side
             when :tren then [Geom::Point3d.new(x1, y2, z), Geom::Point3d.new(x2, y2, z)]
             when :duoi then [Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x2, y1, z)]
             when :trai then [Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x1, y2, z)]
             when :phai then [Geom::Point3d.new(x2, y1, z), Geom::Point3d.new(x2, y2, z)]
             end
    return unless pts
    view.line_stipple = ""
    view.line_width = 5
    view.drawing_color = side_color(side)
    view.draw(GL_LINES, pts)
  end
  def near_side?(bb, bbox, side, gap2)
    return false unless gap2.to_f > 0
    case side
    when :tren then bb.min.y >= bbox.max.y - gap2
    when :duoi then bb.max.y <= bbox.min.y + gap2
    when :phai then bb.min.x >= bbox.max.x - gap2
    when :trai then bb.max.x <= bbox.min.x + gap2
    end
  end
  def threshold(bb, bbox, side)
    case side
    when :tren then bbox.max.y - bb.max.y
    when :duoi then bb.min.y - bbox.min.y
    when :phai then bbox.max.x - bb.max.x
    when :trai then bb.min.x - bbox.min.x
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
    return [] unless @clearing && @sweeping
    band_parts
  end
  def auto_plan
    return [] unless @auto_hover
    sheet, side = @auto_hover
    rec = KSU::Sheet.record_for(@sheets, sheet)
    return [] unless rec
    parts = @parts.select { |arr2| arr2[:sheet] == sheet }
    plan_side(parts, rec[:bbox], side)
  end
  def button_plan
    arr = @btn_plan
    arr = [@dest] if arr.nil? || arr.empty?
    arr.flat_map do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      next [] unless rec
      parts = @parts.select { |arr3| arr3[:sheet] == sheet }
      plan_all_sides(parts, rec[:bbox])
    end
  end
  def rect_plan
    return [] unless @kieu_chon_tam == 0 && @sweeping
    sweep = sweep_dir
    sweep ? rank_plan(sweep) : []
  end
  def line_plan
    return [] unless @kieu_chon_tam == 1 && @rank_a && @rank_b
    parts = parts_between(@rank_a, @rank_b)
    return [] if parts.empty?
    rank_drag(parts)
  end
  def lasso_plan
    return [] unless @kieu_chon_tam == 2 && @lasso_pts.any?
    pts = lasso_path
    return [] if pts.length < 2
    parts = parts_along(pts)
    return [] if parts.empty?
    rank_free(parts)
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
  def cur_side
    return @side unless @kieu_chon_tam == 0
    dir = sweep_dir
    dir ? side_of(dir) : side_at_cursor
  end
  def side_at_cursor
    return @side unless @cur_pt
    px = @cur_pt.x.to_f
    py = @cur_pt.y.to_f
    rec = @sheets.find do |s|
      bbox = s[:bbox]
      px >= bbox.min.x.to_f && px <= bbox.max.x.to_f && py >= bbox.min.y.to_f && py <= bbox.max.y.to_f
    end
    return @side unless rec
    depths(px, py, rec[:bbox]).min_by { |_part, len2d| len2d }.first
  end
  def draw_color_chip(view)
    return if @che_do != 0
    return if @clearing || @screen_pt.nil? || !@hien_bang_mau || busy?
    return if @kieu_chon_tam == 0
    num3 = @co_bang_mau.to_f
    num4 = 14.0
    x1 = @screen_pt.x.to_f + num4
    y1 = @screen_pt.y.to_f + num4
    x2 = x1 + num3
    y2 = y1 + num3
    view.line_stipple = ""
    if @layer_theo_vung
      thick = num3 / 4.0
      case cur_side
      when :phai then fill_rect2d(view, x2 - thick, y1, x2, y2, @mau_phai)
      when :trai then fill_rect2d(view, x1, y1, x1 + thick, y2, @mau_trai)
      when :tren then fill_rect2d(view, x1, y1, x2, y1 + thick, @mau_tren)
      when :duoi then fill_rect2d(view, x1, y2 - thick, x2, y2, @mau_duoi)
      end
    else
      fill_rect2d(view, x1, y1, x2, y2, @mau_chung)
    end
    view.drawing_color = KSU::View.edge_color
    view.line_width = 1
    view.draw2d(GL_LINE_LOOP, [
      Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x2, y1, 0),
      Geom::Point3d.new(x2, y2, 0), Geom::Point3d.new(x1, y2, 0)
    ])
  end
  def fill_rect2d(view, x1, y1, x2, y2, color)
    view.drawing_color = color
    view.draw2d(GL_TRIANGLES, [
      Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x2, y1, 0), Geom::Point3d.new(x2, y2, 0),
      Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x2, y2, 0), Geom::Point3d.new(x1, y2, 0)
    ])
  end
  def reset_state
    @sweeping = false
    @sweep_a = nil
    @sweep_b = nil
    @sweep_memo = nil
    @track_ids = []
    @rank_a = nil
    @rank_b = nil
    @lasso_pts = []
    @hover_rec = nil
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
    @parts = []
    two_sided_flags = KSU::Nesting.two_sided_set(@nesting)
    @sheets.each do |arr|
      sheet = arr[:instance]
      transform = arr[:transform]
      sheet.definition.entities.each do |panel|
        next unless KSU::Sheet.panel?(panel)
        next if skip_panel?(panel)
        panel_tr = transform * panel.transformation
        bbox = KSU::Geom._c7b0bc62(panel.definition.bounds, panel_tr)
        fill = KSU::Cutting.outline(panel, panel_tr)
        polygon = fill[:outer]
        holes = fill[:holes] || []
        if polygon.nil? || polygon.length < 3
          polygon = KSU::View.top_corners(bbox)
          holes = []
        end
        z = (-0.1).mm
        overlay_polygon = polygon.map { |pt| Geom::Point3d.new(pt.x, pt.y, z) }
        overlay_holes = holes.map { |h| h.map { |pt| Geom::Point3d.new(pt.x, pt.y, z) } }
        @parts << {
          part: panel,
          sheet: sheet,
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
    @dest = nil
    @btn_joint = nil
    @btn_plan = []
    @hover_sheet = nil
    @editing = nil
    @hover_rec = nil
  end
end
class KSU::Chongbay
  def self.read_bindings
    data = {}
    ["k", "i", "t"].each do |key|
      value = Sketchup.read_default("KSU", key, "")
      data[key] = value unless value.to_s.empty?
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
