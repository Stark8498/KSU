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
      if KSU::Nest.labelling
        total = KSU::Nest.label_total
        done = KSU::Nest.label_done
        draw_mode_hint(view, "Đang gắn nhãn... #{[done + 1, total].min}/#{total}", 10)
        return
      end
      pct = KSU::Nest.progress
      return unless pct
      name = KSU::Nest.type_name
      lbl = KSU::Nest.str || "Đang nesting"
      text = name ? "#{name} | #{lbl}... #{pct}%" : "#{lbl}... #{pct}%"
      draw_mode_hint(view, text)
    end
  end
  class Refine < Progress
    include KSU::Nesting
    include KSU::Postproc
    include KSU::Engine
    include KSU::Back
    def activate
      @flag22 = false
      @nesting = KSU::Nesting.find_nesting(notify: false)
      unless @nesting && @nesting.valid?
        @flag22 = true
        UI.start_timer(0, false) { KSU::Nest.finish }
        return
      end
      @tu_dong_hau_ky = true
      @tam_cach_nhau = KSU::Settings.get("tam_cach_nhau", 6.5, "cai_dat").to_f.mm
      @tam_cach_le = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f.mm
      @cho_phep_xoay = true
      @arr31 = KSU::Nest.rotate_by_name
      @goc_don_van = KSU::Settings.get("goc_don_van", "trai_duoi", "nesting").to_s
      KSU::View.load_colors
      sheet_list
      arr = KSU::Nest.refine_parts
      arr3 = arr && !arr.empty? ? arr : @sheets.map { |i| i[:instance] }
      @sel = arr3.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
      if @sel.empty?
        @flag22 = true
        UI.start_timer(0, false) { KSU::Nest.finish }
        return
      end
      start_postpass
      KSU::View.view.invalidate
    end
    def deactivate(view)
      stop_timer
      KSU::Nest.abort_run unless @flag22
      view.invalidate
    end
    def draw(view)
      return unless @num5 && @num5 > 0
      name = KSU::Nest.refine_name
      text = name ? "#{name} | Đang hậu kỳ... #{percent}%" : "Đang hậu kỳ... #{percent}%"
      draw_mode_hint(view, text)
    end
    def cancel
      @flag53 = true
      @flag22 = true
      stop_timer
      KSU::View.clear_cache
      KSU::View.view&.invalidate
      KSU::Nest.finish
    end
    def sheet_list
      @sheets = KSU::Sheet.sheet_list(@nesting)
    end
    def sheet_recs
      @sheets
    end
    def reload_sheets
      sheet_list
    end
  end
  def progress
    @progress
  end
  def str
    @str
  end
  def type_name
    @type_name
  end
  def refine_name
    @refine_name
  end
  def refine_parts
    @refine_parts
  end
  def rotate_by_name
    color = @cfg
    color.is_a?(Hash) && color[:rotate_by_name].is_a?(Hash) ? color[:rotate_by_name] : {}
  end
  def labelling
    @labelling
  end
  def label_total
    @label_total.to_i
  end
  def label_done
    @label_done.to_i
  end
  def open
    KSU::Intem.check_license
    KSU::Xuatdxf.assert_license
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    k = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    if @arr47
      tool = Sketchup.active_model.tools.active_tool
      return if tool.is_a?(Progress)
      abort_collect
    end
    return if @progress || @labelling
    KSU::Settings.open_window("nesting")
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def start3(cfg, rows)
    @cfg = cfg
    @arr61 = rows
    @arr45 = []
    @arr39 = []
    @arr51 = []
    @h22 = {}
    @num4 = 0
    @flag42 = false
    @flag58 = false
    @arr47 = []
    rows.each do |type|
      groups = one_group(type)
      next if groups.empty?
      slots = groups.any? { |g| g[:two] } ? 2 : 1
      groups.each_with_index do |arr, i|
        @arr47 << { type: type, two: arr[:two], parts: arr[:parts],
                              last: i == groups.length - 1, slots: slots }
      end
    end
    if @arr47.empty?
      abort_collect
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    job_list = []
    @arr47.each do |job|
      members = build_parts(job)
      unless members
        abort_collect
        UI.messagebox("Có lỗi xảy ra khi nesting!")
        return
      end
      job_list << members
    end
    reset_layout
    hide_all
    start_run(job_list)
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def split_two?(job)
    !!job[:two] && @cfg[:tach_nhom] != false
  end
  def sheet_area(job)
    m_left, half, thick, b = margins_of(@cfg)
    width_mm = @cfg[:sheet_w] - m_left - half
    height_mm = @cfg[:sheet_h] - thick - b
    if job[:two] && !split_two?(job)
      len2d = KSU::Avail.two_sided_margin
      width_mm -= len2d
      height_mm -= len2d
    end
    [width_mm, height_mm]
  end
  def pack_area(job)
    width_mm, height_mm = sheet_area(job)
    return [width_mm, height_mm] unless split_two?(job)
    len2d = KSU::Avail.two_sided_margin
    [width_mm - len2d, height_mm - len2d]
  end
  def build_parts(job)
    width_mm, height_mm = sheet_area(job)
    return nil if width_mm <= 0 || height_mm <= 0
    cfg = @cfg
    flat = []
    rot = []
    arr3 = []
    arr4 = []
    layers = {}
    if cfg[:by_name]
      job[:parts].each_with_index
                    .sort_by { |arr, i| [KSU::Nesting.sort_key(arr[:group].name), i] }
                    .each_with_index { |(lv, pi), half| layers[pi] = half }
    end
    job[:parts].each_with_index do |arr, pi|
      arr[:bounds_mm].each do |b|
        flat << b
        rot << (arr[:rotatable] != false)
        arr3 << (arr[:two_sided] == true)
        arr4 << (layers[pi] || 0)
      end
    end
    err_code = corner_code
    groups = rotate_coords([flat], err_code)
    swapped = err_code == 1 || err_code == 3
    w2, h2 = pack_area(job)
    return nil if w2 <= 0 || h2 <= 0
    {
      w: swapped ? height_mm : width_mm,
      h: swapped ? width_mm : height_mm,
      w2: swapped ? h2 : w2,
      h2: swapped ? w2 : h2,
      sp: cfg[:spacing],
      rot: rot,
      holes: true,
      parts: groups[0],
      two: cfg[:tach_nhom] ? arr3 : [],
      ord: cfg[:by_name] ? arr4 : [],
      pair: cfg[:ghep_cap] != false
    }
  end
  def start_run(job_list)
    @type_name = @arr47[0][:type][:name]
    @progress = 0
    @str = "Đang tính dữ liệu"
    model = Sketchup.active_model
    switch_tool(Progress) unless model.tools.active_tool.instance_of?(Progress)
    KSU::Nesting::Engine.instance.start_jobs(
      jobs: job_list,
      on_job_progress: lambda { |j, pct|
        if j == @num4 && @str != "Đang xếp tấm"
          @progress = pct
          KSU::View.view.invalidate
        end
      },
      on_job_place_progress: lambda { |j, done, total|
        if j == @num4
          @str = "Đang xếp tấm"
          @progress = total > 0 ? (done * 100.0 / total).round : 100
          KSU::View.view.invalidate
        end
      },
      on_job_done: ->(j, data, label_data) { job_done(j, data, label_data) }
    )
  end
  def job_done(j, data, label_data)
    return unless @cfg && @h22
    @h22[j] = [data, label_data]
    drain_jobs
  end
  def drain_jobs
    return if @flag42 || @flag58
    @flag58 = true
    while @cfg && @h22 && @h22.key?(@num4)
      data, label_data = @h22.delete(@num4)
      job = @arr47[@num4]
      @num4 += 1
      tag_parts(job, [[0, label_data]]) if label_data && !label_data.empty?
      sheets = data ? to_sheets(job, data) : []
      shift_to_corner(sheets, job)
      @arr51.concat(sheets)
      next unless job[:last]
      arr3 = @arr51
      @arr51 = []
      flag = arr3.empty? ? [] : draw_job(job, arr3)
      next unless @cfg[:hau_ky] && !flag.empty?
      @refine_parts = flag
      @refine_name = job[:type][:name]
      @flag42 = true
      @flag58 = false
      switch_tool(Refine)
      return
    end
    @flag58 = false
    return unless @cfg
    if @num4 >= @arr47.length
      finish_run
    else
      @type_name = @arr47[@num4][:type][:name]
      @progress = 0
      @str = "Đang tính dữ liệu"
      model = Sketchup.active_model
      switch_tool(Progress) unless model.tools.active_tool.instance_of?(Progress)
      model.active_view.invalidate
    end
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  ensure
    @flag58 = false
  end
  def switch_tool(tool_cls)
    @flag24 = true
    KSU.select_tool(tool_cls)
  ensure
    @flag24 = false
  end
  def finish
    @refine_parts = nil
    @refine_name = nil
    @flag42 = false
    return clear_progress unless @arr47
    drain_jobs
  end
  def finish_run
    @arr47 = nil
    @h22 = nil
    @num4 = nil
    @arr51 = nil
    @type_name = nil
    @progress = nil
    @str = nil
    finish_draw
    restore_view
    restore_selection
    @cfg = nil
    @arr61 = nil
    @arr45 = nil
    @arr39 = nil
    clear_progress
  end
  def reset_jobs
    @arr47 = nil
    @h22 = nil
    @num4 = nil
    @refine_parts = nil
    @refine_name = nil
    @flag42 = false
    @flag58 = false
    @arr51 = nil
    @type_name = nil
    @cfg = nil
    @arr61 = nil
    @arr45 = nil
    @arr39 = nil
    @root = nil
    @progress = nil
    @str = nil
  end
  def abort_collect
    stop_engine
    clear_collect
    reset_jobs
    restore_view
    clear_progress
  end
  def abort_run
    return unless @arr47
    stop_engine
    reset_jobs
    restore_view
  end
  def abort_unless_done
    return if @flag24
    abort_run
  end
  def stop_engine
    return unless defined?(KSU::Nesting::Engine)
    KSU::Nesting::Engine.instance.stop
  rescue StandardError
    nil
  end
  def hide_all
    model = Sketchup.active_model
    @arr60 = []
    KSU.start
    model.entities.each do |ent|
      next unless ent.respond_to?(:hidden?) && ent.respond_to?(:hidden=)
      next if ent.hidden?
      ent.hidden = true
      @arr60 << ent
    end
    KSU.commit
    opts = model.rendering_options
    opts["DisplayCoordinateAxes"] = false if opts.keys.include?("DisplayCoordinateAxes")
    @prev_persp = KSU::View.enter_top_view(model)
  rescue StandardError
    KSU.abort_op
  end
  def restore_view
    model = Sketchup.active_model
    model.active_view.zoom_extents
    if @arr60 && !@arr60.empty?
      KSU.start
      @arr60.each { |ent| ent.hidden = false if ent && ent.valid? }
      KSU.commit
    end
    @arr60 = nil
    opts = model.rendering_options
    opts["DisplayCoordinateAxes"] = true if opts.keys.include?("DisplayCoordinateAxes")
    KSU::View.restore_perspective(@prev_persp)
    @prev_persp = nil
    model.active_view.invalidate
  rescue StandardError
    KSU.abort_op
  end
  def clear_progress
    @progress = nil
    @str = nil
    model = Sketchup.active_model
    model.select_tool(nil) if model.tools.active_tool.is_a?(Progress)
    model.active_view.invalidate
  rescue StandardError
    nil
  end
  def one_group(arr)
    return [] if arr[:parts].empty?
    [{ two: arr[:parts].any? { |arr2| arr2[:two_sided] }, parts: arr[:parts] }]
  end
  def to_sheets(job, result)
    sheets = []
    (result || []).each do |sheet|
      items = sheet.map do |fld|
        grp = job[:parts][fld[0]]
        unless grp
          warn_missing
          next nil
        end
        [grp, fld[1].to_f, fld[2].to_f, fld[3].to_f, fld[4].nil? ? -1 : fld[4].to_i]
      end.compact
      sheets << items unless items.empty?
    end
    sheets
  end
  def corner_code
    case @cfg[:corner]
    when "phai_duoi" then 1
    when "phai_tren" then 2
    when "trai_tren" then 3
    else 0
    end
  end
  def rotate_coords(groups, err_code)
    return groups if err_code == 0
    groups.map do |loops|
      loops.map do |arr2|
        arr2.map do |arr|
          case err_code
          when 1 then [arr[1], -arr[0]]
          when 2 then [-arr[0], -arr[1]]
          else [-arr[1], arr[0]]
          end
        end
      end
    end
  end
  def shift_to_corner(sheets, job)
    err_code = corner_code
    return if err_code == 0
    w1, h1 = sheet_area(job)
    w2, h2 = pack_area(job)
    sheets.each do |items|
      flag = items.any? { |arr| arr[0][:two_sided] }
      width_mm = flag ? w2 : w1
      height_mm = flag ? h2 : h1
      items.each do |fld|
        x = fld[1]
        y = fld[2]
        case err_code
        when 1
          fld[1] = width_mm - y
          fld[2] = x
        when 2
          fld[1] = width_mm - x
          fld[2] = height_mm - y
        when 3
          fld[1] = y
          fld[2] = height_mm - x
        end
      end
    end
  end
  def margins_of(cfg)
    meta = cfg[:margins]
    return meta if meta.is_a?(Array) && meta.length == 4
    [cfg[:margin].to_f] * 4
  end
  def job_settings
    edge = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f
    {
      sheet_w: KSU::Settings.get("chieu_rong_van", 1220.0, "nesting").to_f,
      sheet_h: KSU::Settings.get("chieu_dai_van", 2440.0, "nesting").to_f,
      spacing: KSU::Settings.get("tam_cach_nhau", 6.5, "cai_dat").to_f,
      margin: edge,
      margins: KSU::Avail.sides_mm(edge),
      corner: KSU::Settings.get("goc_don_van", "trai_duoi", "nesting").to_s,
      by_name: KSU::Settings.get("thu_tu_don", "mac_dinh", "nesting").to_s == "theo_ten",
      tach_nhom: !!KSU::Settings.get("tach_nhom_2_mat", true, "nesting"),
      ghep_cap: !!KSU::Settings.get("ghep_cap_toi_uu", true, "nesting"),
      nhom_cap: !!KSU::Settings.get("nhom_cap_am_duong", false, "nesting"),
      hau_ky: !!KSU::Settings.get("tu_dong_hau_ky", true, "nesting")
    }
  end
  def close_contexts
    model = Sketchup.active_model
    model.close_active while model.active_path
  rescue StandardError
    nil
  end
  def erase_nesting
    prev_key = KSU::Nesting.find_nesting(notify: false)
    return unless prev_key && prev_key.valid?
    KSU.start
    prev_key.erase!
    KSU.commit
    KSU::View.view.invalidate
  rescue StandardError
    KSU.abort_op
  end
  def ask_relabel(err)
    return true unless err == :dup_ids
    UI.messagebox("Có vấn đề với dữ liệu nhãn. Tự động gắn lại nhãn?", MB_YESNO) == IDYES
  end
  def run2(cfg, saved_sel = nil)
    flag = saved_sel && !saved_sel.empty?
    arr2 = []
    gather_boards(saved_sel, arr2, {}) if flag
    if flag && arr2.empty?
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    renumber = KSU::Label.label_plan(arr2)
    if renumber.nil? || renumber[:jobs].empty?
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    center_labels = !!KSU::Settings.get("nhan_dat_trong_tam", false, "gan_nhan")
    @label_ctx = {
      max_size: KSU::Settings.get("kich_thuoc_nhan", 50.0, "gan_nhan").to_f.mm,
      gap: KSU::Settings.get("do_gian_chu", -0.1, "gan_nhan").to_f,
      xf: KSU::Settings.get("chieu_rong_chu", 80, "gan_nhan").to_i / 100.0,
      letter_case: KSU::Settings.get("kieu_tieu_de", "upper", "gan_nhan").to_s,
      center: !center_labels,
      renumber: renumber[:renumber]
    }
    @pend_cfg = cfg
    @pend_sel = saved_sel
    @jobs = renumber[:jobs]
    @layer2 = renumber[:layer]
    @label_total = @jobs.size
    @label_done = 0
    @labelling = true
    model = Sketchup.active_model
    KSU.select_tool(Progress) unless model.tools.active_tool.instance_of?(Progress)
    KSU.start(true)
    model.active_view.invalidate
    @label_timer = UI.start_timer(0, true) { label_step }
  end
  def label_step
    return label_finish2 if @label_done >= @label_total
    n = 0
    while n < 16 && @label_done < @label_total
      job = @jobs[@label_done]
      KSU::Label.draw_label_on(job[0], job[1], @layer2, @label_ctx) if job && job[0] && job[0].valid?
      @label_done += 1
      n += 1
    end
    KSU::View.view.invalidate
  rescue StandardError => ent
    label_fail2(ent.message)
  end
  def label_finish2
    cfg = @pend_cfg
    saved_sel = @pend_sel
    label_reset
    KSU.commit
    KSU::View.view.invalidate
    cfg.delete(:materials) if cfg.is_a?(Hash)
    start_collect(cfg, false, saved_sel)
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def label_fail2(msg2)
    label_reset
    KSU.abort_op
    clear_progress
    UI.messagebox("Lỗi gắn nhãn: #{msg2}")
  end
  def label_reset
    UI.stop_timer(@label_timer) if @label_timer
    @label_timer = nil
    @labelling = false
    @pend_cfg = nil
    @pend_sel = nil
    @jobs = nil
    @layer2 = nil
    @label_ctx = nil
  end
  def abort_labelling
    return unless @labelling
    label_reset
    KSU.abort_op
  end
  def tag_parts(job, arr24)
    return if arr24.nil? || arr24.empty?
    arr24.each do |lvl2, parts|
      Array(parts).each do |num2|
        grp = job[:parts][num2.to_i]
        next unless grp
        g = grp[:group]
        next unless g && g.valid?
        id = g.get_attribute("ABF", "board-index")
        @arr45 << id.to_s if id
        @arr39 << g
      end
    end
  end
  def restore_selection
    return if @arr45.nil? || @arr45.empty?
    ents = (@arr39 || []).select { |g| g && g.valid? }
    KSU.select_only(ents)
    UI.messagebox("Cảnh báo! Có tấm vượt khổ! ID: #{@arr45.uniq.join(', ')}.")
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
