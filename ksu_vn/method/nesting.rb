module KSU::Nest
  extend self
  class Progress
    include KSU::Preset
    def activate
      KSU::View.view.invalidate
    end
    def deactivate(view)
      KSU::Nest._b2c4c1d5
      KSU::Nest._2d469ec2
      KSU::Nest.abort_unless_done
      view.invalidate
    end
    def draw(view)
      if KSU::Nest.labelling
        sweep = KSU::Nest.label_total
        done = KSU::Nest.label_done
        draw_mode_hint(view, "Đang gắn nhãn... #{[done + 1, sweep].min}/#{sweep}", 10)
        return
      end
      progress = KSU::Nest.num12
      return unless progress
      name2 = KSU::Nest.name
      lbl = KSU::Nest.str || "Đang nesting"
      text = name2 ? "#{name2} | #{lbl}... #{progress}%" : "#{lbl}... #{progress}%"
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
      _b9664cc7
      KSU::View.view.invalidate
    end
    def deactivate(view)
      stop_timer
      KSU::Nest.abort_run unless @flag22
      view.invalidate
    end
    def draw(view)
      return unless @num5 && @num5 > 0
      name2 = KSU::Nest.refine_name
      text = name2 ? "#{name2} | Đang hậu kỳ... #{percent}%" : "Đang hậu kỳ... #{percent}%"
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
  def num12
    @num12
  end
  def str
    @str
  end
  def name
    @name
  end
  def refine_name
    @refine_name
  end
  def refine_parts
    @refine_parts
  end
  def rotate_by_name
    color = @h18
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
      _a762c251
    end
    return if @num12 || @labelling
    KSU::Settings.open_window("nesting")
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def start3(h18, rows)
    @h18 = h18
    @arr61 = rows
    @arr45 = []
    @arr39 = []
    @arr51 = []
    @h22 = {}
    @num4 = 0
    @flag42 = false
    @flag58 = false
    @arr47 = []
    rows.each do |_381d1670|
      groups = one_group(_381d1670)
      next if groups.empty?
      slots = groups.any? { |g| g[:two] } ? 2 : 1
      groups.each_with_index do |arr, i|
        @arr47 << { type: _381d1670, two: arr[:two], parts: arr[:parts],
                              last: i == groups.length - 1, slots: slots }
      end
    end
    if @arr47.empty?
      _a762c251
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    jobs = []
    @arr47.each do |job|
      members = build_parts(job)
      unless members
        _a762c251
        UI.messagebox("Có lỗi xảy ra khi nesting!")
        return
      end
      jobs << members
    end
    _f8f8046f
    hide_all
    _47d154e7(jobs)
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def split_two?(job)
    !!job[:two] && @h18[:tach_nhom] != false
  end
  def sheet_area(job)
    _b41d8800, half, thick, b = margins_of(@h18)
    width_mm = @h18[:sheet_w] - _b41d8800 - half
    height_mm = @h18[:sheet_h] - thick - b
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
    h18 = @h18
    flat = []
    rot = []
    arr3 = []
    arr4 = []
    layers = {}
    if h18[:by_name]
      job[:parts].each_with_index
                    .sort_by { |arr, i| [KSU::Nesting.sort_key(arr[:group].name), i] }
                    .each_with_index { |(_56afdcfc, _b57e5a96), half| layers[_b57e5a96] = half }
    end
    job[:parts].each_with_index do |arr, _b57e5a96|
      arr[:bounds_mm].each do |b|
        flat << b
        rot << (arr[:rotatable] != false)
        arr3 << (arr[:two_sided] == true)
        arr4 << (layers[_b57e5a96] || 0)
      end
    end
    err_code = corner_code
    groups = rotate_coords([flat], err_code)
    _e84e5dc5 = err_code == 1 || err_code == 3
    w2, h2 = pack_area(job)
    return nil if w2 <= 0 || h2 <= 0
    {
      w: _e84e5dc5 ? height_mm : width_mm,
      h: _e84e5dc5 ? width_mm : height_mm,
      w2: _e84e5dc5 ? h2 : w2,
      h2: _e84e5dc5 ? w2 : h2,
      sp: h18[:spacing],
      rot: rot,
      holes: true,
      parts: groups[0],
      two: h18[:tach_nhom] ? arr3 : [],
      ord: h18[:by_name] ? arr4 : [],
      pair: h18[:ghep_cap] != false
    }
  end
  def _47d154e7(jobs)
    @name = @arr47[0][:type][:name]
    @num12 = 0
    @str = "Đang tính dữ liệu"
    model = Sketchup.active_model
    _02d60c07(Progress) unless model.tools.active_tool.instance_of?(Progress)
    KSU::Nesting::Engine.instance.start_jobs(
      jobs: jobs,
      on_job_progress: lambda { |j, progress|
        if j == @num4 && @str != "Đang xếp tấm"
          @num12 = progress
          KSU::View.view.invalidate
        end
      },
      on_job_place_progress: lambda { |j, done, sweep|
        if j == @num4
          @str = "Đang xếp tấm"
          @num12 = sweep > 0 ? (done * 100.0 / sweep).round : 100
          KSU::View.view.invalidate
        end
      },
      on_job_done: ->(j, data, _c11be090) { _77cf09ee(j, data, _c11be090) }
    )
  end
  def _77cf09ee(j, data, _c11be090)
    return unless @h18 && @h22
    @h22[j] = [data, _c11be090]
    _37275936
  end
  def _37275936
    return if @flag42 || @flag58
    @flag58 = true
    while @h18 && @h22 && @h22.key?(@num4)
      data, arr2 = @h22.delete(@num4)
      job = @arr47[@num4]
      @num4 += 1
      _3ac6e0c3(job, [[0, arr2]]) if arr2 && !arr2.empty?
      sheets = data ? to_sheets(job, data) : []
      shift_to_corner(sheets, job)
      @arr51.concat(sheets)
      next unless job[:last]
      arr3 = @arr51
      @arr51 = []
      flag = arr3.empty? ? [] : _146dab1a(job, arr3)
      next unless @h18[:hau_ky] && !flag.empty?
      @refine_parts = flag
      @refine_name = job[:type][:name]
      @flag42 = true
      @flag58 = false
      _02d60c07(Refine)
      return
    end
    @flag58 = false
    return unless @h18
    if @num4 >= @arr47.length
      _3bfa2532
    else
      @name = @arr47[@num4][:type][:name]
      @num12 = 0
      @str = "Đang tính dữ liệu"
      model = Sketchup.active_model
      _02d60c07(Progress) unless model.tools.active_tool.instance_of?(Progress)
      model.active_view.invalidate
    end
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  ensure
    @flag58 = false
  end
  def _02d60c07(_75318d78)
    @flag24 = true
    KSU.select_tool(_75318d78)
  ensure
    @flag24 = false
  end
  def finish
    @refine_parts = nil
    @refine_name = nil
    @flag42 = false
    return clear_progress unless @arr47
    _37275936
  end
  def _3bfa2532
    @arr47 = nil
    @h22 = nil
    @num4 = nil
    @arr51 = nil
    @name = nil
    @num12 = nil
    @str = nil
    _9ce24ea4
    restore_view
    _741ca308
    @h18 = nil
    @arr61 = nil
    @arr45 = nil
    @arr39 = nil
    clear_progress
  end
  def _0b686c6e
    @arr47 = nil
    @h22 = nil
    @num4 = nil
    @refine_parts = nil
    @refine_name = nil
    @flag42 = false
    @flag58 = false
    @arr51 = nil
    @name = nil
    @h18 = nil
    @arr61 = nil
    @arr45 = nil
    @arr39 = nil
    @grp2 = nil
    @num12 = nil
    @str = nil
  end
  def _a762c251
    stop_engine
    _90d58cd9
    _0b686c6e
    restore_view
    clear_progress
  end
  def abort_run
    return unless @arr47
    stop_engine
    _0b686c6e
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
    @num12 = nil
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
    case @h18[:corner]
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
  def margins_of(h18)
    meta = h18[:margins]
    return meta if meta.is_a?(Array) && meta.length == 4
    [h18[:margin].to_f] * 4
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
  def run2(h18, arr = nil)
    flag = arr && !arr.empty?
    arr2 = []
    _17ee8011(arr, arr2, {}) if flag
    if flag && arr2.empty?
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    renumber = KSU::Label.plan(arr2)
    if renumber.nil? || renumber[:jobs].empty?
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    _e25d94df = !!KSU::Settings.get("nhan_dat_trong_tam", false, "gan_nhan")
    @_dc5a9dc0 = {
      max_size: KSU::Settings.get("kich_thuoc_nhan", 50.0, "gan_nhan").to_f.mm,
      gap: KSU::Settings.get("do_gian_chu", -0.1, "gan_nhan").to_f,
      xf: KSU::Settings.get("chieu_rong_chu", 80, "gan_nhan").to_i / 100.0,
      letter_case: KSU::Settings.get("kieu_tieu_de", "upper", "gan_nhan").to_s,
      center: !_e25d94df,
      renumber: renumber[:renumber]
    }
    @_a7e29efc = h18
    @_576fddc0 = arr
    @jobs = renumber[:jobs]
    @layer2 = renumber[:layer]
    @label_total = @jobs.size
    @label_done = 0
    @labelling = true
    model = Sketchup.active_model
    KSU.select_tool(Progress) unless model.tools.active_tool.instance_of?(Progress)
    KSU.start(true)
    model.active_view.invalidate
    @_b32edef9 = UI.start_timer(0, true) { label_step }
  end
  def label_step
    return _0c3a8be0 if @label_done >= @label_total
    n = 0
    while n < 16 && @label_done < @label_total
      job = @jobs[@label_done]
      KSU::Label.draw_label_on(job[0], job[1], @layer2, @_dc5a9dc0) if job && job[0] && job[0].valid?
      @label_done += 1
      n += 1
    end
    KSU::View.view.invalidate
  rescue StandardError => ent
    _a3c31f39(ent.message)
  end
  def _0c3a8be0
    h18 = @_a7e29efc
    _4effcb0e = @_576fddc0
    _37cfb2cb
    KSU.commit
    KSU::View.view.invalidate
    h18.delete(:materials) if h18.is_a?(Hash)
    _33959628(h18, false, _4effcb0e)
  rescue StandardError => ent
    _a762c251
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
  def _a3c31f39(msg2)
    _37cfb2cb
    KSU.abort_op
    clear_progress
    UI.messagebox("Lỗi gắn nhãn: #{msg2}")
  end
  def _37cfb2cb
    UI.stop_timer(@_b32edef9) if @_b32edef9
    @_b32edef9 = nil
    @labelling = false
    @_a7e29efc = nil
    @_576fddc0 = nil
    @jobs = nil
    @layer2 = nil
    @_dc5a9dc0 = nil
  end
  def _b2c4c1d5
    return unless @labelling
    _37cfb2cb
    KSU.abort_op
  end
  def _3ac6e0c3(job, arr24)
    return if arr24.nil? || arr24.empty?
    arr24.each do |_8f637db2, parts|
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
  def _741ca308
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
