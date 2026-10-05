module KSU::Postproc
  private
  def start_optimize(flag = false)
    return if @progress
    stop_timer
    groups = sheets_by_stock
    if groups.empty?
      UI.messagebox("Không có sheet hợp lệ để tối ưu.")
      return
    end
    return if errors_in_selection? && UI.messagebox("Trong vùng chọn có chi tiết bị lỗi. Điều này có thể tạo ra kết quả không như ý muốn khi tối ưu, ví dụ như chồng lấn hoặc mất tấm. Tiếp tục?", MB_YESNO) != IDYES
    clear_last_cuts(@sel)
    flag ? start_postpass(true) : run_sync(groups)
  end
  def errors_in_selection?
    return false unless @arr38 && @arr38.any?
    return false unless @sel && @sheets
    eps = 1.mm.to_f
    @sel.each do |sheet|
      rec = KSU::Sheet.record_for(@sheets, sheet)
      next unless rec && rec[:bbox]
      lo = rec[:bbox].min
      hi = rec[:bbox].max
      @arr38.each do |segs_for_ray|
        next if segs_for_ray.x.to_f < lo.x.to_f - eps || segs_for_ray.x.to_f > hi.x.to_f + eps
        next if segs_for_ray.y.to_f < lo.y.to_f - eps || segs_for_ray.y.to_f > hi.y.to_f + eps
        return true
      end
    end
    false
  end
  def clear_last_cuts(sheets)
    arr = Array(sheets).select { |s| s && s.valid? && has_last_cut?(s) }.uniq
    return if arr.empty?
    KSU.start
    arr.each do |grp2|
      grp2.definition.entities.grep(Sketchup::Group).each do |grp|
        grp.erase! if KSU::Nesting.last_cut?(grp)
      end
      grp2.attribute_dictionary("ABF")&.delete_key("sheet-last-cut")
    end
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def has_last_cut?(grp)
    return true if grp.get_attribute("ABF", "sheet-last-cut", nil)
    grp.definition.entities.grep(Sketchup::Group).any? { |grp2| KSU::Nesting.last_cut?(grp2) }
  end
  def run_sync(groups)
    @added = []
    @queue = groups.values
    @progress = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    optimize_next
  rescue StandardError => e
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{e.message}")
  end
  def optimize_next
    if @queue.nil? || @queue.empty?
      optimize_done
      return
    end
    pack_batch(@queue.shift)
  end
  def optimize_done
    @progress = nil
    @str = nil
    drop_empty_sheets
    @sel = (@sel + @added).select { |s| s && s.valid? }.uniq
    tidy_sheets
    KSU::View.clear_cache
    KSU::View.view&.invalidate
    start_postpass if @tu_dong_hau_ky
  end
  def start_postpass(flag = false)
    return unless flag || @tu_dong_hau_ky
    stop_timer
    @flag47 = false
    @postpass_ended = false
    @sheet_cache = {}
    @h30 = {}
    @in_tick = false
    @postpass_timer = id = UI.start_timer(0.15, true) { postpass_tick(id) }
  end
  def stop_timer
    UI.stop_timer(@postpass_timer) if @postpass_timer
    @postpass_timer = nil
    @flag7 = false
    @postpass_rows = nil
    @row_ix = 0
    @src_ix = 0
    @flag47 = nil
    @done_count = 0
    @num4 = 0
    @postpass_ended = nil
    @sheet_cache = nil
    @h30 = nil
    @two_sided_ids = nil
  end
  def postpass_tick(timer = nil)
    if timer && @postpass_timer != timer
      UI.stop_timer(timer) rescue nil
      return
    end
    return if @in_tick
    @in_tick = true
    begin
      return finish unless @nesting && @nesting.valid?
      return if @flag7
      if postpass_step == :done
        cancel
        return
      end
      KSU::View.view&.invalidate
    rescue StandardError
      finish
    ensure
      @in_tick = false
    end
  end
  def finish
    stop_timer
    @on_done&.call
  end
  def cancel
    @flag7 = true
    stop_timer
    KSU::View.clear_cache
    KSU::View.view&.invalidate
  end
  def postpass_step
    @sheets ||= KSU::Sheet.sheet_list(@nesting)
    build_postpass_queue if @postpass_rows.nil?
    arr = @postpass_rows[@row_ix]
    return postpass_finish unless arr
    if @src_ix >= arr.length
      next_row
      return :round
    end
    target = arr[@src_ix]
    unless target && target.valid?
      next_src
      return :round
    end
    last_rect = arr[(@src_ix + 1)..].to_a.none? { |s| s && s.valid? }
    if last_rect
      repack_sheet(target, arr)
      next_src
      return :round
    end
    case try_fill(target, arr)
    when :moved
      @flag47 = false
    when :full
      if @flag47
        next_src
      else
        @flag47 = true
        repack_sheet(target, arr)
      end
    end
    :round
  end
  def postpass_finish
    return :done if @postpass_ended
    @postpass_ended = true
    drop_empty_sheets
    @sel = @sel.select { |s| s && s.valid? }
    sheet_list
    KSU::View.clear_cache
    :round
  end
  def build_postpass_queue
    @postpass_rows = sheets_by_stock.values.filter_map do |sheets|
      arr = sheets.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
      sort_by_x(arr) unless arr.empty?
    end
    @num4 = @postpass_rows.inject(0) { |s, arr2| s + arr2.length }
    reset_try_cache
  end
  def next_src
    @_433ed8bf.call(@postpass_rows[@row_ix][@src_ix]) if @_433ed8bf
    @done_count += 1
    @src_ix += 1
    @flag47 = false
    reset_try_cache
  end
  def next_row
    @row_ix += 1
    @src_ix = 0
    @flag47 = false
    reset_try_cache
  end
  def repack_sheet(target, _124c7bd3 = nil)
    KSU.start
    repack_each([target], _124c7bd3)
    KSU.commit
    KSU::View.clear_cache
    reset_try_cache
  rescue StandardError
    KSU.abort_op
  end
  def reset_try_cache
    @try_resume_ix = 0
    @tried_keys = {}
  end
  def try_fill(target, _124c7bd3)
    gap_for = @tam_cach_le.to_f
    deadline = Time.now + 0.5
    usable_w, usable_h = usable_size(target, gap_for)
    return :full unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    found = panels_on(target, gap_for)
    free_area = usable_w * usable_h * 25.4 * 25.4 - found.inject(0.0) { |s, arr3| s + arr3[:area] }
    arr2 = movable_from_later(target, _124c7bd3, gap_for)
    ci3 = @try_resume_ix.to_i
    ci3 = 0 if ci3 < 0 || ci3 >= arr2.length
    while ci3 < arr2.length
      if Time.now > deadline
        @try_resume_ix = ci3
        return :again
      end
      arr = arr2[ci3]
      ci3 += 1
      next if free_area < arr[:area] - 1e-6
      key = [arr[:p][:bw].round(4), arr[:p][:bh].round(4), !!arr[:p][:rotatable], arr[:kids].empty?]
      next if @tried_keys[key]
      screen_box = spot_for(found, arr[:p], usable_w, usable_h, arr[:kids].empty?)
      unless screen_box
        @tried_keys[key] = true
        next
      end
      arr22 = { panel: arr[:p][:panel], src: arr[:src], target: target, box: screen_box,
                  bbox: arr[:p][:bbox], kids: arr[:kids], refx: arr[:p][:bx], refy: arr[:p][:by],
                  virtual: arr[:virtual] }
      next unless do_move(arr22, gap_for)
      forget_sheets(target, arr22[:src])
      reset_try_cache
      return :moved
    end
    reset_try_cache
    :full
  end
  def movable_from_later(target, arr3, gap_for)
    ix = arr3.index(target)
    return [] unless ix
    out = []
    arr3[(ix + 1)..].to_a.each do |src|
      next unless src && src.valid?
      arr29 = panels_on(src, gap_for)
      cluster_parts(arr29).each do |arr|
        next unless arr[:panels].all? { |normal_rgb| normal_rgb && normal_rgb.valid? }
        next out << { src: src, p: arr[:entry], kids: arr[:kid_entries], area: arr[:area], virtual: true } if arr[:entry]
        pt3 = arr29.find { |arr2| arr2[:panel] == arr[:lead] }
        next unless pt3
        arr4 = arr[:children].map { |normal_rgb| arr29.find { |arr2| arr2[:panel] == normal_rgb } }
        next if arr4.any?(&:nil?)
        out << { src: src, p: pt3, kids: arr4, area: arr[:area] }
      end
    end
    out.sort_by { |arr5| -(arr5[:p][:bw] * arr5[:p][:bh]) }
  end
  def do_move(arr22, gap_for)
    KSU.start
    bbox = place_move(arr22, gap_for)
    KSU.commit
    !!bbox
  rescue StandardError
    KSU.abort_op
    false
  end
  def forget_sheets(target, src = nil)
    if @sheet_cache
      @sheet_cache.delete(target.entityID) if target && target.valid?
      @sheet_cache.delete(src.entityID) if src && src.valid?
    end
    KSU::View.clear_cache
  end
  def repack_each(arr, _124c7bd3 = nil)
    ix = start_corner_index
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom_of(s, @nesting)
      rec = KSU::Sheet.record_for(sheet_recs, s)
      next unless rec
      plan = best_plan(s, rec, ix, gap_for, gap2, _124c7bd3)
      KSU::Nesting.apply_moves(@nesting, plan) if plan
      @sheet_cache.delete(s.entityID) if @sheet_cache
    end
  rescue StandardError
    nil
  end
  def best_plan(sheet, rec, ix, gap_for, gap2, _124c7bd3)
    arr = [KSU::Nesting.plan_corner(@nesting, sheet, rec, ix, gap_for, gap2, false, Time.now + 0.5)]
    [ix, (ix + 3) % 4].each do |e|
      arr << KSU::Nesting.plan_edge(@nesting, sheet, rec, e, gap_for, gap2)
    end
    arr = arr.compact
    return nil if arr.empty?
    return arr.first if arr.length == 1
    pending = _124c7bd3 ? movable_from_later(sheet, _124c7bd3, gap_for).first(12) : []
    best = arr.first
    _d0cbe2b0 = plan_score(sheet, gap_for, best, pending)
    arr[1..].each do |members|
      score = plan_score(sheet, gap_for, members, pending)
      next unless score > _d0cbe2b0 + 1e-6
      best = members
      _d0cbe2b0 = score
    end
    best
  end
  def plan_score(sheet, gap_for, plan, pending)
    return 0.0 if pending.nil? || pending.empty?
    usable_w, usable_h = usable_size(sheet, gap_for)
    return 0.0 unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    ctrl = {}
    (plan[:moves] || []).each do |arr3|
      (arr3[:members] || []).each do |grp|
        next unless grp && grp.valid?
        ctrl[grp.entityID] = [arr3[:dx], arr3[:dy]]
      end
    end
    arr4 = panels_on(sheet, gap_for).map do |arr2|
      len2d = ctrl[arr2[:panel].entityID] || [0.0, 0.0]
      { lx: arr2[:bx] + len2d[0], ly: arr2[:by] + len2d[1], w: arr2[:bw], h: arr2[:bh] }
    end
    gap2 = @tam_cach_nhau.to_f
    score = 0.0
    pending.each do |arr5|
      arr = arr5[:p]
      w = arr[:bw]
      elem = arr[:bh]
      box = free_spot(arr4, w, elem, usable_w, usable_h, gap2)
      if box.nil? && @cho_phep_xoay && arr[:rotatable] && arr5[:kids].empty? && (w - elem).abs > 1e-6
        box = free_spot(arr4, elem, w, usable_w, usable_h, gap2)
        w, elem = arr[:bh], arr[:bw] if box
      end
      next unless box
      arr4 << { lx: box[:x], ly: box[:y], w: w, h: elem }
      score += arr[:bw] * arr[:bh]
    end
    score
  end
  def cluster_parts(arr29)
    h3 = {}
    solo = []
    arr29.each do |arr|
      flag = arr[:panel].respond_to?(:get_attribute) ? arr[:panel].get_attribute("KSU", "group-id") : nil
      flag ? (h3[flag] ||= []) << arr : solo << arr
    end
    arr3 = []
    h3.each_value do |members|
      next solo.concat(members) if members.length < 2
      arr3 << merge_group(members) unless members.any? { |f| f[:two_sided] }
    end
    h = {}
    h2 = {}
    solo.each do |arr|
      next if (arr[:holes] || []).empty?
      solo.each do |f|
        next if f.equal?(arr)
        next if h[f.object_id]
        next unless fits_in_hole?(f, arr)
        h[f.object_id] = true
        (h2[arr.object_id] ||= []) << f
      end
    end
    collect_kids = lambda do |oid, _88464b7e|
      (h2[oid] || []).each do |f|
        _88464b7e << f
        collect_kids.call(f.object_id, _88464b7e)
      end
      _88464b7e
    end
    solo.each do |arr|
      next if h[arr.object_id]
      arr2 = collect_kids.call(arr.object_id, [])
      next if arr[:two_sided] || arr2.any? { |f| f[:two_sided] }
      arr3 << {
        lead: arr[:panel],
        children: arr2.map { |f| f[:panel] },
        panels: [arr[:panel]] + arr2.map { |f| f[:panel] },
        area: arr[:area] + arr2.inject(0.0) { |s, f| s + f[:area] }
      }
    end
    arr3.sort_by { |u| -u[:area] }
  end
  def merge_group(members)
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
  def fits_in_hole?(f, arr)
    arr4 = poly_bounds(f[:polygon])
    max_eb = poly_bounds(arr[:polygon])
    return false unless f[:x] >= arr[:x] - 1e-3 && f[:y] >= arr[:y] - 1e-3 &&
                        f[:x] + arr4[2] <= arr[:x] + max_eb[2] + 1e-3 &&
                        f[:y] + arr4[3] <= arr[:y] + max_eb[3] + 1e-3
    dx = f[:x] - arr[:x]
    dy = f[:y] - arr[:y]
    (arr[:holes] || []).any? do |arr2|
      arr2.length >= 3 &&
        f[:polygon].all? { |arr3| point_in_poly?([arr3[0] + dx, arr3[1] + dy], arr2) }
    end
  end
  def spot_for(found, arr, usable_w, usable_h, can_rotate)
    gap2 = @tam_cach_nhau.to_f
    arr4 = found.map { |arr2| { lx: arr2[:bx], ly: arr2[:by], w: arr2[:bw], h: arr2[:bh] } }
    arr3 = [[arr[:bw], arr[:bh], 0]]
    arr3 << [arr[:bh], arr[:bw], 90] if can_rotate && @cho_phep_xoay && arr[:rotatable] && (arr[:bw] - arr[:bh]).abs > 1e-6
    arr3.each do |w, elem, rot|
      next if w > usable_w + 1e-6 || elem > usable_h + 1e-6
      box = free_spot(arr4, w, elem, usable_w, usable_h, gap2)
      return { lx: box[:x], ly: box[:y], w: w, h: elem, rot: rot } if box
    end
    nil
  end
  def percent
    return 0 unless @num4 && @num4 > 0
    (@done_count * 100 / @num4).clamp(0, 100)
  end
  def place_move(arr22, gap_for)
    target = arr22[:target]
    screen_box = arr22[:box]
    rec = KSU::Sheet.record_for(sheet_recs, target)
    return nil unless rec
    root_tr = @nesting.transformation
    tr = root_tr * target.transformation
    _90b332e0 = ->(members) { place_panel(members, target, tr, rec[:bbox], gap_for, root_tr) }
    _4fe34446 = lambda do |arr|
      arr[:panel] && arr[:panel].valid? &&
        _90b332e0.call({ panel: arr[:panel], source_sheet: arr22[:src], bbox: arr[:bbox],
                        lx: screen_box[:lx] + (arr[:bx] - arr22[:refx]), ly: screen_box[:ly] + (arr[:by] - arr22[:refy]),
                        w: arr[:bw], h: arr[:bh], rot: 0 })
    end
    if arr22[:virtual]
      flag = false
      (arr22[:kids] || []).each { |arr| flag = true if _4fe34446.call(arr) }
      return flag ? arr22[:panel] : nil
    end
    bbox = _90b332e0.call({ panel: arr22[:panel], source_sheet: arr22[:src], bbox: arr22[:bbox],
                               lx: screen_box[:lx], ly: screen_box[:ly], w: screen_box[:w], h: screen_box[:h], rot: screen_box[:rot] })
    return nil unless bbox
    (arr22[:kids] || []).each { |arr| _4fe34446.call(arr) }
    bbox
  end
  def panels_on(grp, gap_for)
    key = grp.entityID
    return scan_panels(grp, gap_for) unless @sheet_cache
    @sheet_cache[key] ||= scan_panels(grp, gap_for)
  end
  def scan_panels(sheet, gap_for)
    rec = KSU::Sheet.record_for(sheet_recs, sheet)
    return [] unless rec
    num = rec[:bbox].min.x.to_f
    num2 = rec[:bbox].min.y.to_f
    _fbf0cf8d, _7e1c7e1d = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    ox0 = num + [_fbf0cf8d, 0.0].max
    oy0 = num2 + [_7e1c7e1d, 0.0].max
    gx, gy = KSU::Avail.gaps_for(sheet, gap_for)
    parts_of_sheet(sheet, rec).map do |segs_for_ray|
      loops = panel_loops(segs_for_ray)
      holes = loops[1..] || []
      _354e0ff6 = poly_area(loops.first) - holes.inject(0.0) { |s, elem| s + poly_area(elem) }
      pminx, pminy = panel_origin(segs_for_ray)
      bbox = segs_for_ray[:bbox]
      {
        panel: segs_for_ray[:panel], sheet: segs_for_ray[:sheet], bbox: bbox,
        two_sided: segs_for_ray[:two_sided], rotatable: segs_for_ray[:rotatable],
        polygon: loops.first, holes: holes, area: _354e0ff6,
        x: (pminx - ox0 - gx) * 25.4,
        y: (pminy - oy0 - gy) * 25.4,
        bx: bbox.min.x.to_f - ox0 - gx,
        by: bbox.min.y.to_f - oy0 - gy,
        bw: bbox.width.to_f, bh: bbox.height.to_f
      }
    end
  end
  def parts_of_sheet(grp, rec)
    _ac3b3b9d = rec[:transform]
    return collect_parts([grp]) unless _ac3b3b9d && @h30
    @two_sided_ids ||= KSU::Nesting.two_sided_set(@nesting)
    grp.definition.entities.filter_map do |panel|
      next unless movable?(panel)
      @h30[[grp.entityID, panel.entityID, panel.transformation.to_a]] ||= slot_for(panel, grp, _ac3b3b9d, @two_sided_ids)
    end
  end
  def panel_loops(segs_for_ray)
    outer = segs_for_ray[:outer]
    unless outer && outer.length >= 3
      w = segs_for_ray[:w] * 25.4
      elem = segs_for_ray[:h] * 25.4
      return [[[0.0, 0.0], [w, 0.0], [w, elem], [0.0, elem]]]
    end
    arr = outer.map { |pt| [pt.x.to_f, pt.y.to_f] }
    min_x, min_y = poly_bounds(arr)
    conv2 = ->(arr2) { arr2.map { |pt| [(pt[0] - min_x) * 25.4, (pt[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr)]
    (segs_for_ray[:holes] || []).each do |elem|
      next unless elem && elem.length >= 3
      loops << conv2.call(elem.map { |pt| [pt.x.to_f, pt.y.to_f] })
    end
    loops
  end
  def panel_origin(segs_for_ray)
    outer = segs_for_ray[:outer]
    if outer && outer.length >= 3
      [outer.map { |pt| pt.x.to_f }.min, outer.map { |pt| pt.y.to_f }.min]
    else
      [segs_for_ray[:bbox].min.x.to_f, segs_for_ray[:bbox].min.y.to_f]
    end
  end
end
KSU::Toiuu.include(KSU::Postproc)
module KSU::Postproc
  def self.unpack_value(str)
    return "" if str.nil? || str.to_s.empty?
    return "" unless str.to_s.start_with?("KSU_")
    str2 = str.to_s[4..-1].unpack("m0").first
    return "" if str2.nil?
    str2.bytes.map { |b| b ^ KSU::Back.xor_key }.pack("C*")
  rescue
    ""
  end
  def self.confirm_deactivate
    return false unless UI.messagebox("Bạn có chắc muốn gỡ kích hoạt trên máy tính này?", MB_YESNO) == IDYES
    resp = KSU::Cutting.deactivate_key(KSU::Gannhan.license_field("k"))
    if resp.nil?
      UI.messagebox "Gỡ kích hoạt thất bại! Không kết nối được với máy chủ."
      return false
    end
    err_code = resp["code"] || resp.dig("data", "code")
    return KSU::Reorder.deactivate_error(err_code) unless resp["success"] == true || err_code == "key_deactivated"
    KSU::Push.clear_license
    UI.messagebox "Gỡ kích hoạt thành công!"
    true
  end
end
