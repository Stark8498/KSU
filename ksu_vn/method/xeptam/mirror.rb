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
    ix = KSU::Cutting.index_of(panel)
    return nil if ix.nil?
    want_back = !back_face2?(panel)
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet) && sheet.name.to_s.downcase.include?("sheet")
      partner = sheet.definition.entities.find do |ent|
        KSU.container?(ent) && ent != panel &&
          KSU::Cutting.index_of(ent) == ix && (back_face2?(ent) == want_back)
      end
      return partner if partner
    end
    nil
  end
  def build_pairs
    @h11 = {}
    @arr28 = []
    return unless @nesting
    h19 = Hash.new { |h, k| h[k] = [] }
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet) && sheet.name.to_s.downcase.include?("sheet")
      sheet.definition.entities.each do |grp|
        next unless KSU.container?(grp)
        ix = KSU::Cutting.index_of(grp)
        next if ix.nil?
        h19[ix] << grp
      end
    end
    h19.each_value do |parts|
      arr2 = parts.reject { |_23505ef9| back_face2?(_23505ef9) }
      arr = parts.select { |_23505ef9| back_face2?(_23505ef9) }
      next if arr2.empty? || arr.empty?
      arr2.each_with_index do |grp6, i|
        back = arr[i] || arr.first
        next unless grp6 && back
        @arr28 << grp6 << back
        @h11[grp6.entityID] = { partner: back }
        @h11[back.entityID] = { partner: grp6 }
      end
    end
  end
  def clone_to(panel, cur_sheet, arr)
    tr = @nesting.transformation * cur_sheet.transformation * panel.transformation
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
    !KSU::Cutting.index_of(panel).nil? && !back_face2?(panel)
  end
  def back_of(vec)
    return nil unless vec && vec.valid? && front_panel?(vec)
    back = partner_of2(vec)
    return nil unless back && back.valid? && back_face2?(back)
    rec = rec_by_def(back.parent)
    sheet = rec && rec[:instance]
    return nil unless sheet && sheet.valid?
    [back, sheet]
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
    vec2 = KSU::Sheet.bottom_of(sheet3, @nesting)
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
    grp = KSU::Sheet.clone_sheet_shell(flag, flag.transformation, @nesting)
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
    return unless @flag56 && @dest
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
      pair = back_of(vec)
      next unless pair
      partner, back_sheet = pair
      next unless partner && partner.valid? && back_sheet && back_sheet.valid?
      tb = target_box(anchor, back_sheet, inst4, bb)
      next unless tb
      bb2, framed = tb
      tr = KSU::View.panel_world_box(partner, @nesting.transformation * back_sheet.transformation)
      arr = panel_outline(partner, back_sheet)
      poly = arr ? arr[:outer] : outer_pts_of(partner, back_sheet)
      next if poly.length < 3
      holes = arr ? (arr[:holes] || []) : []
      axis_x = (bb.min.x + bb.max.x) / 2.0
      off_x = bb2.center.x - bb.center.x
      off_y = bb2.center.y - bb.center.y
      nx0 = (2.0 * axis_x - arr2[:max_x]) + off_x
      ny0 = arr2[:min_y] + off_y
      dx = nx0 - tr.min.x
      dy = ny0 - tr.min.y
      partner.hidden = true unless partner.hidden?
      @arr33 << partner
      @arr57 << {
        front: vec,
        partner: partner,
        frame: (framed ? KSU::View.bbox_top(bb2) : nil),
        polygon: KSU::Geom.translate(poly, dx, dy),
        holes: holes.map { |hole| KSU::Geom.translate(hole, dx, dy) },
      }
    end
  end
  def target_box(sheet2, back_sheet, sheet3, bb3)
    found = KSU::Sheet.bottom_of(sheet3, @nesting)
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
  def draw_mirror_preview(view)
    return if @arr57.nil? || @arr57.empty?
    flag = @flag21 ? KSU::View.warn_color : KSU::View.face_color
    edge = @flag21 ? KSU::View.warning_color : KSU::View.edge_color
    @arr57.each do |fld|
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
      (holes || []).each { |h| view.draw(GL_LINE_LOOP, h) if h && h.length >= 3 }
    end
  end
  def draw_rect2d(view)
    return unless @down_x && @drag_x
    KSU::View.draw_rect2d(view, @down_x, @down_y, @drag_x, @drag_y)
    draw_box_preview(view)
  end
  def draw_box_preview(view)
    return unless @nesting && @nesting.valid?
    arr = panels_in_box(view, @down_x, @down_y, @drag_x, @drag_y)
    return if arr.empty?
    fill_c = KSU::View.face_color
    edge = KSU::View.edge_color
    arr.each do |half|
      panel = half[:panel]
      sheet = half[:sheet]
      next unless panel && panel.valid? && sheet && sheet.valid?
      draw_panel_fill(panel, sheet, fill_c, edge)
    end
  end
  def update_hover_sheets(x, y, view)
    return unless @nesting && @nesting.valid?
    prev = [@panel, @sheet, @hover_side, @flag12, @hover_corner, @hover_edge, @vec3]
    @vec3 = panel_at(view, x, y)
    @hover_side = !@vec3 && hit_side_button(view, x, y)
    @flag12 = !@vec3 && !@hover_side && hit_delete_button(view, x, y)
    @hover_corner = (!@vec3 && !@hover_side && !@flag12) ? corner_handle_at(view, x, y) : nil
    @hover_edge = (!@vec3 && !@hover_side && !@flag12 && !@hover_corner) ? edge_handle_at(view, x, y) : nil
    if @vec3 || @hover_side || @flag12 || @hover_corner || @hover_edge
      @panel = @sheet3 = @sheet = nil
      @arr41 = []
    else
      answer = pick_panel_at(view, x, y)
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
    now = [@panel, @sheet, @hover_side, @flag12, @hover_corner, @hover_edge, @vec3]
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
        next if arr[:holes].any? { |h| h.length >= 3 && KSU::View.in_poly?(x, y, h) }
      end
      best_a = arr[:area]
      best = { panel: arr[:panel], sheet: arr[:sheet] }
    end
    best
  end
  def panels_in_box(view, x218, _60000b16, x2, y2)
    left, right = [x218, x2].minmax
    top, bot = [_60000b16, y2].minmax
    crossing = x2 < x218
    arr2 = []
    screen_items(view).each do |arr|
      next unless arr[:panel] && arr[:panel].valid?
      next if arr[:sxmax] < left || arr[:sxmin] > right || arr[:symax] < top || arr[:symin] > bot
      ensure_screen_poly(view, arr)
      outer = arr[:outer]
      if outer.nil?
        next unless crossing || (arr[:sxmin] >= left && arr[:sxmax] <= right && arr[:symin] >= top && arr[:symax] <= bot)
      elsif crossing
        next unless box_touches?(left, top, right, bot, arr)
      else
        next unless outer.all? { |pt| pt.x.to_f.between?(left, right) && pt.y.to_f.between?(top, bot) }
      end
      arr2 << { panel: arr[:panel], sheet: arr[:sheet] }
    end
    arr2
  end
  def box_touches?(left, top, right, bot, arr)
    scr = [
      Geom::Point3d.new(left, top, 0), Geom::Point3d.new(right, top, 0),
      Geom::Point3d.new(right, bot, 0), Geom::Point3d.new(left, bot, 0),
    ]
    return true if box_cuts_poly?(left, top, right, bot, scr, arr[:outer])
    return true if arr[:holes].any? { |h| h.length >= 3 && box_cuts_poly?(left, top, right, bot, scr, h) }
    return false unless KSU::View.in_poly?(left, top, arr[:outer])
    arr[:holes].none? { |h| h.length >= 3 && KSU::View.in_poly?(left, top, h) }
  end
  def box_cuts_poly?(left, top, right, bot, scr, poly)
    n = poly.length
    n.times do |i|
      pt = poly[i]
      return true if pt.x.to_f.between?(left, right) && pt.y.to_f.between?(top, bot)
      b = poly[(i + 1) % n]
      4.times do |j|
        return true if KSU::Geom.segments_cross?(pt, b, scr[j], scr[(j + 1) % 4])
      end
    end
    false
  end
  def panel_tf(panel, sheet)
    if sheet && sheet.valid?
      @nesting.transformation * sheet.transformation * panel.transformation
    else
      @nesting.transformation * panel.transformation
    end
  end
  def outer_pts_of(panel, sheet)
    return [] unless panel && panel.valid? && @nesting && @nesting.valid?
    return [] if sheet && !sheet.valid?
    KSU::Cutting.outer_pts(panel, panel_tf(panel, sheet))
  end
  def panel_outline(panel, sheet)
    return nil unless panel && panel.valid? && @nesting && @nesting.valid?
    return nil if sheet && !sheet.valid?
    KSU::Cutting.outline(panel, panel_tf(panel, sheet))
  end
  def stroke_loops(loops, color)
    arr2 = []
    loops.each do |arr|
      next unless arr && arr.length >= 3
      meta = arr.length
      meta.times { |i| arr2 << arr[i] << arr[(i + 1) % meta] }
    end
    return if arr2.empty?
    KSU::View.set_pen(color)
    KSU::View.view.line_width = 1
    KSU::View.view.draw(GL_LINES, arr2)
  end
  def fill_of(panel, sheet)
    return nil unless panel && panel.respond_to?(:object_id)
    @h24[panel.object_id] ||= panel_outline(panel, sheet)
  end
  def draw_panel_fill(panel, sheet, color, edge_c = nil)
    fill = fill_of(panel, sheet)
    return false unless fill && fill[:outer].length >= 3
    tris = (fill[:tris] ||= KSU::View.poly_tris(fill[:outer], fill[:holes]))
    if tris && !tris.empty?
      KSU::View.set_pen(color)
      KSU::View.view.draw(GL_TRIANGLES, tris)
    else
      KSU::View.draw_poly_holes(fill[:outer], fill[:holes], color: color, line: false)
    end
    KSU::View.draw_loops(fill[:outer], fill[:holes], edge_c)
    true
  end
  def rebuild_geom
    build_pairs
    clear_poly_cache
    reset_caches
    rebuild_outlines
  end
  def refresh_state
    rebuild_geom
    @overlap_fills = KSU::Nesting.overlap_polys(@nesting)
    @err_pts = KSU::Nesting.error_points(@nesting)
    KSU::Sheet.invalidate_cache
    KSU::View.clear_cache
  end
  def clear_poly_cache
    @poly_cache = {}
    @h24 = {}
    return unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |sheet|
      next unless sheet.respond_to?(:name) && sheet.name.to_s.downcase.include?("sheet")
      sheet.definition.entities.each do |panel|
        next unless KSU::Sheet.drawable?(panel)
        next if @sel.include?(panel)
        @poly_cache[panel.object_id] = outer_pts_of(panel, sheet)
      end
    end
  end
  def drop_panel_cache(panels)
    Array(panels).each do |_23505ef9|
      next unless _23505ef9 && _23505ef9.respond_to?(:object_id)
      @poly_cache.delete(_23505ef9.object_id)
      @h24.delete(_23505ef9.object_id)
    end
  end
  def rebuild_sel_polys
    @sel_polys = @sel.each_with_index.map do |panel, ix|
      next [] unless panel && panel.valid?
      sheet = @sel_sheets[ix]
      next [] unless sheet && sheet.valid?
      outer_pts_of(panel, sheet)
    end
    @sel_bounds = @sel_polys.map do |poly|
      poly.length < 3 ? nil : KSU::Geom.bounds(poly)
    end
    @sel_hulls = @sel_polys.map do |poly|
      poly.length < 3 ? nil : (poly.length > 12 ? KSU::Geom.convex_hull(poly) : poly)
    end
    @sel_hull = selection_hull
  end
  def selection_hull
    arr = @sel_polys.select { |arr2| arr2 && arr2.length >= 3 }
    return nil if arr.length < 2
    arr3 = KSU::Geom.convex_hull(arr.flatten)
    arr3.length >= 3 ? arr3 : nil
  end
  def shift_cached_polys(vec)
    return unless @sel_polys
    dx = vec.x.to_f
    dy = vec.y.to_f
    return if dx.abs < 1e-9 && dy.abs < 1e-9
    @sel_polys = @sel_polys.map do |poly|
      poly.length < 3 ? poly : KSU::Geom.translate(poly, dx, dy)
    end
    @sel_bounds = @sel_bounds.map do |bbox|
      next nil unless bbox
      { min_x: bbox[:min_x] + dx, max_x: bbox[:max_x] + dx,
        min_y: bbox[:min_y] + dy, max_y: bbox[:max_y] + dy }
    end
    if @sel_hulls
      @sel_hulls = @sel_hulls.map do |h|
        h.nil? || h.length < 3 ? h : KSU::Geom.translate(h, dx, dy)
      end
    end
    @sel_hull = KSU::Geom.translate(@sel_hull, dx, dy) if @sel_hull
  end
  def skip
    return nil unless @flag56
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
  def self._4b6ac4b0
    KSU::Arrange._9fcc1956(KSU::Caidat.machine_fingerprint)
  end
end
