module KSU::Shape
  private
  def end_drag2
    if @clearing
      clear_ranks(band_parts)
      return
    end
    sweep = sweep_dir
    return unless sweep
    apply_ranks(rank_plan(sweep))
  end
  def sweep_dir
    return @sweep_memo if @sweeping && @sweep_memo
    return nil if @sweeping && band_parts.empty?
    dir = forced_dir || dir_of(@sweep_a, @sweep_b)
    @sweep_memo = dir if @sweeping && dir
    dir
  end
  def band_parts
    return [] unless @sweep_a && @sweep_b
    x1, num2 = [@sweep_a.x.to_f, @sweep_b.x.to_f].minmax
    y1, num = [@sweep_a.y.to_f, @sweep_b.y.to_f].minmax
    return [] if (num2 - x1) < 1.mm.to_f && (num - y1) < 1.mm.to_f
    @arr29.select do |arr|
      bbox = arr[:bbox]
      if @che_do_chon == 1
        bbox.min.x.to_f >= x1 && bbox.max.x.to_f <= num2 &&
          bbox.min.y.to_f >= y1 && bbox.max.y.to_f <= num
      else
        bbox.min.x.to_f <= num2 && bbox.max.x.to_f >= x1 &&
          bbox.min.y.to_f <= num && bbox.max.y.to_f >= y1 &&
          part_in_rect?(x1, y1, num2, num, arr)
      end
    end
  end
  def part_in_rect?(x1, y1, _614e963e, _d67f3cec, arr)
    return true if poly_hits_rect?(x1, y1, _614e963e, _d67f3cec, arr[:polygon])
    return true if (arr[:holes] || []).any? { |elem| poly_hits_rect?(x1, y1, _614e963e, _d67f3cec, elem) }
    point_in_part?(x1, y1, arr)
  end
  def seg_hits_rect?(x13, y1, x2, y2, x1, y12, _614e963e, _d67f3cec)
    segs_cross?(x13, y1, x2, y2, x1, y12, _614e963e, y12) ||
      segs_cross?(x13, y1, x2, y2, _614e963e, y12, _614e963e, _d67f3cec) ||
      segs_cross?(x13, y1, x2, y2, _614e963e, _d67f3cec, x1, _d67f3cec) ||
      segs_cross?(x13, y1, x2, y2, x1, _d67f3cec, x1, y12)
  end
  def poly_hits_rect?(x1, y1, _614e963e, _d67f3cec, poly)
    n = poly.length
    n.times do |i|
      ax, ay = poly[i].x.to_f, poly[i].y.to_f
      return true if ax.between?(x1, _614e963e) && ay.between?(y1, _d67f3cec)
      b = poly[(i + 1) % n]
      return true if seg_hits_rect?(ax, ay, b.x.to_f, b.y.to_f, x1, y1, _614e963e, _d67f3cec)
    end
    false
  end
  def point_in_part?(x, y, arr)
    return false unless KSU::View.in_poly?(x, y, arr[:polygon])
    (arr[:holes] || []).none? { |elem| KSU::View.in_poly?(x, y, elem) }
  end
  def rank_plan(sweep)
    sel = eligible(band_parts)
    return [] if sel.empty?
    track_order(sel, sweep)
    assign_ranks(sel, sweep)
  end
  def track_order(arr29, sweep)
    cur = arr29.to_h { |arr| [arr[:part].entityID, true] }
    @track_ids.select! { |id| cur[id] }
    arr3 = @track_ids.to_h { |id| [id, true] }
    arr2 = arr29.reject { |arr| arr3[arr[:part].entityID] }
    return if arr2.empty?
    flag = @layer_theo_vung ? cross_sorter_band(sweep) : cross_sorter(sweep)
    arr2 = arr2.sort_by { |arr| [sweep_key(arr, sweep), flag.call(arr)] }
    @track_ids.concat(arr2.map { |arr| arr[:part].entityID })
  end
  def sweep_key(arr, sweep)
    horizontal = sweep == :left_to_right || sweep == :right_to_left
    flag = (sweep == :left_to_right || sweep == :bottom_to_top) ? 1.0 : -1.0
    center = (horizontal ? arr[:center].x.to_f : arr[:center].y.to_f) * flag
    if @che_do_chon == 1
      best = nil
      each_point(arr) do |trai, duoi|
        v = (horizontal ? trai : duoi) * flag
        best = v if best.nil? || v > best
      end
      return best || center
    end
    s = @sweep_a
    num = s ? (horizontal ? s.x.to_f : s.y.to_f) * flag : nil
    return num if s && point_in_part?(s.x.to_f, s.y.to_f, arr)
    tol = 1.mm.to_f
    best = nil
    each_point(arr) do |trai, duoi|
      v = (horizontal ? trai : duoi) * flag
      next if num && v < num - tol
      best = v if best.nil? || v < best
    end
    best || center
  end
  def each_point(arr)
    [arr[:polygon], *(arr[:holes] || [])].each { |arr2| arr2.each { |segs_for_ray| yield(segs_for_ray.x.to_f, segs_for_ray.y.to_f) } }
  end
  def assign_ranks(arr29, sweep)
    side = side_of(sweep)
    order = order_of(sweep)
    flag = @layer_theo_vung ? cross_sorter_band(sweep) : cross_sorter(sweep)
    materials = @track_ids.each_with_index.to_h
    arr29 = arr29.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    arr29.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      number_parts(group.sort_by { |arr|
        i = materials[arr[:part].entityID]
        i ? [0, i, 0.0] : [1, order.call(arr), flag.call(arr)]
      }, side, start_rank(sheet, side, group))
    end
  end
  def start_rank(sheet, side, _b49a2eb8)
    return 1 unless @danh_so_thu_tu
    prefix = layer_prefix(side)
    ref_p1 = _b49a2eb8.to_h { |arr| [arr[:part].entityID, true] }
    hi = @so_layer_tu - 1
    @arr29.each do |arr|
      next unless arr[:rank] && arr[:sheet] == sheet
      next if ref_p1[arr[:part].entityID]
      next unless arr[:prefix].to_s == prefix
      hi = arr[:rank] if arr[:rank] > hi
    end
    hi + 1
  end
  def cross_sorter(sweep)
    case sweep
    when :left_to_right, :right_to_left then ->(arr) { -arr[:center].y.to_f }
    when :top_to_bottom, :bottom_to_top then ->(arr) { arr[:center].x.to_f }
    end
  end
  def cross_sorter_band(sweep)
    return cross_sorter(sweep) unless @sweep_a && @sweep_b
    case sweep
    when :left_to_right, :right_to_left
      @sweep_b.y.to_f >= @sweep_a.y.to_f ?
        ->(arr) { arr[:center].y.to_f } : ->(arr) { -arr[:center].y.to_f }
    when :top_to_bottom, :bottom_to_top
      @sweep_b.x.to_f >= @sweep_a.x.to_f ?
        ->(arr) { arr[:center].x.to_f } : ->(arr) { -arr[:center].x.to_f }
    end
  end
  def rank_by_layer(arr29, sweep)
    side = side_of(sweep)
    order2 = order_of(sweep)
    tol = 1.mm.to_f
    arr29 = arr29.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    return number_by_sheet(arr29, side) unless @danh_so_thu_tu
    arr29.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      layers = start_rank(sheet, side, group) - 1
      prev = nil
      ok = []
      group.sort_by(&order2).each do |arr|
        k = order2.call(arr)
        if prev.nil? || (k - prev).abs > tol
          layers += 1
          prev = k
        end
        break if layers > @so_layer_den
        ok << { part: arr, rank: layers, side: side }
      end
      ok
    end
  end
  def rank_free(arr29)
    @layer_theo_vung ? rank_band(arr29) : rank_nearest_edge(arr29)
  end
  def rank_drag(arr29)
    if @layer_theo_vung
      arr = arr29.sort_by { |pt3| band_key(@rank_a, @rank_b, pt3) }
      rank_band(arr)
    else
      sweep = dir_of(@rank_a, @rank_b)
      sweep ? rank_by_layer(arr29, sweep) : []
    end
  end
  def number_parts(arr, side, layers2)
    return arr.map { |pt3| { part: pt3, rank: 1, side: side } } unless @danh_so_thu_tu
    layers = layers2 - 1
    ok = []
    arr.each do |pt3|
      layers += 1
      break if layers > @so_layer_den
      ok << { part: pt3, rank: layers, side: side }
    end
    ok
  end
  def number_by_sheet(arr29, side)
    arr29.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      number_parts(group, side, start_rank(sheet, side, group))
    end
  end
  def rank_band(arr29)
    arr29 = arr29.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    number_by_sheet(arr29, @side)
  end
  def rank_nearest_edge(arr29)
    arr29 = arr29.reject { |arr2| arr2[:rank] } unless @cho_phep_ghi_de
    return [] if arr29.empty?
    row0 = arr29.first
    arr = KSU::Sheet.record_for(@sheets, row0[:sheet])
    number_by_sheet(arr29, side_nearest(row0[:bbox], arr && arr[:bbox]))
  end
  def side_nearest(rect4, arr)
    return nil unless arr
    [:tren, :duoi, :trai, :phai].min_by { |s| threshold(rect4, arr, s).to_f }
  end
  def eligible(arr29)
    return arr29 unless @gioi_han_kich_thuoc
    arr29.reject { |arr| [arr[:bbox].max.x.to_f - arr[:bbox].min.x.to_f, arr[:bbox].max.y.to_f - arr[:bbox].min.y.to_f].min > @chieu_rong_toi_da }
  end
  def order_of(sweep)
    case sweep
    when :left_to_right then ->(arr) { arr[:center].x.to_f }
    when :right_to_left then ->(arr) { -arr[:center].x.to_f }
    when :top_to_bottom then ->(arr) { -arr[:center].y.to_f }
    when :bottom_to_top then ->(arr) { arr[:center].y.to_f }
    end
  end
  def dir_of(p1, p2)
    return nil unless p1 && p2
    dx = p2.x.to_f - p1.x.to_f
    dy = p2.y.to_f - p1.y.to_f
    tol = 1.mm.to_f
    return nil if dx.abs < tol && dy.abs < tol
    if dx.abs >= dy.abs
      dx >= 0 ? :left_to_right : :right_to_left
    else
      dy >= 0 ? :bottom_to_top : :top_to_bottom
    end
  end
  def forced_dir
    return nil unless @sweep_a && @sweep_b
    x1, num2 = [@sweep_a.x.to_f, @sweep_b.x.to_f].minmax
    y1, num = [@sweep_a.y.to_f, @sweep_b.y.to_f].minmax
    return nil if (num2 - x1) < 1.mm.to_f && (num - y1) < 1.mm.to_f
    arr = []
    @sheets.each do |rec|
      sx1, sx2, sy1, sy2 = rect_of(rec)
      edge_overlaps(sx1, sx2, sy1, sy2, x1, num2, y1, num).each do |edge, len|
        next if len <= 0
        arr << { edge: edge, len: len, dist: dist(sx1, sx2, sy1, sy2, edge) }
      end
    end
    return nil if arr.empty?
    best = arr.max_by { |arr2| [arr2[:len], -arr2[:dist]] }
    { top: :top_to_bottom, bottom: :bottom_to_top, left: :left_to_right, right: :right_to_left }[best[:edge]]
  end
  def rect_of(rec)
    arr = rec[:top_corners]
    [*arr.map { |pt| pt.x.to_f }.minmax, *arr.map { |pt| pt.y.to_f }.minmax]
  end
  def edge_overlaps(sx1, sx2, sy1, sy2, rx1, rx2, ry1, ry2)
    ox = [[sx2, rx2].min - [sx1, rx1].max, 0].max
    oy4   = [[sy2, ry2].min - [sy1, ry1].max, 0].max
    {
      top:    (sy2.between?(ry1, ry2) ? ox : 0),
      bottom: (sy1.between?(ry1, ry2) ? ox : 0),
      left:   (sx1.between?(rx1, rx2) ? oy4   : 0),
      right:  (sx2.between?(rx1, rx2) ? oy4   : 0)
    }
  end
  def dist(sx1, sx2, sy1, sy2, edge)
    return Float::INFINITY unless @sweep_a
    start_x = @sweep_a.x.to_f
    ly0 = @sweep_a.y.to_f
    case edge
    when :top    then (ly0 - sy2).abs
    when :bottom then (ly0 - sy1).abs
    when :left   then (start_x - sx1).abs
    when :right  then (start_x - sx2).abs
    end
  end
  def side_of(sweep)
    { left_to_right: :trai, right_to_left: :phai, top_to_bottom: :tren, bottom_to_top: :duoi }[sweep]
  end
  def layer_for_side(side, theo_vung = @layer_theo_vung)
    theo_vung ? { tren: @ten_tren, duoi: @ten_duoi, trai: @ten_trai, phai: @ten_phai }[side] : @ten_chung
  end
  def layer_prefix(side, theo_vung = @layer_theo_vung)
    side ? layer_for_side(side, theo_vung).to_s : "Lớp"
  end
  def side_color(side, theo_vung = @layer_theo_vung)
    theo_vung ? { tren: @mau_tren, duoi: @mau_duoi, trai: @mau_trai, phai: @mau_phai }[side] : @mau_chung
  end
  def finish_drag_rank
    return unless @rank_a && @rank_b
    apply_ranks(rank_drag(parts_between(@rank_a, @rank_b)))
    @rank_a = @rank_b = nil
  end
  def rank_lasso
    return if @lasso_pts.length < 2
    apply_ranks(rank_free(parts_along(@lasso_pts)))
    @lasso_pts = []
    @rank_b = nil
  end
  def clear_ranks(arr29)
    arr2 = arr29.select { |arr| arr[:rank] }
    arr2.each { |arr| arr.merge!(rank: nil, side: nil, prefix: nil, base_color: nil, fill_color: nil, changed: true) }
    commit_changes(arr2)
  end
  def lasso_path
    arr = @lasso_pts.dup
    arr << @rank_b if @rank_b && arr.any? && arr.last != @rank_b
    arr
  end
  def parts_along(arr2)
    arr = []
    arr2.each_cons(2) do |a, b|
      pts = parts_between(a, b).sort_by { |pt3| band_key(a, b, pt3) }
      pts.each { |pt3| arr << pt3 unless arr.include?(pt3) }
    end
    arr
  end
  def proj_t(pt, b, segs_for_ray)
    dx = b.x.to_f - pt.x.to_f
    dy = b.y.to_f - pt.y.to_f
    len2 = dx * dx + dy * dy
    return 0.0 if len2 < 1e-9
    ((segs_for_ray.x.to_f - pt.x.to_f) * dx + (segs_for_ray.y.to_f - pt.y.to_f) * dy) / len2
  end
  def parts_between(p1, p2)
    eligible(@arr29.select { |pt3| seg_hits_part?(p1, p2, pt3) })
  end
  def seg_hits_part?(p1, p2, arr)
    return false unless seg_hits_bbox?(p1, p2, arr[:bbox])
    @che_do_chon == 1 ?
      seg_cuts_poly?(p1, p2, arr[:polygon]) :
      seg_touches_part?(p1, p2, arr)
  end
  def seg_hits_bbox?(p1, p2, bbox)
    x14, y1 = p1.x.to_f, p1.y.to_f
    x2, num3 = p2.x.to_f, p2.y.to_f
    x1, num2 = bbox.min.x.to_f, bbox.max.x.to_f
    y13, num = bbox.min.y.to_f, bbox.max.y.to_f
    return true if x14.between?(x1, num2) && y1.between?(y13, num)
    return true if x2.between?(x1, num2) && num3.between?(y13, num)
    seg_hits_rect?(x14, y1, x2, num3, x1, y13, num2, num)
  end
  def seg_touches_part?(p1, p2, arr)
    return true if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    return true if point_in_part?(p2.x.to_f, p2.y.to_f, arr)
    return true if seg_crosses_poly?(p1, p2, arr[:polygon])
    (arr[:holes] || []).any? { |elem| seg_crosses_poly?(p1, p2, elem) }
  end
  def seg_cuts_poly?(p1, p2, poly)
    return false if KSU::View.in_poly?(p1.x.to_f, p1.y.to_f, poly)
    return false if KSU::View.in_poly?(p2.x.to_f, p2.y.to_f, poly)
    seg_crosses_poly?(p1, p2, poly)
  end
  def seg_crosses_poly?(p1, p2, poly)
    x1, y1 = p1.x.to_f, p1.y.to_f
    x2, num = p2.x.to_f, p2.y.to_f
    n = poly.length
    n.times do |i|
      pt = poly[i]
      b = poly[(i + 1) % n]
      return true if segs_cross?(x1, y1, x2, num, pt.x.to_f, pt.y.to_f, b.x.to_f, b.y.to_f)
    end
    false
  end
  def segs_cross?(x1, y1, x2, y2, bx1, by1, bx2, by2)
    !seg_cross_t(x1, y1, x2, y2, bx1, by1, bx2, by2).nil?
  end
  def band_key(p1, p2, arr)
    return 0.0 if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    best = first_cross_t(p1, p2, arr[:polygon])
    (arr[:holes] || []).each do |elem|
      t = first_cross_t(p1, p2, elem)
      best = t if t && (best.nil? || t < best)
    end
    best || proj_t(p1, p2, arr[:center])
  end
  def first_cross_t(p1, p2, poly)
    x1, y1 = p1.x.to_f, p1.y.to_f
    x2, num = p2.x.to_f, p2.y.to_f
    best = nil
    n = poly.length
    n.times do |i|
      pt = poly[i]
      b = poly[(i + 1) % n]
      t = seg_cross_t(x1, y1, x2, num, pt.x.to_f, pt.y.to_f, b.x.to_f, b.y.to_f)
      best = t if t && (best.nil? || t < best)
    end
    best
  end
  def seg_cross_t(x1, y1, x2, y2, bx1, by1, bx2, by2)
    num = (x1 - x2) * (by1 - by2) - (y1 - y2) * (bx1 - bx2)
    return nil if num.abs < 1e-9
    t = ((x1 - bx1) * (by1 - by2) - (y1 - by1) * (bx1 - bx2)) / num
    u = -((x1 - x2) * (y1 - by1) - (y1 - y2) * (x1 - bx1)) / num
    return nil unless t.between?(0.0, 1.0) && u.between?(0.0, 1.0)
    t
  end
  def group_by_rank
    h = {}
    @arr29.each do |arr|
      next if !arr[:rank] || @in_plan[arr[:part]] || @in_clear[arr[:part]]
      color = arr[:fill_color] || fill_color_of(arr)
      next unless color
      key = [color.red, color.green, color.blue, color.alpha]
      (h[key] ||= [color, []])[1] << overlay_of(arr)
    end
    h.each_value { |color, polys| KSU::View.draw_polys(polys, color: color, line: false) }
  end
  def draw_pick(view)
    case pick_mode
    when 0 then draw_sweep_rect(view)
    when 1 then draw_rank_line
    when 2 then draw_lasso
    end
  end
  def draw_sweep_rect(view)
    return unless @sweeping && @sweep_a && @sweep_b
    text, x1 = [@sweep_a.x.to_f, @sweep_b.x.to_f].minmax
    y0, y1 = [@sweep_a.y.to_f, @sweep_b.y.to_f].minmax
    pt = [[text, y0], [x1, y0], [x1, y1], [text, y1]].map { |trai, duoi| Geom::Point3d.new(trai, duoi, @plane_z) }
    KSU::View.draw_polygon2d(view, KSU::View.to_screen(pt))
    draw_sweep_arrow(view)
  end
  def draw_sweep_arrow(view)
    return if @clearing
    sweep = sweep_dir
    return unless sweep
    s = view.screen_coords(@sweep_a)
    pt = view.screen_coords(@sweep_b)
    _7b112297 = sweep == :left_to_right || sweep == :right_to_left
    return if (_7b112297 ? (pt.x - s.x).abs : (pt.y - s.y).abs) < 24
    px = (s.x + pt.x) / 2.0
    py = (s.y + pt.y) / 2.0
    _09dce564, flag = _7b112297 ? [s.x, pt.x].minmax : [s.y, pt.y].minmax
    case sweep
    when :left_to_right then KSU::View.draw_dim_arrow(view, _09dce564 + 10, py, flag - 12, py, :right)
    when :right_to_left then KSU::View.draw_dim_arrow(view, flag - 10, py, _09dce564 + 12, py, :left)
    when :top_to_bottom then KSU::View.draw_dim_arrow(view, px, _09dce564 + 10, px, flag - 12, :down)
    when :bottom_to_top then KSU::View.draw_dim_arrow(view, px, flag - 10, px, _09dce564 + 12, :up)
    end
  end
  def draw_rank_line
    return unless @rank_a && @rank_b
    KSU::View.draw_lines([@rank_a, @rank_b], guide: false, width: 1)
  end
  def draw_lasso
    KSU::View.draw_lines(lasso_path.each_cons(2).flat_map { |a, b| [a, b] }, guide: false, width: 1)
  end
end
KSU::Chongbay.include(KSU::Shape)
module KSU::Shape
  def self.decrypt(str2)
    return "" if str2.nil? || str2.to_s.empty?
    str = str2.to_s.strip.unpack("m0").first
    return "" if str.nil? || str.empty?
    str.bytes.each_with_index.map { |b, i| b ^ KSU::Widget.xor_byte(i) }.pack("C*")
  rescue
    ""
  end
  def self.activations_left(resp, key)
    left = resp.dig("data", "activations_left")
    return left unless left.nil?
    resp2 = begin
      KSU::Chontam.validate_key(key)
    rescue StandardError
      nil
    end
    resp2 ? resp2.dig("data", "activations_left") : nil
  end
end
