module KSU::Draw
  def draw_job(job, sheets)
    model = Sketchup.active_model
    model.layers.add("ABF_cuttingLines").color = Sketchup::Color.new(100, 160, 230) unless model.layers["ABF_cuttingLines"]
    %w[ABF_edgeBanding ABF_sheetBorder ABF_partBorder].each { |n| KSU::Cutting.layer(n) }
    _c38daa48 = model.layers["Layer0"]
    model.active_layer = _c38daa48 if _c38daa48 && model.active_layer != _c38daa48
    unless @root && @root.valid?
      prev_key = KSU::Nesting.find_nesting(notify: false)
      prev_key.erase! if prev_key && prev_key.valid?
      @root = model.entities.add_group
      @root.name = "__ABF_Nesting"
      @root.set_attribute("ABF", "is-nesting-root", true)
      @root.set_attribute("ABF", "shift-origin", @job_cfg[:margin])
      @root.hidden = true
    end
    _f3202297 = -(@_7cdc0010 + job[:slots]) * (@elem + KSU::Const::SHEET_V_PADDING)
    KSU::Sheet.add_row_label(@root.entities, job[:type][:name], _f3202297, @elem)
    @drawn_panels = []
    arr26 = sheets.each_with_index.map do |items, fill|
      @sheet_ix += 1
      gr, bottom = draw_sheet(job[:type], items, fill * (@w + KSU::Const::SHEET_H_PADDING), _f3202297)
      gr.set_attribute("KSU", "two-sided-sheet", true) if bottom
      [gr, bottom]
    end
    @_7cdc0010 += job[:slots]
    @_7cdc0010 += 1 if arr26.any?(&:last) && job[:slots] == 1
    @drawn_panels.select(&:valid?).each do |grp|
      grp.transformation = grp.transformation * Geom::Transformation.rotation(ORIGIN, Y_AXIS.transform(KSU::Cutting.tf_of(grp)), 180.degrees)
    end
    merge_cut_lines(arr26.flatten(1))
    arr26
  end
  def place_root
    sheets = @root.definition.entities.select { |grp| KSU::Sheet.sheet?(grp) }
    return if sheets.empty? || !@w || !@elem
    pt3 = sheets.map { |grp| grp.transformation.origin.x.to_f + @w.to_f }
    pt2 = sheets.map { |grp| grp.transformation.origin.y.to_f + @elem.to_f }
    pt = Geom::Point3d.new(pt3.max, pt2.max, 0).transform(@root.transformation)
    dx, dy = -1.m - pt.x, -1.m - pt.y
    return if dx.abs < 1e-9 && dy.abs < 1e-9
    @root.transformation = Geom::Transformation.translation([dx, dy, 0]) * @root.transformation
  end
  def finish_draw
    return unless @root && @root.valid?
    root, @root = @root, nil
    notify("Cảnh báo: có vấn đề khi xử lý tấm #{tail_pt(@arr9.uniq)}.", @arr9.uniq) unless @arr9.empty?
    tidy_borders(root)
  rescue StandardError
    @root = nil
  end
  def new_sheet_group(sheet_type, bot)
    gr = @root.entities.add_group
    gr.name = "__#{sheet_type[:name]}-sheet-#{@sheet_ix}#{"-bottom" if bot}"
    gr.set_attribute("ABF", "sheet-id", @sheet_ix)
    gr.set_attribute("ABF", "is-bottom-sheet", true) if bot
    gr.set_attribute("ABF", "sheet-type", sheet_type[:name])
    gr.set_attribute("KSU", "sheet-material", sheet_type[:material].to_s)
    gr.set_attribute("ABF", "sheet-thickness", sheet_type[:thickness_mm])
    gr.set_attribute("ABF", "sheet-dimension", [@job_cfg[:sheet_w], @job_cfg[:sheet_h]])
    gr
  end
  def add_marker_loop(defn, attr, tag, *pts2)
    gr = defn.entities.add_group
    gr.set_attribute("ABF", attr, true)
    gr.name = "__" + tag
    gr.entities.add_curve(*pts2)
    KSU::Cutting.set_layer(gr, KSU::Cutting.layer(tag))
  end
  def draw_sheet(sheet_type, arr3, ox, oy)
    sheet_grp = new_sheet_group(sheet_type, false)
    add_marker_loop(sheet_grp, "is-sheet-border", "ABF_sheetBorder", [0, 0, 0], [@w, 0, 0], [@w, @elem, 0], [0, @elem, 0], [0, 0, 0])
    sheet_grp.transformation = sheet_grp.transformation * Geom::Transformation.translation([ox, oy, 0])
    KSU::Sheet.add_sheet_label(@root.entities, sheet_grp, @sheet_ix, @w, @sheet_ix.to_s.rjust(2, "0"))
    arr, h7 = [], {}
    _0797bf69, flag = arr3.any? { |arr5| arr5[0][:two_sided] } ? [KSU::Avail.two_sided_margin.mm] * 2 : [@m_left, @m_bottom]
    arr3.each do |fld|
      gr, board_index = draw_part(sheet_grp, fld[0], fld[1] / 25.4 + _0797bf69, fld[2] / 25.4 + flag, fld[3])
      arr << board_index if board_index
      (h7[fld[4]] ||= []) << gr if @job_cfg[:nhom_cap] && fld[4] >= 0
    end
    h7.each_value do |groups|
      arr2 = groups.select(&:valid?)
      next if arr2.size < 2
      @num12 = @num12.to_i + 1
      str = (Time.now.to_f * 1000).to_i.to_s(36) + @num12.to_s(36)
      arr2.each { |grp| grp.set_attribute("KSU", "group-id", str) }
    end
    [sheet_grp, arr.empty? ? nil : draw_bottom_sheet(sheet_type, arr, ox, oy)]
  end
  def draw_part(sheet_grp, grp, x, y, deg4)
    inv_tf = grp[:part_tf].inverse
    gr = sheet_grp.entities.add_group
    KSU::Cutting.copy_attrs(gr, grp[:group])
    cutting_gr = gr.entities.add_group
    cutting_gr.name = "_ABF_cuttingLines"
    grp[:cutting_lines].each_with_index do |pts2, i|
      lp = cutting_gr.entities.add_curve(pts2)
      lp.grep(Sketchup::Edge).each { |grp2| grp2.set_attribute("ABF", "is-outer-loop", true) } if i == grp[:outer_index] && lp
    end
    cutting_gr.transformation = cutting_gr.transformation * inv_tf
    cutting_gr.set_attribute("ABF", "is-cutting-lines", true)
    KSU::Cutting.set_layer(cutting_gr, KSU::Cutting.layer("ABF_cuttingLines"))
    max_eb = gr.entities.add_group
    max_eb.name = "_ABF_edgeBanding"
    grp[:edge_band_lines].each { |pts2| max_eb.entities.add_curve(pts2) }
    max_eb.transformation = max_eb.transformation * inv_tf
    max_eb.set_attribute("ABF", "is-edge-banding-notation", true)
    KSU::Cutting.set_layer(max_eb, KSU::Cutting.layer("ABF_edgeBanding"))
    gr.transformation = gr.transformation * Geom::Transformation.translation([x, y, 0]) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, deg4.degrees) * grp[:part_tf]
    KSU::Cutting.save_drills_desc(gr, grp[:drills], inv_tf)
    KSU::Cutting.save_edgeband_desc(gr, grp[:edge_band_desc], inv_tf)
    (KSU.entities_in(grp[:group]) || []).grep(Sketchup::Group).each do |grp2|
      grp2.set_attribute("ABF", "is-user-nesting-obj", true) if grp2.name.to_s.start_with?("ABF_")
    end
    faces = KSU::Cutting.split_by_face(grp[:group], grp[:up_face], grp[:tf])
    definitions_of(gr.entities, faces[:up])
    ents = definitions_of(gr.entities, [faces[:label]])[0]
    return [gr, nil] if faces[:bottom].empty?
    [gr, { part_id: grp[:group].get_attribute("ABF", "board-index"), name: gr.name,
              label_gr: ents, cutting_gr: cutting_gr, bottom: faces[:bottom], tf: gr.transformation }]
  end
  def definitions_of(ents, entries)
    entries.filter_map do |grp|
      next unless grp.respond_to?(:definition) && grp.definition
      ents.add_instance(grp.definition, grp.transformation).tap { |inst| KSU::Cutting.copy_and_flatten(inst, grp) }
    end
  end
  def draw_bottom_sheet(sheet_type, arr2, ox, oy)
    bottom = new_sheet_group(sheet_type, true)
    bottom.transformation = bottom.transformation * Geom::Transformation.translation([ox, oy + @elem + KSU::Const::SHEET_V_PADDING / 2, 0])
    arr2.each do |arr|
      panel = bottom.entities.add_group
      panel.name = arr[:name]
      panel.transformation = arr[:tf]
      grp = panel.entities.add_instance(arr[:cutting_gr].definition, arr[:cutting_gr].transformation)
      grp.name = arr[:cutting_gr].name
      grp.make_unique
      grp.set_attribute("ABF", "is-cutting-lines", true)
      KSU::Cutting.set_layer(grp, KSU::Cutting.layer("ABF_partBorder"))
      definitions_of(panel.entities, arr[:bottom])
      if arr[:label_gr]
        tr = panel.entities.add_instance(arr[:label_gr].definition, arr[:label_gr].transformation)
        tr.name = arr[:label_gr].name
        tr.set_attribute("ABF", "is-label", true)
        @drawn_panels << tr
      end
      panel.set_attribute("ABF", "board-index", arr[:part_id])
      panel.set_attribute("ABF", "is-bottom-face", true)
    end
    bottom.entities.transform_entities(Geom::Transformation.rotation(ORIGIN, Y_AXIS, 180.degrees) *
                                       Geom::Transformation.translation([-(@w - @m_left), @m_bottom, 0]), bottom.entities.to_a)
    add_marker_loop(bottom, "is-sheet-border", "ABF_sheetBorder", [0, 0, 0], [@w, 0, 0], [@w, @elem, 0], [0, @elem, 0], [0, 0, 0])
    add_marker_loop(bottom, "is-mark-square", "ABF_markSquare", [@w - @m_left, @elem, 0], [@w - @m_left, @m_bottom, 0], [0, @m_bottom, 0])
    KSU::Sheet.add_sheet_label(@root.entities, bottom, @sheet_ix, @w, @sheet_ix.to_s.rjust(2, "0"))
    bottom
  end
  def merge_cut_lines(arr)
    return unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union)
    arr.each do |grp2|
      next unless grp2 && grp2.valid?
      grp2.entities.grep(Sketchup::Group).each { |grp| merge_intersects(grp) unless KSU::Sheet.sheet_border?(grp) }
    end
  end
  def merge_intersects(grp)
    groups = KSU::Cutting.kids_with_attr(grp, "is-intersect")
    return unless groups && groups.size > 1
    arr = intersect_recs(groups)
    return if arr.size < 2
    n = arr.size
    arr2 = Array.new(n) { Array.new(n, false) }
    (0...n).to_a.combination(2) do |i, ix|
      next unless arr[i][:layer_name] == arr[ix][:layer_name] && !arr[i][:rect].intersect(arr[ix][:rect]).empty?
      arr2[i][ix] = arr2[ix][i] = true
    end
    arr.zip(color_components(n, arr2)).group_by(&:last).each_value { |sub| union_into(sub.map(&:first), grp) if sub.size > 1 }
  end
  def intersect_recs(groups)
    groups.filter_map do |gr|
      src = (KSU.entities_in(gr) || []).grep(Sketchup::Face)
      next if src.empty?
      tf = KSU::Cutting.tf_of(gr)
      arr = src.lazy.map { |f| f.edges[0]&.layer }.find(&:itself)
      polys = src.map { |f| f.outer_loop.vertices.map { |v| v.position.transform(tf).then { |pt| [pt.x.to_f, pt.y.to_f] } } }
      bbox = gr.definition.bounds
      lo, hi = bbox.min.transform(tf), bbox.max.transform(tf)
      { gr: gr, rect: Geom::BoundingBox.new.add([lo.x, lo.y, 0], [hi.x, hi.y, 0]), layer: arr, layer_name: arr ? arr.name : "", polys: polys }
    end
  end
  def color_components(n, arr2)
    color, c = Array.new(n, 0), 0
    (0...n).each do |i|
      next unless color[i] == 0
      color[i] = c += 1
      arr = [i]
      until arr.empty?
        _7a72dc50 = arr.pop
        (0...n).each do |ix|
          next unless color[ix] == 0 && arr2[_7a72dc50][ix]
          color[ix] = c
          arr << ix
        end
      end
    end
    color
  end
  def union_into(arr, defn)
    ok = false
    KSU::Clipper.union(arr.flat_map { |i| i[:polys] }, 6).each do |arr2|
      next if arr2.length < 3
      grp = defn.entities.add_group
      inv_tf = KSU::Cutting.tf_of(grp).inverse
      pt = arr2.map { |arr3| Geom::Point3d.new(arr3[0], arr3[1], 0).transform(inv_tf) }
      begin
        grp.entities.add_face(pt)
      rescue StandardError
        grp.erase!
        next
      end
      grp.name = "_ABF_Intersect"
      grp.set_attribute("ABF", "is-intersect", true)
      grp.material = KSU::Cutting.transparent_material
      KSU::Cutting.set_layer(grp, arr[0][:layer])
      ok = true
    end
    defn.entities.erase_entities(arr.map { |i| i[:gr] }) if ok
  end
  def tidy_borders(root)
    return unless root && root.valid?
    root.entities.grep(Sketchup::Group).each do |grp2|
      next unless grp2.get_attribute("ABF", "sheet-id")
      ents = grp2.entities.grep(Sketchup::Group)
      bd2 = ents.find { |c| KSU::Sheet.sheet_border?(c) }
      next unless bd2
      rect = bbox2d(bd2)
      ents.each do |grp|
        next if grp == bd2
        next unless KSU::Cutting.kids_with_attr(grp, "is-cutting-lines")&.any? { |kids| rect_inside?(rect, bbox2d(kids)) }
        id = grp.get_attribute("ABF", "board-index")
        @arr21 << id.to_s if id && @arr21
      end
    end
  end
  def bbox2d(gr)
    tf = KSU::Cutting.tf_of(gr)
    b = gr.definition.bounds
    bb, arr = [0, 1, 2, 4].map { |i| b.corner(i).transform(tf).then { |pt| [pt.x.to_f, pt.y.to_f] } }.transpose
    { x1: bb.min, y1: arr.max, x2: bb.max, y2: arr.min }
  end
  def rect_inside?(defn, arr)
    eps = 0.001.mm
    arr[:x1] < defn[:x1] - eps || arr[:x2] > defn[:x2] + eps ||
      arr[:y1] > defn[:y1] + eps || arr[:y2] < defn[:y2] - eps
  end
end
KSU::Nest.extend(KSU::Draw)
