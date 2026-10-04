module KSU::Corner
  def pack_to_corner(nesting, sheet, rec, corner, gap_for, gap2, flag = false, deadline = nil)
    apply_moves(nesting, plan_corner(nesting, sheet, rec, corner, gap_for, gap2, flag, deadline))
  end
  def apply_moves(nesting, plan)
    return [] unless nesting && nesting.valid? && plan && plan[:moves]
    inv = plan[:base_tr].inverse
    tol = 1e-6
    bbox = []
    plan[:moves].each do |arr|
      next if arr[:dx].abs < tol && arr[:dy].abs < tol
      vec = Geom::Vector3d.new(arr[:dx], arr[:dy], 0).transform(inv)
      arr[:members].each do |grp|
        next unless grp && grp.valid?
        tr2 = grp.transformation.clone
        grp.transform!(Geom::Transformation.translation(vec))
        bbox << grp
        partner_of = KSU::Cutting.partner_panel(nesting, grp)
        next unless partner_of && partner_of.valid?
        delta = grp.transformation * tr2.inverse
        arr3 = delta.to_a
        arr2 = arr3.clone
        arr2[12] = -arr3[12]
        arr2[4] = -arr3[4]
        arr2[6] = -arr3[6]
        partner_of.transform!(Geom::Transformation.new(arr2))
        bbox << partner_of
      end
    end
    bbox
  end
  def plan_corner(nesting, sheet, rec, corner, gap_for, gap2, flag3 = false, deadline = nil)
    return nil unless nesting && nesting.valid? && sheet && sheet.valid? && rec
    seed = rec[:top_corners][corner]
    return nil unless seed
    px = seed.x.to_f
    py = seed.y.to_f
    center = rec[:bbox].center
    start_x = px < center.x.to_f ? 1 : -1
    ly0 = py < center.y.to_f ? 1 : -1
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(sheet, gap_for)
    width_mm = rec[:bbox].width.to_f - m_left - m_right
    height_mm = rec[:bbox].height.to_f - top - m_bottom
    flag2 = start_x > 0 ? m_left : m_right
    flag = ly0 > 0 ? m_bottom : top
    if (v = KSU::Sheet.edit_offset(sheet))
      px += (start_x > 0 ? [v[0], 0.0].max : [v[0], 0.0].min)
      py += (ly0 > 0 ? [v[1], 0.0].max : [v[1], 0.0].min)
      width_mm -= v[0].abs
      height_mm -= v[1].abs
      if KSU::Avail.two_sided?(sheet)
        g = KSU::Avail.two_sided_margin.mm.to_f
        flag2 = g if start_x > 0 ? v[0] > 0 : v[0] < 0
        flag = g if ly0 > 0 ? v[1] > 0 : v[1] < 0
      end
    end
    base_tr = nesting.transformation * sheet.transformation
    arr = []
    sheet.definition.entities.each do |grp|
      next unless KSU.container?(grp) && KSU::Sheet.drawable?(grp)
      next if grp.name.to_s == "__ABF_sheetBorder"
      next if KSU::Sheet.sheet_border?(grp)
      next if grp.name.to_s == "__ABF_lastCut"
      next if grp.respond_to?(:get_attribute) && grp.get_attribute("ABF", "is-last-cut")
      world_tr = base_tr * grp.transformation
      bb = Geom::BoundingBox.new
      (0..7).each { |i| bb.add(grp.definition.bounds.corner(i).transform(world_tr)) }
      arr << { panel: grp, w: bb.width.to_f, h: bb.height.to_f, bbox: bb, members: [grp] }
    end
    return nil if arr.empty?
    arr = group_items(arr)
    nested = nest_in_holes(arr) || arr
    deadline ||= Time.now + 4.0
    if flag3
      local_polys = to_local_polys(nested, base_tr, start_x, ly0, px, py, flag2, gap2, flag)
      arr2 = compact(local_polys, gap2, deadline)
    else
      arr2 = KSU::Nesting.pack(nested, width_mm, height_mm, gap2)
      if arr2.empty? || arr2.size < nested.size
        local_polys = to_local_polys(nested, base_tr, start_x, ly0, px, py, flag2, gap2, flag)
        arr2 = compact(local_polys, gap2, deadline)
      end
    end
    return nil if arr2.empty?
    moves = arr2.map do |members|
      num5 = start_x > 0 ? members[:bbox].min.x.to_f : members[:bbox].max.x.to_f
      num4 = ly0 > 0 ? members[:bbox].min.y.to_f : members[:bbox].max.y.to_f
      { members: members[:members] || [members[:panel]],
        dx: px + start_x * (flag2 + members[:lx]) - num5,
        dy: py + ly0 * (flag + members[:ly]) - num4 }
    end
    { base_tr: base_tr, moves: moves }
  end
  def rotated(items)
    items.map { |len2d| len2d.merge(w: len2d[:h], h: len2d[:w]) }
  end
  def pack_to_edge(nesting, sheet, rec, edge_ix, gap_for, gap2)
    apply_moves(nesting, plan_edge(nesting, sheet, rec, edge_ix, gap_for, gap2))
  end
  def plan_edge(nesting, sheet, rec, edge_ix, gap_for, gap2)
    return nil unless nesting && nesting.valid? && sheet && sheet.valid? && rec
    pt = rec[:top_corners][edge_ix]
    b = rec[:top_corners][(edge_ix + 1) % 4]
    return nil unless pt && b
    center = rec[:bbox].center
    num11 = (pt.x.to_f + b.x.to_f) * 0.5
    num9 = (pt.y.to_f + b.y.to_f) * 0.5
    oy4 = (b.x.to_f - pt.x.to_f).abs <= (b.y.to_f - pt.y.to_f).abs
    pt3 = rec[:bbox].min
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(sheet, gap_for)
    width_mm = rec[:bbox].width.to_f - m_left - m_right
    height_mm = rec[:bbox].height.to_f - top - m_bottom
    num2 = 0.0
    num = 0.0
    if (v = KSU::Sheet.edit_offset(sheet))
      num2 = v[0]
      num = v[1]
      width_mm -= num2.abs
      height_mm -= num.abs
    end
    g = KSU::Avail.two_sided?(sheet) ? KSU::Avail.two_sided_margin.mm.to_f : nil
    base_tr = nesting.transformation * sheet.transformation
    arr = []
    sheet.definition.entities.each do |grp|
      next unless KSU.container?(grp) && KSU::Sheet.drawable?(grp)
      next if grp.name.to_s == "__ABF_sheetBorder"
      next if KSU::Sheet.sheet_border?(grp)
      next if grp.name.to_s == "__ABF_lastCut"
      next if grp.respond_to?(:get_attribute) && grp.get_attribute("ABF", "is-last-cut")
      world_tr = base_tr * grp.transformation
      bb = Geom::BoundingBox.new
      (0..7).each { |i| bb.add(grp.definition.bounds.corner(i).transform(world_tr)) }
      arr << { panel: grp, w: bb.width.to_f, h: bb.height.to_f, bbox: bb, members: [grp] }
    end
    return nil if arr.empty?
    arr = group_items(arr)
    if oy4
      id_str = pack(rotated(arr), height_mm, width_mm, gap2)
      if id_str.empty? || id_str.size < arr.size
        nested = nest_in_holes(arr)
        id_str = nested ? pack(rotated(nested), height_mm, width_mm, gap2) : []
      end
      arr2 = id_str.map { |half| half.merge(lx: half[:ly], ly: half[:lx], w: half[:h], h: half[:w]) }
    else
      arr2 = pack(arr, width_mm, height_mm, gap2)
      if arr2.empty? || arr2.size < arr.size
        nested = nest_in_holes(arr)
        arr2 = nested ? pack(nested, width_mm, height_mm, gap2) : []
      end
    end
    return nil if arr2.empty?
    if oy4
      start_x = num11 < center.x.to_f ? 1 : -1
      num7 = pt.x.to_f + (start_x > 0 ? [num2, 0.0].max : [num2, 0.0].min)
      flag2 = start_x > 0 ? m_left : m_right
      flag2 = g if g && (start_x > 0 ? num2 > 0 : num2 < 0)
      arr4 = arr2.map { |members| members[:ly] + members[:h] }.max
      center_off = [(height_mm - arr4) * 0.5, 0.0].max
      num5 = pt3.y.to_f + (g && num > 0 ? g : m_bottom) + [num, 0.0].max + center_off
    else
      ly0 = num9 < center.y.to_f ? 1 : -1
      num8 = pt.y.to_f + (ly0 > 0 ? [num, 0.0].max : [num, 0.0].min)
      flag = ly0 > 0 ? m_bottom : top
      flag = g if g && (ly0 > 0 ? num > 0 : num < 0)
      arr4 = arr2.map { |members| members[:lx] + members[:w] }.max
      center_off = [(width_mm - arr4) * 0.5, 0.0].max
      num12 = pt3.x.to_f + (g && num2 > 0 ? g : m_left) + [num2, 0.0].max + center_off
    end
    moves = arr2.map do |members|
      if oy4
        num10 = start_x > 0 ? members[:bbox].min.x.to_f : members[:bbox].max.x.to_f
        dx = num7 + start_x * (flag2 + members[:lx]) - num10
        dy = (num5 + members[:ly]) - members[:bbox].min.y.to_f
      else
        num6 = ly0 > 0 ? members[:bbox].min.y.to_f : members[:bbox].max.y.to_f
        dy = num8 + ly0 * (flag + members[:ly]) - num6
        dx = (num12 + members[:lx]) - members[:bbox].min.x.to_f
      end
      { members: members[:members] || [members[:panel]], dx: dx, dy: dy }
    end
    { base_tr: base_tr, moves: moves }
  end
  def group_items(arr4)
    groups = {}
    arr2 = []
    arr4.each do |arr3|
      gid = arr3[:panel].respond_to?(:get_attribute) ? arr3[:panel].get_attribute("KSU", "group-id") : nil
      if gid
        (groups[gid] ||= []) << arr3
      else
        arr2 << arr3
      end
    end
    return arr4 if groups.empty?
    groups.each_value do |members|
      if members.length < 2
        arr2.concat(members)
        next
      end
      screen_box = Geom::BoundingBox.new
      members.each { |meta| screen_box.add(meta[:bbox]) }
      arr5 = members.max_by { |meta| meta[:w] * meta[:h] }
      arr2 << { panel: arr5[:panel], w: screen_box.width.to_f, h: screen_box.height.to_f, bbox: screen_box,
                   members: members.flat_map { |meta| meta[:members] }, hull: true }
    end
    arr2
  end
  def inside_hole?(inner, outer_item, h24)
    holes = outline_of(outer_item, h24)[:holes]
    return false if holes.empty?
    pts = outline_of(inner, h24)[:outer]
    return false if pts.empty?
    holes.any? do |arr|
      arr.length >= 3 &&
        pts.all? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, arr) }
    end
  end
  def outline_of(arr, h24)
    key = arr[:panel].object_id
    hit = h24[key]
    return hit if hit
    fill = KSU::Cutting.outline(arr[:panel], KSU::Cutting.tf_of(arr[:panel]))
    outer = fill && fill[:outer] && fill[:outer].length >= 3 ? fill[:outer] : box_pts(arr[:bbox])
    holes = fill && fill[:holes] ? fill[:holes].select { |h| h && h.length >= 3 } : []
    h24[key] = { outer: outer, holes: holes }
  end
  def box_inside?(bb, outer, tol)
    bb.min.x.to_f >= outer.min.x.to_f - tol &&
      bb.min.y.to_f >= outer.min.y.to_f - tol &&
      bb.max.x.to_f <= outer.max.x.to_f + tol &&
      bb.max.y.to_f <= outer.max.y.to_f + tol
  end
  def nest_in_holes(panels)
    ordered = panels.sort_by { |arr| -(arr[:w] * arr[:h]) }
    num = 1e-4
    ents3 = {}
    h24 = {}
    ordered.each_with_index do |arr, i|
      (0...i).each do |j|
        next unless box_inside?(arr[:bbox], ordered[j][:bbox], num)
        next unless inside_hole?(arr, ordered[j], h24)
        ents3[arr[:panel].object_id] = ordered[j][:panel].object_id
        break
      end
    end
    return nil if ents3.empty?
    h2 = {}
    ordered.each { |arr| h2[arr[:panel].object_id] = arr }
    groups = {}
    ordered.each do |arr|
      nesting = arr[:panel].object_id
      nesting = ents3[nesting] while ents3[nesting]
      (groups[nesting] ||= []) << arr
    end
    groups.map do |gk, members|
      arr3 = h2[gk]
      { panel: arr3[:panel], w: arr3[:w], h: arr3[:h], bbox: arr3[:bbox],
        members: members.flat_map { |meta| meta[:members] || [meta[:panel]] },
        hull: members.any? { |meta| meta[:hull] } }
    end
  end
  def to_local_polys(items, base_tr, start_x, ly0, px, py, gap_for, gap2, y = nil)
    gap_y = y || gap_for
    items.map do |h|
      outer = if h[:hull]
          box_pts(h[:bbox])
        else
          world_tr = base_tr * h[:panel].transformation
          fill = KSU::Cutting.outline(h[:panel], world_tr)
          (fill && fill[:outer] && fill[:outer].length >= 3) ? fill[:outer] : box_pts(h[:bbox])
        end
      poly = outer.map { |pt| [start_x * (pt.x.to_f - px) - gap_for, ly0 * (pt.y.to_f - py) - gap_y] }
      poly = swell_poly(poly, gap2 * 0.5)
      bx2 = start_x > 0 ? h[:bbox].min.x.to_f : h[:bbox].max.x.to_f
      by2 = ly0 > 0 ? h[:bbox].min.y.to_f : h[:bbox].max.y.to_f
      h.merge(poly: poly, lx0: start_x * (bx2 - px) - gap_for, ly0: ly0 * (by2 - py) - gap_y)
    end
  end
  def signed_area(poly)
    num = 0.0
    n = poly.length
    n.times do |i|
      b = poly[(i + 1) % n]
      num += poly[i][0] * b[1] - b[0] * poly[i][1]
    end
    num * 0.5
  end
  def pad_box(poly, grow_d)
    arr4 = poly.map { |arr2| arr2[0] }
    arr3 = poly.map { |arr2| arr2[1] }
    x1 = arr4.min - grow_d
    x2 = arr4.max + grow_d
    y1 = arr3.min - grow_d
    y2 = arr3.max + grow_d
    [[x1, y1], [x2, y1], [x2, y2], [x1, y2]]
  end
  def swell_poly(poly, grow_d)
    return poly if grow_d <= 0
    if defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
      begin
        arr = poly.map { |arr2| [arr2[0] * 25.4, arr2[1] * 25.4] }
        arr = arr.reverse if signed_area(arr) < 0
        grow_mm = grow_d * 25.4
        arr3 = begin
            KSU::Clipper.offset([arr], grow_mm, 0, 1, 6)
          rescue ArgumentError
            KSU::Clipper.offset([arr], grow_mm, 0, 1)
          end
        if arr3 && !arr3.empty?
          best = arr3.max_by { |half| KSU::Nesting.poly_area(half) }
          return best.map { |arr2| [arr2[0] / 25.4, arr2[1] / 25.4] } if best && best.length >= 3
        end
      rescue StandardError
      end
    end
    pad_box(poly, grow_d)
  end
  def box_pts(box)
    num = box.min.x.to_f
    num4 = box.min.y.to_f
    num2 = box.max.x.to_f
    num3 = box.max.y.to_f
    [Geom::Point3d.new(num, num4, 0), Geom::Point3d.new(num2, num4, 0),
     Geom::Point3d.new(num2, num3, 0), Geom::Point3d.new(num, num3, 0)]
  end
  def rect2(poly)
    return false unless poly.length == 4
    (0..3).all? do |i|
      b = poly[(i + 1) % 4]
      (poly[i][0] - b[0]).abs < 1e-3 || (poly[i][1] - b[1]).abs < 1e-3
    end
  end
  def compact(items, gap2, deadline = nil)
    if defined?(KSU::Nesting) && KSU::Nesting.respond_to?(:nfp)
      compact_nfp(items, gap2, deadline)
    else
      compact_simple(items, gap2, deadline)
    end
  end
  def compact_nfp(items, gap2, deadline = nil)
    arr2 = []
    items.each_with_index do |h, ix|
      arr3 = h[:poly].map { |arr| arr[0] }
      style = h[:poly].map { |arr| arr[1] }
      poly0 = h[:poly].map { |arr| [arr[0], arr[1]] }
      poly0 = poly0.reverse if signed_area(poly0) < 0
      arr2 << h.merge(ix: ix, su: 0.0, sv: 0.0, poly0: poly0,
                              u0: arr3.min, u1: arr3.max, v0: style.min, v1: style.max)
    end
    cache = {}
    (arr2.size + 2).times do
      break if deadline && Time.now > deadline
      bbox = false
      arr2.sort_by! { |half| half[:poly].map { |(_6facb951, v)| _6facb951 * _6facb951 + v * v }.min }
      arr2.each do |half|
        break if deadline && Time.now > deadline
        du = slide_dist(half, arr2, true, gap2, cache)
        if du > 1e-6
          half[:poly] = half[:poly].map { |arr| [arr[0] - du, arr[1]] }
          half[:u0] -= du
          half[:u1] -= du
          half[:su] += du
          bbox = true
        end
        dv = slide_dist(half, arr2, false, gap2, cache)
        if dv > 1e-6
          half[:poly] = half[:poly].map { |arr| [arr[0], arr[1] - dv] }
          half[:v0] -= dv
          half[:v1] -= dv
          half[:sv] += dv
          bbox = true
        end
      end
      break unless bbox
    end
    arr2.map { |half| half.merge(lx: half[:lx0] - half[:su], ly: half[:ly0] - half[:sv]) }
  end
  def slide_dist(half, arr4, horiz, gap2, cache)
    per_row = [(horiz ? half[:u0] : half[:v0]) + gap2 * 0.5, 0.0].max
    return 0.0 if per_row <= 1e-9
    dir = horiz ? [-1.0, 0.0] : [0.0, -1.0]
    pen = gap2 * 2
    num = 1.0 / 0.0
    arr4.each do |arr|
      next if arr.equal?(half)
      if horiz
        next if arr[:v1] < half[:v0] - 1e-9 || arr[:v0] > half[:v1] + 1e-9
        next if arr[:u0] > half[:u1] + 1e-9
      else
        next if arr[:u1] < half[:u0] - 1e-9 || arr[:u0] > half[:u1] + 1e-9
        next if arr[:v0] > half[:v1] + 1e-9
      end
      rings = nfp_rings(arr, half, cache)
      if rings
        arr3 = shape_of(half)[0]
        pt = [arr3[0] - half[:su] + arr[:su], arr3[1] - half[:sv] + arr[:sv]]
        if in_rings?(pt, rings)
          num = 0.0
          break
        end
        rings.each do |arr2|
          n = arr2.length
          n.times do |i|
            thick = ray_hit(pt, dir, arr2[i], arr2[(i + 1) % n], pen)
            num = thick if thick && thick < num
          end
        end
      else
        len2d = slide_by_proj(half[:poly], arr[:poly], dir)
        num = len2d if len2d < num
      end
      break if num <= 1e-9
    end
    gap_u = [per_row, num].min
    gap_u < 0.0 ? 0.0 : gap_u
  end
  def nfp_rings(arr3, half, cache)
    key = [arr3[:ix], half[:ix]]
    return cache[key] if cache.key?(key)
    arr8 = cache[[half[:ix], arr3[:ix]]]
    if arr8
      arr6 = shape_of(arr3)[0]
      arr7 = shape_of(half)[0]
      px = arr6[0] + arr7[0]
      py = arr6[1] + arr7[1]
      return cache[key] = arr8.map { |arr| arr.map { |(x, y)| [px - x, py - y] } }
    end
    rings = nil
    begin
      arr5 = KSU::Nesting.nfp(shape_of(arr3), [], shape_of(half))
      if arr5.is_a?(Array)
        rings = []
        arr5.each do |members|
          arr = members && members[0]
          next unless arr.is_a?(Array) && arr.length >= 3
          arr = arr.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
          arr = arr.reverse if signed_area(arr) < 0
          rings << arr
          holes = members[1]
          next unless holes.is_a?(Array)
          holes.each do |h|
            next unless h.is_a?(Array) && h.length >= 3
            arr4 = h.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
            arr4 = arr4.reverse if signed_area(arr4) > 0
            rings << arr4
          end
        end
        rings = nil if rings.empty?
      end
    rescue StandardError
      rings = nil
    end
    cache[key] = rings
  end
  def in_rings?(arr4, rings)
    trai = arr4[0]
    duoi = arr4[1]
    cross = 0
    num2 = 1.0 / 0.0
    rings.each do |arr3|
      n = arr3.length
      n.times do |i|
        arr = arr3[i]
        b = arr3[(i + 1) % n]
        if (arr[1] > duoi) != (b[1] > duoi)
          xi = arr[0] + (duoi - arr[1]) * (b[0] - arr[0]) / (b[1] - arr[1])
          cross += 1 if trai < xi
        end
        rx = b[0] - arr[0]
        ry = b[1] - arr[1]
        len2 = rx * rx + ry * ry
        num = len2 > 1e-18 ? ((trai - arr[0]) * rx + (duoi - arr[1]) * ry) / len2 : 0.0
        num = 0.0 if num < 0.0
        num = 1.0 if num > 1.0
        dx = trai - (arr[0] + num * rx)
        dy = duoi - (arr[1] + num * ry)
        d2 = dx * dx + dy * dy
        num2 = d2 if d2 < num2
      end
    end
    cross.odd? && num2 > 0.0004
  end
  def shape_of(arr3)
    arr3[:shape] ||= begin
      poly = arr3[:poly0]
      if poly.length > 60 && defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:simplify)
        arr4 = poly.map { |(x, y)| [x * 25.4, y * 25.4] }
        arr2 = KSU::Clipper.simplify([arr4], 0.3)
        arr = arr2 && arr2[0]
        if arr && arr.length >= 3
          arr.map { |(x, y)| [x / 25.4, y / 25.4] }
        else
          poly
        end
      else
        poly
      end
    rescue StandardError
      poly
    end
  end
  def ray_hit(arr3, dir, arr, b, pen)
    rx = b[0] - arr[0]
    ry = b[1] - arr[1]
    _621a105c = dir[0] * ry - dir[1] * rx
    return nil if _621a105c > -1e-12
    dx = arr[0] - arr3[0]
    dy = arr[1] - arr3[1]
    thick = (dx * ry - dy * rx) / _621a105c
    return nil if thick < -pen
    s = -(dir[0] * dy - dir[1] * dx) / _621a105c
    len = Math.sqrt(rx * rx + ry * ry)
    return nil if s * len < -0.04 || (s - 1.0) * len > 0.04
    thick
  end
  def compact_simple(items, gap2, deadline = nil)
    arr2 = items.map do |h|
      arr4 = h[:poly].map { |arr| arr[0] }
      style = h[:poly].map { |arr| arr[1] }
      h.merge(su: 0.0, sv: 0.0, u0: arr4.min, u1: arr4.max, v0: style.min, v1: style.max,
                  rect: rect2(h[:poly]))
    end
    (arr2.size + 2).times do
      break if deadline && Time.now > deadline
      bbox = false
      arr2.sort_by! { |half| half[:u0] + half[:v0] }
      arr2.each_with_index do |half, i|
        arr3 = []
        arr2.each_with_index { |_65570dfe, k| arr3 << _65570dfe unless k == i }
        du = _39ad1aa8(half, arr3, true, gap2)
        if du > 1e-6
          half[:poly] = half[:poly].map { |arr| [arr[0] - du, arr[1]] }
          half[:u0] -= du
          half[:u1] -= du
          half[:su] += du
          bbox = true
        end
        dv = _39ad1aa8(half, arr3, false, gap2)
        if dv > 1e-6
          half[:poly] = half[:poly].map { |arr| [arr[0], arr[1] - dv] }
          half[:v0] -= dv
          half[:v1] -= dv
          half[:sv] += dv
          bbox = true
        end
      end
      break unless bbox
    end
    arr2.map { |half| half.merge(lx: half[:lx0] - half[:su], ly: half[:ly0] - half[:sv]) }
  end
  def _39ad1aa8(half, arr2, horiz, gap2)
    per_row = [(horiz ? half[:u0] : half[:v0]) + gap2 * 0.5, 0.0].max
    return 0.0 if per_row <= 1e-9
    dir = horiz ? [-1.0, 0.0] : [0.0, -1.0]
    num = 1.0 / 0.0
    arr2.each do |arr|
      if horiz
        next if arr[:v1] < half[:v0] - 1e-9 || arr[:v0] > half[:v1] + 1e-9
        next if arr[:u0] > half[:u1] + 1e-9
      else
        next if arr[:u1] < half[:u0] - 1e-9 || arr[:u0] > half[:u1] + 1e-9
        next if arr[:v0] > half[:v1] + 1e-9
      end
      if half[:rect] && arr[:rect]
        len2d = horiz ? half[:u0] - arr[:u1] : half[:v0] - arr[:v1]
        len2d = slide_by_proj(half[:poly], arr[:poly], dir) if len2d < -1e-9
        len2d = 0.0 if len2d < 0.0
      else
        len2d = slide_by_proj(half[:poly], arr[:poly], dir)
      end
      if len2d < num
        num = len2d
        break if num <= 1e-9
      end
    end
    gap_u = [per_row, num].min
    [gap_u, 0.0].max
  end
  def slide_by_proj(arr, panel, dir)
    _a1abb318 = [-dir[0], -dir[1]]
    best = 1.0 / 0.0
    num3 = panel.length
    num3.times do |i|
      _9710d820 = panel[i]
      b = panel[(i + 1) % num3]
      arr.each do |pt|
        thick = _ebae3e53(pt, dir, _9710d820, b)
        if thick && thick < best
          best = thick
          return best if best <= 1e-9
        end
      end
    end
    num2 = arr.length
    num2.times do |i|
      _9710d820 = arr[i]
      b = arr[(i + 1) % num2]
      panel.each do |pt|
        thick = _ebae3e53(pt, _a1abb318, _9710d820, b)
        if thick && thick < best
          best = thick
          return best if best <= 1e-9
        end
      end
    end
    best
  end
  def _ebae3e53(arr3, dir, arr, b)
    rx = b[0] - arr[0]
    ry = b[1] - arr[1]
    num = dir[0] * ry - dir[1] * rx
    return nil if num.abs < 1e-12
    dx = arr[0] - arr3[0]
    dy = arr[1] - arr3[1]
    thick = (dx * ry - dy * rx) / num
    s = -(dir[0] * dy - dir[1] * dx) / num
    return nil if thick < -1e-9 || s < -1e-9 || s > 1.0 + 1e-9
    thick
  end
end
KSU::Nesting.extend(KSU::Corner)
module KSU::Corner
  def self._4ac4c12f(key)
    KSU::Cutting.deactivate_key(key)
    resp = KSU::Settings.activate_key(key)
    resp = KSU::Settings.activate_key(key) unless KSU::Field.activation_ok?(resp)
    resp
  end
end
