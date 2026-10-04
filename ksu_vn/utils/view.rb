module KSU::View
  @style_memo = nil
  def self.clear_cache
    @panel_cache = nil
    @tri_cache = nil
    @num2 = nil
  end
  def self.sig_of(nesting, flag = false)
    return nil unless nesting && nesting.valid?
    at = Time.now.to_f
    color = @num2
    return color[:sig] if !flag && color && color[:nesting] == nesting && at - color[:at] < 0.25
    sig = compute_sig(nesting)
    @num2 = { nesting: nesting, sig: sig, at: at }
    sig
  end
  def self.compute_sig(nesting)
    return nil unless nesting && nesting.valid?
    acc = [nesting.entityID, nesting.transformation.to_a.hash]
    nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      next unless sheet.name.to_s.downcase.include?("sheet")
      acc << sheet.entityID
      acc << sheet.transformation.to_a.hash
      sheet.definition.entities.each do |panel|
        next unless KSU.container?(panel)
        acc << panel.entityID
        acc << panel.transformation.to_a.hash
        grp2 = panel.respond_to?(:definition) ? panel.definition : nil
        next unless grp2
        acc << grp2.entityID
        acc << grp2.entities.size
        acc << grp2.bounds.min.to_a.hash
        acc << grp2.bounds.max.to_a.hash
      end
    end
    acc.hash
  end
  class TransactionObserver < Sketchup::ModelObserver
    def onTransactionUndo(model)
      KSU::View.invalidate
    end
    def onTransactionRedo(model)
      KSU::View.invalidate
    end
  end
  def self.watch_model
    model = Sketchup.active_model
    return unless model
    return if @observer && @watched_model == model
    obs = TransactionObserver.new
    model.add_observer(obs)
    @observer = obs
    @watched_model = model
  end
  def self.on_change(key, &blk)
    (@h8 ||= {})[key] = blk
    watch_model
  end
  def self.off_change(key)
    @h8&.delete(key)
  end
  def self.invalidate
    clear_cache
    @flag18 = true
    @flag32 = true
    UI.start_timer(0, false) { refresh_now }
  end
  def self.refresh_now
    return unless @flag32
    @flag32 = false
    @flag18 = false
    clear_cache
    @h8&.each_value do |blk|
      begin
        blk.call
      rescue StandardError
      end
    end
    view&.invalidate
  end
  def self.draw_faces(nesting = nil, skip: nil, normal: true, two_sided: false)
    watch_model
    refresh_now if @flag32
    return if @flag18
    return unless normal || two_sided
    nesting ||= KSU::Nesting.find_nesting(notify: false)
    return unless nesting && nesting.valid?
    cache = @panel_cache
    sig = sig_of(nesting)
    unless cache && cache[:nesting] == nesting && cache[:sig] == sig
      panels = KSU::Nesting.panel_list(nesting)
      return if panels.empty?
      two_sided_flags = KSU::Nesting.two_sided_set(nesting)
      z = (-0.1).mm
      panels2 = panels.map do |arr|
        panel_record(arr[:entity], arr[:polygon], arr[:holes], arr[:board_index], arr[:back], z, two_sided_flags)
      end
      @panel_cache = { nesting: nesting, sig: sig, panels: panels2 }
      @tri_cache = nil
      cache = @panel_cache
    end
    arr2 = tri_buckets(cache, skip, normal, two_sided)
    normal_tris = arr2[:normal]
    group_tris = arr2[:group]
    two_tris = arr2[:two]
    unless normal_tris.empty?
      set_pen(panel_normal_color)
      view.draw(GL_TRIANGLES, normal_tris)
    end
    unless group_tris.empty?
      set_pen(panel_group_color)
      view.draw(GL_TRIANGLES, group_tris)
    end
    unless two_tris.empty?
      set_pen(panel_two_color)
      view.draw(GL_TRIANGLES, two_tris)
    end
  end
  def self.panel_record(entity, polygon, holes, board_index, back, z, two_sided_flags)
    poly = polygon.map { |pt| Geom::Point3d.new(pt.x, pt.y, z) }
    pt2 = (holes || []).map { |h| h.map { |pt| Geom::Point3d.new(pt.x, pt.y, z) } }
    {
      entity: entity,
      tris: poly_tris(poly, pt2),
      two_sided: !board_index.nil? && !!two_sided_flags[board_index],
      back: back,
      board_index: board_index,
      group: !!(entity && entity.valid? && entity.get_attribute("KSU", "group-id"))
    }
  end
  def self.cache_key(ref_p1, ref_p2, two_sided)
    arr = ref_p1 ? ref_p1.each_key.map { |ent| ent && ent.valid? ? ent.entityID : -1 }.sort : nil
    [ref_p2, two_sided, arr]
  end
  def self.tri_buckets(cache, ref_p1, ref_p2, two_sided)
    key = cache_key(ref_p1, ref_p2, two_sided)
    b = @tri_cache
    return b if b && b[:cache].equal?(cache) && b[:key] == key
    normal_tris = []
    group_tris = []
    two_tris = []
    cache[:panels].each do |panel|
      next if ref_p1 && ref_p1.include?(panel[:entity])
      tris = panel[:tris]
      next if tris.empty?
      if panel[:back]
        two_tris.concat(tris) if two_sided
      elsif panel[:two_sided] && two_sided
        two_tris.concat(tris)
      elsif ref_p2
        if panel[:group]
          group_tris.concat(tris)
        else
          normal_tris.concat(tris)
        end
      end
    end
    @tri_cache = { cache: cache, key: key, normal: normal_tris, group: group_tris, two: two_tris }
  end
  def self.refresh_panels(nesting, panels, sig)
    @tri_cache = nil
    @num2 = { nesting: nesting, sig: sig, at: Time.now.to_f } if sig
    cache = @panel_cache
    return unless cache && nesting && nesting.valid? && cache[:nesting] == nesting
    h2 = {}
    Array(panels).each { |grp| h2[grp.entityID] = true if grp && grp.valid? }
    cache[:panels].reject! do |ent|
      entity = ent[:entity]
      !(entity && entity.valid?) || h2[entity.entityID]
    end
    h = {}
    nesting.definition.entities.each do |s|
      next unless KSU.container?(s) && s.name.to_s.downcase.include?("sheet")
      h[s.definition.entityID] = s if s.definition
    end
    two_sided_flags = KSU::Nesting.two_sided_set(nesting)
    tr = nesting.transformation
    z = (-0.1).mm
    Array(panels).each do |panel|
      next unless panel && panel.valid? && KSU::Sheet.panel?(panel)
      defn = panel.parent
      next unless defn && defn.respond_to?(:entityID)
      sheet = h[defn.entityID]
      next unless sheet
      is_bottom = KSU::Sheet.bottom_sheet?(sheet)
      next if is_bottom && !KSU::Cutting.cutting_group(panel)
      fill = KSU::Cutting.outline(panel, tr * sheet.transformation * panel.transformation)
      polygon = fill[:outer]
      next unless polygon && polygon.length >= 3
      board_index = panel.get_attribute("ABF", "board-index")
      back = is_bottom || KSU::Cutting.bottom_face?(panel)
      cache[:panels] << panel_record(panel, polygon, fill[:holes], board_index, back, z, two_sided_flags)
    end
    cache[:sig] = sig if sig
  end
  def self.refresh_groups(panels)
    @tri_cache = nil
    cache = @panel_cache
    return unless cache && cache[:panels]
    ids = {}
    Array(panels).each { |grp2| ids[grp2.entityID] = true if grp2 && grp2.valid? }
    return if ids.empty?
    cache[:panels].each do |fld|
      ent = fld[:entity]
      next unless ent && ent.valid? && ids[ent.entityID]
      fld[:group] = !!ent.get_attribute("KSU", "group-id")
    end
  end
  def self.pick_on_plane(view, x, y, z)
    ray = view.pickray(x, y)
    Geom.intersect_line_plane(ray, [Geom::Point3d.new(0, 0, z), Geom::Vector3d.new(0, 0, 1)])
  end
  def self.bbox_top(bbox)
    z = bbox.max.z
    [
      Geom::Point3d.new(bbox.min.x, bbox.min.y, z),
      Geom::Point3d.new(bbox.max.x, bbox.min.y, z),
      Geom::Point3d.new(bbox.max.x, bbox.max.y, z),
      Geom::Point3d.new(bbox.min.x, bbox.max.y, z)
    ]
  end
  def self.extents(scr)
    arr = scr.map(&:x)
    arr2 = scr.map(&:y)
    [arr.min, arr.max, arr2.min, arr2.max, scr.map(&:z).max]
  end
  def self.center_of(scr)
    x1, x2, y1, y2, z = extents(scr)
    Geom::Point3d.new((x1 + x2) / 2.0, (y1 + y2) / 2.0, z)
  end
  def self.draw_outline(scr, color)
    return unless scr
    draw_band(scr, thickness: 50.mm.to_f, position: :outside, color: color)
  end
  def self.draw_rect2d(view, x1, y1, x2, y2, stipple: "")
    return unless x1 && x2
    draw_polygon2d(view, [
      Geom::Point3d.new(x1, y1, 0),
      Geom::Point3d.new(x2, y1, 0),
      Geom::Point3d.new(x2, y2, 0),
      Geom::Point3d.new(x1, y2, 0),
    ], stipple: stipple)
  end
  def self.unit_to(a, b)
    dx = a.x - b.x
    dy = a.y - b.y
    dz = a.z - b.z
    len = Math.sqrt(dx * dx + dy * dy + dz * dz)
    return Geom::Vector3d.new(0, 0, 0) if len < 1e-9
    Geom::Vector3d.new(dx / len, dy / len, dz / len)
  end
  def self.unit2d(a, b)
    dx = b.x - a.x
    dy = b.y - a.y
    len2d = Math.sqrt(dx * dx + dy * dy)
    return [0.0, 0.0] if len2d < 1e-9
    [dx / len2d, dy / len2d]
  end
  def self.expand_corners(scr)
    thick = 50.mm.to_f
    scr.each_with_index.map do |color, i|
      u1 = unit_to(color, scr[(i + 1) % 4])
      u2 = unit_to(color, scr[(i - 1) % 4])
      Geom::Point3d.new(color.x + (u1.x + u2.x) * thick,
                        color.y + (u1.y + u2.y) * thick,
                        color.z + (u1.z + u2.z) * thick)
    end
  end
  def self.corner_dirs(scr, i)
    color = scr[i]
    [unit2d(color, scr[(i + 1) % 4]), unit2d(color, scr[(i - 1) % 4])]
  end
  def self.bracket_pts(color, arr2, arr, arm, thickness_mm)
    a1x = arr2[0] * arm
    a1y = arr2[1] * arm
    a2x = arr2[0] * thickness_mm
    a2y = arr2[1] * thickness_mm
    b1x = arr[0] * arm
    b1y = arr[1] * arm
    b2x = arr[0] * thickness_mm
    b2y = arr[1] * thickness_mm
    px = color.x
    py = color.y
    [
      Geom::Point3d.new(px, py, 0),
      Geom::Point3d.new(px + a1x, py + a1y, 0),
      Geom::Point3d.new(px + a1x + b2x, py + a1y + b2y, 0),
      Geom::Point3d.new(px + b2x, py + b2y, 0),
      Geom::Point3d.new(px + b2x, py + b2y, 0),
      Geom::Point3d.new(px + a2x + b2x, py + a2y + b2y, 0),
      Geom::Point3d.new(px + a2x + b1x, py + a2y + b1y, 0),
      Geom::Point3d.new(px + b1x, py + b1y, 0),
    ]
  end
  def self.screen_scale(view, pt)
    pt3 = view.screen_coords(pt)
    b = view.screen_coords(pt.offset(view.camera.xaxis, 100.mm))
    len2d = Math.sqrt((b.x - pt3.x)**2 + (b.y - pt3.y)**2)
    len2d > 1e-6 ? len2d / 100.0 : 1.0
  end
  def self.draw_brackets(view, corners, color: nil, active: nil)
    arr3 = expand_corners(corners)
    scr = arr3.map { |_23505ef9| view.screen_coords(_23505ef9) }
    scale = screen_scale(view, arr3[0])
    arm = KSU::Const::BRACKET_ARM_MM * scale
    thickness_mm = KSU::Const::BRACKET_THICK_MM * scale
    inset = KSU::Const::BRACKET_INSET_MM * scale
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = color || edge_color
    4.times do |i|
      c = scr[i]
      cd1, cd2 = corner_dirs(scr, i)
      color4 = Geom::Point3d.new(c.x - (cd1[0] + cd2[0]) * inset,
                            c.y - (cd1[1] + cd2[1]) * inset, 0)
      fill = i == active || (block_given? && yield(i))
      quad = bracket_pts(color4, cd1, cd2, arm, thickness_mm)
      view.draw2d(GL_QUADS, quad) if fill
      view.draw2d(GL_LINE_LOOP, quad.values_at(0, 1, 2, 5, 6, 7))
    end
  end
  def self.bracket_hit(view, corners, x, y, pad: KSU::Const::BRACKET_PAD_MM)
    arr3 = expand_corners(corners)
    scr = arr3.map { |_23505ef9| view.screen_coords(_23505ef9) }
    scale = screen_scale(view, arr3[0])
    arm = KSU::Const::BRACKET_ARM_MM * scale
    inset = KSU::Const::BRACKET_INSET_MM * scale
    pad_x = pad * scale
    4.times do |i|
      c = scr[i]
      cd1, cd2 = corner_dirs(scr, i)
      px = c.x - (cd1[0] + cd2[0]) * inset
      py = c.y - (cd1[1] + cd2[1]) * inset
      s = (x - px) * cd1[0] + (y - py) * cd1[1]
      v = (x - px) * cd2[0] + (y - py) * cd2[1]
      return i if s >= -pad_x && v >= -pad_x && s <= arm + pad_x && v <= arm + pad_x
    end
    nil
  end
  def self.edge_frame(arr, outer, i)
    ix = (arr[i].x + arr[(i + 1) % 4].x) * 0.5
    my = (arr[i].y + arr[(i + 1) % 4].y) * 0.5
    ox = (outer[i].x + outer[(i + 1) % 4].x) * 0.5
    oy = (outer[i].y + outer[(i + 1) % 4].y) * 0.5
    rx = outer[(i + 1) % 4].x - outer[i].x
    ry = outer[(i + 1) % 4].y - outer[i].y
    len = Math.sqrt(rx * rx + ry * ry)
    return nil if len < 1e-6
    num2 = rx / len
    num = ry / len
    return nil if num2.abs > num.abs
    nx = ox - ix
    ny = oy - my
    nlen = Math.sqrt(nx * nx + ny * ny)
    if nlen < 1e-6
      nx = -num
      ny = num2
    else
      nx /= nlen
      ny /= nlen
    end
    [ox, oy, num2, num, nx, ny]
  end
  def self.handle_quad(g, half, depth2)
    bx2, by2, dx, dy, nx, ny = g
    [
      Geom::Point3d.new(bx2 - dx * half + nx * depth2, by2 - dy * half + ny * depth2, 0),
      Geom::Point3d.new(bx2 + dx * half + nx * depth2, by2 + dy * half + ny * depth2, 0),
      Geom::Point3d.new(bx2 + dx * half, by2 + dy * half, 0),
      Geom::Point3d.new(bx2 - dx * half, by2 - dy * half, 0),
    ]
  end
  def self.screen_pair(view, corners)
    pt = corners.map { |_23505ef9| view.screen_coords(_23505ef9) }
    outer = expand_corners(corners).map { |_23505ef9| view.screen_coords(_23505ef9) }
    [pt, outer]
  end
  def self.draw_corner_handles(view, corners, color: nil)
    inner, outer = screen_pair(view, corners)
    scale = screen_scale(view, corners[0])
    half = KSU::Const::EDGE_HALF_MM * scale
    depth2 = KSU::Const::EDGE_THICK_MM * scale
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = color || edge_color
    4.times do |i|
      g = edge_frame(inner, outer, i)
      next unless g
      _2ea74b89 = handle_quad(g, half, depth2)
      view.draw2d(GL_QUADS, _2ea74b89) if block_given? && yield(i)
      view.draw2d(GL_LINE_LOOP, _2ea74b89)
    end
  end
  def self.edge_hit(view, corners, x, y, pad: KSU::Const::EDGE_PAD_MM)
    inner, outer = screen_pair(view, corners)
    scale = screen_scale(view, corners[0])
    half = KSU::Const::EDGE_HALF_MM * scale
    depth2 = KSU::Const::EDGE_THICK_MM * scale
    pad_x = pad * scale
    4.times do |i|
      g = edge_frame(inner, outer, i)
      next unless g
      bx2, by2, dx, dy, nx, ny = g
      thick = (x - bx2) * dx + (y - by2) * dy
      s = (x - bx2) * nx + (y - by2) * ny
      return i if thick.abs <= half + pad_x && s >= -pad_x && s <= depth2 + pad_x
    end
    nil
  end
  def self.panel_world_box(panel, tf)
    cutting = KSU::Cutting.cutting_group(panel)
    if cutting && cutting.valid?
      bb = cutting.bounds
      world_tr = tf * panel.transformation
    else
      bb = panel.bounds
      world_tr = tf
    end
    KSU::Geom.world_box(bb, world_tr)
  end
  def self.panel_bbox(panel)
    return Geom::BoundingBox.new unless panel && panel.valid?
    KSU::Geom.world_box(panel.definition.bounds, panel.transformation)
  end
  def self.offset_bbox(bbox, vec)
    out = Geom::BoundingBox.new
    out.add(bbox.min.offset(vec))
    out.add(bbox.max.offset(vec))
    out
  end
  def self.button_center(rec)
    x1, x2, y1, y2, z = extents(rec[:top_corners])
    Geom::Point3d.new((x1 + x2) / 2.0, y2 + 200.mm, z)
  end
  def self.in_rect?(x, y, rect)
    x >= rect[:left] && x <= rect[:right] && y >= rect[:top] && y <= rect[:bottom]
  end
  def self.near_seg?(trai, duoi, pt, b, tol)
    dx = b.x - pt.x
    dy = b.y - pt.y
    len2 = dx * dx + dy * dy
    return false if len2 < 1e-9
    thick = ((trai - pt.x) * dx + (duoi - pt.y) * dy) / len2
    thick = 0.0 if thick < 0.0
    thick = 1.0 if thick > 1.0
    px = pt.x + thick * dx
    py = pt.y + thick * dy
    _130a8af3 = trai - px
    _35b1b769 = duoi - py
    _130a8af3 * _130a8af3 + _35b1b769 * _35b1b769 <= tol * tol
  end
  def self._919af578(view, x, y, rec)
    outer = rec[:top_corners].map { |_23505ef9| view.screen_coords(_23505ef9) }
    in_poly?(x, y, outer)
  end
  def self.hit?(view, fill, x, y)
    return false unless fill
    outer = fill[:outer]
    return false unless outer && outer.length >= 3
    pt = outer.map { |_23505ef9| view.screen_coords(_23505ef9) }
    return false unless in_poly?(x, y, pt)
    (fill[:holes] || []).each do |arr|
      next if arr.length < 3
      return false if in_poly?(x, y, arr.map { |_23505ef9| view.screen_coords(_23505ef9) })
    end
    true
  end
  def self.draw_loops(outer, holes, color)
    return unless color && outer && outer.length >= 3
    draw_loop(outer, color: color)
    (holes || []).each { |h| draw_loop(h, color: color) if h && h.length >= 3 }
  end
  def self._feb12e90(layers)
    arr = [
      [231, 76, 60], [46, 204, 113], [52, 152, 219], [243, 156, 18],
      [155, 89, 182], [26, 188, 156], [241, 196, 15], [230, 126, 34]
    ]
    rgb = arr[(layers - 1) % arr.length]
    Sketchup::Color.new(rgb[0], rgb[1], rgb[2], 180)
  end
  def self._0b8e9c29(view, x220, _60000b16, x2, y2, tip)
    mat = Sketchup::Color.new(0, 0, 0)
    set_pen(mat, true)
    view.line_width = 1
    view.draw2d(GL_LINES, [Geom::Point3d.new(x220, _60000b16, 0), Geom::Point3d.new(x2, y2, 0)])
    s = 8
    pts = case tip
          when :right then [[x2, y2], [x2 - s, y2 - s], [x2, y2], [x2 - s, y2 + s]]
          when :left  then [[x2, y2], [x2 + s, y2 - s], [x2, y2], [x2 + s, y2 + s]]
          when :down  then [[x2, y2], [x2 - s, y2 - s], [x2, y2], [x2 + s, y2 - s]]
          when :up    then [[x2, y2], [x2 - s, y2 + s], [x2, y2], [x2 + s, y2 + s]]
          end
    view.draw2d(GL_LINES, pts.map { |_9710d820, b| Geom::Point3d.new(_9710d820, b, 0) })
  end
end
require "fileutils"
require "json"
module KSU::View
  def self.seed_license_file
    FileUtils.mkdir_p(KSU::Settings.data_dir)
    return if File.exist?(KSU::Cutting.license_path)
    cands2 = KSU::Flip._8351e254
    return if cands2.nil?
    File.write(KSU::Cutting.license_path, KSU::Nfp.pack_key(JSON.generate(cands2)))
    File.delete(KSU::Collide._2b15ac41) if File.exist?(KSU::Collide._2b15ac41)
  end
  def self.show_activation_result(key, resp)
    if resp.nil?
      UI.messagebox "Kích hoạt thất bại! Không kết nối được với máy chủ."
      return false
    end
    err_code = resp["code"] || resp.dig("data", "code")
    unless resp["success"] == true || err_code == "key_activated" || err_code == "instance_already_activated"
      UI.messagebox "Kích hoạt thất bại! " + KSU::Back._cd99bb15(err_code)
      return false
    end
    KSU::Nfp.save_binding(key)
    UI.messagebox "Kích hoạt thành công! Còn lại " + KSU::Shape._142b3e3b(resp, key).to_s + " lượt kích hoạt."
    true
  end
end
