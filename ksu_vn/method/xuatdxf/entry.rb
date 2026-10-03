module KSU::Xuatdxf
  module_function
  def _f60dec30(s)
    return if s[:bottom]
    len2d = KSU::Settings.get("khoang_cach_goc", 50.0, "xuat_dxf").to_f / 25.4
    num2 = s[:w].to_f.mm
    num = s[:h].to_f.mm
    scr = _30057963(s[:ents], s[:parts] || [], num2, num)
    _8b1edfc4(s[:ents], num2, num, len2d, scr)
  end
  def _8b1edfc4(ents, _8ddd8c6f, _68165b06, len2d, scr = {})
    ents.each { |ent| _3161186f(ent, _8ddd8c6f, _68165b06, len2d, scr[ent[:pid]]) }
  end
  def _3161186f(ent, _8ddd8c6f, _68165b06, len2d, seed = nil)
    return unless ent[:closed] && ent[:via_module] && !ent[:sect]
    pts = ent[:pts]
    return if pts.size < 3
    _9535dc0b = _97443b71(ent)
    return unless _9535dc0b
    _9535dc0b = _9535dc0b[0...-1] if _9535dc0b.size > 2 && _9535dc0b.first == _9535dc0b.last
    return if _9535dc0b.size < 2
    pt = _de556708(pts, _9535dc0b, _8ddd8c6f, _68165b06, len2d, seed)
    return unless pt
    ent[:entry] = pt
  end
  def _30057963(ents, parts, _8ddd8c6f, _68165b06)
    outer = {}
    ents.each do |ent|
      next unless ent[:closed] && ent[:via_module] && !ent[:sect] && !ent[:pid].nil?
      next if ent[:pts].size < 3
      min_x, min_y, _a4beb817, _9deb3cee = KSU::Nesting.poly_bounds(ent[:pts])
      _5fb96e91 = (_a4beb817 - min_x) * (_9deb3cee - min_y)
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
    h.each { |k, arr| h2[k] = _984ee8f3(outer[arr[:id]][0], _8ddd8c6f, _68165b06) }
    out = {}
    parts.each do |arr|
      next unless arr[:cb]
      color = h2[arr[:cp].to_s]
      out[arr[:id]] = color if color
    end
    out
  end
  def _984ee8f3(pts, _8ddd8c6f, _68165b06)
    _bb40b229(KSU::Nesting.poly_bounds(pts), _8ddd8c6f, _68165b06)
  end
  def _bb40b229(bounds, _8ddd8c6f, _68165b06)
    min_x, min_y, _a4beb817, _9deb3cee = bounds
    num3 = _a4beb817 - min_x
    arr52 = _9deb3cee - min_y
    if num3 > 1.5 * arr52 && arr52 < 200 / 25.4
      return [1, (min_y + _9deb3cee) / 2.0 > _68165b06 / 2.0 ? -1 : 1]
    end
    (min_x + _a4beb817) / 2.0 >= _8ddd8c6f / 2.0 ? [-1, -1] : [1, 1]
  end
  def _97443b71(ent)
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
      if _a54bea0f(arr3)
        color = :circle
      else
        _9535dc0b = _074e3371(arr3, Time.now + 0.5)
        color = _9535dc0b.map { |pt| [pt.x - min_x, pt.y - min_y, pt.bulge.to_f] }
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
  def _de556708(pts, _9535dc0b, _8ddd8c6f, _68165b06, len2d, seed = nil)
    bounds = KSU::Nesting.poly_bounds(pts)
    min_x, min_y, _a4beb817, _9deb3cee = bounds
    num3 = _a4beb817 - min_x
    arr52 = _9deb3cee - min_y
    x2, dy = seed || _bb40b229(bounds, _8ddd8c6f, _68165b06)
    if num3 > 1.5 * arr52 && arr52 < 200 / 25.4
      ry = dy > 0 ? _9deb3cee : min_y
      rx = x2 > 0 ? _a4beb817 - [len2d, num3].min : min_x + [len2d, num3].min
      return _727b63c7(_9535dc0b, rx, ry, len2d)
    end
    rx = x2 > 0 ? _a4beb817 : min_x
    _4bcb6213 = [len2d, arr52 / 2.0].min
    ry = dy > 0 ? _9deb3cee - _4bcb6213 : min_y + _4bcb6213
    _727b63c7(_9535dc0b, rx, ry, len2d)
  end
  def _727b63c7(_9535dc0b, tx, _51d53976, len2d)
    n = _9535dc0b.size
    return nil if n < 2
    _080e1e07 = nil
    _892e5ea9 = nil
    (0...n).each do |i|
      pt = _9535dc0b[i]
      b = _9535dc0b[(i + 1) % n]
      dx = b.x - pt.x
      dy = b.y - pt.y
      len = Math.sqrt(dx * dx + dy * dy)
      next if len <= len2d * 2
      next if pt.bulge.to_f.abs > 1e-9
      thick = ((tx - pt.x) * dx + (_51d53976 - pt.y) * dy) / (len * len)
      thick = 0.0 if thick < 0
      thick = 1.0 if thick > 1
      trai = pt.x + thick * dx
      duoi = pt.y + thick * dy
      _fa09db7b = (trai - tx)**2 + (duoi - _51d53976)**2
      next unless _892e5ea9.nil? || _fa09db7b < _892e5ea9
      _892e5ea9 = _fa09db7b
      _080e1e07 = [pt, dx, dy, len, thick]
    end
    return nil unless _080e1e07
    pt, dx, dy, len, thick = _080e1e07
    pad_x = len2d / len
    thick = pad_x if thick < pad_x
    thick = 1.0 - pad_x if thick > 1.0 - pad_x
    [pt.x + thick * dx, pt.y + thick * dy]
  end
  def _bb0c6429(pts)
    n = pts.size
    return pts if n < 3
    return pts if KSU::Nesting._5d9dd503(pts) >= 0
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
      _fa09db7b = (trai - rx)**2 + (duoi - ry)**2
      next unless _aa866019.nil? || _fa09db7b < _aa866019
      _aa866019 = _fa09db7b
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
