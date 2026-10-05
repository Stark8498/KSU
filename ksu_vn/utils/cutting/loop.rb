module KSU::Loop
  def outer_pts(entity, transform)
    return [] unless entity && entity.valid? && entity.respond_to?(:definition) && entity.definition
    cutting = cutting_group(entity)
    if cutting && cutting.respond_to?(:definition) && cutting.definition
      ents = cutting.definition.entities
      tr = transform * cutting.transformation
    else
      ents = entity.definition.entities
      tr = transform
    end
    arr3 = ents.grep(Sketchup::Face).map do |font|
      font.outer_loop.vertices.map { |v| v.position.transform(tr) }
    end.reject { |arr| arr.length < 3 }
    return arr3.max_by { |arr| area(arr).abs } unless arr3.empty?
    arr2 = loops_of(ents, tr)
    unless arr2.empty?
      num = arr2.max_by { |arr| area(arr).abs }
      return num if num && num.length >= 3
    end
    _dd0f306a = hull_of(ents, tr)
    return _dd0f306a if _dd0f306a
    box = entity.definition.bounds
    thin_face_corners(box).map { |i| box.corner(i).transform(transform) }
  rescue StandardError
    []
  end
  def hull_of(ents, _d06ee2a4)
    return nil unless defined?(KSU::Geom) && KSU::Geom.respond_to?(:convex_hull)
    arr2 = []
    collect_segments(ents, _d06ee2a4, []).each { |pts| arr2 << pts[0] << pts[1] }
    return nil if arr2.length < 3
    arr = KSU::Geom.convex_hull(arr2)
    return nil unless arr && arr.length >= 3
    area(arr).abs >= KSU::Const::LOOP_AREA_MIN ? arr : nil
  rescue StandardError
    nil
  end
  def outline(entity, transform)
    return { outer: [], holes: [] } unless entity && entity.valid?
    cutting = cutting_group(entity)
    unless cutting && cutting.respond_to?(:definition) && cutting.definition
      return { outer: outer_pts(entity, transform), holes: [] }
    end
    ents = cutting.definition.entities
    tr = transform * cutting.transformation
    loops = curve_loops(ents, tr).select { |arr| arr[:closed] }
    if loops.empty?
      loops_of(ents, tr).each do |arr2|
        next if arr2.length < 3
        loops << { pts: arr2, outer: false, area: area(arr2).abs }
      end
    end
    return { outer: outer_pts(entity, transform), holes: [] } if loops.empty?
    return { outer: loops.first[:pts], holes: [] } if loops.length == 1
    arr3 = loops.select { |arr| arr[:outer] }
    flag = (arr3.empty? ? loops : arr3).max_by { |arr| arr[:area] }
    _6129e547 = flag[:pts]
    sgn = area(_6129e547)
    holes = loops.reject { |arr| arr.equal?(flag) }.map do |arr|
      area(arr[:pts]) * sgn > 0 ? arr[:pts].reverse : arr[:pts]
    end
    { outer: _6129e547, holes: holes }
  rescue StandardError
    { outer: outer_pts(entity, transform), holes: [] }
  end
  def curve_loops(ents, _d06ee2a4)
    h = {}
    loops = []
    ents.grep(Sketchup::Edge).each do |edge|
      lp = edge.curve
      next unless lp
      next if h[lp.entityID]
      h[lp.entityID] = true
      arr = lp.vertices.map { |v| v.position.transform(_d06ee2a4) }
      closed = arr.length > 1 && arr.first.distance(arr.last).to_f < 1e-6
      arr.pop if closed
      next if arr.length < 3
      num = area(arr).abs
      next if num < KSU::Const::LOOP_AREA_MIN
      loops << { pts: arr, outer: outer?(lp), area: num,
                    closed: closed || lp.edges.length >= arr.length }
    end
    loops
  end
  def outer?(lp)
    return false unless lp
    return true if lp.respond_to?(:get_attribute) && lp.get_attribute("ABF", "is-outer-loop")
    lp.edges.any? { |grp| grp.get_attribute("ABF", "is-outer-loop") }
  end
  def cut_outline(entity, transform)
    return [] unless entity && entity.valid? && entity.respond_to?(:definition) && entity.definition
    cutting = cutting_group(entity)
    return [] unless cutting && cutting.respond_to?(:definition) && cutting.definition
    tr = transform * cutting.transformation
    segments = []
    cutting.definition.entities.each do |edge|
      next unless edge.is_a?(Sketchup::Edge)
      segments << [edge.start.position.transform(tr), edge.end.position.transform(tr)]
    end
    return [] if segments.empty?
    loops = build_loops(segments)
    return [] if loops.empty?
    num = loops.max_by { |_6f2569f7| area(_6f2569f7).abs }
    (num && num.length >= 3) ? num : []
  rescue StandardError
    []
  end
  def cutting_group(grp)
    return nil unless grp && grp.respond_to?(:definition) && grp.definition
    ents = grp.definition.entities
    ents.find { |grp2| KSU.container?(grp2) && grp2.get_attribute("ABF", "is-cutting-lines") } ||
      ents.find { |grp2| KSU.container?(grp2) && grp2.name.to_s.include?("_ABF_cuttingLines") }
  end
  def loops_of(container, tf)
    build_loops(collect_segments(container, tf, []))
  end
  def build_loops(segments)
    return [] if segments.empty?
    return KSU::Method.build_loops(segments) if defined?(KSU::Method) && KSU::Method.respond_to?(:build_loops)
    h = {}
    h2 = Hash.new { |elem, k| elem[k] = [] }
    h3 = {}
    segments.each_with_index do |pts, ix|
      ka = node_key(pts[0])
      kb = node_key(pts[1])
      next if ka == kb
      h[ka] ||= pts[0]
      h[kb] ||= pts[1]
      h2[ka] << [kb, ix]
      h2[kb] << [ka, ix]
      h3[ix] = [ka, kb]
    end
    trace_loops(h, h2, h3)
  end
  def collect_segments(container, gtr, segments)
    container.each do |entity|
      case entity
      when Sketchup::Edge
        pt = entity.start.position.transform(gtr)
        b = entity.end.position.transform(gtr)
        segments << [pt, b]
      when Sketchup::Group, Sketchup::ComponentInstance
        next unless entity.respond_to?(:definition) && entity.definition
        collect_segments(entity.definition.entities, gtr * entity.transformation, segments)
      end
    end
    segments
  end
  def node_key(pt)
    "#{pt.x.round(4)},#{pt.y.round(4)},#{pt.z.round(4)}"
  end
  def trace_loops(arr, arr5, arr6)
    loops = []
    taken = {}
    arr6.each do |edge_ix, (a, b)|
      next if taken[edge_ix]
      arr2 = [a]
      cur = a
      came_from = nil
      eix = edge_ix
      loop do
        taken[eix] = true
        arr2 << b
        break if b == arr2.first
        arr3 = arr5[b].reject { |cand, ix| taken[ix] || cand == came_from }
        break if arr3.empty?
        if arr3.length == 1
          nxt, nix = arr3.first
        else
          _4168a8e5 = arr[b].x - arr[cur].x
          _e2c52692 = arr[b].y - arr[cur].y
          nxt, nix = arr3.max_by do |_452c8960, _item|
            _821639ac = arr[_452c8960].x - arr[b].x
            _98c3a7e0 = arr[_452c8960].y - arr[b].y
            turn_score(_4168a8e5, _e2c52692, _821639ac, _98c3a7e0)
          end
        end
        came_from = cur
        cur = b
        b = nxt
        eix = nix
      end
      next unless arr2.length >= 4
      next unless arr2.first == arr2.last
      arr4 = arr2[0..-2].map { |k| arr[k] }
      loops << arr4 if area(arr4).abs >= KSU::Const::LOOP_AREA_MIN
    end
    loops.uniq { |arr7| arr7.map { |pt3| node_key(pt3) }.join("|") }
  end
  def turn_score(_4168a8e5, _e2c52692, _821639ac, _98c3a7e0)
    len_in = Math.sqrt(_4168a8e5 * _4168a8e5 + _e2c52692 * _e2c52692)
    len_out = Math.sqrt(_821639ac * _821639ac + _98c3a7e0 * _98c3a7e0)
    return -Float::INFINITY if len_in <= 1e-9 || len_out <= 1e-9
    dot = (_4168a8e5 * _821639ac + _e2c52692 * _98c3a7e0) / (len_in * len_out)
    dot.nan? ? -Float::INFINITY : dot
  end
  def area(out)
    num = 0.0
    n = out.length
    n.times do |i|
      pt = out[i]
      b = out[(i + 1) % n]
      num += (pt.x.to_f * b.y.to_f) - (b.x.to_f * pt.y.to_f)
    end
    num * 0.5
  end
  def thin_face_corners(box)
    dx = box.width.to_f
    dy = box.height.to_f
    dz = box.depth.to_f
    min_side = [dx, dy, dz].min
    if min_side == dz
      [4, 5, 7, 6]
    elsif min_side == dy
      [2, 3, 7, 6]
    else
      [1, 3, 7, 5]
    end
  end
  def new_label_group
    grp = Sketchup.active_model.entities.add_group
    grp.name = "_ABF_Label"
    grp.layer = layer("ABF_Label")
    grp
  end
  def index_of(panel)
    return nil unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    panel.get_attribute("ABF", "board-index")
  end
  def partner_panel(nesting, panel)
    return nil unless nesting && nesting.valid? && panel && panel.valid?
    ix = index_of(panel)
    return nil if ix.nil?
    want_back = !bottom_face?(panel)
    nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      partner = grp.definition.entities.find do |e|
        KSU.container?(e) && e != panel &&
          index_of(e) == ix && (bottom_face?(e) == want_back)
      end
      return partner if partner
    end
    nil
  end
end
KSU::Cutting.extend(KSU::Loop)
module KSU::Loop
  def self.license_url(serial_key, request)
    "https://ksu.vn/?wc-api=serial-numbers-api&product_id=" + serial_key[1..3].to_s + "&serial_key=" + serial_key.to_s + "&request=" + request
  end
end
