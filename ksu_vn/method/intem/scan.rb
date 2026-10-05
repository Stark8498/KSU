module KSU::Intem
  def self.scan
    model = Sketchup.active_model
    src = (KSU::Nesting.nesting_root || model).entities
    sheets, arr29, materials, box, _04c9a0d8, _63ec5a82, h = {}, [], {}, {}, {}, {}, {}
    corner = KSU::Settings.get("goc_bat_dau", "trai_duoi", "in_tem")
    _462905a2 = KSU::Settings.get("thu_tu_in", "so_tam", "in_tem") == "so_tam"
    dir = KSU::Settings.get("sap_xep", "tang_dan", "in_tem") == "giam_dan" ? -1 : 1
    index_boards(model.entities, _04c9a0d8, {}, 0, _63ec5a82)
    arr4, arr3 = src.grep(Sketchup::Group).select { |s| s.get_attribute("ABF", "sheet-id") }.partition { |s| KSU::Sheet.hidden?(s) }
    arr4.flat_map { |s| s.entities.grep(Sketchup::Group) }.each do |grp|
      board_index = grp.get_attribute("ABF", "board-index")
      h[board_index] ||= hinge(grp) if board_index
    end
    arr3.each do |grp2|
      sheet_id, sheet_type = grp2.get_attribute("ABF", "sheet-id"), grp2.get_attribute("ABF", "sheet-type").to_s
      mat = grp2.get_attribute("KSU", "sheet-material").to_s
      mat = sheet_type if mat.empty?
      w, elem = sheet_dims(grp2)
      row0 = arr29.length
      arr29.concat(grp2.entities.grep(Sketchup::Group).filter_map { |grp| part_record(grp, sheet_id, mat, _04c9a0d8, h, _63ec5a82) })
      arr29.concat(last_cut_parts(grp2, sheet_id, mat))
      px, py = (corner.include?("phai") ? w : 0.0), (corner.include?("tren") ? elem : 0.0)
      parts = (row0...arr29.length).sort_by do |i|
        arr = arr29[i]
        next [arr[:lk] ? 1 : 0, dir * arr[:id].to_i] if _462905a2
        segs_for_ray = arr[:poly][0].min_by { |arr2| (arr2[0] - px)**2 + (arr2[1] - py)**2 }
        [arr[:lk] ? 1 : 0, (segs_for_ray[1] - py).abs.round, (segs_for_ray[0] - px).abs, arr[:id].to_i]
      end
      next if parts.empty?
      num = grp2.get_attribute("ABF", "sheet-thickness").to_f
      sheets[sheet_id] = { w: w, h: elem, th: num, parts: parts }
      (materials[sheet_type] ||= { key: sheet_type, name: sheet_type, th: num, sheets: [] })[:sheets] << sheet_id
      bbox = grp2.bounds
      (box[sheet_type] ||= []) << [-bbox.max.y.to_f, bbox.min.x.to_f] unless bbox.empty?
    end
    materials.each_value { |meta| meta[:sheets].sort_by! { |sheet_id| [sheet_id.to_i, sheet_id.to_s] } }
    { materials: materials.values.sort_by { |meta| box[meta[:key]]&.min || [Float::INFINITY, 0.0] }, sheets: sheets, parts: arr29 }
  end
  def self.sheet_dims(grp)
    ent2 = grp.get_attribute("ABF", "sheet-dimension")
    return [ent2[0].to_f, ent2[1].to_f] if ent2.is_a?(Array) && ent2[0].to_f > 0 && ent2[1].to_f > 0
    bbox = grp.entities.grep(Sketchup::Group).find { |e| KSU::Sheet.sheet_border?(e) }&.bounds
    bbox ? [bbox.width, bbox.height].map { |v| (v * 25.4).round(2) } : [0.0, 0.0]
  end
  def self.last_cut_parts(grp, sheet_id, mat)
    id_str = grp.get_attribute("ABF", "sheet-last-cut")
    data = (JSON.parse(id_str) rescue nil) if id_str
    return [] unless data.is_a?(Hash) && data["polys"].is_a?(Array)
    table_off = KSU::Sheet.edit_offset(grp) || [0.0, 0.0]
    bbox = grp.entities.grep(Sketchup::Group).find { |e| KSU::Sheet.sheet_border?(e) }&.bounds
    lo = bbox.min if bbox&.valid?
    _821639ac, num = (lo ? lo.x.to_f : 0.0) + table_off[0], (lo ? lo.y.to_f : 0.0) + table_off[1]
    data["polys"].select { |arr2| arr2.is_a?(Array) && arr2.length >= 3 }.map.with_index(1) do |arr2, ix|
      arr = arr2.map { |arr4| [((_821639ac + arr4[0].to_f) * 25.4).round(2), ((num + arr4[1].to_f) * 25.4).round(2)] }
      arr << arr.first.dup unless same_pt?(arr.first, arr.last)
      { id: "L#{ix}", eid: nil, sheet: sheet_id, mat: mat, name: "Tấm lưu kho", lk: true, poly: [arr],
        drills: [], ebs: [], cups: [], grooves: [], gname: "", hinge: nil, code1: "", code2: "", code3: "" }
    end
  end
  def self.index_boards(ents, arr4, arr, depth, arr2)
    return if depth > 8
    ents.each do |grp|
      next if !KSU.container?(grp) || arr[grp.entityID]
      arr[grp.entityID] = true
      next if %w[is-nesting-root is-flatten-root is-flatten].any? { |k| grp.get_attribute("ABF", k) }
      board_index = grp.get_attribute("ABF", "board-index")
      next index_boards(KSU.entities_in(grp) || [], arr4, arr, depth + 1, arr2) unless board_index
      arr3 = %w[code_n1 code_n2 code_n3].map { |k| grp.get_attribute("ABF", k).to_s }
      arr4[board_index] = arr3 unless arr3.all?(&:empty?)
      arr2[board_index] = KSU::Cutting.edgeband_list(grp) if (arr2[board_index] || []).empty?
    end
  end
  def self.part_record(grp, sheet_id, mat, arr4, arr3, arr5)
    pid = grp.get_attribute("ABF", "board-index")
    return nil if !pid || KSU::Sheet.sheet_border?(grp)
    cutting_gr = grp.entities.find { |grp2| KSU.container?(grp2) && grp2.get_attribute("ABF", "is-cutting-lines") }
    return nil unless cutting_gr
    part_tf = grp.transformation
    poly = cut_loops_of(cutting_gr, part_tf * cutting_gr.transformation)
    return nil if poly.empty?
    name = KSU::Label.label_text(grp)
    name = pid.to_s if name.to_s.empty?
    arr2 = walk_names(grp, part_tf)
    arr = %w[code_n1 code_n2 code_n3].map { |k| grp.get_attribute("ABF", k).to_s }
    arr = arr4[pid] || arr if arr.all?(&:empty?)
    { id: pid, eid: grp.entityID, sheet: sheet_id, mat: mat, name: name, poly: poly,
      drills: drill_marks(grp, part_tf), ebs: ebs(grp, part_tf, arr5[pid]),
      cups: cups(grp, part_tf), grooves: arr2[:paths], gname: arr2[:names].join(" - "),
      hinge: hinge(grp) || arr3[pid], code1: arr[0], code2: arr[1], code3: arr[2] }
  end
  def self.hinge(entity, depth = 0)
    return nil if depth > 3
    (KSU.entities_in(entity) || []).lazy.filter_map do |grp|
      next unless KSU.container?(grp)
      str = grp.get_attribute("ABF", "setting-name").to_s if grp.get_attribute("ABF", "is-hinge-part-a") || grp.get_attribute("ABF", "is-hinge-part-b")
      str.to_s.empty? ? hinge(grp, depth + 1) : str
    end.first
  end
  def self.curves_in(gr, tf4)
    (KSU.entities_in(gr) || []).grep(Sketchup::Edge).map { |edge2| edge2.curve || edge2 }.uniq(&:entityID).map do |edge|
      (edge.is_a?(Sketchup::Edge) ? [edge.start.position, edge.end.position] : edge.vertices.map(&:position)).map { |pt3| drills(pt3, tf4) }
    end
  end
  def self.cups(entity, tf, depth = 0, out = [])
    return out if depth > 3
    (KSU.entities_in(entity) || []).each_with_object(out) do |grp|
      next unless KSU.container?(grp)
      tf4 = tf * grp.transformation
      next cups(grp, tf4, depth + 1, out) unless grp.get_attribute("ABF", "is-hinge-part-b")
      best = curves_in(grp, tf4).map do |_8794f78f|
        text, y0, x1, y1 = KSU::Nesting.poly_bounds(_8794f78f)
        [[x1 - text, y1 - y0].max.round(2), [((text + x1) / 2).round(2), ((y0 + y1) / 2).round(2)], _8794f78f]
      end.max_by(&:first)
      out << best if best
    end
  end
  def self.walk_names(entity, tf, depth = 0, out = { names: [], paths: [] })
    return out if depth > 3
    (KSU.entities_in(entity) || []).each_with_object(out) do |grp|
      next unless KSU.container?(grp)
      tf4 = tf * grp.transformation
      next walk_names(grp, tf4, depth + 1, out) unless grp.get_attribute("ZSU", "bao_ranh")
      str = grp.get_attribute("ABF", "statistical-name").to_s
      next if str.empty?
      out[:names] << str unless out[:names].include?(str)
      out[:paths].concat(curves_in(grp, tf4))
    end
  end
  def self.cut_loops_of(cutting_gr, tf)
    arr2 = (KSU.entities_in(cutting_gr) || []).grep(Sketchup::Edge).filter_map(&:curve).uniq(&:entityID).filter_map do |face|
      pt = face.vertices.map { |v| drills(v.position, tf) }
      { pts: pt, outer: KSU::Cutting.outer?(face) } if pt.length > 1
    end
    loops = join_loops(arr2)
    _045f7cc5 = loops.index { |arr| arr[:outer] }
    loops[0], loops[_045f7cc5] = loops[_045f7cc5], loops[0] if _045f7cc5
    loops.map { |arr| arr[:pts] }
  end
  def self.join_loops(arr)
    loops = []
    until arr.empty?
      arr3 = arr.shift
      arr2, outer = arr3[:pts].dup, arr3[:outer]
      until closed_loop?(arr2)
        tail_pt = arr2.last
        i = arr.index { |f| !closed_loop?(f[:pts]) && (same_pt?(f[:pts].first, tail_pt) || same_pt?(f[:pts].last, tail_pt)) }
        break unless i
        f = arr.delete_at(i)
        arr2.concat(same_pt?(f[:pts].first, tail_pt) ? f[:pts][1..-1] : f[:pts].reverse[1..-1])
        outer ||= f[:outer]
      end
      loops << { pts: arr2, outer: outer }
    end
    loops
  end
  def self.same_pt?(arr, b)
    (arr[0] - b[0]).abs < 0.05 && (arr[1] - b[1]).abs < 0.05
  end
  def self.closed_loop?(arr)
    arr.length > 3 && same_pt?(arr.first, arr.last)
  end
  def self.drills(segs_for_ray, tf)
    pt = segs_for_ray.transform(tf)
    [(pt.x * 25.4).round(2), (pt.y * 25.4).round(2)]
  end
  def self.drill_marks(grp, part_tf)
    d2x = grp.get_attribute("ABF", "drills-desc")
    return [] unless d2x.is_a?(Array) && d2x[1].is_a?(Array)
    d2x[1].filter_map do |arr|
      next unless arr.is_a?(Array) && arr.length >= 3
      arr2 = [arr[0].to_f, arr[1].to_f] + arr[2..-1].map do |p3|
        drills(Geom::Point3d.new(p3[0].to_f, p3[1].to_f, p3[2].to_f), part_tf) if p3.is_a?(Array) && p3.length >= 2
      end
      arr2 unless arr2.include?(nil)
    end
  end
  def self.ebs(grp, part_tf, eb_spec)
    _aa449197 = grp.get_attribute("ABF", "edge-band-desc")
    return [] unless _aa449197.is_a?(Array)
    _aa449197.filter_map do |arr|
      next unless arr.is_a?(Array) && arr.length >= 7
      n = arr.length
      pt = [0, 3].flat_map { |_c8378bbe| drills(Geom::Point3d.new(*arr[_c8378bbe, 3].map(&:to_f)), part_tf) } +
               [arr[6].to_s, (n == 8 || n >= 12) ? arr.last.to_s : ""]
      pt + (merge_band_fields(eb_spec, arr[6].to_s, n >= 11 ? arr[7, 4].map(&:to_s) : nil) || [])
    end
  end
  def self.merge_band_fields(eb_spec, name, fields)
    return fields unless eb_spec.is_a?(Array) && !eb_spec.empty?
    return eb_spec.find { |t| t[0] == fields[0] && t[3] == fields[3] } || fields if fields
    eb_spec.find { |t| !t[0].empty? && name.start_with?(t[0]) && name_matches?(name, t[3]) } ||
      (eb_spec[0] if eb_spec.length == 1 && name_matches?(name, eb_spec[0][3]))
  end
  def self.name_matches?(name, want2)
    tail_pt = "#{want2}mm"
    name.end_with?(tail_pt) && name[-(tail_pt.length + 1), 1].to_s !~ /[\d.]/
  end
end
