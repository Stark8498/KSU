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
    def initialize(*_9710d820)
      super
      @bulge = 0.0
    end
  end
  module_function
  def _2d01dec4(p1, p2, p3)
    return nil if p1 == p2 || p2 == p3
    pt3 = Geom::Point3d.new((p1.x + p2.x) / 2, (p1.y + p2.y) / 2, 0)
    pt4 = Geom::Point3d.new((p2.x + p3.x) / 2, (p2.y + p3.y) / 2, 0)
    d1 = p1.vector_to(p2).cross(Z_AXIS)
    d2 = p2.vector_to(p3).cross(Z_AXIS)
    return nil unless d1.valid? && d2.valid?
    Geom.intersect_line_line([pt3, d1], [pt4, d2])
  end
  def _b33d5052(vec2, b)
    vec2 = vec2.normalize
    b = b.normalize
    len2d = vec2.dot(b)
    len2d = -1.0 if len2d < -1
    len2d = 1.0 if len2d > 1
    num = Math.acos(len2d)
    num = 2 * Math::PI - num if vec2.cross(b).dot(Z_AXIS) < 0
    (num - (2 * Math::PI)).abs < EPS_ARC ? 0.0 : num
  end
  def _a54bea0f(box)
    return nil if box.size < 12
    _67416b90 = box[0].distance(box[1])
    (1...box.size - 1).each do |i|
      return nil if (_67416b90 - box[i].distance(box[i + 1])).abs > EPS_ARC
    end
    center = _2d01dec4(box[0], box[box.size / 3], box[box.size * 2 / 3])
    return nil unless center
    half = center.distance(box[0])
    (1...box.size).each do |i|
      return nil if (half - center.distance(box[i])).abs > EPS_ARC
    end
    { center: center, radius: half }
  end
  def _826c9296(box, i)
    num = box.size
    p1 = box[i]
    p2 = box[(i + 1) % num]
    p3 = box[(i + 2) % num]
    _d9b81a7a = p1.distance(p2)
    return nil if (p2.distance(p3) - _d9b81a7a).abs > EPS_ARC
    center = _2d01dec4(p1, p2, p3)
    return nil unless center
    r = p1.distance(center)
    num13 = 2
    start_i = i
    end_i = i + 2
    (start_i - 1).downto(i - num + 3) do |j|
      _771229d2 = j % num
      _bfe9f61b = (j + 1) % num
      break unless (box[_771229d2].distance(box[_bfe9f61b]) - _d9b81a7a).abs < EPS_ARC &&
                   (box[_771229d2].distance(center) - r).abs < EPS_ARC
      start_i = _771229d2
      num13 += 1
    end
    pt3 = box[start_i - 1]
    pt = box[start_i]
    pt4 = box[(start_i + 1) % num]
    _dc176291 = box[(start_i + 2) % num]
    a1 = _b33d5052(pt4.vector_to(_dc176291), pt4.vector_to(pt))
    a2 = _b33d5052(pt.vector_to(pt4), pt.vector_to(pt3))
    if pt.distance(pt3) < _d9b81a7a && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      start_i -= 1
      num13 += 1
    end
    (end_i + 1..end_i + num - 3).each do |j|
      _771229d2 = j % num
      _78b1bbe1 = (j - 1) % num
      break unless (box[_78b1bbe1].distance(box[_771229d2]) - _d9b81a7a).abs < EPS_ARC &&
                   (box[_771229d2].distance(center) - r).abs < EPS_ARC
      end_i = _771229d2
      num13 += 1
    end
    end_i %= num
    pt3 = box[end_i - 1]
    pt = box[end_i]
    pt4 = box[(end_i + 1) % num]
    a1 = _b33d5052(pt.vector_to(pt4), pt.vector_to(pt3))
    a2 = _b33d5052(pt3.vector_to(pt), pt3.vector_to(box[end_i - 2]))
    if end_i < num - 1 && pt.distance(pt4) < _d9b81a7a && a1.radians < 72.001 && (a1 - a2).abs < EPS_ARC
      end_i += 1
      num13 += 1
    end
    return nil if num13 < 5
    return nil if num13 > num
    p1 = box[start_i]
    p2 = box[(start_i + 1) % num]
    p3 = box[(start_i + 2) % num]
    vec2 = p1.vector_to(center)
    vec5 = p2.vector_to(center)
    vec4 = box[end_i].vector_to(center)
    _0f0ce717 = vec2.cross(vec5).z > 0
    flag = _0f0ce717 ? _b33d5052(vec2, vec4) : _b33d5052(vec4, vec2)
    return nil if num == 6 && num13 == 5 && flag.radians > 299
    return nil if num13 == 6 && flag.radians > 359
    bulge = Math.tan(flag / 4)
    vec6 = p1.vector_to(p2).cross(p1.vector_to(p3)).z
    bulge *= (vec6 >= 0 ? 1 : -1)
    { start_i: start_i, end_i: end_i, bulge: bulge }
  end
  def _074e3371(box, deadline = nil)
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
        color = _826c9296(box, i)
        next unless color
        start_i = color[:start_i]
        end_i = color[:end_i]
        _23505ef9 = box[start_i]
        if start_i < end_i
          box -= box[(start_i + 1...end_i)]
        else
          box = box[(end_i..start_i)]
        end
        _23505ef9.bulge = color[:bulge]
        done = false
        break
      end
      break if done
    end
    box
  end
  def _c73c2639(snap_edges)
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
    arr4 = []
    arr3 = Array.new(n, false)
    (0...n).each do |i|
      next if arr3[i]
      back = Array.new(n, i)
      _4e8cbee3(i, i, arr2, arr3, back, n, arr, arr4)
    end
    arr4
  end
  def _4e8cbee3(start, i, arr2, arr, back, n, arr4, _c520310e)
    arr[i] = true
    done = true
    (0...n).each do |j|
      next unless arr2[i][j] && !arr[j]
      done = false
      back[j] = i
      _4e8cbee3(start, j, arr2, arr, back, n, arr4, _c520310e)
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
    _c520310e << path.map { |ix| arr4[ix] }
  end
  def _2b17a799(name)
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
    _133ee34f = LAYER_STYLES[str]
    return _133ee34f if _133ee34f
    model = Sketchup.active_model.layers[str]
    rgb = model && model.color ? [model.color.red, model.color.green, model.color.blue] : [0, 0, 0]
    [_2b17a799(str), 1, rgb]
  end
  def _302ced66(_e64bdf77)
    half, g, b = layer_spec(_e64bdf77)[2]
    format("#%02x%02x%02x", half, g, b)
  end
end
