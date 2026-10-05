module KSU::Sheet
  def self.sheet?(entity)
    KSU.container?(entity) && entity.name.to_s.downcase.include?("sheet")
  end
  def self.sheet_list(nesting, include_bottom: false)
    sheets = []
    return sheets unless nesting && nesting.valid?
    tr = nesting.transformation
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      next if !include_bottom && bottom_sheet?(grp)
      transform = tr * grp.transformation
      bd2 = border_of(grp)
      if bd2 && bd2.respond_to?(:definition) && bd2.definition
        tr2 = transform * bd2.transformation
        _55774d63 = (0..7).map { |i| tr2 * bd2.definition.bounds.corner(i) }
      else
        _55774d63 = KSU::Geom.box_corners(grp.definition.bounds, transform)
      end
      box = Geom::BoundingBox.new
      _55774d63.each { |pt3| box.add(pt3) }
      sheets << {
        instance: grp, bbox: box, transform: transform,
        top_corners: [_55774d63[4], _55774d63[5], _55774d63[7], _55774d63[6]],
      }
    end
    sheets
  end
  def self.record_for(arr24, sheet)
    return nil unless arr24 && sheet
    arr24.find { |s| s[:instance] == sheet }
  end
  def self.row_of(sheet, arr24)
    normal = arr24.find { |s| s[:instance] == sheet }
    return [sheet] unless normal
    bbox = normal[:bbox]
    tol = [bbox.height * 0.5, 10.mm].max
    is_bottom = bottom_sheet?(sheet)
    arr24
      .select do |s|
      s[:instance].valid? &&
        (s[:bbox].center.y - bbox.center.y).abs <= tol &&
        bottom_sheet?(s[:instance]) == is_bottom
    end
      .sort_by { |s| s[:bbox].center.x }
      .map { |s| s[:instance] }
  end
  def self.row_offset(arr3, arr, ix, arr24)
    neighbor = if ix > 0
        arr[ix - 1]
      elsif ix < arr.length - 1
        arr[ix + 1]
      end
    if neighbor
      arr2 = arr24.find { |s| s[:instance] == neighbor }
      if arr2
        arr6 = arr3[:top_corners].map(&:x).min
        arr5 = arr2[:top_corners].map(&:x).min
        num = (arr6 - arr5).abs
        return Geom::Vector3d.new(num, 0, 0) if num > 1e-6
      end
    end
    arr4 = arr3[:top_corners].map(&:x)
    row_w = arr4.max - arr4.min
    Geom::Vector3d.new(row_w + 500.mm, 0, 0)
  end
  def self.dist_to_box(segs_for_ray, bbox)
    dx = [bbox.min.x - segs_for_ray.x, 0.0, segs_for_ray.x - bbox.max.x].max
    dy = [bbox.min.y - segs_for_ray.y, 0.0, segs_for_ray.y - bbox.max.y].max
    dz = [bbox.min.z - segs_for_ray.z, 0.0, segs_for_ray.z - bbox.max.z].max
    Math.sqrt(dx * dx + dy * dy + dz * dz)
  end
  def self.world_center(ent2, ents2, nesting)
    return nil unless ent2 && ent2.respond_to?(:bounds)
    segs_for_ray = ent2.bounds.center
    if nesting && nesting.valid? && ents2 == nesting.definition.entities
      return segs_for_ray.transform(nesting.transformation)
    end
    segs_for_ray
  end
  def self.to_point(at)
    return nil unless at
    case at
    when Geom::Point3d
      at
    when Array
      segs_for_ray = at.find { |fld| fld.is_a?(Geom::Point3d) }
      return nil unless segs_for_ray
      path = at[0]
      path.respond_to?(:transformation) ? segs_for_ray.transform(path.transformation) : segs_for_ray
    else
      return nil unless at.respond_to?(:position)
      box = at.position
      at.respond_to?(:transformation) ? box.transform(at.transformation) : box
    end
  end
  def self.offset_pair(pt2, pt, ents3, _71fbc725, nesting)
    if nesting && nesting.valid? && ents3 == nesting.definition.entities
      tr = nesting.transformation
      inv = tr.inverse
      a = pt2.transform(tr).offset(_71fbc725).transform(inv)
      _b57540e5 = pt.transform(tr).offset(_71fbc725).transform(inv)
    else
      a = pt2.offset(_71fbc725)
      _b57540e5 = pt.offset(_71fbc725)
    end
    [a, _b57540e5]
  end
  def self.shift_dims(arr, vec2, nesting)
    arr.each do |slot|
      ent2 = slot[:dim]
      next unless ent2 && ent2.valid?
      s = slot[:start_local]
      e = slot[:end_local]
      next unless s && e
      a, _b57540e5 = offset_pair(s, e, slot[:container], vec2, nesting)
      ent2.start = a if ent2.respond_to?(:start=)
      ent2.end = _b57540e5 if ent2.respond_to?(:end=)
    end
  end
  def self.style_dim(ent2)
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
  def self.set_dim_text(ent2, text)
    return unless ent2 && ent2.valid? && ent2.respond_to?(:text=)
    ent2.text = text
    style_dim(ent2)
  end
  def self.sheet_labels(vec, nesting)
    return [] unless vec && vec.valid? && nesting && nesting.valid?
    bbox = world_bbox(vec, nesting)
    return [] unless bbox
    ents = [nesting.definition.entities]
    model = Sketchup.active_model
    ents << model.entities if model
    ents.uniq!
    best = nil
    best_d3 = Float::INFINITY
    ents.each do |container|
      container.grep(Sketchup::DimensionLinear).each do |ent2|
        next if ent2.deleted? || !ent2.valid?
        segs_for_ray = world_center(ent2, container, nesting)
        next unless segs_for_ray
        len2d = dist_to_box(segs_for_ray, bbox)
        next unless len2d < best_d3
        s = to_point(ent2.start)
        pt = to_point(ent2.end)
        next unless s && pt
        best_d3 = len2d
        best = {
          dim: ent2,
          container: container,
          start_local: Geom::Point3d.new(s.x, s.y, s.z),
          end_local: Geom::Point3d.new(pt.x, pt.y, pt.z),
          offset_vector: ent2.respond_to?(:offset_vector) ? ent2.offset_vector : Geom::Vector3d.new(0, 0, 0),
        }
      end
    end
    best ? [best] : []
  end
end
require "digest"
module KSU::Sheet
  def self.id_hash(id2)
    Digest::SHA256.hexdigest(id2 + "7876emHzygZiMi0YlXCEdatbyp1gywyT2qjLdxfS").to_i(16) & 0x7FFFFFFF
  end
end
