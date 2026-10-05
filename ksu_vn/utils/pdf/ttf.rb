module KSU::Ttf
  module_function
  def import(path)
    data = File.binread(path)
    arr = data[4, 2].unpack1("n").times.to_h { |i| [data[12 + i * 16, 4], data[20 + i * 16, 4].unpack1("N")] }
    head_off, _c6e9e223 = arr.values_at("head", "hhea")
    { data: data, upm: data[head_off + 18, 2].unpack1("n"), num_hm: data[_c6e9e223 + 34, 2].unpack1("n"),
      hmtx_off: arr["hmtx"], cmap: cmap(data, arr["cmap"]) }
      .merge({ ascent: _c6e9e223 + 4, descent: _c6e9e223 + 6, xmin: head_off + 36, ymin: head_off + 38, xmax: head_off + 40, ymax: head_off + 42 }
      .transform_values { |_c8378bbe| data[_c8378bbe, 2].unpack1("n").then { |v| v >= 0x8000 ? v - 0x10000 : v } })
  end
  def cmap(data, table_off)
    best = data[table_off + 2, 2].unpack1("n").times.inject(nil) do |b, i|
      normal = table_off + 4 + i * 8
      pid, arr = [0, 2].map { |len2d| data[normal + len2d, 2].unpack1("n") }
      kids = data[normal + 4, 4].unpack1("N")
      score = pid == 3 && arr == 10 ? 5 : pid == 3 && arr == 1 ? 4 : pid == 0 ? 3 : 0
      score > 0 && (b.nil? || score > b[0]) ? [score, table_off + kids] : b
    end
    fmt = best && data[best[1], 2].unpack1("n")
    fmt == 4 ? cmap_fmt4(data, best[1]) : fmt == 12 ? read_cmap_format12(data, best[1]) : {}
  end
  def cmap_fmt4(data, table_off)
    seg_x2 = data[table_off + 6, 2].unpack1("n")
    pts = seg_x2 / 2
    arr2 = [table_off + 14, table_off + 16 + seg_x2, table_off + 16 + seg_x2 * 2, table_off + 16 + seg_x2 * 3]
    pts.times.each_with_object({}) do |i, arr3|
      end_code, start, delta, arr = arr2.map { |_c8378bbe| data[_c8378bbe + i * 2, 2].unpack1("n") }
      next if start == 0xffff
      (start..end_code).each do |c|
        flag = arr == 0 ? c : data[arr2[3] + i * 2 + arr + (c - start) * 2, 2].unpack1("n")
        flag = (flag + delta) & 0xffff unless arr != 0 && flag == 0
        arr3[c] = flag if flag != 0
      end
    end
  end
  def read_cmap_format12(data, table_off)
    data[table_off + 12, 4].unpack1("N").times.each_with_object({}) do |i, arr|
      screen, edge, seg = [0, 4, 8].map { |len2d| data[table_off + 16 + i * 12 + len2d, 4].unpack1("N") }
      (screen..edge).each { |c| arr[c] = seg + (c - screen) }
    end
  end
  def glyph_width(font_full, _20cd1718)
    n = font_full[:num_hm]
    font_full[:data][font_full[:hmtx_off] + (_20cd1718 < n ? _20cd1718 : n - 1) * 4, 2].unpack1("n")
  end
end
