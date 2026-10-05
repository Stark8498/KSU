module KSU::Collect
  def start_collect(job_cfg, ask, saved_sel)
    model = Sketchup.active_model
    saved_sel = nil if saved_sel && saved_sel.empty?
    ents = collect_parts(saved_sel || model.entities)
    return collect_failed(:empty, job_cfg, ask, saved_sel) if ents.empty?
    @collect_cfg, @collect_ids, @collect_opts, @boards = job_cfg, ask, saved_sel, ents
    @_93fea7ff, @seen_ids, @_43fe5d35, @done_n, @total_area, @arr4 = [], {}, [], 0, 0.0, {}
    @collecting, @progress, @str = true, 0, "Đang chuẩn bị"
    KSU.select_tool(KSU::Nest::Progress) unless model.tools.active_tool.instance_of?(KSU::Nest::Progress)
    model.active_view.invalidate
    @collect_timer = UI.start_timer(0, true) { collect_tick }
  end
  def collect_tick
    total = @boards.length
    return collect_done if @done_n >= total
    t_slice = Time.now
    while @done_n < total && Time.now - t_slice < 0.05
      grp2 = @boards[@done_n]
      @done_n += 1
      next unless grp2.valid?
      id = grp2.get_attribute("ABF", "board-index")
      return collect_failed(:dup_ids, *restart_collect) if id && @seen_ids[id]
      @seen_ids[id] = true if id
      grp, @total_area = part_of(grp2, @collect_cfg, @total_area)
      next if grp == :skip
      grp ? @_93fea7ff << grp : @_43fe5d35 << part_id(grp2)
    end
    @progress = (@done_n * 100.0 / total).round
    set_status(status_text)
  rescue StandardError => e
    one_group(e)
  end
  def collect_done
    arr29, arr = @_93fea7ff, @_43fe5d35
    job_cfg, ask, saved_sel = restart_collect
    notify("Cảnh báo: có vấn đề khi tạo đường biên với tấm #{tail_pt(arr.uniq)}.", arr.uniq, false) unless arr.empty?
    return collect_failed(:empty, job_cfg, ask, saved_sel) if arr29.empty?
    start3(job_cfg, group_by_material(arr29, job_cfg))
  rescue StandardError => e
    one_group(e)
  end
  def collect_failed(_35c8f76f, job_cfg, ask, saved_sel)
    @progress = @str = nil
    set_status(nil)
    return apply_label_plan(job_cfg, saved_sel) if ask && (_35c8f76f != :dup_ids || UI.messagebox("Có vấn đề với dữ liệu nhãn. Tự động gắn lại nhãn?", MB_YESNO) == IDYES)
    KSU.abort_batch
    clear_status
  end
  def restart_collect
    UI.stop_timer(@collect_timer) if @collect_timer
    _e2fd4a2e = [@collect_cfg, @collect_ids, @collect_opts]
    @collect_timer = @collect_cfg = @collect_ids = @collect_opts = @boards = nil
    @_93fea7ff = @seen_ids = @_43fe5d35 = @done_n = @total_area = @arr4 = @collecting = nil
    _e2fd4a2e
  end
  def stop_collect
    return unless @collecting
    restart_collect
    @progress = @str = nil
    KSU.abort_batch
    UI.start_timer(0, false) { clear_status }
  end
  def collect_parts(ents, out = [], arr = {}, ref_p1 = !!KSU::Settings.get("bo_qua_doi_tuong_an", true, "nesting"))
    ents.each do |grp|
      next unless KSU.container?(grp) && grp.valid? && !(ref_p1 && grp.hidden?)
      tag = ref_p1 && grp.layer
      tag = tag.respond_to?(:folder) && tag.folder while tag && tag.visible?
      next if tag || arr[grp.entityID]
      arr[grp.entityID] = true
      next if %w[is-flatten is-flatten-root is-nesting-root].any? { |k| grp.get_attribute("ABF", k) }
      path = grp.is_a?(Sketchup::Group) || grp.get_attribute("ABF", "is-board") || grp.get_attribute("ABF", "board-index") ||
                     KSU::Cutting.kids_with_attr(grp, "is-label")
      _5a718701 = board_like?(grp) if path
      next out << grp if _5a718701&.last && (arr[grp.entityID] = _5a718701)
      collect_parts(KSU.entities_in(grp) || [], out, arr, ref_p1)
    end
    out
  end
  def board_like?(e)
    tf = KSU::Cutting.tf_of(e)
    [tf, KSU::Cutting.board_faces(e, tf)]
  end
  def part_from_face(face, _5a718701 = nil, _7c636277 = true)
    tf, b2 = _5a718701 || board_like?(face)
    return unless b2
    pt, bb = b2.map { |f| f.bounds.center.transform(tf) }
    thickness_mm = KSU::Cutting.d(pt.distance_to_plane([bb, b2[0].normal.transform(tf)]))
    return :skip if thickness_mm < 1.0 || thickness_mm > 50.0
    face2 = KSU::Cutting.front_face(face, b2) if _7c636277 || !face.material
    mat = (face.material || face2.material)&.name.to_s.strip
    [mat[0] == "[" && mat[-1] == "]" ? mat[1..-2] : mat, thickness_mm, tf, face2]
  end
  def part_of(grp2, job_cfg, seen2)
    mat, thickness_mm, tf, face = sheet_type = part_from_face(grp2)
    return [sheet_type, seen2] unless sheet_type.is_a?(Array)
    return [:skip, seen2] if job_cfg[:materials] && !job_cfg[:materials]["#{mat}#{thickness_mm}"]
    tf_axes = Geom::Transformation.axes(ORIGIN, *face.normal.transform(tf).axes).inverse
    groups = KSU::Cutting.kids_with_attr(grp2, "is-label")
    return [:skip, seen2] unless groups
    vec = groups[0].transformation.xaxis.transform(tf_axes * tf)
    ang = Math.atan2(vec.cross(Y_AXIS.reverse).z, vec.dot(Y_AXIS.reverse))
    tr2 = Geom::Transformation.rotation(ORIGIN, Z_AXIS, ang < 0 ? ang + 2 * Math::PI : ang)
    max_eb = KSU::Cutting.edgeband_spec(grp2, thickness_mm, @arr4)
    pt2 = Geom::Transformation.translation((tr2 * tf_axes * tf).origin.to_a.map { |c| -c })
    world_tf2 = pt2 * tr2 * tf_axes * tf
    rec = KSU::Cutting.cut_loops(grp2, face, world_tf2, max_eb[0], *KSU::Cutting.arrow_sizes(KSU::Cutting.short_side(face, tf)))
    return [nil, seen2] if rec[:loops].empty?
    bnds = rec[:loops].map { |arr| KSU::Simplify.simplify_poly(arr[:pts].map { |pt| [pt.x.to_f, pt.y.to_f] }, arr[:outer]) }
    lx, _2d7e228f, _b0566a11 = KSU::Nesting.poly_bounds(bnds.flatten(1))
    ax, ay = seen2 - _b0566a11, -_2d7e228f
    seen2 -= (_b0566a11 - lx + 1)
    tr = Geom::Transformation.translation([ax, ay, 0])
    found = KSU::Cutting.side_drills(grp2, face, world_tf2)
    found[1].each do |len2d|
      if len2d[:depth] > 0 && len2d[:poly]
        len2d[:poly].map! { |pt| pt.transform(tr) }
      else
        len2d[:pos] = len2d[:pos].transform(tr)
      end
    end
    [{
      group: grp2, up_face: face, tf: tf, part_tf: pt2 * tr * tr2 * tf_axes * tf,
      two_sided: !KSU::Cutting.split_by_face(grp2, face, tf)[:bottom].empty?,
      outer_index: rec[:loops].find_index { |arr| arr[:outer] } || 0,
      bounds_mm: bnds.map { |arr| arr.map { |pt| [(pt[0] + ax) * 25.4, (pt[1] + ay) * 25.4] } },
      cutting_lines: rec[:loops].map { |arr| arr[:pts].map { |pt| pt.transform(tr) } },
      edge_band_lines: rec[:edge_band_lines].map { |arr| arr.map { |pt| pt.transform(tr) } },
      edge_band_desc: rec[:edge_band_desc].map do |len2d|
        { p0: len2d[:p0].transform(tr), p1: len2d[:p1].transform(tr), name: len2d[:name], kind: len2d[:kind] }
      end,
      drills: found, material: mat, thickness_mm: thickness_mm,
      rotatable: rotatable(grp2, job_cfg, mat, thickness_mm)
    }, seen2]
  end
  def rotatable(grp, job_cfg, mat, thickness_mm)
    rotate_cfg = job_cfg[:rotate_cfg]
    c = rotate_cfg.is_a?(Hash) && rotate_cfg["#{mat}#{thickness_mm}"]
    return false unless c
    name = grp.name.to_s.downcase
    c[:on] || c[:kw].to_s.split(/[,\n]/).map { |s| s.strip.downcase }.reject(&:empty?).any? { |kw| name.include?(kw) }
  end
  def group_by_material(arr29, job_cfg)
    rows = fill_sizes(arr29.group_by { |arr2| "#{arr2[:material]}#{arr2[:thickness_mm]}" }.values.map do |arr|
      { material: arr[0][:material], thickness_mm: arr[0][:thickness_mm], parts: arr }
    end)
    mat_order = job_cfg && job_cfg[:mat_order]
    mat_order.is_a?(Hash) ? rows.sort_by.with_index { |half, i| [mat_order.fetch("#{half[:material]}#{half[:thickness_mm]}", 1 << 20), i] } : rows
  end
  def fill_sizes(rows)
    rows.sort_by { |half| [half[:thickness_mm].to_f, half[:material].to_s.downcase] }.each { |half| half[:name] = "#{"#{half[:material]} - " unless half[:material].empty?}#{half[:thickness_mm]}mm" }
  end
end
KSU::Nest.extend(KSU::Collect)
