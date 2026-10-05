class KSU::Xeptam
  include KSU::Preset
  include KSU::Nesting
  tool_key "xep_tam"
  def initialize
    KSU::Chontam.check_license
    KSU::Themtam.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    arr = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @xep_tam_tu_do = !!get("xep_tam_tu_do", false)
    @goc_xoay_van = get("goc_xoay_van", 90)
    @ghi_de_khoang_cach = !!get("ghi_de_khoang_cach", false)
    @tam_cach_nhau_rieng = get("tam_cach_nhau_rieng", 6.5).mm
    @tam_cach_le_rieng = get("tam_cach_le_rieng", 3.5).mm
    mm = @tam_cach_le_rieng.to_mm
    _f9c439db = get("tam_cach_le", 3.5)
    @tach_cach_le = !!get("tach_cach_le", false)
    load_side_margins(_f9c439db)
    @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", _f9c439db).mm
    @tach_cach_le_rieng = !!get("tach_cach_le_rieng", false)
    load_side_margins(mm, "_rieng")
    apply_gaps
    load_overlay_settings
    @flag4 = defined?(KSU::Method) && KSU::Method.respond_to?(:compute_push_back)
    @refine_on = defined?(KSU::Method) && KSU::Method.respond_to?(:contact_refine)
    @flag32 = defined?(KSU::Method) && KSU::Method.respond_to?(:nfp_snap)
    @grid = nil
    @flag43 = KSU::Nesting.respond_to?(:nfp) && KSU::Nesting.respond_to?(:inflate) &&
                        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) && KSU::Clipper.respond_to?(:difference)
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    @sel = []
    @sel_sheets = []
    @flag22 = false
    @flag24 = false
    @pressing = false
    @banding = false
    @down_x = @down_y = @drag_x = @drag_y = nil
    @nesting = nil
    @arr24 = []
    @h15 = {}
    @h14 = {}
    @hit_list = nil
    @h32 = {}
    @dest = nil
    @under = nil
    @vec5 = nil
    @arr41 = []
    @vec4 = nil
    @pt5 = nil
    @pt4 = nil
    @flag5 = false
    @pt2 = nil
    @flag21 = false
    @flag16 = false
    @h26 = {}
    @arr18 = []
    @poly_cache = {}
    @h27 = {}
    @arr25 = []
    @flag29 = nil
    @vec6 = nil
    @hover_side = nil
    @flag40 = false
    @hover_corner = nil
    @hover_edge = nil
    @vec3 = nil
    @flag34 = false
    @flag8 = false
    @flag25 = false
    @flag13 = false
    @sel_polys = nil
    @sel_hull = nil
    @sel_bounds = nil
    @obstacle_cache = {}
    @arr30 = nil
    @outlines = {}
    @free_saved = nil
    @flag14 = false
    @saved_free_mode = nil
    @flag44 = nil
    @drag_offset = nil
    @saved_polys = nil
    @saved_bounds = nil
    @saved_hulls = nil
    @saved_offset = nil
    @saved_outlines = nil
    @arr34 = []
    @arr40 = []
    @flag26 = false
    @arr6 = []
    @arr38 = []
    @arr8 = []
    @avail_key = nil
    @grid_cache = {}
    @flag27 = nil
    @progress = nil
    @str = nil
    @queue = nil
    @opt_sheet = nil
  end
  def activate
    KSU::Chontam.check_license
    KSU::Themtam.assert_license
    @nesting = KSU::Nesting.enter_edit
    unless @nesting
      KSU.select_tool(nil)
      return
    end
    @h24 = {}
    sheet_list(@nesting)
    rebuild_overlaps
    @presets = get("presets", nil)
    setup_fields(
      "Xếp tấm tự do" => {
        xep_tam_tu_do: [:switch, "Xếp tấm tự do"],
      },
      "Góc xoay ván" => {
        goc_xoay_van: [nil, "Góc xoay ván", nil, -360, 360],
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS,
      "Khoảng hở" => {
        ghi_de_khoang_cach: [:switch, "Ghi đè khoảng cách", -> { !@xep_tam_tu_do }],
        tam_cach_nhau: [:mm, "Tấm cách nhau", -> { !@xep_tam_tu_do && !@ghi_de_khoang_cach }, 0, 100]
      }.merge(margin_rows(-> { !@xep_tam_tu_do && !@ghi_de_khoang_cach },
                             -> { !@xep_tam_tu_do && !@ghi_de_khoang_cach && @tach_cach_le }, "", true))
        .merge(tam_cach_nhau_rieng: [:mm, "Tấm cách nhau", -> { !@xep_tam_tu_do && @ghi_de_khoang_cach }, 0, 100])
        .merge(margin_rows(-> { !@xep_tam_tu_do && @ghi_de_khoang_cach },
                              -> { !@xep_tam_tu_do && @ghi_de_khoang_cach && @tach_cach_le_rieng }, "_rieng")),
    )
    load_presets(@presets)
    restore_selected_preset
    KSU::View.on_change("xep_tam") { rebuild_all }
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    KSU::Avail.set_override(nil)
    optimize_cancel
    save_selected_preset
    KSU::View.off_change("xep_tam")
    show_originals
    KSU::Nesting.leave_edit
    view.invalidate
  end
  def apply_preset(s)
    apply_settings(s)
    apply_gaps
    @nfp_memo = {}
  end
  def apply_gaps
    @tam_cach_nhau = @ghi_de_khoang_cach ? @tam_cach_nhau_rieng : get("tam_cach_nhau", 6.5).mm
    @tam_cach_le = @ghi_de_khoang_cach ? @tam_cach_le_rieng : get("tam_cach_le", 3.5).mm
    screen_box = if @ghi_de_khoang_cach && @tach_cach_le_rieng
        [@tam_cach_le_trai_rieng.to_f, @tam_cach_le_phai_rieng.to_f,
         @tam_cach_le_tren_rieng.to_f, @tam_cach_le_duoi_rieng.to_f]
      end
    KSU::Avail.set_override(screen_box)
  end
  def set(key, val)
    super
    return unless %w[ghi_de_khoang_cach tam_cach_nhau tam_cach_le tam_cach_nhau_rieng tam_cach_le_rieng
                     tach_cach_le tam_cach_le_trai tam_cach_le_phai tam_cach_le_tren tam_cach_le_duoi
                     tach_cach_le_rieng tam_cach_le_trai_rieng tam_cach_le_phai_rieng
                     tam_cach_le_tren_rieng tam_cach_le_duoi_rieng tam_cach_le_hai_mat].include?(key.to_s)
    apply_gaps
    @nfp_memo = {}
    @obstacle_cache = {}
    clear_grid_cache
  end
  def reload_settings
    super
    apply_gaps
    @nfp_memo = {}
    @obstacle_cache = {}
    clear_grid_cache
  end
  def rebuild_all
    if @flag13
      @flag13 = false
      return
    end
    return if @flag22
    return unless @nesting && @nesting.valid?
    keep_existing = @sel.each_index.select { |i| @sel[i] && @sel[i].valid? }
    @sel = keep_existing.map { |i| @sel[i] }
    @sel_sheets = keep_existing.map { |i| @sel_sheets[i] }
    @flag29 = nil unless @flag29 && @flag29.valid?
    sheet_list(@nesting)
    rebuild_overlaps
  end
  def resume(view)
    KSU::View.load_colors
    view.invalidate
    update_status
  end
  def onSetCursor
    if @vec3 && @vec3.valid?
      UI.set_cursor(643)
      true
    elsif @flag22 || (@vec5 && @vec5.valid?)
      UI.set_cursor(641)
      true
    else
      false
    end
  end
  def enableVCB?
    true
  end
  def update_status
    KSU.set_status(
      "Nhấn Tab để xoay. Nhấn Ctrl để group hoặc bỏ group tấm. Giữ Shift để khóa trục khi kéo. " \
      "Giữ Alt để xếp tự do. Nhấn Mũi tên để căn lề hoặc thay đổi vị trí ván."
    )
    KSU.set_vcb("Tấm cách nhau", Sketchup.format_length(@tam_cach_nhau))
  end
  def onUserText(text, view)
    len = (text.to_l rescue nil)
    unless len
      UI.beep
      update_status
      return
    end
    num = len.to_mm.to_f
    return if num < 0
    if @ghi_de_khoang_cach
      @tam_cach_nhau_rieng = num.mm
      set("tam_cach_nhau_rieng", num)
    else
      @tam_cach_nhau = num.mm
      set("tam_cach_nhau", num)
    end
    update_status
    view.invalidate
  end
  def onKeyDown(key, repeat, rot, view)
    return if @progress
    if key == COPY_MODIFIER_KEY
      unless @flag8
        @flag8 = true
        @flag25 = @flag22 || @pressing || @banding
      end
    else
      @flag25 = true
    end
    if key == 192
      KSU::Settings.open_settings("xep_tam")
      return
    end
    if key == CONSTRAIN_MODIFIER_KEY
      @flag5 = true
      @pt2 = @pt5 if @flag22
      view.invalidate
      return
    end
    if key == ALT_MODIFIER_KEY
      if @free_saved.nil?
        @free_saved = @xep_tam_tu_do
        @xep_tam_tu_do = true
        drag_follow if @flag22
        view.invalidate
      end
      return
    end
    if @flag29 && @flag29.valid? && @sel.empty? &&
       !KSU::Sheet.hidden?(@flag29)
      case key
      when VK_LEFT, VK_RIGHT
        jump = @flag5 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
        reorder_sheet(key == VK_LEFT ? (jump ? :first : :prev) : (jump ? :last : :next))
        view.invalidate
        return
      when VK_UP, VK_DOWN
        swap_sheet_type(key == VK_UP ? :up : :down)
        view.invalidate
        return
      end
    end
    return if @sel.empty?
    if key == 9
      rotate_sel(@goc_xoay_van.degrees)
      return
    end
    side = { VK_LEFT => :left, VK_RIGHT => :right, VK_UP => :top, VK_DOWN => :bottom }[key]
    align_side(side) if side && @sel.length >= 2
  end
  def onKeyUp(key, repeat, rot, view)
    if key == COPY_MODIFIER_KEY
      was_drag = @flag8 && !@flag25
      @flag8 = false
      if was_drag && !@progress && !@flag22 && !@pressing && !@banding
        toggle_group
        view.invalidate
      end
    elsif key == CONSTRAIN_MODIFIER_KEY
      @flag5 = false
      view.invalidate
    elsif key == ALT_MODIFIER_KEY && !@free_saved.nil?
      @xep_tam_tu_do = @free_saved
      @free_saved = nil
      save_drag_state if @flag22
      view.invalidate
    end
  end
  def onReturn(view)
    return if @progress || @flag22
    return unless @sel.empty?
    return unless @flag29 && @flag29.valid?
    return if KSU::Sheet.hidden?(@flag29)
    optimize_sheet(@flag29)
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if @progress
    @flag25 = true
    if click_field(x, y, view) || click_outside(x, y, view)
      @flag34 = true
      return
    end
    panel = panel_at(view, x, y)
    if panel
      rebuild_all if KSU::Flip.flip_pair(@nesting, panel)
      update_hover_sheets(x, y, view)
      onSetCursor
      @flag34 = true
      view.invalidate
      return
    end
    if @flag29 && @flag29.valid?
      _945ac34d = true
      if (side = hit_side_button(view, x, y))
        move_sheet(side)
      elsif hit_delete_button(view, x, y)
        delete_sheet
      elsif (_963558a9 = corner_handle_at(view, x, y))
        pick_edge(_963558a9, false) unless KSU::Sheet.hidden?(@flag29)
      elsif (edge_ix = edge_handle_at(view, x, y))
        pick_edge(edge_ix, true) unless KSU::Sheet.hidden?(@flag29)
      else
        _945ac34d = false
      end
      if _945ac34d
        @flag34 = true
        update_status
        view.invalidate
        return
      end
    end
    @down_x, @down_y = x, y
    @pressing = true
    @banding = false
    @flag16 = (rot & COPY_MODIFIER_MASK) != 0 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
    @nesting ||= KSU::Nesting.find_nesting
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    @pressing = false
    if @flag34
      @flag34 = false
      view.invalidate
      return
    end
    if @banding
      arr = panels_in_box(view, @down_x, @down_y, x, y)
      if arr.any?
        select_many(arr)
        @flag29 = nil
      elsif !@flag16
        @sel = []
        @sel_sheets = []
        @flag29 = nil
      end
      @banding = false
    elsif @flag22
      drag_end
    else
      ok = pick_panel_at(view, x, y)
      if ok
        select_one(ok)
        @flag29 = @sel.size == 1 ? @sel_sheets[0] : nil
      else
        _e53ca5e7 = sheet_at2(view, x, y)
        if _e53ca5e7 || !@flag16
          @sel = []
          @sel_sheets = []
          @flag29 = _e53ca5e7
        end
      end
    end
    update_status
    view.invalidate
  end
  def onMouseMove(rot, x, y, view)
    if @banding
      @drag_x, @drag_y = x, y
      view.invalidate
      return
    end
    hover_preset(x, y, view)
    return if hover_field(x, y, view) && !@pressing && !@flag22
    update_hover_sheets(x, y, view) unless @pressing || @flag22
    if @pressing && !@flag22 && ((x - @down_x).abs > 3 || (y - @down_y).abs > 3)
      ok = pick_panel_at(view, @down_x, @down_y)
      if @sel.any? && ok && @sel.include?(ok[:panel])
        drag_begin(view, @down_x, @down_y)
      elsif ok
        @sel = [ok[:panel]]
        @sel_sheets = [ok[:sheet]]
        ungroup_selection
        drag_begin(view, @down_x, @down_y)
      else
        @banding = true
        @vec5 = @vec4 = @vec6 = nil
      end
    end
    return unless @flag22 && @sel.any?
    @pt5 = @pt4 && KSU::View.pick_on_plane(view, x, y, @pt4.z)
    return unless @pt5
    pt = if @flag5 && @pt2
        dx = (@pt5.x - @pt2.x).abs
        dy = (@pt5.y - @pt2.y).abs
        if dx >= dy
          Geom::Point3d.new(@pt5.x, @pt2.y, @pt2.z)
        else
          Geom::Point3d.new(@pt2.x, @pt5.y, @pt2.z)
        end
      else
        @pt5
      end
    arr = pt - @pt4
    return if arr.length < 1e-9
    prev_pt = @pt4
    shift_by(arr)
    @pt4 = pt
    if @flag24
      @flag21 = false
      view.invalidate
      return
    end
    cur_rec = record_for(@sel_sheets.first)
    inst6 = @dest && @dest[:instance]
    was_free = @flag26
    flag = @flag5 ? nil : @arr24.find do |s|
      !KSU::Sheet.hidden?(s[:instance]) && s[:bbox].contains?(@pt5)
    end
    @under = flag
    if @flag26
      if flag
        @flag26 = false if fits_on?(flag)
        @dest = flag
      else
        @dest = cur_rec
      end
    elsif flag
      @dest = flag
    elsif @xep_tam_tu_do
      @dest = cur_rec
    else
      _f515d7f8, dist = nearest_sheet(@pt5)
      if dist && dist > 0.0
        @flag26 = true
        @dest = cur_rec
      else
        @dest = _f515d7f8 || cur_rec
      end
    end
    went_free = @flag26 && !was_free
    if went_free || (@dest && @dest[:instance]) != inst6
      restore_free_mode
      drag_follow if went_free
      save_drag_state
    end
    dest = @dest || cur_rec
    crossed = !!(flag && cur_rec && flag[:instance] != cur_rec[:instance])
    if dest
      begin
        if @flag26
          @flag21 = true
        elsif @flag5 || @xep_tam_tu_do
          cap = fits_on?(dest)
          @flag21 = !cap
          restore_free_mode if cap && @flag14
        else
          arr2 = nfp_for(dest)
          if arr2 && arr2[:valid]
            shift_nfp(arr2, arr)
            build_grid(dest)
            @flag21 = false
          else
            esc = escape_hole(dest)
            shift_by(esc) if esc
            arr3 = compute_push_back(dest)
            if arr3.length.to_f >= KSU::TOL
              shift_by(arr3)
              push_back(dest, arr, arr3)
              if compute_push_back(dest).length.to_f < KSU::TOL
                build_grid(dest)
                @flag21 = false
              elsif crossed
                force_free_mode
                @flag21 = false
              else
                @flag21 = true
              end
            else
              build_grid(dest)
              @flag21 = false
            end
          end
        end
      rescue
        @flag21 = false
      end
    end
    _304b45a2 = !@xep_tam_tu_do && !@flag26 && dest && hits_border?(dest)
    if (@flag21 || _304b45a2) && !@xep_tam_tu_do && !@flag26
      if _304b45a2 || !@flag19
        restore_drag_state
        @pt4 = prev_pt
        @flag21 = false
      end
    else
      @flag19 = false
      save_drag_state
    end
    rebuild_preview
    view.invalidate
  end
  def draw(view)
    check_dirty
    KSU::View.draw_faces(@nesting, skip: skip, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr6, color: KSU::View.warn_color, line: false) if @arr6 && @arr6.any?
    KSU::View.draw_error_dots(view, @arr38) if @danh_dau_loi
    if @danh_dau_tam_bi_lan && !@flag22
      refresh_avail
      KSU::View.draw_polys(@arr8, color: KSU::View.warn_color, line: false) if @arr8.any?
    end
    KSU::Sheet.draw_borders(view, @nesting)
    draw_rect2d(view) if @banding
    edge = KSU::View.edge_color
    mat = KSU::View.face_color
    warn = KSU::View.warning_color
    warning_face_color = KSU::View.warn_color
    if @vec5 && @vec5.valid? && !@flag22 &&
       (@vec4.nil? || @vec4.valid?) &&
       !@sel.include?(@vec5)
      arr4 = [[@vec5, @vec4]] + @arr41
      arr4.each do |vec, vec3|
        next unless vec && vec.valid?
        next if vec3 && !vec3.valid?
        next if @sel.include?(vec)
        draw_panel_fill(vec, vec3, mat)
        partner_of = partner_of2(vec)
        next unless partner_of && partner_of.valid?
        arr2 = rec_by_def(partner_of.parent)
        draw_panel_fill(partner_of, arr2[:instance], mat) if arr2
      end
    end
    _767745e5 = @flag22 && @flag21
    flag2 = _767745e5 ? warn : edge
    color = _767745e5 ? warning_face_color : mat
    if @sel.any?
      if @sel_polys
        stroke_loops(@sel_polys, flag2)
      else
        @sel.each_with_index do |panel3, ix|
          next unless panel3 && panel3.valid?
          vec2 = @sel_sheets[ix]
          next if vec2 && !vec2.valid?
          draw_panel_fill(panel3, vec2, color, flag2)
        end
      end
    end
    draw_thick_outline(@under, @flag21 ? warning_face_color : mat) if @under && @flag22
    mat2 = Sketchup::Color.new(mat.red, mat.green, mat.blue, [mat.alpha * 3, 255].min)
    mat4 = Sketchup::Color.new(warn.red, warn.green, warn.blue, [mat.alpha * 3, 255].min)
    mat3 = Sketchup::Color.new(warn.red, warn.green, warn.blue, mat.alpha)
    if @flag29 && @flag29.valid?
      arr = record_for(@flag29)
      if arr
        if KSU::Sheet.hidden?(@flag29)
          draw_thick_outline(arr, mat4)
          KSU::View.draw_brackets(view, arr[:top_corners], color: warn, active: KSU::Sheet.corner_index(@flag29, @nesting)) { |i| @hover_corner == i }
        else
          draw_thick_outline(arr, mat2)
          KSU::View.draw_brackets(view, arr[:top_corners]) { |i| @hover_corner == i }
          KSU::View.draw_corner_handles(view, arr[:top_corners]) { |i| @hover_edge == i }
          draw_side_buttons(view, arr)
          KSU::View.draw_warn_button(view, KSU::View.center_of(arr[:top_corners]), hover: @flag40) if KSU::Sheet.empty?(@flag29)
        end
      end
    end
    if @vec6 && @vec6.valid? && !@flag22 &&
       @vec6 != @flag29
      sheet_rec = record_for(@vec6)
      draw_thick_outline(sheet_rec, KSU::Sheet.hidden?(@vec6) ? mat3 : mat) if sheet_rec
    end
    unless @sel.empty? || @arr18.empty?
      arr3 = []
      @sel.each do |panel3|
        partner_of = partner_of2(panel3)
        next unless partner_of && partner_of.valid?
        next if @sel.include?(partner_of)
        next if @arr34.any? { |panel| panel[:front] == panel3 }
        flag = @flag22 ? @outlines[partner_of.object_id] : nil
        unless flag && flag.length >= 3
          rec = rec_by_def(partner_of.parent)
          next unless rec
          next draw_panel_fill(partner_of, rec[:instance], color, flag2) unless @flag22
          flag = outer_pts_of(partner_of, rec[:instance])
          next if flag.length < 3
          @outlines[partner_of.object_id] = flag
        end
        arr3 << flag
      end
      stroke_loops(arr3, flag2)
    end
    draw_mirror_preview(view) if @flag22
    draw_hover unless @flag22
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@progress}%") if @progress
  end
end
class KSU::Xeptam
  def self.license_gate
    key = KSU::Gannhan.license_field("k").to_s
    return false if key.empty?
    KSU::Catcuoi.rebind_license
    return false unless KSU::Engine.license_ok?
    KSU::Assign.activate_here(key)
  rescue
    false
  end
end
class KSU::Xeptam
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
