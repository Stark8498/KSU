module KSU::Detail
  def build_lines_group(panel, prev_key, base_tr, loops, str = "ABF_cuttingLines")
    ents = KSU.entities_in(panel)
    return [nil, base_tr] unless ents
    tr3 = prev_key.transformation * prev_key.definition.bounds.center
    grp = ents.add_group
    ents2 = grp.definition.entities
    loops.each do |arr|
      pts = arr[:pts]
      next if pts.length < 4
      arr3 = ents2.add_curve(pts)
      next unless arr[:outer]
      arr3.each { |ent| ent.set_attribute("ABF", "is-outer-loop", true) if ent.is_a?(Sketchup::Edge) }
    end
    ents2.grep(Sketchup::Face).each(&:erase!)
    grp.transformation = base_tr
    tr2 = grp.transformation * grp.definition.bounds.center
    tr = Geom::Transformation.translation(tr3 - tr2) * base_tr
    grp.transformation = tr
    _56b0abb5(grp, prev_key)
    set_layer(grp, layer(str))
    prev_key.erase! if prev_key && prev_key.valid?
    [grp, tr]
  end
  def edgeband_group(panel)
    ents = KSU.entities_in(panel)
    return nil unless ents
    found = ents.find { |ent| KSU.container?(ent) && ent.get_attribute("ABF", "is-edge-banding-notation") }
    return found if found
    ents.find { |ent| KSU.container?(ent) && ent.name.to_s.include?("_ABF_edgeBanding") }
  end
  def draw_edgeband(panel, part_tf, count_by_length)
    gr = edgeband_group(panel)
    if count_by_length.empty?
      if gr && gr.valid? && gr.respond_to?(:definition) && gr.definition
        ent = gr.definition.entities
        ent.erase_entities(ent.to_a) unless ent.to_a.empty?
      end
      return
    end
    unless gr && gr.valid?
      gr = KSU.entities_in(panel).add_group
      gr.name = "_ABF_edgeBanding"
      gr.set_attribute("ABF", "is-edge-banding-notation", true)
    end
    ent = gr.definition.entities
    ent.erase_entities(ent.to_a) unless ent.to_a.empty?
    count_by_length.each { |pts| ent.add_curve(pts) if pts.length >= 2 }
    ent.grep(Sketchup::Face).each(&:erase!)
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
  def unscale(node)
    return unless node && node.valid? && KSU.container?(node)
    transform = node.transformation
    arr = [X_AXIS, Y_AXIS, Z_AXIS].map { |pt| pt.transform(transform).length }
    return if arr.all? { |s| (s - 1.0).abs < 1e-6 }
    tr = Geom::Transformation.scaling(*arr)
    inv = tr.inverse
    grp2 = node.definition
    grp2.entities.transform_entities(tr, grp2.entities.to_a)
    grp2.instances.each do |instance|
      tr2 = instance.transformation
      instance.transform!(tr2 * inv * tr2.inverse)
    end
  end
  def build_panel(panel, grp, nesting = nil)
    return false unless panel && panel.valid? && grp && grp.valid?
    cutting = cutting_group(panel)
    return false unless cutting && cutting.valid? && cutting.respond_to?(:definition) && cutting.definition
    tr = cutting.transformation
    pt = Geom::Transformation.axes(tr.origin, tr.xaxis.normalize, tr.yaxis.normalize, tr.zaxis.normalize)
    part_tf = pt.inverse
    unscale(grp)
    tf3d = tf_of(grp)
    b2 = board_faces(grp, tf3d)
    return false unless b2
    vec2 = front_face(grp, b2)
    return false unless vec2 && vec2.valid?
    tf2 = align_tf(grp, vec2, tf3d)
    part_tf = tf2 if tf2
    max_eb = edgeband_spec(grp)
    small_size = _f7a09903(vec2, tf3d)
    arr2 = _e4e88386(small_size)
    rec = _4605a894(grp, vec2, part_tf, max_eb[0], arr2[0], arr2[1])
    return false if rec[:loops].empty?
    _2422ecf1, tr2 = build_lines_group(panel, cutting, tr, rec[:loops])
    return false unless _2422ecf1
    draw_edgeband(panel, tr2.inverse, rec[:edge_band_lines])
    save_edgeband_desc(panel, rec[:edge_band_desc], tr2)
    bottom = _babeb881(grp, vec2, tf3d)
    draw_bands(panel, bottom[:up], tr2 * part_tf)
    _c6e26747(panel, _32f2e5fc(grp, vec2, part_tf), tr2)
    holes = label_opts(grp, bottom[:label], vec2, tf3d, max_eb[1], arr2)
    draw_holes(panel, tr2 * part_tf, holes, false)
    if nesting
      if bottom[:bottom].empty?
        erase_partner(nesting, panel)
      else
        build_partner(nesting, panel, rec[:loops], bottom[:bottom], holes, tf2)
      end
    end
    true
  end
  def erase_partner(nesting, panel)
    back = partner_panel(nesting, panel)
    return unless back && back.valid?
    sheet = KSU::Flip.sheet_of(nesting, back)
    back.erase!
    return unless sheet && sheet.valid?
    return unless KSU::Sheet.hidden?(sheet)
    sheet.erase! if KSU::Sheet.empty?(sheet)
  end
  def align_tf(grp, up_face, tf3d)
    arr = kids_with_attr(grp, "is-label")
    return nil unless arr && arr[0] && arr[0].valid?
    out = up_face.normal.transform(tf3d).axes
    tf_axes = Geom::Transformation.axes(ORIGIN, out[0], out[1], out[2]).inverse
    vec = arr[0].transformation.xaxis.transform(tf_axes * tf3d)
    target = Y_AXIS.reverse
    ang = Math.atan2(vec.cross(target).z, vec.dot(target))
    ang += 2 * Math::PI if ang < 0
    tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, ang)
    normal = tr * tf_axes * tf3d
    anchor = normal.origin
    Geom::Transformation.translation([-anchor.x, -anchor.y, -anchor.z]) * normal
  end
  def build_partner(nesting, panel, loops, bands, holes = nil, part_tf = nil)
    back = partner_panel(nesting, panel)
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
    prev_key = ents.to_a.select do |ent|
      next false unless KSU.container?(ent) && ent.valid?
      ent.get_attribute("ABF", "is-label") || ent.name.to_s.include?("_ABF_Label")
    end
    ents.erase_entities(prev_key) unless prev_key.empty?
  end
  def draw_holes(panel, inv_tf, arr, _93bcf54e)
    label3d = arr && arr[:label3d]
    return unless label3d && label3d.valid? && label3d.respond_to?(:definition) && label3d.definition
    ents = KSU.entities_in(panel)
    return unless ents
    clear_labels(panel)
    inst = ents.add_instance(label3d.definition, inv_tf * label3d.transformation)
    _56b0abb5(inst, label3d)
    _5edc6938(inst, arr)
    inst.transformation = inst.transformation * Geom::Transformation.rotation(ORIGIN, Y_AXIS, 180.degrees) if _93bcf54e
    _81410e9d(inst, label3d)
  end
  def _5edc6938(lbl, arr)
    _6967f87f = lbl.get_attribute("ABF", "label-width")
    _54538e67 = lbl.get_attribute("ABF", "label-height")
    _7e53f420 = lbl.get_attribute("ABF", "label-scale")
    return unless _6967f87f && _54538e67 && _7e53f420 && _6967f87f > 0 && _54538e67 > 0 && _7e53f420 != 0
    rotate = arr[:rotate]
    arrow_padding = arr[:arrow_padding]
    _9b67c55d = arrow_padding
    _9b67c55d = _9b67c55d * 8 if rotate == 0 || rotate == 180
    _5ec460ae = arr[:arrow_size] * 2 + arrow_padding * 2 + _9b67c55d * 2 + arr[:max_eb_th] * 2
    arr2 = _e04dc194(arr[:up_face], arr[:tf3d])
    max_h = arr[:max_h]
    if rotate == 0 || rotate == 180
      stroke_w = (arr2[0] - _5ec460ae) / _6967f87f
      sheet_h = [(arr2[1] - _5ec460ae), max_h].min / _54538e67
    else
      stroke_w = (arr2[1] - _5ec460ae) / _6967f87f
      sheet_h = [(arr2[0] - _5ec460ae), max_h].min / _54538e67
    end
    num = [stroke_w, sheet_h].min
    num = 0.001 if num <= 0
    num2 = 1.0 / _7e53f420 * num
    lbl.transformation = lbl.transformation * Geom::Transformation.scaling(num2, num2, 1.0)
    lbl.definition.invalidate_bounds if lbl.respond_to?(:definition) && lbl.definition
  end
  def _e04dc194(font, tf)
    s = _b344f39a(font.bounds, tf)
    [s[2][0], s[1][0]]
  end
  def tf_of(inst)
    transform = inst.transformation
    loop do
      defn = inst.parent
      break unless defn.is_a?(Sketchup::ComponentDefinition)
      inst = defn.instances[0]
      return transform unless inst
      transform = inst.transformation * transform
    end
    transform
  end
  def _b39e8694
    materials = Sketchup.active_model.materials
    meta = materials["Transparent"]
    return meta if meta
    meta = materials.add("Transparent")
    meta.color = "white"
    meta.alpha = 0
    meta
  end
  def _56b0abb5(gr, src)
    arr = src.attribute_dictionaries
    if arr
      ["ABF", "ZSU"].each do |def_name|
        next unless arr[def_name]
        arr[def_name].each_pair { |k, v| gr.set_attribute(def_name, k, v) }
      end
    end
    gr.name = src.name
  end
  def _76f5a256(gr, src)
    return unless gr && gr.valid? && gr.respond_to?(:layer=)
    return unless src && src.respond_to?(:layer)
    vec = src.layer
    return unless vec && vec.valid?
    return if vec.name.to_s == "Layer0"
    gr.layer = vec
  end
  def _81410e9d(gr, src)
    _56b0abb5(gr, src)
    _76f5a256(gr, src)
    tf = tf_of(gr)
    z = tf.origin.z
    if src.get_attribute("ABF", "is-intersect") || src.get_attribute("ABF", "is-screw")
      gr.material = _b39e8694
      (KSU.entities_in(gr) || []).each do |ent|
        next unless ent.is_a?(Sketchup::Edge)
        z = ent.start.position.transform(tf).z
        break
      end
    end
    gr.material = _b39e8694 if src.get_attribute("ABF", "is-user-nesting-obj")
    gr.transformation = gr.transformation * Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -z).transform(tf.inverse))
  end
  def _babeb881(grp, up_face, _7caff9f1)
    arr2 = []
    bot = []
    lbl = nil
    bb = up_face.bounds.center.transform(_7caff9f1)
    vec = up_face.normal.transform(_7caff9f1)
    ents = KSU.entities_in(grp) || []
    h = {}
    ents.each do |g|
      next unless g.is_a?(Sketchup::Group)
      next unless g.get_attribute("ABF", "is-minifix-part-b")
      next if g.get_attribute("ABF", "is-side-drill-depth")
      box = g.transformation.origin.transform(_7caff9f1)
      next unless box.distance_to_plane([bb, vec]) > 0.001
      h[_0d18c046(box)] = g
    end
    ents.grep(Sketchup::Group).each do |g|
      arr3 = g.attribute_dictionaries
      next unless arr3 && arr3["ABF"] && !g.get_attribute("ABF", "is-lockdowel-preview-b", false)
      if g.get_attribute("ABF", "is-label")
        lbl = g
        next
      end
      if g.get_attribute("ABF", "is-intersect") || g.get_attribute("ABF", "is-screw")
        (KSU.entities_in(g) || []).each do |ent|
          next unless ent.is_a?(Sketchup::Edge)
          if ent.start.position.transform(_7caff9f1 * g.transformation).distance_to_plane([bb, vec]) < 0.001
            arr2 << g
          else
            bot << g
          end
          break
        end
        next
      end
      if g.get_attribute("ABF", "is-side-drill-depth")
        box = g.transformation.origin.transform(_7caff9f1)
        if h[_0d18c046(box)] && !g.get_attribute("ABF", "is-minifix-part-b")
          bot << g
          next
        end
        arr2 << g
      end
      next if g.get_attribute("ABF", "is-side-drill")
      if g.transformation.origin.transform(_7caff9f1).distance_to_plane([bb, vec]) < 0.001
        arr2 << g
      else
        bot << g
      end
    end
    { up: arr2.uniq, bottom: bot.uniq, label: lbl }
  end
  def draw_bands(panel, arr2, inv_tf = nil)
    ents = KSU.entities_in(panel)
    return unless ents
    prev_key = ents.select do |ent|
      next false unless KSU.container?(ent)
      next false if ent.get_attribute("ABF", "is-cutting-lines")
      next false if ent.get_attribute("ABF", "is-edge-banding-notation")
      next false if ent.get_attribute("ABF", "is-label")
      name = ent.name.to_s
      next false if name.include?("_ABF_cuttingLines") || name.include?("_ABF_edgeBanding") || name.include?("_ABF_Label")
      next false if KSU::Sheet._27ecfdd1(ent)
      true
    end
    ents.erase_entities(prev_key) unless prev_key.empty?
    arr2.each do |g|
      next unless g.respond_to?(:definition) && g.definition
      transform = inv_tf ? inv_tf * g.transformation : g.transformation
      inst = ents.add_instance(g.definition, transform)
      _81410e9d(inst, g)
    end
  end
  def depth(value, _2164146c, _041c4285)
    num = value.to_f * _041c4285
    num = num.round(_2164146c)
    return num unless (num % 1) == 0
    num.to_i
  end
  def d(_b41d8800)
    depth(_b41d8800, 2, 25.4)
  end
  def _0d18c046(arr)
    (arr[0] * 1000).round + (arr[1] * 1000000).round + (arr[2] || 0).round
  end
  def _975e7df6(vec)
    arr = [Y_AXIS.reverse, X_AXIS.reverse, Y_AXIS, X_AXIS]
    (0...arr.size).each do |i|
      return i if vec.samedirection?(arr[i])
    end
    nil
  end
  def _2d2b3dcc(arr, tf)
    b = KSU::Geom.bounds(arr.map { |v| v.position.transform(tf) })
    [b[:max_y], b[:max_x], b[:min_y], b[:min_x]]
  end
  def _0f0ed6ac(lp, arr2, tf)
    depth2 = lp.get_attribute("ABF", "drill-depth", -1)
    num = lp.vertices.size - 1
    pt = lp.vertices[0].position.transform(tf)
    _c1f843df = lp.vertices[num / 2].position.transform(tf)
    len2d = pt.distance(_c1f843df)
    r = len2d / 2
    arr = { d: d(len2d), depth: depth(depth2, 1, 1), edge: -1 }
    p_ref = Geom::Point3d.new((pt[0] + _c1f843df[0]) / 2, (pt[1] + _c1f843df[1]) / 2, (pt[2] + _c1f843df[2]) / 2)
    arr[:pos] = p_ref
    _0c01b674 = depth2.mm
    pt3 = lp.vertices[num / 4].position.transform(tf)
    pt4 = lp.vertices[num * 3 / 4].position.transform(tf)
    vec = pt.vector_to(_c1f843df).cross(pt3.vector_to(pt4))
    arr2.each do |f|
      next unless pt.on_plane?(f)
      vec = f[1].reverse
      break
    end
    return arr unless vec.valid?
    vec2 = vec.cross(Z_AXIS)
    return arr unless vec2.valid?
    p1 = p_ref.offset(vec2, -r)
    p2 = p1.offset(vec, _0c01b674)
    p3 = p2.offset(vec2, len2d)
    p4 = p_ref.offset(vec2, r)
    arr[:poly] = [p1, p2, p3, p4]
    ent = _975e7df6(vec.reverse)
    return arr unless depth2 > 0 && ent
    arr[:edge] = ent
    arr
  end
  def _32f2e5fc(gr, up_face, tf)
    bounds = _2d2b3dcc(up_face.outer_loop.vertices, tf)
    arr3 = []
    ["is-minifix-part-a", "is-minifix-part-b", "is-hinge-part-a", "is-hinge-part-b", "is-side-drill"].each do |attr|
      partner = kids_with_attr(gr, attr)
      arr3.concat(partner) if partner
    end
    arr3.uniq!
    drills = []
    vec2 = up_face.normal.transform(tf)
    vec = (KSU.entities_in(gr) || []).grep(Sketchup::Face).map { |f| [f.bounds.center.transform(tf), f.normal.transform(tf)] }
    vec.select! { |f| f[1].perpendicular?(vec2) }
    arr3.each do |grp|
      h = {}
      (KSU.entities_in(grp) || []).each do |ent|
        h[ent.curve.entityID] = ent.curve if ent.is_a?(Sketchup::Edge) && ent.curve && ent.curve.is_a?(Sketchup::ArcCurve)
      end
      h.each_value do |color|
        arr = _0f0ed6ac(color, vec, tf * grp.transformation)
        next unless arr
        arr[:edge_pos] = 0
        if arr[:edge] > -1
          case arr[:edge]
          when 0 then arr[:edge_pos] = d(bounds[1] - arr[:pos][0])
          when 1 then arr[:edge_pos] = d(arr[:pos][1] - bounds[2])
          when 2 then arr[:edge_pos] = d(arr[:pos][0] - bounds[3])
          when 3 then arr[:edge_pos] = d(bounds[0] - arr[:pos][1])
          end
        end
        drills << arr
      end
    end
    arr2 = [[], [], [], []]
    drills.each do |arr|
      next if arr[:edge] < 0
      arr2[arr[:edge]] << [arr[:edge_pos], arr]
    end
    arr2.each { |arr5| arr5.sort_by! { |arr4| arr4[0] } }
    arr6 = arr2.map { |arr5| arr5.map { |arr4| arr4[0].to_s }.join("_") }
    [arr6, drills]
  end
  def _c6e26747(panel, data, tf)
    _61b21e0a = data[0]
    arr2 = data[1].map do |rec|
      kids = [rec[:d], rec[:depth]]
      if rec[:depth] > 0 && rec[:poly]
        rec[:poly].each do |pt2|
          pt = pt2.transform(tf)
          kids << [pt.x.to_f, pt.y.to_f, pt.z.to_f]
        end
      else
        pt = rec[:pos].transform(tf)
        kids << [pt.x.to_f, pt.y.to_f, pt.z.to_f]
      end
      kids
    end
    panel.set_attribute("ABF", "drills-desc", [_61b21e0a, arr2])
  end
end
KSU::Cutting.extend(KSU::Detail)
module KSU::Detail
  def self._90be1fb4(id)
    id && !id.to_s.strip.empty? && id.to_s.strip != "0"
  end
end
