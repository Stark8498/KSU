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
    x1, num = [@sweep_a.x.to_f, @sweep_b.x.to_f].minmax
    y1, num2 = [@sweep_a.y.to_f, @sweep_b.y.to_f].minmax
    return [] if (num - x1) < 1.mm.to_f && (num2 - y1) < 1.mm.to_f
    @parts.select do |arr|
      bbox = arr[:bbox]
      if @che_do_chon == 1
        bbox.min.x.to_f >= x1 && bbox.max.x.to_f <= num &&
          bbox.min.y.to_f >= y1 && bbox.max.y.to_f <= num2
      else
        bbox.min.x.to_f <= num && bbox.max.x.to_f >= x1 &&
          bbox.min.y.to_f <= num2 && bbox.max.y.to_f >= y1 &&
          part_in_rect?(x1, y1, num, num2, arr)
      end
    end
  end
  def part_in_rect?(x1, y1, x2, y2, arr)
    return true if poly_hits_rect?(x1, y1, x2, y2, arr[:polygon])
    return true if (arr[:holes] || []).any? { |h| poly_hits_rect?(x1, y1, x2, y2, h) }
    point_in_part?(x1, y1, arr)
  end
  def seg_hits_rect?(x24, ay1, x2, y2, x1, y1, x23, y22)
    segs_cross?(x24, ay1, x2, y2, x1, y1, x23, y1) ||
      segs_cross?(x24, ay1, x2, y2, x23, y1, x23, y22) ||
      segs_cross?(x24, ay1, x2, y2, x23, y22, x1, y22) ||
      segs_cross?(x24, ay1, x2, y2, x1, y22, x1, y1)
  end
  def poly_hits_rect?(x1, y1, x2, y2, poly)
    n = poly.length
    n.times do |i|
      pt2 = poly[i]
      ax = pt2.x.to_f
      ay = pt2.y.to_f
      return true if ax.between?(x1, x2) && ay.between?(y1, y2)
      b = poly[(i + 1) % n]
      return true if seg_hits_rect?(ax, ay, b.x.to_f, b.y.to_f, x1, y1, x2, y2)
    end
    false
  end
  def point_in_part?(x, y, arr)
    return false unless KSU::View.in_poly?(x, y, arr[:polygon])
    (arr[:holes] || []).none? { |h| KSU::View.in_poly?(x, y, h) }
  end
  def rank_plan(sweep = sweep_dir)
    return [] unless sweep
    sel = eligible(band_parts)
    return [] if sel.empty?
    track_order(sel, sweep)
    assign_ranks(sel, sweep)
  end
  def track_order(parts, sweep)
    @track_ids ||= []
    cur = {}
    parts.each { |arr| cur[arr[:part].entityID] = true }
    @track_ids.select! { |id| cur[id] }
    seen = {}
    @track_ids.each { |id| seen[id] = true }
    arr2 = parts.reject { |arr| seen[arr[:part].entityID] }
    return if arr2.empty?
    flag = @layer_theo_vung ?
                   cross_sorter_band(sweep) : cross_sorter(sweep)
    arr2.sort_by { |arr| [sweep_key(arr, sweep), flag.call(arr)] }.each do |arr|
      @track_ids << arr[:part].entityID
    end
  end
  def sweep_key(arr, sweep)
    horizontal = sweep == :left_to_right || sweep == :right_to_left
    flag2 = (sweep == :left_to_right || sweep == :bottom_to_top) ? 1.0 : -1.0
    center = (horizontal ? arr[:center].x.to_f : arr[:center].y.to_f) * flag2
    if @che_do_chon == 1
      best = nil
      each_point(arr) do |trai, duoi|
        v = (horizontal ? trai : duoi) * flag2
        best = v if best.nil? || v > best
      end
      return best || center
    end
    s = @sweep_a
    num = s ? (horizontal ? s.x.to_f : s.y.to_f) * flag2 : nil
    return num if s && point_in_part?(s.x.to_f, s.y.to_f, arr)
    tol = 1.mm.to_f
    best = nil
    each_point(arr) do |trai, duoi|
      v = (horizontal ? trai : duoi) * flag2
      next if num && v < num - tol
      best = v if best.nil? || v < best
    end
    best || center
  end
  def each_point(arr)
    arr[:polygon].each { |pt| yield(pt.x.to_f, pt.y.to_f) }
    (arr[:holes] || []).each do |h|
      h.each { |pt| yield(pt.x.to_f, pt.y.to_f) }
    end
  end
  def assign_ranks(parts, sweep)
    side = side_of(sweep)
    order = order_of(sweep)
    flag = @layer_theo_vung ?
                   cross_sorter_band(sweep) : cross_sorter(sweep)
    materials = {}
    (@track_ids || []).each_with_index { |id, i| materials[id] = i }
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      number_parts(group.sort_by { |arr|
        i = materials[arr[:part].entityID]
        i ? [0, i, 0.0] : [1, order.call(arr), flag.call(arr)]
      }, side, start_rank(sheet, side, group))
    end
  end
  def start_rank(sheet, side, arr2)
    return 1 unless @danh_so_thu_tu
    prefix = layer_prefix(side)
    ref_p1 = {}
    arr2.each { |arr| ref_p1[arr[:part].entityID] = true }
    hi = @so_layer_tu - 1
    @parts.each do |arr|
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
  def rank_by_layer(parts, sweep)
    side = side_of(sweep)
    order2 = order_of(sweep)
    tol = 1.mm.to_f
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    return number_by_sheet(parts, side) unless @danh_so_thu_tu
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      layers = start_rank(sheet, side, group) - 1
      prev = nil
      answer = []
      group.sort_by(&order2).each do |arr|
        k = order2.call(arr)
        if prev.nil? || (k - prev).abs > tol
          layers += 1
          prev = k
        end
        break if layers > @so_layer_den
        answer << { part: arr, rank: layers, side: side }
      end
      answer
    end
  end
  def rank_free(parts)
    return rank_band(parts) if @layer_theo_vung
    rank_nearest_edge(parts)
  end
  def rank_drag(parts)
    if @layer_theo_vung
      arr = parts.sort_by { |rec| band_key(@rank_a, @rank_b, rec) }
      rank_band(arr)
    else
      sweep = dir_of(@rank_a, @rank_b)
      sweep ? rank_by_layer(parts, sweep) : []
    end
  end
  def number_parts(arr, side, layers2 = @so_layer_tu)
    return arr.map { |rec| { part: rec, rank: 1, side: side } } unless @danh_so_thu_tu
    layers = layers2 - 1
    answer = []
    arr.each do |rec|
      layers += 1
      break if layers > @so_layer_den
      answer << { part: rec, rank: layers, side: side }
    end
    answer
  end
  def number_by_sheet(parts, side)
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, group|
      number_parts(group, side, start_rank(sheet, side, group))
    end
  end
  def rank_band(parts)
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    return [] if parts.empty?
    number_by_sheet(parts, @side)
  end
  def rank_nearest_edge(parts)
    parts = parts.reject { |arr3| arr3[:rank] } unless @cho_phep_ghi_de
    return [] if parts.empty?
    row0 = parts.first
    arr = KSU::Sheet.record_for(@sheets, row0[:sheet])
    number_by_sheet(parts, side_nearest(row0[:bbox], arr && arr[:bbox]))
  end
  def side_nearest(rect4, arr)
    return nil unless arr
    [:tren, :duoi, :trai, :phai].min_by { |s| threshold(rect4, arr, s).to_f }
  end
  def eligible(parts)
    return parts unless @gioi_han_kich_thuoc
    parts.reject { |arr| [arr[:bbox].max.x.to_f - arr[:bbox].min.x.to_f, arr[:bbox].max.y.to_f - arr[:bbox].min.y.to_f].min > @chieu_rong_toi_da }
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
    x1, num = [@sweep_a.x.to_f, @sweep_b.x.to_f].minmax
    y1, num2 = [@sweep_a.y.to_f, @sweep_b.y.to_f].minmax
    return nil if (num - x1) < 1.mm.to_f && (num2 - y1) < 1.mm.to_f
    arr = []
    @sheets.each do |rec|
      sx1, sx2, sy1, sy2 = rect_of(rec)
      edge_overlaps(sx1, sx2, sy1, sy2, x1, num, y1, num2).each do |edge, len|
        next if len <= 0
        arr << { edge: edge, len: len, dist: dist(sx1, sx2, sy1, sy2, edge) }
      end
    end
    return nil if arr.empty?
    best = arr.max_by { |color| [color[:len], -color[:dist]] }
    case best[:edge]
    when :top    then :top_to_bottom
    when :bottom then :bottom_to_top
    when :left   then :left_to_right
    when :right  then :right_to_left
    end
  end
  def rect_of(rec)
    pts = rec[:top_corners]
    arr2 = pts.map { |pt| pt.x.to_f }
    arr3 = pts.map { |pt| pt.y.to_f }
    [*arr2.minmax, *arr3.minmax]
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
    case sweep
    when :left_to_right then :trai
    when :right_to_left then :phai
    when :top_to_bottom then :tren
    when :bottom_to_top then :duoi
    end
  end
  def layer_for_side(side, theo_vung = @layer_theo_vung)
    return @ten_chung unless theo_vung
    case side
    when :tren then @ten_tren
    when :duoi then @ten_duoi
    when :trai then @ten_trai
    when :phai then @ten_phai
    end
  end
  def layer_prefix(side, theo_vung = @layer_theo_vung)
    side ? layer_for_side(side, theo_vung).to_s : "Lớp"
  end
  def side_color(side, theo_vung = @layer_theo_vung)
    return @mau_chung unless theo_vung
    case side
    when :tren then @mau_tren
    when :duoi then @mau_duoi
    when :trai then @mau_trai
    when :phai then @mau_phai
    end
  end
  def finish_drag_rank
    return unless @rank_a && @rank_b
    parts = parts_between(@rank_a, @rank_b)
    apply_ranks(rank_drag(parts)) unless parts.empty?
    @rank_a = nil
    @rank_b = nil
  end
  def rank_lasso
    return if @lasso_pts.length < 2
    parts = parts_along(@lasso_pts)
    apply_ranks(rank_free(parts)) unless parts.empty?
    @lasso_pts = []
    @rank_b = nil
  end
  def clear_ranks(parts)
    arr2 = []
    parts.each do |arr|
      next unless arr[:rank]
      arr[:rank] = nil
      arr[:side] = nil
      arr[:prefix] = nil
      arr[:base_color] = nil
      arr[:fill_color] = nil
      arr[:changed] = true
      arr2 << arr
    end
    commit_changes(arr2)
  end
  def lasso_path
    pts = @lasso_pts.dup
    pts << @rank_b if @rank_b && pts.any? && pts.last != @rank_b
    pts
  end
  def parts_along(pts)
    arr = []
    (pts.length - 1).times do |i|
      a = pts[i]
      b = pts[i + 1]
      poly = parts_between(a, b).sort_by { |rec| band_key(a, b, rec) }
      poly.each { |rec| arr << rec unless arr.include?(rec) }
    end
    arr
  end
  def proj_t(pt, b, pt6)
    dx = b.x.to_f - pt.x.to_f
    dy = b.y.to_f - pt.y.to_f
    len2 = dx * dx + dy * dy
    return 0.0 if len2 < 1e-9
    ((pt6.x.to_f - pt.x.to_f) * dx + (pt6.y.to_f - pt.y.to_f) * dy) / len2
  end
  def parts_between(p1, p2)
    eligible(@parts.select { |rec| seg_hits_part?(p1, p2, rec) })
  end
  def seg_hits_part?(p1, p2, arr)
    return false unless seg_hits_bbox?(p1, p2, arr[:bbox])
    @che_do_chon == 1 ?
      seg_cuts_poly?(p1, p2, arr[:polygon]) :
      seg_touches_part?(p1, p2, arr)
  end
  def seg_hits_bbox?(p1, p2, bbox)
    x25, num4 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    x1, num = bbox.min.x.to_f, bbox.max.x.to_f
    y1, num2 = bbox.min.y.to_f, bbox.max.y.to_f
    return true if x25.between?(x1, num) && num4.between?(y1, num2)
    return true if x2.between?(x1, num) && y2.between?(y1, num2)
    seg_hits_rect?(x25, num4, x2, y2, x1, y1, num, num2)
  end
  def seg_touches_part?(p1, p2, arr)
    return true if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    return true if point_in_part?(p2.x.to_f, p2.y.to_f, arr)
    return true if seg_crosses_poly?(p1, p2, arr[:polygon])
    (arr[:holes] || []).any? { |h| seg_crosses_poly?(p1, p2, h) }
  end
  def seg_cuts_poly?(p1, p2, poly)
    return false if KSU::View.in_poly?(p1.x.to_f, p1.y.to_f, poly)
    return false if KSU::View.in_poly?(p2.x.to_f, p2.y.to_f, poly)
    seg_crosses_poly?(p1, p2, poly)
  end
  def seg_crosses_poly?(p1, p2, poly)
    x26, num2 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    n = poly.length
    n.times do |i|
      pt2 = poly[i]
      b = poly[(i + 1) % n]
      return true if segs_cross?(x26, num2, x2, y2, pt2.x.to_f, pt2.y.to_f, b.x.to_f, b.y.to_f)
    end
    false
  end
  def segs_cross?(x27, ay1, x2, y2, bx1, by1, bx2, by2)
    !seg_cross_t(x27, ay1, x2, y2, bx1, by1, bx2, by2).nil?
  end
  def band_key(p1, p2, arr)
    return 0.0 if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    best = first_cross_t(p1, p2, arr[:polygon])
    (arr[:holes] || []).each do |h|
      thick = first_cross_t(p1, p2, h)
      best = thick if thick && (best.nil? || thick < best)
    end
    best || proj_t(p1, p2, arr[:center])
  end
  def first_cross_t(p1, p2, poly)
    x28, num3 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    best = nil
    n = poly.length
    n.times do |i|
      pt2 = poly[i]
      b = poly[(i + 1) % n]
      thick = seg_cross_t(x28, num3, x2, y2, pt2.x.to_f, pt2.y.to_f, b.x.to_f, b.y.to_f)
      best = thick if thick && (best.nil? || thick < best)
    end
    best
  end
  def seg_cross_t(x29, ay1, x2, y2, bx1, by1, bx2, by2)
    num = (x29 - x2) * (by1 - by2) - (ay1 - y2) * (bx1 - bx2)
    return nil if num.abs < 1e-9
    thick = ((x29 - bx1) * (by1 - by2) - (ay1 - by1) * (bx1 - bx2)) / num
    u = -((x29 - x2) * (ay1 - by1) - (ay1 - y2) * (x29 - bx1)) / num
    return nil unless thick.between?(0.0, 1.0) && u.between?(0.0, 1.0)
    thick
  end
  def draw_ranked(view)
    arr2 = @in_plan
    arr3 = @in_clear
    h = {}
    @parts.each do |arr|
      next unless arr[:rank]
      next if arr2[arr[:part]]
      next if arr3[arr[:part]]
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
    when 1 then draw_rank_line(view)
    when 2 then draw_lasso(view)
    end
  end
  def draw_sweep_rect(view)
    return unless @sweeping && @sweep_a && @sweep_b
    x210, x2 = @sweep_a.x.to_f, @sweep_b.x.to_f
    ay1, y2 = @sweep_a.y.to_f, @sweep_b.y.to_f
    pts = [
      Geom::Point3d.new([x210, x2].min, [ay1, y2].min, @plane_z),
      Geom::Point3d.new([x210, x2].max, [ay1, y2].min, @plane_z),
      Geom::Point3d.new([x210, x2].max, [ay1, y2].max, @plane_z),
      Geom::Point3d.new([x210, x2].min, [ay1, y2].max, @plane_z)
    ]
    KSU::View.draw_polygon2d(view, KSU::View.to_screen(pts))
    draw_sweep_arrow(view)
  end
  def draw_sweep_arrow(view)
    return if @clearing
    sweep = sweep_dir
    return unless sweep
    s = view.screen_coords(@sweep_a)
    ent = view.screen_coords(@sweep_b)
    extent_along = case sweep
              when :left_to_right, :right_to_left then (ent.x - s.x).abs
              else (ent.y - s.y).abs
              end
    return if extent_along < 24
    px = (s.x + ent.x) / 2.0
    py = (s.y + ent.y) / 2.0
    case sweep
    when :left_to_right
      ax0, ax1 = [s.x, ent.x].minmax
      KSU::View.draw_dim_arrow(view, ax0 + 10, py, ax1 - 12, py, :right)
    when :right_to_left
      ax0, ax1 = [s.x, ent.x].minmax
      KSU::View.draw_dim_arrow(view, ax1 - 10, py, ax0 + 12, py, :left)
    when :top_to_bottom
      ay0, ay1b = [s.y, ent.y].minmax
      KSU::View.draw_dim_arrow(view, px, ay0 + 10, px, ay1b - 12, :down)
    when :bottom_to_top
      ay0, ay1b = [s.y, ent.y].minmax
      KSU::View.draw_dim_arrow(view, px, ay1b - 10, px, ay0 + 12, :up)
    end
  end
  def draw_rank_line(view)
    return unless @rank_a && @rank_b
    KSU::View.draw_lines([@rank_a, @rank_b], guide: false, width: 1)
  end
  def draw_lasso(view)
    return if @lasso_pts.empty?
    pts = lasso_path
    return if pts.length < 2
    arr = []
    (pts.length - 1).times { |i| arr << pts[i] << pts[i + 1] }
    KSU::View.draw_lines(arr, guide: false, width: 1)
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
    left2 = resp.dig("data", "activations_left")
    return left2 unless left2.nil?
    resp2 = begin
      KSU::Chontam.validate_key(key)
    rescue StandardError
      nil
    end
    resp2 ? resp2.dig("data", "activations_left") : nil
  end
end
