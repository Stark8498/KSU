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
    if errors_in_selection?
      msg2 = "Trong vùng chọn có chi tiết bị lỗi. Điều này có thể tạo ra kết quả không như ý muốn khi tối ưu, ví dụ như chồng lấn hoặc mất tấm. Tiếp tục?"
      return unless UI.messagebox(msg2, MB_YESNO) == IDYES
    end
    clear_last_cuts(@sel)
    if flag
      start_postpass(true)
    elsif !!defined?(KSU::Nesting::Engine)
      run_async(groups)
    else
      run_sync(groups)
    end
  end
  def errors_in_selection?
    return false unless @err_pts && @err_pts.any?
    return false unless @sel && @sheets
    num = 1.mm.to_f
    @sel.each do |sheet|
      rec = @sheets.find { |s| s[:instance] == sheet }
      next unless rec && rec[:bbox]
      lo = rec[:bbox].min
      hi = rec[:bbox].max
      @err_pts.each do |pt|
        next if pt.x.to_f < lo.x.to_f - num || pt.x.to_f > hi.x.to_f + num
        next if pt.y.to_f < lo.y.to_f - num || pt.y.to_f > hi.y.to_f + num
        return true
      end
    end
    false
  end
  def clear_last_cuts(sheets)
    arr = Array(sheets).compact.select { |s| s && s.valid? && has_last_cut?(s) }.uniq
    return if arr.empty?
    KSU.start
    arr.each do |sheet|
      sheet.definition.entities.grep(Sketchup::Group).each do |g|
        g.erase! if KSU::Nesting.last_cut?(g)
      end
      sheet.attribute_dictionary("ABF")&.delete_key("sheet-last-cut")
    end
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def has_last_cut?(sheet)
    return true if sheet.get_attribute("ABF", "sheet-last-cut", nil)
    sheet.definition.entities.grep(Sketchup::Group).any? { |g| KSU::Nesting.last_cut?(g) }
  end
  def run_sync(groups)
    moved = run(groups)
    @sel = (@sel + moved).select { |s| s && s.valid? }.uniq
    KSU::View.clear_cache
    KSU::View.view&.invalidate
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def run_async(groups)
    @added = []
    @queue = groups.values
    @progress = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    optimize_next
  rescue StandardError => ent
    KSU.abort_op
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def optimize_next
    if @queue.nil? || @queue.empty?
      optimize_done
      return
    end
    sheets = @queue.shift
    pack_batch(sheets)
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
    @flag53 = false
    @postpass_rows = nil
    @row_ix = 0
    @src_ix = 0
    @repacked_once = false
    @done_count = 0
    @num5 = 0
    @postpass_ended = false
    @sheet_cache = {}
    @h7 = {}
    @two_sided_ids = nil
    @in_tick = false
    id = nil
    id = UI.start_timer(0.15, true) { postpass_tick(id) }
    @postpass_timer = id
  end
  def stop_timer
    UI.stop_timer(@postpass_timer) if @postpass_timer
    @postpass_timer = nil
    @flag53 = false
    @postpass_rows = nil
    @row_ix = 0
    @src_ix = 0
    @repacked_once = nil
    @done_count = 0
    @num5 = 0
    @postpass_ended = nil
    @sheet_cache = nil
    @h7 = nil
    @two_sided_ids = nil
  end
  def postpass_tick(timer = nil)
    if timer && @postpass_timer != timer
      begin
        UI.stop_timer(timer)
      rescue StandardError
      end
      return
    end
    return if @in_tick
    @in_tick = true
    begin
      return stop_timer unless @nesting && @nesting.valid?
      return if @flag53
      if postpass_step == :done
        cancel
        return
      end
      KSU::View.view&.invalidate
    rescue StandardError
      stop_timer
    ensure
      @in_tick = false
    end
  end
  def cancel
    @flag53 = true
    stop_timer
    KSU::View.clear_cache
    KSU::View.view&.invalidate
  end
  def postpass_step
    @sheets ||= KSU::Sheet.sheet_list(@nesting)
    build_postpass_queue if @postpass_rows.nil?
    node = @postpass_rows[@row_ix]
    return postpass_finish unless node
    if @src_ix >= node.length
      next_row
      return :round
    end
    target = node[@src_ix]
    unless target && target.valid?
      next_src
      return :round
    end
    last = node[(@src_ix + 1)..].to_a.none? { |s| s && s.valid? }
    if last
      repack_sheet(target, node)
      next_src
      return :round
    end
    case try_fill(target, node)
    when :moved
      @repacked_once = false
    when :full
      if @repacked_once
        next_src
      else
        @repacked_once = true
        repack_sheet(target, node)
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
    groups = []
    sheets_by_stock.each_value do |sheets|
      arr = sheets.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
      groups << sort_by_x(arr) unless arr.empty?
    end
    @postpass_rows = groups
    @num5 = groups.inject(0) { |s, g| s + g.length }
    reset_try_cache
    @done_count = 0
    @row_ix = 0
    @src_ix = 0
    @repacked_once = false
  end
  def next_src
    @done_count += 1
    @src_ix += 1
    @repacked_once = false
    reset_try_cache
  end
  def next_row
    @row_ix += 1
    @src_ix = 0
    @repacked_once = false
    reset_try_cache
  end
  def repack_sheet(target, node = nil)
    KSU.start
    repack_each([target], node)
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
  def try_fill(target, node)
    gap_for = @tam_cach_le.to_f
    deadline = Time.now + 0.5
    usable_w, usable_h = usable_size(target, gap_for)
    return :full unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    found = panels_on(target, gap_for)
    free_area = usable_w * usable_h * 25.4 * 25.4 - found.inject(0.0) { |s, ent| s + ent[:area] }
    arr2 = movable_from_later(target, node, gap_for)
    @tried_keys ||= {}
    num = @try_resume_ix.to_i
    num = 0 if num < 0 || num >= arr2.length
    while num < arr2.length
      if Time.now > deadline
        @try_resume_ix = num
        return :again
      end
      arr = arr2[num]
      num += 1
      next if free_area < arr[:area] - 1e-6
      key = [arr[:p][:bw].round(4), arr[:p][:bh].round(4), !!arr[:p][:rotatable], arr[:kids].empty?]
      next if @tried_keys[key]
      screen_box = spot_for(found, arr[:p], usable_w, usable_h, arr[:kids].empty?)
      unless screen_box
        @tried_keys[key] = true
        next
      end
      arr3 = { panel: arr[:p][:panel], src: arr[:src], target: target, box: screen_box,
                  bbox: arr[:p][:bbox], kids: arr[:kids], refx: arr[:p][:bx], refy: arr[:p][:by],
                  virtual: arr[:virtual] }
      next unless do_move(arr3, gap_for)
      forget_sheets(target, arr3[:src])
      reset_try_cache
      return :moved
    end
    reset_try_cache
    :full
  end
  def movable_from_later(target, node, gap_for)
    ix = node.index(target)
    return [] unless ix
    out = []
    node[(ix + 1)..].to_a.each do |src|
      next unless src && src.valid?
      parts = panels_on(src, gap_for)
      cluster_parts(parts).each do |arr|
        next unless arr[:panels].all? { |normal_rgb| normal_rgb && normal_rgb.valid? }
        if arr[:entry]
          out << { src: src, p: arr[:entry], kids: arr[:kid_entries], area: arr[:area], virtual: true }
          next
        end
        lead = parts.find { |ent| ent[:panel] == arr[:lead] }
        next unless lead
        arr4 = arr[:children].map { |normal_rgb| parts.find { |ent| ent[:panel] == normal_rgb } }
        next if arr4.any?(&:nil?)
        out << { src: src, p: lead, kids: arr4, area: arr[:area] }
      end
    end
    out.sort_by { |color| -(color[:p][:bw] * color[:p][:bh]) }
  end
  def do_move(mv, gap_for)
    KSU.start
    bbox = place_move(mv, gap_for)
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
  def repack_each(arr2, node = nil)
    ix = pack_seed
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    arr2.each do |s|
      next unless s && s.valid?
      next if KSU::Sheet.hidden?(s)
      next if KSU::Sheet.bottom_of(s, @nesting)
      rec = sheet_recs.find { |i| i[:instance] == s }
      next unless rec
      plan = best_plan(s, rec, ix, gap_for, gap2, node)
      KSU::Nesting.apply_moves(@nesting, plan) if plan
      @sheet_cache.delete(s.entityID) if @sheet_cache
    end
  rescue StandardError
    nil
  end
  def best_plan(sheet, rec, ix, gap_for, gap2, node)
    arr = [KSU::Nesting.plan_corner(@nesting, sheet, rec, ix, gap_for, gap2, false, Time.now + 0.5)]
    [ix, (ix + 3) % 4].each do |ent|
      arr << KSU::Nesting.plan_edge(@nesting, sheet, rec, ent, gap_for, gap2)
    end
    arr = arr.compact
    return nil if arr.empty?
    return arr.first if arr.length == 1
    str2 = node ? movable_from_later(sheet, node, gap_for).first(12) : []
    best = arr.first
    best_s = plan_score(sheet, gap_for, best, str2)
    arr[1..].each do |members|
      score = plan_score(sheet, gap_for, members, str2)
      next unless score > best_s + 1e-6
      best = members
      best_s = score
    end
    best
  end
  def plan_score(sheet, gap_for, plan, str2)
    return 0.0 if str2.nil? || str2.empty?
    usable_w, usable_h = usable_size(sheet, gap_for)
    return 0.0 unless usable_w && usable_h && usable_w > 0 && usable_h > 0
    ctrl = {}
    (plan[:moves] || []).each do |arr3|
      (arr3[:members] || []).each do |grp|
        next unless grp && grp.valid?
        ctrl[grp.entityID] = [arr3[:dx], arr3[:dy]]
      end
    end
    arr4 = panels_on(sheet, gap_for).map do |ent|
      len2d = ctrl[ent[:panel].entityID] || [0.0, 0.0]
      { lx: ent[:bx] + len2d[0], ly: ent[:by] + len2d[1], w: ent[:bw], h: ent[:bh] }
    end
    gap2 = @tam_cach_nhau.to_f
    score = 0.0
    str2.each do |color|
      arr = color[:p]
      w = arr[:bw]
      h = arr[:bh]
      box = free_spot(arr4, w, h, usable_w, usable_h, gap2)
      if box.nil? && @cho_phep_xoay && arr[:rotatable] && color[:kids].empty? && (w - h).abs > 1e-6
        box = free_spot(arr4, h, w, usable_w, usable_h, gap2)
        if box
          w = arr[:bh]
          h = arr[:bw]
        end
      end
      next unless box
      arr4 << { lx: box[:x], ly: box[:y], w: w, h: h }
      score += arr[:bw] * arr[:bh]
    end
    score
  end
  def cluster_parts(parts)
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
      arr4 << merge_group(members)
    end
    h = {}
    h2 = {}
    solo.each do |ent|
      next if (ent[:holes] || []).empty?
      solo.each do |f|
        next if f.equal?(ent)
        next if h[f.object_id]
        next unless fits_in_hole?(f, ent)
        h[f.object_id] = true
        (h2[ent.object_id] ||= []) << f
      end
    end
    collect_kids = nil
    collect_kids = lambda do |oid, acc|
      (h2[oid] || []).each do |f|
        acc << f
        collect_kids.call(f.object_id, acc)
      end
      acc
    end
    solo.each do |ent|
      next if h[ent.object_id]
      arr3 = collect_kids.call(ent.object_id, [])
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
  def fits_in_hole?(f, ent)
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
  def spot_for(found, arr, usable_w, usable_h, can_rotate)
    gap2 = @tam_cach_nhau.to_f
    arr4 = found.map { |ent| { lx: ent[:bx], ly: ent[:by], w: ent[:bw], h: ent[:bh] } }
    arr3 = [[arr[:bw], arr[:bh], 0]]
    arr3 << [arr[:bh], arr[:bw], 90] if can_rotate && @cho_phep_xoay && arr[:rotatable] && (arr[:bw] - arr[:bh]).abs > 1e-6
    arr3.each do |w, h, rot|
      next if w > usable_w + 1e-6 || h > usable_h + 1e-6
      box = free_spot(arr4, w, h, usable_w, usable_h, gap2)
      return { lx: box[:x], ly: box[:y], w: w, h: h, rot: rot } if box
    end
    nil
  end
  def percent
    return 0 unless @num5 && @num5 > 0
    [[(@done_count * 100 / @num5), 0].max, 100].min
  end
  def place_move(arr2, gap_for)
    target = arr2[:target]
    screen_box = arr2[:box]
    rec = sheet_recs.find { |s| s[:instance] == target }
    return nil unless rec
    root_tr = @nesting.transformation
    tr2 = root_tr * target.transformation
    if arr2[:virtual]
      flag = false
      (arr2[:kids] || []).each do |arr|
        next unless arr[:panel] && arr[:panel].valid?
        spec = {
          panel: arr[:panel], source_sheet: arr2[:src], bbox: arr[:bbox],
          lx: screen_box[:lx] + (arr[:bx] - arr2[:refx]), ly: screen_box[:ly] + (arr[:by] - arr2[:refy]),
          w: arr[:bw], h: arr[:bh], rot: 0
        }
        flag = true if place_panel(spec, target, tr2, rec[:bbox], gap_for, root_tr)
      end
      return flag ? arr2[:panel] : nil
    end
    members = {
      panel: arr2[:panel], source_sheet: arr2[:src], bbox: arr2[:bbox],
      lx: screen_box[:lx], ly: screen_box[:ly], w: screen_box[:w], h: screen_box[:h], rot: screen_box[:rot]
    }
    bbox = place_panel(members, target, tr2, rec[:bbox], gap_for, root_tr)
    return nil unless bbox
    (arr2[:kids] || []).each do |arr|
      next unless arr[:panel] && arr[:panel].valid?
      spec = {
        panel: arr[:panel], source_sheet: arr2[:src], bbox: arr[:bbox],
        lx: screen_box[:lx] + (arr[:bx] - arr2[:refx]), ly: screen_box[:ly] + (arr[:by] - arr2[:refy]),
        w: arr[:bw], h: arr[:bh], rot: 0
      }
      place_panel(spec, target, tr2, rec[:bbox], gap_for, root_tr)
    end
    bbox
  end
  def panels_on(sheet, gap_for)
    key = sheet.entityID
    partner = @sheet_cache && @sheet_cache[key]
    return partner if partner
    answer = scan_panels(sheet, gap_for)
    @sheet_cache[key] = answer if @sheet_cache
    answer
  end
  def scan_panels(sheet, gap_for)
    rec = sheet_recs.find { |s| s[:instance] == sheet }
    return [] unless rec
    num = rec[:bbox].min.x.to_f
    num2 = rec[:bbox].min.y.to_f
    dx, dy = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    ox0 = num + [dx, 0.0].max
    oy0 = num2 + [dy, 0.0].max
    gx, gy = KSU::Avail.gaps_for(sheet, gap_for)
    parts_of_sheet(sheet, rec).map do |pt|
      loops = panel_loops(pt)
      holes = loops[1..] || []
      area = poly_area(loops.first) - holes.inject(0.0) { |s, h| s + poly_area(h) }
      pminx, pminy = panel_origin(pt)
      bbox = pt[:bbox]
      {
        panel: pt[:panel], sheet: pt[:sheet], bbox: bbox,
        two_sided: pt[:two_sided], rotatable: pt[:rotatable],
        polygon: loops.first, holes: holes, area: area,
        x: (pminx - ox0 - gx) * 25.4,
        y: (pminy - oy0 - gy) * 25.4,
        bx: bbox.min.x.to_f - ox0 - gx,
        by: bbox.min.y.to_f - oy0 - gy,
        bw: bbox.width.to_f, bh: bbox.height.to_f
      }
    end
  end
  def parts_of_sheet(sheet, rec)
    transform = rec[:transform]
    return collect_parts([sheet]) unless transform && @h7
    @two_sided_ids ||= KSU::Nesting.two_sided_set(@nesting)
    out = []
    sheet.definition.entities.each do |panel|
      next unless movable?(panel)
      key = [sheet.entityID, panel.entityID, panel.transformation.to_a]
      slot = @h7[key]
      unless slot
        slot = slot_for(panel, sheet, transform, @two_sided_ids)
        @h7[key] = slot
      end
      out << slot
    end
    out
  end
  def panel_loops(pt10)
    outer = pt10[:outer]
    unless outer && outer.length >= 3
      w = pt10[:w] * 25.4
      h = pt10[:h] * 25.4
      return [[[0.0, 0.0], [w, 0.0], [w, h], [0.0, h]]]
    end
    arr2 = outer.map { |pt| [pt.x.to_f, pt.y.to_f] }
    min_x = arr2.map { |pt| pt[0] }.min
    min_y = arr2.map { |pt| pt[1] }.min
    conv2 = ->(arr5) { arr5.map { |pt| [(pt[0] - min_x) * 25.4, (pt[1] - min_y) * 25.4] } }
    loops = [conv2.call(arr2)]
    (pt10[:holes] || []).each do |h|
      next unless h && h.length >= 3
      loops << conv2.call(h.map { |pt| [pt.x.to_f, pt.y.to_f] })
    end
    loops
  end
  def panel_origin(pt11)
    outer = pt11[:outer]
    if outer && outer.length >= 3
      [outer.map { |pt| pt.x.to_f }.min, outer.map { |pt| pt.y.to_f }.min]
    else
      [pt11[:bbox].min.x.to_f, pt11[:bbox].min.y.to_f]
    end
  end
end
KSU::Toiuuvan.include(KSU::Postproc)
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
