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
      ents, parts = scan_sheet(gr)
      ents.concat(sheet_id_text(rec, mat, num2, num))
      pt = gr.transformation.origin
      sheets << {
        id: rec[:id], key: key, mat: h[key],
        w: ent2[0].to_f, h: ent2[1].to_f,
        x: (pt.x.to_f * 25.4).round(2), y: (pt.y.to_f * 25.4).round(2),
        bottom: rec[:bottom], ents: ents, parts: parts
      }
    end
    h3 = layer_flags
    materials = h.keys.map do |k|
      { key: k, name: h[k], th: th[k].to_f,
        on: h3.key?(k) ? !!h3[k] : true }
    end
    { materials: materials, sheets: sheets, true_color: true_color }
  end
  def layer_flags
    id_str = KSU::Settings.get("vat_lieu_chon", "{}", "xuat_dxf").to_s
    h = JSON.parse(id_str)
    h.is_a?(Hash) ? h : {}
  rescue StandardError
    {}
  end
  def export_list(collect_in_rect)
    h = {}
    collect_in_rect[:sheets].each { |s| h[s[:key]] = true if s[:bottom] }
    show_back = !!KSU::Settings.get("hien_mat_sau", false, "xuat_dxf")
    sheets = []
    collect_in_rect[:sheets].each do |s|
      next if s[:bottom] && !show_back
      ents = []
      s[:ents].each do |ent|
        next if ent[:layer] == "ABF_sheetId" || ent[:layer] == "ABF_sheetMaterial"
        ents << {
          c: KSU::Xuatdxf.dxf_color(ent[:layer]),
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
                     name: KSU::Xuatdxf.dxf_name(s, h),
                     bottom: s[:bottom], ents: ents, parts: s[:parts] }
    end
    { materials: collect_in_rect[:materials], sheets: sheets }
  end
  def scan_sheet(sheet_grp)
    ents = []
    parts = []
    obj = KSU.entities_in(sheet_grp)
    return [ents, parts] unless obj
    obj.each do |entity|
      next unless KSU.container?(entity)
      pid = entity.get_attribute("ABF", "board-index")
      if pid && !KSU::Sheet.sheet_border?(entity)
        name = KSU::Label.label_text(entity).to_s
        name = pid.to_s if name.empty?
        pt = entity.bounds.center
        layers, prefix = layers_of(entity)
        parts << { id: pid, name: name, cb: layers, cp: prefix,
                      c: [(pt.x.to_f * 25.4).round(1), (pt.y.to_f * 25.4).round(1)] }
        walk_group(entity, entity.transformation, ents, pid)
      else
        walk_group(entity, entity.transformation, ents, nil)
      end
    end
    parts.sort_by! { |arr2| arr2[:id].to_i }
    [ents, parts]
  end
  def layers_of(panel)
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
  def walk_group(gr, tf3, ents, pid, parent_layer = nil)
    return if gr.get_attribute("ABF", "is-label")
    return if gr.get_attribute("ABF", "is-edge-banding-notation")
    str = gr.name.to_s
    def_name = (gr.respond_to?(:definition) && gr.definition) ? gr.definition.name.to_s : ""
    return if str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    is_border = KSU::Sheet.sheet_border?(gr)
    is_mark = gr.get_attribute("ABF", "is-mark-square")
    is_cut = gr.get_attribute("ABF", "is-cutting-lines")
    is_sect = gr.get_attribute("ABF", "is-intersect")
    obj = KSU.entities_in(gr)
    return unless obj
    normal = dxf_layer(gr, parent_layer)
    if is_cut
      seen = {}
      arr2 = []
      obj.grep(Sketchup::Edge).each do |ent|
        if ent.curve
          next if seen[ent.curve.entityID]
          seen[ent.curve.entityID] = true
          ents << { layer: dxf_layer(ent, normal), pts: xy_of(ent.curve.vertices, tf3),
                       closed: true, via_module: true, bulge: true, pid: pid, sect: false }
        else
          arr2 << ent
        end
      end
      tag = arr2.first ? dxf_layer(arr2.first, normal) : "0"
      merge_loops(arr2).each do |loop_pts|
        ents << { layer: tag, pts: xy_of(loop_pts, tf3),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: false }
      end
    elsif is_border || is_mark
      edge = obj.grep(Sketchup::Edge).first
      if edge && edge.curve
        ents << { layer: dxf_layer(edge, normal), pts: xy_of(edge.curve.vertices, tf3),
                     closed: is_border, via_module: false, bulge: false, pid: pid, sect: false,
                     border: is_border }
      end
    elsif is_sect
      h2 = {}
      obj.grep(Sketchup::Face).each do |f|
        ents << { layer: dxf_layer(f, normal), pts: xy_of(f.outer_loop.vertices, tf3),
                     closed: true, via_module: true, bulge: true, pid: pid, sect: true }
        f.outer_loop.edges.each { |ent| h2[ent.entityID] = true }
      end
      obj.grep(Sketchup::Edge).each do |ent|
        next if ent.curve
        next if h2[ent.entityID]
        ents << { layer: dxf_layer(ent, normal), pts: xy_of([ent.start, ent.end], tf3),
                     closed: false, via_module: false, bulge: false, pid: pid, sect: true }
      end
    else
      h2 = {}
      obj.grep(Sketchup::Face).each do |f|
        f.loops.each do |face|
          ents << { layer: dxf_layer(face.edges[0], normal), pts: xy_of(face.vertices, tf3),
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
          ents << { layer: dxf_layer(ent.curve.edges[0], normal), pts: xy_of(arr3, tf3),
                       closed: closed, via_module: true, bulge: true, pid: pid, sect: true }
        else
          ents << { layer: dxf_layer(ent, normal), pts: xy_of([ent.start, ent.end], tf3),
                       closed: false, via_module: false, bulge: false, pid: pid, sect: true }
        end
      end
    end
    obj.each do |entity|
      next unless KSU.container?(entity)
      walk_group(entity, tf3 * entity.transformation, ents, pid, normal)
    end
  end
  def xy_of(arr, tf3)
    arr.map do |v|
      pt = v.position.transform(tf3)
      [pt.x.to_f, pt.y.to_f]
    end
  end
  def sheet_id_text(rec, mat, sheet_w2, sheet_h2)
    return [] unless KSU::Font.import
    out = []
    num = 18.0
    id_txt = rec[:id].to_s
    if rec[:has_bottom]
      id_txt = id_txt + "-" + (rec[:bottom] ? "0" : "1")
      num = 16.0 if id_txt.size > 2
      num = 14.0 if id_txt.size > 3
      num = 12.0 if id_txt.size > 4
    end
    id_w = KSU::Font.half_width(id_txt)
    num = [num, (sheet_w2 - 0.123 * sheet_w2) / id_w].min if id_w > 0
    ty0 = sheet_h2 * 0.5 - (KSU::Font::HEIGHT * num / 2)
    KSU::Font.text_strokes(id_txt, [sheet_w2 * 0.5 - (id_w * num / 2), ty0], num).each do |poly|
      out << { layer: "ABF_sheetId", pts: poly, closed: false, via_module: false, bulge: false }
    end
    str = mat.to_s
    unless str.empty?
      txt_w = KSU::Font.half_width(str)
      flag = txt_w > 0 ? [8.0, (sheet_w2 - 0.123 * sheet_w2) / txt_w].min : 8.0
      KSU::Font.text_strokes(str, [sheet_w2 * 0.5 - (txt_w * flag / 2), ty0 + 0.45 * sheet_h2], flag).each do |poly|
        out << { layer: "ABF_sheetMaterial", pts: poly, closed: false, via_module: false, bulge: false }
      end
    end
    out
  end
end
