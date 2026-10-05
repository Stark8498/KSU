module KSU::View
  @style_memo = nil
  def self.clear_cache
    @panel_cache = nil
    @tri_cache = nil
    @num9 = nil
  end
  def self.sig_of(nesting, flag = false)
    return nil unless nesting && nesting.valid?
    at = Time.now.to_f
    arr = @num9
    return arr[:sig] if !flag && arr && arr[:nesting] == nesting && at - arr[:at] < 0.25
    sig = compute_sig(nesting)
    @num9 = { nesting: nesting, sig: sig, at: at }
    sig
  end
  def self.compute_sig(nesting)
    return nil unless nesting && nesting.valid?
    tr = [nesting.entityID, nesting.transformation.to_a.hash]
    nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      tr << grp.entityID
      tr << grp.transformation.to_a.hash
      grp.definition.entities.each do |panel|
        next unless KSU.container?(panel)
        tr << panel.entityID
        tr << panel.transformation.to_a.hash
        defn2 = panel.respond_to?(:definition) ? panel.definition : nil
        next unless defn2
        tr << defn2.entityID
        tr << defn2.entities.size
        tr << defn2.bounds.min.to_a.hash
        tr << defn2.bounds.max.to_a.hash
      end
    end
    tr.hash
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
    (@h25 ||= {})[key] = blk
    watch_model
  end
  def self.off_change(key)
    @h25&.delete(key)
  end
  def self.invalidate
    clear_cache
    @flag15 = true
    @flag23 = true
    UI.start_timer(0, false) { refresh_now }
  end
  def self.refresh_now
    return unless @flag23
    @flag23 = false
    @flag15 = false
    clear_cache
    @h25&.each_value { |blk| blk.call rescue nil }
    view&.invalidate
  end
  def self.draw_faces(nesting = nil, skip: nil, normal: true, two_sided: false)
    watch_model
    refresh_now if @flag23
    return if @flag15
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
      arr4 = panels.map do |arr|
        panel_record(arr[:entity], arr[:polygon], arr[:holes], arr[:board_index], arr[:back], z, two_sided_flags)
      end
      @panel_cache = { nesting: nesting, sig: sig, panels: arr4 }
      @tri_cache = nil
      cache = @panel_cache
    end
    arr3 = tri_buckets(cache, skip, normal, two_sided)
    { normal: :panel_normal_color, group: :panel_group_color, two: :panel_two_color }.each do |k, c|
      arr2 = arr3[k]
      next if arr2.empty?
      set_pen(style[c])
      view.draw(GL_TRIANGLES, arr2)
    end
  end
  def self.panel_record(entity, polygon, holes, board_index, back, z, two_sided_flags)
    poly = polygon.map { |segs_for_ray| Geom::Point3d.new(segs_for_ray.x, segs_for_ray.y, z) }
    pt = (holes || []).map { |elem| elem.map { |segs_for_ray| Geom::Point3d.new(segs_for_ray.x, segs_for_ray.y, z) } }
    {
      entity: entity,
      tris: poly_tris(poly, pt),
      two_sided: !board_index.nil? && !!two_sided_flags[board_index],
      back: back,
      board_index: board_index,
      group: !!(entity && entity.valid? && entity.get_attribute("KSU", "group-id"))
    }
  end
  def self.tri_buckets(cache, ref_p1, ref_p2, two_sided)
    key = [ref_p2, two_sided, ref_p1 ? ref_p1.each_key.map { |grp| grp && grp.valid? ? grp.entityID : -1 }.sort : nil]
    b = @tri_cache
    return b if b && b[:cache].equal?(cache) && b[:key] == key
    normal_tris, group_tris, two_tris = [], [], []
    cache[:panels].each do |panel|
      next if ref_p1 && ref_p1.include?(panel[:entity])
      arr = panel[:tris]
      next if arr.empty?
      if panel[:back]
        two_tris.concat(arr) if two_sided
      elsif panel[:two_sided] && two_sided
        two_tris.concat(arr)
      elsif ref_p2
        (panel[:group] ? group_tris : normal_tris).concat(arr)
      end
    end
    @tri_cache = { cache: cache, key: key, normal: normal_tris, group: group_tris, two: two_tris }
  end
  def self.refresh_panels(nesting, panels, sig)
    @tri_cache = nil
    @num9 = { nesting: nesting, sig: sig, at: Time.now.to_f } if sig
    cache = @panel_cache
    return unless cache && nesting && nesting.valid? && cache[:nesting] == nesting
    h = {}
    Array(panels).each { |grp2| h[grp2.entityID] = true if grp2 && grp2.valid? }
    cache[:panels].reject! do |arr|
      entity = arr[:entity]
      !(entity && entity.valid?) || h[entity.entityID]
    end
    h2 = {}
    nesting.definition.entities.each do |s|
      next unless KSU::Sheet.sheet?(s)
      h2[s.definition.entityID] = s if s.definition
    end
    two_sided_flags = KSU::Nesting.two_sided_set(nesting)
    tr = nesting.transformation
    z = (-0.1).mm
    Array(panels).each do |panel|
      next unless panel && panel.valid? && KSU::Sheet.part_group?(panel)
      defn = panel.parent
      next unless defn && defn.respond_to?(:entityID)
      grp = h2[defn.entityID]
      next unless grp
      is_bottom = KSU::Sheet.bottom_sheet?(grp)
      next if is_bottom && !KSU::Cutting.cutting_group(panel)
      fill = KSU::Cutting.outline(panel, tr * grp.transformation * panel.transformation)
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
      grp = fld[:entity]
      next unless grp && grp.valid? && ids[grp.entityID]
      fld[:group] = !!grp.get_attribute("KSU", "group-id")
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
    arr2 = scr.map(&:x)
    arr = scr.map(&:y)
    [arr2.min, arr2.max, arr.min, arr.max, scr.map(&:z).max]
  end
  def self.center_of(scr)
    text, x1, y0, y1, z = extents(scr)
    Geom::Point3d.new((text + x1) / 2.0, (y0 + y1) / 2.0, z)
  end
  def self.draw_outline(scr, color)
    return unless scr
    draw_band(scr, thickness: 50.mm.to_f, position: :outside, color: color)
  end
  def self.draw_rect2d(view, text, y0, x1, y1, stipple: "")
    return unless text && x1
    draw_polygon2d(view, [
      Geom::Point3d.new(text, y0, 0),
      Geom::Point3d.new(x1, y0, 0),
      Geom::Point3d.new(x1, y1, 0),
      Geom::Point3d.new(text, y1, 0),
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
    t = 50.mm.to_f
    scr.each_with_index.map do |pt, i|
      u1 = unit_to(pt, scr[(i + 1) % 4])
      u2 = unit_to(pt, scr[(i - 1) % 4])
      Geom::Point3d.new(pt.x + (u1.x + u2.x) * t,
                        pt.y + (u1.y + u2.y) * t,
                        pt.z + (u1.z + u2.z) * t)
    end
  end
  def self.corner_dirs(scr, i)
    c = scr[i]
    [unit2d(c, scr[(i + 1) % 4]), unit2d(c, scr[(i - 1) % 4])]
  end
  def self.bracket_pts(pt, arr2, arr, arm, thickness_mm)
    a1x = arr2[0] * arm
    a1y = arr2[1] * arm
    a2x = arr2[0] * thickness_mm
    a2y = arr2[1] * thickness_mm
    b1x = arr[0] * arm
    b1y = arr[1] * arm
    b2x = arr[0] * thickness_mm
    b2y = arr[1] * thickness_mm
    px = pt.x
    py = pt.y
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
  def self.screen_scale(view, entity_ref)
    pt = view.screen_coords(entity_ref)
    b = view.screen_coords(entity_ref.offset(view.camera.xaxis, 100.mm))
    len2d = Math.sqrt((b.x - pt.x)**2 + (b.y - pt.y)**2)
    len2d > 1e-6 ? len2d / 100.0 : 1.0
  end
  def self.draw_brackets(view, corners, color: nil, active: nil)
    arr = expand_corners(corners)
    scr = arr.map { |pt3| view.screen_coords(pt3) }
    scale = screen_scale(view, arr[0])
    arm = 150.0 * scale
    thickness_mm = 40.0 * scale
    inset = 40.0 * scale
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = color || edge_color
    4.times do |i|
      c = scr[i]
      cd1, cd2 = corner_dirs(scr, i)
      pt = Geom::Point3d.new(c.x - (cd1[0] + cd2[0]) * inset,
                            c.y - (cd1[1] + cd2[1]) * inset, 0)
      fill = i == active || (block_given? && yield(i))
      quad = bracket_pts(pt, cd1, cd2, arm, thickness_mm)
      view.draw2d(GL_QUADS, quad) if fill
      view.draw2d(GL_LINE_LOOP, quad.values_at(0, 1, 2, 5, 6, 7))
    end
  end
  def self.bracket_hit(view, corners, x, y)
    arr = expand_corners(corners)
    scr = arr.map { |pt3| view.screen_coords(pt3) }
    scale = screen_scale(view, arr[0])
    arm = 150.0 * scale
    inset = 40.0 * scale
    pad_x = 20.0 * scale
    4.times do |i|
      c = scr[i]
      cd1, cd2 = corner_dirs(scr, i)
      px = c.x - (cd1[0] + cd2[0]) * inset
      py = c.y - (cd1[1] + cd2[1]) * inset
      u = (x - px) * cd1[0] + (y - py) * cd1[1]
      v = (x - px) * cd2[0] + (y - py) * cd2[1]
      return i if u >= -pad_x && v >= -pad_x && u <= arm + pad_x && v <= arm + pad_x
    end
    nil
  end
  def self.edge_frame(inner, outer, i)
    _4168a8e5 = (inner[i].x + inner[(i + 1) % 4].x) * 0.5
    _e2c52692 = (inner[i].y + inner[(i + 1) % 4].y) * 0.5
    _821639ac = (outer[i].x + outer[(i + 1) % 4].x) * 0.5
    _98c3a7e0 = (outer[i].y + outer[(i + 1) % 4].y) * 0.5
    rx = outer[(i + 1) % 4].x - outer[i].x
    ry = outer[(i + 1) % 4].y - outer[i].y
    len = Math.sqrt(rx * rx + ry * ry)
    return nil if len < 1e-6
    num = rx / len
    num2 = ry / len
    return nil if num.abs > num2.abs
    nx = _821639ac - _4168a8e5
    ny = _98c3a7e0 - _e2c52692
    nlen = Math.sqrt(nx * nx + ny * ny)
    nx, ny = nlen < 1e-6 ? [-num2, num] : [nx / nlen, ny / nlen]
    [_821639ac, _98c3a7e0, num, num2, nx, ny]
  end
  def self.handle_quad(arr, half, _c86c0371)
    bx2, by2, _ee4f533e, _4c8d9d44, nx, ny = arr
    [
      Geom::Point3d.new(bx2 - _ee4f533e * half + nx * _c86c0371, by2 - _4c8d9d44 * half + ny * _c86c0371, 0),
      Geom::Point3d.new(bx2 + _ee4f533e * half + nx * _c86c0371, by2 + _4c8d9d44 * half + ny * _c86c0371, 0),
      Geom::Point3d.new(bx2 + _ee4f533e * half, by2 + _4c8d9d44 * half, 0),
      Geom::Point3d.new(bx2 - _ee4f533e * half, by2 - _4c8d9d44 * half, 0),
    ]
  end
  def self.screen_pair(view, corners)
    [corners.map { |pt3| view.screen_coords(pt3) }, expand_corners(corners).map { |pt3| view.screen_coords(pt3) }]
  end
  def self.draw_corner_handles(view, corners)
    inner, outer = screen_pair(view, corners)
    scale = screen_scale(view, corners[0])
    half = 100.0 * scale
    num = 40.0 * scale
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = edge_color
    4.times do |i|
      grp2 = edge_frame(inner, outer, i)
      next unless grp2
      _086c3777 = handle_quad(grp2, half, num)
      view.draw2d(GL_QUADS, _086c3777) if block_given? && yield(i)
      view.draw2d(GL_LINE_LOOP, _086c3777)
    end
  end
  def self.edge_hit(view, corners, x, y)
    inner, outer = screen_pair(view, corners)
    scale = screen_scale(view, corners[0])
    half = 100.0 * scale
    num = 40.0 * scale
    pad_x = 20.0 * scale
    4.times do |i|
      grp2 = edge_frame(inner, outer, i)
      next unless grp2
      bx2, by2, _ee4f533e, _4c8d9d44, nx, ny = grp2
      t = (x - bx2) * _ee4f533e + (y - by2) * _4c8d9d44
      s = (x - bx2) * nx + (y - by2) * ny
      return i if t.abs <= half + pad_x && s >= -pad_x && s <= num + pad_x
    end
    nil
  end
  def self.panel_world_box(panel, _7fa7da40)
    cutting = KSU::Cutting.cutting_group(panel)
    failed, world_tr = cutting && cutting.valid? ? [cutting.bounds, _7fa7da40 * panel.transformation] : [panel.bounds, _7fa7da40]
    KSU::Geom.world_box(failed, world_tr)
  end
  def self.panel_bbox(panel)
    return Geom::BoundingBox.new unless panel && panel.valid?
    KSU::Geom.world_box(panel.definition.bounds, panel.transformation)
  end
  def self.offset_bbox(bbox, _71fbc725)
    out = Geom::BoundingBox.new
    out.add(bbox.min.offset(_71fbc725))
    out.add(bbox.max.offset(_71fbc725))
    out
  end
  def self.button_center(rec)
    text, x1, y0, y1, z = extents(rec[:top_corners])
    Geom::Point3d.new((text + x1) / 2.0, y1 + 200.mm, z)
  end
  def self.in_rect?(x, y, rect)
    x >= rect[:left] && x <= rect[:right] && y >= rect[:top] && y <= rect[:bottom]
  end
  def self.near_seg?(trai, duoi, pt, b, tol)
    dx = b.x - pt.x
    dy = b.y - pt.y
    len2 = dx * dx + dy * dy
    return false if len2 < 1e-9
    t = ((trai - pt.x) * dx + (duoi - pt.y) * dy) / len2
    t = 0.0 if t < 0.0
    t = 1.0 if t > 1.0
    px = pt.x + t * dx
    py = pt.y + t * dy
    ddx = trai - px
    ddy = duoi - py
    ddx * ddx + ddy * ddy <= tol * tol
  end
  def self.hit_sheet_top?(view, x, y, rec)
    in_poly?(x, y, rec[:top_corners].map { |pt3| view.screen_coords(pt3) })
  end
  def self.hit?(view, fill, x, y)
    return false unless fill
    outer = fill[:outer]
    return false unless outer && outer.length >= 3
    return false unless in_poly?(x, y, outer.map { |pt3| view.screen_coords(pt3) })
    (fill[:holes] || []).each do |arr|
      next if arr.length < 3
      return false if in_poly?(x, y, arr.map { |pt3| view.screen_coords(pt3) })
    end
    true
  end
  def self.draw_loops(outer, holes, color)
    return unless color && outer && outer.length >= 3
    draw_loop(outer, color: color)
    (holes || []).each { |elem| draw_loop(elem, color: color) if elem && elem.length >= 3 }
  end
  def self.rank_color(layers)
    arr = [
      [231, 76, 60], [46, 204, 113], [52, 152, 219], [243, 156, 18],
      [155, 89, 182], [26, 188, 156], [241, 196, 15], [230, 126, 34]
    ]
    rgb = arr[(layers - 1) % arr.length]
    Sketchup::Color.new(rgb[0], rgb[1], rgb[2], 180)
  end
  def self.draw_dim_arrow(view, x1, y1, x2, y2, tip)
    set_pen(Sketchup::Color.new(0, 0, 0), true)
    view.line_width = 1
    view.draw2d(GL_LINES, [Geom::Point3d.new(x1, y1, 0), Geom::Point3d.new(x2, y2, 0)])
    s = 8
    arr = case tip
          when :right then [[x2, y2], [x2 - s, y2 - s], [x2, y2], [x2 - s, y2 + s]]
          when :left  then [[x2, y2], [x2 + s, y2 - s], [x2, y2], [x2 + s, y2 + s]]
          when :down  then [[x2, y2], [x2 - s, y2 - s], [x2, y2], [x2 + s, y2 - s]]
          when :up    then [[x2, y2], [x2 - s, y2 + s], [x2, y2], [x2 + s, y2 + s]]
          end
    view.draw2d(GL_LINES, arr.map { |a, b| Geom::Point3d.new(a, b, 0) })
  end
end
require "fileutils"
require "json"
module KSU::View
  def self.seed_license_file
    FileUtils.mkdir_p(KSU::Settings.data_dir)
    return if File.exist?(KSU::Cutting.license_path)
    cands2 = KSU::Flip.read_license_file
    return if cands2.nil?
    File.write(KSU::Cutting.license_path, KSU::Nfp.pack_key(JSON.generate(cands2)))
    File.delete(KSU::Collide.license_json) if File.exist?(KSU::Collide.license_json)
  end
  def self.show_activation_result(key, resp)
    if resp.nil?
      UI.messagebox "Kích hoạt thất bại! Không kết nối được với máy chủ."
      return false
    end
    err_code = resp["code"] || resp.dig("data", "code")
    unless resp["success"] == true || err_code == "key_activated" || err_code == "instance_already_activated"
      UI.messagebox "Kích hoạt thất bại! " + KSU::Back.activation_error(err_code)
      return false
    end
    KSU::Nfp.save_binding(key)
    UI.messagebox "Kích hoạt thành công! Còn lại " + KSU::Shape.activations_left(resp, key).to_s + " lượt kích hoạt."
    true
  end
end
