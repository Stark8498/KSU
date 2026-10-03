module KSU::Collect
  def _33959628(h18, _3ef84888, flag = nil)
    model = Sketchup.active_model
    flag = nil if flag && flag.empty?
    arr = []
    _17ee8011(flag || model.entities, arr, {})
    return _9be3af68(:empty, h18, _3ef84888, flag) if arr.empty?
    @flag6 = true
    @_20ca63d7 = h18
    @_aac687ed = _3ef84888
    @_a14b1f13 = flag
    @arr30 = arr
    @arr50 = []
    @h28 = {}
    @arr59 = []
    @num9 = 0
    @num7 = 0.0
    @num12 = 0
    @str = "Đang chuẩn bị"
    KSU.select_tool(KSU::Nest::Progress) unless model.tools.active_tool.instance_of?(KSU::Nest::Progress)
    model.active_view.invalidate
    @_d3fa94d5 = UI.start_timer(0, true) { _41789749 }
  end
  def _41789749
    sweep = @arr30.length
    return _b3aa40f8 if @num9 >= sweep
    _b32f69ac = Time.now
    while @num9 < sweep && Time.now - _b32f69ac < 0.05
      g = @arr30[@num9]
      @num9 += 1
      next unless g && g.valid?
      id = g.get_attribute("ABF", "board-index")
      if id && @h28[id]
        h18 = @_20ca63d7
        _3ef84888 = @_aac687ed
        _4effcb0e = @_a14b1f13
        _90d58cd9
        return _9be3af68(:dup_ids, h18, _3ef84888, _4effcb0e)
      end
      @h28[id] = true if id
      grp, @num7 = _dd36ed49(g, @_20ca63d7, @num7)
      next if grp == :skip
      if grp
        @arr50 << grp
      else
        @arr59 << g.name.to_s
      end
    end
    @num12 = (@num9 * 100.0 / sweep).round
    KSU::View.view.invalidate
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def _b3aa40f8
    h18 = @_20ca63d7
    _3ef84888 = @_aac687ed
    _4effcb0e = @_a14b1f13
    parts = @arr50
    arr = @arr59
    _90d58cd9
    unless arr.empty?
      UI.messagebox("Cảnh báo! Có lỗi xảy ra khi tạo đường cắt của tấm.")
    end
    return _9be3af68(:empty, h18, _3ef84888, _4effcb0e) if parts.empty?
    start(h18, _b0282735(parts, h18))
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def _9be3af68(err, h18, _3ef84888, _4effcb0e = nil)
    clear_progress
    unless _3ef84888
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    run(h18, _4effcb0e) if ask_relabel(err)
  end
  def _90d58cd9
    UI.stop_timer(@_d3fa94d5) if @_d3fa94d5
    @_d3fa94d5 = nil
    @flag6 = false
    @_20ca63d7 = nil
    @_aac687ed = nil
    @_a14b1f13 = nil
    @arr30 = nil
    @arr50 = nil
    @h28 = nil
    @arr59 = nil
    @num9 = nil
    @num7 = nil
  end
  def _2d469ec2
    return unless @flag6
    _90d58cd9
    @num12 = nil
    @str = nil
  end
  def _17ee8011(ents, out, seen)
    ents.each do |ent|
      next unless KSU.container?(ent) && ent.valid?
      next if _2409a439(ent)
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      next if ent.get_attribute("ABF", "is-flatten") || ent.get_attribute("ABF", "is-flatten-root") ||
              ent.get_attribute("ABF", "is-nesting-root")
      flag = ent.is_a?(Sketchup::Group) || _a1ffed00(ent)
      if flag && KSU::Cutting.board_faces(ent, KSU::Cutting.tf_of(ent))
        out << ent
      else
        kids = KSU.entities_in(ent)
        _17ee8011(kids, out, seen) if kids
      end
    end
  end
  def _2409a439(ent)
    return true if ent.hidden?
    _2cb52d46 = ent.layer
    return false unless _2cb52d46
    return true unless _2cb52d46.visible?
    if _2cb52d46.respond_to?(:folder)
      f = _2cb52d46.folder
      while f
        return true unless f.visible?
        f = f.folder
      end
    end
    false
  end
  def _a1ffed00(ent)
    return true if ent.get_attribute("ABF", "is-board") || ent.get_attribute("ABF", "board-index")
    !!KSU::Cutting.kids_with_attr(ent, "is-label")
  end
  def _dd36ed49(g, h18, _c348cdef)
    tf = KSU::Cutting.tf_of(g)
    b2 = KSU::Cutting.board_faces(g, tf)
    return [nil, _c348cdef] unless b2
    thickness_mm = _2c9761fb(b2, tf)
    return [:skip, _c348cdef] if thickness_mm < 1.0 || thickness_mm > 50.0
    face = KSU::Cutting.front_face(g, b2)
    mat = _6f88583c(g, face)
    return [:skip, _c348cdef] if h18[:materials] && !h18[:materials]["#{mat}#{thickness_mm}"]
    out = face.normal.transform(tf).axes
    tf_axes = Geom::Transformation.axes(ORIGIN, out[0], out[1], out[2]).inverse
    arr4 = KSU::Cutting.kids_with_attr(g, "is-label")
    return [:skip, _c348cdef] unless arr4
    vec = arr4[0].transformation.xaxis.transform(tf_axes * tf)
    tr2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, _b33d5052(vec, Y_AXIS.reverse))
    max_eb = KSU::Cutting.edgeband_spec(g, thickness_mm)
    anchor = (tr2 * tf_axes * tf).origin
    tr3 = Geom::Transformation.translation([-anchor.x, -anchor.y, -anchor.z])
    _984e016d = tr3 * tr2 * tf_axes * tf
    small_size = KSU::Cutting._f7a09903(face, tf)
    arr3 = KSU::Cutting._e4e88386(small_size)
    arr2 = KSU::Cutting._4605a894(g, face, _984e016d, max_eb[0], arr3[0], arr3[1])
    return [nil, _c348cdef] if arr2[:loops].empty?
    bounds = arr2[:loops].map do |arr|
      KSU::Simplify._c71fe5d3(arr[:pts].map { |_23505ef9| [_23505ef9.x.to_f, _23505ef9.y.to_f] }, arr[:outer])
    end
    lx = nil
    flag = nil
    ly = nil
    bounds.each do |arr|
      arr.each do |_23505ef9|
        lx = _23505ef9[0] if lx.nil? || _23505ef9[0] < lx
        flag = _23505ef9[0] if flag.nil? || _23505ef9[0] > flag
        ly = _23505ef9[1] if ly.nil? || _23505ef9[1] < ly
      end
    end
    return [nil, _c348cdef] unless lx
    ax = _c348cdef - flag
    ay = -ly
    _c348cdef -= (flag - lx + 1)
    tr = Geom::Transformation.translation([ax, ay, 0])
    part_tf = tr3 * tr * tr2 * tf_axes * tf
    drills = KSU::Cutting._32f2e5fc(g, face, _984e016d)
    drills[1].each do |len2d|
      if len2d[:depth] > 0 && len2d[:poly]
        len2d[:poly].map! { |_23505ef9| _23505ef9.transform(tr) }
      else
        len2d[:pos] = len2d[:pos].transform(tr)
      end
    end
    bottom = KSU::Cutting._babeb881(g, face, tf)
    grp = {
      group: g, up_face: face, tf: tf, part_tf: part_tf,
      two_sided: !bottom[:bottom].empty?,
      outer_index: arr2[:loops].find_index { |arr| arr[:outer] } || 0,
      bounds_mm: bounds.map { |arr| arr.map { |_23505ef9| [(_23505ef9[0] + ax) * 25.4, (_23505ef9[1] + ay) * 25.4] } },
      cutting_lines: arr2[:loops].map { |arr| arr[:pts].map { |_23505ef9| _23505ef9.transform(tr) } },
      edge_band_lines: arr2[:edge_band_lines].map { |arr| arr.map { |_23505ef9| _23505ef9.transform(tr) } },
      edge_band_desc: arr2[:edge_band_desc].map do |len2d|
        { p0: len2d[:p0].transform(tr), p1: len2d[:p1].transform(tr), name: len2d[:name], kind: len2d[:kind] }
      end,
      drills: drills, arrow: arr3, max_eb: max_eb[1],
      material: mat,
      thickness_mm: thickness_mm,
      rotatable: rotatable(g, h18, mat, thickness_mm)
    }
    [grp, _c348cdef]
  end
  def rotatable(g, h18, mat, thickness_mm)
    rotate_cfg = h18[:rotate_cfg]
    return false unless rotate_cfg.is_a?(Hash)
    color = rotate_cfg["#{mat}#{thickness_mm}"]
    return false unless color
    return true if color[:on]
    arr2 = _099ecc27(color[:kw])
    return false if arr2.empty?
    name = g.name.to_s.downcase
    arr2.any? { |_0cc812ea| name.include?(_0cc812ea) }
  end
  def _099ecc27(stream)
    stream.to_s.split(/[,\n]/).map { |s| s.strip.downcase }.reject(&:empty?)
  end
  def _b33d5052(vec, b)
    ang = Math.atan2(vec.cross(b).z, vec.dot(b))
    ang += 2 * Math::PI if ang < 0
    ang
  end
  def _6f88583c(g, face)
    mat = g.material ? g.material.name : (face.material ? face.material.name : "")
    mat = mat.strip
    mat = mat[1..-2] if mat.length > 1 && mat[0] == "[" && mat[-1] == "]"
    mat.to_s
  end
  def _2c9761fb(b2, tf)
    bb = b2[0].bounds.center.transform(tf)
    bb2 = b2[1].bounds.center.transform(tf)
    vec = b2[0].normal.transform(tf)
    KSU::Cutting.d(bb.distance_to_plane([bb2, vec]))
  end
  def _b0282735(parts, h18 = nil)
    h = {}
    materials = []
    parts.each do |arr|
      key = "#{arr[:material]}#{arr[:thickness_mm]}"
      unless h[key]
        h[key] = { material: arr[:material], thickness_mm: arr[:thickness_mm], parts: [] }
        materials << key
      end
      h[key][:parts] << arr
    end
    rows = materials.map { |k| h[k] }
    rows.sort_by! { |half| [half[:thickness_mm].to_f, half[:material].to_s.downcase] }
    mat_order = h18 && h18[:mat_order]
    if mat_order.is_a?(Hash) && !mat_order.empty?
      rows = rows.each_with_index.sort_by do |half, _a4ab9a59|
        [mat_order.fetch("#{half[:material]}#{half[:thickness_mm]}", 1 << 20), _a4ab9a59]
      end.map { |half, _part| half }
    end
    _3758e659(rows)
    rows
  end
  def _3758e659(rows)
    rows.each do |half|
      half[:name] = if half[:material].empty?
                      "#{half[:thickness_mm]}mm"
                    else
                      "#{half[:material]} - #{half[:thickness_mm]}mm"
                    end
    end
  end
end
KSU::Nest.extend(KSU::Collect)
