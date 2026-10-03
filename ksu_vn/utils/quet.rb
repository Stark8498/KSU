module KSU::Quet
  DRAG_PX = 4
  def begin_drag(x, y)
    @arr = [x, y]
    @arr22 = [x, y]
    @flag = false
  end
  def started?
    !@arr.nil?
  end
  def dragging?
    !!@flag
  end
  def update_drag(x, y, view)
    return false unless @arr
    @arr22 = [x, y]
    @flag ||= KSU::Quet.moved_enough?(@arr, @arr22)
    view&.invalidate
    @flag
  end
  def end_drag(x, y)
    return nil unless @arr
    p_ref = @arr
    p1 = [x, y]
    bbox = @flag || KSU::Quet.moved_enough?(p_ref, p1)
    reset
    return [:click, p_ref] unless bbox
    [:rect, KSU::Quet.rect(p_ref, p1), p1[0] >= p_ref[0]]
  end
  def reset
    @arr = nil
    @arr22 = nil
    @flag = false
  end
  def draw_rect(view)
    return unless @flag && @arr && @arr22
    KSU::View.draw_rect2d(view, @arr[0], @arr[1], @arr22[0], @arr22[1],
                                  stipple: @arr22[0] >= @arr[0] ? "" : "-")
  end
  def self.moved_enough?(arr2, b)
    (b[0] - arr2[0]).abs >= DRAG_PX || (b[1] - arr2[1]).abs >= DRAG_PX
  end
  def self.rect(arr2, b)
    [[arr2[0], b[0]].min, [arr2[1], b[1]].min, [arr2[0], b[0]].max, [arr2[1], b[1]].max]
  end
  def self.rect_hit?(screen_box, rect, strict)
    return false unless screen_box
    if strict
      screen_box[0] >= rect[0] && screen_box[2] <= rect[2] && screen_box[1] >= rect[1] && screen_box[3] <= rect[3]
    else
      !(screen_box[2] < rect[0] || screen_box[0] > rect[2] || screen_box[3] < rect[1] || screen_box[1] > rect[3])
    end
  end
  def self.screen_box(view, entity, tf)
    bbox = entity.respond_to?(:definition) && entity.definition ? entity.definition.bounds : entity.bounds
    return nil unless bbox && bbox.valid?
    arr2 = []
    arr = []
    (0..7).each do |_a4ab9a59|
      pt = bbox.corner(_a4ab9a59)
      pt = pt.transform(tf) if tf
      return nil unless KSU::View.in_front?(pt)
      pt2 = view.screen_coords(pt)
      arr2 << pt2.x
      arr << pt2.y
    end
    [arr2.min, arr.min, arr2.max, arr.max]
  end
  def self.collect_in_rect(view, rect, strict, ents = nil, tf = nil, depth = 3, &match)
    out = []
    (ents || Sketchup.active_model.active_entities).each do |ent|
      next unless ent.valid? && KSU.container?(ent)
      next unless ent.visible? && ent.layer.visible?
      tr = tf ? tf * ent.transformation : ent.transformation
      bx2 = screen_box(view, ent, tr)
      next if bx2 && !rect_hit?(bx2, rect, false)
      if match.call(ent)
        out << ent if rect_hit?(bx2, rect, strict)
        next
      end
      next if depth <= 0
      kids = KSU.entities_in(ent)
      out.concat(collect_in_rect(view, rect, strict, kids, tr, depth - 1, &match)) if kids
    end
    out
  end
end
