module KSU::Resize
  private
  def find_free_rects_v1
    @free_rects = {}
    @sheets.each do |rec|
      arr = free_rects_of_v1(rec)
      @free_rects[rec[:instance]] = arr unless arr.empty?
    end
  end
  def usable_rect_v1(rec)
    bbox = rec[:bbox]
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(rec[:instance], @tam_cach_le.to_f)
    [bbox.min.x.to_f + m_left, bbox.min.y.to_f + m_bottom, bbox.max.x.to_f - m_right, bbox.max.y.to_f - top]
  end
  def free_rects_of_v1(rec)
    sheet = rec[:instance]
    panels = panel_boxes_v1(sheet, rec[:transform], true)
    return [] if panels.empty?
    gap2 = @tam_cach_nhau.to_f
    min_side = @chieu_rong_toi_thieu.to_f
    ux1, uy1, ux2, uy2 = usable_rect_v1(rec)
    return [] if ux2 - ux1 < min_side || uy2 - uy1 < min_side
    arr2 = panels.map do |pt|
      { x1: pt.min.x.to_f - gap2, x2: pt.max.x.to_f + gap2,
        y1: pt.min.y.to_f - gap2, y2: pt.max.y.to_f + gap2 }
    end
    @rects.each do |half|
      next unless half[:sheet] == sheet && half[:points] && half[:points].length == 4
      arr3 = half[:points].map { |pt| pt.x.to_f }
      arr4 = half[:points].map { |pt| pt.y.to_f }
      arr2 << { x1: arr3.min, x2: arr3.max, y1: arr4.min, y2: arr4.max }
    end
    arr = []
    while arr.length < 50
      half = largest_gap_v1(ux1, uy1, ux2, uy2, arr2, min_side)
      break unless half
      arr << points_v1(half)
      arr2 << half
    end
    arr
  end
  def largest_gap_v1(ux1, uy1, ux2, uy2, arr2, min_side)
    tol = 1e-6
    arr = KSU::Geom.merge_near([ux1, ux2] + arr2.flat_map { |b| [b[:x1], b[:x2]] }.select { |v| v > ux1 + tol && v < ux2 - tol })
    best = nil
    best_a = 0.0
    (0...arr.length - 1).each do |i|
      ((i + 1)...arr.length).each do |j|
        _77445f53 = arr[i]
        x2 = arr[j]
        w = x2 - _77445f53
        next if w < min_side
        arr3 = []
        arr2.each do |b|
          next unless b[:x1] < x2 - tol && b[:x2] > _77445f53 + tol
          ylo = [b[:y1], uy1].max
          yhi = [b[:y2], uy2].min
          arr3 << [ylo, yhi] if yhi > ylo + tol
        end
        gap2 = longest_free_y_v1(uy1, uy2, arr3)
        next if gap2[:len] < min_side
        _5fb96e91 = w * gap2[:len]
        if _5fb96e91 > best_a + tol
          best_a = _5fb96e91
          best = { x1: _77445f53, y1: gap2[:y1], x2: x2, y2: gap2[:y2] }
        end
      end
    end
    best
  end
  def longest_free_y_v1(ylo, yhi, arr2)
    return { len: yhi - ylo, y1: ylo, y2: yhi } if arr2.empty?
    arr = []
    arr2.sort_by { |arr3| arr3[0] }.each do |v, b|
      if arr.any? && v <= arr.last[1] + 1e-6
        arr.last[1] = [arr.last[1], b].max
      else
        arr << [v, b]
      end
    end
    len = 0.0
    y1 = ylo
    y2 = ylo
    _7e53f420 = ylo
    arr.each do |v, b|
      if v - _7e53f420 > len
        len = v - _7e53f420
        y1 = _7e53f420
        y2 = v
      end
      _7e53f420 = b if b > _7e53f420
    end
    if yhi - _7e53f420 > len
      len = yhi - _7e53f420
      y1 = _7e53f420
      y2 = yhi
    end
    { len: len, y1: y1, y2: y2 }
  end
  def points_v1(half)
    [
      Geom::Point3d.new(half[:x1], half[:y1], @plane_z),
      Geom::Point3d.new(half[:x2], half[:y1], @plane_z),
      Geom::Point3d.new(half[:x2], half[:y2], @plane_z),
      Geom::Point3d.new(half[:x1], half[:y2], @plane_z)
    ]
  end
  def centroid_pt(pts)
    color = KSU::Geom.centroid(pts)
    Geom::Point3d.new(color[0], color[1], @plane_z)
  end
  def buttons_v1
    arr = []
    @sheets.each do |rec|
      sheet = rec[:instance]
      @rects.select { |half| half[:sheet] == sheet && half[:points] && half[:points].length == 4 }.each do |slot|
        arr << { center: centroid_pt(slot[:points]), kind: :remove, sheet: sheet, entry: slot, id: [:remove, slot.object_id] }
      end
      (@free_rects[sheet] || []).each_with_index do |pts, ix|
        next unless pts && pts.length == 4
        arr << { center: centroid_pt(pts), kind: :add, sheet: sheet, entry: nil, points: pts, id: [:add, sheet.entityID, ix] }
      end
    end
    arr
  end
  def add_all_v1
    @free_rects.each do |sheet, arr|
      arr.each do |pts|
        next unless pts && pts.length == 4
        @rects << { sheet: sheet, points: pts }
      end
    end
  end
  def button_hit_v1(view, x, y)
    buttons_v1.find { |arr| KSU::View.button_hit?(view, arr[:center], x, y) }
  end
  def hover_button_v1(view, x, y)
    prev_key = @id
    arr = button_hit_v1(view, x, y)
    @id = arr && arr[:id]
    view.invalidate if prev_key != @id
  end
  def xy_bounds_v1(pts)
    b = KSU::Geom.bounds(pts)
    [b[:min_x], b[:max_x], b[:min_y], b[:max_y]]
  end
  def slot_edges_v1(slot)
    pts = slot[:points]
    return [] unless pts && pts.length == 4
    _77445f53, x2, _60000b16, _9b84c914 = xy_bounds_v1(pts)
    z = @plane_z
    [
      { edge: :x1, a: Geom::Point3d.new(_77445f53, _60000b16, z), b: Geom::Point3d.new(_77445f53, _9b84c914, z) },
      { edge: :x2, a: Geom::Point3d.new(x2, _60000b16, z), b: Geom::Point3d.new(x2, _9b84c914, z) },
      { edge: :y1, a: Geom::Point3d.new(_77445f53, _60000b16, z), b: Geom::Point3d.new(x2, _60000b16, z) },
      { edge: :y2, a: Geom::Point3d.new(_77445f53, _9b84c914, z), b: Geom::Point3d.new(x2, _9b84c914, z) }
    ]
  end
  def edge_at_v1(view, x, y)
    best = nil
    best_d2x = KSU::Const::EDGE_HIT_PX * KSU::Const::EDGE_HIT_PX
    @rects.each do |slot|
      slot_edges_v1(slot).each do |ent|
        len2d = KSU::Geom.dist2_to_seg(Geom::Point3d.new(x, y, 0), view.screen_coords(ent[:a]), view.screen_coords(ent[:b]))
        next unless len2d < best_d2x
        next if edge_blocked_v1?(slot, ent[:edge])
        best_d2x = len2d
        best = { entry: slot, edge: ent[:edge], sheet: slot[:sheet] }
      end
    end
    best
  end
  def edge_blocked_v1?(slot, edge)
    return false unless @cur_pt
    pts = slot[:points]
    return false unless pts && pts.length == 4
    _77445f53, x2, _60000b16, _9b84c914 = xy_bounds_v1(pts)
    num = 1.0.mm.to_f
    px = @cur_pt.x.to_f
    py = @cur_pt.y.to_f
    case edge
    when :x1
      tx = _77445f53 - num
      ty = py.clamp(_60000b16, _9b84c914)
    when :x2
      tx = x2 + num
      ty = py.clamp(_60000b16, _9b84c914)
    when :y1
      tx = px.clamp(_77445f53, x2)
      ty = _60000b16 - num
    when :y2
      tx = px.clamp(_77445f53, x2)
      ty = _9b84c914 + num
    end
    @rects.any? do |arr|
      next false if arr.equal?(slot)
      next false unless arr[:sheet] == slot[:sheet]
      opac = arr[:points]
      next false unless opac && opac.length == 4
      bx0, bx1, by0, by1 = xy_bounds_v1(opac)
      tx > bx0 - 1e-6 && tx < bx1 + 1e-6 && ty > by0 - 1e-6 && ty < by1 + 1e-6
    end
  end
  def cursor_for_v1(edge)
    [:x1, :x2].include?(edge) ? KSU::Const::CURSOR_SCALE_H : KSU::Const::CURSOR_SCALE_V
  end
  def begin_resize_v1(view, x, y)
    return false if @flag35
    h = edge_at_v1(view, x, y)
    return false unless h
    rec = @sheets.find { |s| s[:instance] == h[:sheet] }
    @flag11 = true
    @entry = h[:entry]
    @edge = h[:edge]
    @flag42 = rec ? limits_of(rec) : nil
    @flag18 = rec ? panel_boxes_v1(rec[:instance], rec[:transform]) : nil
    @arr15 = h[:entry][:points].map { |pt4| pt4.clone }
    @flag39 = nil
    view.invalidate
    true
  end
  def resize_to_cursor(view)
    return unless @entry && @cur_pt
    pts = @entry[:points]
    _77445f53, x2, _60000b16, _9b84c914 = xy_bounds_v1(pts)
    arr = @flag42
    case @edge
    when :x1, :x2
      v = @cur_pt.x.to_f
      v = [[v, arr[:xs]].max, arr[:xe]].min if arr
      v = clamp_to_panels_v1(@flag18, @edge, v, _77445f53, x2, _60000b16, _9b84c914)
      if @edge == :x1 then _77445f53 = v else x2 = v end
    when :y1, :y2
      v = @cur_pt.y.to_f
      v = [[v, arr[:ys]].max, arr[:ye]].min if arr
      v = clamp_to_panels_v1(@flag18, @edge, v, _77445f53, x2, _60000b16, _9b84c914)
      if @edge == :y1 then _60000b16 = v else _9b84c914 = v end
    end
    x12 = [_77445f53, x2].min
    _10270e02 = [_77445f53, x2].max
    y1 = [_60000b16, _9b84c914].min
    y2 = [_60000b16, _9b84c914].max
    @entry[:points] = points_v1({ x1: x12, y1: y1, x2: _10270e02, y2: y2 })
    @flag39 = nil
  end
  def clamp_to_panels_v1(panels, edge, v, _77445f53, x2, _60000b16, _9b84c914)
    return v unless panels
    gap2 = @tam_cach_nhau.to_f
    tol = 1.mm.to_f
    panels.each do |bb|
      num2 = bb.min.x.to_f - gap2
      num = bb.max.x.to_f + gap2
      num4 = bb.min.y.to_f - gap2
      num3 = bb.max.y.to_f + gap2
      case edge
      when :x1
        next unless num3 > _60000b16 + tol && num4 < _9b84c914 - tol && num2 < x2
        v = num if num > v
      when :x2
        next unless num3 > _60000b16 + tol && num4 < _9b84c914 - tol && num > _77445f53
        v = num2 if num2 < v
      when :y1
        next unless num > _77445f53 + tol && num2 < x2 - tol && num4 < _9b84c914
        v = num3 if num3 > v
      when :y2
        next unless num > _77445f53 + tol && num2 < x2 - tol && num3 > _60000b16
        v = num4 if num4 < v
      end
    end
    v
  end
  def clamp_point_v1(press_pt, pt)
    return pt unless @arr27 && !@arr27.empty?
    start_x = press_pt.x.to_f
    ly0 = press_pt.y.to_f
    rx = pt.x.to_f
    ry = pt.y.to_f
    rx1 = [start_x, rx].min
    rx2 = [start_x, rx].max
    ry1 = [ly0, ry].min
    ry2 = [ly0, ry].max
    flag2 = clamp_to_panels_v1(@arr27, rx >= start_x ? :x2 : :x1, rx, rx1, rx2, ry1, ry2)
    flag = clamp_to_panels_v1(@arr27, ry >= ly0 ? :y2 : :y1, ry, rx1, rx2, ry1, ry2)
    num2 = (rx - flag2).abs
    num = (ry - flag).abs
    return pt if num2 < 1e-9 && num < 1e-9
    if num2 <= num
      Geom::Point3d.new(flag2, ry, @plane_z)
    else
      Geom::Point3d.new(rx, flag, @plane_z)
    end
  end
  def end_resize_v1
    slot = @entry
    slot[:points] = @arr15 if slot && @arr15 && !big_enough?(slot[:points])
    @flag11 = false
    @entry = nil
    @edge = nil
    @flag42 = nil
    @arr15 = nil
    @flag18 = nil
    @flag39 = nil
  end
  def draw_bad_rect(view)
    return unless @flag11 && @entry
    pts = @entry[:points]
    return unless pts && pts.length == 4
    return if big_enough?(pts)
    KSU::View.draw_loop2d(pts, color: KSU::View.warning_color)
  end
  def draw_slots(view)
    @rects.group_by { |ent| ent[:sheet] }.each do |sheet, entries|
      arr = entries.map { |ent| ent[:points] }.select { |pts| pts && pts.length == 4 }
      next if arr.empty?
      loops = merge_rects_v1(arr)
      if loops.empty?
        arr.each { |pts| KSU::View.draw_fill2d(pts, line: true) }
      else
        loops.each { |_9b67c55d| KSU::View.draw_fill2d(_9b67c55d, line: true) }
      end
    end
  end
  def draw_new_rect(view)
    return unless @flag35
    rect_v1 = drag_rect
    return unless rect_v1
    if big_enough?(rect_v1)
      KSU::View.draw_fill2d(rect_v1, line: true)
    else
      KSU::View.draw_fill2d(rect_v1, color: KSU::View.warn_color, line: false)
      KSU::View.draw_loop2d(rect_v1, color: KSU::View.warning_color)
    end
  end
  def draw_free_rects_v1(view)
    @free_rects.each_value do |arr|
      arr.each do |pts|
        next unless pts && pts.length == 4
        KSU::View.draw_loop2d(pts, guide: true)
      end
    end
  end
  def draw_sheet_buttons_v1(view)
    btn_joint = @mode == 1 && @flag17 && @id ? @id[0] : nil
    buttons_v1.each do |arr|
      hover = @id == arr[:id] || (btn_joint && arr[:kind] == btn_joint)
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
  def self.valid_key_format_v1?(key)
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
