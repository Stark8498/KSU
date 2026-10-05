module KSU::Mirror
  private
  def partner_of2(panel)
    return nil unless panel && panel.valid? && panel.respond_to?(:entityID)
    id = panel.entityID
    slot = @h26[id]
    if slot
      cached = slot[:partner]
      return cached if cached && cached.valid?
      return nil if cached.nil?
    end
    partner = find_partner(panel)
    @h26[id] = { partner: partner }
    partner
  end
  def find_partner(panel)
    ix = KSU::Cutting.index_of(panel)
    return nil if ix.nil?
    want_back = !back_face2?(panel)
    @nesting.definition.entities.each do |grp|
      next unless KSU.container?(grp) && grp.name.to_s.downcase.include?("sheet")
      partner = grp.definition.entities.find do |e|
        KSU.container?(e) && e != panel &&
          KSU::Cutting.index_of(e) == ix && (back_face2?(e) == want_back)
      end
      return partner if partner
    end
    nil
  end
  def build_pairs
    @h26 = {}
    @arr18 = []
    return unless @nesting
    h = Hash.new { |elem, k| elem[k] = [] }
    @nesting.definition.entities.each do |grp2|
      next unless KSU.container?(grp2) && grp2.name.to_s.downcase.include?("sheet")
      grp2.definition.entities.each do |grp|
        next unless KSU.container?(grp)
        ix = KSU::Cutting.index_of(grp)
        next if ix.nil?
        h[ix] << grp
      end
    end
    h.each_value do |arr29|
      arr, arr37 = arr29.partition { |pt3| back_face2?(pt3) }
      next if arr37.empty? || arr.empty?
      arr37.each_with_index do |grp3, i|
        back = arr[i] || arr.first
        @arr18 << grp3 << back
        @h26[grp3.entityID] = { partner: back }
        @h26[back.entityID] = { partner: grp3 }
      end
    end
  end
  def clone_to(panel, cur_sheet, arr)
    tr = @nesting.transformation * cur_sheet.transformation * panel.transformation
    _11485ef7 = arr[:transform].inverse * tr
    KSU::Nesting.clone_panel(arr[:instance].definition.entities, panel, _11485ef7)
  end
  def back_face2?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    @h24 ||= {}
    id = panel.entityID
    cached = @h24[id]
    return cached unless cached.nil?
    @h24[id] = !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def front_panel?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.index_of(panel).nil? && !back_face2?(panel)
  end
  def back_of(vec)
    return nil unless vec && vec.valid? && front_panel?(vec)
    back = partner_of2(vec)
    return nil unless back && back.valid? && back_face2?(back)
    arr = sheet_of(back)
    return nil unless arr
    [back, arr]
  end
  def sync_back(panel2, pair, sheet2, sheet3, num = 0)
    vec, back_sheet = pair
    return unless vec && vec.valid? && sheet3 && sheet3.valid?
    vec2 = bottom_target(sheet2, back_sheet, sheet3)
    return unless vec2 && vec2.valid?
    if vec2 != back_sheet
      vec = KSU::Nesting.move_to_sheet(vec, back_sheet, vec2, @nesting)
    end
    return unless vec && vec.valid?
    place_mirror(panel2, vec, sheet3, vec2)
  end
  def bottom_target(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    vec = KSU::Sheet.bottom_of(sheet3, @nesting)
    return vec if vec && vec.valid?
    grp2, _item, pt = back_sheet_for(sheet2, back_sheet, sheet3)
    return back_sheet unless grp2
    str = KSU::Sheet.sheet_no(sheet3.name.to_s)
    grp = KSU::Sheet.clone_sheet_shell(grp2, grp2.transformation, @nesting)
    return back_sheet unless grp && grp.valid?
    grp.set_attribute("ABF", "is-bottom-sheet", true)
    bb = KSU::Sheet.world_bbox(grp, @nesting)
    if bb
      vec2 = Geom::Vector3d.new(pt.x - bb.center.x, pt.y - bb.center.y, 0)
      tr = vec2.transform(@nesting.transformation.inverse)
      grp.transformation = Geom::Transformation.translation(tr) * grp.transformation
    end
    grp.name = sheet3.name.to_s + "-bottom"
    grp.set_attribute("ABF", "sheet-id", str) if str
    ["sheet-dimension", "sheet-thickness", "sheet-type"].each do |key|
      val = sheet3.get_attribute("ABF", key)
      grp.set_attribute("ABF", key, val) unless val.nil?
    end
    grp
  end
  def place_mirror(panel2, grp, _7b230ca9, _774f7f26)
    return unless panel2 && panel2.valid? && grp && grp.valid?
    _ac3b3b9d = KSU::Sheet.mirror_tf(panel2, _7b230ca9, _774f7f26)
    grp.transformation = _ac3b3b9d if _ac3b3b9d
  end
  def rebuild_preview
    clear_preview
    @arr34 = []
    return unless @flag22 && @dest
    inst4 = @dest[:instance]
    return unless inst4 && inst4.valid?
    bb = KSU::Sheet.world_bbox(inst4, @nesting)
    return unless bb
    @sel.each_with_index do |vec, ix|
      anchor = @sel_sheets[ix]
      next if anchor == inst4
      next unless vec && vec.valid? && anchor && anchor.valid?
      arr2 = @sel_bounds && @sel_bounds[ix]
      next unless arr2
      _9cb9471d, back_sheet = back_of(vec)
      next unless _9cb9471d
      tb = target_box(anchor, back_sheet, inst4, bb)
      next unless tb
      bb2, framed = tb
      tr = KSU::View.panel_world_box(_9cb9471d, @nesting.transformation * back_sheet.transformation)
      arr = panel_outline(_9cb9471d, back_sheet)
      poly = arr ? arr[:outer] : outer_pts_of(_9cb9471d, back_sheet)
      next if poly.length < 3
      holes = arr ? (arr[:holes] || []) : []
      axis_x = (bb.min.x + bb.max.x) / 2.0
      off_x = bb2.center.x - bb.center.x
      off_y = bb2.center.y - bb.center.y
      _bcd2a048 = (2.0 * axis_x - arr2[:max_x]) + off_x
      _48d3c7a6 = arr2[:min_y] + off_y
      dx = _bcd2a048 - tr.min.x
      dy = _48d3c7a6 - tr.min.y
      _9cb9471d.hidden = true unless _9cb9471d.hidden?
      @arr40 << _9cb9471d
      @arr34 << {
        front: vec,
        partner: _9cb9471d,
        frame: (framed ? KSU::View.bbox_top(bb2) : nil),
        polygon: KSU::Geom.translate(poly, dx, dy),
        holes: holes.map { |_99b739cb| KSU::Geom.translate(_99b739cb, dx, dy) },
      }
    end
  end
  def back_sheet_for(sheet2, back_sheet, sheet3, bb2 = nil)
    flag = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return nil unless flag && flag.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(flag, @nesting)
    return nil unless flag2 && flag2.valid?
    bb3 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb = KSU::Sheet.world_bbox(flag, @nesting)
    bb2 ||= KSU::Sheet.world_bbox(sheet3, @nesting)
    return nil unless bb3 && bb && bb2
    [flag, bb, Geom::Point3d.new(
      bb2.center.x + (bb.center.x - bb3.center.x),
      bb2.center.y + (bb.center.y - bb3.center.y),
      bb.center.z
    )]
  end
  def target_box(sheet2, back_sheet, sheet3, _a15857cb)
    found = KSU::Sheet.bottom_of(sheet3, @nesting)
    return [KSU::Sheet.world_bbox(found, @nesting), false] if found && found.valid?
    _item, bb, pt = back_sheet_for(sheet2, back_sheet, sheet3, _a15857cb)
    return nil unless bb
    dx = pt.x - bb.center.x
    dy = pt.y - bb.center.y
    bbox = Geom::BoundingBox.new
    bbox.add(Geom::Point3d.new(bb.min.x + dx, bb.min.y + dy, bb.min.z))
    bbox.add(Geom::Point3d.new(bb.max.x + dx, bb.max.y + dy, bb.max.z))
    [bbox, true]
  end
  def draw_mirror_preview(view)
    return if @arr34.nil? || @arr34.empty?
    flag = @flag21 ? KSU::View.warn_color : KSU::View.face_color
    edge = @flag21 ? KSU::View.warning_color : KSU::View.edge_color
    @arr34.each do |fld|
      if fld[:frame]
        view.line_stipple = "-"
        view.line_width = 2
        view.drawing_color = edge
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
      view.drawing_color = edge
      view.draw(GL_LINE_LOOP, poly)
      (holes || []).each { |elem| view.draw(GL_LINE_LOOP, elem) if elem && elem.length >= 3 }
    end
  end
  def draw_rect2d(view)
    return unless @down_x && @drag_x
    KSU::View.draw_rect2d(view, @down_x, @down_y, @drag_x, @drag_y)
    return unless @nesting && @nesting.valid?
    arr = panels_in_box(view, @down_x, @down_y, @drag_x, @drag_y)
    return if arr.empty?
    _cde72bf5 = KSU::View.face_color
    edge = KSU::View.edge_color
    arr.each do |half|
      panel, vec = half.values_at(:panel, :sheet)
      next unless panel && panel.valid? && vec && vec.valid?
      draw_panel_fill(panel, vec, _cde72bf5, edge)
    end
  end
  def update_hover_sheets(x, y, view)
    return unless @nesting && @nesting.valid?
    prev = [@vec5, @vec6, @hover_side, @flag40, @hover_corner, @hover_edge, @vec3]
    @vec3 = panel_at(view, x, y)
    @hover_side = !@vec3 && hit_side_button(view, x, y)
    @flag40 = !@vec3 && !@hover_side && hit_delete_button(view, x, y)
    @hover_corner = (!@vec3 && !@hover_side && !@flag40) ? corner_handle_at(view, x, y) : nil
    @hover_edge = (!@vec3 && !@hover_side && !@flag40 && !@hover_corner) ? edge_handle_at(view, x, y) : nil
    if @vec3 || @hover_side || @flag40 || @hover_corner || @hover_edge
      @vec5 = @vec4 = @vec6 = nil
      @arr41 = []
    else
      ok = pick_panel_at(view, x, y)
      if ok
        @arr41 = group_mates(ok[:panel]) if @vec5 != ok[:panel]
        @vec5 = ok[:panel]
        @vec4 = ok[:sheet]
        @vec6 = ok[:sheet]
      else
        @vec5 = @vec4 = nil
        @arr41 = []
        @vec6 = sheet_at2(view, x, y)
      end
    end
    now = [@vec5, @vec6, @hover_side, @flag40, @hover_corner, @hover_edge, @vec3]
    view.invalidate if now != prev
  end
  def pick_panel_at(view, x, y)
    best = nil
    best_a = Float::INFINITY
    screen_items(view).each do |arr|
      next unless x.between?(arr[:sxmin], arr[:sxmax]) && y.between?(arr[:symin], arr[:symax])
      next unless arr[:area] < best_a
      next unless arr[:panel] && arr[:panel].valid?
      ensure_screen_poly(view, arr)
      if arr[:outer]
        next unless KSU::View.in_poly?(x, y, arr[:outer])
        next if arr[:holes].any? { |elem| elem.length >= 3 && KSU::View.in_poly?(x, y, elem) }
      end
      best_a = arr[:area]
      best = { panel: arr[:panel], sheet: arr[:sheet] }
    end
    best
  end
  def panels_in_box(view, x1, y1, x2, y2)
    left, b2 = [x1, x2].minmax
    _e4f12bf3, bot = [y1, y2].minmax
    crossing = x2 < x1
    arr2 = []
    screen_items(view).each do |arr|
      next unless arr[:panel] && arr[:panel].valid?
      next if arr[:sxmax] < left || arr[:sxmin] > b2 || arr[:symax] < _e4f12bf3 || arr[:symin] > bot
      ensure_screen_poly(view, arr)
      outer = arr[:outer]
      if outer.nil?
        next unless crossing || (arr[:sxmin] >= left && arr[:sxmax] <= b2 && arr[:symin] >= _e4f12bf3 && arr[:symax] <= bot)
      elsif crossing
        next unless box_touches?(left, _e4f12bf3, b2, bot, arr)
      else
        next unless outer.all? { |pt| pt.x.to_f.between?(left, b2) && pt.y.to_f.between?(_e4f12bf3, bot) }
      end
      arr2 << { panel: arr[:panel], sheet: arr[:sheet] }
    end
    arr2
  end
  def box_touches?(left, _e4f12bf3, b2, bot, arr)
    scr = [
      Geom::Point3d.new(left, _e4f12bf3, 0), Geom::Point3d.new(b2, _e4f12bf3, 0),
      Geom::Point3d.new(b2, bot, 0), Geom::Point3d.new(left, bot, 0),
    ]
    return true if box_cuts_poly?(left, _e4f12bf3, b2, bot, scr, arr[:outer])
    return true if arr[:holes].any? { |elem| elem.length >= 3 && box_cuts_poly?(left, _e4f12bf3, b2, bot, scr, elem) }
    return false unless KSU::View.in_poly?(left, _e4f12bf3, arr[:outer])
    arr[:holes].none? { |elem| elem.length >= 3 && KSU::View.in_poly?(left, _e4f12bf3, elem) }
  end
  def box_cuts_poly?(left, _e4f12bf3, b2, bot, scr, poly)
    n = poly.length
    n.times.any? do |i|
      pt = poly[i]
      b = poly[(i + 1) % n]
      (pt.x.to_f.between?(left, b2) && pt.y.to_f.between?(_e4f12bf3, bot)) ||
        4.times.any? { |ix| KSU::Geom.segments_cross?(pt, b, scr[ix], scr[(ix + 1) % 4]) }
    end
  end
  def panel_tf(panel, grp)
    if grp && grp.valid?
      @nesting.transformation * grp.transformation * panel.transformation
    else
      @nesting.transformation * panel.transformation
    end
  end
  def outer_pts_of(panel, vec)
    return [] unless panel && panel.valid? && @nesting && @nesting.valid?
    return [] if vec && !vec.valid?
    KSU::Cutting.outer_pts(panel, panel_tf(panel, vec))
  end
  def panel_outline(panel, vec)
    return nil unless panel && panel.valid? && @nesting && @nesting.valid?
    return nil if vec && !vec.valid?
    KSU::Cutting.outline(panel, panel_tf(panel, vec))
  end
  def stroke_loops(loops, color)
    segs = []
    loops.each do |arr|
      next unless arr && arr.length >= 3
      meta = arr.length
      meta.times { |i| segs << arr[i] << arr[(i + 1) % meta] }
    end
    return if segs.empty?
    KSU::View.set_pen(color)
    KSU::View.view.line_width = 1
    KSU::View.view.draw(GL_LINES, segs)
  end
  def fill_of(panel, sheet)
    return nil unless panel && panel.respond_to?(:object_id)
    @h27[panel.object_id] ||= panel_outline(panel, sheet)
  end
  def draw_panel_fill(panel, sheet, color, _9770881f = nil)
    fill = fill_of(panel, sheet)
    return false unless fill && fill[:outer].length >= 3
    arr = (fill[:tris] ||= KSU::View.poly_tris(fill[:outer], fill[:holes]))
    if arr && !arr.empty?
      KSU::View.set_pen(color)
      KSU::View.view.draw(GL_TRIANGLES, arr)
    else
      KSU::View.draw_poly_holes(fill[:outer], fill[:holes], color: color, line: false)
    end
    KSU::View.draw_loops(fill[:outer], fill[:holes], _9770881f)
    true
  end
  def rebuild_geom
    build_pairs
    clear_poly_cache
    reset_caches
    rebuild_outlines
  end
  def rebuild_overlaps
    rebuild_geom
    @arr6 = KSU::Nesting.overlap_polys(@nesting)
    @arr38 = KSU::Nesting.error_points(@nesting)
    KSU::Sheet.invalidate_cache
    KSU::View.clear_cache
  end
  def clear_poly_cache
    @poly_cache = {}
    @h27 = {}
    return unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      grp.definition.entities.each do |panel|
        next unless KSU::Sheet.drawable?(panel)
        next if @sel.include?(panel)
        @poly_cache[panel.object_id] = outer_pts_of(panel, grp)
      end
    end
  end
  def drop_panel_cache(panels)
    Array(panels).each do |pt3|
      next unless pt3 && pt3.respond_to?(:object_id)
      @poly_cache.delete(pt3.object_id)
      @h27.delete(pt3.object_id)
    end
  end
  def rebuild_sel_polys
    @sel_polys = @sel.each_with_index.map do |panel, ix|
      next [] unless panel && panel.valid?
      vec = @sel_sheets[ix]
      next [] unless vec && vec.valid?
      outer_pts_of(panel, vec)
    end
    @sel_bounds = @sel_polys.map { |poly| poly.length < 3 ? nil : KSU::Geom.bounds(poly) }
    @sel_hulls = @sel_polys.map { |poly| poly.length < 3 ? nil : (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly) }
    @sel_hull = selection_hull
  end
  def selection_hull
    arr3 = @sel_polys.select { |arr| arr && arr.length >= 3 }
    return nil if arr3.length < 2
    arr2 = KSU::Geom.convex_hull(arr3.flatten)
    arr2.length >= 3 ? arr2 : nil
  end
  def shift_cached_polys(pt)
    return unless @sel_polys
    dx = pt.x.to_f
    dy = pt.y.to_f
    return if dx.abs < 1e-9 && dy.abs < 1e-9
    @sel_polys = @sel_polys.map { |poly| poly.length < 3 ? poly : KSU::Geom.translate(poly, dx, dy) }
    @sel_bounds = @sel_bounds.map do |bbox|
      next nil unless bbox
      { min_x: bbox[:min_x] + dx, max_x: bbox[:max_x] + dx,
        min_y: bbox[:min_y] + dy, max_y: bbox[:max_y] + dy }
    end
    @sel_hulls = @sel_hulls.map { |elem| elem.nil? || elem.length < 3 ? elem : KSU::Geom.translate(elem, dx, dy) } if @sel_hulls
    @sel_hull = KSU::Geom.translate(@sel_hull, dx, dy) if @sel_hull
  end
  def skip
    return nil unless @flag22
    h = {}
    @sel.each do |vec|
      next unless vec && vec.valid?
      h[vec] = true
      partner_of = partner_of2(vec)
      h[partner_of] = true if partner_of && partner_of.valid?
    end
    h
  end
end
KSU::Xeptam.include(KSU::Mirror)
module KSU::Mirror
  def self.machine_id
    KSU::Arrange.normalize_hw_id(KSU::Caidat.machine_fingerprint)
  end
end
