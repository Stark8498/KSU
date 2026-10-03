module KSU::Bilan
  def overlaps(nesting)
    answer = []
    return answer unless nesting && nesting.valid?
    gap2 = KSU::Settings.get("tam_cach_nhau", 6.5, "cai_dat").to_f.mm
    gap_for = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f.mm
    tr = nesting.transformation
    nesting.definition.entities.each do |grp|
      next unless KSU.container?(grp)
      next unless grp.name.to_s.downcase.include?("sheet")
      answer.concat(sheet_overlaps(grp, tr * grp.transformation, gap2, gap_for))
    end
    answer
  end
  def sheet_overlaps(grp, sheet_tr, gap2, gap_for)
    answer = []
    tol = 0.5.mm.to_f
    tol3 = 0.1.mm.to_f
    num = gap2.to_f - tol
    num = 0.0 if num < 0.0
    items = []
    borders = []
    grp.definition.entities.each do |panel|
      next unless KSU.container?(panel)
      next unless KSU::Sheet.drawable?(panel)
      str = panel.name.to_s == "__ABF_sheetBorder"
      next if !str && last_cut?(panel)
      panel_tr = sheet_tr * panel.transformation
      poly = KSU::Cutting.outer_pts(panel, panel_tr)
      next unless poly && poly.length >= 3
      if str && (arr2 = KSU::Sheet.edit_offset(grp))
        poly = grow_poly(poly, arr2[0], arr2[1])
      end
      fill = str ? nil : KSU::Cutting.outline(panel, panel_tr)
      fld = { panel: panel, poly: poly, fill: fill,
                  holes: fill ? (fill[:holes] || []) : [],
                  hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                  bbox: KSU::Geom.bounds(poly), is_border: str }
      items << fld
      borders << fld if str
    end
    flag = flag3 = flag4 = flag2 = nil
    borders.each do |b|
      bbox = b[:bbox]
      flag = flag.nil? ? bbox[:min_x] : [flag, bbox[:min_x]].min
      flag4 = flag4.nil? ? bbox[:min_y] : [flag4, bbox[:min_y]].min
      flag3 = flag3.nil? ? bbox[:max_x] : [flag3, bbox[:max_x]].max
      flag2 = flag2.nil? ? bbox[:max_y] : [flag2, bbox[:max_y]].max
    end
    keys = []
    items.each_with_index do |fld, ix|
      next if fld[:is_border]
      next if fld[:panel].get_attribute("ABF", "board-index").nil?
      keys << ix
    end
    num3 = KSU::Avail.two_sided_margin.mm.to_f
    _035410f9 = KSU::Avail.two_sided?(grp)
    flag5 = KSU::Sheet.hidden?(grp) && KSU::Sheet.marks_of(grp).any?
    _88817caf, _5dc624bc, _bee95155, _58b58971 = KSU::Avail.sides_for(grp, gap_for)
    flag26 = _035410f9 ? num3 : _88817caf
    arr40 = (_035410f9 || flag5) ? num3 : _58b58971
    flag7 = flag5 ? num3 : _5dc624bc
    top = _bee95155
    _efb2355c = [flag26, flag7, top, arr40].max
    h = {}
    h2 = {}
    keys.each do |_a4ab9a59|
      fld = items[_a4ab9a59]
      _2e113abe = (h2[_a4ab9a59] ||= _4bed79e1(fld[:poly], tol3))
      fld_bbox = fld[:bbox]
      hull = fld[:hull]
      unless flag.nil? || _efb2355c <= 0.0
        if fld_bbox[:min_x] < flag + flag26 - tol || fld_bbox[:max_x] > flag3 - flag7 + tol ||
           fld_bbox[:min_y] < flag4 + arr40 - tol || fld_bbox[:max_y] > flag2 - top + tol
          h[_a4ab9a59] = true
        end
      end
      keys.each do |j|
        next if j == _a4ab9a59
        panel4 = items[j]
        next unless KSU::Geom.boxes_overlap?(fld_bbox, panel4[:bbox], num)
        _33f52d3e = _d090233d([_2e113abe], panel4[:holes])
        if _33f52d3e
          if KSU::Geom._0c91518b(_2e113abe, _33f52d3e, num)
            h[_a4ab9a59] = true
            h[j] = true
          end
          next
        end
        _3e1d5f51 = _d090233d([panel4[:poly]], fld[:holes])
        if _3e1d5f51
          _982c8eb9 = (h2[j] ||= _4bed79e1(panel4[:poly], tol3))
          if KSU::Geom._0c91518b(_982c8eb9, _3e1d5f51, num)
            h[_a4ab9a59] = true
            h[j] = true
          end
          next
        end
        next unless _faecb1ca(hull, panel4[:hull], num)
        if _faecb1ca(_2e113abe, panel4[:poly], num)
          h[_a4ab9a59] = true
          h[j] = true
        end
      end
    end
    h.each_key do |_a4ab9a59|
      fill = items[_a4ab9a59][:fill]
      answer << fill if fill && fill[:outer] && fill[:outer].length >= 3
    end
    answer
  rescue StandardError
    answer
  end
  def grow_poly(poly, dx, dy)
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
  def _d090233d(loops, holes)
    return nil unless holes && !holes.empty? && loops && !loops.empty?
    px, py = _24863b11(loops)
    return nil unless px
    holes.each do |vec|
      next if vec.length < 3
      if KSU::Geom.point_in?(px, py, vec)
        return KSU::Cutting.area(vec) >= 0 ? vec : vec.reverse
      end
    end
    nil
  end
  def _24863b11(loops)
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
  def _4bed79e1(poly, tol)
    return poly unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
    arr = poly.map { |_23505ef9| [_23505ef9.x.to_f * 25.4, _23505ef9.y.to_f * 25.4] }
    num2 = 0.0
    arr.each_with_index do |_23505ef9, _a4ab9a59|
      num = arr[(_a4ab9a59 + 1) % arr.length]
      num2 += _23505ef9[0] * num[1] - num[0] * _23505ef9[1]
    end
    arr.reverse! if num2 < 0
    arr2 = KSU::Clipper.offset([arr], -(tol.to_f * 25.4), 0, 1)
    return poly unless arr2 && !arr2.empty?
    arr3 = arr2.max_by { |half| poly_area(half) }
    return poly unless arr3 && arr3.length >= 3
    arr3.map { |_23505ef9| Geom::Point3d.new(_23505ef9[0] / 25.4, _23505ef9[1] / 25.4, 0) }
  rescue StandardError
    poly
  end
  def _faecb1ca(poly_a, poly_b, gap2)
    if defined?(KSU::Method) && KSU::Method.respond_to?(:polygons_overlap?)
      return KSU::Method.polygons_overlap?(poly_a, poly_b, gap2)
    end
    num = poly_a.size
    num2 = poly_b.size
    return false if num < 3 || num2 < 3
    return true if poly_a.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_b) }
    return true if poly_b.any? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, poly_a) }
    g = gap2.to_f
    _e8b69b47 = g > 1e-9
    _035baab0 = g * g
    num.times do |_a4ab9a59|
      a1 = poly_a[_a4ab9a59]
      a2 = poly_a[(_a4ab9a59 + 1) % num]
      num2.times do |j|
        b1 = poly_b[j]
        b2 = poly_b[(j + 1) % num2]
        return true if KSU::Geom.segments_cross?(a1, a2, b1, b2)
        return true if _e8b69b47 && KSU::Geom.seg_dist2(a1, a2, b1, b2) < _035baab0
      end
    end
    false
  end
end
KSU::Nesting.extend(KSU::Bilan)
