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
    best = nil
    num.times do |i|
      normal = _4bcb6213 + 4 + i * 8
      pid = data[normal, 2].unpack1("n")
      eid = data[normal + 2, 2].unpack1("n")
      kids = data[normal + 4, 4].unpack1("N")
      score = if pid == 3 && eid == 10 then 5
                 elsif pid == 3 && eid == 1 then 4
                 elsif pid == 0 then 3
                 else 0 end
      best = [score, _4bcb6213 + kids] if score > 0 && (best.nil? || score > best[0])
    end
    return {} unless best
    cmap_table(data, best[1])
  end
  def cmap_table(data, _4bcb6213)
    fmt = data[_4bcb6213, 2].unpack1("n")
    return cmap_fmt4(data, _4bcb6213) if fmt == 4
    return cmap_fmt12(data, _4bcb6213) if fmt == 12
    {}
  end
  def cmap_fmt4(data, _4bcb6213)
    seg_x2 = data[_4bcb6213 + 6, 2].unpack1("n")
    n_pts = seg_x2 / 2
    end_off = _4bcb6213 + 14
    start_off = end_off + seg_x2 + 2
    delta_off = start_off + seg_x2
    range_off = delta_off + seg_x2
    h = {}
    n_pts.times do |i|
      end_code = data[end_off + i * 2, 2].unpack1("n")
      start = data[start_off + i * 2, 2].unpack1("n")
      delta = data[delta_off + i * 2, 2].unpack1("n")
      range_ix = data[range_off + i * 2, 2].unpack1("n")
      next if start == 0xffff
      (start..end_code).each do |color|
        if range_ix == 0
          g = (color + delta) & 0xffff
        else
          gid_off = range_off + i * 2 + range_ix + (color - start) * 2
          g = data[gid_off, 2].unpack1("n")
          g = (g + delta) & 0xffff if g != 0
        end
        h[color] = g if g != 0
      end
    end
    h
  end
  def cmap_fmt12(data, _4bcb6213)
    num = data[_4bcb6213 + 12, 4].unpack1("N")
    h = {}
    num.times do |i|
      normal = _4bcb6213 + 16 + i * 12
      screen = data[normal, 4].unpack1("N")
      end_char = data[normal + 4, 4].unpack1("N")
      start_gid = data[normal + 8, 4].unpack1("N")
      (screen..end_char).each { |color| h[color] = start_gid + (color - screen) }
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
