module KSU::Corner
  def pack_to_corner(nesting, sheet, rec, corner, gap_for, gap2, flag = false, deadline = nil)
    apply_moves(nesting, plan_corner(nesting, sheet, rec, corner, gap_for, gap2, flag, deadline))
  end
  def apply_moves(nesting, plan)
    return [] unless nesting && nesting.valid? && plan && plan[:moves]
    inv = plan[:base_tr].inverse
    bbox = []
    plan[:moves].each do |arr|
      next if arr[:dx].abs < 1e-6 && arr[:dy].abs < 1e-6
      vec = Geom::Vector3d.new(arr[:dx], arr[:dy], 0).transform(inv)
      arr[:members].each do |grp|
        next unless grp && grp.valid?
        tr = grp.transformation.clone
        grp.transform!(Geom::Transformation.translation(vec))
        bbox << grp
        partner_of = KSU::Cutting.partner_panel(nesting, grp)
        next unless partner_of && partner_of.valid?
        _9fe6030e = (grp.transformation * tr.inverse).to_a
        _9fe6030e[12] = -_9fe6030e[12]
        _9fe6030e[4] = -_9fe6030e[4]
        _9fe6030e[6] = -_9fe6030e[6]
        partner_of.transform!(Geom::Transformation.new(_9fe6030e))
        bbox << partner_of
      end
    end
    bbox
  end
  def plan_corner(nesting, grp2, rec, corner2, gap_for, gap2, flag3 = false, deadline = nil)
    return nil unless nesting && nesting.valid? && grp2 && grp2.valid? && rec
    corner = rec[:top_corners][corner2]
    return nil unless corner
    px = corner.x.to_f
    py = corner.y.to_f
    center = rec[:bbox].center
    start_x = px < center.x.to_f ? 1 : -1
    ly0 = py < center.y.to_f ? 1 : -1
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(grp2, gap_for)
    width_mm = rec[:bbox].width.to_f - m_left - m_right
    height_mm = rec[:bbox].height.to_f - top - m_bottom
    flag2 = start_x > 0 ? m_left : m_right
    flag = ly0 > 0 ? m_bottom : top
    if (v = KSU::Sheet.edit_offset(grp2))
      px += (start_x > 0 ? [v[0], 0.0].max : [v[0], 0.0].min)
      py += (ly0 > 0 ? [v[1], 0.0].max : [v[1], 0.0].min)
      width_mm -= v[0].abs
      height_mm -= v[1].abs
      if KSU::Avail.two_sided?(grp2)
        num = KSU::Avail.two_sided_margin.mm.to_f
        flag2 = num if start_x > 0 ? v[0] > 0 : v[0] < 0
        flag = num if ly0 > 0 ? v[1] > 0 : v[1] < 0
      end
    end
    base_tr = nesting.transformation * grp2.transformation
    arr = []
    grp2.definition.entities.each do |grp|
      next unless KSU.container?(grp) && KSU::Sheet.drawable?(grp)
      next if grp.name.to_s == "__ABF_sheetBorder" || KSU::Sheet.sheet_border?(grp) || last_cut?(grp)
      bb = KSU::Geom.world_box(grp.definition.bounds, base_tr * grp.transformation)
      arr << { panel: grp, w: bb.width.to_f, h: bb.height.to_f, bbox: bb, members: [grp] }
    end
    return nil if arr.empty?
    arr = group_items(arr)
    nested = nest_in_holes(arr) || arr
    deadline ||= Time.now + 4.0
    arr2 = flag3 ? [] : KSU::Nesting.pack(nested, width_mm, height_mm, gap2)
    if arr2.empty? || arr2.size < nested.size
      local_polys = to_local_polys(nested, base_tr, start_x, ly0, px, py, flag2, gap2, flag)
      arr2 = compact(local_polys, gap2, deadline)
    end
    return nil if arr2.empty?
    moves = arr2.map do |members|
      num2 = start_x > 0 ? members[:bbox].min.x.to_f : members[:bbox].max.x.to_f
      num3 = ly0 > 0 ? members[:bbox].min.y.to_f : members[:bbox].max.y.to_f
      { members: members[:members] || [members[:panel]],
        dx: px + start_x * (flag2 + members[:lx]) - num2,
        dy: py + ly0 * (flag + members[:ly]) - num3 }
    end
    { base_tr: base_tr, moves: moves }
  end
  def rotated(items)
    items.map { |len2d| len2d.merge(w: len2d[:h], h: len2d[:w]) }
  end
  def pack_to_edge(nesting, sheet, rec, edge_ix, gap_for, gap2)
    apply_moves(nesting, plan_edge(nesting, sheet, rec, edge_ix, gap_for, gap2))
  end
  def plan_edge(nesting, grp2, rec, edge_ix, gap_for, gap2)
    return nil unless nesting && nesting.valid? && grp2 && grp2.valid? && rec
    pt = rec[:top_corners][edge_ix]
    b = rec[:top_corners][(edge_ix + 1) % 4]
    return nil unless pt && b
    center = rec[:bbox].center
    num6 = (pt.x.to_f + b.x.to_f) * 0.5
    num4 = (pt.y.to_f + b.y.to_f) * 0.5
    oy4 = (b.x.to_f - pt.x.to_f).abs <= (b.y.to_f - pt.y.to_f).abs
    pt2 = rec[:bbox].min
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(grp2, gap_for)
    num2, num3 = KSU::Sheet.edit_offset(grp2) || [0.0, 0.0]
    width_mm = rec[:bbox].width.to_f - m_left - m_right - num2.abs
    height_mm = rec[:bbox].height.to_f - top - m_bottom - num3.abs
    num = KSU::Avail.two_sided?(grp2) ? KSU::Avail.two_sided_margin.mm.to_f : nil
    base_tr = nesting.transformation * grp2.transformation
    arr2 = []
    grp2.definition.entities.each do |grp|
      next unless KSU.container?(grp) && KSU::Sheet.drawable?(grp)
      next if grp.name.to_s == "__ABF_sheetBorder" || KSU::Sheet.sheet_border?(grp) || last_cut?(grp)
      bb = KSU::Geom.world_box(grp.definition.bounds, base_tr * grp.transformation)
      arr2 << { panel: grp, w: bb.width.to_f, h: bb.height.to_f, bbox: bb, members: [grp] }
    end
    return nil if arr2.empty?
    arr2 = group_items(arr2)
    dump_database = lambda do |items|
      oy4 ? pack(rotated(items), height_mm, width_mm, gap2) : pack(items, width_mm, height_mm, gap2)
    end
    arr = dump_database.call(arr2)
    if arr.empty? || arr.size < arr2.size
      nested = nest_in_holes(arr2)
      arr = nested ? dump_database.call(nested) : []
    end
    arr = arr.map { |half| half.merge(lx: half[:ly], ly: half[:lx], w: half[:h], h: half[:w]) } if oy4
    return nil if arr.empty?
    if oy4
      start_x = num6 < center.x.to_f ? 1 : -1
      num11 = pt.x.to_f + (start_x > 0 ? [num2, 0.0].max : [num2, 0.0].min)
      flag2 = start_x > 0 ? m_left : m_right
      flag2 = num if num && (start_x > 0 ? num2 > 0 : num2 < 0)
      arr3 = arr.map { |members| members[:ly] + members[:h] }.max
      center_off = [(height_mm - arr3) * 0.5, 0.0].max
      num8 = pt2.y.to_f + (num && num3 > 0 ? num : m_bottom) + [num3, 0.0].max + center_off
    else
      ly0 = num4 < center.y.to_f ? 1 : -1
      num7 = pt.y.to_f + (ly0 > 0 ? [num3, 0.0].max : [num3, 0.0].min)
      flag = ly0 > 0 ? m_bottom : top
      flag = num if num && (ly0 > 0 ? num3 > 0 : num3 < 0)
      arr3 = arr.map { |members| members[:lx] + members[:w] }.max
      center_off = [(width_mm - arr3) * 0.5, 0.0].max
      num5 = pt2.x.to_f + (num && num2 > 0 ? num : m_left) + [num2, 0.0].max + center_off
    end
    moves = arr.map do |members|
      if oy4
        num10 = start_x > 0 ? members[:bbox].min.x.to_f : members[:bbox].max.x.to_f
        dx = num11 + start_x * (flag2 + members[:lx]) - num10
        dy = (num8 + members[:ly]) - members[:bbox].min.y.to_f
      else
        num9 = ly0 > 0 ? members[:bbox].min.y.to_f : members[:bbox].max.y.to_f
        dy = num7 + ly0 * (flag + members[:ly]) - num9
        dx = (num5 + members[:lx]) - members[:bbox].min.x.to_f
      end
      { members: members[:members] || [members[:panel]], dx: dx, dy: dy }
    end
    { base_tr: base_tr, moves: moves }
  end
  def group_items(arr3)
    groups = {}
    arr2 = []
    arr3.each do |arr|
      flag = arr[:panel].respond_to?(:get_attribute) ? arr[:panel].get_attribute("KSU", "group-id") : nil
      if flag
        (groups[flag] ||= []) << arr
      else
        arr2 << arr
      end
    end
    return arr3 if groups.empty?
    groups.each_value do |members|
      next arr2.concat(members) if members.length < 2
      screen_box = Geom::BoundingBox.new
      members.each { |meta| screen_box.add(meta[:bbox]) }
      arr4 = members.max_by { |meta| meta[:w] * meta[:h] }
      arr2 << { panel: arr4[:panel], w: screen_box.width.to_f, h: screen_box.height.to_f, bbox: screen_box,
                   members: members.flat_map { |meta| meta[:members] }, hull: true }
    end
    arr2
  end
  def inside_hole?(inner, outer_item, h27)
    holes = outline_of(outer_item, h27)[:holes]
    return false if holes.empty?
    arr2 = outline_of(inner, h27)[:outer]
    return false if arr2.empty?
    holes.any? do |arr|
      arr.length >= 3 &&
        arr2.all? { |pt| KSU::Geom.point_in?(pt.x.to_f, pt.y.to_f, arr) }
    end
  end
  def outline_of(arr, h27)
    h27[arr[:panel].object_id] ||= begin
      fill = KSU::Cutting.outline(arr[:panel], KSU::Cutting.tf_of(arr[:panel]))
      { outer: fill && fill[:outer] && fill[:outer].length >= 3 ? fill[:outer] : box_pts(arr[:bbox]),
        holes: fill && fill[:holes] ? fill[:holes].select { |elem| elem && elem.length >= 3 } : [] }
    end
  end
  def box_inside?(inner, outer, eps)
    inner.min.x.to_f >= outer.min.x.to_f - eps &&
      inner.min.y.to_f >= outer.min.y.to_f - eps &&
      inner.max.x.to_f <= outer.max.x.to_f + eps &&
      inner.max.y.to_f <= outer.max.y.to_f + eps
  end
  def nest_in_holes(panels)
    ordered = panels.sort_by { |arr| -(arr[:w] * arr[:h]) }
    eps = 1e-4
    ents3 = {}
    h27 = {}
    ordered.each_with_index do |arr, i|
      (0...i).each do |ix|
        next unless box_inside?(arr[:bbox], ordered[ix][:bbox], eps)
        next unless inside_hole?(arr, ordered[ix], h27)
        ents3[arr[:panel].object_id] = ordered[ix][:panel].object_id
        break
      end
    end
    return nil if ents3.empty?
    h = {}
    ordered.each { |arr| h[arr[:panel].object_id] = arr }
    groups = {}
    ordered.each do |arr|
      nesting = arr[:panel].object_id
      nesting = ents3[nesting] while ents3[nesting]
      (groups[nesting] ||= []) << arr
    end
    groups.map do |gk, members|
      arr2 = h[gk]
      { panel: arr2[:panel], w: arr2[:w], h: arr2[:h], bbox: arr2[:bbox],
        members: members.flat_map { |meta| meta[:members] || [meta[:panel]] },
        hull: members.any? { |meta| meta[:hull] } }
    end
  end
  def to_local_polys(items, base_tr, start_x, ly0, px, py, gap_for, gap2, _5f765dbc = nil)
    gap_y = _5f765dbc || gap_for
    items.map do |h|
      outer = if h[:hull]
          box_pts(h[:bbox])
        else
          fill = KSU::Cutting.outline(h[:panel], base_tr * h[:panel].transformation)
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
    text, y0, x1, y1 = poly_bounds(poly)
    [[text - grow_d, y0 - grow_d], [x1 + grow_d, y0 - grow_d], [x1 + grow_d, y1 + grow_d], [text - grow_d, y1 + grow_d]]
  end
  def swell_poly(poly, grow_d)
    return poly if grow_d <= 0
    if defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
      begin
        arr2 = poly.map { |arr| [arr[0] * 25.4, arr[1] * 25.4] }
        arr2 = arr2.reverse if signed_area(arr2) < 0
        grow_mm = grow_d * 25.4
        arr3 = begin
            KSU::Clipper.offset([arr2], grow_mm, 0, 1, 6)
          rescue ArgumentError
            KSU::Clipper.offset([arr2], grow_mm, 0, 1)
          end
        if arr3 && !arr3.empty?
          best = arr3.max_by { |half| KSU::Nesting.poly_area(half) }
          return best.map { |arr| [arr[0] / 25.4, arr[1] / 25.4] } if best && best.length >= 3
        end
      rescue StandardError
      end
    end
    pad_box(poly, grow_d)
  end
  def box_pts(box)
    num = box.min.x.to_f
    num3 = box.min.y.to_f
    num2 = box.max.x.to_f
    num4 = box.max.y.to_f
    [Geom::Point3d.new(num, num3, 0), Geom::Point3d.new(num2, num3, 0),
     Geom::Point3d.new(num2, num4, 0), Geom::Point3d.new(num, num4, 0)]
  end
  def rect2(poly)
    return false unless poly.length == 4
    (0..3).all? do |i|
      b = poly[(i + 1) % 4]
      (poly[i][0] - b[0]).abs < 1e-3 || (poly[i][1] - b[1]).abs < 1e-3
    end
  end
  def compact(items, gap2, deadline = nil)
    KSU::Nesting.respond_to?(:nfp) ? compact_nfp(items, gap2, deadline) : compact_simple(items, gap2, deadline)
  end
  def compact_nfp(items, gap2, deadline = nil)
    arr2 = items.each_with_index.map do |h, _4168a8e5|
      arr3 = h[:poly].map { |arr| arr[0] }
      style = h[:poly].map { |arr| arr[1] }
      poly0 = h[:poly].map { |arr| [arr[0], arr[1]] }
      poly0 = poly0.reverse if signed_area(poly0) < 0
      h.merge(ix: _4168a8e5, su: 0.0, sv: 0.0, poly0: poly0, u0: arr3.min, u1: arr3.max, v0: style.min, v1: style.max)
    end
    cache = {}
    (arr2.size + 2).times do
      break if deadline && Time.now > deadline
      bbox = false
      arr2.sort_by! { |half| half[:poly].map { |(u, v)| u * u + v * v }.min }
      arr2.each do |half|
        break if deadline && Time.now > deadline
        [true, false].each do |horiz|
          len2d = slide_dist(half, arr2, horiz, gap2, cache)
          next unless len2d > 1e-6
          half[:poly] = half[:poly].map { |arr| horiz ? [arr[0] - len2d, arr[1]] : [arr[0], arr[1] - len2d] }
          _e2f2d156, _95bf7c9d, flag = horiz ? %i[u0 u1 su] : %i[v0 v1 sv]
          half[_e2f2d156] -= len2d
          half[_95bf7c9d] -= len2d
          half[flag] += len2d
          bbox = true
        end
      end
      break unless bbox
    end
    arr2.map { |half| half.merge(lx: half[:lx0] - half[:su], ly: half[:ly0] - half[:sv]) }
  end
  def slide_dist(half, arr3, horiz, gap2, cache)
    per_row = [(horiz ? half[:u0] : half[:v0]) + gap2 * 0.5, 0.0].max
    return 0.0 if per_row <= 1e-9
    dir = horiz ? [-1.0, 0.0] : [0.0, -1.0]
    pen = gap2 * 2
    num = 1.0 / 0.0
    arr3.each do |arr|
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
        entity_ref = shape_of(half)[0]
        pt3 = [entity_ref[0] - half[:su] + arr[:su], entity_ref[1] - half[:sv] + arr[:sv]]
        if in_rings?(pt3, rings)
          num = 0.0
          break
        end
        rings.each do |arr2|
          n = arr2.length
          n.times do |i|
            t = ray_hit(pt3, dir, arr2[i], arr2[(i + 1) % n], pen)
            num = t if t && t < num
          end
        end
      else
        len2d = slide_by_proj(half[:poly], arr[:poly], dir)
        num = len2d if len2d < num
      end
      break if num <= 1e-9
    end
    arr22 = [per_row, num].min
    arr22 < 0.0 ? 0.0 : arr22
  end
  def nfp_rings(arr3, half, cache)
    key = [arr3[:ix], half[:ix]]
    return cache[key] if cache.key?(key)
    arr6 = cache[[half[:ix], arr3[:ix]]]
    if arr6
      arr5 = shape_of(arr3)[0]
      arr8 = shape_of(half)[0]
      px = arr5[0] + arr8[0]
      py = arr5[1] + arr8[1]
      return cache[key] = arr6.map { |arr| arr.map { |(x, y)| [px - x, py - y] } }
    end
    rings = nil
    begin
      arr7 = KSU::Nesting.nfp(shape_of(arr3), [], shape_of(half))
      if arr7.is_a?(Array)
        rings = []
        arr7.each do |members|
          arr = members && members[0]
          next unless arr.is_a?(Array) && arr.length >= 3
          arr = arr.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
          arr = arr.reverse if signed_area(arr) < 0
          rings << arr
          holes = members[1]
          next unless holes.is_a?(Array)
          holes.each do |elem|
            next unless elem.is_a?(Array) && elem.length >= 3
            arr4 = elem.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
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
  def in_rings?(arr3, rings)
    trai = arr3[0]
    duoi = arr3[1]
    cross = 0
    num2 = 1.0 / 0.0
    rings.each do |arr2|
      n = arr2.length
      n.times do |i|
        arr = arr2[i]
        b = arr2[(i + 1) % n]
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
  def shape_of(arr2)
    arr2[:shape] ||= begin
      poly = arr2[:poly0]
      if poly.length > 60 && defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:simplify)
        arr3 = KSU::Clipper.simplify([poly.map { |(x, y)| [x * 25.4, y * 25.4] }], 0.3)
        arr = arr3 && arr3[0]
      end
      arr && arr.length >= 3 ? arr.map { |(x, y)| [x / 25.4, y / 25.4] } : poly
    rescue StandardError
      poly
    end
  end
  def ray_hit(arr2, dir, arr, b, pen)
    rx = b[0] - arr[0]
    ry = b[1] - arr[1]
    _6502dcd6 = dir[0] * ry - dir[1] * rx
    return nil if _6502dcd6 > -1e-12
    dx = arr[0] - arr2[0]
    dy = arr[1] - arr2[1]
    t = (dx * ry - dy * rx) / _6502dcd6
    return nil if t < -pen
    s = -(dir[0] * dy - dir[1] * dx) / _6502dcd6
    len = Math.sqrt(rx * rx + ry * ry)
    return nil if s * len < -0.04 || (s - 1.0) * len > 0.04
    t
  end
  def compact_simple(items, gap2, deadline = nil)
    arr2 = items.map do |h|
      arr3 = h[:poly].map { |arr| arr[0] }
      style = h[:poly].map { |arr| arr[1] }
      h.merge(su: 0.0, sv: 0.0, u0: arr3.min, u1: arr3.max, v0: style.min, v1: style.max,
                  rect: rect2(h[:poly]))
    end
    (arr2.size + 2).times do
      break if deadline && Time.now > deadline
      bbox = false
      arr2.sort_by! { |half| half[:u0] + half[:v0] }
      arr2.each_with_index do |half, i4|
        arr4 = arr2.reject.with_index { |_1c52ed7c, k| k == i4 }
        [true, false].each do |horiz|
          len2d = slide_in(half, arr4, horiz, gap2)
          next unless len2d > 1e-6
          half[:poly] = half[:poly].map { |arr| horiz ? [arr[0] - len2d, arr[1]] : [arr[0], arr[1] - len2d] }
          _e2f2d156, _95bf7c9d, flag = horiz ? %i[u0 u1 su] : %i[v0 v1 sv]
          half[_e2f2d156] -= len2d
          half[_95bf7c9d] -= len2d
          half[flag] += len2d
          bbox = true
        end
      end
      break unless bbox
    end
    arr2.map { |half| half.merge(lx: half[:lx0] - half[:su], ly: half[:ly0] - half[:sv]) }
  end
  def slide_in(half, arr2, horiz, gap2)
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
    arr22 = [per_row, num].min
    [arr22, 0.0].max
  end
  def slide_by_proj(arr22, panel, dir)
    back_dir = [-dir[0], -dir[1]]
    best = 1.0 / 0.0
    num = panel.length
    num.times do |i|
      a = panel[i]
      b = panel[(i + 1) % num]
      arr22.each do |pt3|
        t = ray_t(pt3, dir, a, b)
        if t && t < best
          best = t
          return best if best <= 1e-9
        end
      end
    end
    num2 = arr22.length
    num2.times do |i|
      a = arr22[i]
      b = arr22[(i + 1) % num2]
      panel.each do |pt3|
        t = ray_t(pt3, back_dir, a, b)
        if t && t < best
          best = t
          return best if best <= 1e-9
        end
      end
    end
    best
  end
  def ray_t(arr2, dir, arr, b)
    rx = b[0] - arr[0]
    ry = b[1] - arr[1]
    num = dir[0] * ry - dir[1] * rx
    return nil if num.abs < 1e-12
    dx = arr[0] - arr2[0]
    dy = arr[1] - arr2[1]
    t = (dx * ry - dy * rx) / num
    s = -(dir[0] * dy - dir[1] * dx) / num
    return nil if t < -1e-9 || s < -1e-9 || s > 1.0 + 1e-9
    t
  end
end
KSU::Nesting.extend(KSU::Corner)
module KSU::Corner
  def self.deactivate_now(key)
    KSU::Cutting.deactivate_key(key)
    resp = KSU::Settings.activate_key(key)
    resp = KSU::Settings.activate_key(key) unless KSU::Field.activation_ok?(resp)
    resp
  end
end
