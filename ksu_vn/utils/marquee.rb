module KSU::Quet
  def begin_drag(x, y)
    @arr19 = [x, y]
    @arr43 = [x, y]
    @flag20 = false
  end
  def started?
    !@arr19.nil?
  end
  def dragging?
    !!@flag20
  end
  def update_drag(x, y, view)
    return false unless @arr19
    @arr43 = [x, y]
    @flag20 ||= KSU::Quet.moved_enough?(@arr19, @arr43)
    view&.invalidate
    @flag20
  end
  def end_drag(x, y)
    return nil unless @arr19
    p_ref = @arr19
    p1 = [x, y]
    bbox = @flag20 || KSU::Quet.moved_enough?(p_ref, p1)
    reset
    return [:click, p_ref] unless bbox
    [:rect, KSU::Quet.rect(p_ref, p1), p1[0] >= p_ref[0]]
  end
  def reset
    @arr19 = nil
    @arr43 = nil
    @flag20 = false
  end
  def draw_rect(view)
    return unless @flag20 && @arr19 && @arr43
    KSU::View.draw_rect2d(view, @arr19[0], @arr19[1], @arr43[0], @arr43[1],
                                  stipple: @arr43[0] >= @arr19[0] ? "" : "-")
  end
  def self.moved_enough?(arr, b)
    (b[0] - arr[0]).abs >= 4 || (b[1] - arr[1]).abs >= 4
  end
  def self.rect(arr, b)
    [[arr[0], b[0]].min, [arr[1], b[1]].min, [arr[0], b[0]].max, [arr[1], b[1]].max]
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
    KSU::Geom.box_corners(bbox, tf).each do |segs_for_ray|
      return nil unless KSU::View.in_front?(segs_for_ray)
      pt0 = view.screen_coords(segs_for_ray)
      arr2 << pt0.x
      arr << pt0.y
    end
    [arr2.min, arr.min, arr2.max, arr.max]
  end
  def self.collect_in_rect(view, rect, strict, ents = nil, tf = nil, depth = 3, &_9ac40504)
    out = []
    (ents || Sketchup.active_model.active_entities).each do |grp|
      next unless grp.valid? && KSU.container?(grp)
      next unless grp.visible? && grp.layer.visible?
      tr = tf ? tf * grp.transformation : grp.transformation
      bx2 = screen_box(view, grp, tr)
      next if bx2 && !rect_hit?(bx2, rect, false)
      if _9ac40504.call(grp)
        out << grp if rect_hit?(bx2, rect, strict)
        next
      end
      next if depth <= 0
      kids = KSU.entities_in(grp)
      out.concat(collect_in_rect(view, rect, strict, kids, tr, depth - 1, &_9ac40504)) if kids
    end
    out
  end
end
