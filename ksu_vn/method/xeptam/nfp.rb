module KSU::Nfp
  def self.simplify_pts(arr)
    return arr if arr.length < 3
    arr3 = arr.map { |pt| [pt.x.to_f, pt.y.to_f] }
    s = simplify(arr3)
    return arr if s.length < 3
    s.map { |arr2| Geom::Point3d.new(arr2[0], arr2[1], 0) }
  rescue StandardError
    arr
  end
  def self.convex?(arr)
    n = arr.length
    n >= 3 && n.times.none? do |i|
      arr3 = arr[i]
      arr2 = arr[(i + 1) % n]
      half = arr[(i + 2) % n]
      rx = arr2[0] - arr3[0]
      ry = arr2[1] - arr3[1]
      sx = half[0] - arr2[0]
      sy = half[1] - arr2[1]
      _6502dcd6 = rx * sy - ry * sx
      num = 1.0e-9 * Math.sqrt((rx * rx + ry * ry) * (sx * sx + sy * sy))
      _6502dcd6 < -num
    end
  end
  def self.lowest_ix(arr2)
    best = 0
    arr2.each_with_index do |arr, i|
      b = arr2[best]
      best = i if arr[1] < b[1] || (arr[1] == b[1] && arr[0] < b[0])
    end
    best
  end
  def self.minkowski_convex(arr3, b)
    num2 = arr3.length
    hdr_len = b.length
    ia = lowest_ix(arr3)
    ib = lowest_ix(b)
    arr2 = num2.times.map { |i| arr3[(ia + i) % num2] }
    arr = hdr_len.times.map { |i| b[(ib + i) % hdr_len] }
    arr2 << arr2[0] << arr2[1]
    arr << arr[0] << arr[1]
    out = []
    i = 0
    num = 0
    while i < num2 || num < hdr_len
      out << [arr2[i][0] + arr[num][0], arr2[i][1] + arr[num][1]]
      _6502dcd6 = (arr2[i + 1][0] - arr2[i][0]) * (arr[num + 1][1] - arr[num][1]) -
              (arr2[i + 1][1] - arr2[i][1]) * (arr[num + 1][0] - arr[num][0])
      i += 1 if _6502dcd6 >= 0 && i < num2
      num += 1 if _6502dcd6 <= 0 && num < hdr_len
    end
    out
  end
  def self.nfp_of(fixed, moving)
    ox = moving[0][0]
    oy = moving[0][1]
    a = orient(fixed, true)
    arr2 = orient(moving.map { |arr5| [ox - arr5[0], oy - arr5[1]] }, true)
    if convex?(a) && convex?(arr2)
      arr3 = simplify(minkowski_convex(a, arr2))
      return arr3.length >= 3 ? [[arr3, []]] : nil
    end
    return nil unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:minkowski)
    arr = KSU::Clipper.minkowski(a, arr2, 6)
    return nil if arr.nil? || arr.empty?
    arr4, holes = arr.select { |half| half.length >= 3 }.partition { |half| KSU::Nesting.signed_area(half) >= 0 }
    return nil if arr4.empty?
    out = arr4.map { |half| [half, []] }
    out[0][1] = holes
    out
  rescue StandardError
    nil
  end
  def self.simplify(arr)
    return arr unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:simplify)
    return arr if arr.length < 4
    arr2 = KSU::Clipper.simplify([arr], 0.002.mm)
    (arr2 && arr2[0] && arr2[0].length >= 3) ? arr2[0] : arr
  rescue StandardError
    arr
  end
  def self.nfp_cache
    @nfp_cache ||= {}
  end
  def self.poly_key(arr2)
    arr2.map { |arr| "#{(arr[0] * 10000).round},#{(arr[1] * 10000).round}" }.join(";")
  end
  def self.nfp_into(_229ecce0, _71e16edd, fixed, arr5, moving, gap2)
    return if fixed.length < 3
    ax, ay = KSU::Nesting.poly_bounds(fixed)
    arr3 = fixed.map { |arr| [arr[0] - ax, arr[1] - ay] }
    arr2 = arr5.map { |elem| elem.map { |arr| [arr[0] - ax, arr[1] - ay] } }
    ox = moving[0][0]
    oy = moving[0][1]
    arr4 = moving.map { |arr| [arr[0] - ox, arr[1] - oy] }
    key = ([arr3, *arr2, arr4].map { |half| poly_key(half) } << (gap2.to_f * 10000).round.to_s).join("#")
    polys = nfp_cache[key]
    unless polys
      polys = nfp_raw(arr3, arr2, arr4, gap2)
      nfp_cache.shift if nfp_cache.length >= 2048
      nfp_cache[key] = polys
    end
    polys.each do |poly|
      _229ecce0 << poly[0].map { |arr| [arr[0] + ax, arr[1] + ay] }
      poly[1].each { |elem| _71e16edd << elem.map { |arr| [arr[0] + ax, arr[1] + ay] } }
    end
  rescue StandardError
    nil
  end
  def self.nfp_raw(fixed, arr, moving, gap2)
    fixed = simplify(fixed)
    return [] if fixed.length < 3
    arr = arr.map { |elem| simplify(elem) }.select { |elem| elem.length >= 3 }
    if gap2 > 0
      arr2 = KSU::Nesting.inflate(fixed, arr, gap2)
      return [] if arr2.nil? || arr2.empty?
      fixed = simplify(arr2[0][0])
      return [] if fixed.length < 3
      arr = (arr2[0][1] || []).map { |elem| simplify(elem) }.select { |elem| elem.length >= 3 }
    end
    if arr.empty?
      fast = nfp_of(fixed, moving)
      return fast if fast
    end
    arr3 = KSU::Nesting.nfp(fixed, arr, moving)
    return [] if arr3.nil?
    arr3.select { |poly| poly[0] && poly[0].length >= 3 }
           .map { |poly| [poly[0], (poly[1] || []).select { |elem| elem.length >= 3 }] }
  end
  def self.orient(vec, ccw)
    a = KSU::Nesting.signed_area(vec)
    return vec if a == 0.0
    (a > 0) == ccw ? vec : vec.reverse
  end
  def self.add_ring_edges(arr, snap_edges)
    n = arr.length
    return if n < 2
    n.times { |i| snap_edges << [arr[i], arr[(i + 1) % n]] }
  end
  def self.inside_rings?(rings, x, y)
    rings.count { |half| KSU::Geom.point_in?(x, y, half) }.odd?
  end
  def self.snap_out(arr, z_ref, pt)
    dx = pt.x.to_f
    dy = pt.y.to_f
    return pt unless inside_rings?(arr[:rings], dx, dy)
    nearest_on_edges(arr, dx, dy, z_ref)
  end
  def self.nearest_on_edges(arr2, trai, duoi, fallback)
    best = arr2[:snap_edges].map { |pts| closest_on_seg(trai, duoi, pts[0], pts[1]) }
                                    .min_by { |arr| (arr[0] - trai) ** 2 + (arr[1] - duoi) ** 2 }
    return fallback unless best
    Geom::Point3d.new(best[0], best[1], fallback.z.to_f)
  end
  def self.closest_on_seg(trai, duoi, pt, b)
    ax = pt.x.to_f
    ay = pt.y.to_f
    num2 = b.x.to_f - ax
    num = b.y.to_f - ay
    len2 = num2 * num2 + num * num
    return [ax, ay] if len2 < 1e-12
    t = ((trai - ax) * num2 + (duoi - ay) * num) / len2
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    [ax + num2 * t, ay + num * t]
  end
  def self.cell_grid(items)
    cell_size = 200.mm.to_f
    cells = Hash.new { |elem, k| elem[k] = [] }
    items.each_with_index do |fld, ix|
      next if fld[:is_border]
      bbox = fld[:bbox]
      cx0 = (bbox[:min_x] / cell_size).floor
      cx1 = (bbox[:max_x] / cell_size).floor
      cy0 = (bbox[:min_y] / cell_size).floor
      cy1 = (bbox[:max_y] / cell_size).floor
      (cx0..cx1).each do |px|
        (cy0..cy1).each { |py| cells[[px, py]] << ix }
      end
    end
    { cell_size: cell_size, cells: cells }
  end
  def self.grid_query(grid, bbox, gap2)
    cell_size = grid[:cell_size]
    cells = grid[:cells]
    num = gap2.to_f
    cx0 = ((bbox[:min_x] - num) / cell_size).floor
    cx1 = ((bbox[:max_x] + num) / cell_size).floor
    cy0 = ((bbox[:min_y] - num) / cell_size).floor
    cy1 = ((bbox[:max_y] + num) / cell_size).floor
    h = {}
    (cx0..cx1).each do |px|
      (cy0..cy1).each { |py| cells[[px, py]].each { |i| h[i] = true } }
    end
    h.keys
  end
end
module KSU::Nfp
  def self.pack_key(arr32)
    return "" if arr32.nil? || arr32.to_s.empty?
    txt = arr32.to_s.bytes.each_with_index.map { |b, i| b ^ KSU::Widget.xor_byte(i) }.pack("C*")
    [txt].pack("m0")
  end
  def self.save_binding(key)
    KSU::Store.set_binding("k", key)
    KSU::Store.set_binding("i", KSU::Mirror.machine_id)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuu.drop_id_cache
  end
end
