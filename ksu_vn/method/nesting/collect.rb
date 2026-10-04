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
    t_slice = Time.now
    while @done_n < total && Time.now - t_slice < 0.05
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
      next if hidden_by_layer?(ent)
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      next if ent.get_attribute("ABF", "is-flatten") || ent.get_attribute("ABF", "is-flatten-root") ||
              ent.get_attribute("ABF", "is-nesting-root")
      flag = ent.is_a?(Sketchup::Group) || board_like?(ent)
      if flag && KSU::Cutting.board_faces(ent, KSU::Cutting.tf_of(ent))
        out << ent
      else
        kids = KSU.entities_in(ent)
        gather_boards(kids, out, seen) if kids
      end
    end
  end
  def hidden_by_layer?(ent)
    return true if ent.hidden?
    layer = ent.layer
    return false unless layer
    return true unless layer.visible?
    if layer.respond_to?(:folder)
      f = layer.folder
      while f
        return true unless f.visible?
        f = f.folder
      end
    end
    false
  end
  def board_like?(ent)
    return true if ent.get_attribute("ABF", "is-board") || ent.get_attribute("ABF", "board-index")
    !!KSU::Cutting.kids_with_attr(ent, "is-label")
  end
  def part_of(g, cfg, seen2)
    tf = KSU::Cutting.tf_of(g)
    b2 = KSU::Cutting.board_faces(g, tf)
    return [nil, seen2] unless b2
    thickness_mm = thickness_of(b2, tf)
    return [:skip, seen2] if thickness_mm < 1.0 || thickness_mm > 50.0
    face = KSU::Cutting.front_face(g, b2)
    mat = material_of(g, face)
    return [:skip, seen2] if cfg[:materials] && !cfg[:materials]["#{mat}#{thickness_mm}"]
    out = face.normal.transform(tf).axes
    tf_axes = Geom::Transformation.axes(ORIGIN, out[0], out[1], out[2]).inverse
    arr4 = KSU::Cutting.kids_with_attr(g, "is-label")
    return [:skip, seen2] unless arr4
    vec = arr4[0].transformation.xaxis.transform(tf_axes * tf)
    tr2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, vec_angle(vec, Y_AXIS.reverse))
    max_eb = KSU::Cutting.edgeband_spec(g, thickness_mm)
    anchor = (tr2 * tf_axes * tf).origin
    tr3 = Geom::Transformation.translation([-anchor.x, -anchor.y, -anchor.z])
    world_tf2 = tr3 * tr2 * tf_axes * tf
    small_size = KSU::Cutting.short_side(face, tf)
    arr3 = KSU::Cutting.arrow_sizes(small_size)
    rec = KSU::Cutting.cut_loops(g, face, world_tf2, max_eb[0], arr3[0], arr3[1])
    return [nil, seen2] if rec[:loops].empty?
    bnds = rec[:loops].map do |arr|
      KSU::Simplify.simplify_poly(arr[:pts].map { |pt| [pt.x.to_f, pt.y.to_f] }, arr[:outer])
    end
    lx = nil
    flag = nil
    ly = nil
    bnds.each do |arr|
      arr.each do |pt|
        lx = pt[0] if lx.nil? || pt[0] < lx
        flag = pt[0] if flag.nil? || pt[0] > flag
        ly = pt[1] if ly.nil? || pt[1] < ly
      end
    end
    return [nil, seen2] unless lx
    ax = seen2 - flag
    ay = -ly
    seen2 -= (flag - lx + 1)
    tr = Geom::Transformation.translation([ax, ay, 0])
    part_tf = tr3 * tr * tr2 * tf_axes * tf
    found = KSU::Cutting.side_drills(g, face, world_tf2)
    found[1].each do |len2d|
      if len2d[:depth] > 0 && len2d[:poly]
        len2d[:poly].map! { |pt| pt.transform(tr) }
      else
        len2d[:pos] = len2d[:pos].transform(tr)
      end
    end
    faces = KSU::Cutting.split_by_face(g, face, tf)
    grp = {
      group: g, up_face: face, tf: tf, part_tf: part_tf,
      two_sided: !faces[:bottom].empty?,
      outer_index: rec[:loops].find_index { |arr| arr[:outer] } || 0,
      bounds_mm: bnds.map { |arr| arr.map { |pt| [(pt[0] + ax) * 25.4, (pt[1] + ay) * 25.4] } },
      cutting_lines: rec[:loops].map { |arr| arr[:pts].map { |pt| pt.transform(tr) } },
      edge_band_lines: rec[:edge_band_lines].map { |arr| arr.map { |pt| pt.transform(tr) } },
      edge_band_desc: rec[:edge_band_desc].map do |len2d|
        { p0: len2d[:p0].transform(tr), p1: len2d[:p1].transform(tr), name: len2d[:name], kind: len2d[:kind] }
      end,
      drills: found, arrow: arr3, max_eb: max_eb[1],
      material: mat,
      thickness_mm: thickness_mm,
      rotatable: rotatable(g, cfg, mat, thickness_mm)
    }
    [grp, seen2]
  end
  def rotatable(g, cfg, mat, thickness_mm)
    rotate_cfg = cfg[:rotate_cfg]
    return false unless rotate_cfg.is_a?(Hash)
    color = rotate_cfg["#{mat}#{thickness_mm}"]
    return false unless color
    return true if color[:on]
    arr2 = split_keywords(color[:kw])
    return false if arr2.empty?
    name = g.name.to_s.downcase
    arr2.any? { |kw| name.include?(kw) }
  end
  def split_keywords(stream)
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
