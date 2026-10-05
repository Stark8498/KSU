module KSU::Quet
  DRAG_PX = 4
  def begin_drag_v1(x, y)
    @arr2 = [x, y]
    @arr23 = [x, y]
    @flag = false
  end
  def started_v1?
    !@arr2.nil?
  end
  def dragging_v1?
    !!@flag
  end
  def update_drag_v1(x, y, view)
    return false unless @arr2
    @arr23 = [x, y]
    @flag ||= KSU::Quet.moved_enough_v1?(@arr2, @arr23)
    view&.invalidate
    @flag
  end
  def end_drag_v1(x, y)
    return nil unless @arr2
    p_ref = @arr2
    p1 = [x, y]
    bbox = @flag || KSU::Quet.moved_enough_v1?(p_ref, p1)
    reset_v1
    return [:click, p_ref] unless bbox
    [:rect, KSU::Quet.rect_v1(p_ref, p1), p1[0] >= p_ref[0]]
  end
  def reset_v1
    @arr2 = nil
    @arr23 = nil
    @flag = false
  end
  def draw_rect_v1(view)
    return unless @flag && @arr2 && @arr23
    KSU::View.draw_rect2d(view, @arr2[0], @arr2[1], @arr23[0], @arr23[1],
                                  stipple: @arr23[0] >= @arr2[0] ? "" : "-")
  end
  def self.moved_enough_v1?(v, b)
    (b[0] - v[0]).abs >= DRAG_PX || (b[1] - v[1]).abs >= DRAG_PX
  end
  def self.rect_v1(v, b)
    [[v[0], b[0]].min, [v[1], b[1]].min, [v[0], b[0]].max, [v[1], b[1]].max]
  end
  def self.rect_hit_v1?(screen_box_v1, rect_v1, strict)
    return false unless screen_box_v1
    if strict
      screen_box_v1[0] >= rect_v1[0] && screen_box_v1[2] <= rect_v1[2] && screen_box_v1[1] >= rect_v1[1] && screen_box_v1[3] <= rect_v1[3]
    else
      !(screen_box_v1[2] < rect_v1[0] || screen_box_v1[0] > rect_v1[2] || screen_box_v1[3] < rect_v1[1] || screen_box_v1[1] > rect_v1[3])
    end
  end
  def self.screen_box_v1(view, entity, tf)
    bbox = entity.respond_to?(:definition) && entity.definition ? entity.definition.bounds : entity.bounds
    return nil unless bbox && bbox.valid?
    arr = []
    arr2 = []
    (0..7).each do |i|
      pt = bbox.corner(i)
      pt = pt.transform(tf) if tf
      return nil unless KSU::View.in_front?(pt)
      pt2 = view.screen_coords(pt)
      arr << pt2.x
      arr2 << pt2.y
    end
    [arr.min, arr2.min, arr.max, arr2.max]
  end
  def self.collect_in_rect_v1(view, rect_v1, strict, ents = nil, tf = nil, lvl = 3, &match)
    out = []
    (ents || Sketchup.active_model.active_entities).each do |ent|
      next unless ent.valid? && KSU.container?(ent)
      next unless ent.visible? && ent.layer.visible?
      tr = tf ? tf * ent.transformation : ent.transformation
      bx2 = screen_box_v1(view, ent, tr)
      next if bx2 && !rect_hit_v1?(bx2, rect_v1, false)
      if match.call(ent)
        out << ent if rect_hit_v1?(bx2, rect_v1, strict)
        next
      end
      next if lvl <= 0
      kids = KSU.entities_in(ent)
      out.concat(collect_in_rect_v1(view, rect_v1, strict, kids, tr, lvl - 1, &match)) if kids
    end
    out
  end
end
