module KSU::Resize
  private
  def find_free_rects
    @free_rects = {}
    @sheets.each do |rec|
      arr = free_rects_of(rec)
      @free_rects[rec[:instance]] = arr unless arr.empty?
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
    arr = panels.map do |bb|
      { x1: bb.min.x.to_f - gap2, x2: bb.max.x.to_f + gap2,
        y1: bb.min.y.to_f - gap2, y2: bb.max.y.to_f + gap2 }
    end
    @rects.each do |half|
      next unless half[:sheet] == sheet
      x1, x2, y1, y2 = xy_bounds(half[:points])
      arr << { x1: x1, x2: x2, y1: y1, y2: y2 }
    end
    arr2 = []
    while arr2.length < 50
      half = largest_gap(ux1, uy1, ux2, uy2, arr, min_side)
      break unless half
      arr2 << points(half)
      arr << half
    end
    arr2
  end
  def largest_gap(ux1, uy1, ux2, uy2, arr3, min_side)
    tol = 1e-6
    arr = KSU::Geom.merge_near([ux1, ux2] + arr3.flat_map { |b| [b[:x1], b[:x2]] }.select { |v| v > ux1 + tol && v < ux2 - tol })
    best = nil
    best_a = 0.0
    (0...arr.length - 1).each do |i|
      ((i + 1)...arr.length).each do |ix|
        x1 = arr[i]
        x2 = arr[ix]
        w = x2 - x1
        next if w < min_side
        arr2 = []
        arr3.each do |b|
          next unless b[:x1] < x2 - tol && b[:x2] > x1 + tol
          _09dce564 = [b[:y1], uy1].max
          _a5ffa708 = [b[:y2], uy2].min
          arr2 << [_09dce564, _a5ffa708] if _a5ffa708 > _09dce564 + tol
        end
        gap2 = longest_free_y(uy1, uy2, arr2)
        next if gap2[:len] < min_side
        _354e0ff6 = w * gap2[:len]
        if _354e0ff6 > best_a + tol
          best_a = _354e0ff6
          best = { x1: x1, y1: gap2[:y1], x2: x2, y2: gap2[:y2] }
        end
      end
    end
    best
  end
  def longest_free_y(_09dce564, _a5ffa708, arr)
    return { len: _a5ffa708 - _09dce564, y1: _09dce564, y2: _a5ffa708 } if arr.empty?
    out_rec = []
    arr.sort_by { |arr2| arr2[0] }.each do |a, b|
      if out_rec.any? && a <= out_rec.last[1] + 1e-6
        out_rec.last[1] = [out_rec.last[1], b].max
      else
        out_rec << [a, b]
      end
    end
    len = 0.0
    y1 = y2 = _7a72dc50 = _09dce564
    out_rec.each do |a, b|
      if a - _7a72dc50 > len
        len = a - _7a72dc50
        y1 = _7a72dc50
        y2 = a
      end
      _7a72dc50 = b if b > _7a72dc50
    end
    if _a5ffa708 - _7a72dc50 > len
      len = _a5ffa708 - _7a72dc50
      y1 = _7a72dc50
      y2 = _a5ffa708
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
  def center(pts2)
    arr = KSU::Geom.centroid(pts2)
    Geom::Point3d.new(arr[0], arr[1], @plane_z)
  end
  def buttons
    arr = []
    @sheets.each do |rec|
      grp = rec[:instance]
      @rects.select { |half| half[:sheet] == grp }.each do |slot|
        arr << { center: center(slot[:points]), kind: :remove, sheet: grp, entry: slot, id: [:remove, slot.object_id] }
      end
      (@free_rects[grp] || []).each_with_index do |pts2, ix|
        arr << { center: center(pts2), kind: :add, sheet: grp, entry: nil, points: pts2, id: [:add, grp.entityID, ix] }
      end
    end
    arr
  end
  def add_all
    @free_rects.each do |sheet, entries|
      entries.each { |pts2| @rects << { sheet: sheet, points: pts2 } }
    end
  end
  def button_hit(view, x, y)
    buttons.find { |_945ac34d| KSU::View.button_hit?(view, _945ac34d[:center], x, y) }
  end
  def hover_button(view, x, y)
    _945ac34d = button_hit(view, x, y)
    @id = _945ac34d && _945ac34d[:id]
  end
  def xy_bounds(pts2)
    b = KSU::Geom.bounds(pts2)
    [b[:min_x], b[:max_x], b[:min_y], b[:max_y]]
  end
  def slot_edges(slot)
    x1, x2, y1, y2 = xy_bounds(slot[:points])
    z = @plane_z
    [
      { edge: :x1, a: Geom::Point3d.new(x1, y1, z), b: Geom::Point3d.new(x1, y2, z) },
      { edge: :x2, a: Geom::Point3d.new(x2, y1, z), b: Geom::Point3d.new(x2, y2, z) },
      { edge: :y1, a: Geom::Point3d.new(x1, y1, z), b: Geom::Point3d.new(x2, y1, z) },
      { edge: :y2, a: Geom::Point3d.new(x1, y2, z), b: Geom::Point3d.new(x2, y2, z) }
    ]
  end
  def edge_at(view, x, y)
    best = nil
    best_d2x = 6 * 6
    @rects.each do |slot|
      slot_edges(slot).each do |arr|
        len2d = KSU::Geom.dist2_to_seg(Geom::Point3d.new(x, y, 0), view.screen_coords(arr[:a]), view.screen_coords(arr[:b]))
        next unless len2d < best_d2x
        next if edge_blocked?(slot, arr[:edge])
        best_d2x = len2d
        best = { entry: slot, edge: arr[:edge], sheet: slot[:sheet] }
      end
    end
    best
  end
  def edge_blocked?(slot, edge)
    return false unless @cur_pt
    x1, x2, y1, y2 = xy_bounds(slot[:points])
    eps = 1.0.mm.to_f
    px = @cur_pt.x.to_f
    py = @cur_pt.y.to_f
    tx, ty = case edge
                   when :x1 then [x1 - eps, py.clamp(y1, y2)]
                   when :x2 then [x2 + eps, py.clamp(y1, y2)]
                   when :y1 then [px.clamp(x1, x2), y1 - eps]
                   when :y2 then [px.clamp(x1, x2), y2 + eps]
                   end
    @rects.any? do |panel|
      next false if panel.equal?(slot)
      next false unless panel[:sheet] == slot[:sheet]
      bx0, bx1, by0, by1 = xy_bounds(panel[:points])
      tx > bx0 - 1e-6 && tx < bx1 + 1e-6 && ty > by0 - 1e-6 && ty < by1 + 1e-6
    end
  end
  def cursor_for(edge)
    [:x1, :x2].include?(edge) ? 660 : 659
  end
  def begin_resize(view, x, y)
    return false if @flag22
    elem = edge_at(view, x, y)
    return false unless elem
    rec = KSU::Sheet.record_for(@sheets, elem[:sheet])
    @flag31 = true
    @entry = elem[:entry]
    @edge = elem[:edge]
    @flag3 = rec ? limits_of(rec) : nil
    @flag6 = rec ? panel_boxes(rec[:instance], rec[:transform]) : nil
    @arr44 = elem[:entry][:points].map(&:clone)
    @flag46 = nil
    view.invalidate
    true
  end
  def draw_entry
    return unless @entry && @cur_pt
    x1, x2, y1, y2 = xy_bounds(@entry[:points])
    arr = @flag3
    case @edge
    when :x1, :x2
      v = @cur_pt.x.to_f
      v = [[v, arr[:xs]].max, arr[:xe]].min if arr
      v = clamp_to_panels(@flag6, @edge, v, x1, x2, y1, y2)
      if @edge == :x1 then x1 = v else x2 = v end
    when :y1, :y2
      v = @cur_pt.y.to_f
      v = [[v, arr[:ys]].max, arr[:ye]].min if arr
      v = clamp_to_panels(@flag6, @edge, v, x1, x2, y1, y2)
      if @edge == :y1 then y1 = v else y2 = v end
    end
    @entry[:points] = points({ x1: [x1, x2].min, y1: [y1, y2].min, x2: [x1, x2].max, y2: [y1, y2].max })
    @flag46 = nil
  end
  def clamp_to_panels(panels, edge, v, x1, x2, y1, y2)
    return v unless panels
    gap2 = @tam_cach_nhau.to_f
    tol = 1.mm.to_f
    panels.each do |bb|
      num4 = bb.min.x.to_f - gap2
      num2 = bb.max.x.to_f + gap2
      num = bb.min.y.to_f - gap2
      num3 = bb.max.y.to_f + gap2
      case edge
      when :x1
        next unless num3 > y1 + tol && num < y2 - tol && num4 < x2
        v = num2 if num2 > v
      when :x2
        next unless num3 > y1 + tol && num < y2 - tol && num2 > x1
        v = num4 if num4 < v
      when :y1
        next unless num2 > x1 + tol && num4 < x2 - tol && num < y2
        v = num3 if num3 > v
      when :y2
        next unless num2 > x1 + tol && num4 < x2 - tol && num3 > y1
        v = num if num < v
      end
    end
    v
  end
  def clamp_point(press_pt, pt)
    return pt unless @arr11 && !@arr11.empty?
    start_x = press_pt.x.to_f
    ly0 = press_pt.y.to_f
    rx = pt.x.to_f
    ry = pt.y.to_f
    rx1, rx2, ry1, ry2 = xy_bounds([press_pt, pt])
    flag = clamp_to_panels(@arr11, rx >= start_x ? :x2 : :x1, rx, rx1, rx2, ry1, ry2)
    flag2 = clamp_to_panels(@arr11, ry >= ly0 ? :y2 : :y1, ry, rx1, rx2, ry1, ry2)
    num = (rx - flag).abs
    num2 = (ry - flag2).abs
    return pt if num < 1e-9 && num2 < 1e-9
    num <= num2 ? Geom::Point3d.new(flag, ry, @plane_z) : Geom::Point3d.new(rx, flag2, @plane_z)
  end
  def end_resize
    slot = @entry
    slot[:points] = @arr44 if slot && @arr44 && !big_enough?(slot[:points])
    @flag31 = false
    @entry = @edge = @flag3 = @arr44 = @flag6 = @flag46 = nil
  end
  def draw_cut_line
    return unless @flag31 && @entry
    pts2 = @entry[:points]
    return if big_enough?(pts2)
    KSU::View.draw_loop2d(pts2, color: KSU::View.warning_color)
  end
  def draw_sheet_rects
    @rects.group_by { |arr| arr[:sheet] }.each_value do |entries|
      arr2 = entries.map { |arr| arr[:points] }
      loops = merge_rects(arr2)
      (loops.empty? ? arr2 : loops).each { |_f0ba2e7b| KSU::View.draw_fill2d(_f0ba2e7b, line: true) }
    end
  end
  def draw_drag_rect
    rect = @flag22 && drag_rect
    return unless rect
    if big_enough?(rect)
      KSU::View.draw_fill2d(rect, line: true)
    else
      KSU::View.draw_fill2d(rect, color: KSU::View.warn_color, line: false)
      KSU::View.draw_loop2d(rect, color: KSU::View.warning_color)
    end
  end
  def draw_free_rects
    @free_rects.each_value { |entries| entries.each { |pts2| KSU::View.draw_loop2d(pts2, guide: true) } }
  end
  def draw_sheet_buttons(view)
    btn_joint = @mode == 1 && @flag36 && @id ? @id[0] : nil
    buttons.each do |_945ac34d|
      hover = @id == _945ac34d[:id] || (btn_joint && _945ac34d[:kind] == btn_joint)
      if _945ac34d[:kind] == :remove
        KSU::View.draw_warn_button(view, _945ac34d[:center], hover: hover)
      else
        KSU::View.draw_button(view, _945ac34d[:center], hover: hover)
      end
    end
  end
end
KSU::Catcuoi.include(KSU::Resize)
module KSU::Resize
  def self.valid_key_format?(key)
    return false unless key.length == 19
    return false unless key[0] == "k"
    return false unless key[4] == "-" && key[9] == "-" && key[14] == "-"
    key.chars.each_with_index do |c, i|
      next if i == 0 || i == 4 || i == 9 || i == 14
      return false unless c =~ /\A[0-9a-zA-Z]\z/
    end
    true
  end
end
