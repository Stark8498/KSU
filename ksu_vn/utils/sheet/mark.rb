module KSU::Mark
  def mark?(entity)
    return false unless entity && entity.valid? && KSU.container?(entity)
    return true if entity.get_attribute("ABF", "is-mark-square")
    entity.name.to_s.include?("ABF_markSquare")
  end
  def marks_of(grp)
    return [] unless grp && grp.valid? && grp.respond_to?(:definition) && grp.definition
    grp.definition.entities.select { |e| mark?(e) }
  end
  def border_of(grp)
    return nil unless grp && grp.valid? && grp.respond_to?(:definition) && grp.definition
    grp.definition.entities.find { |grp2| KSU.container?(grp2) && grp2.name.to_s == "__ABF_sheetBorder" }
  end
  def border_polys(sheet)
    marks_of(sheet).map { |grp|
      next nil unless grp.respond_to?(:definition) && grp.definition
      lp = grp.definition.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq.first
      next nil unless lp
      pt = lp.vertices.map { |v| v.position.transform(grp.transformation) }
      pt.length >= 2 ? pt : nil
    }.compact
  end
  def mark_point(sheet)
    arr2 = border_polys(sheet)
    return nil if arr2.empty?
    arr = arr2.first
    min_x, hi_x = arr.map(&:x).minmax
    min_y, hi_y = arr.map(&:y).minmax
    w = hi_x - min_x
    elem = hi_y - min_y
    return nil if w < 1e-6 || elem < 1e-6
    z = arr.first.z.to_f
    scr = [[min_x, min_y], [hi_x, min_y], [hi_x, hi_y], [min_x, hi_y]]
    tol_x = w * 0.25
    tol_y = elem * 0.25
    arr3 = scr.map do |px, py|
      arr.any? { |pt| (pt.x - px).abs < tol_x && (pt.y - py).abs < tol_y }
    end
    free_ix = arr3.index(false)
    return nil unless free_ix
    bx2, by2 = scr[(free_ix + 2) % 4]
    Geom::Point3d.new(bx2, by2, z)
  end
  def mark_corner(grp, nesting = nil)
    pt = mark_point(grp)
    bd2 = border_of(grp)
    return nil unless pt && bd2
    if nesting && nesting.valid?
      bbox = world_bbox(grp, nesting)
      return nil unless bbox
      ccw = pt.transform(nesting.transformation * grp.transformation)
      mid = bbox.center
      return [ccw.x < mid.x ? :left : :right, ccw.y < mid.y ? :bottom : :top]
    end
    mid = bd2.bounds.center
    [pt.x < mid.x ? :left : :right, pt.y < mid.y ? :bottom : :top]
  end
  def corner_index(sheet, nesting = nil)
    start_x, ly0 = mark_corner(sheet, nesting)
    return nil unless start_x
    return 1 if start_x == :right && ly0 == :bottom
    return 2 if start_x == :right && ly0 == :top
    return 3 if start_x == :left && ly0 == :top
    0
  end
  def offset_for(_7b230ca9, nesting)
    bot = bottom_of(_7b230ca9, nesting)
    return nil unless bot && marks_of(bot).any?
    _821639ac, arr = inset_of(bot)
    return nil if _821639ac <= 0 && arr <= 0
    hside, vside = mark_corner(bot, nesting)
    return nil unless hside
    flag2 = (hside == :right) ? _821639ac : -_821639ac
    flag = (vside == :bottom) ? arr : -arr
    [flag2.to_f, flag.to_f]
  end
  def mirror_pos(bb2, bb, _821639ac, _98c3a7e0, hside, vside, eoff_x, eoff_y, px0, px1, py0, py1, part_w, part_h)
    lx0 = px0 - eoff_x
    lx1 = px1 - eoff_x
    lyy0 = py0 - eoff_y
    ly1 = py1 - eoff_y
    flag2 = (hside == :right) ? (lx0 - bb2.min.x) : (bb2.max.x - lx1)
    flag = (vside == :bottom) ? (lyy0 - bb2.min.y) : (bb2.max.y - ly1)
    num2 = (hside == :right) ? bb.max.x.to_f - _821639ac : bb.min.x.to_f + _821639ac
    num = (vside == :top) ? bb.max.y.to_f - _98c3a7e0 : bb.min.y.to_f + _98c3a7e0
    flag3 = (hside == :right) ? (num2 - flag2 - part_w) : (num2 + flag2)
    flag4 = (vside == :bottom) ? (num + flag) : (num - flag - part_h)
    [flag3, flag4]
  end
  def mirror_of_tf(tr0, grp, vec)
    return nil unless tr0 && grp && grp.valid? && vec && vec.valid?
    bd2 = border_of(grp)
    bbox = (bd2 && bd2.respond_to?(:bounds) && bd2.bounds.valid?) ? bd2.bounds : grp.definition.bounds
    px = (bbox.min.x.to_f + bbox.max.x.to_f) / 2.0
    pt = Geom::Transformation.rotation(Geom::Point3d.new(px, 0, 0), Geom::Vector3d.new(0, 1, 0), Math::PI)
    pt * tr0
  end
  def mirror_tf(grp, _7b230ca9, _774f7f26)
    return nil unless grp && grp.valid?
    mirror_of_tf(grp.transformation, _7b230ca9, _774f7f26)
  end
  def offset_polys(_7b230ca9, nesting)
    bot = bottom_of(_7b230ca9, nesting)
    return [] unless bot
    bd_front = border_of(_7b230ca9)
    bd_back = border_of(bot)
    return [] unless bd_front && bd_back
    bb = bd_front.bounds
    bb2 = bd_back.bounds
    border_polys(bot).map do |arr|
      arr.map do |pt|
        Geom::Point3d.new(bb.min.x + (bb2.max.x - pt.x), bb.min.y + (pt.y - bb2.min.y), bb.max.z)
      end
    end
  end
end
KSU::Sheet.extend(KSU::Mark)
