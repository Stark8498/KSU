module KSU::Engine
  private
  def _23d70e90(sheets)
    @h29 = {}
    stroke_w, sheet_h = sheet_size(edited_sheet(sheets))
    return _da79a376 unless stroke_w && sheet_h
    parts = collect_parts(sheets)
    return _da79a376 if parts.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    arr = parts.select { |arr2| arr2[:two_sided] }
    if @tach_nhom_2_mat && !arr.empty?
      _6e065d2e(sheets, parts, width_mm, height_mm, gap_for, gap2)
    else
      _0c084a37(sheets, parts, width_mm, height_mm, gap_for, gap2)
    end
  rescue StandardError => ent
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
    _da79a376
  end
  def _ac73572a(parts, width_mm, height_mm, gap2, _2808e8d4: 0, _3307792a: 100, seed: nil, _d6d35368: false, &blk)
    if parts.empty?
      blk.call([])
      return
    end
    parts = _7714f91b(parts)
    polys, _05c18602, _0638a063, _ad07fd49 = _57ce2a46(parts)
    _1cdba2d3(@cho_phep_xoay ? _05c18602 : false, polys, _0638a063, _d6d35368 ? _ad07fd49 : [], parts, width_mm, height_mm, gap2,
                       _2808e8d4, _3307792a, seed, &blk)
  end
  def _1cdba2d3(rot, polys, _0638a063, _ad07fd49, parts, width_mm, height_mm, gap2, _2808e8d4, _3307792a, seed = nil, &blk)
    @str = "Đang tính dữ liệu"
    KSU::Nesting::Engine.instance.start(
      width_mm: width_mm * 25.4, height_mm: height_mm * 25.4, spacing_mm: gap2 * 25.4,
      rotate90: [rot], use_holes: true, parts_groups: [polys],
      two_sided: [_ad07fd49 || []],
      orders: [@thu_tu_don == "theo_ten" ? _0638a063 : []],
      pair: KSU::Settings.get("ghep_cap_toi_uu", true, "nesting").to_s != "false",
      on_progress: lambda do |progress|
        unless @str == "Đang xếp tấm"
          @num12 = (_2808e8d4 + progress * _3307792a / 100.0).round
          KSU::View.view&.invalidate
        end
      end,
      on_place_progress: lambda do |done, sweep|
        @str = "Đang xếp tấm"
        @num12 = sweep > 0 ? (done * 100.0 / sweep).round : 100
        KSU::View.view&.invalidate
      end,
      on_done: lambda do |data, arr24|
        begin
          _0850aa4d = _603ba9c4(data["0"], parts)
          blk.call(_0850aa4d)
        rescue StandardError => ent
          @num12 = nil
          @str = nil
          @arr6 = nil
          KSU::View.view&.invalidate
          UI.messagebox("Lỗi tối ưu: #{ent.message}")
        end
      end
    )
  end
  def _2cf6d3a4(arr, width_mm, height_mm, seed)
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
  def _14184f07(arr2)
    ix = pack_seed
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr2.compact.uniq.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom(s, @nesting)
      _9dcbc6c4 = sheet_recs.find { |arr| arr[:instance] == s }
      next unless _9dcbc6c4
      KSU::Nesting.pack_to_corner(@nesting, s, _9dcbc6c4, ix, gap_for, gap2)
    end
  rescue StandardError
    nil
  end
  def _10248dd2
    sheet_list
    KSU.start
    _14184f07(@arr27)
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def _0c084a37(sheets, parts, width_mm, height_mm, gap_for, gap2)
    _ac73572a(parts, width_mm, height_mm, gap2, seed: 0) do |arr|
      if arr.empty?
        _1db9fb3a(sheets)
      else
        arr = arr.sort_by { |b| -used_area(b) } unless @thu_tu_don == "theo_ten"
        arr = _2cf6d3a4(arr, width_mm, height_mm, pack_seed)
        _416e5f49 do
          num = ensure_sheets(sheets, arr.length)
          reload_sheets
          num = sort_by_x(num)
          apply_plan(num, arr, gap_for)
        end
      end
      _da79a376
    end
  end
  def _6e065d2e(sheets, parts, width_mm, height_mm, gap_for, gap2)
    _ac73572a(parts, width_mm, height_mm, gap2, _d6d35368: true) do |arr4|
      arr = arr4.select { |b| b.any? { |members| members[:two_sided] } }
      if arr.empty?
        _1db9fb3a(sheets)
      else
        arr3 = arr4.reject { |b| b.any? { |members| members[:two_sided] } }
        arr = _2cf6d3a4(arr, width_mm, height_mm, pack_seed)
        arr3 = _2cf6d3a4(arr3, width_mm, height_mm, pack_seed)
        _416e5f49 { _ae6cb680(sheets, arr, arr3, gap_for) }
      end
      _da79a376
    end
  end
  def _ae6cb680(sheets, arr2, arr, gap_for)
    unless @thu_tu_don == "theo_ten"
      arr2 = arr2.sort_by { |b| [-b.inject(0.0) { |s, members| members[:two_sided] ? s + members[:w].to_f * members[:h].to_f : s }, -used_area(b)] } unless arr2.empty?
      arr = arr.sort_by { |b| -used_area(b) } unless arr.empty?
    end
    if pack_to_row_start?
      num = arr2.empty? ? [] : ensure_sheets(sheets, arr2.length)
      num2 = arr.empty? ? [] : add_sheets(arr.length, sheets)
      @arr17.concat(num2)
    else
      num2 = arr.empty? ? [] : ensure_sheets(sheets, arr.length)
      num = arr2.empty? ? [] : add_sheets(arr2.length, sheets)
      @arr17.concat(num)
      arr = arr.reverse
    end
    reload_sheets
    num = sort_by_x(num)
    num2 = sort_by_x(num2)
    apply_plan(num2, arr, gap_for) unless arr.empty?
    apply_plan(num, arr2, gap_for) unless arr2.empty?
  end
  def _1db9fb3a(sheets)
    @h29 = {}
    _416e5f49 { pack_group(sheets) }
  end
  def _416e5f49
    KSU.start
    yield
    KSU::Sheet.prune_bottoms(@nesting)
    KSU.commit
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def _57ce2a46(node, flag = false)
    flag47 = 0.0
    flat = []
    rot = []
    arr4 = []
    arr6 = []
    layers = {}
    if @thu_tu_don == "theo_ten"
      node.each_with_index
              .sort_by { |pt, _a4ab9a59| [KSU::Nesting.sort_key(pt[:panel].name), _a4ab9a59] }
              .each_with_index { |(_56afdcfc, _b7a8e470), half| layers[_b7a8e470] = half }
    end
    node.each_with_index do |pt, _b7a8e470|
      loops = _fa87e7fb(pt, true)
      outer = loops.first
      num = 0.0
      outer.each { |arr| num = arr[0] if arr[0] > num }
      num2 = flag47
      arr7 = num2.zero? ? loops : loops.map { |arr8| arr8.map { |arr| [arr[0] + num2, arr[1]] } }
      pt[:poly_mm] = arr7.first
      (pt[:members] || []).each do |arr40|
        flag26 = _fa87e7fb(arr40[:part]).first
        arr40[:part][:poly_mm] = flag26.map { |arr| [arr[0] + arr40[:rx] + num2, arr[1] + arr40[:ry]] }
      end
      arr7.each do |_b41d8800|
        flat << _b41d8800
        rot << (pt[:rotatable] != false)
        arr4 << (pt[:two_sided] == true)
        arr6 << (layers[_b7a8e470] || 0)
      end
      flag47 += num + 25.4
    end
    [flat, rot, arr6, arr4]
  end
  def _81d80555(pt)
    panel = pt[:panel]
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def _9f684ec0(pt16)
    if pt16[:outer] && pt16[:outer].length >= 3
      [pt16[:outer].map { |pt| pt.x.to_f }.min * 25.4,
       pt16[:outer].map { |pt| pt.y.to_f }.min * 25.4]
    elsif pt16[:bbox]
      [pt16[:bbox].min.x.to_f * 25.4, pt16[:bbox].min.y.to_f * 25.4]
    end
  end
  def _7714f91b(parts)
    groups = {}
    out = []
    parts.each do |pt|
      gid = _81d80555(pt)
      flag = gid ? _9f684ec0(pt) : nil
      if gid && flag
        (groups[gid] ||= []) << [pt, flag]
      else
        out << pt
      end
    end
    return parts if groups.empty?
    arr3 = parts.map do |pt|
      num3 = pt[:w].to_f * 25.4
      arr52 = pt[:h].to_f * 25.4
      [[num3, arr52].min, [num3, arr52].max]
    end
    groups.each_value do |members|
      if members.length < 2
        members.each { |meta| out << meta[0] }
      else
        out << _46279528(members, arr3)
      end
    end
    out
  end
  def _46279528(members, _e17f53e7)
    arr5 = []
    members.each do |pt, arr4|
      loops = _fa87e7fb(pt)
      sheet_h = loops.map { |arr6| arr6.map { |arr3| [arr3[0] + arr4[0], arr3[1] + arr4[1]] } }
      arr5 << KSU::Nfp._5762df6e(sheet_h.first, true)
      (sheet_h[1..] || []).each { |arr52| arr5 << KSU::Nfp._5762df6e(arr52, false) }
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
    outer = _f573a61c(members) unless outer
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
      loops_mm: [KSU::Nfp._5762df6e(arr9.call(outer), true)],
      rotatable: members.all? { |pt, _part| pt[:rotatable] != false },
      two_sided: members.any? { |pt, _part| pt[:two_sided] },
      members: members.map { |pt, arr4| { part: pt, rx: arr4[0] - arr2[0], ry: arr4[1] - arr2[1] } },
    }
  end
  def _f573a61c(members)
    min_x = min_y = flag3 = flag4 = nil
    members.each do |pt, arr2|
      _fa87e7fb(pt).first.each do |arr|
        x = arr[0] + arr2[0]
        y = arr[1] + arr2[1]
        min_x = x if min_x.nil? || x < min_x
        min_y = y if min_y.nil? || y < min_y
        flag3 = x if flag3.nil? || x > flag3
        flag4 = y if flag4.nil? || y > flag4
      end
    end
    [[min_x, min_y], [flag3, min_y], [flag3, flag4], [min_x, flag4]]
  end
  def _fa87e7fb(grp, flag2 = false)
    return grp[:loops_mm] if grp[:loops_mm]
    ang = flag2 ? (grp[:cano] || 0.0) % 360.0 : 0.0
    outer = grp[:outer]
    unless outer && outer.length >= 3
      num3 = grp[:w] * 25.4
      arr52 = grp[:h] * 25.4
      rect = [[0.0, 0.0], [num3, 0.0], [num3, arr52], [0.0, arr52]]
      return [rect] if ang == 0.0
      rect = _d3de41b2(rect, ang)
      arr8 = rect.map { |_23505ef9| _23505ef9[0] }.min
      arr9 = rect.map { |_23505ef9| _23505ef9[1] }.min
      return [rect.map { |_23505ef9| [_23505ef9[0] - arr8, _23505ef9[1] - arr9] }]
    end
    arr4 = outer.map { |_23505ef9| [_23505ef9.x.to_f, _23505ef9.y.to_f] }
    arr4 = _d3de41b2(arr4, ang) unless ang == 0.0
    arr2 = KSU::Simplify._c71fe5d3(arr4, true)
    min_x = arr2.map { |_23505ef9| _23505ef9[0] }.min
    min_y = arr2.map { |_23505ef9| _23505ef9[1] }.min
    conv2 = ->(arr10) { arr10.map { |_23505ef9| [(_23505ef9[0] - min_x) * 25.4, (_23505ef9[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr2)]
    (grp[:holes] || []).each do |arr52|
      next unless arr52 && arr52.length >= 3
      arr3 = arr52.map { |_23505ef9| [_23505ef9.x.to_f, _23505ef9.y.to_f] }
      arr3 = _d3de41b2(arr3, ang) unless ang == 0.0
      arr5 = KSU::Simplify._c71fe5d3(arr3, false)
      next if arr5.length < 3
      loops << conv2.call(arr5)
    end
    loops
  end
  def _d3de41b2(pts, _62dc8af5)
    rad = _62dc8af5 * Math::PI / 180.0
    _fdb496e4 = Math.cos(rad)
    _a877a0fa = Math.sin(rad)
    pts.map { |arr| [arr[0] * _fdb496e4 - arr[1] * _a877a0fa, arr[0] * _a877a0fa + arr[1] * _fdb496e4] }
  end
  def _603ba9c4(arr3, parts)
    return [] unless arr3
    arr3.map do |arr5|
      arr5.flat_map do |fld|
        id, num2, num, rot = fld
        grp = parts[id]
        next [] unless grp
        members = !!grp[:members]
        arr4 = members ? grp[:members].map { |arr40| arr40[:part] } : [grp]
        arr4.map do |arr|
          poly = arr[:poly_mm] || _fa87e7fb(arr, !members).first
          screen_box = _6d7a71cf(poly, num2.to_f, num.to_f, rot.to_f)
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
  def _6d7a71cf(arr, _8242598f, _7ad94e21, _07d6adce)
    rad = _07d6adce * Math::PI / 180.0
    _fdb496e4 = Math.cos(rad)
    _a877a0fa = Math.sin(rad)
    lx = nil
    ly = nil
    flag = nil
    flag2 = nil
    arr.each do |trai, duoi|
      _ebffc3f1 = trai * _fdb496e4 - duoi * _a877a0fa + _8242598f
      _0e6f8149 = trai * _a877a0fa + duoi * _fdb496e4 + _7ad94e21
      lx = _ebffc3f1 if lx.nil? || _ebffc3f1 < lx
      ly = _0e6f8149 if ly.nil? || _0e6f8149 < ly
      flag = _ebffc3f1 if flag.nil? || _ebffc3f1 > flag
      flag2 = _0e6f8149 if flag2.nil? || _0e6f8149 > flag2
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
  def self._45e9b533
    id = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i"))
    return false if id.to_s.empty?
    KSU::Bottom._016675b8.include?(id)
  end
end
