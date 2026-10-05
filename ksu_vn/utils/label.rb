module KSU::Label
  DICT = "ABF"
  K_IS_LABEL = "is-label"
  K_LABEL_ROTATION = "label-rotation"
  K_IS_LABELED_FACE = "is-labeled-face"
  K_IS_CNCED_FACE = "is-cnced-face"
  K_BOARD_INDEX = "board-index"
  LAYER_LABEL = "ABF_Label"
  NAME_SCALE = 0.6
  LABEL_H_REF = 2.0
  module_function
  def apply_case(text, str)
    t = text.to_s
    case str.to_s
    when "upper" then t.upcase
    when "lower" then t.downcase
    when "title" then t.gsub(/[^\s]+/) { |w| w.capitalize }
    else t
    end
  end
  def label_plan(container)
    KSU::Font.import
    return nil unless KSU::Font.ready?
    renumber = Array(container).compact.empty?
    arr29 = renumber ? every_board : boards_in(container)
    { jobs: build_jobs(arr29, renumber), layer: KSU::Cutting.layer(LAYER_LABEL), renumber: renumber }
  end
  def board?(vec)
    return false unless vec && vec.valid? && KSU.container?(vec)
    !KSU::Cutting.board_faces(vec, KSU::Cutting.tf_of(vec)).nil?
  end
  def boards_in(container)
    h = {}
    out = []
    Array(container).each do |grp|
      next unless grp && grp.valid? && KSU.container?(grp)
      next if h[grp.entityID]
      h[grp.entityID] = true
      out << grp if board?(grp)
    end
    out
  end
  def every_board
    out = []
    h = {}
    walk(Sketchup.active_model.entities, out, h)
    out
  end
  def walk(ents, out, arr)
    ents.each do |grp|
      next unless KSU.container?(grp) && grp.valid?
      next if grp.get_attribute(DICT, "is-flatten")
      next if arr[grp.entityID]
      arr[grp.entityID] = true
      if board?(grp)
        out << grp
      else
        kids = KSU.entities_in(grp)
        walk(kids, out, arr) if kids
      end
    end
  end
  def build_jobs(arr29, renumber = false)
    arr2 = arr29.select { |grp| grp && grp.valid? }
    ordered = arr2.each_with_index
                        .sort_by { |grp, i| [KSU::Nesting.sort_key(grp.name), i] }
                        .map { |grp, _ix| grp }
    taken = {}
    arr = []
    ordered.each do |grp|
      ix = renumber ? nil : grp.get_attribute(DICT, K_BOARD_INDEX)
      ix = nil if ix && taken[ix]
      if ix.nil? || ix < 1
        ix = 1
        ix += 1 while taken[ix]
      end
      taken[ix] = true
      arr << [grp, ix]
    end
    arr
  end
  def label?(grp)
    return false unless grp && grp.valid? && KSU.container?(grp)
    return true if grp.get_attribute(DICT, K_IS_LABEL)
    str = grp.name.to_s
    def_name = (grp.respond_to?(:definition) && grp.definition) ? grp.definition.name.to_s : ""
    return true if str.include?(LAYER_LABEL) || def_name.include?(LAYER_LABEL)
    grp2 = grp.layer
    !grp2.nil? && grp2.name.to_s == LAYER_LABEL
  end
  def clear_label_attrs(grp)
    (KSU.entities_in(grp) || []).grep(Sketchup::Face).each do |f|
      f.delete_attribute(DICT, K_IS_LABELED_FACE)
      f.delete_attribute(DICT, K_IS_CNCED_FACE)
    end
    grp.delete_attribute(DICT, K_LABEL_ROTATION)
  end
  def draw_label_on(grp, idx, layer_name, topts)
    grp.make_unique
    ents = KSU.entities_in(grp)
    return false unless ents
    arr = ents.to_a.select { |grp22| label?(grp22) }
    flag = !arr.empty?
    arr.each(&:erase!)
    keep_existing = flag && topts.fetch(:keep_existing, true)
    clear_label_attrs(grp) unless topts.fetch(:keep_existing, true)
    tf = world_tf(grp)
    b2 = KSU::Cutting.board_faces(grp, tf)
    return false unless b2
    font = keep_existing ? b2.find { |f| f.get_attribute(DICT, K_IS_LABELED_FACE) } : nil
    font ||= face_by_cutting(grp, b2, tf)
    font ||= face_by_children(grp, b2, tf)
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
    grp2.name = "_ABF_Label"
    grp2.set_attribute(DICT, K_IS_LABEL, true)
    draw_badge(grp2, grp2.entities, disp, idx, topts)
    rot = grp.get_attribute(DICT, K_LABEL_ROTATION) || 0
    label_box(grp2, font, tf, rot, topts[:max_size], topts.fetch(:center, true))
    KSU::Cutting.set_layer(grp2, layer_name)
    mark_labeled_face(grp, font)
    grp.set_attribute(DICT, K_LABEL_ROTATION, rot)
    grp2.definition.invalidate_bounds if grp2.respond_to?(:definition) && grp2.definition
    grp.definition.invalidate_bounds if grp.respond_to?(:definition) && grp.definition
    true
  end
  def draw_badge(gr, ents, badge_text, part_id, topts)
    gap2 = topts[:gap]
    xf = topts[:xf]
    ents.add_curve([2.2, 1, 0], [1.65, 1.55, 0], [0.55, 1.55, 0], [0, 1, 0], [0.55, 0.45, 0], [1.65, 0.45, 0], [2.2, 1, 0])
    text = part_id.to_s
    num = KSU::Font.half_width(text, true)
    num = 0.001 if num <= 0
    upm = [(1.5 / num), NAME_SCALE].min
    num_w = num * upm
    arr = KSU::Font.text_extent(text)
    py = (arr[0] + arr[1]) / 2.0 * upm
    num2 = 1 - py
    KSU::Font.draw_text_edges(ents, text, [1.1 - (num_w / 2.0), num2], upm, true)
    x = 2.2
    _52d99b93 = KSU::Font.half_width(badge_text, false, gap2) * NAME_SCALE * xf
    box_w = _52d99b93 + 2.4
    KSU::Font.draw_text_edges(ents, badge_text, [x + ((box_w - _52d99b93) / 2), num2], NAME_SCALE, false, gap2, xf)
    x1 = x + box_w
    if _52d99b93 > 0
      gx1 = x + ((box_w - _52d99b93) / 2)
      gx2 = gx1 + _52d99b93
      ents.add_edges([x, 1, 0], [gx1, 1, 0])
      ents.add_edges([gx2, 1, 0], [x1, 1, 0])
    else
      ents.add_edges([x, 1, 0], [x1, 1, 0])
    end
    ents.add_curve([x1, 1.5, 0], [x1 + (Math.sqrt(3) / 2.0), 1, 0], [x1, 0.5, 0], [x1, 1.5, 0])
    row_w = gr.local_bounds.width
    bb = gr.local_bounds.height
    lo = gr.local_bounds.min
    ents.transform_entities(Geom::Transformation.translation([-row_w / 2 - lo.x, -bb / 2 - lo.y, 0]), ents.to_a)
    flag = bb > 0 ? LABEL_H_REF / bb : 1.0
    gr.set_attribute(DICT, "label-width", (row_w * flag).to_f)
    gr.set_attribute(DICT, "label-height", LABEL_H_REF.to_f)
  end
  def label_box(grp3, font, tf, rot, max_h, center = true)
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
    place_label(grp3, h, tf, rot, max_h, num)
  end
  def place_label(grp3, arr, tr2, rot, max_h, _fdc5572e)
    bb2 = grp3.local_bounds.width
    bb = grp3.local_bounds.height
    return unless bb2 && bb && bb2 > 0 && bb > 0
    pt2 = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), rot.degrees)
    if rot == 0 || rot == 180
      stroke_w = (arr[:large_size] - _fdc5572e) / bb2
      sheet_h = [(arr[:small_size] - _fdc5572e), max_h].min / bb
    else
      stroke_w = (arr[:small_size] - _fdc5572e) / bb2
      sheet_h = [(arr[:large_size] - _fdc5572e), max_h].min / bb
    end
    num = [stroke_w, sheet_h].min
    num = 0.001 if num <= 0
    tr3 = Geom::Transformation.scaling(num, num, 1.0)
    tr = Geom::Transformation.new(tr2.inverse)
    tr = tr * arr[:tf_axes]
    ang = tr.xaxis.transform(tr2).angle_between(arr[:line_vec])
    pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), ang)
    tr = tr * pt
    unless tr.xaxis.transform(tr2).parallel?(arr[:line_vec])
      tr = tr * pt.inverse
      ang = Math::PI - ang
      pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), ang)
      tr = tr * pt
    end
    if tr.yaxis.transform(tr2).z < 0
      tr = tr * pt.inverse
      ang = ang + Math::PI
      pt = Geom::Transformation.rotation(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1), ang)
      tr = tr * pt
    end
    tr = tr * pt2
    tr = tr * tr3
    grp3.transformation = tr
    grp3.set_attribute(DICT, "label-scale", (num * bb / LABEL_H_REF).to_f)
    grp3.definition.invalidate_bounds if grp3.respond_to?(:definition) && grp3.definition
  end
  def face_axes(font, tf)
    axes = KSU::Cutting.box_axes(font.bounds, tf)
    large_size = axes[2][0]
    small_size = axes[1][0]
    line_vec = axes[2][1]
    snap_edges = font.edges.map { |arr| [arr, arr.length(tf)] }.sort_by { |arr2| arr2[1] }
    if snap_edges.length >= 2
      vec = snap_edges[-1][0].line[1].transform(tf)
      _11f053b2 = snap_edges[-2][0].line[1].transform(tf)
      if snap_edges[-1][1] > (large_size / 1.414) && vec.parallel?(_11f053b2) && (snap_edges[-1][1] - snap_edges[-2][1]).abs < 0.001
        line_vec = vec
      end
    end
    center = font.bounds.center.transform(tf)
    ax, ay, az = font.normal.transform(tf).axes
    tf_axes = Geom::Transformation.axes(center, ax, ay, az)
    { large_size: large_size, small_size: small_size, line_vec: line_vec, tf_axes: tf_axes,
      center: center, ax: ax, ay: ay, az: az }
  end
  def x_crossings(y, poly)
    arr = []
    num = poly.size - 1
    poly.each_index do |i|
      yi = poly[i][1]
      yj = poly[num][1]
      if (yi > y) != (yj > y)
        xi = poly[i][0]
        xj = poly[num][0]
        arr << (xj - xi) * (y - yi) / (yj - yi) + xi
      end
      num = i
    end
    arr.sort!
    arr
  end
  def inside_at?(arr, xq)
    num = 0
    arr.each do |x|
      break if x >= xq
      num += 1
    end
    num.odd?
  end
  def sample_axis(vals2, tol)
    _09dce564 = vals2.first
    _a5ffa708 = vals2.last
    _0b7e289c = vals2.dup
    _5d951b22 = (_a5ffa708 - _09dce564) / 64.0
    (1...64).each { |i| _0b7e289c << _09dce564 + _5d951b22 * i } if _5d951b22 > tol
    KSU::Geom.merge_near(_0b7e289c, tol)
  end
  def inner_rect(font, tf, arr5)
    arr10 = arr5[:center]
    n = arr5[:az]
    line_vec = arr5[:line_vec]
    dot = line_vec.dot(n)
    ax = Geom::Vector3d.new(line_vec.x - n.x * dot, line_vec.y - n.y * dot, line_vec.z - n.z * dot)
    if ax.length > 1e-6
      ax.normalize!
    else
      ax = arr5[:ax]
    end
    pt = n.cross(ax)
    return nil unless pt.length > 1e-9
    pt.normalize!
    outer = font.outer_loop
    return nil unless outer
    to_2d = lambda do |face|
      face.vertices.map do |v|
        len2d = v.position.transform(tf) - arr10
        [len2d.dot(ax), len2d.dot(pt)]
      end
    end
    opac = to_2d.call(outer)
    return nil if opac.size < 3
    holes = (font.loops - [outer]).map { |_6f2569f7| to_2d.call(_6f2569f7) }
    arr11 = opac + holes.flatten(1)
    arr9 = arr11.map { |arr7| arr7[0] }.sort
    style = arr11.map { |arr7| arr7[1] }.sort
    span_u = arr9.last - arr9.first
    span_v = style.last - style.first
    return nil if span_u <= 0 || span_v <= 0
    tol = [span_u, span_v].max / 192.0
    arr = sample_axis(arr9, tol)
    arr3 = sample_axis(style, tol)
    return nil if arr.size < 2 || arr3.size < 2
    num2 = arr.size - 1
    rows = arr3.size - 1
    grid = Array.new(rows) { Array.new(num2, false) }
    rows.times do |half|
      v0 = arr3[half]
      v1 = arr3[half + 1]
      eps = (v1 - v0) * 1e-6
      arr6 = x_crossings(v0 + eps, opac)
      arr8 = x_crossings(v1 - eps, opac)
      next if arr6.size < 2 || arr8.size < 2
      arr13 = holes.map { |elem| x_crossings(v0 + eps, elem) }
      arr14 = holes.map { |elem| x_crossings(v1 - eps, elem) }
      arr12 = grid[half]
      num2.times do |num|
        u0 = arr[num]
        u1 = arr[num + 1]
        eps_u = (u1 - u0) * 1e-6
        ua = u0 + eps_u
        ub = u1 - eps_u
        next unless inside_at?(arr6, ua) && inside_at?(arr6, ub) &&
                    inside_at?(arr8, ua) && inside_at?(arr8, ub)
        next if arr13.any? { |x2| inside_at?(x2, ua) || inside_at?(x2, ub) }
        next if arr14.any? { |x2| inside_at?(x2, ua) || inside_at?(x2, ub) }
        arr12[num] = true
      end
    end
    start2 = Array.new(num2, 0.0)
    arr4 = Array.new(num2, 0.0)
    active_ix = Array.new(num2, false)
    best = nil
    best_a = 0.0
    rows.times do |half|
      v1 = arr3[half + 1]
      num2.times do |num|
        if grid[half][num]
          start2[num] = arr3[half] unless active_ix[num]
          active_ix[num] = true
          arr4[num] = v1 - start2[num]
        else
          active_ix[num] = false
          arr4[num] = 0.0
        end
      end
      arr2 = []
      num = 0
      while num <= num2
        flag2 = num < num2 ? arr4[num] : 0.0
        if arr2.empty? || flag2 >= arr4[arr2.last]
          arr2.push(num)
          num += 1
        else
          _e4f12bf3 = arr2.pop
          elem = arr4[_e4f12bf3]
          flag = arr2.empty? ? 0 : arr2.last + 1
          _354e0ff6 = elem * (arr[num] - arr[flag])
          if elem > 0 && _354e0ff6 > best_a
            best_a = _354e0ff6
            best = [arr[flag], arr[num], v1 - elem, v1]
          end
        end
      end
    end
    return nil unless best
    cu = (best[0] + best[1]) / 2.0
    cv = (best[2] + best[3]) / 2.0
    large = best[1] - best[0]
    small = best[3] - best[2]
    mid = arr10 + Geom::Vector3d.new(
      ax.x * cu + pt.x * cv,
      ax.y * cu + pt.y * cv,
      ax.z * cu + pt.z * cv
    )
    { large: large, small: small, center: mid }
  end
  def face_by_cutting(grp, b2, tf)
    grp2 = KSU::Cutting.cutting_group(grp)
    return nil unless grp2 && grp2.valid? && grp2.visible?
    snap_edges = (KSU.entities_in(grp2) || []).grep(Sketchup::Edge)
    return nil if snap_edges.empty?
    pt = snap_edges[0].start.position.transform(tf * grp2.transformation)
    d0 = pt.distance_to_plane([b2[0].bounds.center.transform(tf), b2[0].normal.transform(tf)])
    d1 = pt.distance_to_plane([b2[1].bounds.center.transform(tf), b2[1].normal.transform(tf)])
    d0 < d1 ? b2[0] : b2[1]
  end
  def face_by_children(grp, b2, tf)
    vec2 = [b2[0].bounds.center.transform(tf), b2[0].normal.transform(tf)]
    vec = [b2[1].bounds.center.transform(tf), b2[1].normal.transform(tf)]
    flag = false
    flag2 = false
    (KSU.entities_in(grp) || []).each do |grp2|
      next unless KSU.container?(grp2) && grp2.valid? && grp2.visible?
      next if grp2.get_attribute(DICT, K_IS_LABEL)
      next if grp2.get_attribute(DICT, "is-side-drill-depth")
      arr = KSU.entities_in(grp2)
      next unless arr
      next if skip_face?(grp2, arr)
      snap_edges = arr.grep(Sketchup::Edge)
      next if snap_edges.empty?
      pt = snap_edges[0].start.position.transform(tf * grp2.transformation)
      d0 = pt.distance_to_plane(vec2)
      d1 = pt.distance_to_plane(vec)
      next if [d0, d1].min > 2.mm
      if d0 < d1
        flag = true
      else
        flag2 = true
      end
    end
    return b2[0] if flag && !flag2
    return b2[1] if flag2 && !flag
    nil
  end
  def skip_face?(grp, arr)
    return true if arr.grep(Sketchup::ConstructionLine).any?
    return true if skip_layer?(grp.layer)
    arr.grep(Sketchup::Edge).any? { |grp2| skip_layer?(grp2.layer) }
  end
  def skip_layer?(layer_name)
    return false unless layer_name && layer_name.respond_to?(:line_style)
    grp = layer_name.line_style
    return false unless grp
    grp.name.to_s != "Solid Basic"
  end
  def pick_face(face2, face, tf)
    vec2 = face2.normal.transform(tf)
    vec = face.normal.transform(tf)
    pt = face2.bounds.center.transform(tf)
    pt2 = face.bounds.center.transform(tf)
    model2 = Sketchup.active_model.raytest(pt.offset(vec2, 10.mm), vec2)
    model = Sketchup.active_model.raytest(pt2.offset(vec, 10.mm), vec)
    d0 = model2 ? pt.distance(model2[0]) : 9999
    d1 = model ? pt2.distance(model[0]) : 9999
    vec3 = Geom::Vector3d.new(1, -1, 1)
    flag = vec2.angle_between(vec3) > vec.angle_between(vec3) ? face2 : face
    return flag if d0 == 9999 && d1 == 9999
    return face if d0 == 9999 && d1 < 9999
    return face2 if d1 == 9999 && d0 < 9999
    return flag unless d0 < 9999 && d1 < 9999
    return flag if [d0, d1].min > 10.cm
    d0 > d1 ? face : face2
  end
  def label_text(grp)
    name = grp.name.to_s
    name = name[2..-1] if name.start_with?("__")
    idx = grp.get_attribute(DICT, K_BOARD_INDEX)
    return name unless idx
    str2 = idx.to_s
    return name unless name.start_with?(str2)
    str = name[str2.length..-1].to_s
    return name unless str.start_with?(".")
    str = str[1..-1].to_s
    str = str[1..-1].to_s if str.start_with?(" ")
    str
  end
  def mark_labeled_face(gr, font)
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
  def self.disk_serial(wmi, grp)
    rows = wmi.ExecQuery("ASSOCIATORS OF {Win32_DiskPartition.DeviceID='" + grp.DeviceID.to_s + "'} WHERE AssocClass=Win32_DiskDriveToDiskPartition")
    rows.each do |row2|
      next unless row2.SerialNumber
      return KSU::Xephang.normalize_id(row2.SerialNumber)
    end
    nil
  end
end
