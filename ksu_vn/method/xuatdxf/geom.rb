module KSU::Xuatdxf
  EPS_ARC = 0.0001
  LAYER_STYLES = {
    "ABF_cuttingLines"  => ["_ABF_CUTTING_LINES", 54, [127, 127, 0]],
    "ABF_sheetBorder"   => ["_ABF_SHEET_BORDER", 30, [255, 127, 0]],
    "ABF_partBorder"    => ["_ABF_PART_BORDER", 213, [165, 82, 165]],
    "ABF_markSquare"    => ["_ABF_MARK_SQUARE", 170, [0, 0, 255]],
    "ABF_sheetId"       => ["_ABF_SHEET_ID", 100, [0, 255, 63]],
    "ABF_sheetMaterial" => ["_ABF_SHEET_MATERIAL", 1, [255, 0, 0]]
  }.freeze
  class PtEx < Geom::Point3d
    attr_accessor :bulge
    def initialize(*v)
      super
      @bulge = 0.0
    end
  end
  module_function
  def arc_center(p1, p2, p3)
    return nil if p1 == p2 || p2 == p3
    pt2 = Geom::Point3d.new((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, 0)
    pt = Geom::Point3d.new((p2.x + p3.x) / 2, (p2.y + p3.y) / 2, 0)
    d1 = p1.vector_to(p2).cross(Z_AXIS)
    d2 = p2.vector_to(p3).cross(Z_AXIS)
    return nil unless d1.valid? && d2.valid?
    Geom.intersect_line_line([pt2, d1], [pt, d2])
  end
  def vec_angle(v, b)
    v = v.normalize
    b = b.normalize
    len2d = v.dot(b)
    len2d = -1.0 if len2d < -1
    len2d = 1.0 if len2d > 1
    deg4 = Math.acos(len2d)
    deg4 = 2 * Math::PI - deg4 if v.cross(b).dot(Z_AXIS) < 0
    (deg4 - (2 * Math::PI)).abs < EPS_ARC ? 0.0 : deg4
  end
  def circle?(box)
    return nil if box.size < 12
    step_len = box[0].distance(box[1])
    (1...box.size - 1).each do |i|
      return nil if (step_len - box[i].distance(box[i + 1])).abs > EPS_ARC
    end
    center = arc_center(box[0], box[box.size / 3], box[box.size * 2 / 3])
    return nil unless center
    half = center.distance(box[0])
    (1...box.size).each do |i|
      return nil if (half - center.distance(box[i])).abs > EPS_ARC
    end
    { center: center, radius: half }
  end
  def arc_at(box, i)
    num_v1 = box.size
    p1 = box[i]
    p2 = box[(i + 1) % num_v1]
    p3 = box[(i + 2) % num_v1]
    chord = p1.distance(p2)
    return nil if (p2.distance(p3) - chord).abs > EPS_ARC
    center = arc_center(p1, p2, p3)
    return nil unless center
    r = p1.distance(center)
    num2 = 2
    start_i = i
    end_i = i + 2
    (start_i - 1).downto(i - num_v1 + 3) do |j|
      ja = j % num_v1
      jb = (j + 1) % num_v1
      break unless (box[ja].distance(box[jb]) - chord).abs < EPS_ARC &&
                   (box[ja].distance(center) - r).abs < EPS_ARC
      start_i = ja
      num2 += 1
    end
    pt3 = box[start_i - 1]
    pt = box[start_i]
    pt2 = box[(start_i + 1) % num_v1]
    p_next = box[(start_i + 2) % num_v1]
    a1 = vec_angle(pt2.vector_to(p_next), pt2.vector_to(pt))
    a2 = vec_angle(pt.vector_to(pt2), pt.vector_to(pt3))
    if pt.distance(pt3) < chord && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      start_i -= 1
      num2 += 1
    end
    (end_i + 1..end_i + num_v1 - 3).each do |j|
      ja = j % num_v1
      jp = (j - 1) % num_v1
      break unless (box[jp].distance(box[ja]) - chord).abs < EPS_ARC &&
                   (box[ja].distance(center) - r).abs < EPS_ARC
      end_i = ja
      num2 += 1
    end
    end_i %= num_v1
    pt3 = box[end_i - 1]
    pt = box[end_i]
    pt2 = box[(end_i + 1) % num_v1]
    a1 = vec_angle(pt.vector_to(pt2), pt.vector_to(pt3))
    a2 = vec_angle(pt3.vector_to(pt), pt3.vector_to(box[end_i - 2]))
    if end_i < num_v1 - 1 && pt.distance(pt2) < chord && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      end_i += 1
      num2 += 1
    end
    return nil if num2 < 5
    return nil if num2 > num_v1
    p1 = box[start_i]
    p2 = box[(start_i + 1) % num_v1]
    p3 = box[(start_i + 2) % num_v1]
    vec = p1.vector_to(center)
    vec3 = p2.vector_to(center)
    vec2 = box[end_i].vector_to(center)
    ccw3 = vec.cross(vec3).z > 0
    deg4 = ccw3 ? vec_angle(vec, vec2) : vec_angle(vec2, vec)
    return nil if num_v1 == 6 && num2 == 5 && deg4.radians > 299
    return nil if num2 == 6 && deg4.radians > 359
    bulge = Math.tan(deg4 / 4)
    vec4 = p1.vector_to(p2).cross(p1.vector_to(p3)).z
    bulge *= (vec4 >= 0 ? 1 : -1)
    { start_i: start_i, end_i: end_i, bulge: bulge }
  end
  def simplify_bulge(box, deadline = nil)
    if box[0] == box[-1]
      return box if box.size < 12
    elsif box.size < 5
      return box
    end
    if box[0].vector_to(box[1]).cross(box[1].vector_to(box[2])).z < 0
      box.reverse!
    end
    loop do
      break if deadline && Time.now > deadline
      done = true
      (0...box.size).each do |i|
        color = arc_at(box, i)
        next unless color
        start_i = color[:start_i]
        end_i = color[:end_i]
        pt4 = box[start_i]
        if start_i < end_i
          box -= box[(start_i + 1...end_i)]
        else
          box = box[(end_i..start_i)]
        end
        pt4.bulge = color[:bulge]
        done = false
        break
      end
      break if done
    end
    box
  end
  def merge_loops(snap_edges)
    arr = []
    seen = {}
    snap_edges.each do |ent|
      [ent.start, ent.end].each do |v|
        next if seen[v.entityID]
        seen[v.entityID] = arr.size
        arr << v
      end
    end
    n = arr.size
    return [] if n < 3
    arr2 = Array.new(n) { Array.new(n, false) }
    snap_edges.each do |ent|
      i = seen[ent.start.entityID]
      j = seen[ent.end.entityID]
      arr2[i][j] = true
      arr2[j][i] = true
    end
    seen3 = []
    arr3 = Array.new(n, false)
    (0...n).each do |i|
      next if arr3[i]
      back = Array.new(n, i)
      walk_arc(i, i, arr2, arr3, back, n, arr, seen3)
    end
    seen3
  end
  def walk_arc(start, i, arr2, arr, back, n, arr3, seen3)
    arr[i] = true
    done = true
    (0...n).each do |j|
      next unless arr2[i][j] && !arr[j]
      done = false
      back[j] = i
      walk_arc(start, j, arr2, arr, back, n, arr3, seen3)
    end
    return unless done
    return unless arr2[start][i]
    path = []
    _7e53f420 = i
    loop do
      path << _7e53f420
      _7e53f420 = back[_7e53f420]
      break if _7e53f420 == start
    end
    path << start
    seen3 << path.map { |ix| arr3[ix] }
  end
  def ascii_name(name)
    s = name.to_s.tr(
      "ĂÂÊÔƠƯăâêôơưÁÉÓÚÍÝÀÈÒÙÌỲẢẺỎỦỈỶÃẼÕŨĨỸẠẸỌỤỊỴẮẤẾỐỚỨẰẦỀỒỜỪẲẨỂỔỞỬẴẪỄỖỠỮẶẬỆỘỢỰĐáéóúíýàèòùìỳảẻỏủỉỷãẽõũĩỹạẹọụịỵắấếốớứằầềồờừẳẩểổởửẵẫễỗỡữặậệộợựđ -",
      "AAEOOUaaeoouAEOUIYAEOUIYAEOUIYAEOUIYAEOUIYAAEOOUAAEOOUAAEOOUAAEOOUAAEOOUDaeouiyaeouiyaeouiyaeouiyaeouiyaaeoouaaeoouaaeoouaaeoouaaeooud__"
    ).upcase
    s.gsub(/[^0-9A-Z()$.\-_]/, "")
  end
  def true_color_of(half, g, b)
    (half.to_i << 16) | (g.to_i << 8) | b.to_i
  end
  def layer_spec(str)
    str = str.to_s
    return ["0", 7, [128, 128, 128]] if str.empty? || str == "0" || str.casecmp("Layer0").zero?
    style2 = LAYER_STYLES[str]
    return style2 if style2
    model = Sketchup.active_model.layers[str]
    rgb = model && model.color ? [model.color.red, model.color.green, model.color.blue] : [0, 0, 0]
    [ascii_name(str), 1, rgb]
  end
  def dxf_color(_e64bdf77)
    half, g, b = layer_spec(_e64bdf77)[2]
    format("#%02x%02x%02x", half, g, b)
  end
end
