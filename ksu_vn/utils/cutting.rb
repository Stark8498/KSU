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
    KSU.entities_in(entity).each { |c| set_layer(c, tag) }
  end
  def self.label_of(panel)
    ents = KSU.entities_in(panel)
    return nil unless ents
    ents.to_a.find do |grp|
      next false unless KSU.container?(grp) && grp.valid?
      str = grp.name.to_s
      def_name = (grp.respond_to?(:definition) && grp.definition) ? grp.definition.name.to_s : ""
      str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    end
  end
  def self.label_rect(ents)
    h = {}
    arr = []
    ents.to_a.each do |edge|
      next unless edge.is_a?(Sketchup::Edge) && edge.valid?
      lp = edge.curve
      next unless lp && lp.valid?
      next if h[lp.entityID]
      h[lp.entityID] = true
      arr << lp if lp.respond_to?(:count_edges) && lp.count_edges == 4
    end
    return nil if arr.empty?
    return arr.first if arr.length == 1
    arr.max_by { |face| area(face.vertices.map(&:position)).abs }
  end
  def self.label_pts(panel, tf)
    return nil unless panel && panel.valid?
    lbl = label_of(panel)
    return nil unless lbl && lbl.valid? && lbl.respond_to?(:definition) && lbl.definition
    box2 = label_rect(lbl.definition.entities)
    return nil unless box2
    tr = tf * lbl.transformation
    pt = box2.vertices.map { |v| v.position.transform(tr) }
    pt.pop if pt.length >= 2 && pt.first.distance(pt.last).to_f < 1e-6
    pt.length >= 3 ? pt : nil
  end
  def self.largest_face(src, arr, skip1 = nil, skip2 = nil, skip3 = nil)
    best = nil
    src.each_with_index do |f, i|
      next if f == skip1 || f == skip2 || f == skip3
      best = [f, arr[i]] if best.nil? || arr[i] > best[1]
    end
    best
  end
  def self.board_faces(grp2, tf)
    src = (KSU.entities_in(grp2) || []).grep(Sketchup::Face)
    return nil if src.length < 2
    arr = src.map { |f| f.area(tf) }
    face, a1 = largest_face(src, arr)
    face2, a2 = largest_face(src, arr, face)
    return nil unless face && face2
    vec2 = face.normal.transform(tf)
    vec = face2.normal.transform(tf)
    if vec2.parallel?(vec)
      return nil unless (a1 - a2).abs < 0.001
      [face, face2]
    else
      return nil if src.length < 4
      face3, a3 = largest_face(src, arr, face, face2)
      face4, a4 = largest_face(src, arr, face, face2, face3)
      return nil unless face3 && face4
      vec4 = face3.normal.transform(tf)
      vec3 = face4.normal.transform(tf)
      return nil unless vec4.parallel?(vec3) && (a3 - a4).abs < 0.001
      [face3, face4]
    end
  end
  def self.face_with(grp2, attr)
    (KSU.entities_in(grp2) || []).grep(Sketchup::Face).find { |f| f.get_attribute("ABF", attr) }
  end
  def self.kids_with_attr(grp2, attr)
    ents = KSU.entities_in(grp2)
    return nil unless ents
    seen3 = ents.select { |grp| KSU.container?(grp) && grp.get_attribute("ABF", attr, false) }
    seen3.empty? ? nil : seen3
  end
  def self.front_face(grp2, b2)
    labeled = face_with(grp2, "is-labeled-face")
    label_kids = kids_with_attr(grp2, "is-label")
    flag = (labeled && label_kids) ? labeled : nil
    flag ||= face_with(grp2, "is-cnced-face")
    flag || b2[0]
  end
  def self.edgeband_meta(grp)
    out = {}
    _9fe6030e = grp.get_attribute("ZSU", "thuoc_tinh_dan_canh")
    _9fe6030e = grp.get_attribute("ZSU", "dan_canh_meta") unless _9fe6030e.is_a?(Array)
    return out unless _9fe6030e.is_a?(Array)
    (0...(_9fe6030e.size / 4)).each do |i|
      num = _9fe6030e[i * 4 + 2].to_i
      b = _9fe6030e[i * 4 + 3].to_i
      out[_9fe6030e[i * 4]] = if num == 2
        [_9fe6030e[i * 4 + 1].to_s, false, false, b == 1]
      else
        [_9fe6030e[i * 4 + 1].to_s, num == 1, b == 1, true]
      end
    end
    out
  end
  def self.material_for(face)
    face.material ? face.material.display_name.to_s : ""
  end
  def self.board_thickness(grp2)
    tf = tf_of(grp2)
    b2 = board_faces(grp2, tf)
    return nil unless b2
    bb2 = b2[0].bounds.center.transform(tf)
    bb = b2[1].bounds.center.transform(tf)
    bb2.distance_to_plane([bb, b2[0].normal.transform(tf)]).to_f * 25.4
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
  def self.edgeband_list(grp)
    arr = grp.get_attribute("ABF", "edge-band-types")
    return [] unless arr.is_a?(Array) && arr.size >= 5
    arr2 = edgeband_meta(grp)
    return [] if arr2.empty?
    mat = material_for(grp)
    _312f66e6 = board_thickness(grp)
    out = []
    (0...arr.size / 5).each do |i|
      meta = arr2[arr[i * 5]]
      next unless meta
      thickness = arr[i * 5 + 2].to_f
      want2 = thickness > thickness.to_i ? thickness.to_s : thickness.to_i.to_s
      out << edgeband_row(meta, arr[i * 5 + 1].to_s, mat, _312f66e6, want2)
    end
    out
  end
  def self.edgeband_spec(grp, thick_mm = nil, h6 = nil)
    arr = grp.get_attribute("ABF", "edge-band-types")
    return [[], 0.1.mm] unless arr
    arr2 = edgeband_meta(grp)
    mat = material_for(grp)
    flag2 = thick_mm || (arr2.empty? ? nil : board_thickness(grp))
    flag = h6 ? (h6[:sep] ||= separator) : separator
    h = {}
    (0...arr.size / 5).each do |i|
      id = arr[i * 5]
      name = arr[i * 5 + 1].to_s
      thickness = arr[i * 5 + 2].to_f
      want2 = thickness > thickness.to_i ? thickness.to_s : thickness.to_i.to_s
      fields = edgeband_row(arr2[id], name, mat, flag2, want2)
      stat = arr2[id] ? arr2[id][3] != false : true
      h[id] = { thickness: thickness / 25.4, display_name: display_name(fields, flag), fields: fields, stat: stat }
    end
    src = []
    hi = 0.1.mm
    (KSU.entities_in(grp) || []).grep(Sketchup::Face).each do |f|
      id = f.get_attribute("ABF", "edge-band-id")
      next unless id
      t = h[id]
      next unless t
      src << [f, t[:thickness], t[:display_name], t[:fields], t[:stat], f.get_attribute("ZSU", "loai_canh").to_s]
      hi = [hi, t[:thickness]].max
    end
    [src, hi]
  end
  def self.arrow_sizes(small_size)
    num = 6.5
    num2 = 9
    if small_size > 5.cm
      num = 6.5 + (small_size - 5.cm)
      num2 = 8
    end
    if small_size > 10.cm
      num = 8.5 + ((small_size - 10.cm) / 1.5)
      num2 = 7
    end
    if small_size > 20.cm
      num = 10 + ((small_size - 20.cm) / 2.5)
      num2 = 6
    end
    if small_size > 40.cm
      num = 13 + ((small_size - 40.cm) / 3.5)
      num2 = 5
    end
    if small_size > 80.cm
      num = 17
      num2 = 4
    end
    ratio = small_size / num
    num3 = 15.mm * Math.sqrt(3) / 2
    ratio = num3 if ratio > num3
    [ratio, ratio / num2]
  end
  def self.box_axes(bnds, tf)
    p_ref = bnds.corner(0).transform(tf)
    [1, 2, 4].map { |i|
      pt3 = bnds.corner(i).transform(tf)
      [p_ref.distance(pt3), p_ref.vector_to(pt3)]
    }.sort_by { |arr| arr[0] }
  end
  def self.short_side(font, tf)
    face_size(font, tf)[1]
  end
  def self.cut_loops(grp2, up_face, tf, edgeband_spec, arrow_size, arrow_padding)
    loops = []
    edge_band_lines = []
    edge_band_desc = []
    vec2 = up_face.normal.transform(tf)
    if edgeband_spec.length > 0
      arr4 = []
      up_face.loops.each do |face|
        lines = []
        h = {}
        h2 = {}
        face.edges.each do |edge|
          if edge.curve
            h2[edge.curve.entityID] = edge.curve
          else
            h[edge.entityID] = true
          end
        end
        h2.each_value { |arr2| h[arr2.edges[arr2.edges.size / 2].entityID] = true }
        face.edges.each do |edge|
          axis = [edge.line[0].transform(tf), edge.line[1].transform(tf)]
          num = edge.length(tf)
          num *= edge.curve.edges.size if edge.curve
          edgeband_spec.each do |rec|
            font = rec[0]
            vec = font.normal.transform(tf)
            thickness = rec[1]
            next unless edge.used_by?(font)
            axis[0] = axis[0].offset(vec, -thickness)
            next unless h.key?(edge.entityID)
            p_next = edge.start.position.transform(tf) + edge.end.position.transform(tf).to_a
            p_next.set!(p_next.x / 2, p_next.y / 2, p_next.z / 2)
            p_ref = p_next.offset!(vec, -thickness - arrow_padding)
            pp_vec = vec.cross(vec2)
            next unless pp_vec.length.to_f > 0.0
            arr4 << { p0: p_ref, vec: vec, pp_vec: pp_vec, size: [arrow_size, num / 2].min }
            edge_band_desc << { p0: p_next, p1: p_next.offset(vec, 1), name: rec[2], fields: rec[3], kind: rec[5] }
          end
          lines << axis
        end
        next if lines.empty?
        out = []
        (0...lines.length - 1).each do |i|
          meet = Geom.intersect_line_line(lines[i], lines[i + 1])
          out << meet if meet
        end
        meet0 = Geom.intersect_line_line(lines[-1], lines[0])
        if meet0
          out << meet0
        elsif !lines[-1][1].parallel?(lines[0][1])
          next
        end
        next if out.length < 3
        out << out[0]
        loops << { pts: out.map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }, outer: face.outer? }
      end
      arr4.each_with_index do |arr, i|
        (i + 1...arr4.size).each do |ix|
          arr3 = arr4[ix]
          len2d = arr[:p0].distance(arr3[:p0])
          s = (arr[:size] + arr3[:size]) / 0.85
          next unless len2d < s
          arr[:size] = [arr[:size], arr[:size] / s * len2d].min
          arr3[:size] = [arr3[:size], arr3[:size] / s * len2d].min
        end
      end
      arr4.each do |arr|
        pt2 = arr[:p0].offset(arr[:vec], -arr[:size])
        _e8f9dc5f = arr[:size] / Math.sqrt(3)
        p1 = pt2.offset(arr[:pp_vec], _e8f9dc5f)
        p2 = pt2.offset(arr[:pp_vec], -_e8f9dc5f)
        edge_band_lines << [arr[:p0], p1, p2, arr[:p0]].map { |pt| Geom::Point3d.new(pt.x, pt.y, 0) }
      end
    else
      up_face.loops.each do |face|
        arr2 = face.vertices.map do |v|
          pt3 = v.position.transform(tf)
          Geom::Point3d.new(pt3.x, pt3.y, 0)
        end
        next if arr2.length < 3
        arr2 << arr2[0]
        loops << { pts: arr2, outer: face.outer? }
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
