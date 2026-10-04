module KSU::Collide
  private
  def check_dirty
    return if @flag56
    return if @flag11.nil?
    return unless @nesting && @nesting.valid?
    return if @flag11 == KSU::View.sig_of(@nesting)
    rebuild_all
  end
  def stamp_sig
    @flag11 = (@nesting && @nesting.valid?) ? KSU::View.sig_of(@nesting, true) : nil
  end
  def reset_caches
    KSU::View.clear_cache
    @obstacle_cache = {}
    @nfp_memo = {}
    clear_grid_cache
    @arr3 = nil
    @grid = nil
    stamp_sig
  end
  def drop_sheet_cache(sheets)
    @obstacle_cache ||= {}
    h = {}
    Array(sheets).each { |s| h[s.entityID] = true if s && s.valid? }
    return if h.empty?
    @obstacle_cache.delete_if { |k, v| !(k && k.valid?) || h[k.entityID] }
  end
  def refresh_after_move(panels, sheets)
    drop_sheet_cache(sheets)
    @nfp_memo = {}
    drop_grid_cache(sheets)
    @arr3 = nil
    refresh_hits(panels)
    stamp_sig
    KSU::View.refresh_panels(@nesting, panels, @flag11)
  end
  def sheets_of(panels)
    out = []
    Array(panels).each do |ents|
      next unless ents && ents.valid?
      rec = rec_by_def(ents.parent)
      inst = rec && rec[:instance]
      out << inst if inst && inst.valid? && !out.include?(inst)
    end
    out
  end
  def partners_of(panels)
    out = []
    Array(panels).each do |ent|
      partner_of = partner_of2(ent)
      out << partner_of if partner_of && partner_of.valid? && !out.include?(partner_of)
    end
    out
  end
  def refresh_hits(panels)
    @grid = nil
    return unless @hit_list
    h = {}
    Array(panels).each { |ent| h[ent.entityID] = true if ent && ent.valid? }
    @hit_list.reject! do |bf|
      panel = bf[:panel]
      !(panel && panel.valid?) || h[panel.entityID]
    end
    Array(panels).each do |ent|
      next unless ent && ent.valid? && KSU::Cutting.bottom_face?(ent)
      rec = rec_by_def(ent.parent)
      sheet = rec && rec[:instance]
      next unless sheet && sheet.valid? && KSU::Sheet.bottom_sheet?(sheet)
      fill = panel_outline(ent, sheet)
      @hit_list << { panel: ent, fill: fill } if fill
    end
  end
  def build_grid(arr4)
    return unless @refine_on && @sel_polys && arr4 && arr4[:instance]
    arr3 = obstacles_of(arr4[:instance])
    return unless arr3
    arr5 = []
    bbox = nil
    @sel_polys.each_with_index do |arr, ix|
      next unless arr && arr.length >= 3
      arr5 << arr
      b = (@sel_bounds && @sel_bounds[ix]) || KSU::Geom.bounds(arr)
      bbox = if bbox
          { min_x: [bbox[:min_x], b[:min_x]].min, max_x: [bbox[:max_x], b[:max_x]].max,
            min_y: [bbox[:min_y], b[:min_y]].min, max_y: [bbox[:max_y], b[:max_y]].max }
        else
          b
        end
    end
    return if arr5.empty?
    tol = 0.05.mm.to_f
    gap2 = @tam_cach_nhau.to_f
    in_sel = {}
    @sel.each { |arr| in_sel[arr.object_id] = true if arr }
    rings = []
    items = arr3[:items]
    KSU::Nfp.grid_query(arr3[:grid], bbox, gap2 + tol).each do |i|
      fld = items[i]
      next if fld[:is_border] || in_sel[fld[:panel].object_id]
      rings << fld[:poly]
      (fld[:holes] || []).each { |h| rings << h if h && h.length >= 3 }
    end
    borders = arr3[:borders].map { |arr6| arr6[:poly] }
    return if rings.empty? && borders.empty?
    dx, dy = KSU::Method.contact_refine(arr5, rings, borders, gap2, min_margin, tol, 6)
    return if dx.abs < 1e-12 && dy.abs < 1e-12
    delta = Geom::Vector3d.new(dx, dy, 0)
    add_offset(delta)
    shift_cached_polys(delta)
  rescue StandardError
    nil
  end
  def screen_items(view)
    sig = KSU::View.cam_sig(view)
    return @arr3[:items] if @arr3 && @arr3[:sig] == sig
    items = []
    if @nesting && @nesting.valid?
      tr = @nesting.transformation
      @nesting.definition.entities.each do |node4|
        next unless KSU.container?(node4)
        if node4.name.to_s.downcase.include?("sheet")
          next if KSU::Sheet.bottom_sheet?(node4)
          stroke_w = tr * node4.transformation
          node4.definition.entities.each do |panel|
            next unless KSU::Sheet.panel?(panel)
            next if KSU::Cutting.bottom_face?(panel)
            items << screen_rec(view, panel, node4, stroke_w * panel.transformation)
          end
        elsif !node4.get_attribute("ABF", "board-index").nil? && !KSU::Cutting.bottom_face?(node4)
          items << screen_rec(view, node4, nil, tr * node4.transformation)
        end
      end
    end
    @arr3 = { sig: sig, items: items }
    items
  end
  def screen_rec(view, panel, sheet, world_tr)
    bbox = panel.definition.bounds
    pt = (0..7).map { |i| view.screen_coords(world_tr * bbox.corner(i)) }
    sxmin, sxmax = pt.map(&:x).minmax
    symin, symax = pt.map(&:y).minmax
    {
      panel: panel, sheet: sheet, world_tr: world_tr,
      sxmin: sxmin, sxmax: sxmax, symin: symin, symax: symax,
      area: (sxmax - sxmin) * (symax - symin),
    }
  end
  def ensure_screen_poly(view, h)
    return if h.key?(:outer)
    fill = KSU::Cutting.outline(h[:panel], h[:world_tr])
    outer = fill[:outer]
    h[:outer] = (outer && outer.length >= 3) ? outer.map { |ent| view.screen_coords(ent) } : nil
    h[:holes] = (fill[:holes] || []).map { |h18| h18.map { |ent| view.screen_coords(ent) } }
  end
  def min_margin
    KSU::Avail.sides(@tam_cach_le.to_f).min
  end
  def obstacles_of(sheet)
    return nil unless sheet && sheet.valid?
    @obstacle_cache ||= {}
    partner = @obstacle_cache[sheet]
    return partner if partner
    items = []
    borders = []
    sheet.definition.entities.each do |panel|
      next unless KSU::Sheet.drawable?(panel)
      poly = (@poly_cache && @poly_cache[panel.object_id]) || outer_pts_of(panel, sheet)
      next if poly.length < 3
      is_border = panel.name.to_s == "__ABF_sheetBorder"
      if is_border
        m_left, m_right, m_top, bbox = KSU::Avail.sides_for(sheet, @tam_cach_le.to_f)
        m_min = [m_left, m_right, m_top, bbox].min
        poly = KSU::Avail.shrink_poly(poly, m_left - m_min, m_right - m_min, m_top - m_min, bbox - m_min)
        if (num = KSU::Sheet.edit_offset(sheet))
          num = KSU::Avail.clamp_move(sheet, num, @tam_cach_le.to_f)
          poly = shift_edges(poly, num[0], num[1])
        end
      end
      holes = if is_border
          []
        else
          fill = fill_of(panel, sheet)
          fill ? (fill[:holes] || []) : []
        end
      fld = { panel: panel, poly: poly, holes: holes,
                  hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                  bbox: KSU::Geom.bounds(poly), is_border: is_border }
      items << fld
      borders << fld if is_border
    end
    @obstacle_cache[sheet] = {
      items: items,
      borders: borders,
      grid: KSU::Nfp.cell_grid(items),
    }
  end
  def shift_edges(poly, dx, dy)
    b = KSU::Geom.bounds(poly)
    num = 0.1.mm
    poly.map do |pt|
      x = pt.x.to_f
      x += dx if dx > 0 && (pt.x.to_f - b[:min_x]).abs < num
      x += dx if dx < 0 && (pt.x.to_f - b[:max_x]).abs < num
      y = pt.y.to_f
      y += dy if dy > 0 && (pt.y.to_f - b[:min_y]).abs < num
      y += dy if dy < 0 && (pt.y.to_f - b[:max_y]).abs < num
      Geom::Point3d.new(x, y, pt.z.to_f)
    end
  end
  def hole_around(loops, holes)
    return nil unless holes && !holes.empty? && loops && !loops.empty?
    px, py = bbox_mid(loops)
    return nil unless px
    holes.each do |vec|
      next if vec.length < 3
      if KSU::Geom.point_in?(px, py, vec)
        return KSU::Cutting.area(vec) >= 0 ? vec : vec.reverse
      end
    end
    nil
  end
  def bbox_mid(loops)
    lx = ly = nil
    flag2 = flag = nil
    loops.each do |arr|
      next unless arr
      arr.each do |pt|
        x = pt.x.to_f
        y = pt.y.to_f
        lx = x if lx.nil? || x < lx
        flag2 = x if flag2.nil? || x > flag2
        ly = y if ly.nil? || y < ly
        flag = y if flag.nil? || y > flag
      end
    end
    return [nil, nil] if lx.nil?
    [(lx + flag2) / 2.0, (ly + flag) / 2.0]
  end
  def escape_hole(arr)
    return nil unless @pt5 && @sel_polys
    obs = obstacles_of(arr[:instance])
    return nil unless obs
    num2 = @pt5.x.to_f
    num = @pt5.y.to_f
    px, py = bbox_mid(@sel_polys)
    return nil unless px
    hole = hole_at(obs, num2, num)
    if hole
      return nil if KSU::Geom.point_in?(px, py, hole)
      return Geom::Vector3d.new(num2 - px, num - py, 0)
    end
    return nil unless hole_at(obs, px, py)
    Geom::Vector3d.new(num2 - px, num - py, 0)
  end
  def hole_at(arr, trai, duoi)
    arr[:items].each do |fld|
      next if fld[:is_border]
      holes = fld[:holes]
      next unless holes && !holes.empty?
      holes.each do |h|
        next if h.length < 3
        return h if KSU::Geom.point_in?(trai, duoi, h)
      end
    end
    nil
  end
  def reset_anchor
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    return unless @flag54
    active_ix = anchor_poly
    return unless active_ix && active_ix.length >= 3
    p_ref = active_ix[0]
    @moving_poly = active_ix
    @anchor_pt = Geom::Point3d.new(p_ref.x.to_f, p_ref.y.to_f, p_ref.z.to_f)
    @nfp_on = true
  end
  def anchor_poly
    return nil unless @sel_polys
    arr = @sel_polys.select { |arr3| arr3 && arr3.length >= 3 }
    return nil if arr.empty?
    normal = arr.length == 1 ? arr[0] : @sel_hull
    return nil unless normal && normal.length >= 3
    arr2 = KSU::Nfp.simplify_pts(normal)
    arr2.length >= 3 ? arr2 : normal
  end
  def nfp_for(arr)
    return { valid: false } unless @nfp_on && arr && arr[:instance]
    sheet_id = arr[:instance].object_id
    @nfp_memo[sheet_id] ||= build_nfp(arr)
  end
  def build_nfp(arr8)
    return { valid: false } unless @nfp_on && @moving_poly
    arr4 = obstacles_of(arr8[:instance])
    return { valid: false } unless arr4
    in_sel = {}
    @sel.each { |pt| in_sel[pt.object_id] = true if pt }
    arr9 = arr4[:items].reject { |arr2| arr2[:is_border] || in_sel[arr2[:panel].object_id] }
    return { valid: false } if arr9.length > 300
    moving = @moving_poly.map { |pt| [pt.x.to_f, pt.y.to_f] }
    arr3 = []
    arr5 = []
    num = 0.02.mm.to_f
    num2 = [@tam_cach_nhau.to_f - num, 0.0].max
    edge_gap = [min_margin - num, 0.0].max
    arr9.each do |arr2|
      fixed = arr2[:poly].map { |pt| [pt.x.to_f, pt.y.to_f] }
      arr11 = (arr2[:holes] || []).map { |h| h.map { |pt| [pt.x.to_f, pt.y.to_f] } }
      KSU::Nfp.nfp_into(arr3, arr5, fixed, arr11, moving, num2)
    end
    border_rings(arr4, arr8).each do |ring|
      KSU::Nfp.nfp_into(arr3, arr5, ring, [], moving, edge_gap)
    end
    return { valid: true, rings: [], flat: [], snap_edges: [] } if arr3.empty?
    arr7 = arr3.map { |half| KSU::Nfp.orient(half, true) }
    arr5.each { |half| arr7 << KSU::Nfp.orient(half, false) }
    merged = KSU::Clipper.union(arr7, 6)
    rings = []
    flat = []
    snap_edges = []
    (merged || []).each do |half|
      next unless half && half.length >= 3
      half = KSU::Nfp.simplify(half)
      next if half.length < 3
      pt2 = half.map { |arr| Geom::Point3d.new(arr[0], arr[1], 0) }
      rings << pt2
      flat << half.flat_map { |arr| [arr[0].to_f, arr[1].to_f] }
      KSU::Nfp.add_ring_edges(pt2, snap_edges) unless @flag2
    end
    { valid: true, rings: rings, flat: flat, snap_edges: snap_edges }
  rescue StandardError
    { valid: false }
  end
  def border_rings(arr2, arr)
    bd2 = arr2[:borders].first
    bbox = if bd2
        bd2[:bbox]
      elsif arr[:bbox]
        { min_x: arr[:bbox].min.x.to_f, max_x: arr[:bbox].max.x.to_f,
          min_y: arr[:bbox].min.y.to_f, max_y: arr[:bbox].max.y.to_f }
      end
    return [] unless bbox
    lo_x = bbox[:min_x]
    half = bbox[:max_x]
    thick = bbox[:max_y]
    b = bbox[:min_y]
    pad_x = moving_span + 50.mm.to_f
    [
      [[lo_x - pad_x, thick], [half + pad_x, thick], [half + pad_x, thick + pad_x], [lo_x - pad_x, thick + pad_x]],
      [[lo_x - pad_x, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, b], [lo_x - pad_x, b]],
      [[lo_x - pad_x, b - pad_x], [lo_x, b - pad_x], [lo_x, thick + pad_x], [lo_x - pad_x, thick + pad_x]],
      [[half, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, thick + pad_x], [half, thick + pad_x]],
    ]
  end
  def moving_span
    return 0.0 unless @moving_poly
    bbox = KSU::Geom.bounds(@moving_poly)
    w = bbox[:max_x] - bbox[:min_x]
    h = bbox[:max_y] - bbox[:min_y]
    w > h ? w : h
  end
  def shift_nfp(arr, pt2)
    return unless @anchor_pt && @drag_offset
    return if arr[:rings].nil? || arr[:rings].empty?
    num6 = @anchor_pt.x.to_f
    num7 = @anchor_pt.y.to_f
    num2 = @anchor_pt.z.to_f
    dx = num6 + @drag_offset.x.to_f
    dy = num7 + @drag_offset.y.to_f
    if @flag2 && arr[:flat]
      num5, num = KSU::Method.nfp_snap(arr[:flat], dx, dy)
    else
      inst2 = Geom::Point3d.new(dx, dy, num2)
      pt3 = Geom::Point3d.new(dx - pt2.x.to_f, dy - pt2.y.to_f, num2)
      pt = KSU::Nfp.snap_out(arr, pt3, inst2)
      num5 = pt.x
      num = pt.y
    end
    ddx = num5.to_f - dx
    ddy = num.to_f - dy
    return if ddx.abs < 1e-9 && ddy.abs < 1e-9
    delta = Geom::Vector3d.new(ddx, ddy, 0)
    add_offset(delta)
    shift_cached_polys(delta)
  end
  def rebuild_outlines
    @outlines = {}
    return if @arr28.empty?
    @arr28.each do |panel|
      next unless panel && panel.valid?
      rec = rec_by_def(panel.parent)
      next unless rec
      pts = (@poly_cache && @poly_cache[panel.object_id]) || outer_pts_of(panel, rec[:instance])
      next if pts.length < 3
      @outlines[panel.object_id] = pts
    end
  end
  def overlap?(poly_a, poly_b, gap2)
    return KSU::Method.polygons_overlap?(poly_a, poly_b, gap2) if @flag15
    num = poly_a.size
    hdr_len = poly_b.size
    return false if num < 3 || hdr_len < 3
    return true if poly_a.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_b) }
    return true if poly_b.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_a) }
    g = gap2.to_f
    has_gap = g > 1e-9
    gap2sq = g * g
    num.times do |i|
      a1 = poly_a[i]
      a2 = poly_a[(i + 1) % num]
      hdr_len.times do |j|
        b1 = poly_b[j]
        b2 = poly_b[(j + 1) % hdr_len]
        return true if KSU::Geom.segments_cross?(a1, a2, b1, b2)
        return true if has_gap && KSU::Geom.seg_dist2(a1, a2, b1, b2) < gap2sq
      end
    end
    false
  end
  def hits_border?(arr)
    return false unless @sel_polys && arr && arr[:instance]
    arr2 = obstacles_of(arr[:instance])
    return false unless arr2 && !arr2[:borders].empty?
    @sel_polys.each do |poly|
      next if poly.nil? || poly.length < 3
      arr2[:borders].each do |fld|
        return true if KSU::Geom.polys_overlap?(poly, fld[:poly], 0.0)
      end
    end
    false
  end
  def escape_dir(arr4, pt2)
    inst5 = arr4[:instance]
    arr3 = obstacles_of(inst5)
    return nil unless arr3
    items = arr3[:items]
    borders = arr3[:borders]
    grid = arr3[:grid]
    worst = nil
    num = 0.0
    ax = pt2.x.to_f
    ay = pt2.y.to_f
    num2 = ax.abs > 0 || ay.abs > 0
    h = {}
    @sel.each { |ent| h[ent.object_id] = true }
    @sel.each_with_index do |panel, ix|
      arr2 = (@sel_polys && @sel_polys[ix]) ||
                outer_pts_of(panel, @sel_sheets[ix])
      next if arr2.length < 3
      arr = (@sel_bounds && @sel_bounds[ix]) ||
                   KSU::Geom.bounds(arr2)
      bbox = num2 ? KSU::Geom.translate(arr2, ax, ay) : arr2
      moved_bb = if num2
          { min_x: arr[:min_x] + ax, max_x: arr[:max_x] + ax,
            min_y: arr[:min_y] + ay, max_y: arr[:max_y] + ay }
        else
          arr
        end
      borders.each do |fld|
        pt = KSU::Geom.polys_overlap?(bbox, fld[:poly], min_margin)
        next unless pt
        mag = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
        if mag > num
          num = mag
          worst = pt
        end
      end
      KSU::Nfp.grid_query(grid, moved_bb, @tam_cach_nhau).each do |i|
        fld = items[i]
        next if h[fld[:panel].object_id]
        _33f52d3e = hole_around([bbox], fld[:holes])
        if _33f52d3e
          pt = KSU::Geom.polys_overlap?(bbox, _33f52d3e, @tam_cach_nhau)
          if pt
            mag = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
            if mag > num
              num = mag
              worst = pt
            end
          end
          next
        end
        next unless KSU::Geom.boxes_overlap?(moved_bb, fld[:bbox], @tam_cach_nhau)
        next unless overlap?(bbox, fld[:poly], @tam_cach_nhau)
        pt = KSU::Geom.sat_mtv(bbox, fld[:poly], @tam_cach_nhau)
        next unless pt
        mag = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
        if mag > num
          num = mag
          worst = pt
        end
      end
    end
    worst
  end
end
KSU::Xeptam.include(KSU::Collide)
module KSU::Collide
  def self._2b15ac41
    File.join(KSU::Settings.data_dir, "license.json")
  end
  def self._f812d741
    {
      "invalid_key" => "Mã kích hoạt không tồn tại.",
      "invalid_product_id" => "Mã kích hoạt không tồn tại.",
      "no_activations_left" => "Mã kích hoạt đã hết lượt kích hoạt.",
      "key_cancelled" => "Mã kích hoạt đã bị hủy.",
      "key_revoked" => "Mã kích hoạt đã bị thu hồi.",
      "key_expired" => "Mã kích hoạt đã hết hạn.",
      "instance_not_activated" => "Máy này chưa được kích hoạt."
    }
  end
end
