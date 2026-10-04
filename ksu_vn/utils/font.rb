module KSU::Font
  HEIGHT = 1.0
  CHAR_PADDING = 0.10
  TIGHT_GAP = 0.10
  SPACE = 0.35
  SHX_HEIGHT = 20.0
  UNIT = HEIGHT / SHX_HEIGHT
  SENTINEL = "AutoCAD-86 unifont 1.0\r\n\u001a".freeze
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
    return ready? if defined?(@flag16) && @flag16
    @id_str = {}
    @snap_edges = {}
    @h20 = {}
    @h17 = {}
    @flag59 = false
    begin
      data = defined?(FONT_B64) ? FONT_B64.unpack1("m0") : File.binread(shx_path)
      _4bcb6213 = SENTINEL.bytesize
      want = data[_4bcb6213, 2].unpack1("S<")
      _4bcb6213 += 2
      _aebde291, _8e587281 = data[_4bcb6213, 4].unpack("S<S<")
      _4bcb6213 += 4 + _8e587281
      (want - 1).times do
        break if _4bcb6213 + 4 > data.bytesize
        sheet_h, _ee63bedc = data[_4bcb6213, 4].unpack("S<S<")
        _4bcb6213 += 4
        @id_str[sheet_h] = data[_4bcb6213, _ee63bedc].bytes
        _4bcb6213 += _ee63bedc
      end
      @flag16 = true
    rescue StandardError
      @flag59 = true
      @flag16 = true
    end
    ready?
  end
  def ready?
    !!(defined?(@flag16) && @flag16 && !@flag59 && @id_str && !@id_str.empty?)
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
    when 0x07 then i + 2
    when 0x08 then i + 2
    when 0x09
      loop do
        break if arr[i].nil? || arr[i + 1].nil?
        dx = arr[i]
        dy = arr[i + 1]
        i += 2
        break if dx == 0 && dy == 0
      end
      i
    when 0x0A then i + 2
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
    _2f3325c7 = num * 3
    trai = x
    duoi = y
    (1.._2f3325c7).each do |k|
      num2 = a0 + total * (k.to_f / _2f3325c7)
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
    h = (bulge.to_f / 127.0) * (chord / 2.0)
    nx = -(ry - y) / chord
    ny = (rx - x) / chord
    num2 = 8
    trai = x
    duoi = y
    (1..num2).each do |k|
      thick = k.to_f / num2
      bx2 = x + (rx - x) * thick
      by2 = y + (ry - y) * thick
      _80ce9d04 = h * (1.0 - (2.0 * thick - 1.0) ** 2)
      _4208cdd3 = bx2 + nx * _80ce9d04
      _b570767e = by2 + ny * _80ce9d04
      snap_edges << [trai, duoi, _4208cdd3, _b570767e] if pen
      trai = _4208cdd3
      duoi = _b570767e
    end
    [rx, ry]
  end
  def strokes_for(err_code)
    return @snap_edges[err_code] if @snap_edges.key?(err_code)
    obj = @id_str[err_code]
    if obj.nil?
      @snap_edges[err_code] = nil
      @h20[err_code] = 0.0
      @h17[err_code] = [0.0, 0.0]
      return nil
    end
    arr4, adv = decode_glyph(obj)
    arr2 = arr4.map { |ent| [ent[0] * UNIT, ent[1] * UNIT, ent[2] * UNIT, ent[3] * UNIT] }
    @snap_edges[err_code] = arr2
    @h20[err_code] = adv * UNIT
    if arr2.empty?
      @h17[err_code] = [0.0, 0.0]
    else
      arr3 = arr2.flat_map { |ent| [ent[0], ent[2]] }
      @h17[err_code] = [arr3.min, arr3.max]
    end
    arr2
  end
  def width_of(err_code)
    strokes_for(err_code) unless @h20.key?(err_code)
    @h20[err_code] || 0.0
  end
  def bounds_of(err_code)
    strokes_for(err_code) unless @h17.key?(err_code)
    @h17[err_code] || [0.0, 0.0]
  end
  def _df558da5
    return @_004b3534 if defined?(@_004b3534) && @_004b3534
    ent = strokes_for(48)
    if ent && !ent.empty?
      arr2 = ent.flat_map { |g| [g[1], g[3]] }
      @_004b3534 = [arr2.min, arr2.max]
    else
      @_004b3534 = [0.0, HEIGHT]
    end
    @_004b3534
  end
  def text_extent(text)
    import
    lo = nil
    hi = nil
    text.to_s.unicode_normalize.each_char do |color|
      code = color.ord
      next if code == 32 || code == 9
      ent = strokes_for(code) || strokes_for(0)
      next unless ent
      ent.each do |g|
        [g[1], g[3]].each do |y|
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
    gap2 = gap3 || (flag2 ? TIGHT_GAP : CHAR_PADDING)
    w = 0.0
    stream.each_char do |color|
      code = color.ord
      if code == 32 || code == 9
        w += SPACE
        next
      end
      if flag2
        entity = bounds_of(code)
        w += (entity[1] - entity[0]) + gap2
      else
        flag = width_of(code)
        flag = width_of(0) if @snap_edges[code].nil?
        w += flag + gap2
      end
    end
    w > gap2 ? w - gap2 : 0.0
  end
  def text_strokes(text, box, upm, flag = false, gap3 = nil, xf = 1.0)
    import
    return [] unless ready?
    arr2 = []
    stream = text.to_s.unicode_normalize
    x = 0.0
    pad_x = (gap3 || (flag ? TIGHT_GAP : CHAR_PADDING)) * upm
    _738ce77b = SPACE * upm
    stream.each_char do |color|
      code = color.ord
      if code == 32 || code == 9
        x += _738ce77b
        next
      end
      snap_edges = strokes_for(code)
      snap_edges = strokes_for(0) if snap_edges.nil?
      entity = bounds_of(code)
      if flag
        _4bcb6213 = -entity[0]
        _68cbfb72 = entity[1] - entity[0]
      else
        _68cbfb72 = width_of(code)
        _4bcb6213 = (_68cbfb72 - entity[0] - entity[1]) / 2.0
      end
      if snap_edges
        snap_edges.each do |ent|
          arr2 << [
            [box[0] + ((ent[0] + _4bcb6213) * upm + x) * xf, box[1] + ent[1] * upm],
            [box[0] + ((ent[2] + _4bcb6213) * upm + x) * xf, box[1] + ent[3] * upm]
          ]
        end
      end
      x += _68cbfb72 * upm + pad_x
    end
    arr2
  end
  def draw_text_edges(ents, text, box, upm, flag = false, gap3 = nil, xf = 1.0)
    text_strokes(text, box, upm, flag, gap3, xf).each do |s|
      ents.add_edges([s[0][0], s[0][1], 0], [s[1][0], s[1][1], 0])
    end
    nil
  end
end
KSU::Font.instance_variable_set(:@flag16, nil)
