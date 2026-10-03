module KSU::Postproc
  private
  def _28a699c9(flag = false)
    return if @num12
    stop_timer
    groups = _e1ab909e
    if groups.empty?
      UI.messagebox("Không có sheet hợp lệ để tối ưu.")
      return
    end
    if _11554dfd
      msg2 = "Trong vùng chọn có chi tiết bị lỗi. Điều này có thể tạo ra kết quả không như ý muốn khi tối ưu, ví dụ như chồng lấn hoặc mất tấm. Tiếp tục?"
      return unless UI.messagebox(msg2, MB_YESNO) == IDYES
    end
    _a815fdc9(@arr27)
    if flag
      _b9664cc7(true)
    elsif !!defined?(KSU::Nesting::Engine)
      _f16a0746(groups)
    else
      _8ffda7d7(groups)
    end
  end
  def _11554dfd
    return false unless @arr11 && @arr11.any?
    return false unless @arr27 && @sheets
    tol = 1.mm.to_f
    @arr27.each do |_73dc38ac|
      arr = @sheets.find { |s| s[:instance] == _73dc38ac }
      next unless arr && arr[:bbox]
      lo = arr[:bbox].min
      hi = arr[:bbox].max
      @arr11.each do |pt|
        next if pt.x.to_f < lo.x.to_f - tol || pt.x.to_f > hi.x.to_f + tol
        next if pt.y.to_f < lo.y.to_f - tol || pt.y.to_f > hi.y.to_f + tol
        return true
      end
    end
    false
  end
  def _a815fdc9(sheets)
    arr = Array(sheets).compact.select { |s| s && s.valid? && _545a8b49(s) }.uniq
    return if arr.empty?
    KSU.start
    arr.each do |grp|
      grp.definition.entities.grep(Sketchup::Group).each do |g|
        g.erase! if KSU::Nesting.last_cut?(g)
      end
      grp.attribute_dictionary("ABF")&.delete_key("sheet-last-cut")
    end
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def _545a8b49(grp)
    return true if grp.get_attribute("ABF", "sheet-last-cut", nil)
    grp.definition.entities.grep(Sketchup::Group).any? { |g| KSU::Nesting.last_cut?(g) }
  end
  def _8ffda7d7(groups)
    _d6f11a0e = run(groups)
    @arr27 = (@arr27 + _d6f11a0e).select { |s| s && s.valid? }.uniq
    KSU::View.clear_cache
    KSU::View.view&.invalidate
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def _f16a0746(groups)
    @arr17 = []
    @arr6 = groups.values
    @num12 = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    _da79a376
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def _da79a376
    if @arr6.nil? || @arr6.empty?
      _4ec1b153
      return
    end
    sheets = @arr6.shift
    _23d70e90(sheets)
  end
  def _4ec1b153
    @num12 = nil
    @str = nil
    drop_empty_sheets
    @arr27 = (@arr27 + @arr17).select { |s| s && s.valid? }.uniq
    _10248dd2
    KSU::View.clear_cache
    KSU::View.view&.invalidate
    _b9664cc7 if @tu_dong_hau_ky
  end
  def _b9664cc7(flag = false)
    return unless flag || @tu_dong_hau_ky
    stop_timer
    @flag53 = false
    @arr44 = nil
    @num15 = 0
    @num17 = 0
    @flag57 = false
    @num18 = 0
    @num5 = 0
    @flag44 = false
    @h19 = {}
    @h7 = {}
    @_b933b59e = nil
    @flag43 = false
    id = nil
    id = UI.start_timer(0.15, true) { _0176b6ab(id) }
    @_a16ac17e = id
  end
  def stop_timer
    UI.stop_timer(@_a16ac17e) if @_a16ac17e
    @_a16ac17e = nil
    @flag53 = false
    @arr44 = nil
    @num15 = 0
    @num17 = 0
    @flag57 = nil
    @num18 = 0
    @num5 = 0
    @flag44 = nil
    @h19 = nil
    @h7 = nil
    @_b933b59e = nil
  end
  def _0176b6ab(_ce79ae35 = nil)
    if _ce79ae35 && @_a16ac17e != _ce79ae35
      begin
        UI.stop_timer(_ce79ae35)
      rescue StandardError
      end
      return
    end
    return if @flag43
    @flag43 = true
    begin
      return stop_timer unless @nesting && @nesting.valid?
      return if @flag53
      if _b0b73b9f == :done
        cancel
        return
      end
      KSU::View.view&.invalidate
    rescue StandardError
      stop_timer
    ensure
      @flag43 = false
    end
  end
  def cancel
    @flag53 = true
    stop_timer
    KSU::View.clear_cache
    KSU::View.view&.invalidate
  end
  def _b0b73b9f
    @sheets ||= KSU::Sheet.sheet_list(@nesting)
    _61e17503 if @arr44.nil?
    node = @arr44[@num15]
    return _2e351df2 unless node
    if @num17 >= node.length
      _bf8a619a
      return :round
    end
    target = node[@num17]
    unless target && target.valid?
      _16f1ba59
      return :round
    end
    rect = node[(@num17 + 1)..].to_a.none? { |s| s && s.valid? }
    if rect
      _ceeedf70(target, node)
      _16f1ba59
      return :round
    end
    case _38bca22d(target, node)
    when :moved
      @flag57 = false
    when :full
      if @flag57
        _16f1ba59
      else
        @flag57 = true
        _ceeedf70(target, node)
      end
    end
    :round
  end
  def _2e351df2
    return :done if @flag44
    @flag44 = true
    drop_empty_sheets
    @arr27 = @arr27.select { |s| s && s.valid? }
    sheet_list
    KSU::View.clear_cache
    :round
  end
  def _61e17503
    groups = []
    _e1ab909e.each_value do |sheets|
      arr = sheets.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
      groups << sort_by_x(arr) unless arr.empty?
    end
    @arr44 = groups
    @num5 = groups.inject(0) { |s, g| s + g.length }
    _0a363616
    @num18 = 0
    @num15 = 0
    @num17 = 0
    @flag57 = false
  end
  def _16f1ba59
    @num18 += 1
    @num17 += 1
    @flag57 = false
    _0a363616
  end
  def _bf8a619a
    @num15 += 1
    @num17 = 0
    @flag57 = false
    _0a363616
  end
  def _ceeedf70(target, node = nil)
    KSU.start
    _d93740da([target], node)
    KSU.commit
    KSU::View.clear_cache
    _0a363616
  rescue StandardError
    KSU.abort_op
  end
  def _0a363616
    @num8 = 0
    @h9 = {}
  end
  def _38bca22d(target, node)
    gap_for = @tam_cach_le.to_f
    deadline = Time.now + 0.5
    usable_w, usable_h = usable_size(target, gap_for)
    return :full unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    found = _aeea1f26(target, gap_for)
    _6cab3dc0 = usable_w * usable_h * 25.4 * 25.4 - found.inject(0.0) { |s, ent| s + ent[:area] }
    arr2 = _06a8054e(target, node, gap_for)
    @h9 ||= {}
    num = @num8.to_i
    num = 0 if num < 0 || num >= arr2.length
    while num < arr2.length
      if Time.now > deadline
        @num8 = num
        return :again
      end
      arr = arr2[num]
      num += 1
      next if _6cab3dc0 < arr[:area] - 1e-6
      key = [arr[:p][:bw].round(4), arr[:p][:bh].round(4), !!arr[:p][:rotatable], arr[:kids].empty?]
      next if @h9[key]
      screen_box = _cc51eebc(found, arr[:p], usable_w, usable_h, arr[:kids].empty?)
      unless screen_box
        @h9[key] = true
        next
      end
      arr3 = { panel: arr[:p][:panel], src: arr[:src], target: target, box: screen_box,
                  bbox: arr[:p][:bbox], kids: arr[:kids], refx: arr[:p][:bx], refy: arr[:p][:by],
                  virtual: arr[:virtual] }
      next unless _43a12c4f(arr3, gap_for)
      _5fafa826(target, arr3[:src])
      _0a363616
      return :moved
    end
    _0a363616
    :full
  end
  def _06a8054e(target, node, gap_for)
    _fb072f1a = node.index(target)
    return [] unless _fb072f1a
    out = []
    node[(_fb072f1a + 1)..].to_a.each do |src|
      next unless src && src.valid?
      parts = _aeea1f26(src, gap_for)
      _003ab64b(parts).each do |arr|
        next unless arr[:panels].all? { |normal_rgb| normal_rgb && normal_rgb.valid? }
        if arr[:entry]
          out << { src: src, p: arr[:entry], kids: arr[:kid_entries], area: arr[:area], virtual: true }
          next
        end
        _23505ef9 = parts.find { |ent| ent[:panel] == arr[:lead] }
        next unless _23505ef9
        arr4 = arr[:children].map { |normal_rgb| parts.find { |ent| ent[:panel] == normal_rgb } }
        next if arr4.any?(&:nil?)
        out << { src: src, p: _23505ef9, kids: arr4, area: arr[:area] }
      end
    end
    out.sort_by { |color| -(color[:p][:bw] * color[:p][:bh]) }
  end
  def _43a12c4f(_bd0102dd, gap_for)
    KSU.start
    bbox = _086b9b67(_bd0102dd, gap_for)
    KSU.commit
    !!bbox
  rescue StandardError
    KSU.abort_op
    false
  end
  def _5fafa826(target, src = nil)
    if @h19
      @h19.delete(target.entityID) if target && target.valid?
      @h19.delete(src.entityID) if src && src.valid?
    end
    KSU::View.clear_cache
  end
  def _d93740da(arr2, node = nil)
    ix = pack_seed
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr2.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom(s, @nesting)
      _9dcbc6c4 = sheet_recs.find { |arr| arr[:instance] == s }
      next unless _9dcbc6c4
      plan = _b54811d0(s, _9dcbc6c4, ix, gap_for, gap2, node)
      KSU::Nesting.apply_moves(@nesting, plan) if plan
      @h19.delete(s.entityID) if @h19
    end
  rescue StandardError
    nil
  end
  def _b54811d0(_73dc38ac, _9dcbc6c4, ix, gap_for, gap2, node)
    arr = [KSU::Nesting.plan_corner(@nesting, _73dc38ac, _9dcbc6c4, ix, gap_for, gap2, false, Time.now + 0.5)]
    [ix, (ix + 3) % 4].each do |ent|
      arr << KSU::Nesting.plan_edge(@nesting, _73dc38ac, _9dcbc6c4, ent, gap_for, gap2)
    end
    arr = arr.compact
    return nil if arr.empty?
    return arr.first if arr.length == 1
    str2 = node ? _06a8054e(_73dc38ac, node, gap_for).first(12) : []
    _477c927d = arr.first
    _488638cf = _c4f153fd(_73dc38ac, gap_for, _477c927d, str2)
    arr[1..].each do |members|
      score = _c4f153fd(_73dc38ac, gap_for, members, str2)
      next unless score > _488638cf + 1e-6
      _477c927d = members
      _488638cf = score
    end
    _477c927d
  end
  def _c4f153fd(_73dc38ac, gap_for, plan, str2)
    return 0.0 if str2.nil? || str2.empty?
    usable_w, usable_h = usable_size(_73dc38ac, gap_for)
    return 0.0 unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    ctrl = {}
    (plan[:moves] || []).each do |arr3|
      (arr3[:members] || []).each do |grp|
        next unless grp && grp.valid?
        ctrl[grp.entityID] = [arr3[:dx], arr3[:dy]]
      end
    end
    arr4 = _aeea1f26(_73dc38ac, gap_for).map do |ent|
      len2d = ctrl[ent[:panel].entityID] || [0.0, 0.0]
      { lx: ent[:bx] + len2d[0], ly: ent[:by] + len2d[1], w: ent[:bw], h: ent[:bh] }
    end
    gap2 = @tam_cach_nhau.to_f
    score = 0.0
    str2.each do |color|
      arr = color[:p]
      num3 = arr[:bw]
      arr52 = arr[:bh]
      box = free_spot(arr4, num3, arr52, usable_w, usable_h, gap2)
      if box.nil? && @cho_phep_xoay && arr[:rotatable] && color[:kids].empty? && (num3 - arr52).abs > 1e-6
        box = free_spot(arr4, arr52, num3, usable_w, usable_h, gap2)
        if box
          num3 = arr[:bh]
          arr52 = arr[:bw]
        end
      end
      next unless box
      arr4 << { lx: box[:x], ly: box[:y], w: num3, h: arr52 }
      score += arr[:bw] * arr[:bh]
    end
    score
  end
  def _003ab64b(parts)
    h3 = {}
    solo = []
    parts.each do |ent|
      gid = ent[:panel].respond_to?(:get_attribute) ? ent[:panel].get_attribute("KSU", "group-id") : nil
      if gid
        (h3[gid] ||= []) << ent
      else
        solo << ent
      end
    end
    arr4 = []
    h3.each_value do |members|
      if members.length < 2
        solo.concat(members)
        next
      end
      next if members.any? { |f| f[:two_sided] }
      arr4 << _62eca5db(members)
    end
    h = {}
    h2 = {}
    solo.each do |ent|
      next if (ent[:holes] || []).empty?
      solo.each do |f|
        next if f.equal?(ent)
        next if h[f.object_id]
        next unless _8f10bac2(f, ent)
        h[f.object_id] = true
        (h2[ent.object_id] ||= []) << f
      end
    end
    _1614616b = nil
    _1614616b = lambda do |_ddb19efd, _8b757da4|
      (h2[_ddb19efd] || []).each do |f|
        _8b757da4 << f
        _1614616b.call(f.object_id, _8b757da4)
      end
      _8b757da4
    end
    solo.each do |ent|
      next if h[ent.object_id]
      arr3 = _1614616b.call(ent.object_id, [])
      next if ent[:two_sided] || arr3.any? { |f| f[:two_sided] }
      arr4 << {
        lead: ent[:panel],
        children: arr3.map { |f| f[:panel] },
        panels: [ent[:panel]] + arr3.map { |f| f[:panel] },
        area: ent[:area] + arr3.inject(0.0) { |s, f| s + f[:area] }
      }
    end
    arr4.sort_by { |arr5| -arr5[:area] }
  end
  def _62eca5db(members)
    bx2 = members.map { |f| f[:bx] }.min
    by2 = members.map { |f| f[:by] }.min
    bw2 = members.map { |f| f[:bx] + f[:bw] }.max - bx2
    bh2 = members.map { |f| f[:by] + f[:bh] }.max - by2
    h = members.max_by { |f| f[:area] }
    {
      lead: h[:panel],
      children: (members - [h]).map { |f| f[:panel] },
      panels: members.map { |f| f[:panel] },
      area: members.inject(0.0) { |s, f| s + f[:area] },
      entry: h.merge(bx: bx2, by: by2, bw: bw2, bh: bh2, rotatable: false),
      kid_entries: members
    }
  end
  def _8f10bac2(f, ent)
    arr3 = poly_bounds(f[:polygon])
    max_eb = poly_bounds(ent[:polygon])
    return false unless f[:x] >= ent[:x] - 1e-3 && f[:y] >= ent[:y] - 1e-3 &&
                        f[:x] + arr3[2] <= ent[:x] + max_eb[2] + 1e-3 &&
                        f[:y] + arr3[3] <= ent[:y] + max_eb[3] + 1e-3
    dx = f[:x] - ent[:x]
    dy = f[:y] - ent[:y]
    (ent[:holes] || []).any? do |arr4|
      arr4.length >= 3 &&
        f[:polygon].all? { |arr2| point_in_poly?([arr2[0] + dx, arr2[1] + dy], arr4) }
    end
  end
  def _cc51eebc(found, arr, usable_w, usable_h, _c61e50a5)
    gap2 = @tam_cach_nhau.to_f
    arr4 = found.map { |ent| { lx: ent[:bx], ly: ent[:by], w: ent[:bw], h: ent[:bh] } }
    arr3 = [[arr[:bw], arr[:bh], 0]]
    arr3 << [arr[:bh], arr[:bw], 90] if _c61e50a5 && @cho_phep_xoay && arr[:rotatable] && (arr[:bw] - arr[:bh]).abs > 1e-6
    arr3.each do |num3, arr52, rot|
      next if num3 > usable_w + 1e-6 || arr52 > usable_h + 1e-6
      box = free_spot(arr4, num3, arr52, usable_w, usable_h, gap2)
      return { lx: box[:x], ly: box[:y], w: num3, h: arr52, rot: rot } if box
    end
    nil
  end
  def percent
    return 0 unless @num5 && @num5 > 0
    [[(@num18 * 100 / @num5), 0].max, 100].min
  end
  def _086b9b67(arr2, gap_for)
    target = arr2[:target]
    screen_box = arr2[:box]
    arr3 = sheet_recs.find { |s| s[:instance] == target }
    return nil unless arr3
    root_tr = @nesting.transformation
    tr2 = root_tr * target.transformation
    if arr2[:virtual]
      flag = false
      (arr2[:kids] || []).each do |arr|
        next unless arr[:panel] && arr[:panel].valid?
        _799e513f = {
          panel: arr[:panel], source_sheet: arr2[:src], bbox: arr[:bbox],
          lx: screen_box[:lx] + (arr[:bx] - arr2[:refx]), ly: screen_box[:ly] + (arr[:by] - arr2[:refy]),
          w: arr[:bw], h: arr[:bh], rot: 0
        }
        flag = true if place_panel(_799e513f, target, tr2, arr3[:bbox], gap_for, root_tr)
      end
      return flag ? arr2[:panel] : nil
    end
    members = {
      panel: arr2[:panel], source_sheet: arr2[:src], bbox: arr2[:bbox],
      lx: screen_box[:lx], ly: screen_box[:ly], w: screen_box[:w], h: screen_box[:h], rot: screen_box[:rot]
    }
    bbox = place_panel(members, target, tr2, arr3[:bbox], gap_for, root_tr)
    return nil unless bbox
    (arr2[:kids] || []).each do |arr|
      next unless arr[:panel] && arr[:panel].valid?
      _799e513f = {
        panel: arr[:panel], source_sheet: arr2[:src], bbox: arr[:bbox],
        lx: screen_box[:lx] + (arr[:bx] - arr2[:refx]), ly: screen_box[:ly] + (arr[:by] - arr2[:refy]),
        w: arr[:bw], h: arr[:bh], rot: 0
      }
      place_panel(_799e513f, target, tr2, arr3[:bbox], gap_for, root_tr)
    end
    bbox
  end
  def _aeea1f26(grp, gap_for)
    key = grp.entityID
    partner = @h19 && @h19[key]
    return partner if partner
    answer = _c5297436(grp, gap_for)
    @h19[key] = answer if @h19
    answer
  end
  def _c5297436(_73dc38ac, gap_for)
    arr2 = sheet_recs.find { |s| s[:instance] == _73dc38ac }
    return [] unless arr2
    num = arr2[:bbox].min.x.to_f
    num2 = arr2[:bbox].min.y.to_f
    dx, dy = KSU::Sheet.edit_offset(_73dc38ac) || [0.0, 0.0]
    _c9bc3f08 = num + [dx, 0.0].max
    _1d9bcdf1 = num2 + [dy, 0.0].max
    _5ae18fa7, _b4835d15 = KSU::Avail.gaps_for(_73dc38ac, gap_for)
    _cce35269(_73dc38ac, arr2).map do |pt|
      loops = _0579a704(pt)
      holes = loops[1..] || []
      _5fb96e91 = poly_area(loops.first) - holes.inject(0.0) { |s, arr52| s + poly_area(arr52) }
      _e66e2152, _c0711cd2 = _1998c7d5(pt)
      bbox = pt[:bbox]
      {
        panel: pt[:panel], sheet: pt[:sheet], bbox: bbox,
        two_sided: pt[:two_sided], rotatable: pt[:rotatable],
        polygon: loops.first, holes: holes, area: _5fb96e91,
        x: (_e66e2152 - _c9bc3f08 - _5ae18fa7) * 25.4,
        y: (_c0711cd2 - _1d9bcdf1 - _b4835d15) * 25.4,
        bx: bbox.min.x.to_f - _c9bc3f08 - _5ae18fa7,
        by: bbox.min.y.to_f - _1d9bcdf1 - _b4835d15,
        bw: bbox.width.to_f, bh: bbox.height.to_f
      }
    end
  end
  def _cce35269(grp, arr)
    transform = arr[:transform]
    return collect_parts([grp]) unless transform && @h7
    @_b933b59e ||= KSU::Nesting.two_sided_set(@nesting)
    out = []
    grp.definition.entities.each do |panel|
      next unless _1a400713(panel)
      key = [grp.entityID, panel.entityID, panel.transformation.to_a]
      slot = @h7[key]
      unless slot
        slot = _3fe7c4d4(panel, grp, transform, @_b933b59e)
        @h7[key] = slot
      end
      out << slot
    end
    out
  end
  def _0579a704(pt17)
    outer = pt17[:outer]
    unless outer && outer.length >= 3
      num3 = pt17[:w] * 25.4
      arr52 = pt17[:h] * 25.4
      return [[[0.0, 0.0], [num3, 0.0], [num3, arr52], [0.0, arr52]]]
    end
    arr2 = outer.map { |pt| [pt.x.to_f, pt.y.to_f] }
    min_x = arr2.map { |pt| pt[0] }.min
    min_y = arr2.map { |pt| pt[1] }.min
    conv2 = ->(arr5) { arr5.map { |pt| [(pt[0] - min_x) * 25.4, (pt[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr2)]
    (pt17[:holes] || []).each do |arr52|
      next unless arr52 && arr52.length >= 3
      loops << conv2.call(arr52.map { |pt| [pt.x.to_f, pt.y.to_f] })
    end
    loops
  end
  def _1998c7d5(pt18)
    outer = pt18[:outer]
    if outer && outer.length >= 3
      [outer.map { |pt| pt.x.to_f }.min, outer.map { |pt| pt.y.to_f }.min]
    else
      [pt18[:bbox].min.x.to_f, pt18[:bbox].min.y.to_f]
    end
  end
end
KSU::Toiuuvan.include(KSU::Postproc)
module KSU::Postproc
  def self._75f2a016(str)
    return "" if str.nil? || str.to_s.empty?
    return "" unless str.to_s.start_with?("KSU_")
    str2 = str.to_s[4..-1].unpack("m0").first
    return "" if str2.nil?
    str2.bytes.map { |b| b ^ KSU::Back._f7eacb3a }.pack("C*")
  rescue
    ""
  end
  def self._7b2b347d
    return false unless UI.messagebox("Bạn có chắc muốn gỡ kích hoạt trên máy tính này?", MB_YESNO) == IDYES
    resp = KSU::Cutting._ecf7ba06(KSU::Gannhan.license_field("k"))
    if resp.nil?
      UI.messagebox "Gỡ kích hoạt thất bại! Không kết nối được với máy chủ."
      return false
    end
    err_code = resp["code"] || resp.dig("data", "code")
    return KSU::Reorder._b25875c4(err_code) unless resp["success"] == true || err_code == "key_deactivated"
    KSU::Push._33a88aa5
    UI.messagebox "Gỡ kích hoạt thành công!"
    true
  end
end
