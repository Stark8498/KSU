module KSU::Intem
  def self.scan
    model = Sketchup.active_model
    nesting = KSU::Nesting.nesting_root
    src = nesting ? nesting.entities : model.entities
    sheets = {}
    parts2 = []
    materials2 = {}
    materials = []
    box = {}
    seed = KSU::Settings.get("goc_bat_dau", "trai_duoi", "in_tem").to_s
    str2 = KSU::Settings.get("thu_tu_in", "so_tam", "in_tem").to_s == "so_tam"
    descent = KSU::Settings.get("sap_xep", "tang_dan", "in_tem").to_s == "giam_dan"
    h3 = {}
    h2 = {}
    index_boards(model.entities, h3, {}, 0, h2)
    h16 = {}
    src.grep(Sketchup::Group).each do |sheet|
      next unless sheet.get_attribute("ABF", "sheet-id")
      next unless KSU::Sheet.hidden?(sheet)
      sheet.entities.grep(Sketchup::Group).each do |grp|
        board_index = grp.get_attribute("ABF", "board-index")
        next unless board_index
        next if h16[board_index]
        hinge_spec = hinge(grp)
        h16[board_index] = hinge_spec if hinge_spec
      end
    end
    src.grep(Sketchup::Group).each do |sheet|
      sheet_id = sheet.get_attribute("ABF", "sheet-id")
      next unless sheet_id
      next if KSU::Sheet.hidden?(sheet)
      sheet_type = sheet.get_attribute("ABF", "sheet-type").to_s
      mat = sheet.get_attribute("KSU", "sheet-material").to_s
      mat = sheet_type if mat.empty?
      w, h = sheet_dims(sheet)
      parts = []
      sheet.entities.grep(Sketchup::Group).each do |grp|
        rec = part_record(grp, sheet_id, mat, h3, h16, h2)
        next unless rec
        parts2 << rec
        parts << parts2.length - 1
      end
      last_cut_parts(sheet, sheet_id, mat).each do |rec|
        parts2 << rec
        parts << parts2.length - 1
      end
      next if parts.empty?
      if str2
        dir = descent ? -1 : 1
        parts.sort_by! { |i| [parts2[i][:lk] ? 1 : 0, dir * parts2[i][:id].to_i] }
      else
        px = seed.include?("phai") ? w : 0.0
        py = seed.include?("tren") ? h : 0.0
        parts.sort_by! do |i|
          pt = nearest_pt(parts2[i][:poly], px, py)
          [parts2[i][:lk] ? 1 : 0, (pt[1] - py).abs.round, (pt[0] - px).abs, parts2[i][:id].to_i]
        end
      end
      num4 = sheet.get_attribute("ABF", "sheet-thickness").to_f
      sheets[sheet_id] = { w: w, h: h, th: num4, parts: parts }
      unless materials2[sheet_type]
        materials2[sheet_type] = { key: sheet_type, name: sheet_type, th: num4, sheets: [] }
        materials << sheet_type
      end
      materials2[sheet_type][:sheets] << sheet_id
      bbox = sheet.bounds
      next if bbox.empty?
      ty = bbox.max.y.to_f
      tx = bbox.min.x.to_f
      arr = box[sheet_type]
      box[sheet_type] = [ty, tx] if arr.nil? || ty > arr[0] || (ty == arr[0] && tx < arr[1])
    end
    materials2.each_value { |meta| meta[:sheets].sort_by! { |sheet_id| [sheet_id.to_i, sheet_id.to_s] } }
    materials.sort_by! do |k|
      arr = box[k]
      [arr ? -arr[0] : Float::INFINITY, arr ? arr[1] : 0.0]
    end
    { materials: materials.map { |k| materials2[k] }, sheets: sheets, parts: parts2 }
  end
  def self.nearest_pt(poly, px, py)
    pts = poly[0] || []
    pts.min_by { |arr| (arr[0] - px)**2 + (arr[1] - py)**2 } || [px, py]
  end
  def self.sheet_dims(sheet)
    ent2 = sheet.get_attribute("ABF", "sheet-dimension")
    if ent2.is_a?(Array) && ent2[0].to_f > 0 && ent2[1].to_f > 0
      return [ent2[0].to_f, ent2[1].to_f]
    end
    best_d = sheet.entities.grep(Sketchup::Group).find { |ent| KSU::Sheet.sheet_border?(ent) }
    return [0.0, 0.0] unless best_d
    bbox = best_d.bounds
    [(bbox.width * 25.4).round(2), (bbox.height * 25.4).round(2)]
  end
  def self.last_cut_parts(sheet, sheet_id, mat)
    id_str = sheet.get_attribute("ABF", "sheet-last-cut", nil)
    return [] unless id_str
    data = begin
      JSON.parse(id_str)
    rescue StandardError
      nil
    end
    return [] unless data.is_a?(Hash) && data["polys"].is_a?(Array)
    org_x, org_y = sheet_origin(sheet)
    loops = data["polys"].select { |arr| arr.is_a?(Array) && arr.length >= 3 }
    out = []
    loops.each_with_index do |arr, ix|
      pts = arr.map do |arr2|
        [((org_x + arr2[0].to_f) * 25.4).round(2), ((org_y + arr2[1].to_f) * 25.4).round(2)]
      end
      pts << pts.first.dup unless same_pt?(pts.first, pts.last)
      out << {
        id: "L#{ix + 1}",
        eid: nil,
        sheet: sheet_id,
        mat: mat,
        name: "Tấm lưu kho",
        lk: true,
        poly: [pts],
        drills: [],
        ebs: [],
        cups: [],
        grooves: [],
        gname: "",
        hinge: nil,
        code1: "",
        code2: "",
        code3: ""
      }
    end
    out
  end
  def self.sheet_origin(sheet)
    arr = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    best_d = sheet.entities.grep(Sketchup::Group).find { |ent| KSU::Sheet.sheet_border?(ent) }
    lo = best_d && best_d.bounds.valid? ? best_d.bounds.min : nil
    [(lo ? lo.x.to_f : 0.0) + arr[0], (lo ? lo.y.to_f : 0.0) + arr[1]]
  end
  def self.index_boards(ents, arr4, seen, lvl, arr)
    return if lvl > 8
    ents.each do |ent|
      next unless KSU.container?(ent)
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      next if ent.get_attribute("ABF", "is-nesting-root") || ent.get_attribute("ABF", "is-flatten-root") ||
              ent.get_attribute("ABF", "is-flatten")
      board_index = ent.get_attribute("ABF", "board-index")
      if board_index
        codes = [ent.get_attribute("ABF", "code_n1").to_s,
                 ent.get_attribute("ABF", "code_n2").to_s,
                 ent.get_attribute("ABF", "code_n3").to_s]
        arr4[board_index] = codes unless codes.all?(&:empty?)
        unless arr[board_index]
          arr3 = KSU::Cutting.edgeband_list(ent)
          arr[board_index] = arr3 unless arr3.empty?
        end
        next
      end
      kids = KSU.entities_in(ent)
      index_boards(kids, arr4, seen, lvl + 1, arr) if kids
    end
  end
  def self.part_record(grp, sheet_id, mat, arr, arr4, arr3)
    pid = grp.get_attribute("ABF", "board-index")
    return nil unless pid
    return nil if KSU::Sheet.sheet_border?(grp)
    cutting_gr = grp.entities.find { |ent| KSU.container?(ent) && ent.get_attribute("ABF", "is-cutting-lines") }
    return nil unless cutting_gr
    part_tf = grp.transformation
    poly = cut_loops_of(cutting_gr, part_tf * cutting_gr.transformation)
    return nil if poly.empty?
    name = KSU::Label.label_text(grp)
    name = pid.to_s if name.to_s.empty?
    arr2 = walk_names(grp, part_tf)
    codes = [grp.get_attribute("ABF", "code_n1").to_s,
             grp.get_attribute("ABF", "code_n2").to_s,
             grp.get_attribute("ABF", "code_n3").to_s]
    codes = arr[pid] if codes.all?(&:empty?) && arr[pid]
    {
      id: pid,
      eid: grp.entityID,
      sheet: sheet_id,
      mat: mat,
      name: name,
      poly: poly,
      drills: drills(grp, part_tf),
      ebs: ebs(grp, part_tf, arr3[pid]),
      cups: cups(grp, part_tf),
      grooves: arr2[:paths],
      gname: arr2[:names].join(" - "),
      hinge: hinge(grp) || arr4[pid],
      code1: codes[0],
      code2: codes[1],
      code3: codes[2]
    }
  end
  def self.hinge(entity, num = 0)
    return nil if num > 3
    ents = KSU.entities_in(entity)
    return nil unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      if ent.get_attribute("ABF", "is-hinge-part-a") || ent.get_attribute("ABF", "is-hinge-part-b")
        str = ent.get_attribute("ABF", "setting-name").to_s
        return str unless str.empty?
      end
      half = hinge(ent, num + 1)
      return half if half
    end
    nil
  end
  def self.curves_in(gr, tf4)
    seen = {}
    arr = []
    (KSU.entities_in(gr) || []).each do |edge|
      next unless edge.is_a?(Sketchup::Edge)
      if edge.curve
        next if seen[edge.curve.entityID]
        seen[edge.curve.entityID] = true
        pts = edge.curve.vertices.map(&:position)
      else
        pts = [edge.start.position, edge.end.position]
      end
      arr << pts.map do |pt2|
        pt = pt2.transform(tf4)
        [(pt.x * 25.4).round(2), (pt.y * 25.4).round(2)]
      end
    end
    arr
  end
  def self.cups(entity, tf, num = 0, out = [])
    return out if num > 3
    ents = KSU.entities_in(entity)
    return out unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      tf4 = tf * ent.transformation
      if ent.get_attribute("ABF", "is-hinge-part-b")
        best = nil
        curves_in(ent, tf4).each do |arr5|
          arr3 = arr5.map { |arr4| arr4[0] }
          arr2 = arr5.map { |arr4| arr4[1] }
          rsz = [arr3.max - arr3.min, arr2.max - arr2.min].max.round(2)
          next if best && best[0] >= rsz
          num2 = [((arr3.min + arr3.max) / 2).round(2), ((arr2.min + arr2.max) / 2).round(2)]
          best = [rsz, num2, arr5]
        end
        out << best if best
      else
        cups(ent, tf4, num + 1, out)
      end
    end
    out
  end
  def self.walk_names(entity, tf, num = 0, out = { names: [], paths: [] })
    return out if num > 3
    ents = KSU.entities_in(entity)
    return out unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      tf4 = tf * ent.transformation
      if ent.get_attribute("ZSU", "bao_ranh")
        str = ent.get_attribute("ABF", "statistical-name").to_s
        next if str.empty?
        out[:names] << str unless out[:names].include?(str)
        out[:paths].concat(curves_in(ent, tf4))
      else
        walk_names(ent, tf4, num + 1, out)
      end
    end
    out
  end
  def self.cut_loops_of(cutting_gr, tf)
    arr2 = []
    seen = {}
    (KSU.entities_in(cutting_gr) || []).each do |ent|
      next unless ent.is_a?(Sketchup::Edge) && ent.curve
      next if seen[ent.curve.entityID]
      seen[ent.curve.entityID] = true
      outer2 = KSU::Cutting.outer?(ent.curve)
      pts = ent.curve.vertices.map do |v|
        pt = v.position.transform(tf)
        [(pt.x * 25.4).round(2), (pt.y * 25.4).round(2)]
      end
      arr2 << { pts: pts, outer: outer2 } if pts.length > 1
    end
    return [] if arr2.empty?
    loops = join_loops(arr2)
    outer_ix = loops.index { |arr3| arr3[:outer] } || 0
    loops[0], loops[outer_ix] = loops[outer_ix], loops[0]
    loops.map { |arr3| arr3[:pts] }
  end
  def self.join_loops(h)
    arr = h.dup
    loops = []
    until arr.empty?
      arr2 = arr.shift
      pts = arr2[:pts].dup
      outer = arr2[:outer]
      flag = true
      while flag
        flag = false
        break if closed_loop?(pts)
        tail_pt = pts.last
        arr.each_with_index do |f, i|
          next if closed_loop?(f[:pts])
          if same_pt?(f[:pts].first, tail_pt)
            pts.concat(f[:pts][1..-1])
          elsif same_pt?(f[:pts].last, tail_pt)
            pts.concat(f[:pts].reverse[1..-1])
          else
            next
          end
          outer ||= f[:outer]
          arr.delete_at(i)
          flag = true
          break
        end
      end
      loops << { pts: pts, outer: outer }
    end
    loops
  end
  def self.same_pt?(arr2, b)
    (arr2[0] - b[0]).abs < 0.05 && (arr2[1] - b[1]).abs < 0.05
  end
  def self.closed_loop?(pts)
    pts.length > 3 && same_pt?(pts.first, pts.last)
  end
  def self.drills(grp, part_tf)
    d2x = grp.get_attribute("ABF", "drills-desc")
    return [] unless d2x.is_a?(Array) && d2x[1].is_a?(Array)
    out = []
    d2x[1].each do |arr2|
      next unless arr2.is_a?(Array) && arr2.length >= 3
      num = [arr2[0].to_f, arr2[1].to_f]
      ok = true
      arr2[2..-1].each do |p3|
        next ok = false unless p3.is_a?(Array) && p3.length >= 2
        pt = Geom::Point3d.new(p3[0].to_f, p3[1].to_f, p3[2].to_f).transform(part_tf)
        num << [(pt.x * 25.4).round(2), (pt.y * 25.4).round(2)]
      end
      out << num if ok
    end
    out
  end
  def self.ebs(grp, part_tf, eb_spec)
    arr2 = grp.get_attribute("ABF", "edge-band-desc")
    return [] unless arr2.is_a?(Array)
    out = []
    arr2.each do |arr|
      next unless arr.is_a?(Array) && arr.length >= 7
      p_ref = Geom::Point3d.new(arr[0].to_f, arr[1].to_f, arr[2].to_f).transform(part_tf)
      p1 = Geom::Point3d.new(arr[3].to_f, arr[4].to_f, arr[5].to_f).transform(part_tf)
      n = arr.length
      joint = (n == 8 || n >= 12) ? arr[n - 1].to_s : ""
      num = [(p_ref.x * 25.4).round(2), (p_ref.y * 25.4).round(2),
                (p1.x * 25.4).round(2), (p1.y * 25.4).round(2), arr[6].to_s, joint]
      fields = n >= 11 ? arr[7, 4].map(&:to_s) : nil
      fields = merge_band_fields(eb_spec, arr[6].to_s, fields)
      num.concat(fields) if fields
      out << num
    end
    out
  end
  def self.merge_band_fields(eb_spec, name, fields)
    return fields unless eb_spec.is_a?(Array) && !eb_spec.empty?
    if fields
      hit = eb_spec.find { |thick| thick[0] == fields[0] && thick[3] == fields[3] }
    else
      hit = eb_spec.find do |thick|
        !thick[0].empty? && name.start_with?(thick[0]) && name_matches?(name, thick[3])
      end
      hit ||= eb_spec[0] if eb_spec.length == 1 && name_matches?(name, eb_spec[0][3])
    end
    hit || fields
  end
  def self.name_matches?(name, want2)
    tail_pt = "#{want2}mm"
    return false unless name.end_with?(tail_pt)
    ch = name[-(tail_pt.length + 1), 1]
    ch.nil? || !(ch =~ /[\d.]/)
  end
end
