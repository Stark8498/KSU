module KSU::Geom
  def self.convex_hull(h)
    return KSU::Method.convex_hull(h) if defined?(KSU::Method) && KSU::Method.respond_to?(:convex_hull)
    arr4 = h.map { |pt| [pt.x.to_f, pt.y.to_f] }.uniq
    return h.dup if arr4.length < 3
    arr4.sort!
    cross = lambda do |arr3, arr5, b|
      (arr5[0] - arr3[0]) * (b[1] - arr3[1]) - (arr5[1] - arr3[1]) * (b[0] - arr3[0])
    end
    arr2 = []
    arr4.each do |pt|
      arr2.pop while arr2.length >= 2 && cross.call(arr2[-2], arr2[-1], pt) <= 0
      arr2 << pt
    end
    arr = []
    arr4.reverse_each do |pt|
      arr.pop while arr.length >= 2 && cross.call(arr[-2], arr[-1], pt) <= 0
      arr << pt
    end
    arr6 = arr2[0...-1] + arr[0...-1]
    return h.dup if arr6.length < 3
    arr6.map { |arr7| Geom::Point3d.new(arr7[0], arr7[1], 0) }
  end
  def self.bounds(arr2)
    arr3 = arr2.map { |pt| pt.x.to_f }
    arr = arr2.map { |pt| pt.y.to_f }
    { min_x: arr3.min, max_x: arr3.max, min_y: arr.min, max_y: arr.max }
  end
  def self.boxes_overlap?(arr, b, gap2)
    num = gap2.to_f
    arr[:min_x] <= b[:max_x] + num &&
      arr[:max_x] >= b[:min_x] - num &&
      arr[:min_y] <= b[:max_y] + num &&
      arr[:max_y] >= b[:min_y] - num
  end
  def self.edge_normals(arr)
    n = arr.size
    n.times.each_with_object([]) do |i, _d46c450b|
      pt = arr[i]
      pt2 = arr[(i + 1) % n]
      rx = pt2.x.to_f - pt.x.to_f
      ry = pt2.y.to_f - pt.y.to_f
      len = Math.sqrt(rx * rx + ry * ry)
      _d46c450b << [-ry / len, rx / len] unless len < 1e-9
    end
  end
  def self.project_range(arr, ax, ay)
    lo = Float::INFINITY
    hi = -Float::INFINITY
    arr.each do |pt|
      len2d = pt.x.to_f * ax + pt.y.to_f * ay
      lo = len2d if len2d < lo
      hi = len2d if len2d > hi
    end
    [lo, hi]
  end
  def self.centroid(arr)
    n = arr.size.to_f
    [arr.inject(0.0) { |s, pt| s + pt.x.to_f } / n, arr.inject(0.0) { |s, pt| s + pt.y.to_f } / n]
  end
  def self.translate(arr, dx, dy)
    arr.map { |pt| Geom::Point3d.new(pt.x.to_f + dx.to_f, pt.y.to_f + dy.to_f, pt.z) }
  end
  def self.sat_mtv(poly_a, poly_b, gap2)
    return KSU::Method.sat_mtv(poly_a, poly_b, gap2) if defined?(KSU::Method)
    arr = edge_normals(poly_a) + edge_normals(poly_b)
    return nil if arr.empty?
    num = gap2.to_f
    min_overlap = Float::INFINITY
    nx = ny = 0.0
    arr.each do |ax, ay|
      a_lo, a_hi = project_range(poly_a, ax, ay)
      b_lo, b_hi = project_range(poly_b, ax, ay)
      overlap = [a_hi, b_hi].min - [a_lo, b_lo].max + num
      return nil if overlap <= 0
      if overlap < min_overlap
        min_overlap = overlap
        nx = ax
        ny = ay
      end
    end
    acx, acy = centroid(poly_a)
    bcx, bcy = centroid(poly_b)
    flag = ((acx - bcx) * nx + (acy - bcy) * ny < 0) ? -1 : 1
    Geom::Vector3d.new(flag * nx * min_overlap, flag * ny * min_overlap, 0)
  end
  def self.point_in?(x, y, arr)
    inside = false
    n = arr.size
    ix = n - 1
    n.times do |i|
      xi = arr[i].x.to_f
      yi = arr[i].y.to_f
      xj = arr[ix].x.to_f
      yj = arr[ix].y.to_f
      if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        inside = !inside
      end
      ix = i
    end
    inside
  end
  def self.cross3(pt, b, pt2)
    (b.x.to_f - pt.x.to_f) * (pt2.y.to_f - pt.y.to_f) -
      (b.y.to_f - pt.y.to_f) * (pt2.x.to_f - pt.x.to_f)
  end
  def self.segments_cross?(p1, p2, p3, p4)
    d1 = cross3(p3, p4, p1)
    d2 = cross3(p3, p4, p2)
    d3 = cross3(p1, p2, p3)
    d4 = cross3(p1, p2, p4)
    ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
  end
  def self.dist2_to_seg(pt2, pt, b)
    ax = pt.x.to_f
    ay = pt.y.to_f
    dx = b.x.to_f - ax
    dy = b.y.to_f - ay
    trai = pt2.x.to_f - ax
    duoi = pt2.y.to_f - ay
    len2 = dx * dx + dy * dy
    return trai * trai + duoi * duoi if len2 < 1e-18
    t = (trai * dx + duoi * dy) / len2
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    rx = trai - t * dx
    ry = duoi - t * dy
    rx * rx + ry * ry
  end
  def self.seg_dist2(a1, a2, b1, b2)
    len2d = dist2_to_seg(a1, b1, b2)
    d2 = dist2_to_seg(a2, b1, b2)
    len2d = d2 if d2 < len2d
    d3 = dist2_to_seg(b1, a1, a2)
    len2d = d3 if d3 < len2d
    d4 = dist2_to_seg(b2, a1, a2)
    len2d = d4 if d4 < len2d
    len2d
  end
  def self.polys_overlap?(arr2, arr, gap2)
    num3 = gap2.to_f
    num = 0.0
    pen_u = pen_v = 0.0
    n = arr.size
    n.times do |i|
      pt = arr[i]
      b = arr[(i + 1) % n]
      rx = b.x.to_f - pt.x.to_f
      ry = b.y.to_f - pt.y.to_f
      len = Math.sqrt(rx * rx + ry * ry)
      next if len < 1e-9
      nx = -ry / len
      ny = rx / len
      num2 = 0.0
      arr2.each do |pt2|
        len2d = (pt2.x.to_f - pt.x.to_f) * nx + (pt2.y.to_f - pt.y.to_f) * ny
        pen = num3 - len2d
        num2 = pen if pen > num2
      end
      if num2 > num
        num = num2
        pen_u = nx
        pen_v = ny
      end
    end
    return nil if num < 1e-9
    Geom::Vector3d.new(pen_u * num, pen_v * num, 0)
  end
  def self.box_corners(bnds, tf = nil)
    return [] unless bnds
    (0..7).map { |i| tf ? bnds.corner(i).transform(tf) : bnds.corner(i) }
  end
  def self.world_box(bnds, tf = nil)
    bbox = Geom::BoundingBox.new
    box_corners(bnds, tf).each { |pt3| bbox.add(pt3) }
    bbox
  end
  def self.merge_near(vals2, tol = 1e-6)
    out = []
    vals2.sort.each { |v| out << v if out.empty? || (v - out.last).abs > tol }
    out
  end
end
