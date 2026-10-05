module KSU::Xuatdxf
  module_function
  def set_entries(s)
    return if s[:bottom]
    len2d = KSU::Settings.get("khoang_cach_goc", 50.0, "xuat_dxf").to_f / 25.4
    num = s[:w].to_f.mm
    num2 = s[:h].to_f.mm
    scr = corner_seeds(s[:ents], s[:parts] || [], num, num2)
    entry_each(s[:ents], num, num2, len2d, scr)
  end
  def entry_each(ents, _8ddd8c6f, _68165b06, len2d, scr = {})
    ents.each { |ent| entry_for(ent, _8ddd8c6f, _68165b06, len2d, scr[ent[:pid]]) }
  end
  def entry_for(ent, _8ddd8c6f, _68165b06, len2d, seed = nil)
    return unless ent[:closed] && ent[:via_module] && !ent[:sect]
    pts = ent[:pts]
    return if pts.size < 3
    _9535dc0b = outline_pts(ent)
    return unless _9535dc0b
    _9535dc0b = _9535dc0b[0...-1] if _9535dc0b.size > 2 && _9535dc0b.first == _9535dc0b.last
    return if _9535dc0b.size < 2
    _63629225 = entry_target(pts, _9535dc0b, _8ddd8c6f, _68165b06, len2d, seed)
    return unless _63629225
    ent[:entry] = _63629225
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
    @h21 ||= {}
    color = @h21[key]
    unless color
      arr2 = pts.map { |arr3| PtEx.new(arr3[0], arr3[1], 0) }
      if circle?(arr2)
        color = :circle
      else
        arr4 = simplify_bulge(arr2, Time.now + 0.5)
        color = arr4.map { |pt| [pt.x - min_x, pt.y - min_y, pt.bulge.to_f] }
      end
      @h21.clear if @h21.size > 5000
      @h21[key] = color
    end
    return nil if color == :circle
    color.map do |arr|
      pt = PtEx.new(arr[0] + min_x, arr[1] + min_y, 0)
      pt.bulge = arr[2]
      pt
    end
  end
  def entry_target(pts, _9535dc0b, _8ddd8c6f, _68165b06, len2d, seed = nil)
    bnds = KSU::Nesting.poly_bounds(pts)
    min_x, min_y, hi_x, hi_y = bnds
    w = hi_x - min_x
    h = hi_y - min_y
    _10270e02, dy = seed || corner_sign(bnds, _8ddd8c6f, _68165b06)
    if w > 1.5 * h && h < 200 / 25.4
      ry = dy > 0 ? hi_y : min_y
      rx = _10270e02 > 0 ? hi_x - [len2d, w].min : min_x + [len2d, w].min
      return entry_on_edge(_9535dc0b, rx, ry, len2d)
    end
    rx = _10270e02 > 0 ? hi_x : min_x
    _4bcb6213 = [len2d, h / 2.0].min
    ry = dy > 0 ? hi_y - _4bcb6213 : min_y + _4bcb6213
    entry_on_edge(_9535dc0b, rx, ry, len2d)
  end
  def entry_on_edge(arr, tx, ty, len2d)
    n = arr.size
    return nil if n < 2
    best_e = nil
    best_d = nil
    (0...n).each do |i|
      v = arr[i]
      b = arr[(i + 1) % n]
      dx = b.x - v.x
      dy = b.y - v.y
      _85458193 = Math.sqrt(dx * dx + dy * dy)
      next if _85458193 <= len2d * 2
      next if v.bulge.to_f.abs > 1e-9
      thick = ((tx - v.x) * dx + (ty - v.y) * dy) / (_85458193 * _85458193)
      thick = 0.0 if thick < 0
      thick = 1.0 if thick > 1
      trai = v.x + thick * dx
      duoi = v.y + thick * dy
      d2x = (trai - tx)**2 + (duoi - ty)**2
      next unless best_d.nil? || d2x < best_d
      best_d = d2x
      best_e = [v, dx, dy, _85458193, thick]
    end
    return nil unless best_e
    v, dx, dy, _85458193, thick = best_e
    pad_x = len2d / _85458193
    thick = pad_x if thick < pad_x
    thick = 1.0 - pad_x if thick > 1.0 - pad_x
    [v.x + thick * dx, v.y + thick * dy]
  end
  def ring_len(pts)
    n = pts.size
    return pts if n < 3
    return pts if KSU::Nesting.signed_area(pts) >= 0
    (0...n).map do |k|
      ix = (n - 1 - k) % n
      src = pts[ix]
      pt4 = PtEx.new(src.x, src.y, 0)
      pt4.bulge = -pts[(ix - 1 + n) % n].bulge.to_f
      pt4
    end
  end
  def split_at(pts, rx, ry)
    n = pts.size
    return pts if n < 2
    num = 0
    num2 = 0.0
    num3 = 0.0
    best_d2x = nil
    arr = nil
    (0...n).each do |i|
      v = pts[i]
      b = pts[(i + 1) % n]
      dx = b.x - v.x
      dy = b.y - v.y
      len2sq = dx * dx + dy * dy
      thick = len2sq > 0 ? ((rx - v.x) * dx + (ry - v.y) * dy) / len2sq : 0.0
      thick = 0.0 if thick < 0
      thick = 1.0 if thick > 1
      trai = v.x + thick * dx
      duoi = v.y + thick * dy
      d2x = (trai - rx)**2 + (duoi - ry)**2
      next unless best_d2x.nil? || d2x < best_d2x
      best_d2x = d2x
      num = i
      num2 = thick
      num3 = Math.sqrt(len2sq)
      arr = [trai, duoi]
    end
    if pts[num].bulge.to_f.abs > 1e-9
      start = num2 < 0.5 ? num : (num + 1) % n
      (0...n).map { |k| pts[(start + k) % n] }
    elsif num2 * num3 < 0.04
      (0...n).map { |k| pts[(num + k) % n] }
    elsif (1.0 - num2) * num3 < 0.04
      (0...n).map { |k| pts[(num + 1 + k) % n] }
    else
      _5c63e60a = [PtEx.new(arr[0], arr[1], 0)]
      (1..n).each { |k| _5c63e60a << pts[(num + k) % n] }
      _5c63e60a
    end
  end
end
