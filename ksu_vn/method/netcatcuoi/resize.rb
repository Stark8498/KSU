module KSU::Resize
  private
  def find_free_rects
    @free_rects = {}
    @sheets.each do |rec|
      arr2 = free_rects_of(rec)
      @free_rects[rec[:instance]] = arr2 unless arr2.empty?
    end
  end
  def usable_rect(rec)
    bbox = rec[:bbox]
    m_left, m_right, top, m_bottom = KSU::Avail.sides_for(rec[:instance], @tam_cach_le.to_f)
    [bbox.min.x.to_f + m_left, bbox.min.y.to_f + m_bottom, bbox.max.x.to_f - m_right, bbox.max.y.to_f - top]
  end
  def free_rects_of(rec)
    sheet = rec[:instance]
    panels = panel_boxes(sheet, rec[:transform], true)
    return [] if panels.empty?
    gap2 = @tam_cach_nhau.to_f
    min_side = @chieu_rong_toi_thieu.to_f
    ux1, uy1, ux2, uy2 = usable_rect(rec)
    return [] if ux2 - ux1 < min_side || uy2 - uy1 < min_side
    arr2 = panels.map do |pt|
      { x1: pt.min.x.to_f - gap2, x2: pt.max.x.to_f + gap2,
        y1: pt.min.y.to_f - gap2, y2: pt.max.y.to_f + gap2 }
    end
    @rects.each do |half|
      next unless half[:sheet] == sheet && half[:points] && half[:points].length == 4
      arr5 = half[:points].map { |pt| pt.x.to_f }
      arr4 = half[:points].map { |pt| pt.y.to_f }
      arr2 << { x1: arr5.min, x2: arr5.max, y1: arr4.min, y2: arr4.max }
    end
    arr3 = []
    while arr3.length < 50
      half = largest_gap(ux1, uy1, ux2, uy2, arr2, min_side)
      break unless half
      arr3 << points(half)
      arr2 << half
    end
    arr3
  end
  def largest_gap(ux1, uy1, ux2, uy2, arr3, min_side)
    tol = 1e-6
    arr2 = KSU::Geom._a404e7b6([ux1, ux2] + arr3.flat_map { |b| [b[:x1], b[:x2]] }.select { |v| v > ux1 + tol && v < ux2 - tol })
    best = nil
    best_a = 0.0
    (0...arr2.length - 1).each do |i|
      ((i + 1)...arr2.length).each do |j|
        x212 = arr2[i]
        x2 = arr2[j]
        w = x2 - x212
        next if w < min_side
        arr4 = []
        arr3.each do |b|
          next unless b[:x1] < x2 - tol && b[:x2] > x212 + tol
          ylo = [b[:y1], uy1].max
          yhi = [b[:y2], uy2].min
          arr4 << [ylo, yhi] if yhi > ylo + tol
        end
        gap2 = longest_free_y(uy1, uy2, arr4)
        next if gap2[:len] < min_side
        area = w * gap2[:len]
        if area > best_a + tol
          best_a = area
          best = { x1: x212, y1: gap2[:y1], x2: x2, y2: gap2[:y2] }
        end
      end
    end
    best
  end
  def longest_free_y(ylo, yhi, arr2)
    return { len: yhi - ylo, y1: ylo, y2: yhi } if arr2.empty?
    arr = []
    arr2.sort_by { |arr3| arr3[0] }.each do |_9710d820, b|
      if arr.any? && _9710d820 <= arr.last[1] + 1e-6
        arr.last[1] = [arr.last[1], b].max
      else
        arr << [_9710d820, b]
      end
    end
    len = 0.0
    y1 = ylo
    y2 = ylo
    _7e53f420 = ylo
    arr.each do |_9710d820, b|
      if _9710d820 - _7e53f420 > len
        len = _9710d820 - _7e53f420
        y1 = _7e53f420
        y2 = _9710d820
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
  def points(half)
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
  def buttons
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
  def add_all
    @free_rects.each do |sheet, arr|
      arr.each do |pts|
        next unless pts && pts.length == 4
        @rects << { sheet: sheet, points: pts }
      end
    end
  end
  def button_hit(view, x, y)
    buttons.find { |arr| KSU::View.button_hit?(view, arr[:center], x, y) }
  end
  def hover_button(view, x, y)
    prev_key = @id
    arr = button_hit(view, x, y)
    @id = arr && arr[:id]
    view.invalidate if prev_key != @id
  end
  def xy_bounds(pts)
    b = KSU::Geom.bounds(pts)
    [b[:min_x], b[:max_x], b[:min_y], b[:max_y]]
  end
  def slot_edges(slot)
    pts = slot[:points]
    return [] unless pts && pts.length == 4
    x213, x2, _60000b16, y2 = xy_bounds(pts)
    z = @plane_z
    [
      { edge: :x1, a: Geom::Point3d.new(x213, _60000b16, z), b: Geom::Point3d.new(x213, y2, z) },
      { edge: :x2, a: Geom::Point3d.new(x2, _60000b16, z), b: Geom::Point3d.new(x2, y2, z) },
      { edge: :y1, a: Geom::Point3d.new(x213, _60000b16, z), b: Geom::Point3d.new(x2, _60000b16, z) },
      { edge: :y2, a: Geom::Point3d.new(x213, y2, z), b: Geom::Point3d.new(x2, y2, z) }
    ]
  end
  def edge_at(view, x, y)
    best = nil
    best_d2x = KSU::Const::EDGE_HIT_PX * KSU::Const::EDGE_HIT_PX
    @rects.each do |slot|
      slot_edges(slot).each do |ent|
        len2d = KSU::Geom.dist2_to_seg(Geom::Point3d.new(x, y, 0), view.screen_coords(ent[:a]), view.screen_coords(ent[:b]))
        next unless len2d < best_d2x
        next if edge_blocked?(slot, ent[:edge])
        best_d2x = len2d
        best = { entry: slot, edge: ent[:edge], sheet: slot[:sheet] }
      end
    end
    best
  end
  def edge_blocked?(slot, edge)
    return false unless @cur_pt
    pts = slot[:points]
    return false unless pts && pts.length == 4
    x214, x2, _60000b16, y2 = xy_bounds(pts)
    num = 1.0.mm.to_f
    px = @cur_pt.x.to_f
    py = @cur_pt.y.to_f
    case edge
    when :x1
      tx = x214 - num
      ty = py.clamp(_60000b16, y2)
    when :x2
      tx = x2 + num
      ty = py.clamp(_60000b16, y2)
    when :y1
      tx = px.clamp(x214, x2)
      ty = _60000b16 - num
    when :y2
      tx = px.clamp(x214, x2)
      ty = y2 + num
    end
    @rects.any? do |panel|
      next false if panel.equal?(slot)
      next false unless panel[:sheet] == slot[:sheet]
      opac = panel[:points]
      next false unless opac && opac.length == 4
      _fcc2ae55, _e9dd4105, _f2b1338e, _175bc002 = xy_bounds(opac)
      tx > _fcc2ae55 - 1e-6 && tx < _e9dd4105 + 1e-6 && ty > _f2b1338e - 1e-6 && ty < _175bc002 + 1e-6
    end
  end
  def cursor_for(edge)
    [:x1, :x2].include?(edge) ? KSU::Const::CURSOR_SCALE_H : KSU::Const::CURSOR_SCALE_V
  end
  def begin_resize(view, x, y)
    return false if @flag56
    h = edge_at(view, x, y)
    return false unless h
    rec = @sheets.find { |s| s[:instance] == h[:sheet] }
    @flag19 = true
    @entry = h[:entry]
    @edge = h[:edge]
    @flag61 = rec ? limits_of(rec) : nil
    @flag31 = rec ? panel_boxes(rec[:instance], rec[:transform]) : nil
    @arr16 = h[:entry][:points].map { |_23505ef9| _23505ef9.clone }
    @flag60 = nil
    view.invalidate
    true
  end
  def resize_to_cursor(view)
    return unless @entry && @cur_pt
    pts = @entry[:points]
    x215, x2, _60000b16, y23 = xy_bounds(pts)
    arr = @flag61
    case @edge
    when :x1, :x2
      v = @cur_pt.x.to_f
      v = [[v, arr[:xs]].max, arr[:xe]].min if arr
      v = clamp_to_panels(@flag31, @edge, v, x215, x2, _60000b16, y23)
      if @edge == :x1 then x215 = v else x2 = v end
    when :y1, :y2
      v = @cur_pt.y.to_f
      v = [[v, arr[:ys]].max, arr[:ye]].min if arr
      v = clamp_to_panels(@flag31, @edge, v, x215, x2, _60000b16, y23)
      if @edge == :y1 then _60000b16 = v else y23 = v end
    end
    x12 = [x215, x2].min
    x22 = [x215, x2].max
    y1 = [_60000b16, y23].min
    y2 = [_60000b16, y23].max
    @entry[:points] = points({ x1: x12, y1: y1, x2: x22, y2: y2 })
    @flag60 = nil
  end
  def clamp_to_panels(panels, edge, v, x216, x2, _60000b16, y2)
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
        next unless num4 > _60000b16 + tol && num5 < y2 - tol && num3 > x216
        v = num2 if num2 < v
      when :y1
        next unless num3 > x216 + tol && num2 < x2 - tol && num5 < y2
        v = num4 if num4 > v
      when :y2
        next unless num3 > x216 + tol && num2 < x2 - tol && num4 > _60000b16
        v = num5 if num5 < v
      end
    end
    v
  end
  def clamp_point(press_pt, pt)
    return pt unless @arr26 && !@arr26.empty?
    start_x = press_pt.x.to_f
    ly0 = press_pt.y.to_f
    rx = pt.x.to_f
    ry = pt.y.to_f
    rx1 = [start_x, rx].min
    rx2 = [start_x, rx].max
    ry1 = [ly0, ry].min
    ry2 = [ly0, ry].max
    flag2 = clamp_to_panels(@arr26, rx >= start_x ? :x2 : :x1, rx, rx1, rx2, ry1, ry2)
    flag = clamp_to_panels(@arr26, ry >= ly0 ? :y2 : :y1, ry, rx1, rx2, ry1, ry2)
    num4 = (rx - flag2).abs
    num5 = (ry - flag).abs
    return pt if num4 < 1e-9 && num5 < 1e-9
    if num4 <= num5
      Geom::Point3d.new(flag2, ry, @plane_z)
    else
      Geom::Point3d.new(rx, flag, @plane_z)
    end
  end
  def end_resize
    slot = @entry
    slot[:points] = @arr16 if slot && @arr16 && !big_enough?(slot[:points])
    @flag19 = false
    @entry = nil
    @edge = nil
    @flag61 = nil
    @arr16 = nil
    @flag31 = nil
    @flag60 = nil
  end
  def draw_bad_rect(view)
    return unless @flag19 && @entry
    pts = @entry[:points]
    return unless pts && pts.length == 4
    return if big_enough?(pts)
    KSU::View.draw_loop2d(pts, color: KSU::View.warning_color)
  end
  def draw_slots(view)
    @rects.group_by { |ent| ent[:sheet] }.each do |sheet, entries|
      arr = entries.map { |ent| ent[:points] }.select { |pts| pts && pts.length == 4 }
      next if arr.empty?
      loops = merge_rects(arr)
      if loops.empty?
        arr.each { |pts| KSU::View.draw_fill2d(pts, line: true) }
      else
        loops.each { |loop_pts| KSU::View.draw_fill2d(loop_pts, line: true) }
      end
    end
  end
  def draw_new_rect(view)
    return unless @flag56
    rect = drag_rect
    return unless rect
    if big_enough?(rect)
      KSU::View.draw_fill2d(rect, line: true)
    else
      KSU::View.draw_fill2d(rect, color: KSU::View.warn_color, line: false)
      KSU::View.draw_loop2d(rect, color: KSU::View.warning_color)
    end
  end
  def draw_free_rects(view)
    @free_rects.each_value do |arr|
      arr.each do |pts|
        next unless pts && pts.length == 4
        KSU::View.draw_loop2d(pts, guide: true)
      end
    end
  end
  def draw_sheet_buttons(view)
    btn_joint = @mode == 1 && @flag29 && @id ? @id[0] : nil
    buttons.each do |arr|
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
