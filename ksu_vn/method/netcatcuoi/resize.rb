module KSU::Resize
  private
  def _e4147f27
    @h3 = {}
    @sheets.each do |rec|
      arr2 = _ae3af84a(rec)
      @h3[rec[:instance]] = arr2 unless arr2.empty?
    end
  end
  def _8810a0b1(rec)
    bbox = rec[:bbox]
    flag26, flag7, top, arr40 = KSU::Avail.sides_for(rec[:instance], @tam_cach_le.to_f)
    [bbox.min.x.to_f + flag26, bbox.min.y.to_f + arr40, bbox.max.x.to_f - flag7, bbox.max.y.to_f - top]
  end
  def _ae3af84a(rec)
    sheet = rec[:instance]
    panels = _cca954c3(sheet, rec[:transform], true)
    return [] if panels.empty?
    gap2 = @tam_cach_nhau.to_f
    num = @chieu_rong_toi_thieu.to_f
    _7b2f9929, _328de04c, _38e0f0c5, _24c1c612 = _8810a0b1(rec)
    return [] if _38e0f0c5 - _7b2f9929 < num || _24c1c612 - _328de04c < num
    arr2 = panels.map do |pt|
      { x1: pt.min.x.to_f - gap2, x2: pt.max.x.to_f + gap2,
        y1: pt.min.y.to_f - gap2, y2: pt.max.y.to_f + gap2 }
    end
    @arr10.each do |half|
      next unless half[:sheet] == sheet && half[:points] && half[:points].length == 4
      arr5 = half[:points].map { |pt| pt.x.to_f }
      arr4 = half[:points].map { |pt| pt.y.to_f }
      arr2 << { x1: arr5.min, x2: arr5.max, y1: arr4.min, y2: arr4.max }
    end
    arr3 = []
    while arr3.length < 50
      half = _ff3778ab(_7b2f9929, _328de04c, _38e0f0c5, _24c1c612, arr2, num)
      break unless half
      arr3 << points(half)
      arr2 << half
    end
    arr3
  end
  def _ff3778ab(_7b2f9929, _328de04c, _38e0f0c5, _24c1c612, arr3, _a0976be2)
    tol = 1e-6
    arr2 = KSU::Geom._a404e7b6([_7b2f9929, _38e0f0c5] + arr3.flat_map { |b| [b[:x1], b[:x2]] }.select { |v| v > _7b2f9929 + tol && v < _38e0f0c5 - tol })
    best = nil
    area = 0.0
    (0...arr2.length - 1).each do |i|
      ((i + 1)...arr2.length).each do |j|
        x213 = arr2[i]
        x2 = arr2[j]
        num3 = x2 - x213
        next if num3 < _a0976be2
        arr4 = []
        arr3.each do |b|
          next unless b[:x1] < x2 - tol && b[:x2] > x213 + tol
          _e8649a72 = [b[:y1], _328de04c].max
          _e25dbacd = [b[:y2], _24c1c612].min
          arr4 << [_e8649a72, _e25dbacd] if _e25dbacd > _e8649a72 + tol
        end
        gap2 = _786ab544(_328de04c, _24c1c612, arr4)
        next if gap2[:len] < _a0976be2
        _5fb96e91 = num3 * gap2[:len]
        if _5fb96e91 > area + tol
          area = _5fb96e91
          best = { x1: x213, y1: gap2[:y1], x2: x2, y2: gap2[:y2] }
        end
      end
    end
    best
  end
  def _786ab544(_e8649a72, _e25dbacd, arr2)
    return { len: _e25dbacd - _e8649a72, y1: _e8649a72, y2: _e25dbacd } if arr2.empty?
    arr = []
    arr2.sort_by { |arr3| arr3[0] }.each do |_9710d820, b|
      if arr.any? && _9710d820 <= arr.last[1] + 1e-6
        arr.last[1] = [arr.last[1], b].max
      else
        arr << [_9710d820, b]
      end
    end
    len = 0.0
    y1 = _e8649a72
    y2 = _e8649a72
    _7e53f420 = _e8649a72
    arr.each do |_9710d820, b|
      if _9710d820 - _7e53f420 > len
        len = _9710d820 - _7e53f420
        y1 = _7e53f420
        y2 = _9710d820
      end
      _7e53f420 = b if b > _7e53f420
    end
    if _e25dbacd - _7e53f420 > len
      len = _e25dbacd - _7e53f420
      y1 = _7e53f420
      y2 = _e25dbacd
    end
    { len: len, y1: y1, y2: y2 }
  end
  def points(half)
    [
      Geom::Point3d.new(half[:x1], half[:y1], @num13),
      Geom::Point3d.new(half[:x2], half[:y1], @num13),
      Geom::Point3d.new(half[:x2], half[:y2], @num13),
      Geom::Point3d.new(half[:x1], half[:y2], @num13)
    ]
  end
  def center(pts)
    color = KSU::Geom.centroid(pts)
    Geom::Point3d.new(color[0], color[1], @num13)
  end
  def _0183b2c7
    arr = []
    @sheets.each do |rec|
      sheet = rec[:instance]
      @arr10.select { |half| half[:sheet] == sheet && half[:points] && half[:points].length == 4 }.each do |slot|
        arr << { center: center(slot[:points]), kind: :remove, sheet: sheet, entry: slot, id: [:remove, slot.object_id] }
      end
      (@h3[sheet] || []).each_with_index do |pts, ix|
        next unless pts && pts.length == 4
        arr << { center: center(pts), kind: :add, sheet: sheet, entry: nil, points: pts, id: [:add, sheet.entityID, ix] }
      end
    end
    arr
  end
  def _d82a1555
    @h3.each do |sheet, out|
      out.each do |pts|
        next unless pts && pts.length == 4
        @arr10 << { sheet: sheet, points: pts }
      end
    end
  end
  def _bb230f13(view, x, y)
    _0183b2c7.find { |arr| KSU::View.button_hit?(view, arr[:center], x, y) }
  end
  def _6126236a(view, x, y)
    prev_key = @id
    arr = _bb230f13(view, x, y)
    @id = arr && arr[:id]
    view.invalidate if prev_key != @id
  end
  def _fb89e43a(pts)
    b = KSU::Geom.bounds(pts)
    [b[:min_x], b[:max_x], b[:min_y], b[:max_y]]
  end
  def _fc31c198(slot)
    pts = slot[:points]
    return [] unless pts && pts.length == 4
    x214, x2, _60000b16, y2 = _fb89e43a(pts)
    z = @num13
    [
      { edge: :x1, a: Geom::Point3d.new(x214, _60000b16, z), b: Geom::Point3d.new(x214, y2, z) },
      { edge: :x2, a: Geom::Point3d.new(x2, _60000b16, z), b: Geom::Point3d.new(x2, y2, z) },
      { edge: :y1, a: Geom::Point3d.new(x214, _60000b16, z), b: Geom::Point3d.new(x2, _60000b16, z) },
      { edge: :y2, a: Geom::Point3d.new(x214, y2, z), b: Geom::Point3d.new(x2, y2, z) }
    ]
  end
  def _78f40bb3(view, x, y)
    best = nil
    _aa866019 = KSU::Const::EDGE_HIT_PX * KSU::Const::EDGE_HIT_PX
    @arr10.each do |slot|
      _fc31c198(slot).each do |ent|
        len2d = KSU::Geom.dist2_to_seg(Geom::Point3d.new(x, y, 0), view.screen_coords(ent[:a]), view.screen_coords(ent[:b]))
        next unless len2d < _aa866019
        next if _23b18b68(slot, ent[:edge])
        _aa866019 = len2d
        best = { entry: slot, edge: ent[:edge], sheet: slot[:sheet] }
      end
    end
    best
  end
  def _23b18b68(slot, edge)
    return false unless @pt11
    pts = slot[:points]
    return false unless pts && pts.length == 4
    x215, x2, _60000b16, y2 = _fb89e43a(pts)
    tol = 1.0.mm.to_f
    px = @pt11.x.to_f
    py = @pt11.y.to_f
    case edge
    when :x1
      tx = x215 - tol
      _51d53976 = py.clamp(_60000b16, y2)
    when :x2
      tx = x2 + tol
      _51d53976 = py.clamp(_60000b16, y2)
    when :y1
      tx = px.clamp(x215, x2)
      _51d53976 = _60000b16 - tol
    when :y2
      tx = px.clamp(x215, x2)
      _51d53976 = y2 + tol
    end
    @arr10.any? do |panel|
      next false if panel.equal?(slot)
      next false unless panel[:sheet] == slot[:sheet]
      opac = panel[:points]
      next false unless opac && opac.length == 4
      _fcc2ae55, _e9dd4105, _f2b1338e, _175bc002 = _fb89e43a(opac)
      tx > _fcc2ae55 - 1e-6 && tx < _e9dd4105 + 1e-6 && _51d53976 > _f2b1338e - 1e-6 && _51d53976 < _175bc002 + 1e-6
    end
  end
  def _3c174b26(edge)
    [:x1, :x2].include?(edge) ? KSU::Const::CURSOR_SCALE_H : KSU::Const::CURSOR_SCALE_V
  end
  def _14e05dda(view, x, y)
    return false if @flag56
    arr52 = _78f40bb3(view, x, y)
    return false unless arr52
    rec = @sheets.find { |s| s[:instance] == arr52[:sheet] }
    @flag19 = true
    @entry = arr52[:entry]
    @edge = arr52[:edge]
    @flag61 = rec ? _c34290e2(rec) : nil
    @flag31 = rec ? _cca954c3(rec[:instance], rec[:transform]) : nil
    @arr16 = arr52[:entry][:points].map { |_23505ef9| _23505ef9.clone }
    @flag60 = nil
    view.invalidate
    true
  end
  def _fec87097(view)
    return unless @entry && @pt11
    pts = @entry[:points]
    x216, x2, _60000b16, y24 = _fb89e43a(pts)
    arr = @flag61
    case @edge
    when :x1, :x2
      v = @pt11.x.to_f
      v = [[v, arr[:xs]].max, arr[:xe]].min if arr
      v = _3066d644(@flag31, @edge, v, x216, x2, _60000b16, y24)
      if @edge == :x1 then x216 = v else x2 = v end
    when :y1, :y2
      v = @pt11.y.to_f
      v = [[v, arr[:ys]].max, arr[:ye]].min if arr
      v = _3066d644(@flag31, @edge, v, x216, x2, _60000b16, y24)
      if @edge == :y1 then _60000b16 = v else y24 = v end
    end
    x12 = [x216, x2].min
    x22 = [x216, x2].max
    y1 = [_60000b16, y24].min
    y2 = [_60000b16, y24].max
    @entry[:points] = points({ x1: x12, y1: y1, x2: x22, y2: y2 })
    @flag60 = nil
  end
  def _3066d644(panels, edge, v, x217, x2, _60000b16, y2)
    return v unless panels
    gap2 = @tam_cach_nhau.to_f
    tol = 1.mm.to_f
    panels.each do |bb|
      num2 = bb.min.x.to_f - gap2
      num3 = bb.max.x.to_f + gap2
      num5 = bb.min.y.to_f - gap2
      num4 = bb.max.y.to_f + gap2
      case edge
      when :x1
        next unless num4 > _60000b16 + tol && num5 < y2 - tol && num2 < x2
        v = num3 if num3 > v
      when :x2
        next unless num4 > _60000b16 + tol && num5 < y2 - tol && num3 > x217
        v = num2 if num2 < v
      when :y1
        next unless num3 > x217 + tol && num2 < x2 - tol && num5 < y2
        v = num4 if num4 > v
      when :y2
        next unless num3 > x217 + tol && num2 < x2 - tol && num4 > _60000b16
        v = num5 if num5 < v
      end
    end
    v
  end
  def _81184680(pt10, pt)
    return pt unless @arr26 && !@arr26.empty?
    start_x = pt10.x.to_f
    ly0 = pt10.y.to_f
    rx = pt.x.to_f
    ry = pt.y.to_f
    _02b82ead = [start_x, rx].min
    _7505b7d3 = [start_x, rx].max
    _e72d1472 = [ly0, ry].min
    _64662fb0 = [ly0, ry].max
    flag2 = _3066d644(@arr26, rx >= start_x ? :x2 : :x1, rx, _02b82ead, _7505b7d3, _e72d1472, _64662fb0)
    flag = _3066d644(@arr26, ry >= ly0 ? :y2 : :y1, ry, _02b82ead, _7505b7d3, _e72d1472, _64662fb0)
    num4 = (rx - flag2).abs
    num5 = (ry - flag).abs
    return pt if num4 < 1e-9 && num5 < 1e-9
    if num4 <= num5
      Geom::Point3d.new(flag2, ry, @num13)
    else
      Geom::Point3d.new(rx, flag, @num13)
    end
  end
  def _cd5e80f4
    slot = @entry
    slot[:points] = @arr16 if slot && @arr16 && !_a9ca2ebd(slot[:points])
    @flag19 = false
    @entry = nil
    @edge = nil
    @flag61 = nil
    @arr16 = nil
    @flag31 = nil
    @flag60 = nil
  end
  def _786169a2(view)
    return unless @flag19 && @entry
    pts = @entry[:points]
    return unless pts && pts.length == 4
    return if _a9ca2ebd(pts)
    KSU::View.draw_loop2d(pts, color: KSU::View.warning_color)
  end
  def _b6a93f39(view)
    @arr10.group_by { |ent| ent[:sheet] }.each do |_3b981bf6, entries|
      arr = entries.map { |ent| ent[:points] }.select { |pts| pts && pts.length == 4 }
      next if arr.empty?
      loops = _662cf545(arr)
      if loops.empty?
        arr.each { |pts| KSU::View.draw_fill2d(pts, line: true) }
      else
        loops.each { |_9b67c55d| KSU::View.draw_fill2d(_9b67c55d, line: true) }
      end
    end
  end
  def _f7ec2498(view)
    return unless @flag56
    rect = _d5a5cc33
    return unless rect
    if _a9ca2ebd(rect)
      KSU::View.draw_fill2d(rect, line: true)
    else
      KSU::View.draw_fill2d(rect, color: KSU::View.warn_color, line: false)
      KSU::View.draw_loop2d(rect, color: KSU::View.warning_color)
    end
  end
  def _8964db66(view)
    @h3.each_value do |out|
      out.each do |pts|
        next unless pts && pts.length == 4
        KSU::View.draw_loop2d(pts, guide: true)
      end
    end
  end
  def draw_sheet_buttons(view)
    flag28 = @num11 == 1 && @flag29 && @id ? @id[0] : nil
    _0183b2c7.each do |arr|
      hover = @id == arr[:id] || (flag28 && arr[:kind] == flag28)
      if arr[:kind] == :remove
        KSU::View.draw_warn_button(view, arr[:center], hover: hover)
      else
        KSU::View.draw_button(view, arr[:center], hover: hover)
      end
    end
  end
end
KSU::Netcatcuoi.include(KSU::Resize)
module KSU::Resize
  def self._77984365(key)
    return false unless key.length == 19
    return false unless key[0] == "k"
    return false unless key[4] == "-" && key[9] == "-" && key[14] == "-"
    key.chars.each_with_index do |color, i|
      next if i == 0 || i == 4 || i == 9 || i == 14
      return false unless color =~ /\A[0-9a-zA-Z]\z/
    end
    true
  end
end
