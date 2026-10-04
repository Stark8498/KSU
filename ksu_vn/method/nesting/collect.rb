module KSU::Collect
  def start_collect(cfg, ask, saved_sel = nil)
    model = Sketchup.active_model
    saved_sel = nil if saved_sel && saved_sel.empty?
    arr = []
    gather_boards(saved_sel || model.entities, arr, {})
    return collect_failed(:empty, cfg, ask, saved_sel) if arr.empty?
    @collecting = true
    @collect_cfg = cfg
    @collect_ask = ask
    @collect_scope = saved_sel
    @boards = arr
    @collected = []
    @seen_ids = {}
    @failed_names = []
    @done_n = 0
    @total_area = 0.0
    @progress = 0
    @str = "Đang chuẩn bị"
    KSU.select_tool(KSU::Nest::Progress) unless model.tools.active_tool.instance_of?(KSU::Nest::Progress)
    model.active_view.invalidate
    @collect_timer = UI.start_timer(0, true) { collect_tick }
  end
  def collect_tick
    total = @boards.length
    return collect_done if @done_n >= total
    _b32f69ac = Time.now
    while @done_n < total && Time.now - _b32f69ac < 0.05
      g = @boards[@done_n]
      @done_n += 1
      next unless g && g.valid?
      id = g.get_attribute("ABF", "board-index")
      if id && @seen_ids[id]
        cfg = @collect_cfg
        ask = @collect_ask
        saved_sel = @collect_scope
        clear_collect
        return collect_failed(:dup_ids, cfg, ask, saved_sel)
      end
      @seen_ids[id] = true if id
      grp, @total_area = part_of(g, @collect_cfg, @total_area)
      next if grp == :skip
      if grp
        @collected << grp
      else
        @failed_names << g.name.to_s
      end
    end
    @progress = (@done_n * 100.0 / total).round
    KSU::View.view.invalidate
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def collect_done
    cfg = @collect_cfg
    ask = @collect_ask
    saved_sel = @collect_scope
    parts = @collected
    arr = @failed_names
    clear_collect
    unless arr.empty?
      UI.messagebox("Cảnh báo! Có lỗi xảy ra khi tạo đường cắt của tấm.")
    end
    return collect_failed(:empty, cfg, ask, saved_sel) if parts.empty?
    start3(cfg, jobs_of(parts, cfg))
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def collect_failed(err, cfg, ask, saved_sel = nil)
    clear_progress
    unless ask
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    run2(cfg, saved_sel) if ask_relabel(err)
  end
  def clear_collect
    UI.stop_timer(@collect_timer) if @collect_timer
    @collect_timer = nil
    @collecting = false
    @collect_cfg = nil
    @collect_ask = nil
    @collect_scope = nil
    @boards = nil
    @collected = nil
    @seen_ids = nil
    @failed_names = nil
    @done_n = nil
    @total_area = nil
  end
  def stop_collect
    return unless @collecting
    clear_collect
    @progress = nil
    @str = nil
  end
  def gather_boards(ents, out, seen)
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
        gather_boards(kids, out, seen) if kids
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
  def part_of(g, cfg, _c348cdef)
    tf = KSU::Cutting.tf_of(g)
    b2 = KSU::Cutting.board_faces(g, tf)
    return [nil, _c348cdef] unless b2
    thickness_mm = thickness_of(b2, tf)
    return [:skip, _c348cdef] if thickness_mm < 1.0 || thickness_mm > 50.0
    face = KSU::Cutting.front_face(g, b2)
    mat = material_of(g, face)
    return [:skip, _c348cdef] if cfg[:materials] && !cfg[:materials]["#{mat}#{thickness_mm}"]
    out = face.normal.transform(tf).axes
    tf_axes = Geom::Transformation.axes(ORIGIN, out[0], out[1], out[2]).inverse
    arr4 = KSU::Cutting.kids_with_attr(g, "is-label")
    return [:skip, _c348cdef] unless arr4
    vec = arr4[0].transformation.xaxis.transform(tf_axes * tf)
    tr2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, vec_angle(vec, Y_AXIS.reverse))
    max_eb = KSU::Cutting.edgeband_spec(g, thickness_mm)
    anchor = (tr2 * tf_axes * tf).origin
    tr3 = Geom::Transformation.translation([-anchor.x, -anchor.y, -anchor.z])
    _984e016d = tr3 * tr2 * tf_axes * tf
    small_size = KSU::Cutting.short_side(face, tf)
    arr3 = KSU::Cutting.arrow_sizes(small_size)
    rec = KSU::Cutting.cut_loops(g, face, _984e016d, max_eb[0], arr3[0], arr3[1])
    return [nil, _c348cdef] if rec[:loops].empty?
    bnds = rec[:loops].map do |arr|
      KSU::Simplify.simplify_poly(arr[:pts].map { |_23505ef9| [_23505ef9.x.to_f, _23505ef9.y.to_f] }, arr[:outer])
    end
    lx = nil
    flag = nil
    ly = nil
    bnds.each do |arr|
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
    found = KSU::Cutting.side_drills(g, face, _984e016d)
    found[1].each do |len2d|
      if len2d[:depth] > 0 && len2d[:poly]
        len2d[:poly].map! { |_23505ef9| _23505ef9.transform(tr) }
      else
        len2d[:pos] = len2d[:pos].transform(tr)
      end
    end
    faces = KSU::Cutting.split_by_face(g, face, tf)
    grp = {
      group: g, up_face: face, tf: tf, part_tf: part_tf,
      two_sided: !faces[:bottom].empty?,
      outer_index: rec[:loops].find_index { |arr| arr[:outer] } || 0,
      bounds_mm: bnds.map { |arr| arr.map { |_23505ef9| [(_23505ef9[0] + ax) * 25.4, (_23505ef9[1] + ay) * 25.4] } },
      cutting_lines: rec[:loops].map { |arr| arr[:pts].map { |_23505ef9| _23505ef9.transform(tr) } },
      edge_band_lines: rec[:edge_band_lines].map { |arr| arr.map { |_23505ef9| _23505ef9.transform(tr) } },
      edge_band_desc: rec[:edge_band_desc].map do |len2d|
        { p0: len2d[:p0].transform(tr), p1: len2d[:p1].transform(tr), name: len2d[:name], kind: len2d[:kind] }
      end,
      drills: found, arrow: arr3, max_eb: max_eb[1],
      material: mat,
      thickness_mm: thickness_mm,
      rotatable: rotatable(g, cfg, mat, thickness_mm)
    }
    [grp, _c348cdef]
  end
  def rotatable(g, cfg, mat, thickness_mm)
    rotate_cfg = cfg[:rotate_cfg]
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
  def vec_angle(vec, b)
    ang = Math.atan2(vec.cross(b).z, vec.dot(b))
    ang += 2 * Math::PI if ang < 0
    ang
  end
  def material_of(g, face)
    mat = g.material ? g.material.name : (face.material ? face.material.name : "")
    mat = mat.strip
    mat = mat[1..-2] if mat.length > 1 && mat[0] == "[" && mat[-1] == "]"
    mat.to_s
  end
  def thickness_of(b2, tf)
    bb = b2[0].bounds.center.transform(tf)
    bb2 = b2[1].bounds.center.transform(tf)
    vec = b2[0].normal.transform(tf)
    KSU::Cutting.d(bb.distance_to_plane([bb2, vec]))
  end
  def jobs_of(parts, cfg = nil)
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
    mat_order = cfg && cfg[:mat_order]
    if mat_order.is_a?(Hash) && !mat_order.empty?
      rows = rows.each_with_index.sort_by do |half, i|
        [mat_order.fetch("#{half[:material]}#{half[:thickness_mm]}", 1 << 20), i]
      end.map { |half, _part| half }
    end
    fill_sizes(rows)
    rows
  end
  def fill_sizes(rows)
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
