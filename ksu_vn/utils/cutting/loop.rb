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
    unless arr3.empty?
      num = arr3.max_by { |arr| area(arr).abs }
      return num if num && num.length >= 3
    end
    arr2 = loops_of(ents, tr)
    unless arr2.empty?
      num = arr2.max_by { |arr| area(arr).abs }
      return num if num && num.length >= 3
    end
    hull = hull_of(ents, tr)
    return hull if hull
    box = entity.definition.bounds
    thin_face_corners(box).map { |i| box.corner(i).transform(transform) }
  rescue StandardError
    []
  end
  def hull_of(ents, tf)
    return nil unless defined?(KSU::Geom) && KSU::Geom.respond_to?(:convex_hull)
    pts = []
    collect_segments(ents, tf, []).each { |poly| pts << poly[0] << poly[1] }
    return nil if pts.length < 3
    arr = KSU::Geom.convex_hull(pts)
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
      loops_of(ents, tr).each do |pts|
        next if pts.length < 3
        loops << { pts: pts, outer: false, area: area(pts).abs }
      end
    end
    return { outer: outer_pts(entity, transform), holes: [] } if loops.empty?
    return { outer: loops.first[:pts], holes: [] } if loops.length == 1
    arr3 = loops.select { |arr| arr[:outer] }
    flag = (arr3.empty? ? loops : arr3).max_by { |arr| arr[:area] }
    outer = flag[:pts]
    sgn = area(outer)
    holes = loops.reject { |arr| arr.equal?(flag) }.map do |arr|
      area(arr[:pts]) * sgn > 0 ? arr[:pts].reverse : arr[:pts]
    end
    { outer: outer, holes: holes }
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
    tr = transform * cutting.transformation
    segments = []
    cutting.definition.entities.each do |ent|
      next unless ent.is_a?(Sketchup::Edge)
      segments << [ent.start.position.transform(tr), ent.end.position.transform(tr)]
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
    nesting.definition.entities.each do |sheet|
      next unless KSU::Sheet.sheet?(sheet)
      sheet.definition.entities.each do |panel|
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
  def unhide(arr)
    return unless arr
    arr.each { |ent| ent.hidden = false if ent && ent.valid? && ent.respond_to?(:hidden?) && ent.hidden? }
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
    h21 = {}
    h2 = Hash.new { |h, k| h[k] = [] }
    h3 = {}
    segments.each_with_index do |poly, ix|
      ka = node_key(poly[0])
      kb = node_key(poly[1])
      next if ka == kb
      h21[ka] ||= poly[0]
      h21[kb] ||= poly[1]
      h2[ka] << [kb, ix]
      h2[kb] << [ka, ix]
      h3[ix] = [ka, kb]
    end
    trace_loops(h21, h2, h3)
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
  def node_key(pt)
    "#{pt.x.round(4)},#{pt.y.round(4)},#{pt.z.round(4)}"
  end
  def trace_loops(arr, arr7, arr8)
    loops = []
    h = {}
    arr8.each do |edge_ix, (a, b)|
      next if h[edge_ix]
      arr2 = [a]
      cur = a
      came_from = nil
      eix = edge_ix
      loop do
        h[eix] = true
        arr2 << b
        break if b == arr2.first
        arr3 = arr7[b].reject { |cand, ix| h[ix] || cand == came_from }
        break if arr3.empty?
        if arr3.length == 1
          nxt, nix = arr3.first
        else
          ix2 = arr[b].x - arr[cur].x
          dy_in = arr[b].y - arr[cur].y
          nxt, nix = arr3.max_by do |kx, _part|
            dx_out = arr[kx].x - arr[b].x
            dy_out = arr[kx].y - arr[b].y
            turn_score(ix2, dy_in, dx_out, dy_out)
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
    loops.uniq { |arr6| arr6.map { |_23505ef9| node_key(_23505ef9) }.join("|") }
  end
  def turn_score(ix, dy_in, dx_out, dy_out)
    len_in = Math.sqrt(ix * ix + dy_in * dy_in)
    len_out = Math.sqrt(dx_out * dx_out + dy_out * dy_out)
    return -Float::INFINITY if len_in <= 1e-9 || len_out <= 1e-9
    dot = (ix * dx_out + dy_in * dy_out) / (len_in * len_out)
    dot.nan? ? -Float::INFINITY : dot
  end
  def area(out)
    num = 0.0
    n = out.length
    n.times do |i|
      pt2 = out[i]
      b = out[(i + 1) % n]
      num += (pt2.x.to_f * b.y.to_f) - (b.x.to_f * pt2.y.to_f)
    end
    num * 0.5
  end
  def thin_face_corners(box)
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
  def new_label_group
    node = Sketchup.active_model.entities.add_group
    node.name = "_ABF_Label"
    tag = layer("ABF_Label")
    node.layer = tag if tag
    node
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
    nesting.definition.entities.each do |sheet|
      next unless KSU::Sheet.sheet?(sheet)
      partner = sheet.definition.entities.find do |ent|
        KSU.container?(ent) && ent != panel &&
          index_of(ent) == ix && (bottom_face?(ent) == want_back)
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
