module KSU::Drag
  private
  def corner_handle_at(view, x, y)
    return nil unless @flag37 && @flag37.valid?
    rec = record_for(@flag37)
    return nil unless rec
    KSU::View.bracket_hit(view, rec[:top_corners], x, y)
  end
  def edge_handle_at(view, x, y)
    return nil unless @flag37 && @flag37.valid?
    rec = record_for(@flag37)
    return nil unless rec
    KSU::View.edge_hit(view, rec[:top_corners], x, y)
  end
  def snap_to_corner(corner)
    return unless @flag37 && @flag37.valid?
    rec = record_for(@flag37)
    return unless rec
    KSU.start
    bbox = KSU::Nesting.pack_to_corner(@nesting, @flag37, rec, corner, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
    KSU.commit
    return if bbox.empty?
    after_snap(bbox)
  rescue StandardError
    KSU.abort_op
  end
  def after_snap(bbox)
    bbox = bbox.uniq
    drop_panel_cache(bbox)
    refresh_after_move(bbox, sheets_of(bbox))
    rebuild_outlines
  end
  def snap_to_edge(edge_ix)
    return unless @flag37 && @flag37.valid?
    rec = record_for(@flag37)
    return unless rec
    KSU.start
    bbox = KSU::Nesting.pack_to_edge(@nesting, @flag37, rec, edge_ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
    KSU.commit
    return if bbox.empty?
    after_snap(bbox)
  rescue StandardError
    KSU.abort_op
  end
  def optimize_sheet(sheet)
    return unless @nesting && @nesting.valid?
    return unless sheet && sheet.valid?
    return if @progress
    @flag10 = false
    @flag46 = false
    load_optimize_settings
    reload_sheets
    groups = { KSU::Sheet._7b0a38ee(sheet) => [sheet] }
    unless defined?(KSU::Nesting::Engine)
      @added = []
      run(groups)
      refresh_after_optimize(sheet)
      return
    end
    @opt_sheet = sheet
    @added = []
    @queue = groups.values
    @progress = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    optimize_next
  rescue StandardError => ent
    KSU.abort_op
    @progress = nil
    @str = nil
    @queue = nil
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def load_optimize_settings
    @thu_tu_don = KSU::Settings.get("thu_tu_don", "mac_dinh", "toi_uu_van").to_s
    @tach_nhom_2_mat = !!KSU::Settings.get("tach_nhom_2_mat", true, "toi_uu_van")
    @don_ve_dau_hang = !!KSU::Settings.get("don_ve_dau_hang", true, "toi_uu_van")
    @goc_don_van = KSU::Settings.get("goc_don_van", "trai_duoi", "toi_uu_van").to_s
    @cho_phep_xoay = !!KSU::Settings.get("cho_phep_xoay", false, "toi_uu_van")
    @xoay_theo_tu_khoa = !!KSU::Settings.get("xoay_theo_tu_khoa", false, "toi_uu_van")
    @danh_sach_tu_khoa = KSU::Settings.get("danh_sach_tu_khoa", "XƯƠNG, XÀ, GIẰNG, CHẶN", "toi_uu_van").to_s
    @xoay_theo_vat_lieu = !!KSU::Settings.get("xoay_theo_vat_lieu", false, "toi_uu_van")
    @danh_sach_vat_lieu = KSU::Settings.get("danh_sach_vat_lieu", "TRƠN, TRẮNG, XANH, HỒNG", "toi_uu_van").to_s
  end
  def optimize_next
    if @queue.nil? || @queue.empty?
      optimize_done
      return
    end
    sheets = @queue.shift
    pack_batch(sheets)
  end
  def optimize_done
    @progress = nil
    @str = nil
    @queue = nil
    drop_empty_sheets
    arr = ([@opt_sheet] + @added.to_a).select { |s| s && s.valid? }.uniq
    unless arr.empty?
      KSU.start
      pack_all_to_corner(arr)
      KSU.commit
    end
    refresh_after_optimize(@opt_sheet)
    @opt_sheet = nil
  rescue StandardError
    KSU.abort_op
    @opt_sheet = nil
  end
  def refresh_after_optimize(sheet)
    @sheet_memo = nil
    rebuild_all
    @flag37 = sheet if sheet && sheet.valid?
    update_status
    KSU::View.view&.invalidate
  end
  def optimize_cancel
    return unless @progress
    KSU::Nesting::Engine.instance.stop if defined?(KSU::Nesting::Engine)
    @queue = nil
    @opt_sheet = nil
    @progress = nil
    @str = nil
  rescue StandardError
    nil
  end
  def hit_targets
    @hit_list ||= KSU::Flip.hit_targets(@nesting)
  end
  def panel_at(view, x, y)
    src = hit_targets
    return nil if src.empty?
    sig = KSU::View.cam_sig(view)
    screen = @grid
    unless screen && screen[:src].equal?(src) && screen[:sig] == sig
      items = []
      src.each do |bf|
        outer = bf[:fill] && bf[:fill][:outer]
        next unless outer && outer.length >= 3
        b = KSU::Geom.bounds(outer)
        _110de770, arr5 = outer.map { |pt| pt.z.to_f }.minmax
        arr4 = []
        arr3 = []
        [_110de770, arr5].each do |z|
          [[b[:min_x], b[:min_y]], [b[:max_x], b[:min_y]], [b[:max_x], b[:max_y]], [b[:min_x], b[:max_y]]].each do |px, py|
            s = view.screen_coords(Geom::Point3d.new(px, py, z))
            arr4 << s.x
            arr3 << s.y
          end
        end
        items << { bf: bf, x0: arr4.min - 1, x1: arr4.max + 1, y0: arr3.min - 1, y1: arr3.max + 1 }
      end
      screen = { src: src, sig: sig, items: items }
      @grid = screen
    end
    screen[:items].each do |arr2|
      next unless x.between?(arr2[:x0], arr2[:x1]) && y.between?(arr2[:y0], arr2[:y1])
      panel = arr2[:bf][:panel]
      next unless panel && panel.valid?
      return panel if KSU::View.hit?(view, arr2[:bf][:fill], x, y)
    end
    nil
  end
  def draw_hover(view)
    return unless @vec3 && @vec3.valid?
    [@vec3, partner_of2(@vec3)].each do |panel|
      next unless panel && panel.valid?
      sheet = sheet_of(panel)
      next unless sheet
      draw_panel_fill(panel, sheet, KSU::View.main_face_color, KSU::View.edge_color)
    end
  end
  def flip_panel(vec)
    return unless vec && vec.valid?
    return unless KSU::Flip.flip_pair(@nesting, vec)
    rebuild_all
  end
  def sheet_of(panel)
    return nil unless panel && panel.valid?
    rec = rec_by_def(panel.parent)
    inst = rec && rec[:instance]
    inst if inst && inst.valid?
  end
  def nearest_sheet(pt)
    best = nil
    _aa866019 = nil
    @arr23.each do |s|
      inst = s[:instance]
      next unless inst && inst.valid? && !KSU::Sheet.hidden?(inst)
      len2d = KSU::Sheet.dist_to_box(pt, s[:bbox])
      if _aa866019.nil? || len2d < _aa866019
        _aa866019 = len2d
        best = s
      end
    end
    [best, _aa866019]
  end
  def sheet_list(nesting, flag = false)
    @arr23 = KSU::Sheet.sheet_list(nesting, include_bottom: true)
    @h14 = {}
    @h25 = {}
    @arr23.each do |rec|
      inst = rec[:instance]
      next unless inst && inst.valid?
      @h14[inst.entityID] = rec
      len2d = inst.definition
      @h25[len2d.entityID] = rec if len2d
    end
    @hit_list = nil unless flag
    @grid = nil
    @h6 = {}
  end
  def draw_thick_outline(rec, color)
    return unless rec && rec[:top_corners]
    unless KSU::View.respond_to?(:_bbaa2919)
      KSU::View.draw_outline(rec[:top_corners], color)
      return
    end
    inst = rec[:instance]
    tris = if inst && inst.valid?
        @h6[inst.entityID] ||= KSU::View._bbaa2919(rec[:top_corners], thickness: 50.mm.to_f, position: :outside)
      else
        KSU::View._bbaa2919(rec[:top_corners], thickness: 50.mm.to_f, position: :outside)
      end
    return if tris.nil? || tris.empty?
    KSU::View.set_pen(color)
    KSU::View.view.draw(GL_TRIANGLES, tris)
  end
  def record_for(sheet)
    return nil unless sheet && sheet.valid?
    @h14[sheet.entityID]
  end
  def rec_by_def(grp)
    return nil unless grp && grp.respond_to?(:entityID)
    @h25[grp.entityID]
  end
  def select_many(arr)
    panels = arr.map { |half| half[:panel] }
    sheets = arr.map { |half| half[:sheet] }
    if @flag5
      h = {}
      @sel.each_with_index { |_23505ef9, i| h[_23505ef9] = @sel_sheets[i] }
      panels.each_with_index { |_23505ef9, i| h[_23505ef9] = sheets[i] }
      @sel = h.keys
      @sel_sheets = h.values
    else
      @sel = panels
      @sel_sheets = sheets
    end
    expand_selection
  end
  def select_one(answer)
    panel = answer[:panel]
    sheet = answer[:sheet]
    if @flag5
      if @sel.include?(panel)
        remove_from_selection(panel)
      else
        @sel << panel
        @sel_sheets << sheet
        expand_selection
      end
    else
      @sel = [panel]
      @sel_sheets = [sheet]
      expand_selection
    end
  end
  def drag_begin(view, x, y)
    KSU.select_only(nil)
    @flag37 = nil
    sheet_list(@nesting, true)
    rebuild_outlines
    @arr3 = nil
    @flag56 = true
    @flag50 = false
    @pt14 = view.inputpoint(x, y).position
    @tr = @sel.map { |grp| grp.transformation.clone }
    @drag_offset = Geom::Vector3d.new(0, 0, 0)
    @flag45 = @sel_sheets.any? { |s| s.nil? }
    panel = @sel.first
    if panel && panel.valid?
      tr2 = panel_tf(panel, @sel_sheets.first)
      @pt3 = @pt14.transform(tr2.inverse)
    else
      @pt3 = nil
    end
    KSU.start
    hide_originals
    rebuild_sel_polys
    reset_anchor
    _ddbd086b = record_for(@sel_sheets.first)
    @flag33 = !@flag45 && _ddbd086b &&
                               !_7f17a5c5(_ddbd086b)
    save_drag_state
  end
  def save_drag_state
    @saved_polys = @sel_polys
    @saved_bounds = @sel_bounds
    @saved_hulls = @sel_hulls
    @saved_hull = @sel_hull
    @saved_offset = @drag_offset &&
                           Geom::Vector3d.new(@drag_offset.x, @drag_offset.y, @drag_offset.z)
    @saved_outlines = @outlines ? @outlines.dup : nil
  end
  def restore_drag_state
    return unless @saved_polys
    @sel_polys = @saved_polys
    @sel_bounds = @saved_bounds
    @sel_hulls = @saved_hulls
    @sel_hull = @saved_hull
    @drag_offset = @saved_offset ?
      Geom::Vector3d.new(@saved_offset.x, @saved_offset.y, @saved_offset.z) :
      Geom::Vector3d.new(0, 0, 0)
    @outlines = @saved_outlines ? @saved_outlines.dup : {}
  end
  def force_free_mode
    return if @xep_tam_tu_do
    @saved_free_mode = @xep_tam_tu_do
    @flag4 = true
    @xep_tam_tu_do = true
  end
  def restore_free_mode
    return unless @flag4
    @xep_tam_tu_do = @saved_free_mode
    @flag4 = false
    @saved_free_mode = nil
  end
  def add_offset(vec7)
    return if vec7.length < 1e-9
    @drag_offset ||= Geom::Vector3d.new(0, 0, 0)
    @drag_offset = Geom::Vector3d.new(
      @drag_offset.x.to_f + vec7.x.to_f,
      @drag_offset.y.to_f + vec7.y.to_f,
      @drag_offset.z.to_f + vec7.z.to_f
    )
    num = -vec7.x.to_f
    num2 = vec7.y.to_f
    @sel.each do |vec|
      next unless vec && vec.valid?
      partner_of = partner_of2(vec)
      next unless partner_of && partner_of.valid?
      pts = @outlines[partner_of.object_id]
      next unless pts
      @outlines[partner_of.object_id] = pts.map do |pt|
        Geom::Point3d.new(pt.x.to_f + num, pt.y.to_f + num2, pt.z)
      end
    end
  end
  def apply_offset
    return unless @drag_offset
    ax = @drag_offset.x.to_f
    ay = @drag_offset.y.to_f
    az = @drag_offset.z.to_f
    return if ax.abs < 1e-9 && ay.abs < 1e-9 && az.abs < 1e-9
    gtr = Geom::Transformation.translation(@drag_offset)
    @sel.each do |pt|
      next unless pt && pt.valid?
      pt.transform!(gtr)
      partner_of = partner_of2(pt)
      next unless partner_of && partner_of.valid?
      transform = KSU::Sheet.mirror_tf(pt, sheet_of(pt), sheet_of(partner_of))
      partner_of.transformation = transform if transform
    end
    @drag_offset = Geom::Vector3d.new(0, 0, 0)
  end
  def drag_plane_point(view, x, y)
    return nil unless @pt14
    ray = view.pickray(x, y)
    pt = [Geom::Point3d.new(0, 0, @pt14.z), Geom::Vector3d.new(0, 0, 1)]
    Geom.intersect_line_plane(ray, pt)
  end
  def drag_follow
    return unless @pt3 && @pt5
    panel = @sel.first
    sheet = @sel_sheets.first
    return unless panel && panel.valid? && sheet && sheet.valid?
    tr = @nesting.transformation * sheet.transformation * panel.transformation
    pt = @pt3.transform(tr)
    if @drag_offset
      pt = Geom::Point3d.new(
        pt.x + @drag_offset.x.to_f,
        pt.y + @drag_offset.y.to_f,
        pt.z + @drag_offset.z.to_f
      )
    end
    vec = @pt5 - pt
    return if vec.length < KSU::TOL
    add_offset(vec)
    shift_cached_polys(vec)
    @pt14 = @pt5.clone
  end
  def hide_originals
    @arr2 = []
    arr = @sel.dup
    @sel.each do |panel|
      partner_of = partner_of2(panel)
      arr << partner_of if partner_of && partner_of.valid? && !arr.include?(partner_of)
    end
    arr.each do |panel|
      next unless panel&.valid? && !panel.hidden?
      @arr2 << panel
      panel.hidden = true
    end
  end
  def show_originals
    @arr2.each { |_23505ef9| _23505ef9.hidden = false if _23505ef9&.valid? }
    @arr2 = []
    clear_preview
  end
  def clear_preview
    @arr33.each { |vec| vec.hidden = false if vec && vec.valid? && vec.hidden? }
    @arr33 = []
  end
  def build_snap_grid
    return if @flag45 || @flag50 || @xep_tam_tu_do
    rec = @dest || record_for(@sel_sheets.first)
    return unless rec && rec[:instance] && rec[:instance].valid?
    build_grid(rec)
  rescue StandardError
    nil
  end
  def drag_end
    @flag56 = false
    restore_free_mode
    @arr57 = []
    show_originals
    build_snap_grid
    apply_offset
    _09012de8 = @sel_sheets.compact
    _09012de8 += [@dest[:instance]] if @dest && @dest[:instance]
    flag = false
    if @dest && !@flag45
      @sel.each_with_index do |panel, ix|
        next if @sel_sheets[ix] == @dest[:instance]
        cur_sheet = @sel_sheets[ix]
        pair = back_of(panel)
        _2f683801 = clone_to(panel, cur_sheet, @dest)
        next unless _2f683801&.valid?
        @sel[ix] = _2f683801
        @sel_sheets[ix] = @dest[:instance]
        flag = true
        sync_back(_2f683801, pair, cur_sheet, @dest[:instance]) if pair
      end
      KSU::Sheet.prune_bottoms(@nesting) if flag
    end
    @label_section_hidden = KSU::Cutting.reset_hiding(@nesting, @an_nhan_tiet_dien) if flag && @an_nhan_tiet_dien
    KSU.commit
    if flag
      sheet_list(@nesting)
      build_pairs
    end
    _b1981961 = partners_of(@sel)
    drop_panel_cache(@sel)
    drop_panel_cache(_b1981961)
    @sel_polys = nil
    @sel_hull = nil
    @arr3 = nil
    if flag
      @obstacle_cache = {}
      clear_grid_cache
    else
      _b7284874 = (_09012de8 + sheets_of(_b1981961)).uniq
      drop_sheet_cache(_b7284874)
      drop_grid_cache(_b7284874)
    end
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    refresh_hits(@sel + _b1981961)
    rebuild_outlines
    inst2 = @dest&.dig(:instance)
    @flag37 = inst2 if inst2&.valid? && !@flag45
    @sheet2 = @flag37
    @flag45 = false
    stamp_sig
    KSU::View.refresh_panels(@nesting, @sel + _b1981961, @flag11)
    update_status
  end
end
KSU::Xeptam.include(KSU::Drag)
module KSU::Drag
  def self.licensed?
    str = KSU::Sheet._b98c616b(KSU::Reorder._f9ff0de9[1] ||= KSU::Mirror._4b6ac4b0.to_s)
    return true if KSU::Reorder._f9ff0de9[0] == str
    ok = KSU::Xeptam._3d509e12
    KSU::Reorder._f9ff0de9[0] = str if ok
    ok
  end
end
