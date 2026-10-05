module KSU::Collide
  private
  def check_dirty
    return if @flag22
    return if @flag27.nil?
    return unless @nesting && @nesting.valid?
    return if @flag27 == KSU::View.sig_of(@nesting)
    rebuild_all
  end
  def stamp_sig
    @flag27 = (@nesting && @nesting.valid?) ? KSU::View.sig_of(@nesting, true) : nil
  end
  def reset_caches
    KSU::View.clear_cache
    @obstacle_cache = {}
    @nfp_memo = {}
    clear_grid_cache
    @arr30 = nil
    @grid = nil
    stamp_sig
  end
  def drop_sheet_cache(sheets)
    @obstacle_cache ||= {}
    arr = Array(sheets).select { |s| s && s.valid? }.to_h { |s| [s.entityID, true] }
    return if arr.empty?
    @obstacle_cache.delete_if { |grp, _item| !(grp && grp.valid?) || arr[grp.entityID] }
  end
  def refresh_after_move(panels, sheets)
    drop_sheet_cache(sheets)
    @nfp_memo = {}
    drop_grid_cache(sheets)
    @arr30 = nil
    refresh_hits(panels)
    stamp_sig
    KSU::View.refresh_panels(@nesting, panels, @flag27)
  end
  def sheets_of(panels)
    Array(panels).map { |pt3| sheet_of(pt3) }.compact.uniq
  end
  def partners_of(panels)
    Array(panels).map { |pt3| partner_of2(pt3) }.select { |vec| vec && vec.valid? }.uniq
  end
  def refresh_hits(panels)
    @grid = nil
    return unless @hit_list
    arr = Array(panels).select { |grp| grp && grp.valid? }.to_h { |grp| [grp.entityID, true] }
    @hit_list.reject! { |bf| !(bf[:panel] && bf[:panel].valid?) || arr[bf[:panel].entityID] }
    Array(panels).each do |grp|
      next unless grp && grp.valid? && KSU::Cutting.bottom_face?(grp)
      sheet = sheet_of(grp)
      next unless sheet && KSU::Sheet.bottom_sheet?(sheet)
      fill = panel_outline(grp, sheet)
      @hit_list << { panel: grp, fill: fill } if fill
    end
  end
  def build_grid(rec5)
    return unless @refine_on && @sel_polys && rec5 && rec5[:instance]
    arr3 = obstacles_of(rec5[:instance])
    return unless arr3
    arr4 = []
    arr2 = []
    @sel_polys.each_with_index do |arr, ix|
      next unless arr && arr.length >= 3
      arr4 << arr
      arr2 << ((@sel_bounds && @sel_bounds[ix]) || KSU::Geom.bounds(arr))
    end
    return if arr4.empty?
    bbox = { min_x: arr2.map { |b| b[:min_x] }.min, max_x: arr2.map { |b| b[:max_x] }.max,
              min_y: arr2.map { |b| b[:min_y] }.min, max_y: arr2.map { |b| b[:max_y] }.max }
    tol = 0.05.mm.to_f
    gap2 = @tam_cach_nhau.to_f
    arr5 = @sel.select { |arr| arr }.to_h { |arr| [arr.object_id, true] }
    rings = []
    items = arr3[:items]
    KSU::Nfp.grid_query(arr3[:grid], bbox, gap2 + tol).each do |i|
      fld = items[i]
      next if fld[:is_border] || arr5[fld[:panel].object_id]
      rings << fld[:poly]
      (fld[:holes] || []).each { |elem| rings << elem if elem && elem.length >= 3 }
    end
    borders = arr3[:borders].map { |arr6| arr6[:poly] }
    return if rings.empty? && borders.empty?
    dx, dy = KSU::Method.contact_refine(arr4, rings, borders, gap2, min_margin, tol, 6)
    return if dx.abs < 1e-12 && dy.abs < 1e-12
    shift_by(Geom::Vector3d.new(dx, dy, 0))
  rescue StandardError
    nil
  end
  def screen_items(view)
    sig = KSU::View.cam_sig(view)
    return @arr30[:items] if @arr30 && @arr30[:sig] == sig
    items = []
    if @nesting && @nesting.valid?
      tr = @nesting.transformation
      @nesting.definition.entities.each do |node4|
        next unless KSU.container?(node4)
        if node4.name.to_s.downcase.include?("sheet")
          next if KSU::Sheet.bottom_sheet?(node4)
          stroke_w = tr * node4.transformation
          node4.definition.entities.each do |panel|
            next unless KSU::Sheet.part_group?(panel)
            next if KSU::Cutting.bottom_face?(panel)
            items << screen_rec(view, panel, node4, stroke_w * panel.transformation)
          end
        elsif !node4.get_attribute("ABF", "board-index").nil? && !KSU::Cutting.bottom_face?(node4)
          items << screen_rec(view, node4, nil, tr * node4.transformation)
        end
      end
    end
    @arr30 = { sig: sig, items: items }
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
    h[:outer] = (outer && outer.length >= 3) ? outer.map { |pt3| view.screen_coords(pt3) } : nil
    h[:holes] = (fill[:holes] || []).map { |elem| elem.map { |pt3| view.screen_coords(pt3) } }
  end
  def min_margin
    KSU::Avail.avail_map(@tam_cach_le.to_f).min
  end
  def obstacles_of(grp)
    return nil unless grp && grp.valid?
    @obstacle_cache ||= {}
    cached = @obstacle_cache[grp]
    return cached if cached
    items = []
    borders = []
    grp.definition.entities.each do |panel|
      next unless KSU::Sheet.drawable?(panel)
      poly = (@poly_cache && @poly_cache[panel.object_id]) || outer_pts_of(panel, grp)
      next if poly.length < 3
      is_border = panel.name.to_s == "__ABF_sheetBorder"
      if is_border
        _f125bb43, m_right, m_top, bbox = KSU::Avail.sides_for(grp, @tam_cach_le.to_f)
        m_min = [_f125bb43, m_right, m_top, bbox].min
        poly = KSU::Avail.shrink_poly(poly, _f125bb43 - m_min, m_right - m_min, m_top - m_min, bbox - m_min)
        if (table_off = KSU::Sheet.edit_offset(grp))
          table_off = KSU::Avail.clamp_move(grp, table_off, @tam_cach_le.to_f)
          poly = KSU::Nesting.shifted_bounds(poly, table_off[0], table_off[1])
        end
      end
      fill = is_border ? nil : fill_of(panel, grp)
      holes = (fill && fill[:holes]) || []
      fld = { panel: panel, poly: poly, holes: holes,
                  hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                  bbox: KSU::Geom.bounds(poly), is_border: is_border }
      items << fld
      borders << fld if is_border
    end
    @obstacle_cache[grp] = {
      items: items,
      borders: borders,
      grid: KSU::Nfp.cell_grid(items),
    }
  end
  def escape_hole(rec5)
    return nil unless @pt5 && @sel_polys
    _513637ac = obstacles_of(rec5[:instance])
    return nil unless _513637ac
    num = @pt5.x.to_f
    num2 = @pt5.y.to_f
    arr = @sel_polys.compact.flatten(1)
    return nil if arr.empty?
    b = KSU::Geom.bounds(arr)
    px = (b[:min_x] + b[:max_x]) / 2.0
    py = (b[:min_y] + b[:max_y]) / 2.0
    hole = hole_at(_513637ac, num, num2)
    return nil if hole ? KSU::Geom.point_in?(px, py, hole) : !hole_at(_513637ac, px, py)
    Geom::Vector3d.new(num - px, num2 - py, 0)
  end
  def hole_at(arr2, trai, duoi)
    arr2[:items].reject { |arr| arr[:is_border] }.flat_map { |arr| arr[:holes] || [] }
                     .find { |elem| elem.length >= 3 && KSU::Geom.point_in?(trai, duoi, elem) }
  end
  def reset_anchor
    @nfp_memo = {}
    @moving_poly = nil
    @anchor_pt = nil
    @nfp_on = false
    return unless @flag43
    active_ix = anchor_poly
    return unless active_ix && active_ix.length >= 3
    p_ref = active_ix[0]
    @moving_poly = active_ix
    @anchor_pt = Geom::Point3d.new(p_ref.x.to_f, p_ref.y.to_f, p_ref.z.to_f)
    @nfp_on = true
  end
  def anchor_poly
    return nil unless @sel_polys
    arr = @sel_polys.select { |arr2| arr2 && arr2.length >= 3 }
    return nil if arr.empty?
    normal = arr.length == 1 ? arr[0] : @sel_hull
    return nil unless normal && normal.length >= 3
    arr3 = KSU::Nfp.simplify_pts(normal)
    arr3.length >= 3 ? arr3 : normal
  end
  def nfp_for(arr)
    return { valid: false } unless @nfp_on && arr && arr[:instance]
    sheet_id = arr[:instance].object_id
    @nfp_memo[sheet_id] ||= build_nfp(arr)
  end
  def build_nfp(arr7)
    return { valid: false } unless @nfp_on && @moving_poly
    arr5 = obstacles_of(arr7[:instance])
    return { valid: false } unless arr5
    arr8 = @sel.select { |pt| pt }.to_h { |pt| [pt.object_id, true] }
    arr6 = arr5[:items].reject { |arr2| arr2[:is_border] || arr8[arr2[:panel].object_id] }
    return { valid: false } if arr6.length > 300
    moving = @moving_poly.map { |pt| [pt.x.to_f, pt.y.to_f] }
    arr3 = []
    arr4 = []
    num = 0.02.mm.to_f
    num2 = [@tam_cach_nhau.to_f - num, 0.0].max
    edge_gap = [min_margin - num, 0.0].max
    arr6.each do |arr2|
      fixed = arr2[:poly].map { |pt| [pt.x.to_f, pt.y.to_f] }
      arr10 = (arr2[:holes] || []).map { |elem| elem.map { |pt| [pt.x.to_f, pt.y.to_f] } }
      KSU::Nfp.nfp_into(arr3, arr4, fixed, arr10, moving, num2)
    end
    border_rings(arr5, arr7).each do |ring|
      KSU::Nfp.nfp_into(arr3, arr4, ring, [], moving, edge_gap)
    end
    return { valid: true, rings: [], flat: [], snap_edges: [] } if arr3.empty?
    arr9 = arr3.map { |half| KSU::Nfp.orient(half, true) } + arr4.map { |half| KSU::Nfp.orient(half, false) }
    merged = KSU::Clipper.union(arr9, 6)
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
      KSU::Nfp.add_ring_edges(pt2, snap_edges) unless @flag32
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
    _6f2569f7, half, t, b = bbox.values_at(:min_x, :max_x, :max_y, :min_y)
    pad_x = moving_span + 50.mm.to_f
    [
      [[_6f2569f7 - pad_x, t], [half + pad_x, t], [half + pad_x, t + pad_x], [_6f2569f7 - pad_x, t + pad_x]],
      [[_6f2569f7 - pad_x, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, b], [_6f2569f7 - pad_x, b]],
      [[_6f2569f7 - pad_x, b - pad_x], [_6f2569f7, b - pad_x], [_6f2569f7, t + pad_x], [_6f2569f7 - pad_x, t + pad_x]],
      [[half, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, t + pad_x], [half, t + pad_x]],
    ]
  end
  def moving_span
    return 0.0 unless @moving_poly
    bbox = KSU::Geom.bounds(@moving_poly)
    [bbox[:max_x] - bbox[:min_x], bbox[:max_y] - bbox[:min_y]].max
  end
  def shift_nfp(arr, pt)
    return unless @anchor_pt && @drag_offset
    return if arr[:rings].nil? || arr[:rings].empty?
    num4 = @anchor_pt.x.to_f
    num5 = @anchor_pt.y.to_f
    num = @anchor_pt.z.to_f
    dx = num4 + @drag_offset.x.to_f
    dy = num5 + @drag_offset.y.to_f
    if @flag32 && arr[:flat]
      num3, num2 = KSU::Method.nfp_snap(arr[:flat], dx, dy)
    else
      inst2 = Geom::Point3d.new(dx, dy, num)
      pt3 = Geom::Point3d.new(dx - pt.x.to_f, dy - pt.y.to_f, num)
      pt2 = KSU::Nfp.snap_out(arr, pt3, inst2)
      num3 = pt2.x
      num2 = pt2.y
    end
    ddx = num3.to_f - dx
    ddy = num2.to_f - dy
    return if ddx.abs < 1e-9 && ddy.abs < 1e-9
    shift_by(Geom::Vector3d.new(ddx, ddy, 0))
  end
  def rebuild_outlines
    @outlines = {}
    @arr18.each do |panel|
      next unless panel && panel.valid?
      rec = rec_by_def(panel.parent)
      next unless rec
      arr = (@poly_cache && @poly_cache[panel.object_id]) || outer_pts_of(panel, rec[:instance])
      next if arr.length < 3
      @outlines[panel.object_id] = arr
    end
  end
  def hits_border?(rec5)
    return false unless @sel_polys && rec5 && rec5[:instance]
    arr = obstacles_of(rec5[:instance])
    return false unless arr && !arr[:borders].empty?
    @sel_polys.any? do |poly|
      poly && poly.length >= 3 && arr[:borders].any? { |fld| KSU::Geom.polys_overlap?(poly, fld[:poly], 0.0) }
    end
  end
  def escape_dir(rec5, pt2)
    inst5 = rec5[:instance]
    arr2 = obstacles_of(inst5)
    return nil unless arr2
    items = arr2[:items]
    borders = arr2[:borders]
    grid = arr2[:grid]
    worst = nil
    num2 = 0.0
    _dbd6b0b8 = lambda do |pt|
      next unless pt
      _562dc7fc = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
      next unless _562dc7fc > num2
      num2 = _562dc7fc
      worst = pt
    end
    ax = pt2.x.to_f
    ay = pt2.y.to_f
    num = ax.abs > 0 || ay.abs > 0
    arr4 = @sel.to_h { |pt3| [pt3.object_id, true] }
    @sel.each_with_index do |panel, ix|
      arr3 = (@sel_polys && @sel_polys[ix]) ||
                outer_pts_of(panel, @sel_sheets[ix])
      next if arr3.length < 3
      arr = (@sel_bounds && @sel_bounds[ix]) ||
                   KSU::Geom.bounds(arr3)
      bbox = num ? KSU::Geom.translate(arr3, ax, ay) : arr3
      moved_bb = if num
          { min_x: arr[:min_x] + ax, max_x: arr[:max_x] + ax,
            min_y: arr[:min_y] + ay, max_y: arr[:max_y] + ay }
        else
          arr
        end
      borders.each { |fld| _dbd6b0b8.call(KSU::Geom.polys_overlap?(bbox, fld[:poly], min_margin)) }
      KSU::Nfp.grid_query(grid, moved_bb, @tam_cach_nhau).each do |i|
        fld = items[i]
        next if arr4[fld[:panel].object_id]
        _5020f2e5 = KSU::Nesting.holes_bounds(bbox, fld[:holes])
        next _dbd6b0b8.call(KSU::Geom.polys_overlap?(bbox, _5020f2e5, @tam_cach_nhau)) if _5020f2e5
        next unless KSU::Geom.boxes_overlap?(moved_bb, fld[:bbox], @tam_cach_nhau)
        next unless KSU::Nesting.polygons_overlap?(bbox, fld[:poly], @tam_cach_nhau)
        _dbd6b0b8.call(KSU::Geom.sat_mtv(bbox, fld[:poly], @tam_cach_nhau))
      end
    end
    worst
  end
end
KSU::Xeptam.include(KSU::Collide)
module KSU::Collide
  def self.license_json
    File.join(KSU::Settings.data_dir, "license.json")
  end
  def self.activation_errors
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
