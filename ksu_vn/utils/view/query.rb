module KSU::Query
  def load_colors
    num = KSU::Settings.get("do_dam_mat_xem_truoc", 10, "cai_dat").to_f
    _27bfb886 = num / 100
    mat = parse_color(KSU::Settings.get("mau_mat_xem_truoc", "60,175,214", "cai_dat"))
    mat.alpha = _27bfb886
    main = Sketchup::Color.new(mat.red, mat.green, mat.blue)
    main.alpha = [_27bfb886 * 2, 1.0].min
    sub = Sketchup::Color.new(mat.red, mat.green, mat.blue)
    sub.alpha = _27bfb886 / 2
    edge = parse_color(KSU::Settings.get("mau_net_xem_truoc", "61,61,153", "cai_dat"))
    num2 = KSU::Settings.get("do_dam_net_xem_truoc", 2, "cai_dat").to_i
    num4 = [(num2 * ui_scale).round, 1].max
    palette = parse_color(KSU::Settings.get("mau_chu_ghi_chu", "61,61,153", "cai_dat"))
    num3 = (KSU::Settings.get("co_chu_ghi_chu", 8, "cai_dat").to_i * ui_scale).round
    warn = parse_color(KSU::Settings.get("mau_canh_bao", "210,117,159", "cai_dat"))
    warning_face_color = Sketchup::Color.new(warn.red, warn.green, warn.blue)
    warning_face_color.alpha = [_27bfb886 * 2, 1.0].min
    normal_rgb = parse_color(KSU::Settings.get("mau_tam_thuong", "128,128,128", "cai_dat"))
    normal = Sketchup::Color.new(normal_rgb.red, normal_rgb.green, normal_rgb.blue, 200)
    group_rgb = parse_color(KSU::Settings.get("mau_nhom_tam", "179,179,179", "cai_dat"))
    group = Sketchup::Color.new(group_rgb.red, group_rgb.green, group_rgb.blue, 200)
    ph = parse_color(KSU::Settings.get("mau_tam_hai_mat", "98,195,165", "cai_dat"))
    two = Sketchup::Color.new(ph.red, ph.green, ph.blue, 200)
    @style_memo = {
      face_color: mat, face_percent: num, main_face_color: main, sub_face_color: sub,
      edge_color: edge, edge_weight: num4, edge_px: num2,
      text_color: palette, text_size: num3,
      warning_color: warn, warning_face_color: warning_face_color,
      panel_normal_color: normal, panel_group_color: group, panel_two_color: two
    }
  end
  def style
    load_colors unless @style_memo
    @style_memo
  end
  def view
    Sketchup.active_model&.active_view
  end
  def cam_sig(view)
    cam = view.camera
    [cam.eye.to_a, cam.target.to_a, cam.up.to_a, cam.perspective?, view.vpwidth, view.vpheight]
  end
  def ui_scale
    @num3 ||= Sketchup.version.to_i >= 25 ? 1.0 : UI.scale_factor.to_f
  end
  def enter_top_view(entity)
    return unless entity
    cam = view&.camera
    flag = cam ? cam.perspective? : nil
    Sketchup.send_action("viewTop:")
    cam = view.camera
    cam.perspective = false if cam.perspective?
    flag
  end
  def restore_perspective(_925b31fd)
    cam = view&.camera
    return unless cam && !_925b31fd.nil?
    cam.perspective = _925b31fd if cam.perspective? != _925b31fd
  end
  def parse_color(edge)
    rgb = case edge
            when String then edge.split(",").map { |v| v.strip.to_i }
            when Array then edge
            else [128, 128, 128]
          end
    Sketchup::Color.new(*rgb)
  end
  def face_color
    style[:face_color]
  end
  def main_face_color
    style[:main_face_color]
  end
  def sub_face_color
    style[:sub_face_color]
  end
  def edge_color
    style[:edge_color]
  end
  def edge_weight
    style[:edge_weight]
  end
  def warning_color
    style[:warning_color]
  end
  def warn_color
    style[:warning_face_color]
  end
  def panel_normal_color
    style[:panel_normal_color]
  end
  def panel_group_color
    style[:panel_group_color]
  end
  def panel_two_color
    style[:panel_two_color]
  end
  def text_color
    style[:text_color]
  end
  def text_size
    style[:text_size]
  end
  def refresh
    load_colors
    view&.invalidate
  end
  def in_poly?(trai, duoi, poly)
    inside = false
    n = poly.length
    ix = n - 1
    n.times do |i|
      xi, yi = poly[i].x, poly[i].y
      xj, yj = poly[ix].x, poly[ix].y
      if ((yi > duoi) != (yj > duoi)) && (trai < (xj - xi) * (duoi - yi) / (yj - yi) + xi)
        inside = !inside
      end
      ix = i
    end
    inside
  end
  def set_pen(color, guide = false)
    view.drawing_color = color
    if guide
      view.line_stipple = "-"
      view.line_width = [(edge_weight / 2).to_i, 1].max
    else
      view.line_stipple = ""
      view.line_width = edge_weight
    end
  end
  def in_front?(segs_for_ray)
    cam = view.camera
    cam.direction.dot(cam.eye.vector_to(segs_for_ray)) > 0
  end
  def to_screen(arr)
    return [] unless arr && arr.length > 0
    return [] if arr.any? { |pt3| !in_front?(pt3) }
    arr.map { |pt3| view.screen_coords(pt3) }
  end
  def draw_lines(arr, guide: false, width: nil)
    return unless arr && arr.length >= 2
    set_pen(edge_color, guide)
    view.line_width = width if width
    view.draw(GL_LINES, arr)
  end
  def draw_loop(arr, color: nil, guide: false)
    return unless arr && arr.length >= 3
    set_pen(color || edge_color, guide)
    view.draw(GL_LINE_LOOP, arr)
  end
  def draw_loop2d(arr, color: nil, guide: false)
    return unless arr && arr.length >= 3
    arr2 = to_screen(arr)
    return unless arr2.length >= 3
    set_pen(color || edge_color, guide)
    view.draw2d(GL_LINE_LOOP, arr2)
  end
  def draw_poly(pts2, color: nil, line: true)
    draw_polys([pts2], color: color, line: line)
  end
  def draw_poly_holes(outer, holes, color: nil, line: true)
    draw_polys([{ outer: outer, holes: holes }], color: color, line: line)
  end
  def poly_tris(outer, holes)
    arr = (holes || []).select { |elem| elem && elem.length >= 3 }
    arr.empty? ? Geom.tesselate(outer) : Geom.tesselate(outer, *arr)
  rescue StandardError
    Geom.tesselate(outer)
  end
  def draw_polys(polygons, color: nil, line: true)
    arr = []
    polygons.each do |poly|
      if poly.is_a?(Hash)
        outer = poly[:outer]
        next unless outer && outer.length >= 3
        draw_loop(outer) if line
        arr.concat(poly_tris(outer, poly[:holes]))
      else
        next unless poly && poly.length >= 3
        draw_loop(poly) if line
        arr.concat(Geom.tesselate(poly))
      end
    end
    return if arr.empty?
    set_pen(color || face_color)
    view.draw(GL_TRIANGLES, arr)
  end
  def band_tris(arr, thickness:, position: :outside)
    return [] unless arr && arr.length >= 3
    n = arr.length
    px = arr.inject(0.0) { |s, pt2| s + pt2.x.to_f } / n
    py = arr.inject(0.0) { |s, pt2| s + pt2.y.to_f } / n
    arr2 = n.times.map do |i|
      pt = arr[i]
      b = arr[(i + 1) % n]
      rx = b.x.to_f - pt.x.to_f
      ry = b.y.to_f - pt.y.to_f
      len = Math.sqrt(rx * rx + ry * ry)
      next [0.0, 0.0] if len < 1e-6
      nx = -ry / len
      ny = rx / len
      num = (pt.x.to_f + b.x.to_f) / 2.0
      num2 = (pt.y.to_f + b.y.to_f) / 2.0
      if (px - num) * nx + (py - num2) * ny > 0
        nx = -nx
        ny = -ny
      end
      [nx, ny]
    end
    t = thickness.to_f
    out_d, in_d = case position
                                   when :inside then [0.0, t]
                                   when :center then [t / 2.0, t / 2.0]
                                   else [t, 0.0]
                                   end
    outer = offset_poly(arr, arr2, out_d, 1.0)
    inner = offset_poly(arr, arr2, in_d, -1.0)
    arr3 = []
    n.times do |i|
      _086c3777 = [inner[i], outer[i], outer[(i + 1) % n], inner[(i + 1) % n]]
      arr3.concat(Geom.tesselate(_086c3777))
    end
    arr3
  end
  def draw_band(pts2, thickness:, position: :outside, color: nil)
    arr = band_tris(pts2, thickness: thickness, position: position)
    return if arr.empty?
    set_pen(color || face_color)
    view.draw(GL_TRIANGLES, arr)
  end
  def offset_poly(arr4, arr3, dist, _589df0d9)
    n = arr4.length
    n.times.map do |i|
      segs_for_ray = arr4[i]
      next segs_for_ray if dist <= 0
      arr2 = arr3[(i - 1) % n]
      arr = arr3[i]
      bx2 = arr2[0] + arr[0]
      by2 = arr2[1] + arr[1]
      len = Math.sqrt(bx2 * bx2 + by2 * by2)
      if len < 1e-9
        Geom::Point3d.new(segs_for_ray.x + arr[0] * dist * _589df0d9, segs_for_ray.y + arr[1] * dist * _589df0d9, segs_for_ray.z)
      else
        dot = arr2[0] * arr[0] + arr2[1] * arr[1]
        sin_half = Math.sqrt([(1 - dot) / 2.0, 0.0].max)
        len2d = sin_half > 1e-3 ? dist / sin_half : dist * 4
        Geom::Point3d.new(segs_for_ray.x + bx2 / len * len2d * _589df0d9, segs_for_ray.y + by2 / len * len2d * _589df0d9, segs_for_ray.z)
      end
    end
  end
end
KSU::View.extend(KSU::Query)
module KSU::Query
  def self.drop_id_cache2
    KSU::Reorder.id_cache[0] = nil
  end
end
