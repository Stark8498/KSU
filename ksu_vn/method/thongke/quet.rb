module KSU::Thongke::Quet
  def self.skip_root?(ent)
    ent.get_attribute("ABF", "is-flatten") || ent.get_attribute("ABF", "is-nesting-root") ||
      ent.get_attribute("ABF", "is-bottom-sheet")
  end
  def self.all_roots
    Sketchup.active_model.entities.select { |ent| KSU.container?(ent) }
  end
  def self.selected_roots
    Sketchup.active_model.selection.to_a.select { |ent| KSU.container?(ent) }
  end
  def self.walk_boards(ents, path, ids, out, seen)
    ents.each do |ent|
      next unless KSU.container?(ent) && ent.valid?
      next if seen[ent.entityID] || skip_root?(ent)
      seen[ent.entityID] = true
      if ent.get_attribute("ABF", "is-board")
        out << [ent, path] if ids.nil? || ids[ent.get_attribute("ABF", "board-index").to_i]
      end
      kids = KSU.entities_in(ent)
      walk_boards(kids, path + [ent], ids, out, seen) if kids
    end
    out
  end
  def self.all_boards(scope)
    walk_boards(scope, [], nil, [], {}).map(&:first)
  end
  def self.boards_by_index(keys)
    ids = {}
    keys.each { |id| ids[id.to_i] = true }
    walk_boards(Sketchup.active_model.entities, [], ids, [], {})
  end
  def self.expand_roots(scope)
    scope.flat_map { |ent|
      next [ent] unless ent.get_attribute("ABF", "is-nesting-root")
      (KSU.entities_in(ent) || []).select { |s| KSU.container?(s) }
    }
  end
  def self.each_sheet(scope)
    expand_roots(scope).each do |grp|
      sheet = grp.get_attribute("ABF", "sheet-id")
      yield grp, sheet if sheet
    end
  end
  def self.sheet_of_board
    h = {}
    each_sheet(all_roots) do |_73dc38ac, sheet|
      (KSU.entities_in(_73dc38ac) || []).each do |grp|
        next unless KSU.container?(grp)
        pid = grp.get_attribute("ABF", "board-index")
        h[pid] = sheet if pid
      end
    end
    h
  end
  def self.long_axis(font, tf)
    KSU::Cutting._b344f39a(font.bounds, tf)[2][1]
  end
  def self.label_group(node)
    arr = KSU::Cutting.kids_with_attr(node, "is-label")
    arr ? arr[0] : nil
  end
  def self.extent_along(pts, axis)
    _c04fb39c = axis[1].normalize
    lo, hi = pts.map { |_23505ef9| axis[0].vector_to(_23505ef9).dot(_c04fb39c) }.minmax
    lo ? hi - lo : 0.0
  end
  def self.add_edgebands(arr, node, tf, vec, thick_mm, lbl)
    src = KSU::Cutting.edgeband_spec(node, thick_mm)[0]
    src.each do |f, thickness, disp, fields, stat, joint|
      arr[:edgeband_thickness][disp] = (thickness * 25.4).round(3)
      arr[:edgeband_base][disp] = fields[0].to_s
      next if stat == false
      line_vec = vec.cross(f.normal)
      next if line_vec.length == 0
      f.edges.each do |ent|
        next unless ent.line[1].parallel?(line_vec)
        len = ent.length(tf).to_f
        len /= 2.0 if joint == "chap"
        arr[:edgeband_lengths][disp] = (arr[:edgeband_lengths][disp] || 0) + len
        break
      end
    end
  end
  def self.board_record(node)
    tf = KSU::Label.world_tf(node)
    src = KSU::Cutting.board_faces(node, tf)
    return nil unless src
    arr = { edgeband_lengths: {}, edgeband_thickness: {}, edgeband_base: {} }
    idx = node.get_attribute("ABF", "board-index") || 0
    name = KSU::Label.label_text(node).to_s
    name = idx.to_s if name.empty?
    arr[:index] = idx
    arr[:name] = name
    arr[:material] = node.material ? node.material.display_name : ""
    arr[:code_ns] = [
      node.get_attribute("ABF", "code_n1"),
      node.get_attribute("ABF", "code_n2"),
      node.get_attribute("ABF", "code_n3"),
    ]
    font = src[0]
    lbl = label_group(node)
    vec = lbl ? lbl.transformation.xaxis.transform(tf) : long_axis(font, tf)
    ref_p2 = font.normal.transform(tf)
    pts = font.outer_loop.vertices.map { |v| v.position.transform(tf) }
    p2 = src[1].outer_loop.vertices[0].position.transform(tf)
    thickness = p2.distance_to_plane([pts[0], ref_p2])
    ext_x = extent_along(pts, [pts[0], vec])
    ext_y = extent_along(pts, [pts[0], vec.cross(ref_p2)])
    add_edgebands(arr, node, tf, font.normal, thickness.to_f * 25.4, lbl)
    arr[:length] = [ext_x, ext_y].max.to_f
    arr[:width] = [ext_x, ext_y].min.to_f
    arr[:thickness] = thickness
    arr
  rescue StandardError
    nil
  end
  def self.list_boards(scope)
    arr3 = sheet_of_board
    arr2 = []
    all_boards(scope).each do |g|
      arr = board_record(g)
      next unless arr
      arr[:sheet] = arr3[arr[:index]] || -1
      arr2 << arr
    end
    arr2.each do |arr|
      arr[:length] = KSU::Cutting.d(arr[:length])
      arr[:width] = KSU::Cutting.d(arr[:width])
      arr[:thickness] = KSU::Cutting.d(arr[:thickness])
    end
    arr2
  end
end
