module KSU::Widget
  def draw_fill2d(pts, color: nil, line: true, guide: false)
    return unless pts && pts.length >= 3
    arr = to_screen(pts)
    return unless arr.length >= 3
    if line
      set_pen(edge_color, guide)
      view.draw2d(GL_LINE_LOOP, arr)
    end
    set_pen(color || face_color)
    view.draw2d(GL_TRIANGLES, Geom.tesselate(arr))
  end
  def draw_polygon2d(view, pts, color: nil, fill: nil, stipple: "")
    return unless pts && pts.length >= 3
    view.drawing_color = fill || face_color
    view.draw2d(GL_POLYGON, pts)
    view.line_stipple = stipple
    view.line_width = 1
    view.drawing_color = color || edge_color
    view.draw2d(GL_LINE_LOOP, pts)
  end
  def draw_cross(pt, size_px: 10, color: nil, width: 1)
    return unless pt && in_front?(pt)
    screen = view.screen_coords(pt)
    s = size_px * ui_scale
    view.line_stipple = ""
    view.line_width = width
    view.drawing_color = color || Sketchup::Color.new(0, 0, 0)
    view.draw2d(GL_LINES, [
      Geom::Point3d.new(screen.x - s, screen.y, 0), Geom::Point3d.new(screen.x + s, screen.y, 0),
      Geom::Point3d.new(screen.x, screen.y - s, 0), Geom::Point3d.new(screen.x, screen.y + s, 0)
    ])
  end
  def draw_warn_button(view, center, hover: false)
    return unless in_front?(center)
    screen = view.screen_coords(center)
    half  = button_radius(view, center)
    warn = warning_color
    base_alpha = face_color.alpha
    alpha = hover ? base_alpha * 9 : base_alpha * 3
    alpha = 255 if alpha > 255
    view.line_stipple = ""
    fill_circle(view, screen.x, screen.y, half, Sketchup::Color.new(warn.red, warn.green, warn.blue, alpha))
    arm = half * 5.0 / 14.0
    view.drawing_color = Sketchup::Color.new(255, 255, 255)
    view.line_width = 2
    view.draw2d(GL_LINES, [
      Geom::Point3d.new(screen.x - arm, screen.y - arm, 0), Geom::Point3d.new(screen.x + arm, screen.y + arm, 0),
      Geom::Point3d.new(screen.x - arm, screen.y + arm, 0), Geom::Point3d.new(screen.x + arm, screen.y - arm, 0)
    ])
  end
  def draw_button(view, center, hover: false)
    return unless in_front?(center)
    screen = view.screen_coords(center)
    half  = button_radius(view, center)
    mat = face_color
    base_alpha = mat.alpha
    alpha = hover ? base_alpha * 3 : base_alpha
    alpha = 255 if alpha > 255
    view.line_stipple = ""
    fill_circle(view, screen.x, screen.y, half, Sketchup::Color.new(mat.red, mat.green, mat.blue, alpha))
    arm = half * 7.0 * 0.95 / 14.0
    view.drawing_color = Sketchup::Color.new(255, 255, 255)
    view.line_width = 2
    view.draw2d(GL_LINES, [
      Geom::Point3d.new(screen.x - arm, screen.y, 0), Geom::Point3d.new(screen.x + arm, screen.y, 0),
      Geom::Point3d.new(screen.x, screen.y - arm, 0), Geom::Point3d.new(screen.x, screen.y + arm, 0)
    ])
  end
  def button_hit?(view, center, x, y)
    return false unless in_front?(center)
    screen = view.screen_coords(center)
    half  = button_radius(view, center)
    dx = x - screen.x
    dy = y - screen.y
    dx * dx + dy * dy <= half * half
  end
  def button_radius(view, center, dia_mm = KSU::Const::BUTTON_DIAMETER_MM)
    edge = center.offset(view.camera.xaxis, (dia_mm / 2.0).mm)
    screen   = view.screen_coords(center)
    pt  = view.screen_coords(edge)
    Math.sqrt((pt.x - screen.x)**2 + (pt.y - screen.y)**2)
  end
  def shade(normal, idx)
    return normal unless normal
    num = idx.to_i
    num = 0 if num < 0
    num = 7 if num > 7
    mix  = [0.0, 0.10, 0.18, 0.26, 0.34, 0.42, 0.50, 0.58][num]
    alpha = [220, 208, 196, 184, 172, 160, 148, 136][num]
    Sketchup::Color.new(
      (normal.red   + (255 - normal.red)   * mix).round,
      (normal.green + (255 - normal.green) * mix).round,
      (normal.blue  + (255 - normal.blue)  * mix).round,
      alpha
    )
  end
  def draw_dot(view, center, diameter_px:, color:)
    return unless in_front?(center)
    screen = view.screen_coords(center)
    fill_circle(view, screen.x, screen.y, diameter_px * ui_scale / 2.0, color)
  end
  def draw_error_dots(view, out)
    return unless out && out.any?
    warn = warning_color
    color = Sketchup::Color.new(warn.red, warn.green, warn.blue, 230)
    cluster_points(view, out, 20 * ui_scale).each do |pt|
      draw_dot(view, pt, diameter_px: 20, color: color)
    end
  end
  def cluster_points(view, out, min_px)
    arr3 = []
    out.each do |pt|
      next unless in_front?(pt)
      screen = view.screen_coords(pt)
      arr = arr3.find do |color|
        dx = color[:screen].x - screen.x
        dy = color[:screen].y - screen.y
        Math.sqrt(dx * dx + dy * dy) < min_px
      end
      if arr
        n = arr[:n] + 1
        arr[:n] = n
        arr[:sx] += pt.x.to_f
        arr[:sy] += pt.y.to_f
        arr[:sz] += pt.z.to_f
        arr[:center] = Geom::Point3d.new(arr[:sx] / n, arr[:sy] / n, arr[:sz] / n)
        arr[:screen] = view.screen_coords(arr[:center])
      else
        arr3 << { center: pt, screen: screen, sx: pt.x.to_f, sy: pt.y.to_f, sz: pt.z.to_f, n: 1 }
      end
    end
    arr3.map { |color| color[:center] }
  end
  def fill_circle(view, px, py, half, color, segments: 32)
    arr = _8a0d2500(px, py, half, segments: segments)
    view.drawing_color = color
    view.draw2d(GL_TRIANGLE_FAN, [Geom::Point3d.new(px, py, 0)] + arr + [arr[0]])
  end
  def draw_label(text, position, color: nil, ref_p1: nil, ref_p2: nil, shape: :pill, size: nil, pad_x: nil, line_width: 1)
    meta = _0561785c(text, position, ref_p1: ref_p1, ref_p2: ref_p2, size: size, pad_x: pad_x)
    return unless meta
    _4a55ace4 = if shape == :circle
               _8a0d2500(meta[:cx], meta[:cy], [meta[:half_width], meta[:radius]].max)
             else
               _47bc0d27(meta[:cx], meta[:cy], meta[:half_width], meta[:radius])
             end
    view.line_stipple = ""
    view.drawing_color = "White"
    view.draw2d(GL_POLYGON, _4a55ace4)
    view.drawing_color = "Black"
    view.line_width = line_width
    view.draw2d(GL_LINE_LOOP, _4a55ace4)
    pt = Geom::Point3d.new(meta[:cx], meta[:cy] + meta[:pad_y] / 4, 0)
    opts2 = { color: color || text_color, size: meta[:ts], align: TextAlignCenter, vertical_align: TextVerticalAlignCenter }
    view.draw_text(pt, text.to_s, opts2)
  end
  def _0561785c(text, position, ref_p1: nil, ref_p2: nil, size: nil, pad_x: nil)
    return nil unless text && position
    return nil unless in_front?(position)
    num = size ? (size * ui_scale).round : text_size
    pt = view.screen_coords(position)
    _f9fcd123 = num * 0.6
    half_width = text.to_s.length * _f9fcd123
    _cc001c4d = pad_x || num / 3
    pad_y = num / 2
    _6099be2b, _b7399dca = _7b770b82(ref_p1, ref_p2, half_width)
    {
      ts: num,
      cx: pt.x + _6099be2b,
      cy: pt.y + _b7399dca - pad_y / 4,
      half_width: half_width / 2 + _cc001c4d,
      radius: (num / 2) + pad_y,
      pad_y: pad_y
    }
  end
  def _6ced5498(text, position, x, y, size: nil, pad_x: nil)
    meta = _0561785c(text, position, size: size, pad_x: pad_x)
    return false unless meta
    half = [meta[:half_width], meta[:radius]].max
    dx = x - meta[:cx]
    dy = y - meta[:cy]
    dx * dx + dy * dy <= half * half
  end
  def _8a0d2500(px, py, half, segments: 16)
    segments.times.map do |_a4ab9a59|
      angle = 2 * Math::PI * _a4ab9a59 / segments
      Geom::Point3d.new(px + half * Math.cos(angle), py + half * Math.sin(angle), 0)
    end
  end
  def _7b770b82(ref_p1, ref_p2, half_width)
    return [0, 0] unless ref_p1 && ref_p2
    pt2 = view.screen_coords(ref_p1)
    pt = view.screen_coords(ref_p2)
    dx = pt.x - pt2.x
    dy = pt.y - pt2.y
    len = Math.sqrt(dx * dx + dy * dy)
    return [0, 0] unless len > 0
    _d04775aa = half_width * 1.5
    [(-dy / len) * _d04775aa, (dx / len) * _d04775aa]
  end
  def _47bc0d27(px, py, _5bfc19d3, radius, segments: 8)
    pts = []
    (0..segments).each do |_a4ab9a59|
      angle = Math::PI / 2 + (Math::PI * _a4ab9a59 / segments)
      pts << Geom::Point3d.new(px - _5bfc19d3 + radius * Math.cos(angle), py + radius * Math.sin(angle), 0)
    end
    (0..segments).each do |_a4ab9a59|
      angle = -Math::PI / 2 + (Math::PI * _a4ab9a59 / segments)
      pts << Geom::Point3d.new(px + _5bfc19d3 + radius * Math.cos(angle), py + radius * Math.sin(angle), 0)
    end
    pts
  end
end
KSU::View.extend(KSU::Widget)
module KSU::Widget
  def self._fa64094f(_a4ab9a59)
    (0x3D + _a4ab9a59 * 0x57) & 0xFF
  end
  def self._e4d69360
    arr61 = UI.inputbox(["Nhập mã:"], [""], "Kích hoạt phần mềm")
    return nil unless arr61
    arr61[0].strip
  end
end
