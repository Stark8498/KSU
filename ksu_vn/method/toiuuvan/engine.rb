module KSU::Engine
  private
  def pack_batch_v1(sheets)
    @pack_cache = {}
    stroke_w, sheet_h = sheet_size(edited_sheet(sheets))
    return optimize_next_v1 unless stroke_w && sheet_h
    parts = collect_parts(sheets)
    return optimize_next_v1 if parts.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    arr = parts.select { |arr2| arr2[:two_sided] }
    if @tach_nhom_2_mat && !arr.empty?
      pack_two_sided_v1(sheets, parts, width_mm, height_mm, gap_for, gap2)
    else
      pack_plain_v1(sheets, parts, width_mm, height_mm, gap_for, gap2)
    end
  rescue StandardError => ent
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
    optimize_next_v1
  end
  def solve_async_v1(parts, width_mm, height_mm, gap2, base: 0, span: 100, seed: nil, two_sided: false, &blk)
    if parts.empty?
      blk.call([])
      return
    end
    parts = prep_parts_v1(parts)
    polys, any_rot, orders, two_ids = flatten_polys_v1(parts)
    run_engine(@cho_phep_xoay ? any_rot : false, polys, orders, two_sided ? two_ids : [], parts, width_mm, height_mm, gap2,
                       base, span, seed, &blk)
  end
  def run_engine(rot, polys, orders, two_ids, parts, width_mm, height_mm, gap2, base, span, seed = nil, &blk)
    @str2 = "Đang tính dữ liệu"
    KSU::Nesting::Engine.instance.start2(
      width_mm: width_mm * 25.4, height_mm: height_mm * 25.4, spacing_mm: gap2 * 25.4,
      rotate90: [rot], use_holes: true, parts_groups: [polys],
      two_sided: [two_ids || []],
      orders: [@thu_tu_don == "theo_ten" ? orders : []],
      pair: KSU::Settings.get("ghep_cap_toi_uu", true, "nesting").to_s != "false",
      on_progress: lambda do |pct|
        unless @str2 == "Đang xếp tấm"
          @progress = (base + pct * span / 100.0).round
          KSU::View.view&.invalidate
        end
      end,
      on_place_progress: lambda do |done, total|
        @str2 = "Đang xếp tấm"
        @progress = total > 0 ? (done * 100.0 / total).round : 100
        KSU::View.view&.invalidate
      end,
      on_done: lambda do |data, _64e7aa65|
        begin
          _0850aa4d = read_result_v1(data["0"], parts)
          blk.call(_0850aa4d)
        rescue StandardError => ent
          @progress = nil
          @str2 = nil
          @queue = nil
          KSU::View.view&.invalidate
          UI.messagebox("Lỗi tối ưu: #{ent.message}")
        end
      end
    )
  end
  def align_to_corner_v1(arr, width_mm, height_mm, seed)
    _d6439c88 = (seed == 1 || seed == 2)
    _ab593548 = (seed == 2 || seed == 3)
    arr.each do |placements|
      next if placements.empty?
      lx = placements.map { |members| members[:lx] }.min
      ly = placements.map { |members| members[:ly] }.min
      arr3 = placements.map { |members| members[:lx] + members[:w] }.max
      arr2 = placements.map { |members| members[:ly] + members[:h] }.max
      dx = _d6439c88 ? width_mm - arr3 : -lx
      dy = _ab593548 ? height_mm - arr2 : -ly
      placements.each do |members|
        members[:lx] += dx
        members[:ly] += dy
      end
    end
    arr
  end
  def pack_all_to_corner_v1(arr)
    ix = pack_seed
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr.compact.uniq.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom_of(s, @nesting)
      rec = sheet_recs.find { |i| i[:instance] == s }
      next unless rec
      KSU::Nesting.pack_to_corner(@nesting, s, rec, ix, gap_for, gap2)
    end
  rescue StandardError
    nil
  end
  def tidy_sheets_v1
    sheet_list
    KSU.start
    pack_all_to_corner_v1(@sel)
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def pack_plain_v1(sheets, parts, width_mm, height_mm, gap_for, gap2)
    solve_async_v1(parts, width_mm, height_mm, gap2, seed: 0) do |arr|
      if arr.empty?
        pack_plain_again_v1(sheets)
      else
        arr = arr.sort_by { |b| -used_area(b) } unless @thu_tu_don == "theo_ten"
        arr = align_to_corner_v1(arr, width_mm, height_mm, pack_seed)
        in_operation_v1 do
          num = ensure_sheets(sheets, arr.length)
          reload_sheets
          num = sort_by_x(num)
          apply_plan(num, arr, gap_for)
        end
      end
      optimize_next_v1
    end
  end
  def pack_two_sided_v1(sheets, parts, width_mm, height_mm, gap_for, gap2)
    solve_async_v1(parts, width_mm, height_mm, gap2, two_sided: true) do |arr3|
      arr = arr3.select { |b| b.any? { |members| members[:two_sided] } }
      if arr.empty?
        pack_plain_again_v1(sheets)
      else
        arr2 = arr3.reject { |b| b.any? { |members| members[:two_sided] } }
        arr = align_to_corner_v1(arr, width_mm, height_mm, pack_seed)
        arr2 = align_to_corner_v1(arr2, width_mm, height_mm, pack_seed)
        in_operation_v1 { apply_two_sided_v1(sheets, arr, arr2, gap_for) }
      end
      optimize_next_v1
    end
  end
  def apply_two_sided_v1(sheets, arr2, arr, gap_for)
    unless @thu_tu_don == "theo_ten"
      arr2 = arr2.sort_by { |b| [-b.inject(0.0) { |s, members| members[:two_sided] ? s + members[:w].to_f * members[:h].to_f : s }, -used_area(b)] } unless arr2.empty?
      arr = arr.sort_by { |b| -used_area(b) } unless arr.empty?
    end
    if pack_to_row_start?
      num = arr2.empty? ? [] : ensure_sheets(sheets, arr2.length)
      num2 = arr.empty? ? [] : add_sheets(arr.length, sheets)
      @added.concat(num2)
    else
      num2 = arr.empty? ? [] : ensure_sheets(sheets, arr.length)
      num = arr2.empty? ? [] : add_sheets(arr2.length, sheets)
      @added.concat(num)
      arr = arr.reverse
    end
    reload_sheets
    num = sort_by_x(num)
    num2 = sort_by_x(num2)
    apply_plan(num2, arr, gap_for) unless arr.empty?
    apply_plan(num, arr2, gap_for) unless arr2.empty?
  end
  def pack_plain_again_v1(sheets)
    @pack_cache = {}
    in_operation_v1 { pack_group(sheets) }
  end
  def in_operation_v1
    KSU.start
    yield
    KSU::Sheet.prune_bottoms(@nesting)
    KSU.commit
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def flatten_polys_v1(node, flag = false)
    num3 = 0.0
    flat = []
    rot = []
    two_ids = []
    orders = []
    layers = {}
    if @thu_tu_don == "theo_ten"
      node.each_with_index
              .sort_by { |arr2, i| [KSU::Nesting.sort_key(arr2[:panel].name), i] }
              .each_with_index { |(lv, pi), half| layers[pi] = half }
    end
    node.each_with_index do |arr2, pi|
      loops = loops_mm_v1(arr2, true)
      outer = loops.first
      num2 = 0.0
      outer.each { |arr| num2 = arr[0] if arr[0] > num2 }
      num = num3
      arr3 = num.zero? ? loops : loops.map { |arr4| arr4.map { |arr| [arr[0] + num, arr[1]] } }
      arr2[:poly_mm] = arr3.first
      (arr2[:members] || []).each do |m_bottom|
        m_left = loops_mm_v1(m_bottom[:part]).first
        m_bottom[:part][:poly_mm] = m_left.map { |arr| [arr[0] + m_bottom[:rx] + num, arr[1] + m_bottom[:ry]] }
      end
      arr3.each do |_b41d8800|
        flat << _b41d8800
        rot << (arr2[:rotatable] != false)
        two_ids << (arr2[:two_sided] == true)
        orders << (layers[pi] || 0)
      end
      num3 += num2 + 25.4
    end
    [flat, rot, orders, two_ids]
  end
  def group_id_of_v1(arr)
    panel = arr[:panel]
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def origin_mm_v1(arr)
    if arr[:outer] && arr[:outer].length >= 3
      [arr[:outer].map { |pt| pt.x.to_f }.min * 25.4,
       arr[:outer].map { |pt| pt.y.to_f }.min * 25.4]
    elsif arr[:bbox]
      [arr[:bbox].min.x.to_f * 25.4, arr[:bbox].min.y.to_f * 25.4]
    end
  end
  def prep_parts_v1(parts)
    groups = {}
    out = []
    parts.each do |arr|
      gid = group_id_of_v1(arr)
      flag = gid ? origin_mm_v1(arr) : nil
      if gid && flag
        (groups[gid] ||= []) << [arr, flag]
      else
        out << arr
      end
    end
    return parts if groups.empty?
    base_xy = parts.map do |arr|
      w = arr[:w].to_f * 25.4
      h = arr[:h].to_f * 25.4
      [[w, h].min, [w, h].max]
    end
    groups.each_value do |members|
      if members.length < 2
        members.each { |meta| out << meta[0] }
      else
        out << group_poly(members, base_xy)
      end
    end
    out
  end
  def group_poly(members, base_xy)
    arr6 = []
    members.each do |arr, arr4|
      loops = loops_mm_v1(arr)
      sheet_h = loops.map { |arr5| arr5.map { |arr3| [arr3[0] + arr4[0], arr3[1] + arr4[1]] } }
      arr6 << KSU::Nfp.orient(sheet_h.first, true)
      (sheet_h[1..] || []).each { |h| arr6 << KSU::Nfp.orient(h, false) }
    end
    rings = begin
        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) ? KSU::Clipper.union(arr6, 6) : nil
      rescue StandardError
        nil
      end
    outer = nil
    holes = []
    if rings && !rings.empty?
      arr7 = rings.select { |half| half && half.length >= 3 }
      outer = arr7.max_by { |half| KSU::Nesting.poly_area(half) }
      arr7.each do |half|
        next if half.equal?(outer)
        if outer && KSU::Nesting.point_in_poly?(half[0], outer)
          holes << half
        else
          outer = nil
          break
        end
      end
    end
    outer = nil if outer && KSU::Nesting.poly_area(outer) < 1.0
    outer = group_bbox_v1(members) unless outer
    arr2 = KSU::Nesting.poly_bounds(outer)
    arr8 = ->(arr5) { arr5.map { |arr3| [arr3[0] - arr2[0], arr3[1] - arr2[1]] } }
    _a46bb2b4 = members.max_by { |arr, _part| arr[:w].to_f * arr[:h].to_f }[0]
    box = Geom::BoundingBox.new
    members.each { |arr, _part| box.add(arr[:bbox]) if arr[:bbox] }
    {
      panel: _a46bb2b4[:panel],
      sheet: _a46bb2b4[:sheet],
      bbox: box,
      w: (arr2[2] - arr2[0]) / 25.4,
      h: (arr2[3] - arr2[1]) / 25.4,
      outer: nil,
      holes: nil,
      loops_mm: [KSU::Nfp.orient(arr8.call(outer), true)],
      rotatable: members.all? { |arr, _part| arr[:rotatable] != false },
      two_sided: members.any? { |arr, _part| arr[:two_sided] },
      members: members.map { |arr, arr4| { part: arr, rx: arr4[0] - arr2[0], ry: arr4[1] - arr2[1] } },
    }
  end
  def group_bbox_v1(members)
    min_x = min_y = hi_x = hi_y = nil
    members.each do |_63629225, arr|
      loops_mm_v1(_63629225).first.each do |arr2|
        x = arr2[0] + arr[0]
        y = arr2[1] + arr[1]
        min_x = x if min_x.nil? || x < min_x
        min_y = y if min_y.nil? || y < min_y
        hi_x = x if hi_x.nil? || x > hi_x
        hi_y = y if hi_y.nil? || y > hi_y
      end
    end
    [[min_x, min_y], [hi_x, min_y], [hi_x, hi_y], [min_x, hi_y]]
  end
  def loops_mm_v1(grp, flag = false)
    return grp[:loops_mm] if grp[:loops_mm]
    ang = flag ? (grp[:cano] || 0.0) % 360.0 : 0.0
    outer = grp[:outer]
    unless outer && outer.length >= 3
      w = grp[:w] * 25.4
      h = grp[:h] * 25.4
      rect_v1 = [[0.0, 0.0], [w, 0.0], [w, h], [0.0, h]]
      return [rect_v1] if ang == 0.0
      rect_v1 = rot_poly_v1(rect_v1, ang)
      arr7 = rect_v1.map { |pt4| pt4[0] }.min
      arr6 = rect_v1.map { |pt4| pt4[1] }.min
      return [rect_v1.map { |pt4| [pt4[0] - arr7, pt4[1] - arr6] }]
    end
    arr3 = outer.map { |pt4| [pt4.x.to_f, pt4.y.to_f] }
    arr3 = rot_poly_v1(arr3, ang) unless ang == 0.0
    arr = KSU::Simplify.simplify_poly(arr3, true)
    min_x = arr.map { |pt4| pt4[0] }.min
    min_y = arr.map { |pt4| pt4[1] }.min
    conv2 = ->(arr5) { arr5.map { |pt4| [(pt4[0] - min_x) * 25.4, (pt4[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr)]
    (grp[:holes] || []).each do |h|
      next unless h && h.length >= 3
      arr2 = h.map { |pt4| [pt4.x.to_f, pt4.y.to_f] }
      arr2 = rot_poly_v1(arr2, ang) unless ang == 0.0
      arr4 = KSU::Simplify.simplify_poly(arr2, false)
      next if arr4.length < 3
      loops << conv2.call(arr4)
    end
    loops
  end
  def rot_poly_v1(pts, deg)
    rad = deg * Math::PI / 180.0
    cos_a = Math.cos(rad)
    sin_a = Math.sin(rad)
    pts.map { |arr| [arr[0] * cos_a - arr[1] * sin_a, arr[0] * sin_a + arr[1] * cos_a] }
  end
  def read_result_v1(arr2, parts)
    return [] unless arr2
    arr2.map do |sheet|
      sheet.flat_map do |fld|
        id, ox2, oy2, rot = fld
        grp = parts[id]
        next [] unless grp
        members = !!grp[:members]
        arr3 = members ? grp[:members].map { |m_bottom| m_bottom[:part] } : [grp]
        arr3.map do |arr|
          poly = arr[:poly_mm] || loops_mm_v1(arr, !members).first
          screen_box_v1 = placed_bbox_v1(poly, ox2.to_f, oy2.to_f, rot.to_f)
          addon_data = members ? 0.0 : (arr[:cano] || 0.0)
          {
            panel: arr[:panel], source_sheet: arr[:sheet], bbox: arr[:bbox],
            lx: screen_box_v1[:lx], ly: screen_box_v1[:ly], w: screen_box_v1[:w], h: screen_box_v1[:h],
            rot: (rot.to_f + addon_data) % 360.0, two_sided: !!arr[:two_sided]
          }
        end
      end.compact
    end.reject(&:empty?)
  end
  def placed_bbox_v1(arr, ox2, oy2, deg2)
    rad = deg2 * Math::PI / 180.0
    cos_a = Math.cos(rad)
    sin_a = Math.sin(rad)
    lx = nil
    ly = nil
    flag2 = nil
    flag = nil
    arr.each do |trai, duoi|
      rx = trai * cos_a - duoi * sin_a + ox2
      ry = trai * sin_a + duoi * cos_a + oy2
      lx = rx if lx.nil? || rx < lx
      ly = ry if ly.nil? || ry < ly
      flag2 = rx if flag2.nil? || rx > flag2
      flag = ry if flag.nil? || ry > flag
    end
    {
      lx: lx / 25.4, ly: ly / 25.4,
      w: (flag2 - lx) / 25.4, h: (flag - ly) / 25.4
    }
  end
end
KSU::Toiuuvan.include(KSU::Engine)
KSU::Xeptam.include(KSU::Engine)
module KSU::Engine
  def self.license_ok_v1?
    id = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i"))
    return false if id.to_s.empty?
    KSU::Bottom.bound_here?.include?(id)
  end
end
