module KSU::Drag
  private
  def corner_handle_at(view, x, y)
    rec = record_for(@flag29)
    return nil unless rec
    KSU::View.bracket_hit(view, rec[:top_corners], x, y)
  end
  def edge_handle_at(view, x, y)
    rec = record_for(@flag29)
    return nil unless rec
    KSU::View.edge_hit(view, rec[:top_corners], x, y)
  end
  def pick_edge(ix, edge)
    rec = record_for(@flag29)
    return unless rec
    KSU.start
    num = [@nesting, @flag29, rec, ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f]
    bbox = edge ? KSU::Nesting.pack_to_edge(*num) : KSU::Nesting.pack_to_corner(*num)
    KSU.commit
    return if bbox.empty?
    bbox = bbox.uniq
    drop_panel_cache(bbox)
    refresh_after_move(bbox, sheets_of(bbox))
    rebuild_outlines
  rescue StandardError
    KSU.abort_op
  end
  def optimize_sheet(sheet)
    return unless @nesting && @nesting.valid?
    @pressing = false
    @banding = false
    load_optimize_settings
    reload_sheets
    @opt_sheet = sheet
    @added = []
    @queue = [[sheet]]
    @progress = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    optimize_next
  rescue StandardError => e
    KSU.abort_op
    @progress = nil
    @str = nil
    @queue = nil
    UI.messagebox("Lỗi tối ưu: #{e.message}")
  end
  def load_optimize_settings
    @thu_tu_don = KSU::Settings.get("thu_tu_don", "mac_dinh", "toi_uu_van")
    @tach_nhom_2_mat = !!KSU::Settings.get("tach_nhom_2_mat", true, "toi_uu_van")
    @don_ve_dau_hang = !!KSU::Settings.get("don_ve_dau_hang", true, "toi_uu_van")
    @goc_don_van = KSU::Settings.get("goc_don_van", "trai_duoi", "toi_uu_van")
    @cho_phep_xoay = !!KSU::Settings.get("cho_phep_xoay", false, "toi_uu_van")
    @xoay_theo_tu_khoa = !!KSU::Settings.get("xoay_theo_tu_khoa", false, "toi_uu_van")
    @danh_sach_tu_khoa = KSU::Settings.get("danh_sach_tu_khoa", "XƯƠNG, XÀ, GIẰNG, CHẶN", "toi_uu_van")
    @xoay_theo_vat_lieu = !!KSU::Settings.get("xoay_theo_vat_lieu", false, "toi_uu_van")
    @danh_sach_vat_lieu = KSU::Settings.get("danh_sach_vat_lieu", "TRƠN, TRẮNG, XANH, HỒNG", "toi_uu_van")
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
  def refresh_after_optimize(vec)
    @sheet_memo = nil
    rebuild_all
    @flag29 = vec if vec && vec.valid?
    update_status
    KSU::View.view&.invalidate
  end
  def optimize_cancel
    return unless @progress
    KSU::Nesting::Engine.instance.stop_engine
    @queue = nil
    @opt_sheet = nil
    @progress = nil
    @str = nil
  rescue StandardError
    nil
  end
  def panel_at(view, x, y)
    src = (@hit_list ||= KSU::Flip.flip_rows(@nesting))
    return nil if src.empty?
    sig = KSU::View.cam_sig(view)
    screen = @grid
    unless screen && screen[:src].equal?(src) && screen[:sig] == sig
      items = []
      src.each do |bf|
        outer = bf[:fill] && bf[:fill][:outer]
        next unless outer && outer.length >= 3
        b = KSU::Geom.bounds(outer)
        z_lo, arr5 = outer.map { |pt| pt.z.to_f }.minmax
        arr3 = [z_lo, arr5].flat_map do |z|
          [[b[:min_x], b[:min_y]], [b[:max_x], b[:min_y]], [b[:max_x], b[:max_y]], [b[:min_x], b[:max_y]]].map do |px, py|
            view.screen_coords(Geom::Point3d.new(px, py, z))
          end
        end
        arr4 = arr3.map(&:x)
        arr2 = arr3.map(&:y)
        items << { bf: bf, x0: arr4.min - 1, x1: arr4.max + 1, y0: arr2.min - 1, y1: arr2.max + 1 }
      end
      screen = { src: src, sig: sig, items: items }
      @grid = screen
    end
    screen[:items].each do |arr|
      next unless x.between?(arr[:x0], arr[:x1]) && y.between?(arr[:y0], arr[:y1])
      panel = arr[:bf][:panel]
      next unless panel && panel.valid?
      return panel if KSU::View.hit?(view, arr[:bf][:fill], x, y)
    end
    nil
  end
  def draw_hover
    return unless @vec3 && @vec3.valid?
    [@vec3, partner_of2(@vec3)].each do |panel|
      next unless panel && panel.valid?
      sheet = sheet_of(panel)
      next unless sheet
      draw_panel_fill(panel, sheet, KSU::View.main_face_color, KSU::View.edge_color)
    end
  end
  def sheet_of(panel)
    return nil unless panel && panel.valid?
    rec = rec_by_def(panel.parent)
    inst = rec && rec[:instance]
    inst if inst && inst.valid?
  end
  def nearest_sheet(segs_for_ray)
    best = nil
    best_d2x = nil
    @arr24.each do |s|
      inst = s[:instance]
      next unless inst && inst.valid? && !KSU::Sheet.hidden?(inst)
      len2d = KSU::Sheet.dist_to_box(segs_for_ray, s[:bbox])
      if best_d2x.nil? || len2d < best_d2x
        best_d2x = len2d
        best = s
      end
    end
    [best, best_d2x]
  end
  def sheet_list(nesting, flag = false)
    @arr24 = KSU::Sheet.sheet_list(nesting, include_bottom: true)
    @h15 = {}
    @h14 = {}
    @arr24.each do |rec|
      inst = rec[:instance]
      next unless inst && inst.valid?
      @h15[inst.entityID] = rec
      len2d = inst.definition
      @h14[len2d.entityID] = rec if len2d
    end
    @hit_list = nil unless flag
    @grid = nil
    @h32 = {}
  end
  def draw_thick_outline(rec, color)
    return unless rec && rec[:top_corners]
    inst = rec[:instance]
    return KSU::View.draw_outline(rec[:top_corners], color) unless inst && inst.valid?
    num = @h32[inst.entityID] ||= KSU::View.band_tris(rec[:top_corners], thickness: 50.mm.to_f, position: :outside)
    return if num.nil? || num.empty?
    KSU::View.set_pen(color)
    KSU::View.view.draw(GL_TRIANGLES, num)
  end
  def record_for(grp)
    return nil unless grp && grp.valid?
    @h15[grp.entityID]
  end
  def rec_by_def(grp)
    return nil unless grp && grp.respond_to?(:entityID)
    @h14[grp.entityID]
  end
  def select_many(arr)
    panels = arr.map { |half| half[:panel] }
    sheets = arr.map { |half| half[:sheet] }
    if @flag16
      out_rec = (@sel.zip(@sel_sheets) + panels.zip(sheets)).to_h
      @sel = out_rec.keys
      @sel_sheets = out_rec.values
    else
      @sel = panels
      @sel_sheets = sheets
    end
    ungroup_selection
  end
  def select_one(ok)
    panel = ok[:panel]
    sheet = ok[:sheet]
    return remove_from_selection(panel) if @flag16 && @sel.include?(panel)
    if @flag16
      @sel << panel
      @sel_sheets << sheet
    else
      @sel = [panel]
      @sel_sheets = [sheet]
    end
    ungroup_selection
  end
  def drag_begin(view, x, y)
    KSU.select_only(nil)
    @flag29 = nil
    sheet_list(@nesting, true)
    rebuild_outlines
    @arr30 = nil
    @flag22 = true
    @flag26 = false
    @pt4 = view.inputpoint(x, y).position
    @drag_offset = Geom::Vector3d.new(0, 0, 0)
    @flag24 = @sel_sheets.any? { |s| s.nil? }
    panel = @sel.first
    @flag44 = (panel && panel.valid?) ? @pt4.transform(panel_tf(panel, @sel_sheets.first).inverse) : nil
    KSU.start
    hide_originals
    rebuild_sel_polys
    reset_anchor
    cur_rec = record_for(@sel_sheets.first)
    @flag19 = !@flag24 && cur_rec &&
                               !fits_on?(cur_rec)
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
    @flag14 = true
    @xep_tam_tu_do = true
  end
  def restore_free_mode
    return unless @flag14
    @xep_tam_tu_do = @saved_free_mode
    @flag14 = false
    @saved_free_mode = nil
  end
  def add_offset(pt)
    return if pt.length < 1e-9
    @drag_offset ||= Geom::Vector3d.new(0, 0, 0)
    @drag_offset = Geom::Vector3d.new(
      @drag_offset.x.to_f + pt.x.to_f,
      @drag_offset.y.to_f + pt.y.to_f,
      @drag_offset.z.to_f + pt.z.to_f
    )
    num = -pt.x.to_f
    num2 = pt.y.to_f
    @sel.each do |vec|
      next unless vec && vec.valid?
      partner_of = partner_of2(vec)
      next unless partner_of && partner_of.valid?
      arr = @outlines[partner_of.object_id]
      next unless arr
      @outlines[partner_of.object_id] = arr.map do |segs_for_ray|
        Geom::Point3d.new(segs_for_ray.x.to_f + num, segs_for_ray.y.to_f + num2, segs_for_ray.z)
      end
    end
  end
  def shift_by(_71fbc725)
    add_offset(_71fbc725)
    shift_cached_polys(_71fbc725)
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
      _ac3b3b9d = KSU::Sheet.mirror_tf(pt, sheet_of(pt), sheet_of(partner_of))
      partner_of.transformation = _ac3b3b9d if _ac3b3b9d
    end
    @drag_offset = Geom::Vector3d.new(0, 0, 0)
  end
  def drag_follow
    return unless @flag44 && @pt5
    panel = @sel.first
    vec = @sel_sheets.first
    return unless panel && panel.valid? && vec && vec.valid?
    pt = @flag44.transform(panel_tf(panel, vec))
    if @drag_offset
      pt = Geom::Point3d.new(
        pt.x + @drag_offset.x.to_f,
        pt.y + @drag_offset.y.to_f,
        pt.z + @drag_offset.z.to_f
      )
    end
    arr = @pt5 - pt
    return if arr.length < KSU::TOL
    shift_by(arr)
    @pt4 = @pt5.clone
  end
  def hide_originals
    @arr25 = []
    (@sel + partners_of(@sel)).each do |panel|
      next unless panel&.valid? && !panel.hidden?
      @arr25 << panel
      panel.hidden = true
    end
  end
  def show_originals
    @arr25.each { |pt3| pt3.hidden = false if pt3&.valid? }
    @arr25 = []
    clear_preview
  end
  def clear_preview
    @arr40.each { |vec| vec.hidden = false if vec && vec.valid? && vec.hidden? }
    @arr40 = []
  end
  def build_snap_grid
    return if @flag24 || @flag26 || @xep_tam_tu_do
    rec = @dest || record_for(@sel_sheets.first)
    return unless rec && rec[:instance] && rec[:instance].valid?
    build_grid(rec)
  rescue StandardError
    nil
  end
  def drag_end
    @flag22 = false
    restore_free_mode
    @arr34 = []
    show_originals
    build_snap_grid
    apply_offset
    touched = @sel_sheets.compact
    touched += [@dest[:instance]] if @dest && @dest[:instance]
    flag = false
    if @dest && !@flag24
      @sel.each_with_index do |panel, ix|
        next if @sel_sheets[ix] == @dest[:instance]
        cur_sheet = @sel_sheets[ix]
        pair = back_of(panel)
        moved_panel = clone_to(panel, cur_sheet, @dest)
        next unless moved_panel&.valid?
        @sel[ix] = moved_panel
        @sel_sheets[ix] = @dest[:instance]
        flag = true
        sync_back(moved_panel, pair, cur_sheet, @dest[:instance]) if pair
      end
      KSU::Sheet.prune_bottoms(@nesting) if flag
    end
    KSU.commit
    if flag
      sheet_list(@nesting)
      build_pairs
    end
    partners = partners_of(@sel)
    drop_panel_cache(@sel + partners)
    @sel_polys = nil
    @sel_hull = nil
    @arr30 = nil
    if flag
      @obstacle_cache = {}
      clear_grid_cache
    else
      all_sheets = (touched + sheets_of(partners)).uniq
      drop_sheet_cache(all_sheets)
      drop_grid_cache(all_sheets)
    end
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    refresh_hits(@sel + partners)
    rebuild_outlines
    inst2 = @dest&.dig(:instance)
    @flag29 = inst2 if inst2&.valid? && !@flag24
    @vec6 = @flag29
    @flag24 = false
    stamp_sig
    KSU::View.refresh_panels(@nesting, @sel + partners, @flag27)
    update_status
  end
end
KSU::Xeptam.include(KSU::Drag)
module KSU::Drag
  def self.licensed?
    str = KSU::Sheet.id_hash(KSU::Reorder.id_cache[1] ||= KSU::Mirror.machine_id.to_s)
    return true if KSU::Reorder.id_cache[0] == str
    ok = KSU::Xeptam.license_gate
    KSU::Reorder.id_cache[0] = str if ok
    ok
  end
end
