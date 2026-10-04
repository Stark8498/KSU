module KSU::Mark
  def mark?(entity)
    return false unless entity && entity.valid? && KSU.container?(entity)
    return true if entity.get_attribute("ABF", "is-mark-square")
    entity.name.to_s.include?("ABF_markSquare")
  end
  def marks_of(sheet)
    return [] unless sheet && sheet.valid? && sheet.respond_to?(:definition) && sheet.definition
    sheet.definition.entities.select { |ent| mark?(ent) }
  end
  def border_of(sheet)
    return nil unless sheet && sheet.valid? && sheet.respond_to?(:definition) && sheet.definition
    sheet.definition.entities.find { |ent| KSU.container?(ent) && ent.name.to_s == "__ABF_sheetBorder" }
  end
  def border_polys(sheet)
    marks_of(sheet).map { |grp|
      next nil unless grp.respond_to?(:definition) && grp.definition
      lp = grp.definition.entities.grep(Sketchup::Edge).map(&:curve).compact.uniq.first
      next nil unless lp
      pts = lp.vertices.map { |v| v.position.transform(grp.transformation) }
      pts.length >= 2 ? pts : nil
    }.compact
  end
  def mark_point(sheet)
    arr3 = border_polys(sheet)
    return nil if arr3.empty?
    pts = arr3.first
    return nil if pts.length < 2
    min_x, arr = pts.map(&:x).minmax
    min_y, arr2 = pts.map(&:y).minmax
    w = arr - min_x
    h = arr2 - min_y
    return nil if w < 1e-6 || h < 1e-6
    z = pts.first.z.to_f
    scr = [[min_x, min_y], [arr, min_y], [arr, arr2], [min_x, arr2]]
    tol_x = w * 0.25
    _0cd9b30a = h * 0.25
    arr4 = scr.map do |px, py|
      pts.any? { |pt| (pt.x - px).abs < tol_x && (pt.y - py).abs < _0cd9b30a }
    end
    _a14aed83 = arr4.index(false)
    return nil unless _a14aed83
    bx2, by2 = scr[(_a14aed83 + 2) % 4]
    Geom::Point3d.new(bx2, by2, z)
  end
  def mark_corner(sheet, nesting = nil)
    color = mark_point(sheet)
    bd2 = border_of(sheet)
    return nil unless color && bd2
    if nesting && nesting.valid?
      bbox = world_bbox(sheet, nesting)
      return nil unless bbox
      ccw = color.transform(nesting.transformation * sheet.transformation)
      mid = bbox.center
      return [ccw.x < mid.x ? :left : :right, ccw.y < mid.y ? :bottom : :top]
    end
    mid = bd2.bounds.center
    [color.x < mid.x ? :left : :right, color.y < mid.y ? :bottom : :top]
  end
  def corner_index(sheet, nesting = nil)
    start_x, ly0 = mark_corner(sheet, nesting)
    return nil unless start_x
    return 1 if start_x == :right && ly0 == :bottom
    return 2 if start_x == :right && ly0 == :top
    return 3 if start_x == :left && ly0 == :top
    0
  end
  def offset_for(sheet, nesting)
    bot = bottom_of(sheet, nesting)
    return nil unless bot && marks_of(bot).any?
    _3e7613f3, arr = inset_of(bot)
    return nil if _3e7613f3 <= 0 && arr <= 0
    hside, vside = mark_corner(bot, nesting)
    return nil unless hside
    flag2 = (hside == :right) ? :left : :right
    dx = (flag2 == :left) ? _3e7613f3 : -_3e7613f3
    dy = (vside == :bottom) ? arr : -arr
    [dx.to_f, dy.to_f]
  end
  def _5134c34c(bb2, bb, _3e7613f3, _9ba1a361, hside, vside, _7bb0b74c, _5e0b9d0f, _16d547ab, _740b67b8, _08bd07cc, _29b02ee7, _e9f5ddbc, _1aa82cff)
    _18feedaf = _16d547ab - _7bb0b74c
    _331de21b = _740b67b8 - _7bb0b74c
    _ce465202 = _08bd07cc - _5e0b9d0f
    _93bc3b1a = _29b02ee7 - _5e0b9d0f
    flag5 = (hside == :right) ? :left : :right
    flag2 = (flag5 == :left) ? (_18feedaf - bb2.min.x) : (bb2.max.x - _331de21b)
    flag = (vside == :bottom) ? (_ce465202 - bb2.min.y) : (bb2.max.y - _93bc3b1a)
    num = (hside == :right) ? bb.max.x.to_f - _3e7613f3 : bb.min.x.to_f + _3e7613f3
    num2 = (vside == :top) ? bb.max.y.to_f - _9ba1a361 : bb.min.y.to_f + _9ba1a361
    flag4 = (hside == :right) ? (num - flag2 - _e9f5ddbc) : (num + flag2)
    flag3 = (vside == :bottom) ? (num2 + flag) : (num2 - flag - _1aa82cff)
    [flag4, flag3]
  end
  def _1c44e717(_f4e85c51, sheet, tr)
    return nil unless _f4e85c51 && sheet && sheet.valid? && tr && tr.valid?
    bd2 = border_of(sheet)
    bbox = (bd2 && bd2.respond_to?(:bounds) && bd2.bounds.valid?) ? bd2.bounds : sheet.definition.bounds
    px = (bbox.min.x.to_f + bbox.max.x.to_f) / 2.0
    pt = Geom::Transformation.rotation(Geom::Point3d.new(px, 0, 0), Geom::Vector3d.new(0, 1, 0), Math::PI)
    pt * _f4e85c51
  end
  def mirror_tf(panel, sheet, tr)
    return nil unless panel && panel.valid?
    _1c44e717(panel.transformation, sheet, tr)
  end
  def offset_polys(sheet, nesting)
    bot = bottom_of(sheet, nesting)
    return [] unless bot
    _bd796177 = border_of(sheet)
    _7e85d3e0 = border_of(bot)
    return [] unless _bd796177 && _7e85d3e0
    bb = _bd796177.bounds
    bb2 = _7e85d3e0.bounds
    border_polys(bot).map do |pts|
      pts.map do |pt|
        Geom::Point3d.new(bb.min.x + (bb2.max.x - pt.x), bb.min.y + (pt.y - bb2.min.y), bb.max.z)
      end
    end
  end
end
KSU::Sheet.extend(KSU::Mark)
