module KSU::Bilan
  def overlaps(nesting, gap2 = nil)
    return [] unless nesting && nesting.valid?
    gap2 ||= KSU::Settings.get("tam_cach_nhau", 6.5, "cai_dat").to_f.mm
    gap_for = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f.mm
    tr = nesting.transformation
    nesting.definition.entities.flat_map do |grp|
      KSU::Sheet.sheet?(grp) ? sheet_overlaps(grp, tr * grp.transformation, gap2, gap_for) : []
    end
  end
  def sheet_overlaps(grp, sheet_tr, gap2, gap_for)
    ok = []
    tol = 0.5.mm.to_f
    eps = 0.1.mm.to_f
    num = [gap2.to_f - tol, 0.0].max
    items = []
    grp.definition.entities.each do |panel|
      next unless KSU.container?(panel) && KSU::Sheet.drawable?(panel)
      is_border = panel.name.to_s == "__ABF_sheetBorder"
      next if !is_border && last_cut?(panel)
      panel_tr = sheet_tr * panel.transformation
      poly = KSU::Cutting.outer_pts(panel, panel_tr)
      next unless poly && poly.length >= 3
      if is_border && (table_off = KSU::Sheet.edit_offset(grp))
        poly = shifted_bounds(poly, table_off[0], table_off[1])
      end
      items << { panel: panel, poly: poly, tr: panel_tr,
                    hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                    bbox: KSU::Geom.bounds(poly), is_border: is_border }
    end
    arr2 = items.select { |arr| arr[:is_border] }.map { |arr| arr[:bbox] }
    _0fdc7e1e, arr5 = arr2.map { |b| b[:min_x] }.min, arr2.map { |b| b[:max_x] }.max
    _33e31bae, arr4 = arr2.map { |b| b[:min_y] }.min, arr2.map { |b| b[:max_y] }.max
    keys = items.each_index.reject { |i| items[i][:is_border] || items[i][:panel].get_attribute("ABF", "board-index").nil? }
    num2 = KSU::Avail.two_sided_margin.mm.to_f
    _64ad4cc5 = KSU::Avail.two_sided?(grp)
    flag = KSU::Sheet.hidden?(grp) && KSU::Sheet.marks_of(grp).any?
    _f125bb43, m_right, top, _64fb130d = KSU::Avail.sides_for(grp, gap_for)
    m_left = _64ad4cc5 ? num2 : _f125bb43
    m_bottom = (_64ad4cc5 || flag) ? num2 : _64fb130d
    m_right3 = flag ? num2 : m_right
    _1b214521 = [m_left, m_right3, top, m_bottom].max
    h = {}
    h2 = {}
    _e6762308 = ->(arr) { arr[:fill] ||= KSU::Cutting.outline(arr[:panel], arr[:tr]) }
    keys.each do |i|
      fld = items[i]
      fld_bbox = fld[:bbox]
      hull = fld[:hull]
      h[i] = true if _0fdc7e1e && _1b214521 > 0.0 &&
                             (fld_bbox[:min_x] < _0fdc7e1e + m_left - tol || fld_bbox[:max_x] > arr5 - m_right3 + tol ||
                              fld_bbox[:min_y] < _33e31bae + m_bottom - tol || fld_bbox[:max_y] > arr4 - top + tol)
      keys.each do |ix|
        next if ix == i
        panel4 = items[ix]
        next unless KSU::Geom.boxes_overlap?(fld_bbox, panel4[:bbox], num)
        _ac7c1b6d = _e964015e = (h2[i] ||= grow_polygon(fld[:poly], eps))
        _5020f2e5 = holes_bounds(_ac7c1b6d, _e6762308.call(panel4)[:holes])
        unless _5020f2e5
          _5020f2e5 = holes_bounds(panel4[:poly], _e6762308.call(fld)[:holes])
          _e964015e = (h2[ix] ||= grow_polygon(panel4[:poly], eps)) if _5020f2e5
        end
        hit = if _5020f2e5
                   KSU::Geom.polys_overlap?(_e964015e, _5020f2e5, num)
                 else
                   polygons_overlap?(hull, panel4[:hull], num) && polygons_overlap?(_ac7c1b6d, panel4[:poly], num)
                 end
        next unless hit
        h[i] = true
        h[ix] = true
      end
    end
    h.each_key do |i|
      fill = _e6762308.call(items[i])
      ok << fill.merge(panel: items[i][:panel]) if fill && fill[:outer] && fill[:outer].length >= 3
    end
    ok
  rescue StandardError
    ok
  end
  def shifted_bounds(poly, _fbf0cf8d, _7e1c7e1d)
    b = KSU::Geom.bounds(poly)
    eps = 0.1.mm
    poly.map do |pt|
      x = pt.x.to_f
      x += _fbf0cf8d if _fbf0cf8d > 0 && (pt.x.to_f - b[:min_x]).abs < eps
      x += _fbf0cf8d if _fbf0cf8d < 0 && (pt.x.to_f - b[:max_x]).abs < eps
      y = pt.y.to_f
      y += _7e1c7e1d if _7e1c7e1d > 0 && (pt.y.to_f - b[:min_y]).abs < eps
      y += _7e1c7e1d if _7e1c7e1d < 0 && (pt.y.to_f - b[:max_y]).abs < eps
      Geom::Point3d.new(x, y, pt.z.to_f)
    end
  end
  def holes_bounds(poly, holes)
    return nil unless holes && !holes.empty?
    b = KSU::Geom.bounds(poly)
    px, py = (b[:min_x] + b[:max_x]) / 2.0, (b[:min_y] + b[:max_y]) / 2.0
    holes.each do |vec|
      next if vec.length < 3
      if KSU::Geom.point_in?(px, py, vec)
        return KSU::Cutting.area(vec) >= 0 ? vec : vec.reverse
      end
    end
    nil
  end
  def grow_polygon(poly, eps)
    return poly unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
    arr = poly.map { |pt| [pt.x.to_f * 25.4, pt.y.to_f * 25.4] }
    arr.reverse! if signed_area(arr) < 0
    arr2 = KSU::Clipper.offset([arr], -(eps.to_f * 25.4), 0, 1)
    return poly unless arr2 && !arr2.empty?
    best = arr2.max_by { |half| poly_area(half) }
    return poly unless best && best.length >= 3
    best.map { |pt| Geom::Point3d.new(pt[0] / 25.4, pt[1] / 25.4, 0) }
  rescue StandardError
    poly
  end
  def polygons_overlap?(poly_a, poly_b, gap2)
    if defined?(KSU::Method) && KSU::Method.respond_to?(:polygons_overlap?)
      return KSU::Method.polygons_overlap?(poly_a, poly_b, gap2)
    end
    num2 = poly_a.size
    hdr_len = poly_b.size
    return false if num2 < 3 || hdr_len < 3
    return true if poly_a.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_b) }
    return true if poly_b.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_a) }
    num = gap2.to_f
    _bb9748de = num > 1e-9
    _ca323f59 = num * num
    num2.times do |i|
      a1 = poly_a[i]
      a2 = poly_a[(i + 1) % num2]
      hdr_len.times do |ix|
        b1 = poly_b[ix]
        b2 = poly_b[(ix + 1) % hdr_len]
        return true if KSU::Geom.segments_cross?(a1, a2, b1, b2)
        return true if _bb9748de && KSU::Geom.seg_dist2(a1, a2, b1, b2) < _ca323f59
      end
    end
    false
  end
end
KSU::Nesting.extend(KSU::Bilan)
