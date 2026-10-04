module KSU::Query
  def load_colors
    num = KSU::Settings.get("do_dam_mat_xem_truoc", 10, "cai_dat").to_f / 100
    mat = parse_color(KSU::Settings.get("mau_mat_xem_truoc", "60,175,214", "cai_dat"))
    mat.alpha = num
    main = Sketchup::Color.new(mat.red, mat.green, mat.blue)
    main.alpha = [num * 2, 1.0].min
    sub = Sketchup::Color.new(mat.red, mat.green, mat.blue)
    sub.alpha = num / 2
    edge = parse_color(KSU::Settings.get("mau_net_xem_truoc", "61,61,153", "cai_dat"))
    weight = [(KSU::Settings.get("do_dam_net_xem_truoc", 2, "cai_dat").to_i * ui_scale).round, 1].max
    palette = parse_color(KSU::Settings.get("mau_chu_ghi_chu", "61,61,153", "cai_dat"))
    num2 = (KSU::Settings.get("co_chu_ghi_chu", 8, "cai_dat").to_i * ui_scale).round
    warn = parse_color(KSU::Settings.get("mau_canh_bao", "210,117,159", "cai_dat"))
    warning_face_color = Sketchup::Color.new(warn.red, warn.green, warn.blue)
    warning_face_color.alpha = [num * 2, 1.0].min
    normal_rgb = parse_color(KSU::Settings.get("mau_tam_thuong", "128,128,128", "cai_dat"))
    normal = Sketchup::Color.new(normal_rgb.red, normal_rgb.green, normal_rgb.blue, 200)
    group_rgb = parse_color(KSU::Settings.get("mau_nhom_tam", "179,179,179", "cai_dat"))
    group = Sketchup::Color.new(group_rgb.red, group_rgb.green, group_rgb.blue, 200)
    ph = parse_color(KSU::Settings.get("mau_tam_hai_mat", "98,195,165", "cai_dat"))
    two = Sketchup::Color.new(ph.red, ph.green, ph.blue, 200)
    @style_memo = {
      face_color: mat, main_face_color: main, sub_face_color: sub,
      edge_color: edge, edge_weight: weight,
      text_color: palette, text_size: num2,
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
    @num6 ||= Sketchup.version.to_i >= 25 ? 1.0 : UI.scale_factor.to_f
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
  def restore_perspective(was_persp)
    cam = view&.camera
    return unless cam
    return if was_persp.nil?
    cam.perspective = was_persp if cam.perspective? != was_persp
  end
  def parse_color(value)
    rgb = case value
            when String then value.split(",").map { |v| v.strip.to_i }
            when Array then value
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
    flag = false
    n = poly.length
    j = n - 1
    n.times do |i|
      xi, yi = poly[i].x, poly[i].y
      xj, yj = poly[j].x, poly[j].y
      if ((yi > duoi) != (yj > duoi)) && (trai < (xj - xi) * (duoi - yi) / (yj - yi) + xi)
        flag = !flag
      end
      j = i
    end
    flag
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
  def in_front?(pt)
    cam = view.camera
    cam.direction.dot(cam.eye.vector_to(pt)) > 0
  end
  def to_screen(pts)
    return [] unless pts && pts.length > 0
    return [] if pts.any? { |pt| !in_front?(pt) }
    pts.map { |pt| view.screen_coords(pt) }
  end
  def draw_lines(pts, color: nil, guide: false, width: nil)
    return unless pts && pts.length >= 2
    set_pen(color || edge_color, guide)
    view.line_width = width if width
    view.draw(GL_LINES, pts)
  end
  def draw_loop(pts, color: nil, guide: false)
    return unless pts && pts.length >= 3
    set_pen(color || edge_color, guide)
    view.draw(GL_LINE_LOOP, pts)
  end
  def draw_loop2d(pts, color: nil, guide: false)
    return unless pts && pts.length >= 3
    arr = to_screen(pts)
    return unless arr.length >= 3
    set_pen(color || edge_color, guide)
    view.draw2d(GL_LINE_LOOP, arr)
  end
  def draw_poly(pts, color: nil, line: true)
    draw_polys([pts], color: color, line: line)
  end
  def draw_poly_holes(outer, holes, color: nil, line: true)
    draw_polys([{ outer: outer, holes: holes }], color: color, line: line)
  end
  def poly_tris(outer, holes)
    arr = (holes || []).select { |h| h && h.length >= 3 }
    arr.empty? ? Geom.tesselate(outer) : Geom.tesselate(outer, *arr)
  rescue StandardError
    Geom.tesselate(outer)
  end
  def draw_polys(arr, color: nil, line: true)
    tris = []
    arr.each do |poly|
      if poly.is_a?(Hash)
        outer = poly[:outer]
        next unless outer && outer.length >= 3
        draw_loop(outer) if line
        tris.concat(poly_tris(outer, poly[:holes]))
      else
        next unless poly && poly.length >= 3
        draw_loop(poly) if line
        tris.concat(Geom.tesselate(poly))
      end
    end
    return if tris.empty?
    set_pen(color || face_color)
    view.draw(GL_TRIANGLES, tris)
  end
  def band_tris(pts, thickness:, position: :outside)
    return [] unless pts && pts.length >= 3
    n = pts.length
    px = pts.inject(0.0) { |s, pt3| s + pt3.x.to_f } / n
    py = pts.inject(0.0) { |s, pt3| s + pt3.y.to_f } / n
    arr2 = n.times.map do |i|
      pt2 = pts[i]
      b = pts[(i + 1) % n]
      rx = b.x.to_f - pt2.x.to_f
      ry = b.y.to_f - pt2.y.to_f
      len = Math.sqrt(rx * rx + ry * ry)
      next [0.0, 0.0] if len < 1e-6
      nx = -ry / len
      ny = rx / len
      num6 = (pt2.x.to_f + b.x.to_f) / 2.0
      num4 = (pt2.y.to_f + b.y.to_f) / 2.0
      if (px - num6) * nx + (py - num4) * ny > 0
        nx = -nx
        ny = -ny
      end
      [nx, ny]
    end
    thick = thickness.to_f
    arr = case position
               when :inside then [0.0, thick]
               when :center then [thick / 2.0, thick / 2.0]
               else [thick, 0.0]
               end
    out_d = arr[0]
    in_d = arr[1]
    outer = offset_poly(pts, arr2, out_d, 1.0)
    arr3 = offset_poly(pts, arr2, in_d, -1.0)
    tris = []
    n.times do |i|
      quad = [arr3[i], outer[i], outer[(i + 1) % n], arr3[(i + 1) % n]]
      tris.concat(Geom.tesselate(quad))
    end
    tris
  end
  def draw_band(pts, thickness:, position: :outside, color: nil)
    tris = band_tris(pts, thickness: thickness, position: position)
    return if tris.empty?
    set_pen(color || face_color)
    view.draw(GL_TRIANGLES, tris)
  end
  def offset_poly(pts, arr3, dist, sign)
    n = pts.length
    n.times.map do |i|
      pt = pts[i]
      next pt if dist <= 0
      arr2 = arr3[(i - 1) % n]
      arr = arr3[i]
      bx2 = arr2[0] + arr[0]
      by2 = arr2[1] + arr[1]
      len = Math.sqrt(bx2 * bx2 + by2 * by2)
      if len < 1e-9
        Geom::Point3d.new(pt.x + arr[0] * dist * sign, pt.y + arr[1] * dist * sign, pt.z)
      else
        dot = arr2[0] * arr[0] + arr2[1] * arr[1]
        sin_half = Math.sqrt([(1 - dot) / 2.0, 0.0].max)
        len2d = sin_half > 1e-3 ? dist / sin_half : dist * 4
        Geom::Point3d.new(pt.x + bx2 / len * len2d * sign, pt.y + by2 / len * len2d * sign, pt.z)
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
