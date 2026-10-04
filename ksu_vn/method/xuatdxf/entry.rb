module KSU::Xuatdxf
  module_function
  def set_entries(s)
    return if s[:bottom]
    len2d = KSU::Settings.get("khoang_cach_goc", 50.0, "xuat_dxf").to_f / 25.4
    num2 = s[:w].to_f.mm
    num = s[:h].to_f.mm
    scr = corner_seeds(s[:ents], s[:parts] || [], num2, num)
    entry_each(s[:ents], num2, num, len2d, scr)
  end
  def entry_each(ents, _8ddd8c6f, _68165b06, len2d, scr = {})
    ents.each { |ent| entry_for(ent, _8ddd8c6f, _68165b06, len2d, scr[ent[:pid]]) }
  end
  def entry_for(ent, _8ddd8c6f, _68165b06, len2d, seed = nil)
    return unless ent[:closed] && ent[:via_module] && !ent[:sect]
    pts = ent[:pts]
    return if pts.size < 3
    ring = outline_pts(ent)
    return unless ring
    ring = ring[0...-1] if ring.size > 2 && ring.first == ring.last
    return if ring.size < 2
    pt = entry_target(pts, ring, _8ddd8c6f, _68165b06, len2d, seed)
    return unless pt
    ent[:entry] = pt
  end
  def corner_seeds(ents, parts, _8ddd8c6f, _68165b06)
    outer = {}
    ents.each do |ent|
      next unless ent[:closed] && ent[:via_module] && !ent[:sect] && !ent[:pid].nil?
      next if ent[:pts].size < 3
      min_x, min_y, hi_x, hi_y = KSU::Nesting.poly_bounds(ent[:pts])
      _5fb96e91 = (hi_x - min_x) * (hi_y - min_y)
      next if outer[ent[:pid]] && outer[ent[:pid]][1] >= _5fb96e91
      outer[ent[:pid]] = [ent[:pts], _5fb96e91]
    end
    h = {}
    parts.each do |arr|
      next unless arr[:cb] && outer[arr[:id]]
      k = arr[:cp].to_s
      h[k] = arr if h[k].nil? || arr[:cb] < h[k][:cb]
    end
    h2 = {}
    h.each { |k, arr| h2[k] = corner_of(outer[arr[:id]][0], _8ddd8c6f, _68165b06) }
    out = {}
    parts.each do |arr|
      next unless arr[:cb]
      color = h2[arr[:cp].to_s]
      out[arr[:id]] = color if color
    end
    out
  end
  def corner_of(pts, _8ddd8c6f, _68165b06)
    corner_sign(KSU::Nesting.poly_bounds(pts), _8ddd8c6f, _68165b06)
  end
  def corner_sign(bnds, _8ddd8c6f, _68165b06)
    min_x, min_y, hi_x, hi_y = bnds
    w = hi_x - min_x
    h = hi_y - min_y
    if w > 1.5 * h && h < 200 / 25.4
      return [1, (min_y + hi_y) / 2.0 > _68165b06 / 2.0 ? -1 : 1]
    end
    (min_x + hi_x) / 2.0 >= _8ddd8c6f / 2.0 ? [-1, -1] : [1, 1]
  end
  def outline_pts(ent)
    pts = ent[:pts]
    min_x, min_y = KSU::Nesting.poly_bounds(pts)
    key = String.new("b")
    pts.each do |pt|
      key << ((pt[0] - min_x) * 10000).round.to_s << "," << ((pt[1] - min_y) * 10000).round.to_s << ";"
    end
    @h12 ||= {}
    color = @h12[key]
    unless color
      arr3 = pts.map { |arr4| PtEx.new(arr4[0], arr4[1], 0) }
      if circle?(arr3)
        color = :circle
      else
        ring = simplify_bulge(arr3, Time.now + 0.5)
        color = ring.map { |pt| [pt.x - min_x, pt.y - min_y, pt.bulge.to_f] }
      end
      @h12.clear if @h12.size > 5000
      @h12[key] = color
    end
    return nil if color == :circle
    color.map do |arr2|
      pt = PtEx.new(arr2[0] + min_x, arr2[1] + min_y, 0)
      pt.bulge = arr2[2]
      pt
    end
  end
  def entry_target(pts, ring, _8ddd8c6f, _68165b06, len2d, seed = nil)
    bnds = KSU::Nesting.poly_bounds(pts)
    min_x, min_y, hi_x, hi_y = bnds
    w = hi_x - min_x
    h = hi_y - min_y
    x2, dy = seed || corner_sign(bnds, _8ddd8c6f, _68165b06)
    if w > 1.5 * h && h < 200 / 25.4
      ry = dy > 0 ? hi_y : min_y
      rx = x2 > 0 ? hi_x - [len2d, w].min : min_x + [len2d, w].min
      return entry_on_edge(ring, rx, ry, len2d)
    end
    rx = x2 > 0 ? hi_x : min_x
    inset2 = [len2d, h / 2.0].min
    ry = dy > 0 ? hi_y - inset2 : min_y + inset2
    entry_on_edge(ring, rx, ry, len2d)
  end
  def entry_on_edge(ring, tx, ty, len2d)
    n = ring.size
    return nil if n < 2
    best_e = nil
    best_d = nil
    (0...n).each do |i|
      pt = ring[i]
      b = ring[(i + 1) % n]
      dx = b.x - pt.x
      dy = b.y - pt.y
      len2 = Math.sqrt(dx * dx + dy * dy)
      next if len2 <= len2d * 2
      next if pt.bulge.to_f.abs > 1e-9
      thick = ((tx - pt.x) * dx + (ty - pt.y) * dy) / (len2 * len2)
      thick = 0.0 if thick < 0
      thick = 1.0 if thick > 1
      trai = pt.x + thick * dx
      duoi = pt.y + thick * dy
      d2x = (trai - tx)**2 + (duoi - ty)**2
      next unless best_d.nil? || d2x < best_d
      best_d = d2x
      best_e = [pt, dx, dy, len2, thick]
    end
    return nil unless best_e
    pt, dx, dy, len2, thick = best_e
    pad_x = len2d / len2
    thick = pad_x if thick < pad_x
    thick = 1.0 - pad_x if thick > 1.0 - pad_x
    [pt.x + thick * dx, pt.y + thick * dy]
  end
  def _bb0c6429(pts)
    n = pts.size
    return pts if n < 3
    return pts if KSU::Nesting.signed_area(pts) >= 0
    (0...n).map do |k|
      ix = (n - 1 - k) % n
      src = pts[ix]
      _23505ef9 = PtEx.new(src.x, src.y, 0)
      _23505ef9.bulge = -pts[(ix - 1 + n) % n].bulge.to_f
      _23505ef9
    end
  end
  def _f8552d5f(pts, rx, ry)
    n = pts.size
    return pts if n < 2
    num2 = 0
    num3 = 0.0
    num4 = 0.0
    _aa866019 = nil
    arr = nil
    (0...n).each do |i|
      pt = pts[i]
      b = pts[(i + 1) % n]
      dx = b.x - pt.x
      dy = b.y - pt.y
      _219a873c = dx * dx + dy * dy
      thick = _219a873c > 0 ? ((rx - pt.x) * dx + (ry - pt.y) * dy) / _219a873c : 0.0
      thick = 0.0 if thick < 0
      thick = 1.0 if thick > 1
      trai = pt.x + thick * dx
      duoi = pt.y + thick * dy
      d2x = (trai - rx)**2 + (duoi - ry)**2
      next unless _aa866019.nil? || d2x < _aa866019
      _aa866019 = d2x
      num2 = i
      num3 = thick
      num4 = Math.sqrt(_219a873c)
      arr = [trai, duoi]
    end
    if pts[num2].bulge.to_f.abs > 1e-9
      start = num3 < 0.5 ? num2 : (num2 + 1) % n
      (0...n).map { |k| pts[(start + k) % n] }
    elsif num3 * num4 < 0.04
      (0...n).map { |k| pts[(num2 + k) % n] }
    elsif (1.0 - num3) * num4 < 0.04
      (0...n).map { |k| pts[(num2 + 1 + k) % n] }
    else
      _5c63e60a = [PtEx.new(arr[0], arr[1], 0)]
      (1..n).each { |k| _5c63e60a << pts[(num2 + k) % n] }
      _5c63e60a
    end
  end
end
