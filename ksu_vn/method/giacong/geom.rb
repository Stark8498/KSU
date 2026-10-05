module KSU::Giacong
  EPS_ARC = 0.0001
  LAYER_STYLES = {
    "ABF_cuttingLines"  => ["_ABF_CUTTING_LINES", 54, [127, 127, 0]],
    "ABF_sheetBorder"   => ["_ABF_SHEET_BORDER", 30, [255, 127, 0]],
    "ABF_partBorder"    => ["_ABF_PART_BORDER", 213, [165, 82, 165]],
    "ABF_markSquare"    => ["_ABF_MARK_SQUARE", 170, [0, 0, 255]],
    "ABF_sheetId"       => ["_ABF_SHEET_ID", 100, [0, 255, 63]],
    "ABF_sheetMaterial" => ["_ABF_SHEET_MATERIAL", 1, [255, 0, 0]]
  }.freeze
  class PtEx < ::Geom::Point3d
    attr_accessor :bulge
    def initialize(*a)
      super
      @bulge = 0.0
    end
  end
  module_function
  def arc_center_of(p1, p2, p3)
    return nil if p1 == p2 || p2 == p3
    pt = ::Geom::Point3d.new((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, 0)
    pt2 = ::Geom::Point3d.new((p2.x + p3.x) / 2, (p2.y + p3.y) / 2, 0)
    d1 = p1.vector_to(p2).cross(::Z_AXIS)
    d2 = p2.vector_to(p3).cross(::Z_AXIS)
    return nil unless d1.valid? && d2.valid?
    ::Geom.intersect_line_line([pt, d1], [pt2, d2])
  end
  def vectors_parallel?(vec, b)
    vec = vec.normalize
    b = b.normalize
    len2d = vec.dot(b)
    len2d = -1.0 if len2d < -1
    len2d = 1.0 if len2d > 1
    deg4 = Math.acos(len2d)
    deg4 = 2 * Math::PI - deg4 if vec.cross(b).dot(::Z_AXIS) < 0
    (deg4 - (2 * Math::PI)).abs < EPS_ARC ? 0.0 : deg4
  end
  def detect_arc(box)
    return nil if box.size < 12
    _68582c75 = box[0].distance(box[1])
    (1...box.size - 1).each do |i|
      return nil if (_68582c75 - box[i].distance(box[i + 1])).abs > EPS_ARC
    end
    center = arc_center_of(box[0], box[box.size / 3], box[box.size * 2 / 3])
    return nil unless center
    half = center.distance(box[0])
    (1...box.size).each do |i|
      return nil if (half - center.distance(box[i])).abs > EPS_ARC
    end
    { center: center, radius: half }
  end
  def corner_at(box, i)
    num = box.size
    p1 = box[i]
    p2 = box[(i + 1) % num]
    p3 = box[(i + 2) % num]
    _1efef886 = p1.distance(p2)
    return nil if (p2.distance(p3) - _1efef886).abs > EPS_ARC
    center = arc_center_of(p1, p2, p3)
    return nil unless center
    r = p1.distance(center)
    num2 = 2
    start_i = i
    end_i = i + 2
    (start_i - 1).downto(i - num + 3) do |ix|
      _da4d1e02 = ix % num
      _c0ca53f2 = (ix + 1) % num
      break unless (box[_da4d1e02].distance(box[_c0ca53f2]) - _1efef886).abs < EPS_ARC &&
                   (box[_da4d1e02].distance(center) - r).abs < EPS_ARC
      start_i = _da4d1e02
      num2 += 1
    end
    pt3 = box[start_i - 1]
    pt = box[start_i]
    pt2 = box[(start_i + 1) % num]
    p_next = box[(start_i + 2) % num]
    a1 = vectors_parallel?(pt2.vector_to(p_next), pt2.vector_to(pt))
    a2 = vectors_parallel?(pt.vector_to(pt2), pt.vector_to(pt3))
    if pt.distance(pt3) < _1efef886 && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      start_i -= 1
      num2 += 1
    end
    (end_i + 1..end_i + num - 3).each do |ix|
      _da4d1e02 = ix % num
      _2f581e4c = (ix - 1) % num
      break unless (box[_2f581e4c].distance(box[_da4d1e02]) - _1efef886).abs < EPS_ARC &&
                   (box[_da4d1e02].distance(center) - r).abs < EPS_ARC
      end_i = _da4d1e02
      num2 += 1
    end
    end_i %= num
    pt3 = box[end_i - 1]
    pt = box[end_i]
    pt2 = box[(end_i + 1) % num]
    a1 = vectors_parallel?(pt.vector_to(pt2), pt.vector_to(pt3))
    a2 = vectors_parallel?(pt3.vector_to(pt), pt3.vector_to(box[end_i - 2]))
    if end_i < num - 1 && pt.distance(pt2) < _1efef886 && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      end_i += 1
      num2 += 1
    end
    return nil if num2 < 5
    return nil if num2 > num
    p1 = box[start_i]
    p2 = box[(start_i + 1) % num]
    p3 = box[(start_i + 2) % num]
    vec = p1.vector_to(center)
    vec4 = p2.vector_to(center)
    vec2 = box[end_i].vector_to(center)
    _47c7e3b1 = vec.cross(vec4).z > 0
    deg4 = _47c7e3b1 ? vectors_parallel?(vec, vec2) : vectors_parallel?(vec2, vec)
    return nil if num == 6 && num2 == 5 && deg4.radians > 299
    return nil if num2 == 6 && deg4.radians > 359
    bulge = Math.tan(deg4 / 4)
    vec3 = p1.vector_to(p2).cross(p1.vector_to(p3)).z
    bulge *= (vec3 >= 0 ? 1 : -1)
    { start_i: start_i, end_i: end_i, bulge: bulge }
  end
  def simplify_loop(box)
    if box[0] == box[-1]
      return box if box.size < 12
    elsif box.size < 5
      return box
    end
    if box[0].vector_to(box[1]).cross(box[1].vector_to(box[2])).z < 0
      box.reverse!
    end
    loop do
      done = true
      (0...box.size).each do |i|
        arr = corner_at(box, i)
        next unless arr
        start_i = arr[:start_i]
        end_i = arr[:end_i]
        pt3 = box[start_i]
        if start_i < end_i
          box -= box[(start_i + 1...end_i)]
        else
          box = box[(end_i..start_i)]
        end
        pt3.bulge = arr[:bulge]
        done = false
        break
      end
      break if done
    end
    box
  end
  def build_loops(snap_edges)
    arr = []
    h = {}
    snap_edges.each do |edge|
      [edge.start, edge.end].each do |v|
        next if h[v.entityID]
        h[v.entityID] = arr.size
        arr << v
      end
    end
    n = arr.size
    return [] if n < 3
    arr2 = Array.new(n) { Array.new(n, false) }
    snap_edges.each do |edge|
      i = h[edge.start.entityID]
      ix = h[edge.end.entityID]
      arr2[i][ix] = true
      arr2[ix][i] = true
    end
    seen3 = []
    arr3 = Array.new(n, false)
    (0...n).each do |i|
      next if arr3[i]
      back = Array.new(n, i)
      walk_loop(i, i, arr2, arr3, back, n, arr, seen3)
    end
    seen3
  end
  def walk_loop(start, i, arr, arr2, back, n, arr3, seen3)
    arr2[i] = true
    done = true
    (0...n).each do |ix|
      next unless arr[i][ix] && !arr2[ix]
      done = false
      back[ix] = i
      walk_loop(start, ix, arr, arr2, back, n, arr3, seen3)
    end
    return unless done
    return unless arr[start][i]
    path = []
    _7a72dc50 = i
    loop do
      path << _7a72dc50
      _7a72dc50 = back[_7a72dc50]
      break if _7a72dc50 == start
    end
    path << start
    seen3 << path.map { |ix2| arr3[ix2] }
  end
  def entity_name(name)
    s = name.to_s.tr(
      "ĂÂÊÔƠƯăâêôơưÁÉÓÚÍÝÀÈÒÙÌỲẢẺỎỦỈỶÃẼÕŨĨỸẠẸỌỤỊỴẮẤẾỐỚỨẰẦỀỒỜỪẲẨỂỔỞỬẴẪỄỖỠỮẶẬỆỘỢỰĐáéóúíýàèòùìỳảẻỏủỉỷãẽõũĩỹạẹọụịỵắấếốớứằầềồờừẳẩểổởửẵẫễỗỡữặậệộợựđ -",
      "AAEOOUaaeoouAEOUIYAEOUIYAEOUIYAEOUIYAEOUIYAAEOOUAAEOOUAAEOOUAAEOOUAAEOOUDaeouiyaeouiyaeouiyaeouiyaeouiyaaeoouaaeoouaaeoouaaeoouaaeooud__"
    ).upcase
    s.gsub(/[^0-9A-Z()$.\-_]/, "")
  end
  def pack_rgb(half, num, b)
    (half.to_i << 16) | (num.to_i << 8) | b.to_i
  end
  def layer_style(str)
    str = str.to_s
    return ["0", 7, [128, 128, 128]] if str.empty? || str == "0" || str.casecmp("Layer0").zero?
    _fa73ee8a = LAYER_STYLES[str]
    return _fa73ee8a if _fa73ee8a
    model = Sketchup.active_model.layers[str]
    rgb = model && model.color ? [model.color.red, model.color.green, model.color.blue] : [0, 0, 0]
    [entity_name(str), 1, rgb]
  end
end
