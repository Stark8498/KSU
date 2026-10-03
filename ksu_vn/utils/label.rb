module KSU::Label
  DICT = "ABF"
  K_IS_LABEL = "is-label"
  K_LABEL_WIDTH = "label-width"
  K_LABEL_HEIGHT = "label-height"
  K_LABEL_SCALE = "label-scale"
  K_LABEL_ROTATION = "label-rotation"
  K_IS_LABELED_FACE = "is-labeled-face"
  K_IS_CNCED_FACE = "is-cnced-face"
  K_BOARD_INDEX = "board-index"
  LAYER_LABEL = "ABF_Label"
  GROUP_NAME = "_ABF_Label"
  TEXT_H_PADDING_X2 = 2.4
  NAME_SCALE = 0.6
  LABEL_H_REF = 2.0
  module_function
  def apply_case(text, str2)
    thick = text.to_s
    case str2.to_s
    when "upper" then thick.upcase
    when "lower" then thick.downcase
    when "title" then thick.gsub(/[^\s]+/) { |w| w.capitalize }
    else thick
    end
  end
  def plan(container)
    KSU::Font.import
    return nil unless KSU::Font.ready?
    renumber = Array(container).compact.empty?
    parts = renumber ? every_board : boards_in(container)
    { jobs: jobs(parts, renumber), layer: KSU::Cutting.layer(LAYER_LABEL), renumber: renumber }
  end
  def board?(ent)
    return false unless ent && ent.valid? && KSU.container?(ent)
    !KSU::Cutting.board_faces(ent, KSU::Cutting.tf_of(ent)).nil?
  end
  def boards_in(container)
    seen = {}
    out = []
    Array(container).each do |ent|
      next unless ent && ent.valid? && KSU.container?(ent)
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      out << ent if board?(ent)
    end
    out
  end
  def every_board
    out = []
    seen = {}
    walk(Sketchup.active_model.entities, out, seen)
    out
  end
  def walk(ents, out, seen)
    ents.each do |ent|
      next unless KSU.container?(ent) && ent.valid?
      next if ent.get_attribute(DICT, "is-flatten")
      next if seen[ent.entityID]
      seen[ent.entityID] = true
      if board?(ent)
        out << ent
      else
        kids = KSU.entities_in(ent)
        walk(kids, out, seen) if kids
      end
    end
  end
  def jobs(parts, renumber = false)
    arr2 = parts.select { |grp| grp && grp.valid? }
    ordered = arr2.each_with_index
                        .sort_by { |grp, i| [KSU::Nesting.sort_key(grp.name), i] }
                        .map { |grp, _ix| grp }
    h = {}
    arr = []
    ordered.each do |grp|
      ix = renumber ? nil : grp.get_attribute(DICT, K_BOARD_INDEX)
      ix = nil if ix && h[ix]
      if ix.nil? || ix < 1
        ix = 1
        ix += 1 while h[ix]
      end
      h[ix] = true
      arr << [grp, ix]
    end
    arr
  end
  def label?(ent)
    return false unless ent && ent.valid? && KSU.container?(ent)
    return true if ent.get_attribute(DICT, K_IS_LABEL)
    name = ent.name.to_s
    def_name = (ent.respond_to?(:definition) && ent.definition) ? ent.definition.name.to_s : ""
    return true if name.include?(LAYER_LABEL) || def_name.include?(LAYER_LABEL)
    grp2 = ent.layer
    !grp2.nil? && grp2.name.to_s == LAYER_LABEL
  end
  def clear_label_attrs(grp)
    (KSU.entities_in(grp) || []).grep(Sketchup::Face).each do |f|
      f.delete_attribute(DICT, K_IS_LABELED_FACE)
      f.delete_attribute(DICT, K_IS_CNCED_FACE)
    end
    grp.delete_attribute(DICT, K_LABEL_ROTATION)
  end
  def draw_label_on(grp, idx, _2cb52d46, topts)
    grp.make_unique
    ents = KSU.entities_in(grp)
    return false unless ents
    arr2 = ents.to_a.select { |g| label?(g) }
    flag = !arr2.empty?
    arr2.each(&:erase!)
    keep_existing = flag && topts.fetch(:keep_existing, true)
    clear_label_attrs(grp) unless topts.fetch(:keep_existing, true)
    tf = world_tf(grp)
    b2 = KSU::Cutting.board_faces(grp, tf)
    return false unless b2
    font = keep_existing ? b2.find { |f| f.get_attribute(DICT, K_IS_LABELED_FACE) } : nil
    font ||= _681febe3(grp, b2, tf)
    font ||= _89cdc81b(grp, b2, tf)
    font ||= b2.find { |f| f.get_attribute(DICT, K_IS_CNCED_FACE) }
    font ||= b2.find { |f| f.get_attribute(DICT, K_IS_LABELED_FACE) }
    font ||= pick_face(b2[0], b2[1], tf)
    return false unless font
    str = label_text(grp).to_s
    str = topts[:default_name].to_s.strip if str.empty?
    disp = apply_case(str, topts[:letter_case])
    grp.name = str.empty? ? "__#{idx}" : "__#{idx}. #{str}"
    grp.set_attribute(DICT, "is-board", true)
    grp.set_attribute(DICT, K_BOARD_INDEX, idx)
    grp2 = KSU.entities_in(grp).add_group
    grp2.name = GROUP_NAME
    grp2.set_attribute(DICT, K_IS_LABEL, true)
    draw_badge(grp2, grp2.entities, disp, idx, topts)
    rot = grp.get_attribute(DICT, K_LABEL_ROTATION) || 0
    label_box(grp2, font, tf, rot, topts[:max_size], topts.fetch(:center, true))
    KSU::Cutting.set_layer(grp2, _2cb52d46)
    _f612f2b9(grp, font)
    grp.set_attribute(DICT, K_LABEL_ROTATION, rot)
    grp2.definition.invalidate_bounds if grp2.respond_to?(:definition) && grp2.definition
    grp.definition.invalidate_bounds if grp.respond_to?(:definition) && grp.definition
    true
  end
  def draw_badge(gr, ents, name, str, topts)
    gap2 = topts[:gap]
    xf = topts[:xf]
    x = 0
    ents.add_curve([2.2, 1, 0], [1.65, 1.55, 0], [0.55, 1.55, 0], [0, 1, 0], [0.55, 0.45, 0], [1.65, 0.45, 0], [2.2, 1, 0])
    text = str.to_s
    num = KSU::Font.half_width(text, true)
    num = 0.001 if num <= 0
    upm = [(1.5 / num), NAME_SCALE].min
    num_w = num * upm
    arr = KSU::Font._1589cfd8(text)
    py = (arr[0] + arr[1]) / 2.0 * upm
    num2 = 1 - py
    KSU::Font._068ebc81(ents, text, [1.1 - (num_w / 2.0), num2], upm, true)
    x += 2.2
    name_w = KSU::Font.half_width(name, false, gap2) * NAME_SCALE * xf
    box_w = name_w + TEXT_H_PADDING_X2
    y = num2
    KSU::Font._068ebc81(ents, name, [x + ((box_w - name_w) / 2), y], NAME_SCALE, false, gap2, xf)
    x2 = x + box_w
    w2 = name_w
    if w2 > 0
      _d38e1814 = x + ((box_w - w2) / 2)
      _5b73324a = _d38e1814 + w2
      ents.add_edges([x, 1, 0], [_d38e1814, 1, 0])
      ents.add_edges([_5b73324a, 1, 0], [x2, 1, 0])
    else
      ents.add_edges([x, 1, 0], [x2, 1, 0])
    end
    ents.add_curve([x2, 1.5, 0], [x2 + (Math.sqrt(3) / 2.0), 1, 0], [x2, 0.5, 0], [x2, 1.5, 0])
    row_w = gr.local_bounds.width
    bb = gr.local_bounds.height
    lo = gr.local_bounds.min
    ents.transform_entities(Geom::Transformation.translation([-row_w / 2 - lo.x, -bb / 2 - lo.y, 0]), ents.to_a)
    flag = bb > 0 ? LABEL_H_REF / bb : 1.0
    gr.set_attribute(DICT, K_LABEL_WIDTH, (row_w * flag).to_f)
    gr.set_attribute(DICT, K_LABEL_HEIGHT, LABEL_H_REF.to_f)
  end
  def label_box(grp, font, tf, rot, max_h, center = true)
    h = face_axes(font, tf)
    unless center
      rect = inner_rect(font, tf, h)
      if rect && rect[:large] > 0 && rect[:small] > 0
        h = h.merge(
          large_size: rect[:large],
          small_size: rect[:small],
          tf_axes: Geom::Transformation.axes(rect[:center], h[:ax], h[:ay], h[:az])
        )
      end
    end
    upright = (rot == 0) || (rot == 180)
    num = 4.cm
    if upright
      num = 2.cm if h[:small_size] < 20.cm
      num = 1.cm if h[:small_size] < 10.cm
      num = 4.mm if h[:small_size] < 5.cm
    else
      num = 1.cm if h[:small_size] < 40.cm
      num = 4.mm if h[:small_size] < 20.cm
      num = 2.mm if h[:small_size] < 10.cm
    end
    _8010294b(grp, h, tf, rot, max_h, num)
  end
  def _8010294b(grp, arr, tf, rot, max_h, _5ec460ae)
    bb2 = grp.local_bounds.width
    bb = grp.local_bounds.height
    return unless bb2 && bb && bb2 > 0 && bb > 0
    pt2 = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), rot.degrees)
    if rot == 0 || rot == 180
      stroke_w = (arr[:large_size] - _5ec460ae) / bb2
      sheet_h = [(arr[:small_size] - _5ec460ae), max_h].min / bb
    else
      stroke_w = (arr[:small_size] - _5ec460ae) / bb2
      sheet_h = [(arr[:large_size] - _5ec460ae), max_h].min / bb
    end
    num = [stroke_w, sheet_h].min
    num = 0.001 if num <= 0
    tr2 = Geom::Transformation.scaling(num, num, 1.0)
    tr = Geom::Transformation.new(tf.inverse)
    tr = tr * arr[:tf_axes]
    _c8bde48c = tr.xaxis.transform(tf).angle_between(arr[:line_vec])
    pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), _c8bde48c)
    tr = tr * pt
    unless tr.xaxis.transform(tf).parallel?(arr[:line_vec])
      tr = tr * pt.inverse
      _c8bde48c = Math::PI - _c8bde48c
      pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), _c8bde48c)
      tr = tr * pt
    end
    if tr.yaxis.transform(tf).z < 0
      tr = tr * pt.inverse
      _c8bde48c = _c8bde48c + Math::PI
      pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), _c8bde48c)
      tr = tr * pt
    end
    tr = tr * pt2
    tr = tr * tr2
    grp.transformation = tr
    grp.set_attribute(DICT, K_LABEL_SCALE, (num * bb / LABEL_H_REF).to_f)
    grp.definition.invalidate_bounds if grp.respond_to?(:definition) && grp.definition
  end
  def face_axes(font, tf)
    _32998202 = KSU::Cutting._b344f39a(font.bounds, tf)
    large_size = _32998202[2][0]
    small_size = _32998202[1][0]
    line_vec = _32998202[2][1]
    snap_edges = font.edges.map { |ent| [ent, ent.length(tf)] }.sort_by { |arr2| arr2[1] }
    if snap_edges.length >= 2
      vec = snap_edges[-1][0].line[1].transform(tf)
      _298717ec = snap_edges[-2][0].line[1].transform(tf)
      if snap_edges[-1][1] > (large_size / 1.414) && vec.parallel?(_298717ec) && (snap_edges[-1][0].length(tf) - snap_edges[-2][0].length(tf)).abs < 0.001
        line_vec = vec
      end
    end
    center = font.bounds.center.transform(tf)
    ref_p2 = font.normal.transform(tf)
    ax = ref_p2.axes[0]
    ay = ref_p2.axes[1]
    az = ref_p2.axes[2]
    tf_axes = Geom::Transformation.axes(center, ax, ay, az)
    { large_size: large_size, small_size: small_size, line_vec: line_vec, tf_axes: tf_axes,
      center: center, ax: ax, ay: ay, az: az }
  end
  def _9f608530(_bc71159c, poly)
    arr = []
    j = poly.size - 1
    poly.each_index do |i|
      yi = poly[i][1]
      yj = poly[j][1]
      if (yi > _bc71159c) != (yj > _bc71159c)
        xi = poly[i][0]
        xj = poly[j][0]
        arr << (xj - xi) * (_bc71159c - yi) / (yj - yi) + xi
      end
      j = i
    end
    arr.sort!
    arr
  end
  def _efa8b7d4(arr, _fbc30e40)
    num = 0
    arr.each do |x|
      break if x >= _fbc30e40
      num += 1
    end
    num.odd?
  end
  def _8cfbee10(arr, tol)
    _e8649a72 = arr.first
    _e25dbacd = arr.last
    _972803c5 = arr.dup
    _89bad203 = (_e25dbacd - _e8649a72) / 64.0
    (1...64).each { |i| _972803c5 << _e8649a72 + _89bad203 * i } if _89bad203 > tol
    KSU::Geom._a404e7b6(_972803c5, tol)
  end
  def inner_rect(font, tf, arr6)
    color = arr6[:center]
    n = arr6[:az]
    line_vec = arr6[:line_vec]
    _4664cd3f = line_vec.dot(n)
    ax = Geom::Vector3d.new(line_vec.x - n.x * _4664cd3f, line_vec.y - n.y * _4664cd3f, line_vec.z - n.z * _4664cd3f)
    if ax.length > 1e-6
      ax.normalize!
    else
      ax = arr6[:ax]
    end
    pt = n.cross(ax)
    return nil unless pt.length > 1e-9
    pt.normalize!
    outer = font.outer_loop
    return nil unless outer
    _1431d16b = lambda do |face|
      face.vertices.map do |v|
        len2d = v.position.transform(tf) - color
        [len2d.dot(ax), len2d.dot(pt)]
      end
    end
    opac = _1431d16b.call(outer)
    return nil if opac.size < 3
    holes = (font.loops - [outer]).map { |_b41d8800| _1431d16b.call(_b41d8800) }
    arr12 = opac + holes.flatten(1)
    arr9 = arr12.map { |arr7| arr7[0] }.sort
    style = arr12.map { |arr7| arr7[1] }.sort
    _e0c27e7f = arr9.last - arr9.first
    _5a14088d = style.last - style.first
    return nil if _e0c27e7f <= 0 || _5a14088d <= 0
    tol = [_e0c27e7f, _5a14088d].max / 192.0
    arr2 = _8cfbee10(arr9, tol)
    arr3 = _8cfbee10(style, tol)
    return nil if arr2.size < 2 || arr3.size < 2
    num2 = arr2.size - 1
    rows = arr3.size - 1
    grid = Array.new(rows) { Array.new(num2, false) }
    rows.times do |half|
      _6e2cbaa3 = arr3[half]
      _57f116a2 = arr3[half + 1]
      _b6d1d40c = (_57f116a2 - _6e2cbaa3) * 1e-6
      arr10 = _9f608530(_6e2cbaa3 + _b6d1d40c, opac)
      arr8 = _9f608530(_57f116a2 - _b6d1d40c, opac)
      next if arr10.size < 2 || arr8.size < 2
      arr15 = holes.map { |h| _9f608530(_6e2cbaa3 + _b6d1d40c, h) }
      arr14 = holes.map { |h| _9f608530(_57f116a2 - _b6d1d40c, h) }
      arr16 = grid[half]
      num2.times do |num|
        _296d32cf = arr2[num]
        _20e46575 = arr2[num + 1]
        _5353a747 = (_20e46575 - _296d32cf) * 1e-6
        _a5d8aa8c = _296d32cf + _5353a747
        _c05963ef = _20e46575 - _5353a747
        next unless _efa8b7d4(arr10, _a5d8aa8c) && _efa8b7d4(arr10, _c05963ef) &&
                    _efa8b7d4(arr8, _a5d8aa8c) && _efa8b7d4(arr8, _c05963ef)
        next if arr15.any? { |x2| _efa8b7d4(x2, _a5d8aa8c) || _efa8b7d4(x2, _c05963ef) }
        next if arr14.any? { |x2| _efa8b7d4(x2, _a5d8aa8c) || _efa8b7d4(x2, _c05963ef) }
        arr16[num] = true
      end
    end
    start2 = Array.new(num2, 0.0)
    arr5 = Array.new(num2, 0.0)
    active_ix = Array.new(num2, false)
    best = nil
    area = 0.0
    rows.times do |half|
      _57f116a2 = arr3[half + 1]
      num2.times do |num|
        if grid[half][num]
          start2[num] = arr3[half] unless active_ix[num]
          active_ix[num] = true
          arr5[num] = _57f116a2 - start2[num]
        else
          active_ix[num] = false
          arr5[num] = 0.0
        end
      end
      arr4 = []
      num = 0
      while num <= num2
        flag2 = num < num2 ? arr5[num] : 0.0
        if arr4.empty? || flag2 >= arr5[arr4.last]
          arr4.push(num)
          num += 1
        else
          _ab593548 = arr4.pop
          h = arr5[_ab593548]
          flag = arr4.empty? ? 0 : arr4.last + 1
          _5fb96e91 = h * (arr2[num] - arr2[flag])
          if h > 0 && _5fb96e91 > area
            area = _5fb96e91
            best = [arr2[flag], arr2[num], _57f116a2 - h, _57f116a2]
          end
        end
      end
    end
    return nil unless best
    _b0f47b06 = (best[0] + best[1]) / 2.0
    _f79423d2 = (best[2] + best[3]) / 2.0
    large = best[1] - best[0]
    small = best[3] - best[2]
    center = color + Geom::Vector3d.new(
      ax.x * _b0f47b06 + pt.x * _f79423d2,
      ax.y * _b0f47b06 + pt.y * _f79423d2,
      ax.z * _b0f47b06 + pt.z * _f79423d2
    )
    { large: large, small: small, center: center }
  end
  def _681febe3(grp, b2, tf)
    grp7 = KSU::Cutting.cutting_group(grp)
    return nil unless grp7 && grp7.valid? && grp7.visible?
    snap_edges = (KSU.entities_in(grp7) || []).grep(Sketchup::Edge)
    return nil if snap_edges.empty?
    pt = snap_edges[0].start.position.transform(tf * grp7.transformation)
    vec2 = pt.distance_to_plane([b2[0].bounds.center.transform(tf), b2[0].normal.transform(tf)])
    d1 = pt.distance_to_plane([b2[1].bounds.center.transform(tf), b2[1].normal.transform(tf)])
    vec2 < d1 ? b2[0] : b2[1]
  end
  def _89cdc81b(grp, b2, tf)
    vec2 = [b2[0].bounds.center.transform(tf), b2[0].normal.transform(tf)]
    vec = [b2[1].bounds.center.transform(tf), b2[1].normal.transform(tf)]
    flag = false
    flag2 = false
    (KSU.entities_in(grp) || []).each do |g|
      next unless KSU.container?(g) && g.valid? && g.visible?
      next if g.get_attribute(DICT, K_IS_LABEL)
      next if g.get_attribute(DICT, "is-side-drill-depth")
      arr2 = KSU.entities_in(g)
      next unless arr2
      next if _5f641d51(g, arr2)
      snap_edges = arr2.grep(Sketchup::Edge)
      next if snap_edges.empty?
      pt = snap_edges[0].start.position.transform(tf * g.transformation)
      _7b905c3b = pt.distance_to_plane(vec2)
      d1 = pt.distance_to_plane(vec)
      next if [_7b905c3b, d1].min > 2.mm
      if _7b905c3b < d1
        flag = true
      else
        flag2 = true
      end
    end
    return b2[0] if flag && !flag2
    return b2[1] if flag2 && !flag
    nil
  end
  def _5f641d51(g, arr)
    return true if arr.grep(Sketchup::ConstructionLine).any?
    return true if _a233e68c(g.layer)
    arr.grep(Sketchup::Edge).any? { |ent| _a233e68c(ent.layer) }
  end
  def _a233e68c(_2cb52d46)
    return false unless _2cb52d46 && _2cb52d46.respond_to?(:line_style)
    grp = _2cb52d46.line_style
    return false unless grp
    grp.name.to_s != "Solid Basic"
  end
  def pick_face(face, face2, tf)
    vec8 = face.normal.transform(tf)
    vec2 = face2.normal.transform(tf)
    pt2 = face.bounds.center.transform(tf)
    pt = face2.bounds.center.transform(tf)
    model = Sketchup.active_model.raytest(pt2.offset(vec8, 10.mm), vec8)
    model2 = Sketchup.active_model.raytest(pt.offset(vec2, 10.mm), vec2)
    flag2 = model ? pt2.distance(model[0]) : 9999
    d1 = model2 ? pt.distance(model2[0]) : 9999
    vec = Geom::Vector3d.new(1, -1, 1)
    flag3 = vec8.angle_between(vec) > vec2.angle_between(vec) ? face : face2
    return flag3 if flag2 == 9999 && d1 == 9999
    return face2 if flag2 == 9999 && d1 < 9999
    return face if d1 == 9999 && flag2 < 9999
    return flag3 unless flag2 < 9999 && d1 < 9999
    return flag3 if [flag2, d1].min > 10.cm
    flag2 > d1 ? face2 : face
  end
  def label_text(node)
    name = node.name.to_s
    name = name[2..-1] if name.start_with?("__")
    name ||= ""
    idx = node.get_attribute(DICT, K_BOARD_INDEX)
    return name unless idx
    str2 = idx.to_s
    return name unless name.start_with?(str2)
    str = name[str2.length..-1].to_s
    return name unless str.start_with?(".")
    str = str[1..-1].to_s
    str = str[1..-1].to_s if str.start_with?(" ")
    str
  end
  def _f612f2b9(gr, font)
    (KSU.entities_in(gr) || []).grep(Sketchup::Face).each do |f|
      f.delete_attribute(DICT, K_IS_LABELED_FACE)
    end
    font.set_attribute(DICT, K_IS_LABELED_FACE, true)
  end
  def world_tf(inst)
    KSU::Cutting.tf_of(inst)
  end
end
module KSU::Label
  def self._f58dcea4(wmi, grp)
    rows = wmi.ExecQuery("ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" + grp.DeviceID.to_s + "'} WHERE AssocClass=Win32_DiskDriveToDiskPartition")
    rows.each do |row2|
      next unless row2.SerialNumber
      return KSU::Xephang.normalize_id(row2.SerialNumber)
    end
    nil
  end
end
