module KSU::Engine
  private
  def pack_batch(sheets)
    @pack_cache = {}
    stroke_w, sheet_h = sheet_size(edited_sheet(sheets))
    return optimize_next unless stroke_w && sheet_h
    arr29 = collect_parts(sheets)
    return optimize_next if arr29.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    if @tach_nhom_2_mat && arr29.any? { |arr| arr[:two_sided] }
      pack_two_sided(sheets, arr29, width_mm, height_mm, gap_for, gap2)
    else
      pack_plain(sheets, arr29, width_mm, height_mm, gap_for, gap2)
    end
  rescue StandardError => e
    UI.messagebox("Lỗi tối ưu: #{e.message}")
    optimize_next
  end
  def solve_async(arr29, width_mm, height_mm, gap2, two_sided: false, &blk)
    arr29 = prep_parts(arr29)
    polys, any_rot, orders, two_ids = flatten_polys(arr29)
    @str = "Đang tính dữ liệu"
    KSU::Nesting::Engine.instance.start2(
      width_mm: width_mm * 25.4, height_mm: height_mm * 25.4, spacing_mm: gap2 * 25.4,
      rotate90: [@cho_phep_xoay ? any_rot : false], use_holes: true, parts_groups: [polys],
      two_sided: [two_sided ? two_ids : []],
      orders: [@thu_tu_don == "theo_ten" ? orders : []],
      pair: KSU::Settings.get("ghep_cap_toi_uu", true, "nesting").to_s != "false",
      on_progress: lambda do |_02d1df38|
        unless @str == "Đang xếp tấm"
          @progress = _02d1df38
          KSU::View.view&.invalidate
        end
      end,
      on_place_progress: lambda do |done, total|
        @str = "Đang xếp tấm"
        @progress = total > 0 ? (done * 100.0 / total).round : 100
        KSU::View.view&.invalidate
      end,
      on_done: lambda do |data, _0faafe3b|
        begin
          blk.call(read_result(data["0"], arr29))
        rescue StandardError => e
          @progress = @str = @queue = nil
          KSU::View.view&.invalidate
          UI.messagebox("Lỗi tối ưu: #{e.message}")
        end
      end
    )
  end
  def align_to_corner(arr, width_mm, height_mm, corner)
    b2 = (corner == 1 || corner == 2)
    _e4f12bf3 = (corner == 2 || corner == 3)
    arr.each do |placements|
      next if placements.empty?
      dx = b2 ? width_mm - placements.map { |members| members[:lx] + members[:w] }.max : -placements.map { |members| members[:lx] }.min
      dy = _e4f12bf3 ? height_mm - placements.map { |members| members[:ly] + members[:h] }.max : -placements.map { |members| members[:ly] }.min
      placements.each do |members|
        members[:lx] += dx
        members[:ly] += dy
      end
    end
  end
  def pack_all_to_corner(arr)
    ix = start_corner_index
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr.uniq.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom_of(s, @nesting)
      rec = KSU::Sheet.record_for(sheet_recs, s)
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
  def pack_plain(sheets, arr29, width_mm, height_mm, gap_for, gap2)
    solve_async(arr29, width_mm, height_mm, gap2) do |arr|
      if arr.empty?
        pack_plain_again(sheets)
      else
        arr = arr.sort_by { |b| -used_area(b) } unless @thu_tu_don == "theo_ten"
        align_to_corner(arr, width_mm, height_mm, start_corner_index)
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
  def pack_two_sided(sheets, arr29, width_mm, height_mm, gap_for, gap2)
    solve_async(arr29, width_mm, height_mm, gap2, two_sided: true) do |_096c95d4|
      arr, flag = _096c95d4.partition { |b| b.any? { |members| members[:two_sided] } }
      if arr.empty?
        pack_plain_again(sheets)
      else
        align_to_corner(arr, width_mm, height_mm, start_corner_index)
        align_to_corner(flag, width_mm, height_mm, start_corner_index)
        in_operation { apply_two_sided(sheets, arr, flag, gap_for) }
      end
      optimize_next
    end
  end
  def apply_two_sided(sheets, arr2, arr, gap_for)
    unless @thu_tu_don == "theo_ten"
      arr2 = arr2.sort_by { |b| [-b.inject(0.0) { |s, members| members[:two_sided] ? s + members[:w].to_f * members[:h].to_f : s }, -used_area(b)] }
      arr = arr.sort_by { |b| -used_area(b) }
    end
    if fill_first_row?
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
  rescue StandardError => e
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{e.message}")
  end
  def flatten_polys(arr2)
    num = 0.0
    flat = []
    rot = []
    two_ids = []
    orders = []
    layers = {}
    if @thu_tu_don == "theo_ten"
      arr2.each_with_index
              .sort_by { |segs_for_ray, i| [KSU::Nesting.sort_key(segs_for_ray[:panel].name), i] }
              .each_with_index { |(lv, pi), half| layers[pi] = half }
    end
    arr2.each_with_index do |segs_for_ray, pi|
      loops = loops_mm(segs_for_ray, true)
      num2 = 0.0
      loops.first.each { |arr| num2 = arr[0] if arr[0] > num2 }
      arr3 = num.zero? ? loops : loops.map { |arr4| arr4.map { |arr| [arr[0] + num, arr[1]] } }
      segs_for_ray[:poly_mm] = arr3.first
      (segs_for_ray[:members] || []).each do |m_bottom|
        m_bottom[:part][:poly_mm] = loops_mm(m_bottom[:part]).first.map { |arr| [arr[0] + m_bottom[:rx] + num, arr[1] + m_bottom[:ry]] }
      end
      arr3.each do |_6f2569f7|
        flat << _6f2569f7
        rot << (segs_for_ray[:rotatable] != false)
        two_ids << (segs_for_ray[:two_sided] == true)
        orders << (layers[pi] || 0)
      end
      num += num2 + 25.4
    end
    [flat, rot, orders, two_ids]
  end
  def group_id_of(segs_for_ray)
    panel = segs_for_ray[:panel]
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def origin_mm(segs_for_ray)
    if segs_for_ray[:outer] && segs_for_ray[:outer].length >= 3
      [segs_for_ray[:outer].map { |pt| pt.x.to_f }.min * 25.4,
       segs_for_ray[:outer].map { |pt| pt.y.to_f }.min * 25.4]
    elsif segs_for_ray[:bbox]
      [segs_for_ray[:bbox].min.x.to_f * 25.4, segs_for_ray[:bbox].min.y.to_f * 25.4]
    end
  end
  def prep_parts(arr29)
    groups = {}
    out = []
    arr29.each do |segs_for_ray|
      _20cd1718 = group_id_of(segs_for_ray)
      flag = _20cd1718 ? origin_mm(segs_for_ray) : nil
      _20cd1718 && flag ? (groups[_20cd1718] ||= []) << [segs_for_ray, flag] : out << segs_for_ray
    end
    return arr29 if groups.empty?
    groups.each_value { |members| out << (members.length < 2 ? members[0][0] : merge_members(members)) }
    out
  end
  def merge_members(members)
    arr4 = []
    members.each do |segs_for_ray, arr2|
      sheet_h = loops_mm(segs_for_ray).map { |arr6| arr6.map { |arr3| [arr3[0] + arr2[0], arr3[1] + arr2[1]] } }
      arr4 << KSU::Nfp.orient(sheet_h.first, true)
      sheet_h[1..].each { |elem| arr4 << KSU::Nfp.orient(elem, false) }
    end
    rings = begin
        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) ? KSU::Clipper.union(arr4, 6) : nil
      rescue StandardError
        nil
      end
    outer = nil
    if rings && !rings.empty?
      arr5 = rings.select { |half| half && half.length >= 3 }
      outer = arr5.max_by { |half| KSU::Nesting.poly_area(half) }
      outer = nil unless arr5.all? { |half| half.equal?(outer) || KSU::Nesting.point_in_poly?(half[0], outer) }
    end
    outer = nil if outer && KSU::Nesting.poly_area(outer) < 1.0
    outer = group_bbox(members) unless outer
    arr = KSU::Nesting.poly_bounds(outer)
    _78875996 = members.max_by { |segs_for_ray, _item| segs_for_ray[:w].to_f * segs_for_ray[:h].to_f }[0]
    {
      panel: _78875996[:panel],
      sheet: _78875996[:sheet],
      bbox: members.each_with_object(Geom::BoundingBox.new) { |(segs_for_ray, _item), bbox| bbox.add(segs_for_ray[:bbox]) if segs_for_ray[:bbox] },
      w: (arr[2] - arr[0]) / 25.4,
      h: (arr[3] - arr[1]) / 25.4,
      outer: nil,
      holes: nil,
      loops_mm: [KSU::Nfp.orient(outer.map { |arr3| [arr3[0] - arr[0], arr3[1] - arr[1]] }, true)],
      rotatable: members.all? { |segs_for_ray, _item| segs_for_ray[:rotatable] != false },
      two_sided: members.any? { |segs_for_ray, _item| segs_for_ray[:two_sided] },
      members: members.map { |segs_for_ray, arr2| { part: segs_for_ray, rx: arr2[0] - arr[0], ry: arr2[1] - arr[1] } },
    }
  end
  def group_bbox(members)
    arr3 = members.flat_map { |segs_for_ray, arr| loops_mm(segs_for_ray).first.map { |arr2| [arr2[0] + arr[0], arr2[1] + arr[1]] } }
    min_x, min_y, hi_x, hi_y = KSU::Nesting.poly_bounds(arr3)
    [[min_x, min_y], [hi_x, min_y], [hi_x, hi_y], [min_x, hi_y]]
  end
  def loops_mm(grp, flag = false)
    return grp[:loops_mm] if grp[:loops_mm]
    ang = flag ? (grp[:cano] || 0.0) % 360.0 : 0.0
    outer = grp[:outer]
    unless outer && outer.length >= 3
      w = grp[:w] * 25.4
      elem = grp[:h] * 25.4
      rect = [[0.0, 0.0], [w, 0.0], [w, elem], [0.0, elem]]
      return [rect] if ang == 0.0
      rect = rot_poly(rect, ang)
      _78dcb2bf, _9ff9e93b = KSU::Nesting.poly_bounds(rect)
      return [rect.map { |pt| [pt[0] - _78dcb2bf, pt[1] - _9ff9e93b] }]
    end
    _6129e547 = outer.map { |pt| [pt.x.to_f, pt.y.to_f] }
    _6129e547 = rot_poly(_6129e547, ang) unless ang == 0.0
    _34678109 = KSU::Simplify.simplify_poly(_6129e547, true)
    min_x, min_y = KSU::Nesting.poly_bounds(_34678109)
    conv2 = ->(arr4) { arr4.map { |pt| [(pt[0] - min_x) * 25.4, (pt[1] - min_y) * 25.4] } }
    loops = [conv2.call(_34678109)]
    (grp[:holes] || []).each do |elem|
      next unless elem && elem.length >= 3
      arr = elem.map { |pt| [pt.x.to_f, pt.y.to_f] }
      arr = rot_poly(arr, ang) unless ang == 0.0
      arr3 = KSU::Simplify.simplify_poly(arr, false)
      next if arr3.length < 3
      loops << conv2.call(arr3)
    end
    loops
  end
  def rot_poly(arr2, deg)
    rad = deg * Math::PI / 180.0
    cos_a = Math.cos(rad)
    sin_a = Math.sin(rad)
    arr2.map { |arr| [arr[0] * cos_a - arr[1] * sin_a, arr[0] * sin_a + arr[1] * cos_a] }
  end
  def read_result(arr2, arr29)
    return [] unless arr2
    arr2.map do |arr3|
      arr3.flat_map do |fld|
        id, ox2, oy2, rot = fld
        grp = arr29[id]
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
      end
    end.reject(&:empty?)
  end
  def placed_bbox(_4fa7c1a8, ox2, oy2, deg2)
    arr = rot_poly(_4fa7c1a8, deg2).map { |x, y| [x + ox2, y + oy2] }
    lx, _2d7e228f, _b0566a11, _897789b7 = KSU::Nesting.poly_bounds(arr)
    { lx: lx / 25.4, ly: _2d7e228f / 25.4, w: (_b0566a11 - lx) / 25.4, h: (_897789b7 - _2d7e228f) / 25.4 }
  end
end
KSU::Toiuu.include(KSU::Engine)
KSU::Xeptam.include(KSU::Engine)
module KSU::Engine
  def self.license_ok?
    id = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i"))
    return false if id.to_s.empty?
    KSU::Bottom.bound_here?.include?(id)
  end
end
