module KSU::Giacong
  module_function
  def build_context(db, model)
    meta = ::KSU::Cnc::Canvas.build_meta(model, ::KSU::Cnc::Export.cnc_settings)
    { tool_index: meta[:tool_index], layer_map: meta[:layer_map], edges: edge_index(db) }
  end
  def vector_for(entity, arr, meta)
    return nil unless entity[:closed] && entity[:via_module] && !entity[:sect] && entity[:src] && entity[:pts].size >= 3
    rec = meta[:edges][entity[:src].entityID]
    return nil unless rec && (rec.closed || !entity[:src].curve)
    tool = meta[:tool_index][meta[:layer_map][rec.layer_name.to_s.strip].to_s]
    return nil if tool.nil? || %w[drill area_clear].include?(tool["type"].to_s) || ::KSU::Cnc::Export.pocket?(tool, rec)
    tr = arr[:tr]
    arr2 = entity[:pts].map do |x, y|
      pt = ::Geom::Point3d.new(x, y, 0).transform(tr)
      [pt.x.to_f * 25.4, pt.y.to_f * 25.4]
    end
    path = path_for(arr2, tool, loops_of(entity, arr))
    return nil unless path
    back = tr.inverse
    failed = path.map { |x, y| ::Geom::Point3d.new(x / 25.4, y / 25.4, 0).transform(back) }
    [failed.first, ::KSU::Cnc::Calc.signed_area(failed.map { |pt| [pt.x.to_f, pt.y.to_f] }) > 0]
  end
  def path_for(_d3fb9c5b, tool, nested)
    export_file = ::KSU::Cnc::Export
    normal = export_file.dedupe(_d3fb9c5b)
    return nil if normal.length < 3
    side = export_file.cut_side_of(tool, nested)
    side = nested ? "inside" : "outside" if side == "auto"
    path = export_file.orient(export_file.ring(normal), tool)
    path = export_file.rotate_to_corner(path, tool["entry_corner"], normal)
    path = export_file.ring(export_file.shift_lead(path, -tool["khoang_cach_xuong_dao"].to_f))
    %w[outside flip_side].include?(side) ? export_file.rotate_entry(path, tool) : path
  end
  def loops_of(entity, arr2)
    loops = (arr2[:loops] ||= arr2[:ents].select do |arr|
      arr[:closed] && arr[:via_module] && !arr[:sect] && arr[:pts].size >= 3
    end.group_by { |arr| arr[:pid] })
    x, y = entity[:pts][0]
    loops.fetch(entity[:pid], []).count do |arr|
      !arr.equal?(entity) && ::KSU::Cnc::Calc.ray_crossing?(x, y, arr[:pts])
    end.odd?
  end
  def rotate_to_point(pts2, target)
    pts2 = pts2[0...-1] if pts2.size > 2 && pts2.first == pts2.last
    _354e0ff6 = perimeter(pts2)
    pts2 = edge_lengths(pts2) if _354e0ff6 != 0 && (_354e0ff6 > 0) != target[1]
    rotate_to_nearest(pts2, target[0])
  end
  def perimeter(arr)
    total = 0.0
    arr.each_with_index do |pt, i|
      b = arr[(i + 1) % arr.size]
      total += pt.x.to_f * b.y.to_f - b.x.to_f * pt.y.to_f
      bulge = pt.bulge.to_f
      next if bulge.abs <= 1e-9
      num = 4.0 * Math.atan(bulge)
      r = pt.distance(b).to_f / (2.0 * Math.sin(num.abs / 2.0))
      total += r * r * (num - Math.sin(num))
    end
    total / 2.0
  end
  def edge_lengths(arr)
    n = arr.size
    (0...n).map do |k|
      ix = (n - 1 - k) % n
      src = arr[ix]
      pt3 = PtEx.new(src.x, src.y, 0)
      pt3.bulge = -arr[(ix - 1 + n) % n].bulge.to_f
      pt3
    end
  end
  def rotate_to_nearest(arr, target)
    n = arr.size
    return arr if n < 2
    best = nil
    arr.each_with_index do |pt2, i|
      hit = distance_to_edge(pt2, arr[(i + 1) % n], target)
      best = [i, *hit] if best.nil? || hit[0] < best[1]
    end
    i, _2a53676a, pt, sweep = best
    pt2 = arr[i]
    num = 0.01 / 25.4
    return arr.rotate(i) if pt.distance(pt2) < num
    return arr.rotate(i + 1) if pt.distance(arr[(i + 1) % n]) < num
    head_off = PtEx.new(pt.x, pt.y, 0)
    tail_pt = PtEx.new(pt2.x, pt2.y, 0)
    if sweep
      num2 = 4.0 * Math.atan(pt2.bulge.to_f)
      tail_pt.bulge = Math.tan(sweep / 4.0)
      head_off.bulge = Math.tan((num2 - sweep) / 4.0)
    end
    [head_off] + arr.rotate(i + 1)[0...-1] + [tail_pt]
  end
  def distance_to_edge(pt, b, target)
    ax, ay, bx2, by2 = pt.x.to_f, pt.y.to_f, b.x.to_f, b.y.to_f
    trai, duoi = target.x.to_f, target.y.to_f
    bulge = pt.bulge.to_f
    if bulge.abs <= 1e-9
      dx, dy = bx2 - ax, by2 - ay
      _3c77079d = dx * dx + dy * dy
      t = _3c77079d > 0 ? (((trai - ax) * dx + (duoi - ay) * dy) / _3c77079d).clamp(0.0, 1.0) : 0.0
      pt2 = ::Geom::Point3d.new(ax + t * dx, ay + t * dy, 0)
      return [pt2.distance(target).to_f, pt2, nil]
    end
    num2 = 4.0 * Math.atan(bulge)
    chord = Math.hypot(bx2 - ax, by2 - ay)
    _0c44d192 = chord / 2.0 / Math.tan(num2 / 2.0)
    px = (ax + bx2) / 2.0 - (by2 - ay) / chord * _0c44d192
    py = (ay + by2) / 2.0 + (bx2 - ax) / chord * _0c44d192
    r = Math.hypot(ax - px, ay - py)
    num = Math.atan2(duoi - py, trai - px) - Math.atan2(ay - py, ax - px)
    num %= 2.0 * Math::PI
    num -= 2.0 * Math::PI if num2 < 0 && num > 0
    if num.abs <= num2.abs
      deg4 = Math.atan2(duoi - py, trai - px)
      pt2 = ::Geom::Point3d.new(px + r * Math.cos(deg4), py + r * Math.sin(deg4), 0)
      return [pt2.distance(target).to_f, pt2, num]
    end
    end_code = pt.distance(target) <= b.distance(target) ? pt : b
    [end_code.distance(target).to_f, ::Geom::Point3d.new(end_code.x, end_code.y, 0), end_code.equal?(pt) ? 0.0 : num2]
  end
end
