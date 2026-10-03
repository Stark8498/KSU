module KSU::Xuatdxf
  module_function
  def collect_in_rect(nesting)
    arr5, bot = KSU::Sheet.sheet_maps(nesting)
    arr3 = []
    arr5.each do |id, gr|
      arr3 << { id: id, gr: gr, bottom: false, has_bottom: bot.key?(id) }
    end
    bot.each do |id, gr|
      arr3 << { id: id, gr: gr, bottom: true, has_bottom: true }
    end
    arr3.sort_by! { |i| i[:id].to_i * 10000 + (i[:bottom] ? 0 : 1) }
    true_color = Sketchup.active_model.layers.any? do |grp|
      grp.get_attribute("ABF", "cutting-layer-original-name")
    end
    sheets = []
    h = {}
    th = {}
    arr3.each do |rec|
      gr = rec[:gr]
      next unless gr && gr.valid?
      sheet_type = gr.get_attribute("ABF", "sheet-type").to_s
      mat = gr.get_attribute("KSU", "sheet-material").to_s
      mat = sheet_type if mat.empty?
      key = sheet_type.empty? ? mat : sheet_type
      h[key] ||= mat
      th[key] ||= gr.get_attribute("ABF", "sheet-thickness").to_f
      ent2 = gr.get_attribute("ABF", "sheet-dimension", [1220, 2440])
      num2 = ent2[0].to_f.mm
      num = ent2[1].to_f.mm
      ents, parts = _daa2f929(gr)
      ents.concat(_cdd54f61(rec, mat, num2, num))
      pt = gr.transformation.origin
      sheets << {
        id: rec[:id], key: key, mat: h[key],
        w: ent2[0].to_f, h: ent2[1].to_f,
        x: (pt.x.to_f * 25.4).round(2), y: (pt.y.to_f * 25.4).round(2),
        bottom: rec[:bottom], ents: ents, parts: parts
      }
    end
    _884dee16 = _4d1bd02d
    materials = h.keys.map do |k|
      { key: k, name: h[k], th: th[k].to_f,
        on: _884dee16.key?(k) ? !!_884dee16[k] : true }
    end
    { materials: materials, sheets: sheets, true_color: true_color }
  end
  def _4d1bd02d
    id_str = KSU::Settings.get("vat_lieu_chon", "{}", "xuat_dxf").to_s
    _27161c40 = JSON.parse(id_str)
    _27161c40.is_a?(Hash) ? _27161c40 : {}
  rescue StandardError
    {}
  end
  def _89a2e173(collect_in_rect)
    h = {}
    collect_in_rect[:sheets].each { |s| h[s[:key]] = true if s[:bottom] }
    _9c089a0b = !!KSU::Settings.get("hien_mat_sau", false, "xuat_dxf")
    sheets = []
    collect_in_rect[:sheets].each do |s|
      next if s[:bottom] && !_9c089a0b
      ents = []
      s[:ents].each do |ent|
        next if ent[:layer] == "ABF_sheetId" || ent[:layer] == "ABF_sheetMaterial"
        ents << {
          c: KSU::Xuatdxf._302ced66(ent[:layer]),
          closed: ent[:closed],
          bd: ent[:border] ? 1 : 0,
          p: ent[:pid],
          s: ent[:sect] ? 1 : 0,
          v: ent[:via_module] ? 1 : 0,
          b: ent[:bulge] ? 1 : 0,
          pts: ent[:pts].map { |arr2| [(arr2[0] * 25.4).round(4), (arr2[1] * 25.4).round(4)] }
        }
      end
      sheets << { id: s[:id], key: s[:key], mat: s[:mat], w: s[:w], h: s[:h],
                     x: s[:x], y: s[:y],
                     name: KSU::Xuatdxf._c57d63ae(s, h),
                     bottom: s[:bottom], ents: ents, parts: s[:parts] }
    end
    { materials: collect_in_rect[:materials], sheets: sheets }
  end
  def _daa2f929(_d4a205ac)
    ents = []
    parts = []
    obj = KSU.entities_in(_d4a205ac)
    return [ents, parts] unless obj
    obj.each do |entity|
      next unless KSU.container?(entity)
      pid = entity.get_attribute("ABF", "board-index")
      if pid && !KSU::Sheet._27ecfdd1(entity)
        name = KSU::Label.label_text(entity).to_s
        name = pid.to_s if name.empty?
        pt = entity.bounds.center
        layers, prefix = _530b02a3(entity)
        parts << { id: pid, name: name, cb: layers, cp: prefix,
                      c: [(pt.x.to_f * 25.4).round(1), (pt.y.to_f * 25.4).round(1)] }
        _7c10a028(entity, entity.transformation, ents, pid)
      else
        _7c10a028(entity, entity.transformation, ents, nil)
      end
    end
    parts.sort_by! { |arr2| arr2[:id].to_i }
    [ents, parts]
  end
  def _530b02a3(panel)
    cutting = KSU::Cutting.cutting_group(panel)
    return [nil, nil] unless cutting
    grp = cutting.layer
    num2 = grp.get_attribute("ABF", "cutting-layer-postfix")
    if num2.nil?
      meta = grp.name.to_s.match(/\A(.*?)\s*(\d+)\z/)
      layers = meta ? meta[2].to_i : 0
      prefix = meta ? meta[1] : ""
    else
      layers = num2.to_i
      prefix = grp.get_attribute("ABF", "cutting-layer-original-name").to_s
    end
    layers > 0 ? [layers, prefix.strip] : [nil, nil]
  end
  def dxf_layer(entity, normal)
    name = entity ? entity.layer.name.to_s : ""
    return name unless name.empty? || name == "Layer0"
    normal.to_s.empty? ? name : normal
  end
  def _7c10a028(gr, _7bafc8a5, ents, pid, _8d6669ce = nil)
    return if gr.get_attribute("ABF", "is-label")
    return if gr.get_attribute("ABF", "is-edge-banding-notation")
    name = gr.name.to_s
    def_name = (gr.respond_to?(:definition) && gr.definition) ? gr.definition.name.to_s : ""
    return if name.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    _27846c89 = KSU::Sheet._27ecfdd1(gr)
    _84dcc166 = gr.get_attribute("ABF", "is-mark-square")
    _bc8516a9 = gr.get_attribute("ABF", "is-cutting-lines")
    _20c319d6 = gr.get_attribute("ABF", "is-intersect")
    obj = KSU.entities_in(gr)
    return unless obj
    normal = dxf_layer(gr, _8d6669ce)
    if _bc8516a9
      seen = {}
      arr2 = []
      obj.grep(Sketchup::Edge).each do |ent|
        if ent.curve
          next if seen[ent.curve.entityID]
          seen[ent.curve.entityID] = true
          ents << { layer: dxf_layer(ent, normal), pts: pts(ent.curve.vertices, _7bafc8a5),
                       closed: true, via_module: true, bulge: true, pid: pid, sect: false }
        else
          arr2 << ent
        end
      end
      layer = arr2.first ? dxf_layer(arr2.first, normal) : "0"
      _c73c2639(arr2).each do |_c9fa72f2|
        ents << { layer: layer, pts: pts(_c9fa72f2, _7bafc8a5),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: false }
      end
    elsif _27846c89 || _84dcc166
      edge = obj.grep(Sketchup::Edge).first
      if edge && edge.curve
        ents << { layer: dxf_layer(edge, normal), pts: pts(edge.curve.vertices, _7bafc8a5),
                     closed: _27846c89, via_module: false, bulge: false, pid: pid, sect: false,
                     border: _27846c89 }
      end
    elsif _20c319d6
      h2 = {}
      obj.grep(Sketchup::Face).each do |f|
        ents << { layer: dxf_layer(f, normal), pts: pts(f.outer_loop.vertices, _7bafc8a5),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: true }
        f.outer_loop.edges.each { |ent| h2[ent.entityID] = true }
      end
      obj.grep(Sketchup::Edge).each do |ent|
        next if ent.curve
        next if h2[ent.entityID]
        ents << { layer: dxf_layer(ent, normal), pts: pts([ent.start, ent.end], _7bafc8a5),
                     closed: false, via_module: false, bulge: false, pid: pid, sect: true }
      end
    else
      h2 = {}
      obj.grep(Sketchup::Face).each do |f|
        f.loops.each do |face|
          ents << { layer: dxf_layer(face.edges[0], normal), pts: pts(face.vertices, _7bafc8a5),
                       closed: true, via_module: true, bulge: true, pid: pid, sect: true }
          face.edges.each { |ent| h2[ent.entityID] = true }
        end
      end
      seen = {}
      obj.grep(Sketchup::Edge).each do |ent|
        next if h2[ent.entityID]
        if ent.curve
          next if seen[ent.curve.entityID]
          seen[ent.curve.entityID] = true
          arr3 = ent.curve.vertices
          closed = arr3.first.position == arr3.last.position
          ents << { layer: dxf_layer(ent.curve.edges[0], normal), pts: pts(arr3, _7bafc8a5),
                       closed: closed, via_module: true, bulge: true, pid: pid, sect: true }
        else
          ents << { layer: dxf_layer(ent, normal), pts: pts([ent.start, ent.end], _7bafc8a5),
                       closed: false, via_module: false, bulge: false, pid: pid, sect: true }
        end
      end
    end
    obj.each do |entity|
      next unless KSU.container?(entity)
      _7c10a028(entity, _7bafc8a5 * entity.transformation, ents, pid, normal)
    end
  end
  def pts(arr, _7bafc8a5)
    arr.map do |v|
      pt = v.position.transform(_7bafc8a5)
      [pt.x.to_f, pt.y.to_f]
    end
  end
  def _cdd54f61(rec, mat, _8ddd8c6f, _68165b06)
    return [] unless KSU::Font.import
    out = []
    num = 18.0
    _5cb20db4 = rec[:id].to_s
    if rec[:has_bottom]
      _5cb20db4 = _5cb20db4 + "-" + (rec[:bottom] ? "0" : "1")
      num = 16.0 if _5cb20db4.size > 2
      num = 14.0 if _5cb20db4.size > 3
      num = 12.0 if _5cb20db4.size > 4
    end
    _6b31f7ce = KSU::Font.half_width(_5cb20db4)
    num = [num, (_8ddd8c6f - 0.123 * _8ddd8c6f) / _6b31f7ce].min if _6b31f7ce > 0
    _60000b16 = _68165b06 * 0.5 - (KSU::Font::HEIGHT * num / 2)
    KSU::Font._1ff4cc8f(_5cb20db4, [_8ddd8c6f * 0.5 - (_6b31f7ce * num / 2), _60000b16], num).each do |pts|
      out << { layer: "ABF_sheetId", pts: pts, closed: false, via_module: false, bulge: false }
    end
    str = mat.to_s
    unless str.empty?
      _4c541df4 = KSU::Font.half_width(str)
      flag = _4c541df4 > 0 ? [8.0, (_8ddd8c6f - 0.123 * _8ddd8c6f) / _4c541df4].min : 8.0
      KSU::Font._1ff4cc8f(str, [_8ddd8c6f * 0.5 - (_4c541df4 * flag / 2), _60000b16 + 0.45 * _68165b06], flag).each do |pts|
        out << { layer: "ABF_sheetMaterial", pts: pts, closed: false, via_module: false, bulge: false }
      end
    end
    out
  end
end
