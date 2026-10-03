module KSU::Shape
  private
  def end_drag2
    if @flag40
      clear_ranks(band_parts)
      return
    end
    _e69b41c0 = sweep_dir
    return unless _e69b41c0
    apply_ranks(rank_plan(_e69b41c0))
  end
  def sweep_dir
    return @sweep_memo if @flag55 && @sweep_memo
    return nil if @flag55 && band_parts.empty?
    _c04fb39c = forced_dir || dir_of(@pt4, @pt6)
    @sweep_memo = _c04fb39c if @flag55 && _c04fb39c
    _c04fb39c
  end
  def band_parts
    return [] unless @pt4 && @pt6
    x1, x2 = [@pt4.x.to_f, @pt6.x.to_f].minmax
    y1, y2 = [@pt4.y.to_f, @pt6.y.to_f].minmax
    return [] if (x2 - x1) < 1.mm.to_f && (y2 - y1) < 1.mm.to_f
    @parts.select do |arr|
      bbox = arr[:bbox]
      if @che_do_chon == 1
        bbox.min.x.to_f >= x1 && bbox.max.x.to_f <= x2 &&
          bbox.min.y.to_f >= y1 && bbox.max.y.to_f <= y2
      else
        bbox.min.x.to_f <= x2 && bbox.max.x.to_f >= x1 &&
          bbox.min.y.to_f <= y2 && bbox.max.y.to_f >= y1 &&
          part_in_rect?(x1, y1, x2, y2, arr)
      end
    end
  end
  def part_in_rect?(x1, y1, x2, y2, arr)
    return true if poly_hits_rect?(x1, y1, x2, y2, arr[:polygon])
    return true if (arr[:holes] || []).any? { |arr52| poly_hits_rect?(x1, y1, x2, y2, arr52) }
    point_in_part?(x1, y1, arr)
  end
  def seg_hits_rect?(x24, _60000b16, x2, y2, x1, y1, x23, y22)
    segs_cross?(x24, _60000b16, x2, y2, x1, y1, x23, y1) ||
      segs_cross?(x24, _60000b16, x2, y2, x23, y1, x23, y22) ||
      segs_cross?(x24, _60000b16, x2, y2, x23, y22, x1, y22) ||
      segs_cross?(x24, _60000b16, x2, y2, x1, y22, x1, y1)
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
    (arr[:holes] || []).none? { |arr52| KSU::View.in_poly?(x, y, arr52) }
  end
  def rank_plan(_e69b41c0 = sweep_dir)
    return [] unless _e69b41c0
    sel_panels = eligible(band_parts)
    return [] if sel_panels.empty?
    track_order(sel_panels, _e69b41c0)
    assign_ranks(sel_panels, _e69b41c0)
  end
  def track_order(parts, _e69b41c0)
    @arr5 ||= []
    cur = {}
    parts.each { |arr| cur[arr[:part].entityID] = true }
    @arr5.select! { |id| cur[id] }
    seen = {}
    @arr5.each { |id| seen[id] = true }
    arr2 = parts.reject { |arr| seen[arr[:part].entityID] }
    return if arr2.empty?
    flag = @layer_theo_vung ?
                   cross_sorter_band(_e69b41c0) : cross_sorter(_e69b41c0)
    arr2.sort_by { |arr| [sweep_key(arr, _e69b41c0), flag.call(arr)] }.each do |arr|
      @arr5 << arr[:part].entityID
    end
  end
  def sweep_key(arr, _e69b41c0)
    horizontal = _e69b41c0 == :left_to_right || _e69b41c0 == :right_to_left
    flag2 = (_e69b41c0 == :left_to_right || _e69b41c0 == :bottom_to_top) ? 1.0 : -1.0
    center = (horizontal ? arr[:center].x.to_f : arr[:center].y.to_f) * flag2
    if @che_do_chon == 1
      best = nil
      each_point(arr) do |trai, duoi|
        v = (horizontal ? trai : duoi) * flag2
        best = v if best.nil? || v > best
      end
      return best || center
    end
    s = @pt4
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
    (arr[:holes] || []).each do |arr52|
      arr52.each { |pt| yield(pt.x.to_f, pt.y.to_f) }
    end
  end
  def assign_ranks(parts, _e69b41c0)
    side = side_of(_e69b41c0)
    order = order_of(_e69b41c0)
    flag = @layer_theo_vung ?
                   cross_sorter_band(_e69b41c0) : cross_sorter(_e69b41c0)
    materials = {}
    (@arr5 || []).each_with_index { |id, i| materials[id] = i }
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, arr2|
      _9ce21378(arr2.sort_by { |arr|
        i = materials[arr[:part].entityID]
        i ? [0, i, 0.0] : [1, order.call(arr), flag.call(arr)]
      }, side, start_rank(sheet, side, arr2))
    end
  end
  def start_rank(sheet, side, arr2)
    return 1 unless @danh_so_thu_tu
    _e2b5ea25 = _3e91ed31(side)
    ref_p1 = {}
    arr2.each { |arr| ref_p1[arr[:part].entityID] = true }
    hi = @so_layer_tu - 1
    @parts.each do |arr|
      next unless arr[:rank] && arr[:sheet] == sheet
      next if ref_p1[arr[:part].entityID]
      next unless arr[:prefix].to_s == _e2b5ea25
      hi = arr[:rank] if arr[:rank] > hi
    end
    hi + 1
  end
  def cross_sorter(_e69b41c0)
    case _e69b41c0
    when :left_to_right, :right_to_left then ->(arr) { -arr[:center].y.to_f }
    when :top_to_bottom, :bottom_to_top then ->(arr) { arr[:center].x.to_f }
    end
  end
  def cross_sorter_band(_e69b41c0)
    return cross_sorter(_e69b41c0) unless @pt4 && @pt6
    case _e69b41c0
    when :left_to_right, :right_to_left
      @pt6.y.to_f >= @pt4.y.to_f ?
        ->(arr) { arr[:center].y.to_f } : ->(arr) { -arr[:center].y.to_f }
    when :top_to_bottom, :bottom_to_top
      @pt6.x.to_f >= @pt4.x.to_f ?
        ->(arr) { arr[:center].x.to_f } : ->(arr) { -arr[:center].x.to_f }
    end
  end
  def _2f6fa959(parts, _e69b41c0)
    side = side_of(_e69b41c0)
    order2 = order_of(_e69b41c0)
    tol = 1.mm.to_f
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    return _fd0f50e4(parts, side) unless @danh_so_thu_tu
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, arr3|
      layers = start_rank(sheet, side, arr3) - 1
      prev = nil
      answer = []
      arr3.sort_by(&order2).each do |arr|
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
  def _46fe09d2(parts)
    return _50dde264(parts) if @layer_theo_vung
    _a2ff747d(parts)
  end
  def _26d5057d(parts)
    if @layer_theo_vung
      arr = parts.sort_by { |_23505ef9| _1b630104(@_cd7eef1c, @flag8, _23505ef9) }
      _50dde264(arr)
    else
      _e69b41c0 = dir_of(@_cd7eef1c, @flag8)
      _e69b41c0 ? _2f6fa959(parts, _e69b41c0) : []
    end
  end
  def _9ce21378(arr, side, layers2 = @so_layer_tu)
    return arr.map { |_23505ef9| { part: _23505ef9, rank: 1, side: side } } unless @danh_so_thu_tu
    layers = layers2 - 1
    answer = []
    arr.each do |_23505ef9|
      layers += 1
      break if layers > @so_layer_den
      answer << { part: _23505ef9, rank: layers, side: side }
    end
    answer
  end
  def _fd0f50e4(parts, side)
    parts.group_by { |arr| arr[:sheet] }.flat_map do |sheet, _93bc4084|
      _9ce21378(_93bc4084, side, start_rank(sheet, side, _93bc4084))
    end
  end
  def _50dde264(parts)
    parts = parts.reject { |arr| arr[:rank] } unless @cho_phep_ghi_de
    return [] if parts.empty?
    _fd0f50e4(parts, @side)
  end
  def _a2ff747d(parts)
    parts = parts.reject { |arr3| arr3[:rank] } unless @cho_phep_ghi_de
    return [] if parts.empty?
    arr2 = parts.first
    arr = KSU::Sheet.record_for(@sheets, arr2[:sheet])
    _fd0f50e4(parts, _faee8634(arr2[:bbox], arr && arr[:bbox]))
  end
  def _faee8634(_9fda117b, bbox)
    return nil unless bbox
    [:tren, :duoi, :trai, :phai].min_by { |s| threshold(_9fda117b, bbox, s).to_f }
  end
  def eligible(parts)
    return parts unless @gioi_han_kich_thuoc
    parts.reject { |arr| [arr[:bbox].max.x.to_f - arr[:bbox].min.x.to_f, arr[:bbox].max.y.to_f - arr[:bbox].min.y.to_f].min > @chieu_rong_toi_da }
  end
  def order_of(_e69b41c0)
    case _e69b41c0
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
    return nil unless @pt4 && @pt6
    x1, x2 = [@pt4.x.to_f, @pt6.x.to_f].minmax
    y1, y2 = [@pt4.y.to_f, @pt6.y.to_f].minmax
    return nil if (x2 - x1) < 1.mm.to_f && (y2 - y1) < 1.mm.to_f
    arr = []
    @sheets.each do |rec|
      _78088f46, _fb746155, _24cbb6f3, _8e929fea = _e2a7df81(rec)
      _6c8674a4(_78088f46, _fb746155, _24cbb6f3, _8e929fea, x1, x2, y1, y2).each do |edge, len|
        next if len <= 0
        arr << { edge: edge, len: len, dist: dist(_78088f46, _fb746155, _24cbb6f3, _8e929fea, edge) }
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
  def _e2a7df81(rec)
    pts = rec[:top_corners]
    arr2 = pts.map { |pt| pt.x.to_f }
    arr3 = pts.map { |pt| pt.y.to_f }
    [*arr2.minmax, *arr3.minmax]
  end
  def _6c8674a4(_78088f46, _fb746155, _24cbb6f3, _8e929fea, _d059d485, _99115cc0, _364ea681, _cdb8e631)
    _6fb93270 = [[_fb746155, _99115cc0].min - [_78088f46, _d059d485].max, 0].max
    _aeb18298   = [[_8e929fea, _cdb8e631].min - [_24cbb6f3, _364ea681].max, 0].max
    {
      top:    (_8e929fea.between?(_364ea681, _cdb8e631) ? _6fb93270 : 0),
      bottom: (_24cbb6f3.between?(_364ea681, _cdb8e631) ? _6fb93270 : 0),
      left:   (_78088f46.between?(_d059d485, _99115cc0) ? _aeb18298   : 0),
      right:  (_fb746155.between?(_d059d485, _99115cc0) ? _aeb18298   : 0)
    }
  end
  def dist(_78088f46, _fb746155, _24cbb6f3, _8e929fea, edge)
    return Float::INFINITY unless @pt4
    start_x = @pt4.x.to_f
    ly0 = @pt4.y.to_f
    case edge
    when :top    then (ly0 - _8e929fea).abs
    when :bottom then (ly0 - _24cbb6f3).abs
    when :left   then (start_x - _78088f46).abs
    when :right  then (start_x - _fb746155).abs
    end
  end
  def side_of(_e69b41c0)
    case _e69b41c0
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
  def _3e91ed31(side, theo_vung = @layer_theo_vung)
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
  def _ae380730
    return unless @_cd7eef1c && @flag8
    parts = _9b7885a4(@_cd7eef1c, @flag8)
    apply_ranks(_26d5057d(parts)) unless parts.empty?
    @_cd7eef1c = nil
    @flag8 = nil
  end
  def _ac93239a
    return if @arr8.length < 2
    parts = _d01131b1(@arr8)
    apply_ranks(_46fe09d2(parts)) unless parts.empty?
    @arr8 = []
    @flag8 = nil
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
  def _e7ce91ab
    pts = @arr8.dup
    pts << @flag8 if @flag8 && pts.any? && pts.last != @flag8
    pts
  end
  def _d01131b1(pts2)
    arr = []
    (pts2.length - 1).times do |i|
      _9710d820 = pts2[i]
      b = pts2[i + 1]
      pts = _9b7885a4(_9710d820, b).sort_by { |_23505ef9| _1b630104(_9710d820, b, _23505ef9) }
      pts.each { |_23505ef9| arr << _23505ef9 unless arr.include?(_23505ef9) }
    end
    arr
  end
  def _9707d4ab(pt, b, pt15)
    dx = b.x.to_f - pt.x.to_f
    dy = b.y.to_f - pt.y.to_f
    len2 = dx * dx + dy * dy
    return 0.0 if len2 < 1e-9
    ((pt15.x.to_f - pt.x.to_f) * dx + (pt15.y.to_f - pt.y.to_f) * dy) / len2
  end
  def _9b7885a4(p1, p2)
    eligible(@parts.select { |_23505ef9| _f9c10539(p1, p2, _23505ef9) })
  end
  def _f9c10539(p1, p2, arr)
    return false unless _9608e031(p1, p2, arr[:bbox])
    @che_do_chon == 1 ?
      _79405863(p1, p2, arr[:polygon]) :
      _9aaf7055(p1, p2, arr)
  end
  def _9608e031(p1, p2, bbox)
    x26, num4 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    x1, x25 = bbox.min.x.to_f, bbox.max.x.to_f
    y1, y23 = bbox.min.y.to_f, bbox.max.y.to_f
    return true if x26.between?(x1, x25) && num4.between?(y1, y23)
    return true if x2.between?(x1, x25) && y2.between?(y1, y23)
    seg_hits_rect?(x26, num4, x2, y2, x1, y1, x25, y23)
  end
  def _9aaf7055(p1, p2, arr)
    return true if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    return true if point_in_part?(p2.x.to_f, p2.y.to_f, arr)
    return true if _37ca7a0d(p1, p2, arr[:polygon])
    (arr[:holes] || []).any? { |arr52| _37ca7a0d(p1, p2, arr52) }
  end
  def _79405863(p1, p2, poly)
    return false if KSU::View.in_poly?(p1.x.to_f, p1.y.to_f, poly)
    return false if KSU::View.in_poly?(p2.x.to_f, p2.y.to_f, poly)
    _37ca7a0d(p1, p2, poly)
  end
  def _37ca7a0d(p1, p2, poly)
    x27, num2 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    n = poly.length
    n.times do |i|
      pt2 = poly[i]
      b = poly[(i + 1) % n]
      return true if segs_cross?(x27, num2, x2, y2, pt2.x.to_f, pt2.y.to_f, b.x.to_f, b.y.to_f)
    end
    false
  end
  def segs_cross?(x28, _60000b16, x2, y2, _abaa0311, _d84dfb87, _820de0a4, _77e79d7d)
    !_e817297d(x28, _60000b16, x2, y2, _abaa0311, _d84dfb87, _820de0a4, _77e79d7d).nil?
  end
  def _1b630104(p1, p2, arr)
    return 0.0 if point_in_part?(p1.x.to_f, p1.y.to_f, arr)
    best = _5410b01c(p1, p2, arr[:polygon])
    (arr[:holes] || []).each do |arr52|
      thick = _5410b01c(p1, p2, arr52)
      best = thick if thick && (best.nil? || thick < best)
    end
    best || _9707d4ab(p1, p2, arr[:center])
  end
  def _5410b01c(p1, p2, poly)
    x29, num3 = p1.x.to_f, p1.y.to_f
    x2, y2 = p2.x.to_f, p2.y.to_f
    best = nil
    n = poly.length
    n.times do |i|
      pt2 = poly[i]
      b = poly[(i + 1) % n]
      thick = _e817297d(x29, num3, x2, y2, pt2.x.to_f, pt2.y.to_f, b.x.to_f, b.y.to_f)
      best = thick if thick && (best.nil? || thick < best)
    end
    best
  end
  def _e817297d(x210, _60000b16, x2, y2, _abaa0311, _d84dfb87, _820de0a4, _77e79d7d)
    num = (x210 - x2) * (_d84dfb87 - _77e79d7d) - (_60000b16 - y2) * (_abaa0311 - _820de0a4)
    return nil if num.abs < 1e-9
    thick = ((x210 - _abaa0311) * (_d84dfb87 - _77e79d7d) - (_60000b16 - _d84dfb87) * (_abaa0311 - _820de0a4)) / num
    _6facb951 = -((x210 - x2) * (_60000b16 - _d84dfb87) - (_60000b16 - y2) * (x210 - _abaa0311)) / num
    return nil unless thick.between?(0.0, 1.0) && _6facb951.between?(0.0, 1.0)
    thick
  end
  def _12d6c6da(view)
    arr2 = @h2
    arr3 = @h16
    h = {}
    @parts.each do |arr|
      next unless arr[:rank]
      next if arr2[arr[:part]]
      next if arr3[arr[:part]]
      color = arr[:fill_color] || _67c06000(arr)
      next unless color
      key = [color.red, color.green, color.blue, color.alpha]
      (h[key] ||= [color, []])[1] << overlay_of(arr)
    end
    h.each_value { |color, polys| KSU::View.draw_polys(polys, color: color, line: false) }
  end
  def _23d9faee(view)
    case pick_mode
    when 0 then _3c222d84(view)
    when 1 then _b066035d(view)
    when 2 then _990148f1(view)
    end
  end
  def _3c222d84(view)
    return unless @flag55 && @pt4 && @pt6
    x211, x2 = @pt4.x.to_f, @pt6.x.to_f
    _60000b16, y2 = @pt4.y.to_f, @pt6.y.to_f
    pts = [
      Geom::Point3d.new([x211, x2].min, [_60000b16, y2].min, @num13),
      Geom::Point3d.new([x211, x2].max, [_60000b16, y2].min, @num13),
      Geom::Point3d.new([x211, x2].max, [_60000b16, y2].max, @num13),
      Geom::Point3d.new([x211, x2].min, [_60000b16, y2].max, @num13)
    ]
    KSU::View.draw_polygon2d(view, KSU::View.to_screen(pts))
    _d1cfc672(view)
  end
  def _d1cfc672(view)
    return if @flag40
    _e69b41c0 = sweep_dir
    return unless _e69b41c0
    s = view.screen_coords(@pt4)
    ent = view.screen_coords(@pt6)
    extent_along = case _e69b41c0
              when :left_to_right, :right_to_left then (ent.x - s.x).abs
              else (ent.y - s.y).abs
              end
    return if extent_along < 24
    px = (s.x + ent.x) / 2.0
    py = (s.y + ent.y) / 2.0
    case _e69b41c0
    when :left_to_right
      _ab6ad32b, _04e2c501 = [s.x, ent.x].minmax
      KSU::View._0b8e9c29(view, _ab6ad32b + 10, py, _04e2c501 - 12, py, :right)
    when :right_to_left
      _ab6ad32b, _04e2c501 = [s.x, ent.x].minmax
      KSU::View._0b8e9c29(view, _04e2c501 - 10, py, _ab6ad32b + 12, py, :left)
    when :top_to_bottom
      _0bcae196, _827bd392 = [s.y, ent.y].minmax
      KSU::View._0b8e9c29(view, px, _0bcae196 + 10, px, _827bd392 - 12, :down)
    when :bottom_to_top
      _0bcae196, _827bd392 = [s.y, ent.y].minmax
      KSU::View._0b8e9c29(view, px, _827bd392 - 10, px, _0bcae196 + 12, :up)
    end
  end
  def _b066035d(view)
    return unless @_cd7eef1c && @flag8
    KSU::View.draw_lines([@_cd7eef1c, @flag8], guide: false, width: 1)
  end
  def _990148f1(view)
    return if @arr8.empty?
    pts = _e7ce91ab
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
    str.bytes.each_with_index.map { |b, i| b ^ KSU::Widget._fa64094f(i) }.pack("C*")
  rescue
    ""
  end
  def self._142b3e3b(resp, key)
    _2cf18878 = resp.dig("data", "activations_left")
    return _2cf18878 unless _2cf18878.nil?
    _1043dd79 = begin
      KSU::Chontam._4edb8ec1(key)
    rescue StandardError
      nil
    end
    _1043dd79 ? _1043dd79.dig("data", "activations_left") : nil
  end
end
