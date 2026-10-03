module KSU::Draw
  def reset_layout
    cfg = @cfg
    @w = cfg[:sheet_w].mm
    @h = cfg[:sheet_h].mm
    @m_left, @m_right, @top, @m_bottom = KSU::Nest.margins_of(cfg).map { |v| v.mm }
    @errors = []
    @sheet_ix = 0
    @num = 0
    @root = nil
  end
  def ensure_root(model)
    return @root if @root && @root.valid?
    prev_key = KSU::Nesting.find_nesting(notify: false)
    prev_key.erase! if prev_key && prev_key.valid?
    gr = model.entities.add_group
    gr.name = "__ABF_Nesting"
    gr.set_attribute("ABF", "is-nesting-root", true)
    gr.set_attribute("ABF", "shift-origin", @cfg[:margin])
    @root = gr
  end
  def draw_job(job, sheets)
    model = Sketchup.active_model
    KSU.start
    begin
      _a2d1d319(model)
      _fc5affbb = model.layers["Layer0"]
      model.active_layer = _fc5affbb if _fc5affbb && model.active_layer != _fc5affbb
      ensure_root(model)
      _ba93b302 = -(@num + job[:slots]) * (@h + KSU::Const::SHEET_V_PADDING)
      KSU::Sheet._edd17adf(@root.entities, job[:type][:name], _ba93b302, @h)
      @drawn_panels = []
      @drawn_sheets = []
      arr2 = []
      flag = false
      sheets.each_with_index do |items, fill|
        @sheet_ix += 1
        _8af8d41e = fill * (@w + KSU::Const::SHEET_H_PADDING)
        gr, _8486f8b2 = draw_sheet(@root, job[:type], items, @sheet_ix, _8af8d41e, _ba93b302, @cfg)
        gr.set_attribute("KSU", "two-sided-sheet", true) if gr && gr.valid? && _8486f8b2
        arr2 << gr
        flag = true if _8486f8b2
      end
      @num += job[:slots]
      @num += 1 if flag && job[:slots] == 1
      _c91f065e
      _ce93a4c7(@drawn_sheets)
      place_root
      KSU.commit
      model.active_view.zoom_extents
      arr2.select { |s| s && s.valid? }
    rescue StandardError => ent
      KSU.abort_op
      UI.messagebox("Lỗi nesting: #{ent.message}")
      []
    end
  end
  def place_root
    return unless @root && @root.valid?
    num = num2 = nil
    @root.definition.entities.each do |ent|
      next unless KSU.container?(ent) && ent.respond_to?(:name) && ent.name.to_s.downcase.include?("sheet")
      ent.definition.invalidate_bounds if ent.respond_to?(:definition) && ent.definition
      bbox = ent.bounds
      next if bbox.empty?
      num = bbox.max.x.to_f if num.nil? || bbox.max.x.to_f > num
      num2 = bbox.max.y.to_f if num2.nil? || bbox.max.y.to_f > num2
    end
    return unless num
    transform = Geom::Point3d.new(num, num2, 0).transform(@root.transformation)
    dx = -1.m - transform.x
    dy = -1.m - transform.y
    return if dx.abs < 1e-9 && dy.abs < 1e-9
    @root.transformation = Geom::Transformation.translation([dx, dy, 0]) * @root.transformation
  end
  def finish_draw
    return unless @root && @root.valid?
    root = @root
    KSU.start
    place_root
    KSU.commit
    @root = nil
    unless @errors.empty?
      UI.messagebox("Lỗi nesting! Xảy ra ở một trong các chi tiết: #{@errors.uniq.join(', ')}")
    end
    _42f184ce(root)
  rescue StandardError
    KSU.abort_op
    @root = nil
  end
  def draw_sheet(root, sheet_type, arr3, sheet_ix, _8af8d41e, _feddf318, cfg)
    name = "#{sheet_type[:name]}-sheet-#{sheet_ix}"
    grp = root.entities.add_group
    grp.name = "__" + name
    grp.set_attribute("ABF", "sheet-id", sheet_ix)
    grp.set_attribute("ABF", "sheet-type", sheet_type[:name])
    grp.set_attribute("KSU", "sheet-material", sheet_type[:material].to_s)
    grp.set_attribute("ABF", "sheet-thickness", sheet_type[:thickness_mm])
    grp.set_attribute("ABF", "sheet-dimension", [cfg[:sheet_w], cfg[:sheet_h]])
    _842b28a8(grp)
    grp.transformation = grp.transformation * Geom::Transformation.translation([_8af8d41e, _feddf318, 0])
    KSU::Sheet._babc606e(root.entities, grp, sheet_ix, @w, _ec3291d0(sheet_ix))
    @drawn_sheets << grp
    arr2 = []
    h = {}
    flag = arr3.any? { |arr4| arr4[0][:two_sided] }
    flag2 = flag ? KSU::Avail.two_sided_margin.mm : @m_left
    flag3 = flag ? KSU::Avail.two_sided_margin.mm : @m_bottom
    arr3.each do |fld|
      x = fld[1] / 25.4 + flag2
      y = fld[2] / 25.4 + flag3
      gr, board_index = draw_panel(grp, fld[0], x, y, fld[3], cfg)
      arr2 << board_index if board_index
      next unless cfg[:nhom_cap] && gr && fld[4].to_i >= 0
      (h[fld[4].to_i] ||= []) << gr
    end
    _2354b03d(h)
    return [grp, false] if arr2.empty?
    bottom = _49fac9a3(root, sheet_type, arr2, name, sheet_ix, _8af8d41e, _feddf318, cfg)
    @drawn_sheets << bottom
    KSU::Sheet._babc606e(root.entities, bottom, sheet_ix, @w, _ec3291d0(sheet_ix))
    [grp, true]
  end
  def _2354b03d(arr)
    return if arr.nil? || arr.empty?
    arr.each_value do |arr3|
      arr2 = arr3.select { |g| g && g.valid? }
      next if arr2.size < 2
      @num10 = @num10.to_i + 1
      gid = (Time.now.to_f * 1000).to_i.to_s(36) + @num10.to_s(36)
      arr2.each { |g| g.set_attribute("KSU", "group-id", gid) }
    end
  end
  def draw_panel(grp3, grp, x, y, _33aa68d7, cfg)
    part_tf = grp[:part_tf]
    gr = grp3.entities.add_group
    KSU::Cutting._56b0abb5(gr, grp[:group])
    gr.delete_attribute("KSU", "group-id")
    cutting_gr = gr.entities.add_group
    cutting_gr.name = "_ABF_cuttingLines"
    grp[:cutting_lines].each_with_index do |pts, i|
      lp = cutting_gr.entities.add_curve(pts)
      next unless i == grp[:outer_index] && lp
      lp.each { |ent| ent.set_attribute("ABF", "is-outer-loop", true) if ent.is_a?(Sketchup::Edge) }
    end
    cutting_gr.transformation = cutting_gr.transformation * part_tf.inverse
    cutting_gr.set_attribute("ABF", "is-cutting-lines", true)
    KSU::Cutting.set_layer(cutting_gr, KSU::Cutting.layer("ABF_cuttingLines"))
    max_eb = gr.entities.add_group
    max_eb.name = "_ABF_edgeBanding"
    grp[:edge_band_lines].each { |pts| max_eb.entities.add_curve(pts) }
    max_eb.transformation = max_eb.transformation * part_tf.inverse
    max_eb.set_attribute("ABF", "is-edge-banding-notation", true)
    KSU::Cutting.set_layer(max_eb, KSU::Cutting.layer("ABF_edgeBanding"))
    gr.transformation = gr.transformation * Geom::Transformation.translation([x, y, 0])
    gr.transformation = gr.transformation * Geom::Transformation.rotation(ORIGIN, Z_AXIS, _33aa68d7.degrees)
    gr.transformation = gr.transformation * part_tf
    KSU::Cutting._c6e26747(gr, grp[:drills], part_tf.inverse)
    KSU::Cutting.save_edgeband_desc(gr, grp[:edge_band_desc], part_tf.inverse)
    _fc78e970(grp[:group])
    bottom = KSU::Cutting._babeb881(grp[:group], grp[:up_face], grp[:tf])
    bottom[:up].each do |grp5|
      next unless grp5.respond_to?(:definition) && grp5.definition
      KSU::Cutting._81410e9d(gr.entities.add_instance(grp5.definition, grp5.transformation), grp5)
    end
    label_gr = nil
    if bottom[:label] && bottom[:label].respond_to?(:definition) && bottom[:label].definition
      label_gr = gr.entities.add_instance(bottom[:label].definition, bottom[:label].transformation)
      KSU::Cutting._56b0abb5(label_gr, bottom[:label])
      KSU::Cutting._81410e9d(label_gr, bottom[:label])
    end
    board_index = nil
    unless bottom[:bottom].empty?
      board_index = { part_id: grp[:group].get_attribute("ABF", "board-index"), name: gr.name,
                label_gr: label_gr, cutting_gr: cutting_gr, bottom: bottom[:bottom], tf: gr.transformation }
    end
    [gr, board_index]
  end
  def _49fac9a3(root, sheet_type, arr3, name, sheet_ix, _8af8d41e, _feddf318, cfg)
    bottom = root.entities.add_group
    bottom.name = "__#{name}-bottom"
    bottom.set_attribute("ABF", "sheet-id", sheet_ix)
    bottom.set_attribute("ABF", "is-bottom-sheet", true)
    bottom.set_attribute("ABF", "sheet-type", sheet_type[:name])
    bottom.set_attribute("KSU", "sheet-material", sheet_type[:material].to_s)
    bottom.set_attribute("ABF", "sheet-thickness", sheet_type[:thickness_mm])
    bottom.set_attribute("ABF", "sheet-dimension", [cfg[:sheet_w], cfg[:sheet_h]])
    bottom.transformation = bottom.transformation *
                            Geom::Transformation.translation([_8af8d41e, _feddf318 + @h + KSU::Const::SHEET_V_PADDING / 2, 0])
    arr3.each do |arr|
      panel = bottom.entities.add_group
      panel.name = arr[:name]
      panel.transformation = arr[:tf]
      grp3 = panel.entities.add_instance(arr[:cutting_gr].definition, arr[:cutting_gr].transformation)
      grp3.name = arr[:cutting_gr].name
      grp3.make_unique
      grp3.set_attribute("ABF", "is-cutting-lines", true)
      KSU::Cutting.set_layer(grp3, KSU::Cutting.layer("ABF_partBorder"))
      arr[:bottom].each do |grp|
        next unless grp.respond_to?(:definition) && grp.definition
        KSU::Cutting._81410e9d(panel.entities.add_instance(grp.definition, grp.transformation), grp)
      end
      if arr[:label_gr]
        tr = panel.entities.add_instance(arr[:label_gr].definition, arr[:label_gr].transformation)
        tr.name = arr[:label_gr].name
        tr.set_attribute("ABF", "is-label", true)
        @drawn_panels << tr
      end
      panel.set_attribute("ABF", "board-index", arr[:part_id])
      panel.set_attribute("ABF", "is-bottom-face", true)
    end
    tr2 = Geom::Transformation.rotation(ORIGIN, Y_AXIS, 180.degrees) *
             Geom::Transformation.translation([-(@w - @m_left), @m_bottom, 0])
    bottom.entities.transform_entities(tr2, bottom.entities.to_a)
    _842b28a8(bottom)
    _7da9d41e(bottom, true)
    bottom
  end
  def _fc78e970(grp)
    (KSU.entities_in(grp) || []).each do |ent|
      next unless ent.is_a?(Sketchup::Group) && ent.name.to_s.start_with?("ABF_")
      ent.set_attribute("ABF", "is-user-nesting-obj", true)
    end
  end
  def warn_missing
    return unless @errors.empty?
    @arr61.each do |sheet_type|
      sheet_type[:parts].each do |arr|
        @errors << arr[:group].name.to_s if arr[:bounds_mm].size > 1
      end
    end
  end
  def _c91f065e
    @drawn_panels.each do |gr|
      next unless gr && gr.valid?
      tf = KSU::Cutting.tf_of(gr)
      gr.transformation = gr.transformation * Geom::Transformation.rotation(ORIGIN, Y_AXIS.transform(tf), 180.degrees)
    end
  end
  def _a2d1d319(model)
    unless model.layers["ABF_cuttingLines"]
      _2cb52d46 = model.layers.add("ABF_cuttingLines")
      _2cb52d46.color = Sketchup::Color.new(255, 255, 255)
    end
    KSU::Cutting.layer("ABF_edgeBanding")
    KSU::Cutting.layer("ABF_sheetBorder")
    KSU::Cutting.layer("ABF_partBorder")
  end
  def _842b28a8(defn)
    gr = defn.entities.add_group
    gr.set_attribute("ABF", "is-sheet-border", true)
    gr.name = "__ABF_sheetBorder"
    gr.entities.add_curve([0, 0, 0], [@w, 0, 0], [@w, @h, 0], [0, @h, 0], [0, 0, 0])
    KSU::Cutting.set_layer(gr, KSU::Cutting.layer("ABF_sheetBorder"))
  end
  def _7da9d41e(defn, _95f7dd2a)
    gr = defn.entities.add_group
    gr.set_attribute("ABF", "is-mark-square", true)
    name = "ABF_markSquare"
    gr.name = "__" + name
    if _95f7dd2a
      gr.entities.add_curve([@w - @m_left, @h, 0], [@w - @m_left, @m_bottom, 0], [0, @m_bottom, 0])
    else
      gr.entities.add_curve([@m_left, @h, 0], [@m_left, @m_bottom, 0], [@w, @m_bottom, 0])
    end
    KSU::Cutting.set_layer(gr, KSU::Cutting.layer(name))
  end
  def _ec3291d0(id)
    id.to_s.rjust(2, "0")
  end
  def _ce93a4c7(arr)
    return unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union)
    arr.each do |sheet|
      next unless sheet && sheet.valid?
      sheet.entities.grep(Sketchup::Group).each do |grp|
        next if KSU::Sheet._27ecfdd1(grp)
        _e3d864eb(grp)
      end
    end
  end
  def _e3d864eb(grp)
    arr3 = (KSU.entities_in(grp) || []).to_a.select do |g|
      KSU.container?(g) && g.get_attribute("ABF", "is-intersect")
    end
    return if arr3.size < 2
    arr = _a086bafa(arr3)
    return if arr.size < 2
    n = arr.size
    arr2 = Array.new(n) { Array.new(n, false) }
    (0...n - 1).each do |i|
      (i + 1...n).each do |j|
        next unless !arr[i][:rect].intersect(arr[j][:rect]).empty? && arr[i][:layer_name] == arr[j][:layer_name]
        arr2[i][j] = true
        arr2[j][i] = true
      end
    end
    color = _2827207b(n, arr2)
    (1..n).each do |color2|
      ix = (0...n).select { |i| color[i] == color2 }
      next if ix.size < 2
      _13398956(ix.map { |i| arr[i] }, grp)
    end
  end
  def _a086bafa(arr2)
    arr = []
    arr2.each do |gr|
      src = (KSU.entities_in(gr) || []).grep(Sketchup::Face)
      next if src.empty?
      tf = KSU::Cutting.tf_of(gr)
      grp = nil
      polys = src.map do |f|
        grp ||= f.edges[0] && f.edges[0].layer
        f.outer_loop.vertices.map do |v|
          pt = v.position.transform(tf)
          [pt.x.to_f, pt.y.to_f]
        end
      end
      bbox = Geom::BoundingBox.new
      lo = gr.definition.bounds.min.transform(tf)
      hi = gr.definition.bounds.max.transform(tf)
      bbox.add([lo.x, lo.y, 0], [hi.x, hi.y, 0])
      arr << { gr: gr, rect: bbox, layer: grp, layer_name: grp ? grp.name : "", polys: polys }
    end
    arr
  end
  def _2827207b(n, arr2)
    color = Array.new(n, 0)
    color3 = 0
    (0...n).each do |i|
      next unless color[i] == 0
      color3 += 1
      arr = [i]
      color[i] = color3
      until arr.empty?
        _7e53f420 = arr.pop
        (0...n).each do |j|
          next unless color[j] == 0 && arr2[_7e53f420][j]
          color[j] = color3
          arr << j
        end
      end
    end
    color
  end
  def _13398956(arr3, defn)
    polys = arr3.flat_map { |i| i[:polys] }
    rings = KSU::Clipper.union(polys, 6)
    return if rings.nil? || rings.empty?
    _2cb52d46 = arr3[0][:layer]
    ok = false
    rings.each do |arr2|
      next unless arr2 && arr2.length >= 3
      grp = defn.entities.add_group
      _ad0be572 = KSU::Cutting.tf_of(grp).inverse
      pts = arr2.map { |arr4| Geom::Point3d.new(arr4[0], arr4[1], 0).transform(_ad0be572) }
      begin
        grp.entities.add_face(pts)
      rescue StandardError
        grp.erase!
        next
      end
      grp.name = "_ABF_Intersect"
      grp.set_attribute("ABF", "is-intersect", true)
      grp.material = KSU::Cutting._b39e8694
      KSU::Cutting.set_layer(grp, _2cb52d46) if _2cb52d46
      ok = true
    end
    defn.entities.erase_entities(arr3.map { |i| i[:gr] }) if ok
  end
  def _42f184ce(root)
    return unless root && root.valid?
    root.entities.grep(Sketchup::Group).each do |sheet|
      next unless sheet.get_attribute("ABF", "sheet-id")
      ents = sheet.entities.grep(Sketchup::Group)
      bd2 = ents.find { |color| KSU::Sheet._27ecfdd1(color) }
      next unless bd2
      rect = _127808db(bd2)
      ents.each do |entity|
        next if entity == bd2
        (KSU.entities_in(entity) || []).each do |kids|
          next unless KSU.container?(kids)
          next unless kids.get_attribute("ABF", "is-cutting-lines")
          if _4afb97a0(rect, _127808db(kids))
            id = entity.get_attribute("ABF", "board-index")
            @arr45 << id.to_s if id && @arr45
            break
          end
        end
      end
    end
  end
  def _127808db(gr)
    tf = KSU::Cutting.tf_of(gr)
    b = gr.definition.bounds
    arr2 = []
    arr = []
    [0, 1, 2, 4].each do |i|
      pt = b.corner(i).transform(tf)
      arr2 << pt.x.to_f
      arr << pt.y.to_f
    end
    { x1: arr2.min, y1: arr.max, x2: arr2.max, y2: arr.min }
  end
  def _4afb97a0(defn, entity)
    tol = 0.001.mm
    entity[:x1] < defn[:x1] - tol || entity[:x2] > defn[:x2] + tol ||
      entity[:y1] > defn[:y1] + tol || entity[:y2] < defn[:y2] - tol
  end
end
KSU::Nest.extend(KSU::Draw)
