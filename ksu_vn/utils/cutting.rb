module KSU::Cutting
  def self.bottom_face?(panel)
    return false unless panel && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def self.layer(name)
    model = Sketchup.active_model
    model.layers[name] || model.layers.add(name)
  end
  def self.set_layer(entity, tag)
    return unless entity && entity.valid? && tag
    entity.layer = tag if entity.respond_to?(:layer=)
    return unless KSU.container?(entity)
    ents = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
    ents.each { |color| set_layer(color, tag) }
  end
  def self.label_of(panel)
    ents = KSU.entities_in(panel)
    return nil unless ents
    ents.to_a.find do |ent|
      next false unless KSU.container?(ent) && ent.valid?
      str = ent.name.to_s
      def_name = (ent.respond_to?(:definition) && ent.definition) ? ent.definition.name.to_s : ""
      str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    end
  end
  def self.label_rect(ents)
    seen = {}
    arr = []
    ents.to_a.each do |ent|
      next unless ent.is_a?(Sketchup::Edge) && ent.valid?
      lp = ent.curve
      next unless lp && lp.valid?
      next if seen[lp.entityID]
      seen[lp.entityID] = true
      arr << lp if lp.respond_to?(:count_edges) && lp.count_edges == 4
    end
    return nil if arr.empty?
    return arr.first if arr.length == 1
    arr.max_by { |color| area(color.vertices.map(&:position)).abs }
  end
  def self.label_pts(panel, tf)
    return nil unless panel && panel.valid?
    lbl = label_of(panel)
    return nil unless lbl && lbl.valid? && lbl.respond_to?(:definition) && lbl.definition
    box2 = label_rect(lbl.definition.entities)
    return nil unless box2
    tr = tf * lbl.transformation
    pts = box2.vertices.map { |v| v.position.transform(tr) }
    pts.pop if pts.length >= 2 && pts.first.distance(pts.last).to_f < 1e-6
    pts.length >= 3 ? pts : nil
  end
  def self.largest_face(src, arr, skip1 = nil, skip2 = nil, skip3 = nil)
    best = nil
    src.each_with_index do |f, i|
      next if f == skip1 || f == skip2 || f == skip3
      best = [f, arr[i]] if best.nil? || arr[i] > best[1]
    end
    best
  end
  def self.board_faces(g, tf)
    src = (KSU.entities_in(g) || []).grep(Sketchup::Face)
    return nil if src.length < 2
    arr = src.map { |f| f.area(tf) }
    face, a1 = largest_face(src, arr)
    face2, a2 = largest_face(src, arr, face)
    return nil unless face && face2
    vec2 = face.normal.transform(tf)
    vec4 = face2.normal.transform(tf)
    if vec2.parallel?(vec4)
      return nil unless (a1 - a2).abs < 0.001
      [face, face2]
    else
      return nil if src.length < 4
      face3, a3 = largest_face(src, arr, face, face2)
      face4, a4 = largest_face(src, arr, face, face2, face3)
      return nil unless face3 && face4
      vec = face3.normal.transform(tf)
      vec3 = face4.normal.transform(tf)
      return nil unless vec.parallel?(vec3) && (a3 - a4).abs < 0.001
      [face3, face4]
    end
  end
  def self.face_with(g, attr)
    src = (KSU.entities_in(g) || []).grep(Sketchup::Face).select { |f| f.get_attribute("ABF", attr) }
    src[0] if src.length > 0
  end
  def self.kids_with_attr(g, attr)
    ents = KSU.entities_in(g)
    return nil unless ents
    arr = ents.select { |ent| KSU.container?(ent) && ent.get_attribute("ABF", attr, false) }
    arr.empty? ? nil : arr
  end
  def self.front_face(g, b2)
    labeled = face_with(g, "is-labeled-face")
    label_kids = kids_with_attr(g, "is-label")
    flag = (labeled && label_kids) ? labeled : nil
    flag ||= face_with(g, "is-cnced-face")
    flag ||= b2[0]
    flag
  end
  def self.edgeband_meta(g)
    out = {}
    arr = g.get_attribute("ZSU", "thuoc_tinh_dan_canh")
    arr = g.get_attribute("ZSU", "dan_canh_meta") unless arr.is_a?(Array)
    return out unless arr.is_a?(Array)
    (0...(arr.size / 4)).each do |i|
      num2 = arr[i * 4 + 2].to_i
      b = arr[i * 4 + 3].to_i
      out[arr[i * 4]] = if num2 == 2
        [arr[i * 4 + 1].to_s, false, false, b == 1]
      else
        [arr[i * 4 + 1].to_s, num2 == 1, b == 1, true]
      end
    end
    out
  end
  def self.material_for(g)
    g.material ? g.material.display_name.to_s : ""
  end
  def self.board_thickness(g)
    tf = tf_of(g)
    b2 = board_faces(g, tf)
    return nil unless b2
    bb = b2[0].bounds.center.transform(tf)
    bb2 = b2[1].bounds.center.transform(tf)
    bb.distance_to_plane([bb2, b2[0].normal.transform(tf)]).to_f * 25.4
  rescue StandardError
    nil
  end
  def self.edgeband_row(arr, name, mat, thickness, disp)
    return [name.to_s, "", "", disp] unless arr
    [arr[0].to_s,
     arr[1] ? mat.to_s : "",
     arr[2] && thickness ? format("%.1f", thickness) : "",
     disp]
  end
  def self.separator
    s = KSU::Settings.get("ngan_cach", "-", "in_tem").to_s.strip[0, 1].to_s
    s.empty? ? " " : " #{s} "
  end
  def self.display_name(fields, str = " - ")
    head_off = fields[0, 3].reject { |s| s.to_s.empty? }.join(str)
    (head_off.empty? ? "" : head_off + str) + fields[3].to_s + "mm"
  end
  def self.edgeband_list(g)
    arr = g.get_attribute("ABF", "edge-band-types")
    return [] unless arr.is_a?(Array) && arr.size >= 5
    arr2 = edgeband_meta(g)
    return [] if arr2.empty?
    mat = material_for(g)
    thick_mm = board_thickness(g)
    out = []
    (0...arr.size / 5).each do |i|
      meta = arr2[arr[i * 5]]
      next unless meta
      thickness = arr[i * 5 + 2].to_f
      str = thickness > thickness.to_i ? thickness.to_s : thickness.to_i.to_s
      out << edgeband_row(meta, arr[i * 5 + 1].to_s, mat, thick_mm, str)
    end
    out
  end
  def self.edgeband_spec(g, thick_mm = nil)
    arr2 = g.get_attribute("ABF", "edge-band-types")
    return [[], 0.1.mm] unless arr2
    arr3 = edgeband_meta(g)
    mat = material_for(g)
    flag = thick_mm || (arr3.empty? ? nil : board_thickness(g))
    _419b7d17 = separator
    h = {}
    (0...arr2.size / 5).each do |i|
      id = arr2[i * 5]
      name = arr2[i * 5 + 1].to_s
      thickness = arr2[i * 5 + 2].to_f
      str = thickness > thickness.to_i ? thickness.to_s : thickness.to_i.to_s
      fields = edgeband_row(arr3[id], name, mat, flag, str)
      stat = arr3[id] ? arr3[id][3] != false : true
      h[id] = { thickness: thickness / 25.4, display_name: display_name(fields, _419b7d17), fields: fields, stat: stat }
    end
    src = []
    hi = 0.1.mm
    (KSU.entities_in(g) || []).grep(Sketchup::Face).each do |f|
      id = f.get_attribute("ABF", "edge-band-id")
      next unless id
      thick = h[id]
      next unless thick
      src << [f, thick[:thickness], thick[:display_name], thick[:fields], thick[:stat], f.get_attribute("ZSU", "loai_canh").to_s]
      hi = [hi, thick[:thickness]].max
    end
    [src, hi]
  end
  def self.arrow_sizes(small_size)
    num2 = 6.5
    num = 9
    if small_size > 5.cm
      num2 = 6.5 + (small_size - 5.cm)
      num = 8
    end
    if small_size > 10.cm
      num2 = 8.5 + ((small_size - 10.cm) / 1.5)
      num = 7
    end
    if small_size > 20.cm
      num2 = 10 + ((small_size - 20.cm) / 2.5)
      num = 6
    end
    if small_size > 40.cm
      num2 = 13 + ((small_size - 40.cm) / 3.5)
      num = 5
    end
    if small_size > 80.cm
      num2 = 17
      num = 4
    end
    _05045e96 = small_size / num2
    num3 = 15.mm * Math.sqrt(3) / 2
    _05045e96 = num3 if _05045e96 > num3
    [_05045e96, _05045e96 / num]
  end
  def self.box_axes(bnds, tf)
    p_ref = bnds.corner(0).transform(tf)
    [1, 2, 4].map { |i|
      pt = bnds.corner(i).transform(tf)
      [p_ref.distance(pt), p_ref.vector_to(pt)]
    }.sort_by { |arr| arr[0] }
  end
  def self.short_side(font, tf)
    face_size(font, tf)[1]
  end
  def self.cut_loops(g, up_face, tf, edgeband_spec, arrow_size, arrow_padding)
    loops = []
    edge_band_lines = []
    edge_band_desc = []
    vec2 = up_face.normal.transform(tf)
    if edgeband_spec.length > 0
      arr3 = []
      up_face.loops.each do |face|
        count_by_length = []
        h = {}
        h2 = {}
        face.edges.each do |ent|
          if ent.curve
            h2[ent.curve.entityID] = ent.curve
          else
            h[ent.entityID] = true
          end
        end
        h2.each_value { |color| h[color.edges[color.edges.size / 2].entityID] = true }
        face.edges.each do |ent|
          axis = [ent.line[0].transform(tf), ent.line[1].transform(tf)]
          num = ent.length(tf)
          num *= ent.curve.edges.size if ent.curve
          edgeband_spec.each do |rec|
            font = rec[0]
            vec = font.normal.transform(tf)
            thickness = rec[1]
            next unless ent.used_by?(font)
            axis[0] = axis[0].offset(vec, -thickness)
            next unless h.key?(ent.entityID)
            p_next = ent.start.position.transform(tf) + ent.end.position.transform(tf).to_a
            p_next.set!(p_next.x / 2, p_next.y / 2, p_next.z / 2)
            p_ref = p_next.offset!(vec, -thickness - arrow_padding)
            pp_vec = vec.cross(vec2)
            next unless pp_vec.length.to_f > 0.0
            arr3 << { p0: p_ref, vec: vec, pp_vec: pp_vec, size: [arrow_size, num / 2].min }
            edge_band_desc << { p0: p_next, p1: p_next.offset(vec, 1), name: rec[2], fields: rec[3], kind: rec[5] }
          end
          count_by_length << axis
        end
        next if count_by_length.empty?
        out = []
        (0...count_by_length.length - 1).each do |i|
          _9ba5a7e0 = Geom.intersect_line_line(count_by_length[i], count_by_length[i + 1])
          out << _9ba5a7e0 if _9ba5a7e0
        end
        _d28e4f82 = Geom.intersect_line_line(count_by_length[-1], count_by_length[0])
        if _d28e4f82
          out << _d28e4f82
        elsif !count_by_length[-1][1].parallel?(count_by_length[0][1])
          next
        end
        next if out.length < 3
        out << out[0]
        loops << { pts: out.map { |pt2| Geom::Point3d.new(pt2.x, pt2.y, 0) }, outer: face.outer? }
      end
      arr3.each_with_index do |arr, i|
        (i + 1...arr3.size).each do |j|
          arr4 = arr3[j]
          len2d = arr[:p0].distance(arr4[:p0])
          s = (arr[:size] + arr4[:size]) / 0.85
          next unless len2d < s
          arr[:size] = [arr[:size], arr[:size] / s * len2d].min
          arr4[:size] = [arr4[:size], arr4[:size] / s * len2d].min
        end
      end
      arr3.each do |arr|
        pt4 = arr[:p0].offset(arr[:vec], -arr[:size])
        _8d05dd56 = arr[:size] / Math.sqrt(3)
        p1 = pt4.offset(arr[:pp_vec], _8d05dd56)
        p2 = pt4.offset(arr[:pp_vec], -_8d05dd56)
        edge_band_lines << [arr[:p0], p1, p2, arr[:p0]].map { |pt2| Geom::Point3d.new(pt2.x, pt2.y, 0) }
      end
    else
      up_face.loops.each do |face|
        color = face.vertices.map do |v|
          pt3 = v.position.transform(tf)
          Geom::Point3d.new(pt3.x, pt3.y, 0)
        end
        next if color.length < 3
        color << color[0]
        loops << { pts: color, outer: face.outer? }
      end
    end
    { loops: loops, edge_band_lines: edge_band_lines, edge_band_desc: edge_band_desc }
  end
end
require "uri"
module KSU::Cutting
  def self.license_path
    File.join(KSU::Settings.data_dir, "license.dat")
  end
  def self.deactivate_key(serial_key)
    KSU::Const.fetch_json(KSU::Loop.license_url(serial_key, "deactivate") + "&instance=" + URI.encode_www_form_component(KSU::Gannhan.license_field("i")))
  end
end
