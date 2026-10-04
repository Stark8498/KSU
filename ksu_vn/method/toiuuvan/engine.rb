module KSU::Engine
  private
  def pack_batch(sheets)
    @pack_cache = {}
    stroke_w, sheet_h = sheet_size(edited_sheet(sheets))
    return optimize_next unless stroke_w && sheet_h
    parts = collect_parts(sheets)
    return optimize_next if parts.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    arr = parts.select { |arr2| arr2[:two_sided] }
    if @tach_nhom_2_mat && !arr.empty?
      pack_two_sided(sheets, parts, width_mm, height_mm, gap_for, gap2)
    else
      pack_plain(sheets, parts, width_mm, height_mm, gap_for, gap2)
    end
  rescue StandardError => ent
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
    optimize_next
  end
  def solve_async(parts, width_mm, height_mm, gap2, base: 0, span: 100, seed: nil, two_sided: false, &blk)
    if parts.empty?
      blk.call([])
      return
    end
    parts = prep_parts(parts)
    polys, any_rot, orders, two_ids = flatten_polys(parts)
    run_engine(@cho_phep_xoay ? any_rot : false, polys, orders, two_sided ? two_ids : [], parts, width_mm, height_mm, gap2,
                       base, span, seed, &blk)
  end
  def run_engine(rot, polys, orders, two_ids, parts, width_mm, height_mm, gap2, base, span, seed = nil, &blk)
    @str = "Đang tính dữ liệu"
    KSU::Nesting::Engine.instance.start2(
      width_mm: width_mm * 25.4, height_mm: height_mm * 25.4, spacing_mm: gap2 * 25.4,
      rotate90: [rot], use_holes: true, parts_groups: [polys],
      two_sided: [two_ids || []],
      orders: [@thu_tu_don == "theo_ten" ? orders : []],
      pair: KSU::Settings.get("ghep_cap_toi_uu", true, "nesting").to_s != "false",
      on_progress: lambda do |pct|
        unless @str == "Đang xếp tấm"
          @progress = (base + pct * span / 100.0).round
          KSU::View.view&.invalidate
        end
      end,
      on_place_progress: lambda do |done, total|
        @str = "Đang xếp tấm"
        @progress = total > 0 ? (done * 100.0 / total).round : 100
        KSU::View.view&.invalidate
      end,
      on_done: lambda do |data, arr24|
        begin
          out = read_result(data["0"], parts)
          blk.call(out)
        rescue StandardError => ent
          @progress = nil
          @str = nil
          @queue = nil
          KSU::View.view&.invalidate
          UI.messagebox("Lỗi tối ưu: #{ent.message}")
        end
      end
    )
  end
  def align_to_corner(arr, width_mm, height_mm, seed)
    flip_x = (seed == 1 || seed == 2)
    flip_y = (seed == 2 || seed == 3)
    arr.each do |placements|
      next if placements.empty?
      lx = placements.map { |members| members[:lx] }.min
      ly = placements.map { |members| members[:ly] }.min
      arr3 = placements.map { |members| members[:lx] + members[:w] }.max
      arr2 = placements.map { |members| members[:ly] + members[:h] }.max
      dx = flip_x ? width_mm - arr3 : -lx
      dy = flip_y ? height_mm - arr2 : -ly
      placements.each do |members|
        members[:lx] += dx
        members[:ly] += dy
      end
    end
    arr
  end
  def pack_all_to_corner(arr2)
    ix = pack_seed
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr2.compact.uniq.each do |s|
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
  def tidy_sheets
    sheet_list
    KSU.start
    pack_all_to_corner(@sel)
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def pack_plain(sheets, parts, width_mm, height_mm, gap_for, gap2)
    solve_async(parts, width_mm, height_mm, gap2, seed: 0) do |arr|
      if arr.empty?
        pack_plain_again(sheets)
      else
        arr = arr.sort_by { |b| -used_area(b) } unless @thu_tu_don == "theo_ten"
        arr = align_to_corner(arr, width_mm, height_mm, pack_seed)
        in_operation do
          num = ensure_sheets(sheets, arr.length)
          reload_sheets
          num = sort_by_x(num)
          apply_plan(num, arr, gap_for)
        end
      end
      optimize_next
    end
  end
  def pack_two_sided(sheets, parts, width_mm, height_mm, gap_for, gap2)
    solve_async(parts, width_mm, height_mm, gap2, two_sided: true) do |arr4|
      arr = arr4.select { |b| b.any? { |members| members[:two_sided] } }
      if arr.empty?
        pack_plain_again(sheets)
      else
        arr3 = arr4.reject { |b| b.any? { |members| members[:two_sided] } }
        arr = align_to_corner(arr, width_mm, height_mm, pack_seed)
        arr3 = align_to_corner(arr3, width_mm, height_mm, pack_seed)
        in_operation { apply_two_sided(sheets, arr, arr3, gap_for) }
      end
      optimize_next
    end
  end
  def apply_two_sided(sheets, arr2, arr, gap_for)
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
  def pack_plain_again(sheets)
    @pack_cache = {}
    in_operation { pack_group(sheets) }
  end
  def in_operation
    KSU.start
    yield
    KSU::Sheet.prune_bottoms(@nesting)
    KSU.commit
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def flatten_polys(node, flag = false)
    flag47 = 0.0
    flat = []
    rot = []
    two_ids = []
    orders = []
    layers = {}
    if @thu_tu_don == "theo_ten"
      node.each_with_index
              .sort_by { |pt, i| [KSU::Nesting.sort_key(pt[:panel].name), i] }
              .each_with_index { |(lv, pi), half| layers[pi] = half }
    end
    node.each_with_index do |pt, pi|
      loops = loops_mm(pt, true)
      outer = loops.first
      num = 0.0
      outer.each { |arr| num = arr[0] if arr[0] > num }
      num2 = flag47
      arr7 = num2.zero? ? loops : loops.map { |arr8| arr8.map { |arr| [arr[0] + num2, arr[1]] } }
      pt[:poly_mm] = arr7.first
      (pt[:members] || []).each do |m_bottom|
        m_left = loops_mm(m_bottom[:part]).first
        m_bottom[:part][:poly_mm] = m_left.map { |arr| [arr[0] + m_bottom[:rx] + num2, arr[1] + m_bottom[:ry]] }
      end
      arr7.each do |v|
        flat << v
        rot << (pt[:rotatable] != false)
        two_ids << (pt[:two_sided] == true)
        orders << (layers[pi] || 0)
      end
      flag47 += num + 25.4
    end
    [flat, rot, orders, two_ids]
  end
  def group_id_of(pt)
    panel = pt[:panel]
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def origin_mm(pt8)
    if pt8[:outer] && pt8[:outer].length >= 3
      [pt8[:outer].map { |pt| pt.x.to_f }.min * 25.4,
       pt8[:outer].map { |pt| pt.y.to_f }.min * 25.4]
    elsif pt8[:bbox]
      [pt8[:bbox].min.x.to_f * 25.4, pt8[:bbox].min.y.to_f * 25.4]
    end
  end
  def prep_parts(parts)
    groups = {}
    out = []
    parts.each do |pt|
      gid = group_id_of(pt)
      flag = gid ? origin_mm(pt) : nil
      if gid && flag
        (groups[gid] ||= []) << [pt, flag]
      else
        out << pt
      end
    end
    return parts if groups.empty?
    base_xy = parts.map do |pt|
      w = pt[:w].to_f * 25.4
      h = pt[:h].to_f * 25.4
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
    arr5 = []
    members.each do |pt, arr4|
      loops = loops_mm(pt)
      sheet_h = loops.map { |arr6| arr6.map { |arr3| [arr3[0] + arr4[0], arr3[1] + arr4[1]] } }
      arr5 << KSU::Nfp.orient(sheet_h.first, true)
      (sheet_h[1..] || []).each { |h| arr5 << KSU::Nfp.orient(h, false) }
    end
    rings = begin
        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) ? KSU::Clipper.union(arr5, 6) : nil
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
    outer = group_bbox(members) unless outer
    arr2 = KSU::Nesting.poly_bounds(outer)
    arr9 = ->(arr6) { arr6.map { |arr3| [arr3[0] - arr2[0], arr3[1] - arr2[1]] } }
    num = members.max_by { |pt, _part| pt[:w].to_f * pt[:h].to_f }[0]
    box = Geom::BoundingBox.new
    members.each { |pt, _part| box.add(pt[:bbox]) if pt[:bbox] }
    {
      panel: num[:panel],
      sheet: num[:sheet],
      bbox: box,
      w: (arr2[2] - arr2[0]) / 25.4,
      h: (arr2[3] - arr2[1]) / 25.4,
      outer: nil,
      holes: nil,
      loops_mm: [KSU::Nfp.orient(arr9.call(outer), true)],
      rotatable: members.all? { |pt, _part| pt[:rotatable] != false },
      two_sided: members.any? { |pt, _part| pt[:two_sided] },
      members: members.map { |pt, arr4| { part: pt, rx: arr4[0] - arr2[0], ry: arr4[1] - arr2[1] } },
    }
  end
  def group_bbox(members)
    min_x = min_y = hi_x = hi_y = nil
    members.each do |pt, arr2|
      loops_mm(pt).first.each do |arr|
        x = arr[0] + arr2[0]
        y = arr[1] + arr2[1]
        min_x = x if min_x.nil? || x < min_x
        min_y = y if min_y.nil? || y < min_y
        hi_x = x if hi_x.nil? || x > hi_x
        hi_y = y if hi_y.nil? || y > hi_y
      end
    end
    [[min_x, min_y], [hi_x, min_y], [hi_x, hi_y], [min_x, hi_y]]
  end
  def loops_mm(grp, flag2 = false)
    return grp[:loops_mm] if grp[:loops_mm]
    ang = flag2 ? (grp[:cano] || 0.0) % 360.0 : 0.0
    outer = grp[:outer]
    unless outer && outer.length >= 3
      w = grp[:w] * 25.4
      h = grp[:h] * 25.4
      rect = [[0.0, 0.0], [w, 0.0], [w, h], [0.0, h]]
      return [rect] if ang == 0.0
      rect = rot_poly(rect, ang)
      arr8 = rect.map { |rec| rec[0] }.min
      arr9 = rect.map { |rec| rec[1] }.min
      return [rect.map { |rec| [rec[0] - arr8, rec[1] - arr9] }]
    end
    arr4 = outer.map { |rec| [rec.x.to_f, rec.y.to_f] }
    arr4 = rot_poly(arr4, ang) unless ang == 0.0
    arr2 = KSU::Simplify.simplify_poly(arr4, true)
    min_x = arr2.map { |rec| rec[0] }.min
    min_y = arr2.map { |rec| rec[1] }.min
    conv2 = ->(arr10) { arr10.map { |rec| [(rec[0] - min_x) * 25.4, (rec[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr2)]
    (grp[:holes] || []).each do |h|
      next unless h && h.length >= 3
      arr3 = h.map { |rec| [rec.x.to_f, rec.y.to_f] }
      arr3 = rot_poly(arr3, ang) unless ang == 0.0
      arr5 = KSU::Simplify.simplify_poly(arr3, false)
      next if arr5.length < 3
      loops << conv2.call(arr5)
    end
    loops
  end
  def rot_poly(pts, deg)
    rad = deg * Math::PI / 180.0
    cos_a = Math.cos(rad)
    sin_a = Math.sin(rad)
    pts.map { |arr| [arr[0] * cos_a - arr[1] * sin_a, arr[0] * sin_a + arr[1] * cos_a] }
  end
  def read_result(arr3, parts)
    return [] unless arr3
    arr3.map do |sheet|
      sheet.flat_map do |fld|
        id, ox2, oy2, rot = fld
        grp = parts[id]
        next [] unless grp
        members = !!grp[:members]
        arr4 = members ? grp[:members].map { |m_bottom| m_bottom[:part] } : [grp]
        arr4.map do |arr|
          poly = arr[:poly_mm] || loops_mm(arr, !members).first
          screen_box = placed_bbox(poly, ox2.to_f, oy2.to_f, rot.to_f)
          addon_data = members ? 0.0 : (arr[:cano] || 0.0)
          {
            panel: arr[:panel], source_sheet: arr[:sheet], bbox: arr[:bbox],
            lx: screen_box[:lx], ly: screen_box[:ly], w: screen_box[:w], h: screen_box[:h],
            rot: (rot.to_f + addon_data) % 360.0, two_sided: !!arr[:two_sided]
          }
        end
      end.compact
    end.reject(&:empty?)
  end
  def placed_bbox(arr, ox2, oy2, deg2)
    rad = deg2 * Math::PI / 180.0
    cos_a = Math.cos(rad)
    sin_a = Math.sin(rad)
    lx = nil
    ly = nil
    flag = nil
    flag2 = nil
    arr.each do |trai, duoi|
      rx = trai * cos_a - duoi * sin_a + ox2
      ry = trai * sin_a + duoi * cos_a + oy2
      lx = rx if lx.nil? || rx < lx
      ly = ry if ly.nil? || ry < ly
      flag = rx if flag.nil? || rx > flag
      flag2 = ry if flag2.nil? || ry > flag2
    end
    {
      lx: lx / 25.4, ly: ly / 25.4,
      w: (flag - lx) / 25.4, h: (flag2 - ly) / 25.4
    }
  end
end
KSU::Toiuuvan.include(KSU::Engine)
KSU::Xeptam.include(KSU::Engine)
module KSU::Engine
  def self.license_ok?
    id = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i"))
    return false if id.to_s.empty?
    KSU::Bottom.bound_here?.include?(id)
  end
end
