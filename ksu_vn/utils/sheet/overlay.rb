module KSU::Overlay
  def edit_offset(grp)
    return nil unless grp && grp.valid? && grp.respond_to?(:get_attribute)
    v = grp.get_attribute("KSU", "nest_edit_offset")
    return nil unless v.is_a?(Array) && v.length == 2
    [v[0].to_f, v[1].to_f]
  end
  def movable_kids(grp)
    return [] unless grp && grp.valid? && grp.respond_to?(:definition) && grp.definition
    grp.definition.entities.to_a.select do |ent|
      KSU.container?(ent) && ent.name.to_s != "__ABF_sheetBorder" && !_27ecfdd1(ent) && !mark?(ent)
    end
  end
  def apply_offsets(nesting)
    return unless nesting && nesting.valid?
    arr = []
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      next if hidden?(grp)
      next if edit_offset(grp)
      v = offset_for(grp, nesting)
      arr << [grp, v[0], v[1]] if v
    end
    return if arr.empty?
    KSU.start(false)
    arr.each do |grp, dx, dy|
      transform = Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, 0))
      movable_kids(grp).each { |ent| ent.transformation = transform * ent.transformation }
      grp.set_attribute("KSU", "nest_edit_offset", [dx, dy])
    end
    KSU.commit
  end
  def clear_offsets(nesting)
    return unless nesting && nesting.valid?
    arr = []
    nesting.definition.entities.each do |_73dc38ac|
      arr2 = edit_offset(_73dc38ac)
      arr << [_73dc38ac, arr2[0], arr2[1]] if arr2
    end
    return if arr.empty?
    KSU.start(false)
    arr.each do |_73dc38ac, _3e7613f3, _9ba1a361|
      transform = Geom::Transformation.translation(Geom::Vector3d.new(-_3e7613f3, -_9ba1a361, 0))
      movable_kids(_73dc38ac).each { |ent| ent.transformation = transform * ent.transformation }
      _73dc38ac.delete_attribute("KSU", "nest_edit_offset")
    end
    KSU.commit
  end
  def draw_borders(view, nesting)
    return unless view && nesting && nesting.valid?
    entries = entries_for(nesting)
    return if entries.empty?
    tr = nesting.transformation
    num = 0.2.mm
    flag = false
    entries.each do |ent|
      grp = ent[:sheet]
      next unless grp && grp.valid?
      unless flag
        view.line_stipple = ""
        view.line_width = KSU::View.edge_weight
        view.drawing_color = KSU::View.warning_color
        flag = true
      end
      tr7 = tr * grp.transformation
      ent[:polylines].each do |pts|
        transform = pts.map do |pt2|
          pt = pt2.transform(tr7)
          Geom::Point3d.new(pt.x, pt.y, pt.z + num)
        end
        view.draw(GL_LINE_STRIP, transform)
      end
    end
  end
  def entries_for(nesting)
    cache = @entries_cache
    return cache[:entries] if cache && cache[:nesting] == nesting
    @h13 ||= {}
    entries = []
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      if hidden?(grp)
        polylines = (@h13[grp.entityID] ||= border_polys(grp))
      else
        next unless edit_offset(grp)
        polylines = (@h13[grp.entityID] ||= offset_polys(grp, nesting))
      end
      next if polylines.empty?
      entries << { sheet: grp, polylines: polylines }
    end
    @entries_cache = { nesting: nesting, entries: entries }
    entries
  end
  def invalidate_cache
    @h13 = nil
    @entries_cache = nil
  end
  def inset_of(_73dc38ac, num = 3.mm)
    color = mark_point(_73dc38ac)
    bd2 = border_of(_73dc38ac)
    return [num, num] unless color && bd2 && bd2.bounds.valid?
    bbox = bd2.bounds
    num2 = [color.x - bbox.min.x, bbox.max.x - color.x].min
    num3 = [color.y - bbox.min.y, bbox.max.y - color.y].min
    num2 = num if num2 < 0
    num3 = num if num3 < 0
    [num2.to_f, num3.to_f]
  end
end
KSU::Sheet.extend(KSU::Overlay)
