module KSU::Ttf
  module_function
  def import(path)
    data = File.binread(path)
    hmtx_off = table_offsets(data)
    head_off = hmtx_off["head"]
    upm = data[head_off + 18, 2].unpack1("n")
    hhea_off = hmtx_off["hhea"]
    num_hm = data[hhea_off + 34, 2].unpack1("n")
    ascent = read_short(data, hhea_off + 4)
    descent = read_short(data, hhea_off + 6)
    {
      data: data,
      upm: upm,
      num_hm: num_hm,
      hmtx_off: hmtx_off["hmtx"],
      cmap: cmap(data, hmtx_off["cmap"]),
      ascent: ascent,
      descent: descent,
      xmin: read_short(data, head_off + 36),
      ymin: read_short(data, head_off + 38),
      xmax: read_short(data, head_off + 40),
      ymax: read_short(data, head_off + 42)
    }
  end
  def table_offsets(data)
    num = data[4, 2].unpack1("n")
    hmtx_off = {}
    num.times do |i|
      normal = 12 + i * 16
      tag = data[normal, 4]
      _4bcb6213 = data[normal + 8, 4].unpack1("N")
      hmtx_off[tag] = _4bcb6213
    end
    hmtx_off
  end
  def cmap(data, _4bcb6213)
    num = data[_4bcb6213 + 2, 2].unpack1("n")
    flag = nil
    num.times do |i|
      normal = _4bcb6213 + 4 + i * 8
      pid = data[normal, 2].unpack1("n")
      _507dcc2d = data[normal + 2, 2].unpack1("n")
      kids = data[normal + 4, 4].unpack1("N")
      score = if pid == 3 && _507dcc2d == 10 then 5
                 elsif pid == 3 && _507dcc2d == 1 then 4
                 elsif pid == 0 then 3
                 else 0 end
      flag = [score, _4bcb6213 + kids] if score > 0 && (flag.nil? || score > flag[0])
    end
    return {} unless flag
    _a3257134(data, flag[1])
  end
  def _a3257134(data, _4bcb6213)
    fmt = data[_4bcb6213, 2].unpack1("n")
    return _31c28be0(data, _4bcb6213) if fmt == 4
    return _19412587(data, _4bcb6213) if fmt == 12
    {}
  end
  def _31c28be0(data, _4bcb6213)
    _cd2f261c = data[_4bcb6213 + 6, 2].unpack1("n")
    pts = _cd2f261c / 2
    _b44355cf = _4bcb6213 + 14
    _cd0dfa0c = _b44355cf + _cd2f261c + 2
    _1ef61ee4 = _cd0dfa0c + _cd2f261c
    _774060b6 = _1ef61ee4 + _cd2f261c
    h = {}
    pts.times do |i|
      _781628f9 = data[_b44355cf + i * 2, 2].unpack1("n")
      start = data[_cd0dfa0c + i * 2, 2].unpack1("n")
      delta = data[_1ef61ee4 + i * 2, 2].unpack1("n")
      _52d8d4a9 = data[_774060b6 + i * 2, 2].unpack1("n")
      next if start == 0xffff
      (start.._781628f9).each do |color|
        if _52d8d4a9 == 0
          g = (color + delta) & 0xffff
        else
          _b7a8e470 = _774060b6 + i * 2 + _52d8d4a9 + (color - start) * 2
          g = data[_b7a8e470, 2].unpack1("n")
          g = (g + delta) & 0xffff if g != 0
        end
        h[color] = g if g != 0
      end
    end
    h
  end
  def _19412587(data, _4bcb6213)
    num = data[_4bcb6213 + 12, 4].unpack1("N")
    h = {}
    num.times do |i|
      normal = _4bcb6213 + 16 + i * 12
      screen = data[normal, 4].unpack1("N")
      edge_color = data[normal + 4, 4].unpack1("N")
      _6048e0bb = data[normal + 8, 4].unpack1("N")
      (screen..edge_color).each { |color| h[color] = _6048e0bb + (color - screen) }
    end
    h
  end
  def gid(font_full, cls2)
    font_full[:cmap][cls2] || 0
  end
  def advance(font_full, gid)
    n = font_full[:num_hm]
    ix = gid < n ? gid : n - 1
    font_full[:data][font_full[:hmtx_off] + ix * 4, 2].unpack1("n")
  end
  def read_short(data, _4bcb6213)
    v = data[_4bcb6213, 2].unpack1("n")
    v >= 0x8000 ? v - 0x10000 : v
  end
end
