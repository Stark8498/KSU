class KSU::Gannhan
  include KSU::Preset
  include KSU::Quet
  tool_key "gan_nhan"
  MODE_GAN = 0
  MODE_SUA = 1
  MODE_KIEM = 2
  def initialize
    KSU::Chongbay.check_license
    KSU::Netcatcuoi.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    k = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @mode ||= 0
    @labelling = false
    @label_sel = false
    @label_total = 0
    @label_done = 0
    @bo_qua_kich_thuoc = !!get("bo_qua_kich_thuoc", false)
    @bo_qua_net_dung = !!get("bo_qua_net_dung", false)
    @bo_qua_chu = !!get("bo_qua_chu", false)
    load_overlay_settings
    @ten_mac_dinh = get("ten_mac_dinh", "KSU").to_s
    @chuan_hoa_vat_lieu = !!get("chuan_hoa_vat_lieu", false)
    @cap_nhat_nhan_da_co = !!get("cap_nhat_nhan_da_co", true)
    @kich_thuoc_nhan = get("kich_thuoc_nhan", 50.0).to_f.mm
    @do_gian_chu = get("do_gian_chu", -0.1).to_f
    @chieu_rong_chu = get("chieu_rong_chu", 80).to_i
    @kieu_tieu_de = get("kieu_tieu_de", "upper").to_s
    @nhan_dat_trong_tam = !!get("nhan_dat_trong_tam", false)
    @goc_xoay_nhan = get("goc_xoay_nhan", 90).to_i
    @presets = get("presets", nil)
    if Sketchup.active_model.tools.active_tool == self
      @scope ||= []
      @arr4 ||= []
      collect_in_rect if @mode == MODE_KIEM
      nesting = KSU::Nesting.find_nesting(notify: false)
      @err_pts = KSU::Nesting.error_points(nesting)
      @_x_bi_lan_polys = nil
      @label_section_hidden = KSU::Cutting.apply_label_hiding(nesting, @an_nhan_tiet_dien, @label_section_hidden)
    else
      @label_section_hidden = []
      @scope = []
      @arr4 = []
      @err_pts = []
      @_x_bi_lan_polys = nil
    end
  end
  def activate
    KSU::Chongbay.check_license
    KSU::Netcatcuoi.assert_license
    @mode = MODE_GAN
    reload
    model = Sketchup.active_model
    @scope = model.selection.empty? ? model.entities.to_a : model.selection.to_a
    @arr4 = []
    KSU::View.load_colors
    KSU::Preset.load_cfg
    init_modes(
      ["Gắn nhãn", "Sửa nhãn", "Kiểm nhãn"],
      active_proc: -> { @mode },
      on_click: ->(i) { switch_mode(i) },
    )
    setup_fields(
      "Tên mặc định" => {
        ten_mac_dinh: [:text, "Tên mặc định", -> { @mode == MODE_GAN }],
      },
      "Chuẩn hóa vật liệu" => {
        chuan_hoa_vat_lieu: [:switch, "Chuẩn hóa vật liệu", -> { @mode != MODE_KIEM }],
      },
      "Cập nhật nhãn đã có" => {
        cap_nhat_nhan_da_co: [:switch, "Cập nhật nhãn đã có", -> { @mode == MODE_GAN }],
      },
      "Gắn nhãn" => {
        nhan_dat_trong_tam: [:switch, "Nhãn đặt trong tấm", -> { @mode != MODE_KIEM }],
        kich_thuoc_nhan: [:mm, "Kích thước nhãn", -> { @mode != MODE_KIEM }, 0, 10000],
        chieu_rong_chu: [:value, "Chiều rộng chữ", -> { @mode == MODE_GAN }, 10, 200],
        do_gian_chu: [:select, "Độ giãn chữ", { 0.1 => "Thưa", 0.0 => "Vừa", -0.1 => "Hẹp" }, -> { @mode == MODE_GAN }],
        kieu_tieu_de: [:select, "Định dạng chữ", { "upper" => "AA", "title" => "Aa", "lower" => "aa", "none" => "Không" }, -> { @mode == MODE_GAN }],
      },
      "Sửa nhãn" => {
        goc_xoay_nhan: [:value, "Góc xoay nhãn", -> { @mode == MODE_SUA }, 1, 359],
      },
      "Kiểm nhãn" => {
        bo_qua_kich_thuoc: [:switch, "Bỏ qua kích thước", -> { @mode == MODE_KIEM }],
        bo_qua_net_dung: [:switch, "Bỏ qua nét dựng", -> { @mode == MODE_KIEM }],
        bo_qua_chu: [:switch, "Bỏ qua chữ", -> { @mode == MODE_KIEM }],
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS,
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(KSU::Nesting.find_nesting(notify: false), @an_nhan_tiet_dien, @label_section_hidden)
    update_status
    model.active_view.invalidate
  end
  def deactivate(view)
    reset
    stop_labelling(true) if @labelling
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nil, false, @label_section_hidden)
    view&.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    draw_overlay(view)
    draw_rect(view)
    draw_modes(view) unless @labelling
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "Đang gắn nhãn... #{[@label_done + 1, @label_total].min}/#{@label_total}", 10) if @labelling
  end
  def onMouseMove(kflags, x, y, view)
    hover_field(x, y, view)
    hover_mode(x, y, view)
    hover_preset(x, y, view)
    return unless edit_mode? || attach_mode?
    return update_drag(x, y, view) if started?
    return unless edit_mode?
    hover_label(x, y, view)
  end
  def onLButtonDown(kflags, x, y, view)
    return if click_field(x, y, view)
    return if click_mode(x, y, view)
    return if click_outside(x, y, view)
    return unless edit_mode? || attach_mode?
    begin_drag(x, y)
  end
  def onLButtonUp(kflags, x, y, view)
    return unless edit_mode? || attach_mode?
    arr = end_drag(x, y)
    return unless arr
    if attach_mode?
      if arr[0] == :rect
        pick_boards_in_rect(view, arr[1], arr[2])
      else
        pick_board_at(view, x, y)
      end
    elsif arr[0] == :rect
      pick_labels_in_rect(view, arr[1], arr[2])
    else
      click_label(view, x, y)
    end
  end
  def onKeyDown(key, rep, rot, view)
    return if @labelling
    case key
    when 192
      KSU::Settings.open_settings("gan_nhan")
    when 9
      if edit_mode? && selected_pairs.any?
        rotate_labels
      else
        switch_mode((@mode + 1) % 3)
      end
    when 13
      if @mode == MODE_KIEM
        isolate_bad
      elsif @mode == MODE_GAN
        run_attach((rot & CONSTRAIN_MODIFIER_MASK) != 0)
      end
    when 27
      KSU.select_tool(nil)
      return true
    end
  end
  private
  def edit_mode?
    @mode == MODE_SUA && !@labelling
  end
  def attach_mode?
    @mode == MODE_GAN && !@labelling
  end
  def labelable?(ent)
    return false unless ent && ent.valid? && KSU.container?(ent)
    !KSU::Cutting.board_faces(ent, KSU::Label.world_tf(ent)).nil?
  end
  def pick_boards_in_rect(view, rect, strict)
    KSU.select_only(KSU::Quet.collect_in_rect(view, rect, strict) { |ent| labelable?(ent) })
    view.invalidate
  end
  def pick_board_at(view, x, y)
    board = board_at(view, x, y)
    KSU.select_only(board || [])
    view.invalidate
  end
  def walk_pick(view, x, y)
    ph = view.pick_helper
    ph.do_pick(x, y)
    (0...ph.count).each do |i|
      path = ph.path_at(i)
      next unless path
      path.reverse_each do |_310b620e|
        hit = yield(_310b620e)
        return hit if hit
      end
    end
    yield(ph.best_picked)
  end
  def board_at(view, x, y)
    walk_pick(view, x, y) { |_310b620e| labelable?(_310b620e) ? _310b620e : nil }
  end
  def switch_mode(i)
    return if @mode == i
    @mode = i
    @label_sel = false
    reset
    if @mode == MODE_KIEM
      collect_in_rect
    else
      @arr4 = []
      KSU.select_only([])
    end
    update_status
    Sketchup.active_model&.active_view&.invalidate
  end
  def update_status
    case @mode
    when MODE_KIEM
      KSU.set_status("Nhấn Tab để chuyển sang chế độ gắn nhãn. Nhấn Enter để bắt đầu kiểm nhãn.")
    when MODE_SUA
      KSU.set_status("Di chuột qua tấm để chọn nhãn, kéo chuột quét qua nhãn để chọn nhiều nhãn. Nhấn Tab để xoay nhãn. Nhấn chuột trái để đảo mặt gắn nhãn.")
    else
      KSU.set_status("Nhấn chuột hoặc kéo quét để chọn ván cần gắn nhãn. Nhấn Tab để chuyển sang chế độ sửa nhãn. Nhấn Enter để bắt đầu gắn nhãn.")
    end
  end
  def hover_label(x, y, view)
    return if @label_sel
    return if busy?
    fld = label_pair_at(view, x, y)
    model = Sketchup.active_model
    unless fld
      return if model.selection.empty?
      KSU.select_only([])
      view.invalidate
      return
    end
    return if model.selection.size == 1 && model.selection.contains?(fld[1])
    KSU.select_only(fld[1])
    view.invalidate
  end
  def pick_labels_in_rect(view, rect, strict)
    labels = KSU::Quet.collect_in_rect(view, rect, strict, nil, nil, 4) { |ent| !pair_from_label(ent).nil? }
    @label_sel = !labels.empty?
    KSU.select_only(labels)
    view.invalidate
  end
  def click_label(view, x, y)
    fld = label_pair_at(view, x, y)
    if @label_sel
      return flip_label_face if fld && Sketchup.active_model.selection.contains?(fld[1])
      @label_sel = false
      KSU.select_only(fld ? fld[1] : [])
      view.invalidate
    end
    flip_label_face if fld
  end
  def label_pair_at(view, x, y)
    walk_pick(view, x, y) { |_310b620e| label_pair_of(_310b620e) }
  end
  def label_pair_of(grp)
    return nil unless grp && grp.valid? && KSU.container?(grp)
    return nil unless grp.get_attribute(KSU::Label::DICT, KSU::Label::K_BOARD_INDEX)
    lbl = KSU::Cutting.label_of(grp)
    (lbl && lbl.valid?) ? [grp, lbl] : nil
  end
  def selected_pairs
    KSU.selection.map { |ent| pair_from_label(ent) }.compact
  end
  def pair_from_label(entity)
    return nil unless KSU.container?(entity) && entity.valid?
    return nil unless entity.get_attribute(KSU::Label::DICT, KSU::Label::K_IS_LABEL) || entity.name.to_s == KSU::Label::GROUP_NAME
    board = board_of_label(entity)
    board ? [board, entity] : nil
  end
  def board_of_label(lbl)
    _49fd085d = lbl.parent
    return nil unless _49fd085d.is_a?(Sketchup::ComponentDefinition)
    _49fd085d.instances.find { |i| i.valid? && i.get_attribute(KSU::Label::DICT, KSU::Label::K_BOARD_INDEX) }
  end
  def relabel_each
    items = selected_pairs
    return if items.empty?
    KSU.start(false)
    items.each do |board, lbl|
      tf = KSU::Label.world_tf(board)
      src = KSU::Cutting.board_faces(board, tf)
      next unless src
      _7e53f420 = KSU::Cutting.face_with(board, KSU::Label::K_IS_LABELED_FACE)
      rot = (board.get_attribute(KSU::Label::DICT, KSU::Label::K_LABEL_ROTATION) || 0).to_i
      font, rot = yield(board, src, _7e53f420, rot)
      KSU::Label.label_box(lbl, font, tf, rot, @kich_thuoc_nhan, !@nhan_dat_trong_tam)
      board.set_attribute(KSU::Label::DICT, KSU::Label::K_LABEL_ROTATION, rot)
      KSU::Chuanhoa.normalize_group(board) if @chuan_hoa_vat_lieu
    end
    KSU.commit
    KSU::View.view.invalidate
  end
  def rotate_labels
    relabel_each do |_256b4519, src, _7e53f420, rot|
      [_7e53f420 || src[0], (rot + @goc_xoay_nhan) % 360]
    end
  end
  def flip_label_face
    relabel_each do |board, src, _7e53f420, rot|
      font = src[0] == _7e53f420 ? src[1] : src[0]
      clear_cnc_marks(board)
      KSU::Label.mark_labeled_face(board, font)
      [font, rot]
    end
  end
  def clear_cnc_marks(board)
    (KSU.entities_in(board) || []).grep(Sketchup::Face).each do |f|
      f.delete_attribute(KSU::Label::DICT, KSU::Label::K_IS_CNCED_FACE)
    end
  end
  def run_attach(flag = false)
    return if @labelling
    _9535dc0b = flag ? [] : KSU.selection
    renumber = KSU::Label.label_plan(_9535dc0b)
    if renumber.nil?
      UI.messagebox("Không tải được font ksu.shx.")
      return
    end
    if renumber[:jobs].empty?
      UI.messagebox("Không tìm thấy khối tấm để gắn nhãn.")
      return
    end
    @jobs = renumber[:jobs]
    @layer2 = renumber[:layer]
    @_dc5a9dc0 = {
      max_size: @kich_thuoc_nhan,
      gap: @do_gian_chu,
      xf: @chieu_rong_chu / 100.0,
      letter_case: @kieu_tieu_de,
      center: !@nhan_dat_trong_tam,
      default_name: @ten_mac_dinh,
      renumber: renumber[:renumber],
      keep_existing: @cap_nhat_nhan_da_co,
    }
    @label_total = @jobs.size
    @label_done = 0
    @labelling = true
    KSU.start(true)
    KSU::View.view.invalidate
    @label_timer = UI.start_timer(0, true) { _8692db05 }
  end
  def _8692db05
    return _ed0aba0e if @label_done >= @label_total
    n = 0
    while n < 16 && @label_done < @label_total
      job = @jobs[@label_done]
      if job && job[0] && job[0].valid?
        KSU::Label.draw_label_on(job[0], job[1], @layer2, @_dc5a9dc0)
        KSU::Chuanhoa.normalize_group(job[0]) if @chuan_hoa_vat_lieu
      end
      @label_done += 1
      n += 1
    end
    KSU::View.view.invalidate
  rescue StandardError => ent
    _feede56d(ent.message)
  end
  def _ed0aba0e
    stop_labelling(true)
    KSU::View.view.invalidate
  end
  def _feede56d(msg2)
    stop_labelling(false)
    UI.messagebox("Lỗi gắn nhãn: #{msg2}")
    KSU::View.view.invalidate
  end
  def stop_labelling(commit)
    UI.stop_timer(@label_timer) if @label_timer
    @label_timer = nil
    @labelling = false
    if commit
      KSU.commit
    else
      KSU.abort_op
    end
  end
  def isolate_bad
    return if @arr4.nil? || @arr4.empty?
    KSU::Isolate.start(@arr4)
    KSU.select_tool(nil)
  end
  def collect_in_rect
    @arr4 = @scope.select(&:valid?).reject do |ent|
      next true if @bo_qua_kich_thuoc && ent.is_a?(Sketchup::Dimension)
      next true if @bo_qua_net_dung && (ent.is_a?(Sketchup::ConstructionLine) || ent.is_a?(Sketchup::ConstructionPoint))
      next true if @bo_qua_chu && ent.is_a?(Sketchup::Text)
      ent.is_a?(Sketchup::Group) && (ent.name == "__ABF_Nesting" ||
                                      (ent.get_attribute("ABF", "is-board") == true &&
                                       ent.entities.grep(Sketchup::Group).any? { |kids| kids.name == "_ABF_Label" }))
    end
    KSU.select_only(@arr4)
  end
end
class KSU::Gannhan
  def self.license_field(key)
    data = KSU::Lastcut._af392092(key, "")
    KSU::Postproc._75f2a016(data)
  end
end
class KSU::Gannhan
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
