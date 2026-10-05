module KSU::Chuanhoa
  def self.normalize_group(entity)
    ents = KSU.entities_in(entity)
    return 0 unless ents
    KSU::Cutting.unscale(entity)
    if ents.grep(Sketchup::Face).any?
      apply_face_materials(entity, ents)
      return 1
    end
    ents.select { |e| KSU.container?(e) }.inject(0) { |acc2, e| acc2 + normalize_group(e) }
  end
  def self.apply_face_materials(board, ents)
    colors = edge_band_colors(board, ents)
    ents.grep(Sketchup::Edge).each { |face| face.material = nil if face.material }
    ents.grep(Sketchup::Face).each do |f|
      f.delete_attribute("ZSU", "an_mat_van")
      mat = if colors.key?(f)
                 material_for(colors[f])
               elsif f.get_attribute("ZSU", "chan_dan_canh", false)
                 material_rgb("210,117,159")
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
    rgb = s =~ /\A\h{6}\z/ ? [s[0, 2], s[2, 2], s[4, 2]].map { |num| num.to_i(16) }.join(", ") : "60, 175, 214"
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
  def self.norm_board(grp2)
    return nil unless grp2 && grp2.respond_to?(:definition)
    grp3 = grp2.definition
    container = grp3.entities
    snap_edges = container.grep(Sketchup::Edge)
    arr = KSU::Cutting.board_faces(grp2, IDENTITY)
    return nil if snap_edges.empty? || arr.nil?
    lbl = container.find { |grp| KSU.container?(grp) && (grp.get_attribute("ABF", "is-label") || grp.name == "_ABF_Label") }
    if lbl
      ref_dir = lbl.transformation.xaxis
    else
      edge = snap_edges.max_by { |grp| grp.length }
      ref_dir = edge.start.position.vector_to(edge.end.position)
    end
    tr2 = grp2.transformation
    grp = ref_dir.transform(tr2)
    normal = arr.max_by do |f|
      n = f.normal.transform(tr2)
      [f.area.round(4), (n * grp).z.round(4), n.z.round(4), n.y.round(4), n.x.round(4)]
    end.normal
    dot = ref_dir.dot(normal)
    vec = Geom::Vector3d.new(
      ref_dir.x - dot * normal.x,
      ref_dir.y - dot * normal.y,
      ref_dir.z - dot * normal.z
    )
    vec = ref_dir if vec.length < 0.001
    vec.normalize!
    vec2 = normal.cross(vec)
    vec2.normalize!
    box2 = Geom::Transformation.axes(ORIGIN, vec, vec2, normal)
    failed = snap_edges.flat_map(&:vertices).uniq.map { |v| v.position.transform(box2.inverse) }
    anchor = Geom::Point3d.new(failed.map(&:x).min, failed.map(&:y).min, failed.map(&:z).min).transform(box2)
    tr = Geom::Transformation.axes(anchor, vec, vec2, normal)
    container.transform_entities(tr.inverse, container.to_a)
    grp3.instances.each do |i|
      i.transformation *= tr
      mat = i.material
      i.material = nil
      i.material = mat
    end
    grp3.invalidate_bounds
  end
end
