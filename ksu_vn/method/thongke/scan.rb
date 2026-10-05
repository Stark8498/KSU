module KSU::Thongke::Quet
  def self.all_roots
    Sketchup.active_model.entities.select { |e| KSU.container?(e) }
  end
  def self.walk_boards(ents, path = [], ids = nil, out = [], arr = {})
    ents.each do |grp|
      next unless KSU.container?(grp) && grp.valid?
      next if arr[grp.entityID] || grp.get_attribute("ABF", "is-flatten") ||
              grp.get_attribute("ABF", "is-nesting-root") || grp.get_attribute("ABF", "is-bottom-sheet")
      arr[grp.entityID] = true
      out << [grp, path] if grp.get_attribute("ABF", "is-board") && (ids.nil? || ids[grp.get_attribute("ABF", "board-index").to_i])
      walk_boards(KSU.entities_in(grp) || [], path + [grp], ids, out, arr)
    end
    out
  end
  def self.each_sheet(arr)
    arr.flat_map { |grp|
      next [grp] unless grp.get_attribute("ABF", "is-nesting-root")
      (KSU.entities_in(grp) || []).select { |s| KSU.container?(s) }
    }.each do |grp2|
      sheet_id = grp2.get_attribute("ABF", "sheet-id")
      yield grp2, sheet_id if sheet_id
    end
  end
  def self.long_axis(arr, vec)
    dir = vec.normalize
    lo, hi = arr.map { |pt3| arr[0].vector_to(pt3).dot(dir) }.minmax
    lo ? hi - lo : 0.0
  end
  def self.fill_edgeband(rec, _124c7bd3, tf, vec, thick_mm)
    KSU::Cutting.edgeband_spec(_124c7bd3, thick_mm)[0].each do |f, thickness, disp, fields, stat, kind|
      rec[:edgeband_thickness][disp] = (thickness * 25.4).round(3)
      rec[:edgeband_base][disp] = fields[0].to_s
      next if stat == false
      line_vec = vec.cross(f.normal)
      next if line_vec.length == 0
      flag = f.edges.find { |edge| edge.line[1].parallel?(line_vec) }
      next unless flag
      rec[:edgeband_lengths][disp] = (rec[:edgeband_lengths][disp] || 0) + flag.length(tf).to_f / (kind == "chap" ? 2.0 : 1.0)
    end
  end
  def self.board_record(grp)
    tf = KSU::Label.world_tf(grp)
    font, back = KSU::Cutting.board_faces(grp, tf)
    return unless font
    labels = KSU::Cutting.kids_with_attr(grp, "is-label")
    vec = labels ? labels[0].transformation.xaxis.transform(tf) : KSU::Cutting.box_axes(font.bounds, tf)[2][1]
    ref_p2 = font.normal.transform(tf)
    pt = font.outer_loop.vertices.map { |v| v.position.transform(tf) }
    thickness = back.outer_loop.vertices[0].position.transform(tf).distance_to_plane([pt[0], ref_p2])
    axes = [long_axis(pt, vec), long_axis(pt, vec.cross(ref_p2))]
    rec = { edgeband_lengths: {}, edgeband_thickness: {}, edgeband_base: {} }
    fill_edgeband(rec, grp, tf, font.normal, thickness.to_f * 25.4)
    idx = grp.get_attribute("ABF", "board-index") || 0
    rec.merge!(index: idx, name: KSU::Label.label_text(grp).to_s.then { |n| n.empty? ? idx.to_s : n },
      material: KSU::Cutting.material_for(grp), code_ns: %w[code_n1 code_n2 code_n3].map { |k| grp.get_attribute("ABF", k) },
      length: axes.max.to_f, width: axes.min.to_f, thickness: thickness)
  rescue StandardError
  end
  def self.list_boards(_4230ad5c)
    h = {}
    each_sheet(all_roots) do |sheet, sheet_id|
      KSU::Cutting.kids_with_attr(sheet, "board-index")&.each { |grp| h[grp.get_attribute("ABF", "board-index")] = sheet_id }
    end
    walk_boards(_4230ad5c).filter_map { |grp2, _item| board_record(grp2) }.each do |rec|
      rec[:sheet] = h[rec[:index]] || -1
      %i[length width thickness].each { |k| rec[k] = KSU::Cutting.d(rec[k]) }
    end
  end
end
