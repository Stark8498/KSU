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
    @h15 = {}
    @h27 = {}
    clear_grid_cache
    @arr3 = nil
    @grid = nil
    stamp_sig
  end
  def drop_sheet_cache(sheets)
    @h15 ||= {}
    keys = {}
    Array(sheets).each { |s| keys[s.entityID] = true if s && s.valid? }
    return if keys.empty?
    @h15.delete_if { |k, v| !(k && k.valid?) || keys[k.entityID] }
  end
  def refresh_after_move(panels, sheets)
    drop_sheet_cache(sheets)
    @h27 = {}
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
    Array(panels).each do |_23505ef9|
      partner_of = partner_of2(_23505ef9)
      out << partner_of if partner_of && partner_of.valid? && !out.include?(partner_of)
    end
    out
  end
  def refresh_hits(panels)
    @grid = nil
    return unless @hit_list
    keys = {}
    Array(panels).each { |_23505ef9| keys[_23505ef9.entityID] = true if _23505ef9 && _23505ef9.valid? }
    @hit_list.reject! do |bf|
      panel = bf[:panel]
      !(panel && panel.valid?) || keys[panel.entityID]
    end
    Array(panels).each do |_23505ef9|
      next unless _23505ef9 && _23505ef9.valid? && KSU::Cutting.bottom_face?(_23505ef9)
      rec = rec_by_def(_23505ef9.parent)
      sheet = rec && rec[:instance]
      next unless sheet && sheet.valid? && KSU::Sheet.bottom_sheet?(sheet)
      fill = panel_outline(_23505ef9, sheet)
      @hit_list << { panel: _23505ef9, fill: fill } if fill
    end
  end
  def build_grid(arr4)
    return unless @flag9 && @sel_polys && arr4 && arr4[:instance]
    arr3 = _1adb886a(arr4[:instance])
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
    _9535dc0b = {}
    @sel_panels.each { |arr| _9535dc0b[arr.object_id] = true if arr }
    rings = []
    items = arr3[:items]
    KSU::Nfp._a6cf3d0d(arr3[:grid], bbox, gap2 + tol).each do |i|
      fld = items[i]
      next if fld[:is_border] || _9535dc0b[fld[:panel].object_id]
      rings << fld[:poly]
      (fld[:holes] || []).each { |arr52| rings << arr52 if arr52 && arr52.length >= 3 }
    end
    borders = arr3[:borders].map { |arr6| arr6[:poly] }
    return if rings.empty? && borders.empty?
    dx, dy = KSU::Method.contact_refine(arr5, rings, borders, gap2, _970aa8ae, tol, 6)
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
      @nesting.definition.entities.each do |grp|
        next unless KSU.container?(grp)
        if grp.name.to_s.downcase.include?("sheet")
          next if KSU::Sheet.bottom_sheet?(grp)
          stroke_w = tr * grp.transformation
          grp.definition.entities.each do |panel|
            next unless KSU::Sheet.panel?(panel)
            next if KSU::Cutting.bottom_face?(panel)
            items << screen_rec(view, panel, grp, stroke_w * panel.transformation)
          end
        elsif !grp.get_attribute("ABF", "board-index").nil? && !KSU::Cutting.bottom_face?(grp)
          items << screen_rec(view, grp, nil, tr * grp.transformation)
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
  def _9b1924b8(view, h)
    return if h.key?(:outer)
    fill = KSU::Cutting.outline(h[:panel], h[:world_tr])
    outer = fill[:outer]
    h[:outer] = (outer && outer.length >= 3) ? outer.map { |_23505ef9| view.screen_coords(_23505ef9) } : nil
    h[:holes] = (fill[:holes] || []).map { |arr52| arr52.map { |_23505ef9| view.screen_coords(_23505ef9) } }
  end
  def _970aa8ae
    KSU::Avail.sides(@tam_cach_le.to_f).min
  end
  def _1adb886a(sheet)
    return nil unless sheet && sheet.valid?
    @h15 ||= {}
    partner = @h15[sheet]
    return partner if partner
    items = []
    borders = []
    sheet.definition.entities.each do |panel|
      next unless KSU::Sheet.drawable?(panel)
      poly = (@h21 && @h21[panel.object_id]) || outer_pts_of(panel, sheet)
      next if poly.length < 3
      str = panel.name.to_s == "__ABF_sheetBorder"
      if str
        _88817caf, _5dc624bc, _bee95155, bbox = KSU::Avail.sides_for(sheet, @tam_cach_le.to_f)
        _08f8a9e0 = [_88817caf, _5dc624bc, _bee95155, bbox].min
        poly = KSU::Avail.shrink_poly(poly, _88817caf - _08f8a9e0, _5dc624bc - _08f8a9e0, _bee95155 - _08f8a9e0, bbox - _08f8a9e0)
        if (num = KSU::Sheet.edit_offset(sheet))
          num = KSU::Avail.clamp_move(sheet, num, @tam_cach_le.to_f)
          poly = _56bc8e10(poly, num[0], num[1])
        end
      end
      holes = if str
          []
        else
          fill = _cdd6bfc2(panel, sheet)
          fill ? (fill[:holes] || []) : []
        end
      fld = { panel: panel, poly: poly, holes: holes,
                  hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                  bbox: KSU::Geom.bounds(poly), is_border: str }
      items << fld
      borders << fld if str
    end
    @h15[sheet] = {
      items: items,
      borders: borders,
      grid: KSU::Nfp._78849fa5(items),
    }
  end
  def _56bc8e10(poly, dx, dy)
    b = KSU::Geom.bounds(poly)
    tol = 0.1.mm
    poly.map do |pt|
      x = pt.x.to_f
      x += dx if dx > 0 && (pt.x.to_f - b[:min_x]).abs < tol
      x += dx if dx < 0 && (pt.x.to_f - b[:max_x]).abs < tol
      y = pt.y.to_f
      y += dy if dy > 0 && (pt.y.to_f - b[:min_y]).abs < tol
      y += dy if dy < 0 && (pt.y.to_f - b[:max_y]).abs < tol
      Geom::Point3d.new(x, y, pt.z.to_f)
    end
  end
  def _79fb30a5(loops, holes)
    return nil unless holes && !holes.empty? && loops && !loops.empty?
    px, py = _5ac34e7b(loops)
    return nil unless px
    holes.each do |vec|
      next if vec.length < 3
      if KSU::Geom.point_in?(px, py, vec)
        return KSU::Cutting.area(vec) >= 0 ? vec : vec.reverse
      end
    end
    nil
  end
  def _5ac34e7b(loops)
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
  def _19030d1a(arr)
    return nil unless @pt5 && @sel_polys
    _24eac4c4 = _1adb886a(arr[:instance])
    return nil unless _24eac4c4
    x = @pt5.x.to_f
    y = @pt5.y.to_f
    px, py = _5ac34e7b(@sel_polys)
    return nil unless px
    _80253039 = _fb706f65(_24eac4c4, x, y)
    if _80253039
      return nil if KSU::Geom.point_in?(px, py, _80253039)
      return Geom::Vector3d.new(x - px, y - py, 0)
    end
    return nil unless _fb706f65(_24eac4c4, px, py)
    Geom::Vector3d.new(x - px, y - py, 0)
  end
  def _fb706f65(arr, trai, duoi)
    arr[:items].each do |fld|
      next if fld[:is_border]
      holes = fld[:holes]
      next unless holes && !holes.empty?
      holes.each do |arr52|
        next if arr52.length < 3
        return arr52 if KSU::Geom.point_in?(trai, duoi, arr52)
      end
    end
    nil
  end
  def reset_anchor
    @h27 = {}
    @arr15 = nil
    @anchor_pt = nil
    @flag35 = false
    return unless @flag54
    active_ix = anchor_poly
    return unless active_ix && active_ix.length >= 3
    p_ref = active_ix[0]
    @arr15 = active_ix
    @anchor_pt = Geom::Point3d.new(p_ref.x.to_f, p_ref.y.to_f, p_ref.z.to_f)
    @flag35 = true
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
  def _0feae552(arr)
    return { valid: false } unless @flag35 && arr && arr[:instance]
    sheet_id = arr[:instance].object_id
    @h27[sheet_id] ||= _4a014121(arr)
  end
  def _4a014121(arr8)
    return { valid: false } unless @flag35 && @arr15
    arr4 = _1adb886a(arr8[:instance])
    return { valid: false } unless arr4
    _9535dc0b = {}
    @sel_panels.each { |pt| _9535dc0b[pt.object_id] = true if pt }
    arr9 = arr4[:items].reject { |arr2| arr2[:is_border] || _9535dc0b[arr2[:panel].object_id] }
    return { valid: false } if arr9.length > 300
    moving = @arr15.map { |pt| [pt.x.to_f, pt.y.to_f] }
    arr3 = []
    arr5 = []
    num = 0.02.mm.to_f
    num2 = [@tam_cach_nhau.to_f - num, 0.0].max
    _ac6822d3 = [_970aa8ae - num, 0.0].max
    arr9.each do |arr2|
      fixed = arr2[:poly].map { |pt| [pt.x.to_f, pt.y.to_f] }
      arr11 = (arr2[:holes] || []).map { |arr52| arr52.map { |pt| [pt.x.to_f, pt.y.to_f] } }
      KSU::Nfp._3ea4c8e4(arr3, arr5, fixed, arr11, moving, num2)
    end
    _c6c7c535(arr4, arr8).each do |_e1aa7d6a|
      KSU::Nfp._3ea4c8e4(arr3, arr5, _e1aa7d6a, [], moving, _ac6822d3)
    end
    return { valid: true, rings: [], flat: [], snap_edges: [] } if arr3.empty?
    arr7 = arr3.map { |half| KSU::Nfp._5762df6e(half, true) }
    arr5.each { |half| arr7 << KSU::Nfp._5762df6e(half, false) }
    _69887b79 = KSU::Clipper.union(arr7, 6)
    rings = []
    flat = []
    snap_edges = []
    (_69887b79 || []).each do |half|
      next unless half && half.length >= 3
      half = KSU::Nfp.simplify(half)
      next if half.length < 3
      pt2 = half.map { |arr| Geom::Point3d.new(arr[0], arr[1], 0) }
      rings << pt2
      flat << half.flat_map { |arr| [arr[0].to_f, arr[1].to_f] }
      KSU::Nfp._8c9066f6(pt2, snap_edges) unless @flag2
    end
    { valid: true, rings: rings, flat: flat, snap_edges: snap_edges }
  rescue StandardError
    { valid: false }
  end
  def _c6c7c535(arr2, arr)
    bd2 = arr2[:borders].first
    bbox = if bd2
        bd2[:bbox]
      elsif arr[:bbox]
        { min_x: arr[:bbox].min.x.to_f, max_x: arr[:bbox].max.x.to_f,
          min_y: arr[:bbox].min.y.to_f, max_y: arr[:bbox].max.y.to_f }
      end
    return [] unless bbox
    _b41d8800 = bbox[:min_x]
    half = bbox[:max_x]
    thick = bbox[:max_y]
    b = bbox[:min_y]
    pad_x = _5bb0f6d2 + 50.mm.to_f
    [
      [[_b41d8800 - pad_x, thick], [half + pad_x, thick], [half + pad_x, thick + pad_x], [_b41d8800 - pad_x, thick + pad_x]],
      [[_b41d8800 - pad_x, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, b], [_b41d8800 - pad_x, b]],
      [[_b41d8800 - pad_x, b - pad_x], [_b41d8800, b - pad_x], [_b41d8800, thick + pad_x], [_b41d8800 - pad_x, thick + pad_x]],
      [[half, b - pad_x], [half + pad_x, b - pad_x], [half + pad_x, thick + pad_x], [half, thick + pad_x]],
    ]
  end
  def _5bb0f6d2
    return 0.0 unless @arr15
    bbox = KSU::Geom.bounds(@arr15)
    num3 = bbox[:max_x] - bbox[:min_x]
    arr52 = bbox[:max_y] - bbox[:min_y]
    num3 > arr52 ? num3 : arr52
  end
  def _25080947(arr, pt2)
    return unless @anchor_pt && @drag_offset
    return if arr[:rings].nil? || arr[:rings].empty?
    num6 = @anchor_pt.x.to_f
    num7 = @anchor_pt.y.to_f
    num2 = @anchor_pt.z.to_f
    dx2 = num6 + @drag_offset.x.to_f
    dy = num7 + @drag_offset.y.to_f
    if @flag2 && arr[:flat]
      dx, dy2 = KSU::Method.nfp_snap(arr[:flat], dx2, dy)
    else
      inst2 = Geom::Point3d.new(dx2, dy, num2)
      pt3 = Geom::Point3d.new(dx2 - pt2.x.to_f, dy - pt2.y.to_f, num2)
      pt = KSU::Nfp._4ec2a6e7(arr, pt3, inst2)
      dx = pt.x
      dy2 = pt.y
    end
    num4 = dx.to_f - dx2
    num3 = dy2.to_f - dy
    return if num4.abs < 1e-9 && num3.abs < 1e-9
    delta = Geom::Vector3d.new(num4, num3, 0)
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
      pts = (@h21 && @h21[panel.object_id]) || outer_pts_of(panel, rec[:instance])
      next if pts.length < 3
      @outlines[panel.object_id] = pts
    end
  end
  def _af0cebe5(poly_a, poly_b, gap2)
    return KSU::Method.polygons_overlap?(poly_a, poly_b, gap2) if @flag15
    num = poly_a.size
    num2 = poly_b.size
    return false if num < 3 || num2 < 3
    return true if poly_a.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_b) }
    return true if poly_b.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_a) }
    g = gap2.to_f
    _e8b69b47 = g > 1e-9
    _035baab0 = g * g
    num.times do |i|
      a1 = poly_a[i]
      a2 = poly_a[(i + 1) % num]
      num2.times do |j|
        b1 = poly_b[j]
        b2 = poly_b[(j + 1) % num2]
        return true if KSU::Geom.segments_cross?(a1, a2, b1, b2)
        return true if _e8b69b47 && KSU::Geom.seg_dist2(a1, a2, b1, b2) < _035baab0
      end
    end
    false
  end
  def _11075c77(arr)
    return false unless @sel_polys && arr && arr[:instance]
    arr2 = _1adb886a(arr[:instance])
    return false unless arr2 && !arr2[:borders].empty?
    @sel_polys.each do |poly|
      next if poly.nil? || poly.length < 3
      arr2[:borders].each do |fld|
        return true if KSU::Geom._0c91518b(poly, fld[:poly], 0.0)
      end
    end
    false
  end
  def _4237de17(arr4, pt2)
    inst5 = arr4[:instance]
    arr3 = _1adb886a(inst5)
    return nil unless arr3
    items = arr3[:items]
    borders = arr3[:borders]
    grid = arr3[:grid]
    _77aba818 = nil
    num = 0.0
    ax = pt2.x.to_f
    ay = pt2.y.to_f
    num2 = ax.abs > 0 || ay.abs > 0
    h = {}
    @sel_panels.each { |_23505ef9| h[_23505ef9.object_id] = true }
    @sel_panels.each_with_index do |panel, ix|
      arr2 = (@sel_polys && @sel_polys[ix]) ||
                outer_pts_of(panel, @sel_sheets[ix])
      next if arr2.length < 3
      arr = (@sel_bounds && @sel_bounds[ix]) ||
                   KSU::Geom.bounds(arr2)
      bbox = num2 ? KSU::Geom.translate(arr2, ax, ay) : arr2
      _f8733e26 = if num2
          { min_x: arr[:min_x] + ax, max_x: arr[:max_x] + ax,
            min_y: arr[:min_y] + ay, max_y: arr[:max_y] + ay }
        else
          arr
        end
      borders.each do |fld|
        pt = KSU::Geom._0c91518b(bbox, fld[:poly], _970aa8ae)
        next unless pt
        _0b24b753 = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
        if _0b24b753 > num
          num = _0b24b753
          _77aba818 = pt
        end
      end
      KSU::Nfp._a6cf3d0d(grid, _f8733e26, @tam_cach_nhau).each do |i|
        fld = items[i]
        next if h[fld[:panel].object_id]
        _33f52d3e = _79fb30a5([bbox], fld[:holes])
        if _33f52d3e
          pt = KSU::Geom._0c91518b(bbox, _33f52d3e, @tam_cach_nhau)
          if pt
            _0b24b753 = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
            if _0b24b753 > num
              num = _0b24b753
              _77aba818 = pt
            end
          end
          next
        end
        next unless KSU::Geom.boxes_overlap?(_f8733e26, fld[:bbox], @tam_cach_nhau)
        next unless _af0cebe5(bbox, fld[:poly], @tam_cach_nhau)
        pt = KSU::Geom.sat_mtv(bbox, fld[:poly], @tam_cach_nhau)
        next unless pt
        _0b24b753 = Math.sqrt(pt.x * pt.x + pt.y * pt.y)
        if _0b24b753 > num
          num = _0b24b753
          _77aba818 = pt
        end
      end
    end
    _77aba818
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
