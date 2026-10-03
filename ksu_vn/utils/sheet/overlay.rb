module KSU::Overlay
  def edit_offset(sheet)
    return nil unless sheet && sheet.valid? && sheet.respond_to?(:get_attribute)
    v = sheet.get_attribute("KSU", "nest_edit_offset")
    return nil unless v.is_a?(Array) && v.length == 2
    [v[0].to_f, v[1].to_f]
  end
  def movable_kids(sheet)
    return [] unless sheet && sheet.valid? && sheet.respond_to?(:definition) && sheet.definition
    sheet.definition.entities.to_a.select do |ent|
      KSU.container?(ent) && ent.name.to_s != "__ABF_sheetBorder" && !sheet_border?(ent) && !mark?(ent)
    end
  end
  def apply_offsets(nesting)
    return unless nesting && nesting.valid?
    arr = []
    nesting.definition.entities.each do |sheet|
      next unless sheet.respond_to?(:name) && sheet.name.to_s.downcase.include?("sheet")
      next if hidden?(sheet)
      next if edit_offset(sheet)
      v = offset_for(sheet, nesting)
      arr << [sheet, v[0], v[1]] if v
    end
    return if arr.empty?
    KSU.start(false)
    arr.each do |sheet, dx, dy|
      transform = Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, 0))
      movable_kids(sheet).each { |ent| ent.transformation = transform * ent.transformation }
      sheet.set_attribute("KSU", "nest_edit_offset", [dx, dy])
    end
    KSU.commit
  end
  def clear_offsets(nesting)
    return unless nesting && nesting.valid?
    arr = []
    nesting.definition.entities.each do |sheet|
      arr2 = edit_offset(sheet)
      arr << [sheet, arr2[0], arr2[1]] if arr2
    end
    return if arr.empty?
    KSU.start(false)
    arr.each do |sheet, _3e7613f3, _9ba1a361|
      transform = Geom::Transformation.translation(Geom::Vector3d.new(-_3e7613f3, -_9ba1a361, 0))
      movable_kids(sheet).each { |ent| ent.transformation = transform * ent.transformation }
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
    flag = false
    entries.each do |ent|
      sheet = ent[:sheet]
      next unless sheet && sheet.valid?
      unless flag
        view.line_stipple = ""
        view.line_width = KSU::View.edge_weight
        view.drawing_color = KSU::View.warning_color
        flag = true
      end
      tr7 = tr * sheet.transformation
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
    nesting.definition.entities.each do |sheet|
      next unless sheet.respond_to?(:name) && sheet.name.to_s.downcase.include?("sheet")
      if hidden?(sheet)
        polylines = (@h13[sheet.entityID] ||= border_polys(sheet))
      else
        next unless edit_offset(sheet)
        polylines = (@h13[sheet.entityID] ||= offset_polys(sheet, nesting))
      end
      next if polylines.empty?
      entries << { sheet: sheet, polylines: polylines }
    end
    @entries_cache = { nesting: nesting, entries: entries }
    entries
  end
  def invalidate_cache
    @h13 = nil
    @entries_cache = nil
  end
  def inset_of(sheet, num = 3.mm)
    color = mark_point(sheet)
    bd2 = border_of(sheet)
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
