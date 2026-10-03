module KSU::Mirror
  private
  def partner_of2(panel)
    return nil unless panel && panel.valid? && panel.respond_to?(:entityID)
    id = panel.entityID
    slot = @h11[id]
    if slot
      partner2 = slot[:partner]
      return partner2 if partner2 && partner2.valid?
      return nil if partner2.nil?
    end
    partner = find_partner(panel)
    @h11[id] = { partner: partner }
    partner
  end
  def find_partner(panel)
    ix = KSU::Cutting.board_index(panel)
    return nil if ix.nil?
    want_back = !back_face2?(panel)
    @nesting.definition.entities.each do |grp|
      next unless KSU.container?(grp) && grp.name.to_s.downcase.include?("sheet")
      partner = grp.definition.entities.find do |ent|
        KSU.container?(ent) && ent != panel &&
          KSU::Cutting.board_index(ent) == ix && (back_face2?(ent) == want_back)
      end
      return partner if partner
    end
    nil
  end
  def build_pairs
    @h11 = {}
    @arr28 = []
    return unless @nesting
    h = Hash.new { |arr52, k| arr52[k] = [] }
    @nesting.definition.entities.each do |grp3|
      next unless KSU.container?(grp3) && grp3.name.to_s.downcase.include?("sheet")
      grp3.definition.entities.each do |grp|
        next unless KSU.container?(grp)
        ix = KSU::Cutting.board_index(grp)
        next if ix.nil?
        h[ix] << grp
      end
    end
    h.each_value do |parts|
      arr2 = parts.reject { |_23505ef9| back_face2?(_23505ef9) }
      arr = parts.select { |_23505ef9| back_face2?(_23505ef9) }
      next if arr2.empty? || arr.empty?
      arr2.each_with_index do |grp8, _a4ab9a59|
        back = arr[_a4ab9a59] || arr.first
        next unless grp8 && back
        @arr28 << grp8 << back
        @h11[grp8.entityID] = { partner: back }
        @h11[back.entityID] = { partner: grp8 }
      end
    end
  end
  def clone_to(panel, sheet, arr)
    tr = @nesting.transformation * sheet.transformation * panel.transformation
    tr5 = arr[:transform].inverse * tr
    KSU::Nesting.clone_panel(arr[:instance].definition.entities, panel, tr5)
  end
  def back_face2?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    @h4 ||= {}
    id = panel.entityID
    partner = @h4[id]
    return partner unless partner.nil?
    @h4[id] = !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def front_panel?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.board_index(panel).nil? && !back_face2?(panel)
  end
  def back_of(panel)
    return nil unless panel && panel.valid? && front_panel?(panel)
    back = partner_of2(panel)
    return nil unless back && back.valid? && back_face2?(back)
    arr = rec_by_def(back.parent)
    vec2 = arr && arr[:instance]
    return nil unless vec2 && vec2.valid?
    [back, vec2]
  end
  def sync_back(panel2, pair, sheet2, sheet3, num = 0)
    partner, back_sheet = pair
    return unless partner && partner.valid? && sheet3 && sheet3.valid?
    vec = bottom_target(sheet2, back_sheet, sheet3)
    return unless vec && vec.valid?
    if vec != back_sheet
      partner = KSU::Nesting.move_to_sheet(partner, back_sheet, vec, @nesting)
    end
    return unless partner && partner.valid?
    place_mirror(panel2, partner, sheet3, vec)
  end
  def bottom_target(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    vec2 = KSU::Sheet.bottom(sheet3, @nesting)
    return vec2 if vec2 && vec2.valid?
    flag = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return back_sheet unless flag && flag.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(flag, @nesting)
    return back_sheet unless flag2 && flag2.valid?
    bb4 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb = KSU::Sheet.world_bbox(flag, @nesting)
    bb3 = KSU::Sheet.world_bbox(sheet3, @nesting)
    return back_sheet unless bb4 && bb && bb3
    str = KSU::Sheet.sheet_no(sheet3.name.to_s)
    pt = Geom::Point3d.new(
      bb3.center.x + (bb.center.x - bb4.center.x),
      bb3.center.y + (bb.center.y - bb4.center.y),
      bb.center.z
    )
    grp = KSU::Sheet._f74b0a99(flag, flag.transformation, @nesting)
    return back_sheet unless grp && grp.valid?
    grp.set_attribute("ABF", "is-bottom-sheet", true)
    bb2 = KSU::Sheet.world_bbox(grp, @nesting)
    if bb2
      vec3 = Geom::Vector3d.new(pt.x - bb2.center.x, pt.y - bb2.center.y, 0)
      tr = vec3.transform(@nesting.transformation.inverse)
      grp.transformation = Geom::Transformation.translation(tr) * grp.transformation
    end
    grp.name = sheet3.name.to_s + "-bottom"
    grp.set_attribute("ABF", "sheet-id", str) if str
    ["sheet-dimension", "sheet-thickness", "sheet-type"].each do |key|
      value = sheet3.get_attribute("ABF", key)
      grp.set_attribute("ABF", key, value) unless value.nil?
    end
    grp
  end
  def place_mirror(panel2, grp, sheet, tr)
    return unless panel2 && panel2.valid? && grp && grp.valid?
    transform = KSU::Sheet.mirror_tf(panel2, sheet, tr)
    grp.transformation = transform if transform
  end
  def rebuild_preview
    clear_preview
    @arr57 = []
    return unless @flag56 && @arr46
    instance = @arr46[:instance]
    return unless instance && instance.valid?
    bb = KSU::Sheet.world_bbox(instance, @nesting)
    return unless bb
    @arr27.each_with_index do |vec, ix|
      anchor = @arr12[ix]
      next if anchor == instance
      next unless vec && vec.valid? && anchor && anchor.valid?
      arr2 = @arr55 && @arr55[ix]
      next unless arr2
      pair = back_of(vec)
      next unless pair
      partner, back_sheet = pair
      next unless partner && partner.valid? && back_sheet && back_sheet.valid?
      _794181de = target_box(anchor, back_sheet, instance, bb)
      next unless _794181de
      bb2, _1b6c344e = _794181de
      tr = KSU::View._66e14707(partner, @nesting.transformation * back_sheet.transformation)
      arr = _89bccf8d(partner, back_sheet)
      poly = arr ? arr[:outer] : _8e5202c8(partner, back_sheet)
      next if poly.length < 3
      holes = arr ? (arr[:holes] || []) : []
      _17ed90bb = (bb.min.x + bb.max.x) / 2.0
      _46ac7359 = bb2.center.x - bb.center.x
      _478babd6 = bb2.center.y - bb.center.y
      _5f2b530c = (2.0 * _17ed90bb - arr2[:max_x]) + _46ac7359
      _76baa4cb = arr2[:min_y] + _478babd6
      dx = _5f2b530c - tr.min.x
      dy = _76baa4cb - tr.min.y
      partner.hidden = true unless partner.hidden?
      @arr33 << partner
      @arr57 << {
        front: vec,
        partner: partner,
        frame: (_1b6c344e ? KSU::View.top_corners(bb2) : nil),
        polygon: KSU::Geom.translate(poly, dx, dy),
        holes: holes.map { |_c9fa72f2| KSU::Geom.translate(_c9fa72f2, dx, dy) },
      }
    end
  end
  def target_box(sheet2, back_sheet, sheet3, bb3)
    found = KSU::Sheet.bottom(sheet3, @nesting)
    return [KSU::Sheet.world_bbox(found, @nesting), false] if found && found.valid?
    flag = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return nil unless flag && flag.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(flag, @nesting)
    return nil unless flag2 && flag2.valid?
    bb2 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb = KSU::Sheet.world_bbox(flag, @nesting)
    return nil unless bb2 && bb
    pt = Geom::Point3d.new(
      bb3.center.x + (bb.center.x - bb2.center.x),
      bb3.center.y + (bb.center.y - bb2.center.y),
      bb.center.z
    )
    dx = pt.x - bb.center.x
    dy = pt.y - bb.center.y
    bbox = Geom::BoundingBox.new
    bbox.add(Geom::Point3d.new(bb.min.x + dx, bb.min.y + dy, bb.min.z))
    bbox.add(Geom::Point3d.new(bb.max.x + dx, bb.max.y + dy, bb.max.z))
    [bbox, true]
  end
  def _f42544d1(view)
    return if @arr57.nil? || @arr57.empty?
    flag = @flag21 ? KSU::View.warn_color : KSU::View.face_color
    edge_color3 = @flag21 ? KSU::View.warning_color : KSU::View.edge_color
    @arr57.each do |fld|
      if fld[:frame]
        view.line_stipple = "-"
        view.line_width = 2
        view.drawing_color = edge_color3
        view.draw(GL_LINE_LOOP, fld[:frame])
        view.line_stipple = ""
      end
      poly = fld[:polygon]
      next if poly.length < 3
      holes = fld[:holes]
      if holes && !holes.empty?
        KSU::View.draw_poly_holes(poly, holes, color: flag, line: false)
      else
        KSU::View.draw_poly(poly, color: flag, line: false)
      end
      view.line_stipple = ""
      view.line_width = 1
      view.drawing_color = edge_color3
      view.draw(GL_LINE_LOOP, poly)
      (holes || []).each { |arr52| view.draw(GL_LINE_LOOP, arr52) if arr52 && arr52.length >= 3 }
    end
  end
  def draw_rect2d(view)
    return unless @_3a930069 && @_86277c8a
    KSU::View.draw_rect2d(view, @_3a930069, @_0b246bc2, @_86277c8a, @_e76905aa)
    _9b91a3d7(view)
  end
  def _9b91a3d7(view)
    return unless @nesting && @nesting.valid?
    arr = _101ef2e3(view, @_3a930069, @_0b246bc2, @_86277c8a, @_e76905aa)
    return if arr.empty?
    _33c34f08 = KSU::View.face_color
    edge_color4 = KSU::View.edge_color
    arr.each do |half|
      panel = half[:panel]
      vec = half[:sheet]
      next unless panel && panel.valid? && vec && vec.valid?
      _9a1f1a22(panel, vec, _33c34f08, edge_color4)
    end
  end
  def _37011ad2(x, y, view)
    return unless @nesting && @nesting.valid?
    prev = [@panel, @sheet, @hover_side, @flag12, @flag39, @flag51, @vec3]
    @vec3 = _ecb07074(view, x, y)
    @hover_side = !@vec3 && hit_side_button(view, x, y)
    @flag12 = !@vec3 && !@hover_side && hit_delete_button(view, x, y)
    @flag39 = (!@vec3 && !@hover_side && !@flag12) ? _f3bdae07(view, x, y) : nil
    @flag51 = (!@vec3 && !@hover_side && !@flag12 && !@flag39) ? _30c1f1e6(view, x, y) : nil
    if @vec3 || @hover_side || @flag12 || @flag39 || @flag51
      @panel = @sheet3 = @sheet = nil
      @arr41 = []
    else
      answer = _b01ddcaf(view, x, y)
      if answer
        @arr41 = group_mates(answer[:panel]) if @panel != answer[:panel]
        @panel = answer[:panel]
        @sheet3 = answer[:sheet]
        @sheet = answer[:sheet]
      else
        @panel = @sheet3 = nil
        @arr41 = []
        @sheet = sheet_at2(view, x, y)
      end
    end
    _13d621f9 = [@panel, @sheet, @hover_side, @flag12, @flag39, @flag51, @vec3]
    view.invalidate if _13d621f9 != prev
  end
  def _b01ddcaf(view, x, y)
    _477c927d = nil
    area = Float::INFINITY
    screen_items(view).each do |arr|
      next unless x.between?(arr[:sxmin], arr[:sxmax]) && y.between?(arr[:symin], arr[:symax])
      next unless arr[:area] < area
      next unless arr[:panel] && arr[:panel].valid?
      _9b1924b8(view, arr)
      if arr[:outer]
        next unless KSU::View.in_poly?(x, y, arr[:outer])
        next if arr[:holes].any? { |arr52| arr52.length >= 3 && KSU::View.in_poly?(x, y, arr52) }
      end
      area = arr[:area]
      _477c927d = { panel: arr[:panel], sheet: arr[:sheet] }
    end
    _477c927d
  end
  def _101ef2e3(view, x219, _60000b16, x2, y2)
    _2cf18878, _d6439c88 = [x219, x2].minmax
    _ab593548, bot = [_60000b16, y2].minmax
    _3b0d8ae2 = x2 < x219
    arr2 = []
    screen_items(view).each do |arr|
      next unless arr[:panel] && arr[:panel].valid?
      next if arr[:sxmax] < _2cf18878 || arr[:sxmin] > _d6439c88 || arr[:symax] < _ab593548 || arr[:symin] > bot
      _9b1924b8(view, arr)
      outer = arr[:outer]
      if outer.nil?
        next unless _3b0d8ae2 || (arr[:sxmin] >= _2cf18878 && arr[:sxmax] <= _d6439c88 && arr[:symin] >= _ab593548 && arr[:symax] <= bot)
      elsif _3b0d8ae2
        next unless _ee68e33c(_2cf18878, _ab593548, _d6439c88, bot, arr)
      else
        next unless outer.all? { |pt| pt.x.to_f.between?(_2cf18878, _d6439c88) && pt.y.to_f.between?(_ab593548, bot) }
      end
      arr2 << { panel: arr[:panel], sheet: arr[:sheet] }
    end
    arr2
  end
  def _ee68e33c(_2cf18878, _ab593548, _d6439c88, bot, arr)
    scr = [
      Geom::Point3d.new(_2cf18878, _ab593548, 0), Geom::Point3d.new(_d6439c88, _ab593548, 0),
      Geom::Point3d.new(_d6439c88, bot, 0), Geom::Point3d.new(_2cf18878, bot, 0),
    ]
    return true if _c949afeb(_2cf18878, _ab593548, _d6439c88, bot, scr, arr[:outer])
    return true if arr[:holes].any? { |arr52| arr52.length >= 3 && _c949afeb(_2cf18878, _ab593548, _d6439c88, bot, scr, arr52) }
    return false unless KSU::View.in_poly?(_2cf18878, _ab593548, arr[:outer])
    arr[:holes].none? { |arr52| arr52.length >= 3 && KSU::View.in_poly?(_2cf18878, _ab593548, arr52) }
  end
  def _c949afeb(_2cf18878, _ab593548, _d6439c88, bot, scr, poly)
    n = poly.length
    n.times do |_a4ab9a59|
      pt = poly[_a4ab9a59]
      return true if pt.x.to_f.between?(_2cf18878, _d6439c88) && pt.y.to_f.between?(_ab593548, bot)
      b = poly[(_a4ab9a59 + 1) % n]
      4.times do |j|
        return true if KSU::Geom.segments_cross?(pt, b, scr[j], scr[(j + 1) % 4])
      end
    end
    false
  end
  def _68d76957(panel, grp)
    if grp && grp.valid?
      @nesting.transformation * grp.transformation * panel.transformation
    else
      @nesting.transformation * panel.transformation
    end
  end
  def _8e5202c8(panel, vec)
    return [] unless panel && panel.valid? && @nesting && @nesting.valid?
    return [] if vec && !vec.valid?
    KSU::Cutting.outer_pts(panel, _68d76957(panel, vec))
  end
  def _89bccf8d(panel, vec)
    return nil unless panel && panel.valid? && @nesting && @nesting.valid?
    return nil if vec && !vec.valid?
    KSU::Cutting.outline(panel, _68d76957(panel, vec))
  end
  def _83ee7e20(loops, color)
    arr2 = []
    loops.each do |arr|
      next unless arr && arr.length >= 3
      meta = arr.length
      meta.times { |_a4ab9a59| arr2 << arr[_a4ab9a59] << arr[(_a4ab9a59 + 1) % meta] }
    end
    return if arr2.empty?
    KSU::View.set_pen(color)
    KSU::View.view.line_width = 1
    KSU::View.view.draw(GL_LINES, arr2)
  end
  def _cdd6bfc2(panel, _73dc38ac)
    return nil unless panel && panel.respond_to?(:object_id)
    @h24[panel.object_id] ||= _89bccf8d(panel, _73dc38ac)
  end
  def _9a1f1a22(panel, _73dc38ac, color, _4a7d3cee = nil)
    fill = _cdd6bfc2(panel, _73dc38ac)
    return false unless fill && fill[:outer].length >= 3
    tris2 = (fill[:tris] ||= KSU::View.tris(fill[:outer], fill[:holes]))
    if tris2 && !tris2.empty?
      KSU::View.set_pen(color)
      KSU::View.view.draw(GL_TRIANGLES, tris2)
    else
      KSU::View.draw_poly_holes(fill[:outer], fill[:holes], color: color, line: false)
    end
    KSU::View._2c42fd38(fill[:outer], fill[:holes], _4a7d3cee)
    true
  end
  def _b5e0ad4b
    build_pairs
    _a70d673b
    reset_caches
    _285eca92
  end
  def _1817fa46
    _b5e0ad4b
    @arr20 = KSU::Nesting.overlap_polys(@nesting)
    @arr11 = KSU::Nesting.error_points(@nesting)
    KSU::Sheet.invalidate_cache
    KSU::View.clear_cache
  end
  def _a70d673b
    @h21 = {}
    @h24 = {}
    return unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      grp.definition.entities.each do |panel|
        next unless KSU::Sheet.drawable?(panel)
        next if @arr27.include?(panel)
        @h21[panel.object_id] = _8e5202c8(panel, grp)
      end
    end
  end
  def _8f1f5186(panels)
    Array(panels).each do |_23505ef9|
      next unless _23505ef9 && _23505ef9.respond_to?(:object_id)
      @h21.delete(_23505ef9.object_id)
      @h24.delete(_23505ef9.object_id)
    end
  end
  def _4f4ecb72
    @arr63 = @arr27.each_with_index.map do |panel, ix|
      next [] unless panel && panel.valid?
      vec = @arr12[ix]
      next [] unless vec && vec.valid?
      _8e5202c8(panel, vec)
    end
    @arr55 = @arr63.map do |poly|
      poly.length < 3 ? nil : KSU::Geom.bounds(poly)
    end
    @arr19 = @arr63.map do |poly|
      poly.length < 3 ? nil : (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly)
    end
    @arr53 = _7ceb2cd7
  end
  def _7ceb2cd7
    arr = @arr63.select { |arr2| arr2 && arr2.length >= 3 }
    return nil if arr.length < 2
    arr3 = KSU::Geom.convex_hull(arr.flatten)
    arr3.length >= 3 ? arr3 : nil
  end
  def _52bcd343(vec)
    return unless @arr63
    dx = vec.x.to_f
    dy = vec.y.to_f
    return if dx.abs < 1e-9 && dy.abs < 1e-9
    @arr63 = @arr63.map do |poly|
      poly.length < 3 ? poly : KSU::Geom.translate(poly, dx, dy)
    end
    @arr55 = @arr55.map do |bbox|
      next nil unless bbox
      { min_x: bbox[:min_x] + dx, max_x: bbox[:max_x] + dx,
        min_y: bbox[:min_y] + dy, max_y: bbox[:max_y] + dy }
    end
    if @arr19
      @arr19 = @arr19.map do |arr52|
        arr52.nil? || arr52.length < 3 ? arr52 : KSU::Geom.translate(arr52, dx, dy)
      end
    end
    @arr53 = KSU::Geom.translate(@arr53, dx, dy) if @arr53
  end
  def skip
    return nil unless @flag56
    out = {}
    @arr27.each do |vec|
      next unless vec && vec.valid?
      out[vec] = true
      partner_of = partner_of2(vec)
      out[partner_of] = true if partner_of && partner_of.valid?
    end
    out
  end
end
KSU::Xeptam.include(KSU::Mirror)
module KSU::Mirror
  def self._4b6ac4b0
    KSU::Arrange._9fcc1956(KSU::Caidat.machine_fingerprint)
  end
end
