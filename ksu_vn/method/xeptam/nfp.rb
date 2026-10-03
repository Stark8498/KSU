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
      _2a1092ed = half[1] - arr[1]
      _621a105c = rx * _2a1092ed - ry * sx
      num = 1.0e-9 * Math.sqrt((rx * rx + ry * ry) * (sx * sx + _2a1092ed * _2a1092ed))
      return false if _621a105c < -num
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
    num4 = b.length
    ia = lowest_ix(arr4)
    ib = lowest_ix(b)
    arr = num3.times.map { |i| arr4[(ia + i) % num3] }
    arr2 = num4.times.map { |i| b[(ib + i) % num4] }
    arr << arr[0] << arr[1]
    arr2 << arr2[0] << arr2[1]
    out = []
    i = 0
    j = 0
    while i < num3 || j < num4
      out << [arr[i][0] + arr2[j][0], arr[i][1] + arr2[j][1]]
      _621a105c = (arr[i + 1][0] - arr[i][0]) * (arr2[j + 1][1] - arr2[j][1]) -
              (arr[i + 1][1] - arr[i][1]) * (arr2[j + 1][0] - arr2[j][0])
      i += 1 if _621a105c >= 0 && i < num3
      j += 1 if _621a105c <= 0 && j < num4
    end
    out
  end
  def self.nfp_of(fixed, moving)
    ox = moving[0][0]
    oy = moving[0][1]
    _9710d820 = _5762df6e(fixed, true)
    arr3 = _5762df6e(moving.map { |arr5| [ox - arr5[0], oy - arr5[1]] }, true)
    if convex?(_9710d820) && convex?(arr3)
      arr6 = simplify(minkowski_convex(_9710d820, arr3))
      return arr6.length >= 3 ? [[arr6, []]] : nil
    end
    return nil unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:minkowski)
    arr2 = KSU::Clipper.minkowski(_9710d820, arr3, 6)
    return nil if arr2.nil? || arr2.empty?
    arr4 = []
    holes = []
    arr2.each do |half|
      next if half.length < 3
      (_3b7ac698(half) >= 0 ? arr4 : holes) << half
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
    arr.each { |arr52| parts << poly_key(arr52) }
    parts << poly_key(moving)
    parts << (gap2.to_f * 10000).round.to_s
    parts.join("#")
  end
  def self._3ea4c8e4(_39341bf8, _99491fe1, fixed, arr7, moving, gap2)
    return if fixed.length < 3
    ax = ay = nil
    fixed.each do |arr|
      ax = arr[0] if ax.nil? || arr[0] < ax
      ay = arr[1] if ay.nil? || arr[1] < ay
    end
    arr6 = fixed.map { |arr| [arr[0] - ax, arr[1] - ay] }
    arr4 = arr7.map { |arr52| arr52.map { |arr| [arr[0] - ax, arr[1] - ay] } }
    ox = moving[0][0]
    oy = moving[0][1]
    arr5 = moving.map { |arr| [arr[0] - ox, arr[1] - oy] }
    key = nfp_key(arr6, arr4, arr5, gap2)
    polys = nfp_cache[key]
    unless polys
      polys = _00adeb53(arr6, arr4, arr5, gap2)
      nfp_cache.shift if nfp_cache.length >= 2048
      nfp_cache[key] = polys
    end
    polys.each do |poly|
      _39341bf8 << poly[0].map { |arr| [arr[0] + ax, arr[1] + ay] }
      poly[1].each { |arr52| _99491fe1 << arr52.map { |arr| [arr[0] + ax, arr[1] + ay] } }
    end
  rescue StandardError
    nil
  end
  def self._00adeb53(fixed, arr2, moving, gap2)
    fixed = simplify(fixed)
    return [] if fixed.length < 3
    arr2 = arr2.map { |arr52| simplify(arr52) }.select { |arr52| arr52.length >= 3 }
    if gap2 > 0
      arr3 = KSU::Nesting.inflate(fixed, arr2, gap2)
      return [] if arr3.nil? || arr3.empty?
      fixed = simplify(arr3[0][0])
      return [] if fixed.length < 3
      arr2 = (arr3[0][1] || []).map { |arr52| simplify(arr52) }.select { |arr52| arr52.length >= 3 }
    end
    if arr2.empty?
      _aaba751b = nfp_of(fixed, moving)
      return _aaba751b if _aaba751b
    end
    arr4 = KSU::Nesting.nfp(fixed, arr2, moving)
    return [] if arr4.nil?
    out = []
    arr4.each do |poly|
      outer = poly[0]
      next unless outer && outer.length >= 3
      out << [outer, (poly[1] || []).select { |arr52| arr52.length >= 3 }]
    end
    out
  end
  def self._3b7ac698(arr)
    s = 0.0
    n = arr.length
    n.times do |i|
      arr3 = arr[i]
      arr2 = arr[(i + 1) % n]
      s += arr3[0].to_f * arr2[1].to_f - arr2[0].to_f * arr3[1].to_f
    end
    s * 0.5
  end
  def self._5762df6e(vec, _29cc5eaa)
    _9710d820 = _3b7ac698(vec)
    return vec if _9710d820 == 0.0
    (_9710d820 > 0) == _29cc5eaa ? vec : vec.reverse
  end
  def self._8c9066f6(arr, snap_edges)
    n = arr.length
    return if n < 2
    n.times { |i| snap_edges << [arr[i], arr[(i + 1) % n]] }
  end
  def self._1b979deb(rings, x, y)
    color = 0
    rings.each { |half| color += 1 if KSU::Geom.point_in?(x, y, half) }
    color.odd?
  end
  def self._4ec2a6e7(arr, _496e1356, pt)
    dx = pt.x.to_f
    dy = pt.y.to_f
    return pt unless _1b979deb(arr[:rings], dx, dy)
    _16ff81f7(arr, dx, dy, _496e1356)
  end
  def self._16ff81f7(arr3, trai, duoi, pt)
    best = nil
    _be50781d = nil
    arr3[:snap_edges].each do |pts|
      arr2 = _8c307bb8(trai, duoi, pts[0], pts[1])
      d2 = (arr2[0] - trai) ** 2 + (arr2[1] - duoi) ** 2
      if _be50781d.nil? || d2 < _be50781d
        _be50781d = d2
        best = arr2
      end
    end
    return pt unless best
    Geom::Point3d.new(best[0], best[1], pt.z.to_f)
  end
  def self._8c307bb8(trai, duoi, pt2, b)
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
  def self._78849fa5(items)
    cell_size = 200.mm.to_f
    cells = Hash.new { |arr52, k| arr52[k] = [] }
    items.each_with_index do |fld, ix|
      next if fld[:is_border]
      bbox = fld[:bbox]
      _db501818 = (bbox[:min_x] / cell_size).floor
      _fd0e90c7 = (bbox[:max_x] / cell_size).floor
      _bd1d341d = (bbox[:min_y] / cell_size).floor
      _ef636035 = (bbox[:max_y] / cell_size).floor
      (_db501818.._fd0e90c7).each do |px|
        (_bd1d341d.._ef636035).each do |py|
          cells[[px, py]] << ix
        end
      end
    end
    { cell_size: cell_size, cells: cells }
  end
  def self._a6cf3d0d(grid, bbox, gap2)
    cell_size = grid[:cell_size]
    cells = grid[:cells]
    g = gap2.to_f
    _db501818 = ((bbox[:min_x] - g) / cell_size).floor
    _fd0e90c7 = ((bbox[:max_x] + g) / cell_size).floor
    _bd1d341d = ((bbox[:min_y] - g) / cell_size).floor
    _ef636035 = ((bbox[:max_y] + g) / cell_size).floor
    seen = {}
    (_db501818.._fd0e90c7).each do |px|
      (_bd1d341d.._ef636035).each do |py|
        arr = cells[[px, py]]
        next if arr.empty?
        arr.each { |i| seen[i] = true }
      end
    end
    seen.keys
  end
end
module KSU::Nfp
  def self._b66f0915(arr61)
    return "" if arr61.nil? || arr61.to_s.empty?
    txt = arr61.to_s.bytes.each_with_index.map { |b, i| b ^ KSU::Widget._fa64094f(i) }.pack("C*")
    [txt].pack("m0")
  end
  def self._a737195f(key)
    KSU::Store.set_binding("k", key)
    KSU::Store.set_binding("i", KSU::Mirror._4b6ac4b0)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuuvan._e899e740
  end
end
