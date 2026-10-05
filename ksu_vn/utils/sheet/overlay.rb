module KSU::Overlay
  def edit_offset(grp)
    return nil unless grp && grp.valid? && grp.respond_to?(:get_attribute)
    v = grp.get_attribute("KSU", "nest_edit_offset")
    return nil unless v.is_a?(Array) && v.length == 2
    [v[0].to_f, v[1].to_f]
  end
  def movable_kids(grp)
    return [] unless grp && grp.valid? && grp.respond_to?(:definition) && grp.definition
    grp.definition.entities.to_a.select do |grp2|
      KSU.container?(grp2) && grp2.name.to_s != "__ABF_sheetBorder" && !sheet_border?(grp2) && !mark?(grp2)
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
    arr.each do |grp, _fbf0cf8d, _7e1c7e1d|
      vec = Geom::Transformation.translation(Geom::Vector3d.new(_fbf0cf8d, _7e1c7e1d, 0))
      movable_kids(grp).each { |grp2| grp2.transformation = vec * grp2.transformation }
      grp.set_attribute("KSU", "nest_edit_offset", [_fbf0cf8d, _7e1c7e1d])
    end
    KSU.commit
  end
  def clear_offsets(nesting)
    return unless nesting && nesting.valid?
    arr2 = []
    nesting.definition.entities.each do |sheet|
      table_off = edit_offset(sheet)
      arr2 << [sheet, table_off[0], table_off[1]] if table_off
    end
    return if arr2.empty?
    KSU.start(false)
    arr2.each do |sheet, _821639ac, _98c3a7e0|
      vec = Geom::Transformation.translation(Geom::Vector3d.new(-_821639ac, -_98c3a7e0, 0))
      movable_kids(sheet).each { |grp| grp.transformation = vec * grp.transformation }
      sheet.delete_attribute("KSU", "nest_edit_offset")
    end
    KSU.commit
  end
  def draw_borders(view, nesting)
    return unless view && nesting && nesting.valid?
    entries = entries_for(nesting)
    return if entries.empty?
    tr = nesting.transformation
    num = 0.2.mm
    arr26 = false
    entries.each do |arr|
      grp = arr[:sheet]
      next unless grp && grp.valid?
      unless arr26
        view.line_stipple = ""
        view.line_width = KSU::View.edge_weight
        view.drawing_color = KSU::View.warning_color
        arr26 = true
      end
      tr2 = tr * grp.transformation
      arr[:polylines].each do |arr2|
        arr3 = arr2.map do |pt2|
          pt = pt2.transform(tr2)
          Geom::Point3d.new(pt.x, pt.y, pt.z + num)
        end
        view.draw(GL_LINE_STRIP, arr3)
      end
    end
  end
  def entries_for(nesting)
    cache = @entries_cache
    return cache[:entries] if cache && cache[:nesting] == nesting
    @h3 ||= {}
    entries = []
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      if hidden?(grp)
        polylines = (@h3[grp.entityID] ||= border_polys(grp))
      else
        next unless edit_offset(grp)
        polylines = (@h3[grp.entityID] ||= offset_polys(grp, nesting))
      end
      next if polylines.empty?
      entries << { sheet: grp, polylines: polylines }
    end
    @entries_cache = { nesting: nesting, entries: entries }
    entries
  end
  def invalidate_cache
    @h3 = nil
    @entries_cache = nil
  end
  def inset_of(sheet, fallback = 3.mm)
    pt = mark_point(sheet)
    bd2 = border_of(sheet)
    return [fallback, fallback] unless pt && bd2 && bd2.bounds.valid?
    bbox = bd2.bounds
    num = [pt.x - bbox.min.x, bbox.max.x - pt.x].min
    num2 = [pt.y - bbox.min.y, bbox.max.y - pt.y].min
    num = fallback if num < 0
    num2 = fallback if num2 < 0
    [num.to_f, num2.to_f]
  end
end
KSU::Sheet.extend(KSU::Overlay)
