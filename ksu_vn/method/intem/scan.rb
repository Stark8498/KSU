module KSU::Intem
  def self._9e1d7ab3
    model = Sketchup.active_model
    nesting = KSU::Nesting._d7b62fb6
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
    _e12462c7(model.entities, h3, {}, 0, h2)
    h = {}
    src.grep(Sketchup::Group).each do |sheet|
      next unless sheet.get_attribute("ABF", "sheet-id")
      next unless KSU::Sheet.hidden?(sheet)
      sheet.entities.grep(Sketchup::Group).each do |grp5|
        board_index = grp5.get_attribute("ABF", "board-index")
        next unless board_index
        next if h[board_index]
        _14954c73 = hinge(grp5)
        h[board_index] = _14954c73 if _14954c73
      end
    end
    src.grep(Sketchup::Group).each do |sheet|
      sheet_id = sheet.get_attribute("ABF", "sheet-id")
      next unless sheet_id
      next if KSU::Sheet.hidden?(sheet)
      sheet_type = sheet.get_attribute("ABF", "sheet-type").to_s
      mat = sheet.get_attribute("KSU", "sheet-material").to_s
      mat = sheet_type if mat.empty?
      num3, arr52 = _acf1b201(sheet)
      parts = []
      sheet.entities.grep(Sketchup::Group).each do |grp5|
        rec = _cbfbfd78(grp5, sheet_id, mat, h3, h, h2)
        next unless rec
        parts2 << rec
        parts << parts2.length - 1
      end
      _9ec31362(sheet, sheet_id, mat).each do |rec|
        parts2 << rec
        parts << parts2.length - 1
      end
      next if parts.empty?
      if str2
        _c04fb39c = descent ? -1 : 1
        parts.sort_by! { |i| [parts2[i][:lk] ? 1 : 0, _c04fb39c * parts2[i][:id].to_i] }
      else
        px = seed.include?("phai") ? num3 : 0.0
        py = seed.include?("tren") ? arr52 : 0.0
        parts.sort_by! do |i|
          pt = _f0de9fe3(parts2[i][:poly], px, py)
          [parts2[i][:lk] ? 1 : 0, (pt[1] - py).abs.round, (pt[0] - px).abs, parts2[i][:id].to_i]
        end
      end
      num4 = sheet.get_attribute("ABF", "sheet-thickness").to_f
      sheets[sheet_id] = { w: num3, h: arr52, th: num4, parts: parts }
      unless materials2[sheet_type]
        materials2[sheet_type] = { key: sheet_type, name: sheet_type, th: num4, sheets: [] }
        materials << sheet_type
      end
      materials2[sheet_type][:sheets] << sheet_id
      bbox = sheet.bounds
      next if bbox.empty?
      num = bbox.max.y.to_f
      tx = bbox.min.x.to_f
      arr = box[sheet_type]
      box[sheet_type] = [num, tx] if arr.nil? || num > arr[0] || (num == arr[0] && tx < arr[1])
    end
    materials2.each_value { |meta| meta[:sheets].sort_by! { |sheet_id| [sheet_id.to_i, sheet_id.to_s] } }
    materials.sort_by! do |k|
      arr = box[k]
      [arr ? -arr[0] : Float::INFINITY, arr ? arr[1] : 0.0]
    end
    { materials: materials.map { |k| materials2[k] }, sheets: sheets, parts: parts2 }
  end
  def self._f0de9fe3(poly, px, py)
    pts = poly[0] || []
    pts.min_by { |arr| (arr[0] - px)**2 + (arr[1] - py)**2 } || [px, py]
  end
  def self._acf1b201(sheet)
    ent2 = sheet.get_attribute("ABF", "sheet-dimension")
    if ent2.is_a?(Array) && ent2[0].to_f > 0 && ent2[1].to_f > 0
      return [ent2[0].to_f, ent2[1].to_f]
    end
    ents = sheet.entities.grep(Sketchup::Group).find { |ent| KSU::Sheet._27ecfdd1(ent) }
    return [0.0, 0.0] unless ents
    bbox = ents.bounds
    [(bbox.width * 25.4).round(2), (bbox.height * 25.4).round(2)]
  end
  def self._9ec31362(sheet, sheet_id, mat)
    id_str = sheet.get_attribute("ABF", "sheet-last-cut", nil)
    return [] unless id_str
    data = begin
      JSON.parse(id_str)
    rescue StandardError
      nil
    end
    return [] unless data.is_a?(Hash) && data["polys"].is_a?(Array)
    _3e7613f3, _9ba1a361 = _6aba4c5e(sheet)
    loops = data["polys"].select { |arr| arr.is_a?(Array) && arr.length >= 3 }
    out = []
    loops.each_with_index do |arr, ix|
      pts = arr.map do |arr2|
        [((_3e7613f3 + arr2[0].to_f) * 25.4).round(2), ((_9ba1a361 + arr2[1].to_f) * 25.4).round(2)]
      end
      pts << pts.first.dup unless _a8e56783(pts.first, pts.last)
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
  def self._6aba4c5e(sheet)
    arr = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    ents = sheet.entities.grep(Sketchup::Group).find { |ent| KSU::Sheet._27ecfdd1(ent) }
    lo = ents && ents.bounds.valid? ? ents.bounds.min : nil
    [(lo ? lo.x.to_f : 0.0) + arr[0], (lo ? lo.y.to_f : 0.0) + arr[1]]
  end
  def self._e12462c7(ents, arr4, seen, depth, arr)
    return if depth > 8
    ents.each do |ent|
      next unless KSU.container?(ent)
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      next if ent.get_attribute("ABF", "is-nesting-root") || ent.get_attribute("ABF", "is-flatten-root") ||
              ent.get_attribute("ABF", "is-flatten")
      board_index = ent.get_attribute("ABF", "board-index")
      if board_index
        str = [ent.get_attribute("ABF", "code_n1").to_s,
                 ent.get_attribute("ABF", "code_n2").to_s,
                 ent.get_attribute("ABF", "code_n3").to_s]
        arr4[board_index] = str unless str.all?(&:empty?)
        unless arr[board_index]
          arr3 = KSU::Cutting.edgeband_list(ent)
          arr[board_index] = arr3 unless arr3.empty?
        end
        next
      end
      kids = KSU.entities_in(ent)
      _e12462c7(kids, arr4, seen, depth + 1, arr) if kids
    end
  end
  def self._cbfbfd78(grp, sheet_id, mat, arr, arr4, arr3)
    pid = grp.get_attribute("ABF", "board-index")
    return nil unless pid
    return nil if KSU::Sheet._27ecfdd1(grp)
    cutting_gr = grp.entities.find { |ent| KSU.container?(ent) && ent.get_attribute("ABF", "is-cutting-lines") }
    return nil unless cutting_gr
    part_tf = grp.transformation
    poly = _d8a5a5cb(cutting_gr, part_tf * cutting_gr.transformation)
    return nil if poly.empty?
    name = KSU::Label.label_text(grp)
    name = pid.to_s if name.to_s.empty?
    arr2 = _503b4f27(grp, part_tf)
    _93188890 = [grp.get_attribute("ABF", "code_n1").to_s,
             grp.get_attribute("ABF", "code_n2").to_s,
             grp.get_attribute("ABF", "code_n3").to_s]
    _93188890 = arr[pid] if _93188890.all?(&:empty?) && arr[pid]
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
      code1: _93188890[0],
      code2: _93188890[1],
      code3: _93188890[2]
    }
  end
  def self.hinge(entity, depth = 0)
    return nil if depth > 3
    ents = KSU.entities_in(entity)
    return nil unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      if ent.get_attribute("ABF", "is-hinge-part-a") || ent.get_attribute("ABF", "is-hinge-part-b")
        name = ent.get_attribute("ABF", "setting-name").to_s
        return name unless name.empty?
      end
      half = hinge(ent, depth + 1)
      return half if half
    end
    nil
  end
  def self._f0ab79c9(gr, _4e80230a)
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
        pt = pt2.transform(_4e80230a)
        [(pt.x * 25.4).round(2), (pt.y * 25.4).round(2)]
      end
    end
    arr
  end
  def self.cups(entity, tf, depth = 0, out = [])
    return out if depth > 3
    ents = KSU.entities_in(entity)
    return out unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      tr = tf * ent.transformation
      if ent.get_attribute("ABF", "is-hinge-part-b")
        best = nil
        _f0ab79c9(ent, tr).each do |arr5|
          arr3 = arr5.map { |arr4| arr4[0] }
          arr2 = arr5.map { |arr4| arr4[1] }
          rsz = [arr3.max - arr3.min, arr2.max - arr2.min].max.round(2)
          next if best && best[0] >= rsz
          num2 = [((arr3.min + arr3.max) / 2).round(2), ((arr2.min + arr2.max) / 2).round(2)]
          best = [rsz, num2, arr5]
        end
        out << best if best
      else
        cups(ent, tr, depth + 1, out)
      end
    end
    out
  end
  def self._503b4f27(entity, tf, depth = 0, out = { names: [], paths: [] })
    return out if depth > 3
    ents = KSU.entities_in(entity)
    return out unless ents
    ents.each do |ent|
      next unless KSU.container?(ent)
      tr = tf * ent.transformation
      if ent.get_attribute("ZSU", "bao_ranh")
        name = ent.get_attribute("ABF", "statistical-name").to_s
        next if name.empty?
        out[:names] << name unless out[:names].include?(name)
        out[:paths].concat(_f0ab79c9(ent, tr))
      else
        _503b4f27(ent, tr, depth + 1, out)
      end
    end
    out
  end
  def self._d8a5a5cb(cutting_gr, tf)
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
    loops = _1391721f(arr2)
    _65e1bd60 = loops.index { |arr3| arr3[:outer] } || 0
    loops[0], loops[_65e1bd60] = loops[_65e1bd60], loops[0]
    loops.map { |arr3| arr3[:pts] }
  end
  def self._1391721f(h)
    arr = h.dup
    loops = []
    until arr.empty?
      arr2 = arr.shift
      pts = arr2[:pts].dup
      outer = arr2[:outer]
      flag = true
      while flag
        flag = false
        break if _fe5ae039(pts)
        _fc35762e = pts.last
        arr.each_with_index do |f, i|
          next if _fe5ae039(f[:pts])
          if _a8e56783(f[:pts].first, _fc35762e)
            pts.concat(f[:pts][1..-1])
          elsif _a8e56783(f[:pts].last, _fc35762e)
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
  def self._a8e56783(arr2, b)
    (arr2[0] - b[0]).abs < 0.05 && (arr2[1] - b[1]).abs < 0.05
  end
  def self._fe5ae039(pts)
    pts.length > 3 && _a8e56783(pts.first, pts.last)
  end
  def self.drills(grp, part_tf)
    arr3 = grp.get_attribute("ABF", "drills-desc")
    return [] unless arr3.is_a?(Array) && arr3[1].is_a?(Array)
    out = []
    arr3[1].each do |arr2|
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
  def self.ebs(grp, part_tf, _53962504)
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
      fields = _6eef93f0(_53962504, arr[6].to_s, fields)
      num.concat(fields) if fields
      out << num
    end
    out
  end
  def self._6eef93f0(arr, name, fields)
    return fields unless arr.is_a?(Array) && !arr.empty?
    if fields
      hit = arr.find { |thick| thick[0] == fields[0] && thick[3] == fields[3] }
    else
      hit = arr.find do |thick|
        !thick[0].empty? && name.start_with?(thick[0]) && _a1ae3880(name, thick[3])
      end
      hit ||= arr[0] if arr.length == 1 && _a1ae3880(name, arr[0][3])
    end
    hit || fields
  end
  def self._a1ae3880(name, _204e57f4)
    str = "#{_204e57f4}mm"
    return false unless name.end_with?(str)
    ch = name[-(str.length + 1), 1]
    ch.nil? || !(ch =~ /[\d.]/)
  end
end
