module KSU::Sheet
  def self.sheet?(entity)
    KSU.container?(entity) && entity.name.to_s.downcase.include?("sheet")
  end
  def self.sheet_list(nesting, include_bottom: false)
    sheets = []
    return sheets unless nesting && nesting.valid?
    tr = nesting.transformation
    nesting.definition.entities.each do |sheet|
      next unless sheet.respond_to?(:name) && sheet.name.to_s.downcase.include?("sheet")
      next if !include_bottom && bottom_sheet?(sheet)
      transform = tr * sheet.transformation
      bd2 = border_of(sheet)
      if bd2 && bd2.respond_to?(:definition) && bd2.definition
        tr6 = transform * bd2.transformation
        arr = (0..7).map { |i| tr6 * bd2.definition.bounds.corner(i) }
      else
        bb = sheet.definition.bounds
        arr = (0..7).map { |i| bb.corner(i).transform(transform) }
      end
      box = Geom::BoundingBox.new
      arr.each { |_23505ef9| box.add(_23505ef9) }
      sheets << {
        instance: sheet, bbox: box, transform: transform,
        top_corners: [arr[4], arr[5], arr[7], arr[6]],
      }
    end
    sheets
  end
  def self.record_for(arr23, sheet)
    return nil unless arr23 && sheet
    arr23.find { |s| s[:instance] == sheet }
  end
  def self.row_of(sheet, arr23)
    normal = arr23.find { |s| s[:instance] == sheet }
    return [sheet] unless normal
    bbox = normal[:bbox]
    tol = [bbox.height * 0.5, 10.mm].max
    is_bottom = bottom_sheet?(sheet)
    arr23
      .select do |s|
      s[:instance].valid? &&
        (s[:bbox].center.y - bbox.center.y).abs <= tol &&
        bottom_sheet?(s[:instance]) == is_bottom
    end
      .sort_by { |s| s[:bbox].center.x }
      .map { |s| s[:instance] }
  end
  def self.row_offset(arr2, arr, ix, arr23)
    neighbor = if ix > 0
        arr[ix - 1]
      elsif ix < arr.length - 1
        arr[ix + 1]
      end
    if neighbor
      arr4 = arr23.find { |s| s[:instance] == neighbor }
      if arr4
        arr6 = arr2[:top_corners].map(&:x).min
        arr5 = arr4[:top_corners].map(&:x).min
        num = (arr6 - arr5).abs
        return Geom::Vector3d.new(num, 0, 0) if num > 1e-6
      end
    end
    arr3 = arr2[:top_corners].map(&:x)
    row_w = arr3.max - arr3.min
    Geom::Vector3d.new(row_w + 500.mm, 0, 0)
  end
  def self.dist_to_box(pt, bbox)
    dx = [bbox.min.x - pt.x, 0.0, pt.x - bbox.max.x].max
    dy = [bbox.min.y - pt.y, 0.0, pt.y - bbox.max.y].max
    dz = [bbox.min.z - pt.z, 0.0, pt.z - bbox.max.z].max
    Math.sqrt(dx * dx + dy * dy + dz * dz)
  end
  def self.world_center(ent2, ents2, nesting)
    return nil unless ent2 && ent2.respond_to?(:bounds)
    pt = ent2.bounds.center
    if nesting && nesting.valid? && ents2 == nesting.definition.entities
      return pt.transform(nesting.transformation)
    end
    pt
  end
  def self.to_point(arr)
    return nil unless arr
    case arr
    when Geom::Point3d
      arr
    when Array
      pt = arr.find { |fld| fld.is_a?(Geom::Point3d) }
      return nil unless pt
      path = arr[0]
      path.respond_to?(:transformation) ? pt.transform(path.transformation) : pt
    else
      return nil unless arr.respond_to?(:position)
      box = arr.position
      arr.respond_to?(:transformation) ? box.transform(arr.transformation) : box
    end
  end
  def self.offset_pair(pt2, pt, ents3, vec, nesting)
    if nesting && nesting.valid? && ents3 == nesting.definition.entities
      tr = nesting.transformation
      inv = tr.inverse
      a = pt2.transform(tr).offset(vec).transform(inv)
      b = pt.transform(tr).offset(vec).transform(inv)
    else
      a = pt2.offset(vec)
      b = pt.offset(vec)
    end
    [a, b]
  end
  def self.shift_dims(arr, vec2, nesting)
    arr.each do |slot|
      ent2 = slot[:dim]
      next unless ent2 && ent2.valid?
      s = slot[:start_local]
      ent = slot[:end_local]
      next unless s && ent
      a, b = offset_pair(s, ent, slot[:container], vec2, nesting)
      ent2.start = a if ent2.respond_to?(:start=)
      ent2.end = b if ent2.respond_to?(:end=)
    end
  end
  def self._9728a3d1(ent2)
    return unless ent2 && ent2.valid?
    begin
      ent2.has_aligned_text = true if ent2.respond_to?(:has_aligned_text=)
      if ent2.respond_to?(:aligned_text_position=)
        ent2.aligned_text_position = Sketchup::DimensionLinear::ALIGNED_TEXT_OUTSIDE
      end
    rescue StandardError
      nil
    end
  end
  def self._ba804f88(ent2, text)
    return unless ent2 && ent2.valid? && ent2.respond_to?(:text=)
    ent2.text = text
    _9728a3d1(ent2)
  end
  def self.sheet_labels(sheet, nesting)
    return [] unless sheet && sheet.valid? && nesting && nesting.valid?
    bbox = world_bbox(sheet, nesting)
    return [] unless bbox
    ents = [nesting.definition.entities]
    model = Sketchup.active_model
    ents << model.entities if model
    ents.uniq!
    _477c927d = nil
    _f84bb2e3 = Float::INFINITY
    ents.each do |container|
      container.grep(Sketchup::DimensionLinear).each do |ent2|
        next if ent2.deleted? || !ent2.valid?
        pt = world_center(ent2, container, nesting)
        next unless pt
        len2d = dist_to_box(pt, bbox)
        next unless len2d < _f84bb2e3
        s = to_point(ent2.start)
        ent = to_point(ent2.end)
        next unless s && ent
        _f84bb2e3 = len2d
        _477c927d = {
          dim: ent2,
          container: container,
          start_local: Geom::Point3d.new(s.x, s.y, s.z),
          end_local: Geom::Point3d.new(ent.x, ent.y, ent.z),
          offset_vector: ent2.respond_to?(:offset_vector) ? ent2.offset_vector : Geom::Vector3d.new(0, 0, 0),
        }
      end
    end
    _477c927d ? [_477c927d] : []
  end
end
require "digest"
module KSU::Sheet
  def self._b98c616b(_af9dd713)
    Digest::SHA256.hexdigest(_af9dd713 + "7876emHzygZiMi0YlXCEdatbyp1gywyT2qjLdxfS").to_i(16) & 0x7FFFFFFF
  end
end
