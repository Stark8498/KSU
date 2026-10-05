module KSU::Nest
  extend self
  class Progress
    include KSU::Preset
    def activate
      KSU::View.view.invalidate
    end
    def deactivate(view)
      KSU::Nest.abort_labelling
      KSU::Nest.stop_collect
      KSU::Nest.abort_unless_done
      view.invalidate
    end
    def draw(view)
      KSU::Nest.set_status(KSU::Nest.status_text)
    end
    def onCancel(reason, view)
      KSU::Nest.schedule_tick if reason == 2
    end
  end
  class Refine < Progress
    include KSU::Nesting
    include KSU::Postproc
    include KSU::Engine
    include KSU::Back
    def activate
      @nesting = KSU::Nesting.find_nesting(notify: false)
      return request_finish unless @nesting && @nesting.valid?
      arr = KSU::Nest.spacing_settings
      @tam_cach_nhau = arr[0].to_f.mm
      @tam_cach_le = arr[1].to_f.mm
      KSU::Avail.set_override(arr[2].map { |v| v.mm.to_f })
      @tu_dong_hau_ky, @cho_phep_xoay, @arr39, @goc_don_van = true, true, KSU::Nest.rotate_by_name, KSU::Nest.corner
      KSU::View.load_colors
      sheet_list
      arr2 = KSU::Nest.pending
      arr3 = arr2 && !arr2.empty? ? arr2 : @sheets.map { |i| i[:instance] }
      @sel = arr3.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
      return request_finish if @sel.empty?
      @_433ed8bf = lambda { |sheet| KSU::Nest.on_group_changed(sheet) }
      @on_done = lambda { cancel }
      start_postpass
      KSU::View.view.invalidate
    end
    def request_finish
      @flag38 = true
      UI.start_timer(0, false) { KSU::Nest.finish }
    end
    def deactivate(view)
      stop_timer
      KSU::Avail.set_override(nil)
      KSU::Nest.abort_run unless @flag38
      view.invalidate
    end
    def draw(view)
      return unless @num4 && @num4 > 0
      KSU::Nest.set_status("Đang hậu kỳ... #{percent}%")
      arr = @postpass_rows && @postpass_rows[@row_ix].to_a[@src_ix]
      KSU::Nest.set_active_sheet(arr.get_attribute("ABF", "sheet-id")) if arr && arr.valid?
      KSU::Nest.refresh
    end
    def cancel
      @flag38 = true
      super
      KSU::Nest.finish
    end
    def sheet_list
      @sheets = KSU::Sheet.sheet_list(@nesting)
    end
    alias reload_sheets sheet_list
    def sheet_recs
      @sheets
    end
  end
  class ModelWatch < Sketchup::AppObserver
    def onNewModel(model)
      UI.start_timer(0, false) { KSU::Nest.shutdown }
    end
    alias onOpenModel onNewModel
  end
  def shutdown
    @arr31, @sel_snapshot = [], []
    return cancel_labelling if labelling
    dlg = KSU::Settings.tool_windows
    return unless dlg
    return KSU::Settings.mark_stale(%w[nesting]) unless KSU::Settings.active_tab == "nesting"
    send_materials(dlg, material_rows(@sel_snapshot))
  rescue StandardError
    nil
  end
  def status_text
    return "Đang gắn nhãn... #{[@label_done + 1, @label_total].min}/#{@label_total}" if @labelling
    "#{"#{@job_name} | " if @job_name}#{@str || "Đang nesting"}... #{@progress}%" if @progress
  end
  def notify(text, arr = nil, _50dcea0d = true)
    axis = { text: text }
    axis[:ids] = arr.map(&:to_s) if arr && !arr.empty?
    axis[:zoom] = false unless _50dcea0d
    (@arr31 ||= []) << axis
    return UI.messagebox(text) unless KSU::Settings.tool_windows
    send_to_page("nestingNotes", line: axis)
  end
  def tail_pt(entries)
    entries.length > 8 ? entries[0, 8].join(", ") + ", ..." : entries.join(", ")
  end
  def plan_parts(nesting)
    prev_key = KSU::Avail.override
    job_cfg = @job_cfg || job_settings
    KSU::Avail.set_override(margins_of(job_cfg).map { |v| v.to_f.mm.to_f })
    KSU::Nesting.overlaps(nesting, job_cfg[:spacing].to_f.mm)
  ensure
    KSU::Avail.set_override(prev_key)
  end
  def part_ids_of(nesting)
    return unless nesting && nesting.valid?
    flag = plan_parts(nesting).filter_map { |f| f[:panel] && f[:panel].valid? && part_id(f[:panel]) }.uniq
    notify("Cảnh báo: tấm #{tail_pt(flag)} bị chồng lấn.", flag) unless flag.empty?
    arr = []
    KSU::Nesting.error_points(nesting, 20, arr)
    arr = arr.uniq
    notify("Cảnh báo: tấm #{tail_pt(arr)} có điểm bị lỗi.", arr) unless arr.empty?
  rescue StandardError
    nil
  end
  def send_to_page(action, to_json_row)
    dlg = KSU::Settings.tool_windows
    KSU::Settings.send_to_dialog(dlg, "nesting", action, to_json_row.to_json) if dlg
  end
  def place_parts(groups, job = nil)
    return unless @root && @root.valid? && !groups.empty?
    h5, _5d24831c, tr = {}, KSU::Nesting.two_sided_set(@root), @root.transformation
    sheets = groups.filter_map do |gr|
      next unless gr && gr.valid?
      arr2 = group_shapes(gr, tr, h5)
      arr2[:fills] = panel_payload(KSU::Nesting.sheet_transform(gr, tr), _5d24831c)
      (@h4 ||= {})[gr.entityID] = layout_hash(gr)
      arr2
    end
    return if sheets.empty?
    send_to_page("nestingLive", sheets: sheets, job: job, layers: h5.keys, colors: parse_rows(h5.keys))
  rescue StandardError
    nil
  end
  def on_job_result(ix, s, resp)
    job = @arr36 && @arr36[ix]
    return unless job && @job_cfg
    items = resp.empty? ? nil : JSON.parse(resp)
    if @job_ix && ix > @job_ix
      sheets = (@h2 ||= {})[ix] ||= {}
      if items
        (sheets[s] ||= []).concat(items)
      else
        sheets[s] = []
      end
      return
    end
    send_to_page("nestingLive", place: place(job, ix, s, items))
  rescue StandardError
    nil
  end
  def place(job, ix, s, items)
    to_json_row = { tmp: "#{ix}-#{s}", job: ix, key: job[:type][:name], paper: sheet_frame(ix, s), layers: ["ABF_cuttingLines"], colors: @_a4b96af4 || [""] }
    num = @arr13[to_json_row[:tmp]] = items && (@arr13[to_json_row[:tmp]] || items.any? { |arr2| job[:parts].dig(arr2[0].to_i, :two_sided) })
    return to_json_row.merge(clear: true) unless items
    to_json_row[:parts] = items.filter_map { |fld| place_part(job, ix, s, fld, num) }
    to_json_row[:bottom] = sheet_frame(ix, s, true) if job[:two] && to_json_row[:parts].any? { |arr| arr[:two] }
    to_json_row
  end
  def flush_live(ix)
    (@h2.delete(ix) || {}).sort.each { |s, items| send_to_page("nestingLive", place: place(@arr36[ix], ix, s, items)) }
  rescue StandardError
    nil
  end
  def sheet_layout
    w, elem = @job_cfg[:sheet_w].to_f, @job_cfg[:sheet_h].to_f
    arr2 = @arr36.map do |job|
      usable_w, usable_h = sheet_area(job)
      _354e0ff6 = job[:parts].inject(0.0) { |acc2, arr| acc2 + polygon_area(arr[:bounds_mm][arr[:outer_index]] || []) }
      [(_354e0ff6 / (usable_w.to_f * usable_h.to_f * 0.75)).ceil, 1].max
    end.max
    flag = -@arr36[0][:slots] * (elem + 700.0) + elem + (@arr36[0][:slots] > 1 ? elem + 350.0 : 0.0)
    rows = @arr36.inject(0) { |acc2, arr3| acc2 + arr3[:slots] }
    { x0: 0.0, y0: -rows * (elem + 700.0), x1: arr2 * (w + 500.0) - 500.0, y1: flag }
  rescue StandardError
    nil
  end
  def polygon_area(arr)
    return 0.0 if arr.length < 3
    arr.each_index.inject(0.0) do |acc2, i|
      arr2, b = arr[i], arr[(i + 1) % arr.length]
      acc2 + arr2[0].to_f * b[1].to_f - b[0].to_f * arr2[1].to_f
    end.abs / 2.0
  end
  def sheet_origin(ix, s)
    _b505e76d = @arr36[0..ix].inject(0) { |acc2, arr| acc2 + arr[:slots] }
    [s * (@job_cfg[:sheet_w].to_f + 500.0), -_b505e76d * (@job_cfg[:sheet_h].to_f + 700.0)]
  end
  def sheet_frame(ix, s, bot = false)
    w, elem = @job_cfg[:sheet_w].to_f, @job_cfg[:sheet_h].to_f
    text, y0 = sheet_origin(ix, s)
    y0 += elem + 350.0 if bot
    [[text, y0], [text + w, y0], [text + w, y0 + elem], [text, y0 + elem]]
  end
  def place_part(job, ix, s, fld, _5d24831c)
    grp = job[:parts][fld[0].to_i]
    return unless grp
    x, y, ang = fld[1].to_f, fld[2].to_f, fld[3].to_f
    err_code = corner_code
    if err_code != 0
      w, elem = sheet_area(job, _5d24831c)
      x, y = case err_code
                   when 1 then [w - y, x]
                   when 2 then [w - x, elem - y]
                   else [y, elem - x]
                   end
    end
    arr2 = margins_of(@job_cfg)
    _821639ac, num2 = _5d24831c ? [KSU::Avail.two_sided_margin.to_f] * 2 : [arr2[0].to_f, arr2[3].to_f]
    start_x, ly0 = sheet_origin(ix, s)
    dx, dy = x + _821639ac + start_x, y + num2 + ly0
    rad = ang * Math::PI / 180.0
    cos_a, sin_a = Math.cos(rad), Math.sin(rad)
    _90b332e0 = lambda do |arr3|
      arr3.map { |trai, duoi| [(trai * cos_a - duoi * sin_a + dx).round(2), (trai * sin_a + duoi * cos_a + dy).round(2)] }
    end
    loops = (grp[:cutting_lines] || []).map { |axis| axis.map { |segs_for_ray| [segs_for_ray.x.to_f * 25.4, segs_for_ray.y.to_f * 25.4] } }
    loops = grp[:bounds_mm] if loops.empty?
    outer = loops[grp[:outer_index]] || loops[0]
    return unless outer && outer.length > 2
    num = loops.filter_map { |arr| [1, 0, _90b332e0.call(arr)] if arr.length > 1 }
    { pts: _90b332e0.call(outer), two: grp[:two_sided] == true, group: !!(@job_cfg[:nhom_cap] && fld[4].to_i >= 0), lines: num, id: part_id(grp[:group]),
      holes: loops.each_with_index.filter_map { |arr, i| _90b332e0.call(arr) if i != grp[:outer_index] && arr.length > 2 } }
  end
  def layout_hash(gr)
    (KSU.entities_in(gr) || []).filter_map { |grp| grp.transformation.to_a if KSU.container?(grp) }.hash
  end
  def on_group_changed(grp)
    return unless grp && grp.valid?
    refresh(true)
    send_to_page("nestingLive", done: grp.get_attribute("ABF", "sheet-id"))
  end
  def set_active_sheet(id)
    return if id.nil? || id == @active_id
    @active_id = id
    send_to_page("nestingLive", busy: id)
  end
  def refresh(flag = false)
    return unless @root && @root.valid? && @h4
    at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return if !flag && @_d94dd3d6 && at - @_d94dd3d6 < 0.25
    @_d94dd3d6 = at
    place_parts(@root.definition.entities.select { |gr| KSU::Sheet.sheet?(gr) && @h4[gr.entityID] != layout_hash(gr) })
  end
  def set_status(text)
    return if text == @status_text || !KSU::Settings.tool_windows
    @status_text = text
    send_to_page("nestingProgress", text: text)
  end
  def pending
    @pending
  end
  def rotate_by_name
    @job_cfg.is_a?(Hash) && @job_cfg[:rotate_by_name].is_a?(Hash) ? @job_cfg[:rotate_by_name] : {}
  end
  def labelling
    !!(@arr36 || @progress || @labelling || @collecting)
  end
  def corner
    @job_cfg.is_a?(Hash) && @job_cfg[:corner] ? @job_cfg[:corner] : KSU::Settings.get("goc_don_van", "trai_duoi", "nesting")
  end
  def open
    KSU::Intem.check_license
    KSU::Giacong.assert_license
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    arr = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    return unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    stop_labelling if @arr36 && !Sketchup.active_model.tools.active_tool.is_a?(Progress)
    KSU::Settings.open_window("nesting") unless labelling && !KSU::Settings.tool_windows
  rescue StandardError => e
    one_group(e)
  end
  def start3(job_cfg, rows)
    @job_cfg, @arr32 = job_cfg, rows
    @arr21, @made, @h18, @job_ix, @refining, @flag41 = [], [], {}, 0, false, false
    @arr36 = rows.reject { |arr| arr[:parts].empty? }.map do |arr|
      flag = arr[:parts].any? { |arr3| arr3[:two_sided] }
      { type: arr, two: flag, parts: arr[:parts], slots: flag ? 2 : 1 }
    end
    job_list = @arr36.map { |job| pack_area(job) || break }
    return stop_labelling unless job_list&.any?
    @w, @elem, @m_left, @m_bottom = (@job_cfg.values_at(:sheet_w, :sheet_h) + margins_of(@job_cfg).values_at(0, 3)).map(&:mm)
    @arr9, @sheet_ix, @_7cdc0010, @root, @h4, @h2, @arr13 = [], 0, 0, nil, {}, {}, {}
    @_a4b96af4 = parse_rows(["ABF_cuttingLines"])
    @active_id = nil
    send_to_page("nestingLive", reset: true, pp: !!@job_cfg[:hau_ky], tones: tones, extent: sheet_layout, keys: @arr36.map { |arr2| arr2[:type][:name] })
    start_run(job_list)
  rescue StandardError => e
    one_group(e)
  end
  def sheet_area(job, flag = false)
    _6f2569f7, half, t, b = margins_of(@job_cfg)
    arr = [@job_cfg[:sheet_w] - _6f2569f7 - half, @job_cfg[:sheet_h] - t - b]
    return arr unless job[:two] && (flag || @job_cfg[:tach_nhom] == false)
    len2d = KSU::Avail.two_sided_margin
    arr.map { |v| v - len2d }
  end
  def pack_area(job)
    width_mm, height_mm = sheet_area(job)
    return if width_mm <= 0 || height_mm <= 0
    flat, rot, _5d24831c, _18c71dc1, _c2a4afd5, outer, layers = [], [], [], [], [], [], {}
    if @job_cfg[:by_name]
      job[:parts].each_with_index
                    .sort_by { |arr2, i| [KSU::Nesting.sort_key(arr2[:group].name), i] }
                    .each_with_index { |(lv, _031d8f49), half| layers[_031d8f49] = half }
    end
    err_code = corner_code
    _5d5d62fb = case err_code
              when 1 then ->(arr) { [arr[1], -arr[0]] }
              when 2 then ->(arr) { [-arr[0], -arr[1]] }
              when 3 then ->(arr) { [-arr[1], arr[0]] }
              end
    job[:parts].each_with_index do |arr2, _031d8f49|
      arr2[:bounds_mm].each_with_index do |b, board_index|
        flat << (_5d5d62fb ? b.map(&_5d5d62fb) : b)
        _c2a4afd5 << _031d8f49
        outer << (board_index == arr2[:outer_index])
        rot << (arr2[:rotatable] != false)
        _5d24831c << (arr2[:two_sided] == true)
        _18c71dc1 << layers[_031d8f49]
      end
    end
    _b95e286f, flag = sheet_area(job, true)
    return if _b95e286f <= 0 || flag <= 0
    width_mm, height_mm, _b95e286f, flag = height_mm, width_mm, flag, _b95e286f if err_code.odd?
    { w: width_mm, h: height_mm, w2: _b95e286f, h2: flag, sp: @job_cfg[:spacing], rot: rot, holes: true, parts: flat,
      two: @job_cfg[:tach_nhom] ? _5d24831c : [], ord: @job_cfg[:by_name] ? _18c71dc1 : [], own: _c2a4afd5, outer: outer, pair: @job_cfg[:ghep_cap] != false }
  end
  def show_progress
    @job_name, @progress, @str = @arr36[@job_ix][:type][:name], 0, "Đang tính dữ liệu"
    switch_tool(Progress) unless Sketchup.active_model.tools.active_tool.instance_of?(Progress)
  end
  def start_run(job_list)
    show_progress
    KSU::Nesting::Engine.instance.start_jobs(
      jobs: job_list,
      on_job_progress: lambda { |ix, num|
        next unless ix == @job_ix && @str != "Đang xếp tấm"
        @progress = num
        KSU::View.view.invalidate
      },
      on_job_place_progress: lambda { |ix, done, total|
        num = total.to_i > 0 ? [(done * 100.0 / total.to_i).round, 100].min : 100
        next if ix != @job_ix || (@str == "Đang xếp tấm" && @progress == num)
        @str, @progress = "Đang xếp tấm", num
        KSU::View.view.invalidate
      },
      on_job_place: lambda { |ix, s, resp| on_job_result(ix, s, resp) },
      on_job_done: lambda { |ix, data, label_data|
        next unless @job_cfg && @h18
        @h18[ix] = [data, label_data]
        drain_jobs if ix == @job_ix
      }
    )
  end
  def schedule_tick
    UI.start_timer(0, false) { cancel_labelling if KSU.batch_lost? }
  end
  def drain_jobs
    return cancel_labelling if KSU.batch_lost?
    return if @refining || @flag41
    @flag41 = true
    while @job_cfg && @h18&.key?(@job_ix)
      ix = @job_ix
      data, label_data = @h18.delete(ix)
      job = @arr36[ix]
      @job_ix += 1
      Array(label_data).each do |num2|
        num = job[:parts].dig(num2.to_i, :group)
        next unless num && num.valid?
        id = num.get_attribute("ABF", "board-index")
        @arr21 << id.to_s if id
        @made << num
      end
      sheets = shift_to_corner(to_sheets(job, data), job)
      next if sheets.empty?
      arr26 = draw_job(job, sheets)
      (@arr26 ||= []).concat(arr26.map(&:first).select(&:valid?))
      place_parts(arr26.flatten.compact, ix)
    end
    return unless @job_cfg
    flush_live(@job_ix)
    if @job_ix < @arr36.length
      show_progress
      return Sketchup.active_model.active_view.invalidate
    end
    arr26, @arr26 = @arr26.to_a.select(&:valid?), nil
    return finish_run unless @job_cfg[:hau_ky] && !arr26.empty?
    @pending, @refining = arr26, true
    switch_tool(Refine)
  rescue StandardError => e
    one_group(e)
  ensure
    @flag41 = false
  end
  def switch_tool(tool_cls)
    @flag28 = true
    KSU.select_tool(tool_cls)
  ensure
    @flag28 = false
  end
  def finish
    @pending, @refining = nil, false
    @arr36 ? finish_run : clear_status
  end
  def finish_run
    @arr36 = @h18 = @job_ix = @job_name = @progress = @str = nil
    restore_model
    root = @root
    finish_draw
    unless @arr21.nil? || @arr21.empty?
      KSU.select_only((@made || []).select { |vec| vec && vec.valid? })
      notify("Lỗi: tấm #{tail_pt(@arr21.uniq)} vượt khổ ván và bị bỏ qua khi nesting.", @arr21.uniq, false)
    end
    part_ids_of(root)
    @job_cfg = @arr32 = @arr21 = @made = nil
    clear_status
  rescue StandardError => e
    one_group(e)
  end
  def restore_model
    return unless KSU.in_batch?
    return KSU.abort_batch unless @root && @root.valid?
    @root.hidden = false
    place_root
    KSU.commit_batch
    Sketchup.active_model.active_view.zoom_extents
  end
  def restore_selection
    @arr36 = @h18 = @job_ix = @pending = @refining = @flag41 = nil
    @job_name = @job_cfg = @arr32 = @arr21 = @made = @root = @progress = @str = @arr26 = @h4 = @_d94dd3d6 = @_a4b96af4 = @h2 = @arr13 = nil
    set_status(nil)
  end
  def stop_labelling
    KSU::Nesting::Engine.instance.stop_engine rescue nil
    end_label_timer
    restart_collect
    restore_selection
    KSU.abort_batch
    clear_status
  end
  def one_group(e)
    puts "KSU Nesting: #{e.message}"
    stop_labelling
  end
  def part_id(grp)
    id = grp.respond_to?(:get_attribute) ? grp.get_attribute("ABF", "board-index") : nil
    id.nil? ? grp.name.to_s : id.to_s
  end
  def abort_run
    return unless @arr36
    KSU::Nesting::Engine.instance.stop_engine rescue nil
    restore_selection
    KSU.abort_batch
    UI.start_timer(0, false) { clear_status }
  end
  def abort_unless_done
    abort_run unless @flag28
  end
  def cancel_labelling
    stop_labelling if labelling
  end
  def clear_status
    @progress = @str = nil
    set_status(nil)
    KSU::Nesting::Engine.instance.stop rescue nil
    model = Sketchup.active_model
    model.select_tool(nil) if model.tools.active_tool.is_a?(Progress)
    model.active_view.invalidate
    KSU::Settings.mark_stale
    dlg = KSU::Settings.tool_windows
    send_materials(dlg, material_rows(@sel_snapshot)) if dlg
  rescue StandardError
  end
  def to_sheets(job, result)
    (result || []).each_with_object([]) do |arr2, sheets|
      items = arr2.map do |fld|
        grp = job[:parts][fld[0]]
        next [grp, fld[1].to_f, fld[2].to_f, fld[3].to_f, fld[4].nil? ? -1 : fld[4].to_i] if grp
        @arr32.flat_map { |t| t[:parts] }.each { |arr| @arr9 << part_id(arr[:group]) if arr[:bounds_mm].size > 1 } if @arr9.empty?
        nil
      end.compact
      sheets << items unless items.empty?
    end
  end
  def corner_code
    %w[trai_duoi phai_duoi phai_tren trai_tren].index(@job_cfg[:corner]) || 0
  end
  def shift_to_corner(sheets, job)
    err_code = corner_code
    return sheets if err_code == 0
    world_tr, _5d24831c = sheet_area(job), sheet_area(job, true)
    sheets.each do |items|
      w, elem = items.any? { |arr| arr[0][:two_sided] } ? _5d24831c : world_tr
      items.each do |fld|
        x, y = fld[1], fld[2]
        fld[1], fld[2] = case err_code
                                 when 1 then [w - y, x]
                                 when 2 then [w - x, elem - y]
                                 else [y, elem - x]
                                 end
      end
    end
  end
  def margins_of(job_cfg)
    meta = job_cfg[:margins]
    return meta if meta.is_a?(Array) && meta.length == 4
    [job_cfg[:margin].to_f] * 4
  end
  def spacing_settings
    (@job_cfg.is_a?(Hash) ? @job_cfg : job_settings).values_at(:spacing, :margin, :margins)
  end
  def split_margins(edge)
    return [edge] * 4 unless KSU::Settings.get("tach_cach_le_rieng", false, "nesting")
    KSU::Store::MARGIN_SIDES.each_key.map { |s| KSU::Settings.get("tam_cach_le_#{s}_rieng", edge, "nesting").to_f }
  end
  def job_settings
    edge = KSU::Settings.get("tam_cach_le_rieng", 3.5, "nesting")
    {
      sheet_w: KSU::Settings.get("chieu_rong_van", 1220.0, "nesting"),
      sheet_h: KSU::Settings.get("chieu_dai_van", 2440.0, "nesting"),
      spacing: KSU::Settings.get("tam_cach_nhau_rieng", 6.5, "nesting"),
      margin: edge,
      margins: split_margins(edge),
      corner: KSU::Settings.get("goc_don_van", "trai_duoi", "nesting"),
      by_name: KSU::Settings.get("thu_tu_don", "mac_dinh", "nesting") == "theo_ten",
      tach_nhom: !!KSU::Settings.get("tach_nhom_2_mat", true, "nesting"),
      ghep_cap: !!KSU::Settings.get("ghep_cap_toi_uu", true, "nesting"),
      nhom_cap: !!KSU::Settings.get("nhom_cap_am_duong", false, "nesting"),
      hau_ky: !!KSU::Settings.get("tu_dong_hau_ky", true, "nesting")
    }
  end
  def relabel_nesting
    prev_key = KSU::Nesting.find_nesting(notify: false)
    return unless prev_key && prev_key.valid?
    prev_key.erase!
    KSU::View.view.invalidate
  rescue StandardError
    nil
  end
  def apply_label_plan(job_cfg, saved_sel)
    flag = saved_sel ? collect_parts(saved_sel) : []
    renumber = KSU::Label.label_plan(flag) unless saved_sel && flag.empty?
    if renumber.nil? || renumber[:jobs].empty?
      return apply_label_plan(job_cfg, nil) if saved_sel && UI.messagebox("Có vấn đề với dữ liệu nhãn. Tự động gắn lại nhãn?", MB_YESNO) == IDYES
      KSU.abort_batch
      return clear_status
    end
    _8ab67ce9 = KSU::Settings.get("nhan_dat_trong_tam", false, "gan_nhan")
    @label_ctx = {
      max_size: KSU::Settings.get("kich_thuoc_nhan", 50.0, "gan_nhan").mm,
      gap: KSU::Settings.get("do_gian_chu", -0.1, "gan_nhan"),
      xf: KSU::Settings.get("chieu_rong_chu", 80, "gan_nhan") / 100.0,
      letter_case: KSU::Settings.get("kieu_tieu_de", "upper", "gan_nhan"),
      center: !_8ab67ce9, renumber: renumber[:renumber]
    }
    @_904e338e, @_3a91e949, @jobs, @layer2 = job_cfg, saved_sel, renumber[:jobs], renumber[:layer]
    @label_total, @label_done, @labelling = @jobs.size, 0, true
    KSU.select_tool(Progress) unless Sketchup.active_model.tools.active_tool.instance_of?(Progress)
    KSU::View.view.invalidate
    @label_timer = UI.start_timer(0, true) { label_step }
  end
  def label_step
    return label_finish2 if @label_done >= @label_total
    @jobs[@label_done, 16].each do |job|
      KSU::Label.draw_label_on(job[0], job[1], @layer2, @label_ctx) if job && job[0] && job[0].valid?
      @label_done += 1
    end
    KSU::View.view.invalidate
  rescue StandardError => e
    puts "KSU Nesting: #{e.message}"
    end_label_timer
    KSU.abort_batch
    clear_status
  end
  def label_finish2
    job_cfg, saved_sel = @_904e338e, @_3a91e949
    end_label_timer
    KSU::View.view.invalidate
    start_collect(job_cfg, false, saved_sel)
  rescue StandardError => e
    one_group(e)
  end
  def end_label_timer
    UI.stop_timer(@label_timer) if @label_timer
    @labelling = false
    @label_timer = @_904e338e = @_3a91e949 = @jobs = @layer2 = @label_ctx = nil
  end
  def abort_labelling
    return unless @labelling
    end_label_timer
    KSU.abort_batch
    UI.start_timer(0, false) { clear_status }
  end
end
module KSU::Nest
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (61 + i * 87) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
