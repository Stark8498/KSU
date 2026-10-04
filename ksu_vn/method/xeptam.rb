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
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @xep_tam_tu_do = !!get("xep_tam_tu_do", false)
    @goc_xoay_van = get("goc_xoay_van", 90).to_i
    @ghi_de_khoang_cach = !!get("ghi_de_khoang_cach", false)
    @tam_cach_nhau_rieng = get("tam_cach_nhau_rieng", 6.5).to_f.mm
    @tam_cach_le_rieng = get("tam_cach_le_rieng", 3.5).to_f.mm
    mm = @tam_cach_le_rieng.to_mm
    num = get("tam_cach_le", 3.5).to_f
    @tach_cach_le = !!get("tach_cach_le", false)
    load_side_margins(num)
    @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", num).to_f.mm
    @tach_cach_le_rieng = !!get("tach_cach_le_rieng", false)
    load_side_margins(mm, "_rieng")
    apply_gaps
    load_overlay_settings
    @label_section_hidden = []
    @flag15 = defined?(KSU::Method) && KSU::Method.respond_to?(:polygons_overlap?)
    @flag27 = defined?(KSU::Method) && KSU::Method.respond_to?(:compute_push_back)
    @refine_on = defined?(KSU::Method) && KSU::Method.respond_to?(:contact_refine)
    @flag2 = defined?(KSU::Method) && KSU::Method.respond_to?(:nfp_snap)
    @grid = nil
    @flag54 = defined?(KSU::Nesting) && KSU::Nesting.respond_to?(:nfp) && KSU::Nesting.respond_to?(:inflate) &&
                        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) && KSU::Clipper.respond_to?(:difference)
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    @sel = []
    @sel_sheets = []
    @flag56 = false
    @flag45 = false
    @pressing = false
    @banding = false
    @down_x = @down_y = @drag_x = @drag_y = nil
    @nesting = nil
    @arr23 = []
    @h14 = {}
    @h25 = {}
    @hit_list = nil
    @h6 = {}
    @dest = nil
    @under = nil
    @panel = nil
    @arr41 = []
    @sheet4 = nil
    @pt5 = nil
    @pt14 = nil
    @flag25 = false
    @pt7 = nil
    @flag21 = false
    @flag5 = false
    @h11 = {}
    @arr28 = []
    @poly_cache = {}
    @h24 = {}
    @arr2 = []
    @flag37 = nil
    @sheet = nil
    @hover_side = nil
    @flag12 = false
    @hover_corner = nil
    @hover_edge = nil
    @vec3 = nil
    @flag38 = false
    @flag30 = false
    @flag52 = false
    @flag36 = false
    @sel_polys = nil
    @sel_hull = nil
    @sel_bounds = nil
    @obstacle_cache = {}
    @arr3 = nil
    @outlines = {}
    @free_saved = nil
    @flag4 = false
    @saved_free_mode = nil
    @pt3 = nil
    @drag_offset = nil
    @saved_polys = nil
    @saved_bounds = nil
    @saved_hulls = nil
    @saved_offset = nil
    @saved_outlines = nil
    @arr57 = []
    @arr33 = []
    @flag50 = false
    @overlap_fills = []
    @err_pts = []
    @arr18 = []
    @avail_key = nil
    @grid_cache = {}
    @flag11 = nil
    @progress = nil
    @str = nil
    @queue = nil
    @opt_sheet = nil
    if Sketchup.active_model.tools.active_tool == self
      @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    end
  end
  def activate
    KSU::Chontam.check_license
    KSU::Themtam.assert_license
    @nesting = KSU::Nesting.enter_edit
    unless @nesting
      KSU.select_tool(nil)
      return
    end
    @h4 = {}
    sheet_list(@nesting)
    refresh_state
    clear_grid_cache
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
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
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
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view.invalidate
  end
  def apply_preset(s)
    apply_settings(s)
    apply_gaps
    @nfp_memo = {}
  end
  def apply_gaps
    @tam_cach_nhau = @ghi_de_khoang_cach ? @tam_cach_nhau_rieng : get("tam_cach_nhau", 6.5).to_f.mm
    @tam_cach_le = @ghi_de_khoang_cach ? @tam_cach_le_rieng : get("tam_cach_le", 3.5).to_f.mm
    screen_box = if @ghi_de_khoang_cach && @tach_cach_le_rieng
        [@tam_cach_le_trai_rieng.to_f, @tam_cach_le_phai_rieng.to_f,
         @tam_cach_le_tren_rieng.to_f, @tam_cach_le_duoi_rieng.to_f]
      end
    KSU::Avail.set_override(screen_box)
  end
  def set(key, value)
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
    if @flag36
      @flag36 = false
      return
    end
    return if @flag56
    return unless @nesting && @nesting.valid?
    keep_existing = @sel.each_index.select { |i| @sel[i] && @sel[i].valid? }
    @sel = keep_existing.map { |i| @sel[i] }
    @sel_sheets = keep_existing.map { |i| @sel_sheets[i] }
    @flag37 = nil unless @flag37 && @flag37.valid?
    sheet_list(@nesting)
    refresh_state
  end
  def resume(view)
    KSU::View.load_colors
    view.invalidate
    update_status
  end
  def onSetCursor
    if @vec3 && @vec3.valid?
      UI.set_cursor(KSU::Const::CURSOR_ORBIT)
      true
    elsif @flag56 || (@panel && @panel.valid?)
      UI.set_cursor(KSU::Const::CURSOR_MOVE)
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
    len = begin
        text.to_l
      rescue StandardError
        nil
      end
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
      unless @flag30
        @flag30 = true
        @flag52 = @flag56 || @pressing || @banding
      end
    else
      @flag52 = true
    end
    if key == 192
      KSU::Settings.open_settings("xep_tam") if defined?(KSU::Settings)
      return
    end
    if key == CONSTRAIN_MODIFIER_KEY
      @flag25 = true
      @pt7 = @pt5 if @flag56
      view.invalidate
      return
    end
    if key == ALT_MODIFIER_KEY
      if @free_saved.nil?
        @free_saved = @xep_tam_tu_do
        @xep_tam_tu_do = true
        drag_follow if @flag56
        view.invalidate
      end
      return
    end
    if @flag37 && @flag37.valid? && @sel.empty? &&
       !KSU::Sheet.hidden?(@flag37)
      case key
      when VK_LEFT, VK_RIGHT
        jump = @flag25 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
        dir = if key == VK_LEFT
            jump ? :first : :prev
          else
            jump ? :last : :next
          end
        reorder_sheet(dir)
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
    if @sel.length >= 2
      case key
      when VK_LEFT then _2bff4638(:left)
      when VK_RIGHT then _2bff4638(:right)
      when VK_UP then _2bff4638(:top)
      when VK_DOWN then _2bff4638(:bottom)
      else return
      end
    end
  end
  def onKeyUp(key, repeat, rot, view)
    if key == COPY_MODIFIER_KEY
      was_drag = @flag30 && !@flag52
      @flag30 = false
      if was_drag && !@progress && !@flag56 && !@pressing && !@banding
        toggle_group
        view.invalidate
      end
    elsif key == CONSTRAIN_MODIFIER_KEY
      @flag25 = false
      view.invalidate
    elsif key == ALT_MODIFIER_KEY && !@free_saved.nil?
      @xep_tam_tu_do = @free_saved
      @free_saved = nil
      save_drag_state if @flag56
      view.invalidate
    end
  end
  def onReturn(view)
    return if @progress
    return if @flag56
    return unless @sel.empty?
    return unless @flag37 && @flag37.valid?
    return if KSU::Sheet.hidden?(@flag37)
    optimize_sheet(@flag37)
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if @progress
    @flag52 = true
    if click_field(x, y, view)
      @flag38 = true
      return
    end
    if click_outside(x, y, view)
      @flag38 = true
      return
    end
    panel = panel_at(view, x, y)
    if panel
      flip_panel(panel)
      update_hover_sheets(x, y, view)
      onSetCursor
      @flag38 = true
      view.invalidate
      return
    end
    if @flag37 && @flag37.valid?
      side = hit_side_button(view, x, y)
      if side
        move_sheet(side)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      if hit_delete_button(view, x, y)
        delete_sheet
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      corner = corner_handle_at(view, x, y)
      if corner
        snap_to_corner(corner) unless KSU::Sheet.hidden?(@flag37)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      edge_ix = edge_handle_at(view, x, y)
      if edge_ix
        snap_to_edge(edge_ix) unless KSU::Sheet.hidden?(@flag37)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
    end
    @down_x, @down_y = x, y
    @pressing = true
    @banding = false
    @flag5 = (rot & COPY_MODIFIER_MASK) != 0 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
    @nesting ||= KSU::Nesting.find_nesting
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    @pressing = false
    if @flag38
      @flag38 = false
      view.invalidate
      return
    end
    if @banding
      arr = panels_in_box(view, @down_x, @down_y, x, y)
      if arr.any?
        select_many(arr)
        @flag37 = nil
      elsif !@flag5
        @sel = []
        @sel_sheets = []
        @flag37 = nil
      end
      @banding = false
    elsif @flag56
      drag_end
    else
      answer = _b01ddcaf(view, x, y)
      if answer
        select_one(answer)
        @flag37 = @sel.size == 1 ? @sel_sheets[0] : nil
      else
        sheet = sheet_at2(view, x, y)
        if sheet
          @sel = []
          @sel_sheets = []
          @flag37 = sheet
        elsif !@flag5
          @sel = []
          @sel_sheets = []
          @flag37 = nil
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
    return if hover_field(x, y, view) && !@pressing && !@flag56
    update_hover_sheets(x, y, view) unless @pressing || @flag56
    if @pressing && !@flag56
      dx = (x - @down_x).abs
      dy = (y - @down_y).abs
      if dx > 3 || dy > 3
        answer = _b01ddcaf(view, @down_x, @down_y)
        if @sel.any? && answer && @sel.include?(answer[:panel])
          drag_begin(view, @down_x, @down_y)
        elsif answer
          @sel = [answer[:panel]]
          @sel_sheets = [answer[:sheet]]
          expand_selection
          drag_begin(view, @down_x, @down_y)
        else
          @banding = true
          @panel = @sheet4 = @sheet = nil
        end
      end
    end
    return unless @flag56 && @sel.any?
    @pt5 = drag_plane_point(view, x, y)
    return unless @pt5
    pt = if @flag25 && @pt7
        dx = (@pt5.x - @pt7.x).abs
        dy = (@pt5.y - @pt7.y).abs
        if dx >= dy
          Geom::Point3d.new(@pt5.x, @pt7.y, @pt7.z)
        else
          Geom::Point3d.new(@pt7.x, @pt5.y, @pt7.z)
        end
      else
        @pt5
      end
    vec = pt - @pt14
    return if vec.length < 1e-9
    prev_pt = @pt14
    add_offset(vec)
    shift_cached_polys(vec)
    @pt14 = pt
    if @flag45
      @flag21 = false
      view.invalidate
      return
    end
    arr = record_for(@sel_sheets.first)
    inst6 = @dest && @dest[:instance]
    was_free = @flag50
    flag = @flag25 ? nil : @arr23.find do |s|
      !KSU::Sheet.hidden?(s[:instance]) && s[:bbox].contains?(@pt5)
    end
    @under = flag
    if @flag50
      if flag
        @flag50 = false if fits_on?(flag)
        @dest = flag
      else
        @dest = arr
      end
    elsif flag
      @dest = flag
    elsif @xep_tam_tu_do
      @dest = arr
    else
      near, dist = nearest_sheet(@pt5)
      if dist && dist > 0.0
        @flag50 = true
        @dest = arr
      else
        @dest = near || arr
      end
    end
    went_free = @flag50 && !was_free
    if went_free || (@dest && @dest[:instance]) != inst6
      restore_free_mode
      drag_follow if went_free
      save_drag_state
    end
    dest = @dest || arr
    crossed = !!(flag && arr && flag[:instance] != arr[:instance])
    if dest
      begin
        if @flag50
          @flag21 = true
        elsif @flag25 || @xep_tam_tu_do
          cap = fits_on?(dest)
          @flag21 = !cap
          restore_free_mode if cap && @flag4
        else
          arr5 = nfp_for(dest)
          if arr5 && arr5[:valid]
            shift_nfp(arr5, vec)
            build_grid(dest)
            @flag21 = false
          else
            esc = escape_hole(dest)
            if esc
              add_offset(esc)
              shift_cached_polys(esc)
            end
            arr4 = compute_push_back(dest, true)
            if arr4.length.to_f >= KSU::TOL
              add_offset(arr4)
              shift_cached_polys(arr4)
              _63b8ba0b(dest, vec, arr4)
              if compute_push_back(dest, true).length.to_f < KSU::TOL
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
    on_border = !@xep_tam_tu_do && !@flag50 && dest && hits_border?(dest)
    if (@flag21 || on_border) && !@xep_tam_tu_do && !@flag50
      if on_border || !@flag33
        restore_drag_state
        @pt14 = prev_pt
        @flag21 = false
      end
    else
      @flag33 = false
      save_drag_state
    end
    rebuild_preview
    view.invalidate
  end
  def draw(view)
    check_dirty
    KSU::View.draw_faces(@nesting, skip: skip, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@overlap_fills, color: KSU::View.warn_color, line: false) if @overlap_fills && @overlap_fills.any?
    KSU::View.draw_error_dots(view, @err_pts) if @danh_dau_loi
    if @danh_dau_tam_bi_lan && !@flag56
      refresh_avail
      KSU::View.draw_polys(@arr18, color: KSU::View.warn_color, line: false) if @arr18.any?
    end
    KSU::Sheet.draw_borders(view, @nesting)
    draw_rect2d(view) if @banding
    edge = KSU::View.edge_color
    mat = KSU::View.face_color
    warn = KSU::View.warning_color
    warning_face_color = KSU::View.warn_color
    if @panel2 && @panel2.valid? && !@flag56 &&
       (@sheet4.nil? || @sheet4.valid?) &&
       !@sel.include?(@panel2)
      arr5 = [[@panel2, @sheet4]] + @arr41
      arr5.each do |vec, vec2|
        next unless vec && vec.valid?
        next if vec2 && !vec2.valid?
        next if @sel.include?(vec)
        draw_panel_fill(vec, vec2, mat)
        partner_of = partner_of2(vec)
        next unless partner_of && partner_of.valid?
        arr3 = rec_by_def(partner_of.parent)
        draw_panel_fill(partner_of, arr3[:instance], mat) if arr3
      end
    end
    if @sel.any?
      warn_on = @flag56 && @flag21
      flag = warn_on ? warn : edge
      color = warn_on ? warning_face_color : mat
      if @sel_polys
        stroke_loops(@sel_polys, flag)
      else
        @sel.each_with_index do |panel, ix|
          next unless panel && panel.valid?
          sheet = @sel_sheets[ix]
          next if sheet && !sheet.valid?
          draw_panel_fill(panel, sheet, color, flag)
        end
      end
    end
    draw_thick_outline(@under, @flag21 ? warning_face_color : mat) if @under && @flag56
    mat3 = Sketchup::Color.new(mat.red, mat.green, mat.blue, [mat.alpha * 3, 255].min)
    mat4 = Sketchup::Color.new(warn.red, warn.green, warn.blue, [mat.alpha * 3, 255].min)
    mat2 = Sketchup::Color.new(warn.red, warn.green, warn.blue, mat.alpha)
    if @flag37 && @flag37.valid?
      arr = record_for(@flag37)
      if arr
        if KSU::Sheet.hidden?(@flag37)
          draw_thick_outline(arr, mat4)
          KSU::View.draw_brackets(view, arr[:top_corners], color: warn, active: KSU::Sheet.corner_index(@flag37, @nesting)) { |i| @hover_corner == i }
        else
          draw_thick_outline(arr, mat3)
          KSU::View.draw_brackets(view, arr[:top_corners]) { |i| @hover_corner == i }
          KSU::View.draw_corner_handles(view, arr[:top_corners]) { |i| @hover_edge == i }
          draw_side_buttons(view, arr)
          KSU::View.draw_warn_button(view, KSU::View.center_of(arr[:top_corners]), hover: @flag12) if KSU::Sheet.empty?(@flag37)
        end
      end
    end
    if @sheet && @sheet.valid? && !@flag56 &&
       @sheet != @flag37
      sheet_rec = record_for(@sheet)
      draw_thick_outline(sheet_rec, KSU::Sheet.hidden?(@sheet) ? mat2 : mat) if sheet_rec
    end
    unless @sel.empty? || @arr28.empty?
      warn_bot = @flag56 && @flag21
      flag3 = warn_bot ? warning_face_color : mat
      flag2 = warn_bot ? warn : edge
      if @flag56
        arr4 = []
        @sel.each do |panel|
          partner_of = partner_of2(panel)
          next unless partner_of && partner_of.valid?
          next if @sel.include?(partner_of)
          next if @arr57.any? { |panel3| panel3[:front] == panel }
          pts = @outlines[partner_of.object_id]
          unless pts && pts.length >= 3
            rec = rec_by_def(partner_of.parent)
            next unless rec
            pts = outer_pts_of(partner_of, rec[:instance])
            next if pts.length < 3
            @outlines[partner_of.object_id] = pts
          end
          arr4 << pts
        end
        stroke_loops(arr4, flag2)
      else
        @sel.each do |panel|
          partner_of = partner_of2(panel)
          next unless partner_of && partner_of.valid?
          next if @sel.include?(partner_of)
          next if @arr57.any? { |panel3| panel3[:front] == panel }
          rec = rec_by_def(partner_of.parent)
          next unless rec
          draw_panel_fill(partner_of, rec[:instance], flag3, flag2)
        end
      end
    end
    _f42544d1(view) if @flag56
    draw_hover(view) unless @flag56
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@progress}%") if @progress
  end
end
class KSU::Xeptam
  def self._3d509e12
    key = KSU::Gannhan.license_field("k").to_s
    return false if key.empty?
    KSU::Netcatcuoi.rebind_license
    return false unless KSU::Engine._45e9b533
    KSU::Assign._91d00075(key)
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
