module KSU::Nesting
  module_function
  def poly_bounds(poly)
    arr2 = poly.map { |arr| arr[0] }
    arr3 = poly.map { |arr| arr[1] }
    [arr2.min, arr3.min, arr2.max, arr3.max]
  end
  def poly_area(poly)
    n = poly.length
    num = 0.0
    n.times do |i|
      j = (i + 1) % n
      num += poly[i][0] * poly[j][1] - poly[j][0] * poly[i][1]
    end
    num.abs * 0.5
  end
  def point_in_poly?(pt, poly)
    x, y = pt
    flag = false
    n = poly.length
    j = n - 1
    n.times do |i|
      xi, yi = poly[i]
      xj, yj = poly[j]
      if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        flag = !flag
      end
      j = i
    end
    flag
  end
  def pack(items, width_mm, height_mm, gap2)
    if defined?(KSU::Method) && KSU::Method.respond_to?(:pack_bl)
      id_str = KSU::Method.pack_bl(items.map { |len2d| len2d[:w] }, items.map { |len2d| len2d[:h] },
                                   width_mm, height_mm, gap2, false, 1000, 0)
      unless id_str.empty?
        return [] unless id_str.all? { |ent| ent[0] == 0 }
        return id_str.each_with_index.map do |(_bin, x, y, num3, arr52), i|
                 items[i].merge(lx: x, ly: y, w: num3, h: arr52)
               end
      end
    end
    pack_fallback(items, width_mm, height_mm, gap2)
  end
  def pack_fallback(items, width_mm, height_mm, gap2)
    best = []
    arr2 = [-1, 0.0]
    arr3 = [
      items.sort_by { |len2d| -len2d[:h] },
      items.sort_by { |len2d| -len2d[:w] },
      items.sort_by { |len2d| -(len2d[:w] * len2d[:h]) },
      items.sort_by { |len2d| -[len2d[:w], len2d[:h]].max },
      items.sort_by { |len2d| -[len2d[:w], len2d[:h]].min },
      items.sort_by { |len2d| -(len2d[:w] + len2d[:h]) },
    ]
    random = Random.new(42)
    100.times { arr3 << items.shuffle(random: random) }
    arr3.each do |ordered|
      arr = pack_sequence(ordered, width_mm, height_mm, gap2)
      next if arr.empty?
      arr5 = arr.map { |members| members[:ly] + members[:h] }.max
      score = [arr.size, -arr5]
      next unless score[0] > arr2[0] || (score[0] == arr2[0] && score[1] > arr2[1])
      arr2 = score
      best = arr
    end
    best
  end
  def pack_sequence(ordered, width_mm, height_mm, gap2)
    arr = []
    ordered.each do |len2d|
      next if len2d[:w] > width_mm + KSU::Const::EPS || len2d[:h] > height_mm + KSU::Const::EPS
      box = find_spot(arr, len2d[:w], len2d[:h], width_mm, height_mm, gap2)
      next unless box
      arr << len2d.merge(lx: box[0], ly: box[1], w: len2d[:w], h: len2d[:h])
    end
    arr
  end
  def find_spot(arr4, pw, ph, width_mm, height_mm, gap2)
    arr3 = [0.0]
    arr2 = [0.0]
    arr4.each do |arr|
      arr3 << arr[:lx] + arr[:w] + gap2
      arr2 << arr[:ly] + arr[:h] + gap2
    end
    arr3 = arr3.uniq.sort
    arr2 = arr2.uniq.sort
    arr2.each do |y|
      next if y + ph > height_mm + KSU::Const::EPS
      arr3.each do |x|
        next if x + pw > width_mm + KSU::Const::EPS
        x2 = x + pw
        y2 = y + ph
        flag = arr4.any? do |arr|
          w = arr[:lx] + arr[:w]
          h = arr[:ly] + arr[:h]
          !(x2 + gap2 <= arr[:lx] + KSU::Const::EPS || w + gap2 <= x + KSU::Const::EPS ||
            y2 + gap2 <= arr[:ly] + KSU::Const::EPS || h + gap2 <= y + KSU::Const::EPS)
        end
        return [x, y] unless flag
      end
    end
    nil
  end
end
module KSU::Nesting
  def self._f92a626b
    require "win32/registry"
    Win32::Registry::HKEY_LOCAL_MACHINE.open("SYSTEM\\HardwareConfig") do |_0017d9ec|
      _abfef0a3, data = Win32::Registry::API.QueryValue(_0017d9ec.hkey, "LastConfig")
      return "" if data.nil?
      return data.dup.force_encoding("UTF-16LE").encode("UTF-8")[/[^{}]+/].to_s
    end
  rescue StandardError
    ""
  end
end
