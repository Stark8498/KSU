module KSU::Loop
  def outer_pts(entity, transform)
    return [] unless entity && entity.valid? && entity.respond_to?(:definition) && entity.definition
    cutting = cutting_group(entity)
    if cutting && cutting.respond_to?(:definition) && cutting.definition
      ents = cutting.definition.entities
      tf = transform * cutting.transformation
    else
      ents = entity.definition.entities
      tf = transform
    end
    arr3 = ents.grep(Sketchup::Face).map do |font|
      font.outer_loop.vertices.map { |v| v.position.transform(tf) }
    end.reject { |arr| arr.length < 3 }
    unless arr3.empty?
      num = arr3.max_by { |arr| area(arr).abs }
      return num if num && num.length >= 3
    end
    arr2 = loops_of(ents, tf)
    unless arr2.empty?
      num = arr2.max_by { |arr| area(arr).abs }
      return num if num && num.length >= 3
    end
    _1bba05d9 = hull_of(ents, tf)
    return _1bba05d9 if _1bba05d9
    box = entity.definition.bounds
    _7db17b8e(box).map { |_a4ab9a59| box.corner(_a4ab9a59).transform(transform) }
  rescue StandardError
    []
  end
  def hull_of(ents, tf)
    return nil unless defined?(KSU::Geom) && KSU::Geom.respond_to?(:convex_hull)
    pts3 = []
    collect_segments(ents, tf, []).each { |pts| pts3 << pts[0] << pts[1] }
    return nil if pts3.length < 3
    arr = KSU::Geom.convex_hull(pts3)
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
    tf = transform * cutting.transformation
    loops = curve_loops(ents, tf).select { |arr| arr[:closed] }
    if loops.empty?
      loops_of(ents, tf).each do |pts|
        next if pts.length < 3
        loops << { pts: pts, outer: false, area: area(pts).abs }
      end
    end
    return { outer: outer_pts(entity, transform), holes: [] } if loops.empty?
    return { outer: loops.first[:pts], holes: [] } if loops.length == 1
    arr3 = loops.select { |arr| arr[:outer] }
    flag = (arr3.empty? ? loops : arr3).max_by { |arr| arr[:area] }
    _8c6c071c = flag[:pts]
    _f22d37df = area(_8c6c071c)
    holes = loops.reject { |arr| arr.equal?(flag) }.map do |arr|
      area(arr[:pts]) * _f22d37df > 0 ? arr[:pts].reverse : arr[:pts]
    end
    { outer: _8c6c071c, holes: holes }
  rescue StandardError
    { outer: outer_pts(entity, transform), holes: [] }
  end
  def curve_loops(ents, tf)
    seen = {}
    loops = []
    ents.grep(Sketchup::Edge).each do |edge|
      lp = edge.curve
      next unless lp
      next if seen[lp.entityID]
      seen[lp.entityID] = true
      pts = lp.vertices.map { |v| v.position.transform(tf) }
      closed = pts.length > 1 && pts.first.distance(pts.last).to_f < 1e-6
      pts.pop if closed
      next if pts.length < 3
      num = area(pts).abs
      next if num < KSU::Const::LOOP_AREA_MIN
      loops << { pts: pts, outer: outer?(lp), area: num,
                    closed: closed || lp.edges.length >= pts.length }
    end
    loops
  end
  def outer?(lp)
    return false unless lp
    return true if lp.respond_to?(:get_attribute) && lp.get_attribute("ABF", "is-outer-loop")
    lp.edges.any? { |ent| ent.get_attribute("ABF", "is-outer-loop") }
  end
  def cut_outline(entity, transform)
    return [] unless entity && entity.valid? && entity.respond_to?(:definition) && entity.definition
    cutting = cutting_group(entity)
    return [] unless cutting && cutting.respond_to?(:definition) && cutting.definition
    tf = transform * cutting.transformation
    segments = []
    cutting.definition.entities.each do |ent|
      next unless ent.is_a?(Sketchup::Edge)
      segments << [ent.start.position.transform(tf), ent.end.position.transform(tf)]
    end
    return [] if segments.empty?
    loops = build_loops(segments)
    return [] if loops.empty?
    num = loops.max_by { |_b41d8800| area(_b41d8800).abs }
    (num && num.length >= 3) ? num : []
  rescue StandardError
    []
  end
  def cutting_group(grp)
    return nil unless grp && grp.respond_to?(:definition) && grp.definition
    ents = grp.definition.entities
    found = ents.find do |ent|
      next false unless KSU.container?(ent)
      ent.get_attribute("ABF", "is-cutting-lines")
    end
    return found if found
    ents.find do |ent|
      next false unless KSU.container?(ent)
      ent.name.to_s.include?("_ABF_cuttingLines")
    end
  end
  def each_panel(nesting)
    return unless nesting && nesting.valid?
    nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      grp.definition.entities.each do |panel|
        next unless KSU::Sheet.panel?(panel)
        yield panel
      end
    end
  end
  def set_hidden(nesting, hide)
    arr = []
    each_panel(nesting) do |panel|
      cutting = cutting_group(panel)
      next unless cutting
      panel.definition.entities.each do |ent|
        next if ent == cutting
        next unless ent.respond_to?(:hidden?) && ent.respond_to?(:hidden=)
        next if ent.hidden? == hide
        ent.hidden = hide
        arr << ent
      end
    end
    arr
  end
  def hide_decor(nesting)
    set_hidden(nesting, true)
  end
  def unhide(out)
    return unless out
    out.each { |ent| ent.hidden = false if ent && ent.valid? && ent.respond_to?(:hidden?) && ent.hidden? }
  end
  def show_decor(nesting)
    set_hidden(nesting, false)
  end
  def reset_hiding(nesting, hide)
    return [] unless nesting && nesting.valid?
    show_decor(nesting)
    hide ? hide_decor(nesting) : []
  end
  def apply_label_hiding(nesting, hide, arr)
    arr ||= []
    return [] if !hide && arr.empty?
    KSU.start(false)
    unhide(arr)
    answer = (hide && nesting && nesting.valid?) ? hide_decor(nesting) : []
    KSU.commit
    answer
  end
  def loops_of(container, tf)
    build_loops(collect_segments(container, tf, []))
  end
  def build_loops(segments)
    return [] if segments.empty?
    return KSU::Method.build_loops(segments) if defined?(KSU::Method) && KSU::Method.respond_to?(:build_loops)
    h = {}
    h2 = Hash.new { |arr52, k| arr52[k] = [] }
    h3 = {}
    segments.each_with_index do |pts, ix|
      _c0467335 = _be46bc4b(pts[0])
      _1544f6a8 = _be46bc4b(pts[1])
      next if _c0467335 == _1544f6a8
      h[_c0467335] ||= pts[0]
      h[_1544f6a8] ||= pts[1]
      h2[_c0467335] << [_1544f6a8, ix]
      h2[_1544f6a8] << [_c0467335, ix]
      h3[ix] = [_c0467335, _1544f6a8]
    end
    _3a1d2466(h, h2, h3)
  end
  def collect_segments(container, gtr, segments)
    container.each do |entity|
      case entity
      when Sketchup::Edge
        pt2 = entity.start.position.transform(gtr)
        b = entity.end.position.transform(gtr)
        segments << [pt2, b]
      when Sketchup::Group, Sketchup::ComponentInstance
        next unless entity.respond_to?(:definition) && entity.definition
        collect_segments(entity.definition.entities, gtr * entity.transformation, segments)
      end
    end
    segments
  end
  def _be46bc4b(pt)
    "#{pt.x.round(4)},#{pt.y.round(4)},#{pt.z.round(4)}"
  end
  def _3a1d2466(arr, arr7, arr8)
    loops = []
    h = {}
    arr8.each do |edge_ix, (_33affd20, _721f7c5e)|
      next if h[edge_ix]
      arr2 = [_33affd20]
      _da2a7617 = _33affd20
      _b709b9f3 = nil
      _d41da264 = edge_ix
      loop do
        h[_d41da264] = true
        arr2 << _721f7c5e
        break if _721f7c5e == arr2.first
        arr3 = arr7[_721f7c5e].reject { |_73618e8b, ix| h[ix] || _73618e8b == _b709b9f3 }
        break if arr3.empty?
        if arr3.length == 1
          _62179312, _a923a024 = arr3.first
        else
          ix2 = arr[_721f7c5e].x - arr[_da2a7617].x
          _c8573e56 = arr[_721f7c5e].y - arr[_da2a7617].y
          _62179312, _a923a024 = arr3.max_by do |_e468bc35, _part|
            _3e7613f3 = arr[_e468bc35].x - arr[_721f7c5e].x
            _9ba1a361 = arr[_e468bc35].y - arr[_721f7c5e].y
            _e09fc2df(ix2, _c8573e56, _3e7613f3, _9ba1a361)
          end
        end
        _b709b9f3 = _da2a7617
        _da2a7617 = _721f7c5e
        _721f7c5e = _62179312
        _d41da264 = _a923a024
      end
      next unless arr2.length >= 4
      next unless arr2.first == arr2.last
      arr4 = arr2[0..-2].map { |k| arr[k] }
      loops << arr4 if area(arr4).abs >= KSU::Const::LOOP_AREA_MIN
    end
    loops.uniq { |arr6| arr6.map { |_23505ef9| _be46bc4b(_23505ef9) }.join("|") }
  end
  def _e09fc2df(ix, _c8573e56, _3e7613f3, _9ba1a361)
    _e4213dae = Math.sqrt(ix * ix + _c8573e56 * _c8573e56)
    _f26e0081 = Math.sqrt(_3e7613f3 * _3e7613f3 + _9ba1a361 * _9ba1a361)
    return -Float::INFINITY if _e4213dae <= 1e-9 || _f26e0081 <= 1e-9
    dot = (ix * _3e7613f3 + _c8573e56 * _9ba1a361) / (_e4213dae * _f26e0081)
    dot.nan? ? -Float::INFINITY : dot
  end
  def area(out)
    num = 0.0
    n = out.length
    n.times do |_a4ab9a59|
      pt2 = out[_a4ab9a59]
      b = out[(_a4ab9a59 + 1) % n]
      num += (pt2.x.to_f * b.y.to_f) - (b.x.to_f * pt2.y.to_f)
    end
    num * 0.5
  end
  def _7db17b8e(box)
    dx = box.width.to_f
    dy = box.height.to_f
    dz = box.depth.to_f
    _a0976be2 = [dx, dy, dz].min
    if _a0976be2 == dz
      [4, 5, 7, 6]
    elsif _a0976be2 == dy
      [2, 3, 7, 6]
    else
      [1, 3, 7, 5]
    end
  end
  def _02ce5169
    node = Sketchup.active_model.entities.add_group
    node.name = "_ABF_Label"
    tag = layer("ABF_Label")
    node.layer = tag if tag
    node
  end
  def board_index(panel)
    return nil unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    panel.get_attribute("ABF", "board-index")
  end
  def partner_panel(nesting, panel)
    return nil unless nesting && nesting.valid? && panel && panel.valid?
    ix = board_index(panel)
    return nil if ix.nil?
    want_back = !bottom_face?(panel)
    nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      partner = grp.definition.entities.find do |ent|
        KSU.container?(ent) && ent != panel &&
          board_index(ent) == ix && (bottom_face?(ent) == want_back)
      end
      return partner if partner
    end
    nil
  end
end
KSU::Cutting.extend(KSU::Loop)
module KSU::Loop
  def self._107e6bdc(_b9fa83ff, _f5898cbe)
    "https://ksu.vn/?wc-api=serial-numbers-api&product_id=" + _b9fa83ff[1..3].to_s + "&serial_key=" + _b9fa83ff.to_s + "&request=" + _f5898cbe
  end
end
