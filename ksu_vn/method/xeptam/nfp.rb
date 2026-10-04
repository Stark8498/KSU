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
  def self.convex?(arr2)
    n = arr2.length
    return false if n < 3
    n.times do |i|
      arr3 = arr2[i]
      arr = arr2[(i + 1) % n]
      half = arr2[(i + 2) % n]
      rx = arr[0] - arr3[0]
      ry = arr[1] - arr3[1]
      sx = half[0] - arr[0]
      sy = half[1] - arr[1]
      cross = rx * sy - ry * sx
      num = 1.0e-9 * Math.sqrt((rx * rx + ry * ry) * (sx * sx + sy * sy))
      return false if cross < -num
    end
    true
  end
  def self.lowest_ix(arr3)
    best = 0
    arr3.each_with_index do |arr2, i|
      b = arr3[best]
      best = i if arr2[1] < b[1] || (arr2[1] == b[1] && arr2[0] < b[0])
    end
    best
  end
  def self.minkowski_convex(arr4, b)
    num3 = arr4.length
    hdr_len = b.length
    ia = lowest_ix(arr4)
    ib = lowest_ix(b)
    arr = num3.times.map { |i| arr4[(ia + i) % num3] }
    arr2 = hdr_len.times.map { |i| b[(ib + i) % hdr_len] }
    arr << arr[0] << arr[1]
    arr2 << arr2[0] << arr2[1]
    out = []
    i = 0
    j = 0
    while i < num3 || j < hdr_len
      out << [arr[i][0] + arr2[j][0], arr[i][1] + arr2[j][1]]
      cross = (arr[i + 1][0] - arr[i][0]) * (arr2[j + 1][1] - arr2[j][1]) -
              (arr[i + 1][1] - arr[i][1]) * (arr2[j + 1][0] - arr2[j][0])
      i += 1 if cross >= 0 && i < num3
      j += 1 if cross <= 0 && j < hdr_len
    end
    out
  end
  def self.nfp_of(fixed, moving)
    ox = moving[0][0]
    oy = moving[0][1]
    area = orient(fixed, true)
    arr3 = orient(moving.map { |arr5| [ox - arr5[0], oy - arr5[1]] }, true)
    if convex?(area) && convex?(arr3)
      arr6 = simplify(minkowski_convex(area, arr3))
      return arr6.length >= 3 ? [[arr6, []]] : nil
    end
    return nil unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:minkowski)
    arr2 = KSU::Clipper.minkowski(area, arr3, 6)
    return nil if arr2.nil? || arr2.empty?
    arr4 = []
    holes = []
    arr2.each do |half|
      next if half.length < 3
      (ring_area(half) >= 0 ? arr4 : holes) << half
    end
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
  def self.nfp_key(fixed, arr, moving, gap2)
    parts = [poly_key(fixed)]
    arr.each { |h| parts << poly_key(h) }
    parts << poly_key(moving)
    parts << (gap2.to_f * 10000).round.to_s
    parts.join("#")
  end
  def self.nfp_into(outers, holes, fixed, arr7, moving, gap2)
    return if fixed.length < 3
    ax = ay = nil
    fixed.each do |arr|
      ax = arr[0] if ax.nil? || arr[0] < ax
      ay = arr[1] if ay.nil? || arr[1] < ay
    end
    arr6 = fixed.map { |arr| [arr[0] - ax, arr[1] - ay] }
    arr4 = arr7.map { |h| h.map { |arr| [arr[0] - ax, arr[1] - ay] } }
    ox = moving[0][0]
    oy = moving[0][1]
    arr5 = moving.map { |arr| [arr[0] - ox, arr[1] - oy] }
    key = nfp_key(arr6, arr4, arr5, gap2)
    polys = nfp_cache[key]
    unless polys
      polys = nfp_raw(arr6, arr4, arr5, gap2)
      nfp_cache.shift if nfp_cache.length >= 2048
      nfp_cache[key] = polys
    end
    polys.each do |poly|
      outers << poly[0].map { |arr| [arr[0] + ax, arr[1] + ay] }
      poly[1].each { |h| holes << h.map { |arr| [arr[0] + ax, arr[1] + ay] } }
    end
  rescue StandardError
    nil
  end
  def self.nfp_raw(fixed, arr2, moving, gap2)
    fixed = simplify(fixed)
    return [] if fixed.length < 3
    arr2 = arr2.map { |h| simplify(h) }.select { |h| h.length >= 3 }
    if gap2 > 0
      arr3 = KSU::Nesting.inflate(fixed, arr2, gap2)
      return [] if arr3.nil? || arr3.empty?
      fixed = simplify(arr3[0][0])
      return [] if fixed.length < 3
      arr2 = (arr3[0][1] || []).map { |h| simplify(h) }.select { |h| h.length >= 3 }
    end
    if arr2.empty?
      fast = nfp_of(fixed, moving)
      return fast if fast
    end
    arr4 = KSU::Nesting.nfp(fixed, arr2, moving)
    return [] if arr4.nil?
    out = []
    arr4.each do |poly|
      outer = poly[0]
      next unless outer && outer.length >= 3
      out << [outer, (poly[1] || []).select { |h| h.length >= 3 }]
    end
    out
  end
  def self.ring_area(arr)
    s = 0.0
    n = arr.length
    n.times do |i|
      arr3 = arr[i]
      arr2 = arr[(i + 1) % n]
      s += arr3[0].to_f * arr2[1].to_f - arr2[0].to_f * arr3[1].to_f
    end
    s * 0.5
  end
  def self.orient(vec, ccw)
    area = ring_area(vec)
    return vec if area == 0.0
    (area > 0) == ccw ? vec : vec.reverse
  end
  def self.add_ring_edges(arr, snap_edges)
    n = arr.length
    return if n < 2
    n.times { |i| snap_edges << [arr[i], arr[(i + 1) % n]] }
  end
  def self.inside_rings?(rings, x, y)
    color = 0
    rings.each { |half| color += 1 if KSU::Geom.point_in?(x, y, half) }
    color.odd?
  end
  def self.snap_out(arr, z_ref, pt)
    dx = pt.x.to_f
    dy = pt.y.to_f
    return pt unless inside_rings?(arr[:rings], dx, dy)
    nearest_on_edges(arr, dx, dy, z_ref)
  end
  def self.nearest_on_edges(arr3, trai, duoi, pt)
    best = nil
    best_d2 = nil
    arr3[:snap_edges].each do |poly|
      arr2 = closest_on_seg(trai, duoi, poly[0], poly[1])
      d2 = (arr2[0] - trai) ** 2 + (arr2[1] - duoi) ** 2
      if best_d2.nil? || d2 < best_d2
        best_d2 = d2
        best = arr2
      end
    end
    return pt unless best
    Geom::Point3d.new(best[0], best[1], pt.z.to_f)
  end
  def self.closest_on_seg(trai, duoi, pt2, b)
    ax = pt2.x.to_f
    ay = pt2.y.to_f
    num2 = b.x.to_f - ax
    num3 = b.y.to_f - ay
    len2 = num2 * num2 + num3 * num3
    return [ax, ay] if len2 < 1e-12
    thick = ((trai - ax) * num2 + (duoi - ay) * num3) / len2
    thick = 0.0 if thick < 0.0
    thick = 1.0 if thick > 1.0
    [ax + num2 * thick, ay + num3 * thick]
  end
  def self.cell_grid(items)
    cell_size = 200.mm.to_f
    cells = Hash.new { |h, k| h[k] = [] }
    items.each_with_index do |fld, ix|
      next if fld[:is_border]
      bbox = fld[:bbox]
      cx0 = (bbox[:min_x] / cell_size).floor
      cx1 = (bbox[:max_x] / cell_size).floor
      cy0 = (bbox[:min_y] / cell_size).floor
      cy1 = (bbox[:max_y] / cell_size).floor
      (cx0..cx1).each do |px|
        (cy0..cy1).each do |py|
          cells[[px, py]] << ix
        end
      end
    end
    { cell_size: cell_size, cells: cells }
  end
  def self.grid_query(grid, bbox, gap2)
    cell_size = grid[:cell_size]
    cells = grid[:cells]
    g = gap2.to_f
    cx0 = ((bbox[:min_x] - g) / cell_size).floor
    cx1 = ((bbox[:max_x] + g) / cell_size).floor
    cy0 = ((bbox[:min_y] - g) / cell_size).floor
    cy1 = ((bbox[:max_y] + g) / cell_size).floor
    seen = {}
    (cx0..cx1).each do |px|
      (cy0..cy1).each do |py|
        arr = cells[[px, py]]
        next if arr.empty?
        arr.each { |i| seen[i] = true }
      end
    end
    seen.keys
  end
end
module KSU::Nfp
  def self.pack_key(arr61)
    return "" if arr61.nil? || arr61.to_s.empty?
    txt = arr61.to_s.bytes.each_with_index.map { |b, i| b ^ KSU::Widget.xor_byte(i) }.pack("C*")
    [txt].pack("m0")
  end
  def self.save_binding(key)
    KSU::Store.set_binding("k", key)
    KSU::Store.set_binding("i", KSU::Mirror.machine_id)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuuvan.drop_id_cache
  end
end
