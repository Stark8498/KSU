module KSU::Chuanhoa
  MAU_CANH_DAN = "60, 175, 214"
  MAU_CANH_CHAN = "210,117,159"
  def self.normalize_group(entity)
    ents = KSU.entities_in(entity)
    return 0 unless ents
    KSU::Cutting.unscale(entity)
    if ents.grep(Sketchup::Face).any?
      apply_face_materials(entity, ents)
      return 1
    end
    ents.select { |ent| KSU.container?(ent) }.inject(0) { |acc2, ent| acc2 + normalize_group(ent) }
  end
  def self.apply_face_materials(board, ents)
    colors = edge_band_colors(board, ents)
    ents.grep(Sketchup::Edge).each { |ent| ent.material = nil if ent.material }
    ents.grep(Sketchup::Face).each do |f|
      f.delete_attribute("ZSU", "an_mat_van")
      if colors.key?(f)
        mat = material_for(colors[f])
      elsif f.get_attribute("ZSU", "chan_dan_canh", false)
        mat = material_rgb(MAU_CANH_CHAN)
      else
        mat = nil
      end
      f.material = mat unless f.material == mat
      f.back_material = mat unless f.back_material == mat
      [true, false].each { |side| f.clear_texture_position(side) if f.texture_positioned?(side) } if f.respond_to?(:texture_positioned?)
    end
    norm_board(board)
  end
  def self.edge_band_colors(board, ents)
    arr = board.get_attribute("ABF", "edge-band-types")
    return {} unless arr.is_a?(Array)
    h = {}
    (0...(arr.size / 5)).each { |i| h[arr[i * 5]] = arr[i * 5 + 3] }
    colors = {}
    ents.grep(Sketchup::Face).each do |f|
      id = f.get_attribute("ABF", "edge-band-id")
      colors[f] = h[id] unless id.nil?
    end
    colors
  end
  def self.material_for(color)
    s = color.to_s.delete("#")
    rgb = s =~ /\A\h{6}\z/ ? [s[0, 2], s[2, 2], s[4, 2]].map { |num| num.to_i(16) }.join(", ") : MAU_CANH_DAN
    material_rgb(rgb)
  end
  def self.material_rgb(rgb)
    model = Sketchup.active_model
    name = "ZSU_#{rgb.gsub(',', "_")}_100"
    mat = model.materials[name]
    unless mat
      mat = model.materials.add(name)
      arr = rgb.split(",").map(&:to_i)
      mat.color = Sketchup::Color.new(arr[0], arr[1], arr[2])
      mat.alpha = 1.0
    end
    mat
  end
  def self.norm_board(node)
    return nil unless node && node.respond_to?(:definition)
    grp4 = node.definition
    container = grp4.entities
    snap_edges = container.grep(Sketchup::Edge)
    arr = KSU::Cutting.board_faces(node, IDENTITY)
    return nil if snap_edges.empty? || arr.nil?
    lbl = container.find { |ent| KSU.container?(ent) && (ent.get_attribute("ABF", "is-label") || ent.name == "_ABF_Label") }
    if lbl
      pt = lbl.transformation.xaxis
    else
      edge = snap_edges.max_by { |ent| ent.length }
      pt = edge.start.position.vector_to(edge.end.position)
    end
    transform = node.transformation
    ent = pt.transform(transform)
    pt2 = arr.max_by do |f|
      n = f.normal.transform(transform)
      [f.area.round(4), (n * ent).z.round(4), n.z.round(4), n.y.round(4), n.x.round(4)]
    end.normal
    dot = pt.dot(pt2)
    vec = Geom::Vector3d.new(
      pt.x - dot * pt2.x,
      pt.y - dot * pt2.y,
      pt.z - dot * pt2.z
    )
    vec = pt if vec.length < 0.001
    vec.normalize!
    vec2 = pt2.cross(vec)
    vec2.normalize!
    box2 = Geom::Transformation.axes(ORIGIN, vec, vec2, pt2)
    pt3 = snap_edges.flat_map(&:vertices).uniq.map { |v| v.position.transform(box2.inverse) }
    anchor = Geom::Point3d.new(pt3.map(&:x).min, pt3.map(&:y).min, pt3.map(&:z).min).transform(box2)
    tr = Geom::Transformation.axes(anchor, vec, vec2, pt2)
    container.transform_entities(tr.inverse, container.to_a)
    grp4.instances.each do |i|
      i.transformation *= tr
      mat = i.material
      i.material = nil
      i.material = mat
    end
    grp4.invalidate_bounds
  end
end
