module KSU::Giacong
  module_function
  def collect_in_rect(nesting)
    arr2, bot = KSU::Sheet.sheet_maps(nesting)
    arr = []
    arr2.each do |id, gr|
      arr << { id: id, gr: gr, bottom: false, has_bottom: bot.key?(id) }
    end
    bot.each do |id, gr|
      arr << { id: id, gr: gr, bottom: true, has_bottom: true }
    end
    arr.sort_by! { |i| i[:id].to_i * 10000 + (i[:bottom] ? 0 : 1) }
    model2 = Sketchup.active_model.layers.any? do |grp|
      !info_layer?(grp.name) && grp.get_attribute("ABF", "cutting-layer-original-name")
    end
    sheets = []
    arr.each do |rec|
      gr = rec[:gr]
      next unless gr && gr.valid?
      sheet_type = gr.get_attribute("ABF", "sheet-type").to_s
      mat = gr.get_attribute("KSU", "sheet-material").to_s
      mat = sheet_type if mat.empty?
      key = sheet_type.empty? ? mat : sheet_type
      ent2 = gr.get_attribute("ABF", "sheet-dimension", [1220, 2440])
      num2 = ent2[0].to_f.mm
      num = ent2[1].to_f.mm
      ents = sheet_entities(gr)
      ents.concat(text_outlines(rec, mat, num2, num))
      sheets << {
        id: rec[:id], key: key, bottom: rec[:bottom], ents: ents, gr: gr,
        front: arr2[rec[:id]] || gr, tr: nesting.transformation * gr.transformation
      }
    end
    { sheets: sheets, true_color: model2 }
  end
  def info_layer?(name)
    %w[ABF_sheetId ABF_sheetMaterial].include?(name.to_s)
  end
  def sheet_entities(sheet_grp)
    ents = []
    obj = KSU.entities_in(sheet_grp)
    return ents unless obj
    obj.each do |grp|
      next unless KSU.container?(grp)
      next if grp.get_attribute("ABF", "is-sheet-id") || grp.get_attribute("ABF", "is-sheet-material")
      pid = grp.get_attribute("ABF", "board-index")
      pid = nil if KSU::Sheet.sheet_border?(grp)
      scan_group(grp, grp.transformation, ents, pid)
    end
    ents
  end
  def layer(entity, normal)
    name = entity ? entity.layer.name.to_s : ""
    name = "Layer0" if info_layer?(name)
    return name unless name.empty? || name == "Layer0"
    normal.to_s.empty? ? name : normal
  end
  def scan_group(gr, _a17fc600, ents, pid, _e6398f51 = nil)
    return if gr.get_attribute("ABF", "is-label")
    return if gr.get_attribute("ABF", "is-edge-banding-notation")
    str = gr.name.to_s
    def_name = (gr.respond_to?(:definition) && gr.definition) ? gr.definition.name.to_s : ""
    return if str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    is_border = KSU::Sheet.sheet_border?(gr)
    _b2169942 = gr.get_attribute("ABF", "is-mark-square")
    _ea2023f0 = gr.get_attribute("ABF", "is-cutting-lines")
    _31db2d43 = gr.get_attribute("ABF", "is-intersect")
    obj = KSU.entities_in(gr)
    return unless obj
    normal = layer(gr, _e6398f51)
    if _ea2023f0
      h = {}
      arr = []
      obj.grep(Sketchup::Edge).each do |edge2|
        if edge2.curve
          next if h[edge2.curve.entityID]
          h[edge2.curve.entityID] = true
          ents << { layer: layer(edge2, normal), pts: pts(edge2.curve.vertices, _a17fc600),
                       closed: true, via_module: true, bulge: true, pid: pid, sect: false, src: edge2 }
        else
          arr << edge2
        end
      end
      flag = arr.first ? layer(arr.first, normal) : "0"
      build_loops(arr).each do |_99b739cb|
        ents << { layer: flag, pts: pts(_99b739cb, _a17fc600),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: false, src: arr.first }
      end
    elsif is_border || _b2169942
      edge = obj.grep(Sketchup::Edge).first
      if edge && edge.curve
        ents << { layer: layer(edge, normal), pts: pts(edge.curve.vertices, _a17fc600),
                     closed: is_border, via_module: false, bulge: false, pid: pid, sect: false,
                     border: is_border, src: edge }
      end
    elsif _31db2d43
      taken = {}
      obj.grep(Sketchup::Face).each do |f|
        ents << { layer: layer(f, normal), pts: pts(f.outer_loop.vertices, _a17fc600),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: true, src: f.outer_loop.edges[0] }
        f.outer_loop.edges.each { |edge2| taken[edge2.entityID] = true }
      end
      obj.grep(Sketchup::Edge).each do |edge2|
        next if edge2.curve
        next if taken[edge2.entityID]
        ents << { layer: layer(edge2, normal), pts: pts([edge2.start, edge2.end], _a17fc600),
                     closed: false, via_module: false, bulge: false, pid: pid, sect: true, src: edge2 }
      end
    else
      taken = {}
      obj.grep(Sketchup::Face).each do |f|
        f.loops.each do |face|
          ents << { layer: layer(face.edges[0], normal), pts: pts(face.vertices, _a17fc600),
                       closed: true, via_module: true, bulge: true, pid: pid, sect: true, src: face.edges[0] }
          face.edges.each { |edge2| taken[edge2.entityID] = true }
        end
      end
      h = {}
      obj.grep(Sketchup::Edge).each do |edge2|
        next if taken[edge2.entityID]
        if edge2.curve
          next if h[edge2.curve.entityID]
          h[edge2.curve.entityID] = true
          arr2 = edge2.curve.vertices
          closed = arr2.first.position == arr2.last.position
          ents << { layer: layer(edge2.curve.edges[0], normal), pts: pts(arr2, _a17fc600),
                       closed: closed, via_module: true, bulge: true, pid: pid, sect: true, src: edge2 }
        else
          ents << { layer: layer(edge2, normal), pts: pts([edge2.start, edge2.end], _a17fc600),
                       closed: false, via_module: false, bulge: false, pid: pid, sect: true, src: edge2 }
        end
      end
    end
    obj.each do |grp|
      next unless KSU.container?(grp)
      scan_group(grp, _a17fc600 * grp.transformation, ents, pid, normal)
    end
  end
  def pts(arr, _a17fc600)
    arr.map do |v|
      pt = v.position.transform(_a17fc600)
      [pt.x.to_f, pt.y.to_f]
    end
  end
  def text_outlines(rec, mat, _aec9a3e4, _3f9664d4)
    return [] unless KSU::Font.import
    out = []
    num = 18.0
    _9744b478 = rec[:id].to_s
    if rec[:has_bottom]
      _9744b478 = _9744b478 + "-" + (rec[:bottom] ? "0" : "1")
      num = 16.0 if _9744b478.size > 2
      num = 14.0 if _9744b478.size > 3
      num = 12.0 if _9744b478.size > 4
    end
    _4589850d = KSU::Font.half_width(_9744b478)
    num = [num, (_aec9a3e4 - 0.123 * _aec9a3e4) / _4589850d].min if _4589850d > 0
    y1 = _3f9664d4 * 0.5 - (KSU::Font::HEIGHT * num / 2)
    KSU::Font.text_strokes(_9744b478, [_aec9a3e4 * 0.5 - (_4589850d * num / 2), y1], num).each do |pts|
      out << { layer: "ABF_sheetId", pts: pts, closed: false, via_module: false, bulge: false }
    end
    str = mat.to_s
    unless str.empty?
      _c3b38880 = KSU::Font.half_width(str)
      flag = _c3b38880 > 0 ? [8.0, (_aec9a3e4 - 0.123 * _aec9a3e4) / _c3b38880].min : 8.0
      KSU::Font.text_strokes(str, [_aec9a3e4 * 0.5 - (_c3b38880 * flag / 2), y1 + 0.45 * _3f9664d4], flag).each do |pts|
        out << { layer: "ABF_sheetMaterial", pts: pts, closed: false, via_module: false, bulge: false }
      end
    end
    out
  end
  def edge_index(db)
    db.vectors.each_with_object({}) do |rec, snap_edges|
      ::KSU::Cnc::Dialog.entities_in(rec).each { |edge| snap_edges[edge.entityID] ||= rec }
    end
  end
  def scan_cached(db, arr, _502c66f2)
    @scan_memo = [db, {}, nil] unless @scan_memo && @scan_memo[0].equal?(db)
    done = @scan_memo[1]
    idx = ::KSU::Cnc::Canvas.sheet_index(db)
    sheets = ::KSU::Cnc::Canvas.sheet_rows(db)
    rows, pending, h = {}, [], false
    arr.uniq.each do |id|
      unless done.key?(id)
        next pending << id if h && ::KSU::Cnc::Util.now - _502c66f2 > 0.3
        index = idx[id]
        snap_edges = (@scan_memo[2] ||= edge_index(db))
        done[id] = index ? vectors_to_xy(sheets[index][:vectors], snap_edges) : []
        h = true
      end
      rows[id] = done[id]
    end
    { sheets: rows, pending: pending }
  end
  def vectors_to_xy(vectors, snap_edges)
    anchor = ::KSU::Cnc::Export.origin_of(vectors)
    return [] unless anchor
    vectors.filter_map(&:sheet_entity).uniq.flat_map do |gr|
      flag = gr.valid? && tag_board_chain(vectors, gr)
      next [] unless flag
      sheet_entities(gr).filter_map do |entity|
        next unless entity[:sect] && !(entity[:src] && (snap_edges[entity[:src].entityID] || info_layer?(entity[:src].layer.name)))
        out = entity[:pts].map { |x, y| ::KSU::Cnc::Export.to_mm(::Geom::Point3d.new(x, y, 0).transform(flag), anchor) }
        out = ::KSU::Cnc::Canvas.round_path(out)
        out.pop if entity[:closed] && out.length > 2 && out.first == out.last
        next if out.length < 2
        { layer: entity[:layer] == "Layer0" ? "Untagged" : entity[:layer], points: out, closed: entity[:closed] }
      end
    end
  end
  def tag_board_chain(vectors, gr)
    vectors.each do |vec|
      arr = Array(vec.board_chain)
      flag = arr.index { |fld| fld.equal?(gr) }
      return arr[0..flag].map(&:transformation).inject(:*) if flag
    end
    nesting = Sketchup.active_model.entities.find { |fld| KSU.container?(fld) && KSU.entities_in(fld).include?(gr) }
    nesting && nesting.transformation * gr.transformation
  end
end
