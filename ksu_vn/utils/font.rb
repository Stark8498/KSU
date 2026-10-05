module KSU::Font
  HEIGHT = 1.0
  UNIT = HEIGHT / 20.0
  TAN225 = 0.41421356237
  DIRS = [
    [1.0, 0.0], [1.0, TAN225], [1.0, 1.0], [TAN225, 1.0],
    [0.0, 1.0], [-TAN225, 1.0], [-1.0, 1.0], [-1.0, TAN225],
    [-1.0, 0.0], [-1.0, -TAN225], [-1.0, -1.0], [-TAN225, -1.0],
    [0.0, -1.0], [TAN225, -1.0], [1.0, -1.0], [1.0, -TAN225],
  ].freeze
  module_function
  def shx_path
    File.expand_path("../clibs/ksu.shx", __dir__)
  end
  def import
    return ready? if defined?(@flag33) && @flag33
    @id_str = {}
    @snap_edges = {}
    @h12 = {}
    @h28 = {}
    @fail = false
    begin
      data = defined?(FONT_B64) ? FONT_B64.unpack1("m0") : File.binread(shx_path)
      table_off = "AutoCAD-86 unifont 1.0\r\n\u001a".bytesize
      want = data[table_off, 2].unpack1("S<")
      table_off += 2
      ver, hdr_len = data[table_off, 4].unpack("S<S<")
      table_off += 4 + hdr_len
      (want - 1).times do
        break if table_off + 4 > data.bytesize
        sheet_h, glyph_len = data[table_off, 4].unpack("S<S<")
        table_off += 4
        @id_str[sheet_h] = data[table_off, glyph_len].bytes
        table_off += glyph_len
      end
      @flag33 = true
    rescue StandardError
      @fail = true
      @flag33 = true
    end
    ready?
  end
  def ready?
    !!(defined?(@flag33) && @flag33 && !@fail && @id_str && !@id_str.empty?)
  end
  def sbyte(b)
    return 0 if b.nil?
    b >= 128 ? b - 256 : b
  end
  def ubyte(b)
    b.nil? ? 0 : b
  end
  def skip_op(arr, i)
    b = arr[i]
    i += 1
    case b
    when nil, 0x00, 0x01, 0x02, 0x05, 0x06, 0x0E then i
    when 0x03, 0x04 then i + 1
    when 0x07, 0x08, 0x0A then i + 2
    when 0x09
      loop do
        break if arr[i].nil? || arr[i + 1].nil?
        dx = arr[i]
        dy = arr[i + 1]
        i += 2
        break if dx == 0 && dy == 0
      end
      i
    when 0x0B then i + 5
    when 0x0C then i + 3
    when 0x0D
      loop do
        break if arr[i].nil? || arr[i + 1].nil?
        break if arr[i] == 0 && arr[i + 1] == 0
        i += 3
      end
      i + 2
    else
      i
    end
  end
  def decode_glyph(arr)
    snap_edges = []
    x = 0.0
    y = 0.0
    pen = false
    upm = 1.0
    arr3 = []
    i = 0
    n = arr.length
    while i < n
      b = arr[i]
      i += 1
      case b
      when 0x00
        next
      when 0x0E
        i = skip_op(arr, i)
        next
      when 0x01
        pen = true
      when 0x02
        pen = false
      when 0x03
        s = ubyte(arr[i]).to_f
        i += 1
        upm /= s unless s == 0.0
      when 0x04
        s = ubyte(arr[i]).to_f
        i += 1
        upm *= s unless s == 0.0
      when 0x05
        arr3.push([x, y])
      when 0x06
        x, y = arr3.pop || [x, y]
      when 0x07
        i += 2
      when 0x08
        nx = x + sbyte(arr[i]) * upm
        ny = y + sbyte(arr[i + 1]) * upm
        i += 2
        snap_edges << [x, y, nx, ny] if pen
        x = nx
        y = ny
      when 0x09
        loop do
          break if arr[i].nil? || arr[i + 1].nil?
          dx = sbyte(arr[i])
          dy = sbyte(arr[i + 1])
          i += 2
          break if dx == 0 && dy == 0
          nx = x + dx * upm
          ny = y + dy * upm
          snap_edges << [x, y, nx, ny] if pen
          x = nx
          y = ny
        end
      when 0x0A
        x, y = arc_octant(snap_edges, x, y, ubyte(arr[i]), ubyte(arr[i + 1]), upm, pen)
        i += 2
      when 0x0B
        i += 5
      when 0x0C
        x, y = bulge(snap_edges, x, y, sbyte(arr[i]), sbyte(arr[i + 1]), sbyte(arr[i + 2]), upm, pen)
        i += 3
      when 0x0D
        loop do
          break if arr[i].nil? || arr[i + 1].nil?
          dx = sbyte(arr[i])
          dy = sbyte(arr[i + 1])
          i += 2
          break if dx == 0 && dy == 0
          hdr_box = sbyte(arr[i])
          i += 1
          x, y = bulge(snap_edges, x, y, dx, dy, hdr_box, upm, pen)
        end
      else
        arr2 = DIRS[b & 0x0F]
        len = (b >> 4) & 0x0F
        nx = x + len * arr2[0] * upm
        ny = y + len * arr2[1] * upm
        snap_edges << [x, y, nx, ny] if pen
        x = nx
        y = ny
      end
    end
    [snap_edges, x]
  end
  def arc_octant(snap_edges, x, y, r, job, upm, pen)
    half = r * upm
    return [x, y] if half <= 0
    ccw = (job & 0x80) != 0
    start = (job >> 4) & 0x07
    num = job & 0x0F
    num = 8 if num == 0
    a0 = start * (Math::PI / 4.0)
    px = x - half * Math.cos(a0)
    py = y - half * Math.sin(a0)
    total = num * (Math::PI / 4.0)
    total = -total if ccw
    steps = num * 3
    trai = x
    duoi = y
    (1..steps).each do |num3|
      num2 = a0 + total * (num3.to_f / steps)
      nx = px + half * Math.cos(num2)
      ny = py + half * Math.sin(num2)
      snap_edges << [trai, duoi, nx, ny] if pen
      trai = nx
      duoi = ny
    end
    [trai, duoi]
  end
  def bulge(snap_edges, x, y, dx, dy, bulge, upm, pen)
    rx = x + dx * upm
    ry = y + dy * upm
    if bulge == 0
      snap_edges << [x, y, rx, ry] if pen
      return [rx, ry]
    end
    chord = Math.hypot(rx - x, ry - y)
    return [rx, ry] if chord < 1e-9
    elem = (bulge.to_f / 127.0) * (chord / 2.0)
    nx = -(ry - y) / chord
    ny = (rx - x) / chord
    steps = 8
    trai = x
    duoi = y
    (1..steps).each do |num|
      t = num.to_f / steps
      bx2 = x + (rx - x) * t
      by2 = y + (ry - y) * t
      bulge_h = elem * (1.0 - (2.0 * t - 1.0) ** 2)
      bx3 = bx2 + nx * bulge_h
      by3 = by2 + ny * bulge_h
      snap_edges << [trai, duoi, bx3, by3] if pen
      trai = bx3
      duoi = by3
    end
    [rx, ry]
  end
  def strokes_for(err_code)
    return @snap_edges[err_code] if @snap_edges.key?(err_code)
    obj = @id_str[err_code]
    if obj.nil?
      @snap_edges[err_code] = nil
      @h12[err_code] = 0.0
      @h28[err_code] = [0.0, 0.0]
      return nil
    end
    segs, adv = decode_glyph(obj)
    arr2 = segs.map { |arr| [arr[0] * UNIT, arr[1] * UNIT, arr[2] * UNIT, arr[3] * UNIT] }
    @snap_edges[err_code] = arr2
    @h12[err_code] = adv * UNIT
    if arr2.empty?
      @h28[err_code] = [0.0, 0.0]
    else
      arr3 = arr2.flat_map { |arr| [arr[0], arr[2]] }
      @h28[err_code] = [arr3.min, arr3.max]
    end
    arr2
  end
  def width_of(err_code)
    strokes_for(err_code) unless @h12.key?(err_code)
    @h12[err_code] || 0.0
  end
  def bounds_of(err_code)
    strokes_for(err_code) unless @h28.key?(err_code)
    @h28[err_code] || [0.0, 0.0]
  end
  def text_extent(text)
    import
    lo = nil
    hi = nil
    text.to_s.unicode_normalize.each_char do |c|
      _c8378bbe = c.ord
      next if _c8378bbe == 32 || _c8378bbe == 9
      arr = strokes_for(_c8378bbe) || strokes_for(0)
      next unless arr
      arr.each do |arr2|
        [arr2[1], arr2[3]].each do |y|
          lo = y if lo.nil? || y < lo
          hi = y if hi.nil? || y > hi
        end
      end
    end
    return [0.0, HEIGHT] if lo.nil?
    [lo, hi]
  end
  def half_width(text, flag2 = false, gap3 = nil)
    import
    return 0.0 unless ready?
    stream = text.to_s.unicode_normalize
    gap2 = gap3 || 0.10
    w = 0.0
    stream.each_char do |c|
      _c8378bbe = c.ord
      if _c8378bbe == 32 || _c8378bbe == 9
        w += 0.35
        next
      end
      if flag2
        entity = bounds_of(_c8378bbe)
        w += (entity[1] - entity[0]) + gap2
      else
        flag = width_of(_c8378bbe)
        flag = width_of(0) if @snap_edges[_c8378bbe].nil?
        w += flag + gap2
      end
    end
    w > gap2 ? w - gap2 : 0.0
  end
  def text_strokes(text, box, upm, flag = false, gap3 = nil, xf = 1.0)
    import
    return [] unless ready?
    segs = []
    stream = text.to_s.unicode_normalize
    x = 0.0
    pad_x = (gap3 || 0.10) * upm
    space_w = 0.35 * upm
    stream.each_char do |c|
      _c8378bbe = c.ord
      if _c8378bbe == 32 || _c8378bbe == 9
        x += space_w
        next
      end
      snap_edges = strokes_for(_c8378bbe)
      snap_edges = strokes_for(0) if snap_edges.nil?
      entity = bounds_of(_c8378bbe)
      if flag
        table_off = -entity[0]
        _be4b922d = entity[1] - entity[0]
      else
        _be4b922d = width_of(_c8378bbe)
        table_off = (_be4b922d - entity[0] - entity[1]) / 2.0
      end
      if snap_edges
        snap_edges.each do |arr|
          segs << [
            [box[0] + ((arr[0] + table_off) * upm + x) * xf, box[1] + arr[1] * upm],
            [box[0] + ((arr[2] + table_off) * upm + x) * xf, box[1] + arr[3] * upm]
          ]
        end
      end
      x += _be4b922d * upm + pad_x
    end
    segs
  end
  def draw_text_edges(ents, text, box, upm, flag = false, gap3 = nil, xf = 1.0)
    text_strokes(text, box, upm, flag, gap3, xf).each do |s|
      ents.add_edges([s[0][0], s[0][1], 0], [s[1][0], s[1][1], 0])
    end
    nil
  end
end
KSU::Font.instance_variable_set(:@flag33, nil)
