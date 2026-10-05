module KSU::Detail
  def build_lines_group(panel, prev_key, base_tr, loops, str = "ABF_cuttingLines")
    ents = KSU.entities_in(panel)
    return [nil, base_tr] unless ents
    tr3 = prev_key.transformation * prev_key.definition.bounds.center
    grp = ents.add_group
    defn2 = grp.definition.entities
    loops.each do |arr2|
      arr = arr2[:pts]
      next if arr.length < 4
      arr3 = defn2.add_curve(arr)
      next unless arr2[:outer]
      arr3.each { |grp2| grp2.set_attribute("ABF", "is-outer-loop", true) if grp2.is_a?(Sketchup::Edge) }
    end
    defn2.grep(Sketchup::Face).each(&:erase!)
    grp.transformation = base_tr
    tr2 = grp.transformation * grp.definition.bounds.center
    tr = Geom::Transformation.translation(tr3 - tr2) * base_tr
    grp.transformation = tr
    copy_attrs(grp, prev_key)
    set_layer(grp, layer(str))
    prev_key.erase! if prev_key && prev_key.valid?
    [grp, tr]
  end
  def edgeband_group(panel)
    ents = KSU.entities_in(panel)
    return nil unless ents
    ents.find { |grp| KSU.container?(grp) && grp.get_attribute("ABF", "is-edge-banding-notation") } ||
      ents.find { |grp| KSU.container?(grp) && grp.name.to_s.include?("_ABF_edgeBanding") }
  end
  def draw_edgeband(panel, part_tf, lines)
    gr = edgeband_group(panel)
    if lines.empty?
      if gr && gr.valid? && gr.respond_to?(:definition) && gr.definition
        ents = gr.definition.entities
        ents.erase_entities(ents.to_a) unless ents.to_a.empty?
      end
      return
    end
    unless gr && gr.valid?
      gr = KSU.entities_in(panel).add_group
      gr.name = "_ABF_edgeBanding"
      gr.set_attribute("ABF", "is-edge-banding-notation", true)
    end
    ents = gr.definition.entities
    ents.erase_entities(ents.to_a) unless ents.to_a.empty?
    lines.each { |arr| ents.add_curve(arr) if arr.length >= 2 }
    ents.grep(Sketchup::Face).each(&:erase!)
    gr.transformation = part_tf.inverse
    set_layer(gr, layer("ABF_edgeBanding"))
  end
  def save_edgeband_desc(panel, descent, tf)
    arr = descent.map do |len2d|
      p_ref = len2d[:p0].transform(tf)
      p1 = len2d[:p1].transform(tf)
      [p_ref.x.to_f, p_ref.y.to_f, p_ref.z.to_f, p1.x.to_f, p1.y.to_f, p1.z.to_f, len2d[:name]] +
        Array(len2d[:fields]).map(&:to_s) + [len2d[:kind].to_s]
    end
    panel.set_attribute("ABF", "edge-band-desc", arr)
  end
  def unscale(grp)
    return unless grp && grp.valid? && KSU.container?(grp)
    tr3 = grp.transformation
    arr = [X_AXIS, Y_AXIS, Z_AXIS].map { |pt| pt.transform(tr3).length }
    return if arr.all? { |s| (s - 1.0).abs < 1e-6 }
    tr2 = Geom::Transformation.scaling(*arr)
    inv = tr2.inverse
    grp2 = grp.definition
    grp2.entities.transform_entities(tr2, grp2.entities.to_a)
    grp2.instances.each do |instance|
      tr = instance.transformation
      instance.transform!(tr * inv * tr.inverse)
    end
  end
  def build_panel(panel, vec, nesting = nil)
    return false unless panel && panel.valid? && vec && vec.valid?
    cutting = cutting_group(panel)
    return false unless cutting && cutting.valid? && cutting.respond_to?(:definition) && cutting.definition
    tr2 = cutting.transformation
    part_tf = Geom::Transformation.axes(tr2.origin, tr2.xaxis.normalize, tr2.yaxis.normalize, tr2.zaxis.normalize).inverse
    unscale(vec)
    tf3d = tf_of(vec)
    b2 = board_faces(vec, tf3d)
    return false unless b2
    vec2 = front_face(vec, b2)
    return false unless vec2 && vec2.valid?
    tf2 = align_tf(vec, vec2, tf3d)
    part_tf = tf2 if tf2
    max_eb = edgeband_spec(vec)
    arr = arrow_sizes(short_side(vec2, tf3d))
    rec = cut_loops(vec, vec2, part_tf, max_eb[0], arr[0], arr[1])
    return false if rec[:loops].empty?
    lines_grp, tr = build_lines_group(panel, cutting, tr2, rec[:loops])
    return false unless lines_grp
    draw_edgeband(panel, tr.inverse, rec[:edge_band_lines])
    save_edgeband_desc(panel, rec[:edge_band_desc], tr)
    faces = split_by_face(vec, vec2, tf3d)
    draw_bands(panel, faces[:up], tr * part_tf)
    save_drills_desc(panel, side_drills(vec, vec2, part_tf), tr)
    holes = label_opts(vec, faces[:label], vec2, tf3d, max_eb[1], arr)
    draw_holes(panel, tr * part_tf, holes, false)
    if nesting
      if faces[:bottom].empty?
        erase_partner(nesting, panel)
      else
        build_partner(nesting, panel, rec[:loops], faces[:bottom], holes, tf2)
      end
    end
    true
  end
  def erase_partner(nesting, _cb0d0d2e)
    back = partner_panel(nesting, _cb0d0d2e)
    return unless back && back.valid?
    grp = KSU::Flip.sheet_of(nesting, back)
    back.erase!
    return unless grp && grp.valid?
    return unless KSU::Sheet.hidden?(grp)
    grp.erase! if KSU::Sheet.empty?(grp)
  end
  def align_tf(_b7318596, up_face, tf3d)
    groups = kids_with_attr(_b7318596, "is-label")
    return nil unless groups && groups[0] && groups[0].valid?
    _d46c450b = up_face.normal.transform(tf3d).axes
    tf_axes = Geom::Transformation.axes(ORIGIN, _d46c450b[0], _d46c450b[1], _d46c450b[2]).inverse
    vec = groups[0].transformation.xaxis.transform(tf_axes * tf3d)
    target = Y_AXIS.reverse
    ang = Math.atan2(vec.cross(target).z, vec.dot(target))
    ang += 2 * Math::PI if ang < 0
    tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, ang)
    normal = tr * tf_axes * tf3d
    anchor = normal.origin
    Geom::Transformation.translation([-anchor.x, -anchor.y, -anchor.z]) * normal
  end
  def build_partner(nesting, _cb0d0d2e, loops, bands, holes = nil, part_tf = nil)
    back = partner_panel(nesting, _cb0d0d2e)
    return unless back && back.valid?
    grp = cutting_group(back)
    return unless grp && grp.valid? && grp.respond_to?(:definition) && grp.definition
    tr = grp.transformation
    pt = Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
    grp2, tr2 = build_lines_group(back, grp, tr, loops, "ABF_partBorder")
    return unless grp2
    inv_tf = part_tf || pt.inverse
    draw_bands(back, bands, tr2 * inv_tf)
    draw_holes(back, tr2 * inv_tf, holes, true) if holes
  end
  def label_opts(grp, label3d, up_face, tf3d, max_eb_th, arr)
    {
      label3d: label3d,
      up_face: up_face,
      tf3d: tf3d,
      rotate: (grp.get_attribute("ABF", "label-rotation") || 0),
      max_h: KSU::Settings.get("kich_thuoc_nhan", 50.0, "gan_nhan").to_f.mm,
      max_eb_th: max_eb_th,
      arrow_size: arr[0],
      arrow_padding: arr[1],
    }
  end
  def clear_labels(panel)
    ents = KSU.entities_in(panel)
    return unless ents
    prev_key = ents.to_a.select do |grp|
      next false unless KSU.container?(grp) && grp.valid?
      grp.get_attribute("ABF", "is-label") || grp.name.to_s.include?("_ABF_Label")
    end
    ents.erase_entities(prev_key) unless prev_key.empty?
  end
  def draw_holes(panel, inv_tf, arr, flip)
    label3d = arr && arr[:label3d]
    return unless label3d && label3d.valid? && label3d.respond_to?(:definition) && label3d.definition
    ents = KSU.entities_in(panel)
    return unless ents
    clear_labels(panel)
    inst = ents.add_instance(label3d.definition, inv_tf * label3d.transformation)
    copy_attrs(inst, label3d)
    fit_label(inst, arr)
    inst.transformation = inst.transformation * Geom::Transformation.rotation(ORIGIN, Y_AXIS, 180.degrees) if flip
    copy_and_flatten(inst, label3d)
  end
  def fit_label(lbl, arr)
    _2083e4e3 = lbl.get_attribute("ABF", "label-width")
    _ebdef9f9 = lbl.get_attribute("ABF", "label-height")
    _7a72dc50 = lbl.get_attribute("ABF", "label-scale")
    return unless _2083e4e3 && _ebdef9f9 && _7a72dc50 && _2083e4e3 > 0 && _ebdef9f9 > 0 && _7a72dc50 != 0
    rotate = arr[:rotate]
    arrow_padding = arr[:arrow_padding]
    _f0ba2e7b = arrow_padding
    _f0ba2e7b = _f0ba2e7b * 8 if rotate == 0 || rotate == 180
    _fdc5572e = arr[:arrow_size] * 2 + arrow_padding * 2 + _f0ba2e7b * 2 + arr[:max_eb_th] * 2
    arr2 = face_size(arr[:up_face], arr[:tf3d])
    max_h = arr[:max_h]
    if rotate == 0 || rotate == 180
      stroke_w = (arr2[0] - _fdc5572e) / _2083e4e3
      sheet_h = [(arr2[1] - _fdc5572e), max_h].min / _ebdef9f9
    else
      stroke_w = (arr2[1] - _fdc5572e) / _2083e4e3
      sheet_h = [(arr2[0] - _fdc5572e), max_h].min / _ebdef9f9
    end
    num = [stroke_w, sheet_h].min
    num = 0.001 if num <= 0
    num2 = 1.0 / _7a72dc50 * num
    lbl.transformation = lbl.transformation * Geom::Transformation.scaling(num2, num2, 1.0)
    lbl.definition.invalidate_bounds if lbl.respond_to?(:definition) && lbl.definition
  end
  def face_size(font, tf)
    s = box_axes(font.bounds, tf)
    [s[2][0], s[1][0]]
  end
  def tf_of(inst)
    tr = inst.transformation
    loop do
      defn = inst.parent
      break unless defn.is_a?(Sketchup::ComponentDefinition)
      inst = defn.instances[0]
      return tr unless inst
      tr = inst.transformation * tr
    end
    tr
  end
  def transparent_material
    materials = Sketchup.active_model.materials
    meta = materials["Transparent"]
    return meta if meta
    meta = materials.add("Transparent")
    meta.color = "white"
    meta.alpha = 0
    meta
  end
  def copy_attrs(gr, src)
    arr = src.attribute_dictionaries
    if arr
      ["ABF", "ZSU"].each do |def_name|
        next unless arr[def_name]
        arr[def_name].each_pair { |k, v| gr.set_attribute(def_name, k, v) }
      end
    end
    gr.name = src.name
  end
  def copy_layer(gr, src)
    return unless gr && gr.valid? && gr.respond_to?(:layer=)
    return unless src && src.respond_to?(:layer)
    vec = src.layer
    return unless vec && vec.valid?
    return if vec.name.to_s == "Layer0"
    gr.layer = vec
  end
  def copy_and_flatten(gr, src)
    copy_attrs(gr, src)
    copy_layer(gr, src)
    tr = tf_of(gr)
    z = tr.origin.z
    if src.get_attribute("ABF", "is-intersect") || src.get_attribute("ABF", "is-screw")
      gr.material = transparent_material
      (KSU.entities_in(gr) || []).each do |edge|
        next unless edge.is_a?(Sketchup::Edge)
        z = edge.start.position.transform(tr).z
        break
      end
    end
    gr.material = transparent_material if src.get_attribute("ABF", "is-user-nesting-obj")
    gr.transformation = gr.transformation * Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -z).transform(tr.inverse))
  end
  def split_by_face(_b7318596, up_face, tf3d)
    arr = []
    bot = []
    lbl = nil
    bb = up_face.bounds.center.transform(tf3d)
    vec = up_face.normal.transform(tf3d)
    ents = KSU.entities_in(_b7318596) || []
    h = {}
    ents.each do |grp|
      next unless grp.is_a?(Sketchup::Group)
      next unless grp.get_attribute("ABF", "is-minifix-part-b")
      next if grp.get_attribute("ABF", "is-side-drill-depth")
      box = grp.transformation.origin.transform(tf3d)
      next unless box.distance_to_plane([bb, vec]) > 0.001
      h[grid_key(box)] = grp
    end
    ents.grep(Sketchup::Group).each do |grp|
      arr2 = grp.attribute_dictionaries
      next unless arr2 && arr2["ABF"] && !grp.get_attribute("ABF", "is-lockdowel-preview-b", false)
      if grp.get_attribute("ABF", "is-label")
        lbl = grp
        next
      end
      if grp.get_attribute("ABF", "is-intersect") || grp.get_attribute("ABF", "is-screw")
        (KSU.entities_in(grp) || []).each do |edge|
          next unless edge.is_a?(Sketchup::Edge)
          if edge.start.position.transform(tf3d * grp.transformation).distance_to_plane([bb, vec]) < 0.001
            arr << grp
          else
            bot << grp
          end
          break
        end
        next
      end
      if grp.get_attribute("ABF", "is-side-drill-depth")
        box = grp.transformation.origin.transform(tf3d)
        if h[grid_key(box)] && !grp.get_attribute("ABF", "is-minifix-part-b")
          bot << grp
          next
        end
        arr << grp
      end
      next if grp.get_attribute("ABF", "is-side-drill")
      if grp.transformation.origin.transform(tf3d).distance_to_plane([bb, vec]) < 0.001
        arr << grp
      else
        bot << grp
      end
    end
    { up: arr.uniq, bottom: bot.uniq, label: lbl }
  end
  def draw_bands(panel, arr2, inv_tf = nil)
    ents = KSU.entities_in(panel)
    return unless ents
    prev_key = ents.select do |grp2|
      next false unless KSU.container?(grp2)
      next false if grp2.get_attribute("ABF", "is-cutting-lines")
      next false if grp2.get_attribute("ABF", "is-edge-banding-notation")
      next false if grp2.get_attribute("ABF", "is-label")
      arr = grp2.name.to_s
      next false if arr.include?("_ABF_cuttingLines") || arr.include?("_ABF_edgeBanding") || arr.include?("_ABF_Label")
      next false if KSU::Sheet.sheet_border?(grp2)
      true
    end
    ents.erase_entities(prev_key) unless prev_key.empty?
    arr2.each do |grp|
      next unless grp.respond_to?(:definition) && grp.definition
      tr = inv_tf ? inv_tf * grp.transformation : grp.transformation
      inst = ents.add_instance(grp.definition, tr)
      copy_and_flatten(inst, grp)
    end
  end
  def depth(num, digits, factor)
    seen3 = (num.to_f * factor).round(digits)
    return seen3 unless (seen3 % 1) == 0
    seen3.to_i
  end
  def d(_6f2569f7)
    depth(_6f2569f7, 2, 25.4)
  end
  def grid_key(arr)
    (arr[0] * 1000).round + (arr[1] * 1000000).round + (arr[2] || 0).round
  end
  def edge_index(vec)
    arr = [Y_AXIS.reverse, X_AXIS.reverse, Y_AXIS, X_AXIS]
    (0...arr.size).each do |i|
      return i if vec.samedirection?(arr[i])
    end
    nil
  end
  def edge_bounds(arr, tf)
    b = KSU::Geom.bounds(arr.map { |v| v.position.transform(tf) })
    [b[:max_y], b[:max_x], b[:min_y], b[:min_x]]
  end
  def drill_of(lp, arr, tf)
    depth2 = lp.get_attribute("ABF", "drill-depth", -1)
    num = lp.vertices.size - 1
    pt = lp.vertices[0].position.transform(tf)
    far_pt = lp.vertices[num / 2].position.transform(tf)
    len2d = pt.distance(far_pt)
    r = len2d / 2
    seen3 = { d: d(len2d), depth: depth(depth2, 1, 1), edge: -1 }
    p_ref = Geom::Point3d.new((pt[0] + far_pt[0]) / 2, (pt[1] + far_pt[1]) / 2, (pt[2] + far_pt[2]) / 2)
    seen3[:pos] = p_ref
    depth_len = depth2.mm
    pt3 = lp.vertices[num / 4].position.transform(tf)
    pt2 = lp.vertices[num * 3 / 4].position.transform(tf)
    vec = pt.vector_to(far_pt).cross(pt3.vector_to(pt2))
    arr.each do |f|
      next unless pt.on_plane?(f)
      vec = f[1].reverse
      break
    end
    return seen3 unless vec.valid?
    vec2 = vec.cross(Z_AXIS)
    return seen3 unless vec2.valid?
    p1 = p_ref.offset(vec2, -r)
    p2 = p1.offset(vec, depth_len)
    p3 = p2.offset(vec2, len2d)
    p4 = p_ref.offset(vec2, r)
    seen3[:poly] = [p1, p2, p3, p4]
    e = edge_index(vec.reverse)
    return seen3 unless depth2 > 0 && e
    seen3[:edge] = e
    seen3
  end
  def side_drills(gr, up_face, tf)
    bnds = edge_bounds(up_face.outer_loop.vertices, tf)
    arr2 = []
    ["is-minifix-part-a", "is-minifix-part-b", "is-hinge-part-a", "is-hinge-part-b", "is-side-drill"].each do |attr|
      partner = kids_with_attr(gr, attr)
      arr2.concat(partner) if partner
    end
    arr2.uniq!
    found = []
    vec2 = up_face.normal.transform(tf)
    vec = (KSU.entities_in(gr) || []).grep(Sketchup::Face).map { |f| [f.bounds.center.transform(tf), f.normal.transform(tf)] }
    vec.select! { |f| f[1].perpendicular?(vec2) }
    arr2.each do |grp|
      h = {}
      (KSU.entities_in(grp) || []).each do |edge|
        h[edge.curve.entityID] = edge.curve if edge.is_a?(Sketchup::Edge) && edge.curve && edge.curve.is_a?(Sketchup::ArcCurve)
      end
      h.each_value do |c|
        _7cffa1ad = drill_of(c, vec, tf * grp.transformation)
        _7cffa1ad[:edge_pos] = 0
        case _7cffa1ad[:edge]
        when 0 then _7cffa1ad[:edge_pos] = d(bnds[1] - _7cffa1ad[:pos][0])
        when 1 then _7cffa1ad[:edge_pos] = d(_7cffa1ad[:pos][1] - bnds[2])
        when 2 then _7cffa1ad[:edge_pos] = d(_7cffa1ad[:pos][0] - bnds[3])
        when 3 then _7cffa1ad[:edge_pos] = d(bnds[0] - _7cffa1ad[:pos][1])
        end
        found << _7cffa1ad
      end
    end
    arr3 = [[], [], [], []]
    found.each do |_7cffa1ad|
      next if _7cffa1ad[:edge] < 0
      arr3[_7cffa1ad[:edge]] << [_7cffa1ad[:edge_pos], _7cffa1ad]
    end
    arr3.each { |arr| arr.sort_by! { |arr4| arr4[0] } }
    arr5 = arr3.map { |arr| arr.map { |arr4| arr4[0].to_s }.join("_") }
    [arr5, found]
  end
  def save_drills_desc(panel, data, tf)
    arr = data[1].map do |rec|
      kids = [rec[:d], rec[:depth]]
      if rec[:depth] > 0 && rec[:poly]
        rec[:poly].each do |pt|
          segs_for_ray = pt.transform(tf)
          kids << [segs_for_ray.x.to_f, segs_for_ray.y.to_f, segs_for_ray.z.to_f]
        end
      else
        segs_for_ray = rec[:pos].transform(tf)
        kids << [segs_for_ray.x.to_f, segs_for_ray.y.to_f, segs_for_ray.z.to_f]
      end
      kids
    end
    panel.set_attribute("ABF", "drills-desc", [data[0], arr])
  end
end
KSU::Cutting.extend(KSU::Detail)
module KSU::Detail
  def self.has_id?(id)
    id && !id.to_s.strip.empty? && id.to_s.strip != "0"
  end
end
