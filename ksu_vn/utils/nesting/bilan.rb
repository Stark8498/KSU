module KSU::Bilan
  def overlaps_v1(nesting)
    answer = []
    return answer unless nesting && nesting.valid?
    gap2 = KSU::Settings.get("tam_cach_nhau", 6.5, "cai_dat").to_f.mm
    gap_for = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f.mm
    tr = nesting.transformation
    nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      next unless sheet.name.to_s.downcase.include?("sheet")
      answer.concat(sheet_overlaps_v1(sheet, tr * sheet.transformation, gap2, gap_for))
    end
    answer
  end
  def sheet_overlaps_v1(sheet, sheet_tr, gap2, gap_for)
    answer = []
    tol = 0.5.mm.to_f
    num3 = 0.1.mm.to_f
    num = gap2.to_f - tol
    num = 0.0 if num < 0.0
    items = []
    borders = []
    sheet.definition.entities.each do |panel|
      next unless KSU.container?(panel)
      next unless KSU::Sheet.drawable?(panel)
      is_border = panel.name.to_s == "__ABF_sheetBorder"
      next if !is_border && last_cut?(panel)
      panel_tr = sheet_tr * panel.transformation
      poly = KSU::Cutting.outer_pts(panel, panel_tr)
      next unless poly && poly.length >= 3
      if is_border && (arr2 = KSU::Sheet.edit_offset(sheet))
        poly = grow_poly(poly, arr2[0], arr2[1])
      end
      fill = is_border ? nil : KSU::Cutting.outline(panel, panel_tr)
      fld = { panel: panel, poly: poly, fill: fill,
                  holes: fill ? (fill[:holes] || []) : [],
                  hull: (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly),
                  bbox: KSU::Geom.bounds(poly), is_border: is_border }
      items << fld
      borders << fld if is_border
    end
    flag = flag3 = flag2 = flag4 = nil
    borders.each do |b|
      bbox = b[:bbox]
      flag = flag.nil? ? bbox[:min_x] : [flag, bbox[:min_x]].min
      flag2 = flag2.nil? ? bbox[:min_y] : [flag2, bbox[:min_y]].min
      flag3 = flag3.nil? ? bbox[:max_x] : [flag3, bbox[:max_x]].max
      flag4 = flag4.nil? ? bbox[:max_y] : [flag4, bbox[:max_y]].max
    end
    keys = []
    items.each_with_index do |fld, ix|
      next if fld[:is_border]
      next if fld[:panel].get_attribute("ABF", "board-index").nil?
      keys << ix
    end
    num2 = KSU::Avail.two_sided_margin.mm.to_f
    two_face = KSU::Avail.two_sided?(sheet)
    flag5 = KSU::Sheet.hidden?(sheet) && KSU::Sheet.marks_of(sheet).any?
    m_left2, m_right2, m_top2, m_bot2 = KSU::Avail.sides_for(sheet, gap_for)
    m_left = two_face ? num2 : m_left2
    m_bottom = (two_face || flag5) ? num2 : m_bot2
    m_right = flag5 ? num2 : m_right2
    top = m_top2
    m_max = [m_left, m_right, top, m_bottom].max
    h = {}
    h2 = {}
    keys.each do |i|
      fld = items[i]
      small = (h2[i] ||= offset_in(fld[:poly], num3))
      fld_bbox = fld[:bbox]
      hull = fld[:hull]
      unless flag.nil? || m_max <= 0.0
        if fld_bbox[:min_x] < flag + m_left - tol || fld_bbox[:max_x] > flag3 - m_right + tol ||
           fld_bbox[:min_y] < flag2 + m_bottom - tol || fld_bbox[:max_y] > flag4 - top + tol
          h[i] = true
        end
      end
      keys.each do |j|
        next if j == i
        arr = items[j]
        next unless KSU::Geom.boxes_overlap?(fld_bbox, arr[:bbox], num)
        _33f52d3e = hole_near([small], arr[:holes])
        if _33f52d3e
          if KSU::Geom.polys_overlap?(small, _33f52d3e, num)
            h[i] = true
            h[j] = true
          end
          next
        end
        hole2 = hole_near([arr[:poly]], fld[:holes])
        if hole2
          small2 = (h2[j] ||= offset_in(arr[:poly], num3))
          if KSU::Geom.polys_overlap?(small2, hole2, num)
            h[i] = true
            h[j] = true
          end
          next
        end
        next unless polys_hit?(hull, arr[:hull], num)
        if polys_hit?(small, arr[:poly], num)
          h[i] = true
          h[j] = true
        end
      end
    end
    h.each_key do |i|
      fill = items[i][:fill]
      answer << fill if fill && fill[:outer] && fill[:outer].length >= 3
    end
    answer
  rescue StandardError
    answer
  end
  def grow_poly(poly, dx, dy)
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
  def hole_near(loops, holes)
    return nil unless holes && !holes.empty? && loops && !loops.empty?
    px, py = loops_mid(loops)
    return nil unless px
    holes.each do |vec|
      next if vec.length < 3
      if KSU::Geom.point_in?(px, py, vec)
        return KSU::Cutting.area(vec) >= 0 ? vec : vec.reverse
      end
    end
    nil
  end
  def loops_mid(loops)
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
  def offset_in(poly, num2)
    return poly unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
    arr = poly.map { |pt4| [pt4.x.to_f * 25.4, pt4.y.to_f * 25.4] }
    num = 0.0
    arr.each_with_index do |pt4, i|
      _f4dc3a1d = arr[(i + 1) % arr.length]
      num += pt4[0] * _f4dc3a1d[1] - _f4dc3a1d[0] * pt4[1]
    end
    arr.reverse! if num < 0
    arr2 = KSU::Clipper.offset([arr], -(num2.to_f * 25.4), 0, 1)
    return poly unless arr2 && !arr2.empty?
    best = arr2.max_by { |half| poly_area(half) }
    return poly unless best && best.length >= 3
    best.map { |pt4| Geom::Point3d.new(pt4[0] / 25.4, pt4[1] / 25.4, 0) }
  rescue StandardError
    poly
  end
  def polys_hit?(poly_a, poly_b, gap2)
    if defined?(KSU::Method) && KSU::Method.respond_to?(:polygons_overlap?)
      return KSU::Method.polygons_overlap?(poly_a, poly_b, gap2)
    end
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
end
KSU::Nesting.extend(KSU::Bilan)
