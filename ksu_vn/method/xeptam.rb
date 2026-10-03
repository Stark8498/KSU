class KSU::Xeptam
  include KSU::Preset
  include KSU::Nesting
  tool_key "xep_tam"
  def initialize
    KSU::Chontam.check_license
    KSU::Themtam.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, _a4ab9a59| b ^ (0x3D + _a4ab9a59 * 0x57) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
    @xep_tam_tu_do = !!get("xep_tam_tu_do", false)
    @goc_xoay_van = get("goc_xoay_van", 90).to_i
    @ghi_de_khoang_cach = !!get("ghi_de_khoang_cach", false)
    @tam_cach_nhau_rieng = get("tam_cach_nhau_rieng", 6.5).to_f.mm
    @tam_cach_le_rieng = get("tam_cach_le_rieng", 3.5).to_f.mm
    _b4ae88a5 = @tam_cach_le_rieng.to_mm
    num = get("tam_cach_le", 3.5).to_f
    @tach_cach_le = !!get("tach_cach_le", false)
    load_side_margins(num)
    @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", num).to_f.mm
    @tach_cach_le_rieng = !!get("tach_cach_le_rieng", false)
    load_side_margins(_b4ae88a5, "_rieng")
    _de5cc9a8
    load_overlay_settings
    @label_section_hidden = []
    @flag15 = defined?(KSU::Method) && KSU::Method.respond_to?(:polygons_overlap?)
    @flag27 = defined?(KSU::Method) && KSU::Method.respond_to?(:compute_push_back)
    @flag9 = defined?(KSU::Method) && KSU::Method.respond_to?(:contact_refine)
    @flag2 = defined?(KSU::Method) && KSU::Method.respond_to?(:nfp_snap)
    @grid = nil
    @flag54 = defined?(KSU::Nesting) && KSU::Nesting.respond_to?(:nfp) && KSU::Nesting.respond_to?(:inflate) &&
                        defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union) && KSU::Clipper.respond_to?(:difference)
    @h27 = {}
    @arr15 = nil
    @pt13 = nil
    @flag35 = false
    @arr27 = []
    @arr12 = []
    @flag56 = false
    @flag45 = false
    @flag10 = false
    @flag46 = false
    @_3a930069 = @_0b246bc2 = @_86277c8a = @_e76905aa = nil
    @nesting = nil
    @arr23 = []
    @h14 = {}
    @h25 = {}
    @hit_list = nil
    @h6 = {}
    @arr46 = nil
    @_955ee93a = nil
    @panel = nil
    @arr41 = []
    @sheet4 = nil
    @pt5 = nil
    @pt14 = nil
    @flag25 = false
    @pt7 = nil
    @flag21 = false
    @flag5 = false
    @h11 = {}
    @arr28 = []
    @h21 = {}
    @h24 = {}
    @arr2 = []
    @flag37 = nil
    @sheet = nil
    @hover_side = nil
    @flag12 = false
    @flag39 = nil
    @flag51 = nil
    @vec3 = nil
    @flag38 = false
    @flag30 = false
    @flag52 = false
    @flag36 = false
    @arr63 = nil
    @arr53 = nil
    @arr55 = nil
    @h15 = {}
    @arr3 = nil
    @h26 = {}
    @_75ce293c = nil
    @flag4 = false
    @_8bfa6763 = nil
    @pt3 = nil
    @pt8 = nil
    @_27cbbc5a = nil
    @_ee3eb631 = nil
    @_8a0971a9 = nil
    @pt2 = nil
    @flag3 = nil
    @arr57 = []
    @arr33 = []
    @flag50 = false
    @arr20 = []
    @arr11 = []
    @arr18 = []
    @_02765833 = nil
    @h23 = {}
    @flag11 = nil
    @num12 = nil
    @str = nil
    @arr6 = nil
    @_b7599404 = nil
    if Sketchup.active_model.tools.active_tool == self
      @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    end
  end
  def activate
    KSU::Chontam.check_license
    KSU::Themtam.assert_license
    @nesting = KSU::Nesting.enter_edit
    unless @nesting
      KSU.select_tool(nil)
      return
    end
    @h4 = {}
    sheet_list(@nesting)
    _1817fa46
    _5b9cf20b
    @presets = get("presets", nil)
    setup_fields(
      "Xếp tấm tự do" => {
        xep_tam_tu_do: [:switch, "Xếp tấm tự do"],
      },
      "Góc xoay ván" => {
        goc_xoay_van: [nil, "Góc xoay ván", nil, -360, 360],
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS,
      "Khoảng hở" => {
        ghi_de_khoang_cach: [:switch, "Ghi đè khoảng cách", -> { !@xep_tam_tu_do }],
        tam_cach_nhau: [:mm, "Tấm cách nhau", -> { !@xep_tam_tu_do && !@ghi_de_khoang_cach }, 0, 100]
      }.merge(margin_rows(-> { !@xep_tam_tu_do && !@ghi_de_khoang_cach },
                             -> { !@xep_tam_tu_do && !@ghi_de_khoang_cach && @tach_cach_le }, "", true))
        .merge(tam_cach_nhau_rieng: [:mm, "Tấm cách nhau", -> { !@xep_tam_tu_do && @ghi_de_khoang_cach }, 0, 100])
        .merge(margin_rows(-> { !@xep_tam_tu_do && @ghi_de_khoang_cach },
                              -> { !@xep_tam_tu_do && @ghi_de_khoang_cach && @tach_cach_le_rieng }, "_rieng")),
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    KSU::View.on_change("xep_tam") { rebuild_all }
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    KSU::Avail.set_override(nil)
    _40219b95
    save_selected_preset
    KSU::View.off_change("xep_tam")
    _4601b4c9
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view.invalidate
  end
  def apply_preset(s)
    apply_settings(s)
    _de5cc9a8
    @h27 = {}
  end
  def _de5cc9a8
    @tam_cach_nhau = @ghi_de_khoang_cach ? @tam_cach_nhau_rieng : get("tam_cach_nhau", 6.5).to_f.mm
    @tam_cach_le = @ghi_de_khoang_cach ? @tam_cach_le_rieng : get("tam_cach_le", 3.5).to_f.mm
    screen_box = if @ghi_de_khoang_cach && @tach_cach_le_rieng
        [@tam_cach_le_trai_rieng.to_f, @tam_cach_le_phai_rieng.to_f,
         @tam_cach_le_tren_rieng.to_f, @tam_cach_le_duoi_rieng.to_f]
      end
    KSU::Avail.set_override(screen_box)
  end
  def set(key, value)
    super
    return unless %w[ghi_de_khoang_cach tam_cach_nhau tam_cach_le tam_cach_nhau_rieng tam_cach_le_rieng
                     tach_cach_le tam_cach_le_trai tam_cach_le_phai tam_cach_le_tren tam_cach_le_duoi
                     tach_cach_le_rieng tam_cach_le_trai_rieng tam_cach_le_phai_rieng
                     tam_cach_le_tren_rieng tam_cach_le_duoi_rieng tam_cach_le_hai_mat].include?(key.to_s)
    _de5cc9a8
    @h27 = {}
    @h15 = {}
    _5b9cf20b
  end
  def reload_settings
    super
    _de5cc9a8
    @h27 = {}
    @h15 = {}
    _5b9cf20b
  end
  def rebuild_all
    if @flag36
      @flag36 = false
      return
    end
    return if @flag56
    return unless @nesting && @nesting.valid?
    keep_existing = @arr27.each_index.select { |_a4ab9a59| @arr27[_a4ab9a59] && @arr27[_a4ab9a59].valid? }
    @arr27 = keep_existing.map { |_a4ab9a59| @arr27[_a4ab9a59] }
    @arr12 = keep_existing.map { |_a4ab9a59| @arr12[_a4ab9a59] }
    @flag37 = nil unless @flag37 && @flag37.valid?
    sheet_list(@nesting)
    _1817fa46
  end
  def resume(view)
    KSU::View.load_colors
    view.invalidate
    update_status
  end
  def onSetCursor
    if @vec3 && @vec3.valid?
      UI.set_cursor(KSU::Const::CURSOR_ORBIT)
      true
    elsif @flag56 || (@panel && @panel.valid?)
      UI.set_cursor(KSU::Const::CURSOR_MOVE)
      true
    else
      false
    end
  end
  def enableVCB?
    true
  end
  def update_status
    KSU.set_status(
      "Nhấn Tab để xoay. Nhấn Ctrl để group hoặc bỏ group tấm. Giữ Shift để khóa trục khi kéo. " \
      "Giữ Alt để xếp tự do. Nhấn Mũi tên để căn lề hoặc thay đổi vị trí ván."
    )
    KSU.set_vcb("Tấm cách nhau", Sketchup.format_length(@tam_cach_nhau))
  end
  def onUserText(text, view)
    len = begin
        text.to_l
      rescue StandardError
        nil
      end
    unless len
      UI.beep
      update_status
      return
    end
    num = len.to_mm.to_f
    return if num < 0
    if @ghi_de_khoang_cach
      @tam_cach_nhau_rieng = num.mm
      set("tam_cach_nhau_rieng", num)
    else
      @tam_cach_nhau = num.mm
      set("tam_cach_nhau", num)
    end
    update_status
    view.invalidate
  end
  def onKeyDown(key, _4ce596b6, rot, view)
    return if @num12
    if key == COPY_MODIFIER_KEY
      unless @flag30
        @flag30 = true
        @flag52 = @flag56 || @flag10 || @flag46
      end
    else
      @flag52 = true
    end
    if key == 192
      KSU::Settings.open_settings("xep_tam") if defined?(KSU::Settings)
      return
    end
    if key == CONSTRAIN_MODIFIER_KEY
      @flag25 = true
      @pt7 = @pt5 if @flag56
      view.invalidate
      return
    end
    if key == ALT_MODIFIER_KEY
      if @_75ce293c.nil?
        @_75ce293c = @xep_tam_tu_do
        @xep_tam_tu_do = true
        _50ab81be if @flag56
        view.invalidate
      end
      return
    end
    if @flag37 && @flag37.valid? && @arr27.empty? &&
       !KSU::Sheet.hidden?(@flag37)
      case key
      when VK_LEFT, VK_RIGHT
        _b5af8dbf = @flag25 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
        _c04fb39c = if key == VK_LEFT
            _b5af8dbf ? :first : :prev
          else
            _b5af8dbf ? :last : :next
          end
        _ce446adc(_c04fb39c)
        view.invalidate
        return
      when VK_UP, VK_DOWN
        _c574b8db(key == VK_UP ? :up : :down)
        view.invalidate
        return
      end
    end
    return if @arr27.empty?
    if key == 9
      _3ea06bed(@goc_xoay_van.degrees)
      return
    end
    if @arr27.length >= 2
      case key
      when VK_LEFT then _2bff4638(:left)
      when VK_RIGHT then _2bff4638(:right)
      when VK_UP then _2bff4638(:top)
      when VK_DOWN then _2bff4638(:bottom)
      else return
      end
    end
  end
  def onKeyUp(key, _4ce596b6, rot, view)
    if key == COPY_MODIFIER_KEY
      _f0301936 = @flag30 && !@flag52
      @flag30 = false
      if _f0301936 && !@num12 && !@flag56 && !@flag10 && !@flag46
        toggle_group
        view.invalidate
      end
    elsif key == CONSTRAIN_MODIFIER_KEY
      @flag25 = false
      view.invalidate
    elsif key == ALT_MODIFIER_KEY && !@_75ce293c.nil?
      @xep_tam_tu_do = @_75ce293c
      @_75ce293c = nil
      _f8e75e9d if @flag56
      view.invalidate
    end
  end
  def onReturn(view)
    return if @num12
    return if @flag56
    return unless @arr27.empty?
    return unless @flag37 && @flag37.valid?
    return if KSU::Sheet.hidden?(@flag37)
    _cfe1b27c(@flag37)
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if @num12
    @flag52 = true
    if click_field(x, y, view)
      @flag38 = true
      return
    end
    if click_outside(x, y, view)
      @flag38 = true
      return
    end
    _7a82534c = _ecb07074(view, x, y)
    if _7a82534c
      _903c1e24(_7a82534c)
      _37011ad2(x, y, view)
      onSetCursor
      @flag38 = true
      view.invalidate
      return
    end
    if @flag37 && @flag37.valid?
      _11dde2f2 = hit_side_button(view, x, y)
      if _11dde2f2
        move_sheet(_11dde2f2)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      if hit_delete_button(view, x, y)
        delete_sheet
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      _3b0598af = _f3bdae07(view, x, y)
      if _3b0598af
        _f098d644(_3b0598af) unless KSU::Sheet.hidden?(@flag37)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
      edge_ix = _30c1f1e6(view, x, y)
      if edge_ix
        _fa7e4609(edge_ix) unless KSU::Sheet.hidden?(@flag37)
        @flag38 = true
        update_status
        view.invalidate
        return
      end
    end
    @_3a930069, @_0b246bc2 = x, y
    @flag10 = true
    @flag46 = false
    @flag5 = (rot & COPY_MODIFIER_MASK) != 0 || (rot & CONSTRAIN_MODIFIER_MASK) != 0
    @nesting ||= KSU::Nesting.find_nesting
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    @flag10 = false
    if @flag38
      @flag38 = false
      view.invalidate
      return
    end
    if @flag46
      arr = _101ef2e3(view, @_3a930069, @_0b246bc2, x, y)
      if arr.any?
        _78c88320(arr)
        @flag37 = nil
      elsif !@flag5
        @arr27 = []
        @arr12 = []
        @flag37 = nil
      end
      @flag46 = false
    elsif @flag56
      _f97c64c2
    else
      answer = _b01ddcaf(view, x, y)
      if answer
        _2171a7c6(answer)
        @flag37 = @arr27.size == 1 ? @arr12[0] : nil
      else
        _b51e23e4 = sheet_at2(view, x, y)
        if _b51e23e4
          @arr27 = []
          @arr12 = []
          @flag37 = _b51e23e4
        elsif !@flag5
          @arr27 = []
          @arr12 = []
          @flag37 = nil
        end
      end
    end
    update_status
    view.invalidate
  end
  def onMouseMove(rot, x, y, view)
    if @flag46
      @_86277c8a, @_e76905aa = x, y
      view.invalidate
      return
    end
    hover_preset(x, y, view)
    return if hover_field(x, y, view) && !@flag10 && !@flag56
    _37011ad2(x, y, view) unless @flag10 || @flag56
    if @flag10 && !@flag56
      dx = (x - @_3a930069).abs
      dy = (y - @_0b246bc2).abs
      if dx > 3 || dy > 3
        answer = _b01ddcaf(view, @_3a930069, @_0b246bc2)
        if @arr27.any? && answer && @arr27.include?(answer[:panel])
          _afb25a1e(view, @_3a930069, @_0b246bc2)
        elsif answer
          @arr27 = [answer[:panel]]
          @arr12 = [answer[:sheet]]
          expand_selection
          _afb25a1e(view, @_3a930069, @_0b246bc2)
        else
          @flag46 = true
          @panel = @sheet4 = @sheet = nil
        end
      end
    end
    return unless @flag56 && @arr27.any?
    @pt5 = _7fd07e0b(view, x, y)
    return unless @pt5
    _38196f56 = if @flag25 && @pt7
        dx = (@pt5.x - @pt7.x).abs
        dy = (@pt5.y - @pt7.y).abs
        if dx >= dy
          Geom::Point3d.new(@pt5.x, @pt7.y, @pt7.z)
        else
          Geom::Point3d.new(@pt7.x, @pt5.y, @pt7.z)
        end
      else
        @pt5
      end
    vec = _38196f56 - @pt14
    return if vec.length < 1e-9
    _af333274 = @pt14
    _98834989(vec)
    _52bcd343(vec)
    @pt14 = _38196f56
    if @flag45
      @flag21 = false
      view.invalidate
      return
    end
    arr = record_for(@arr12.first)
    instance = @arr46 && @arr46[:instance]
    _1f2cf874 = @flag50
    flag = @flag25 ? nil : @arr23.find do |s|
      !KSU::Sheet.hidden?(s[:instance]) && s[:bbox].contains?(@pt5)
    end
    @_955ee93a = flag
    if @flag50
      if flag
        @flag50 = false if _7f17a5c5(flag)
        @arr46 = flag
      else
        @arr46 = arr
      end
    elsif flag
      @arr46 = flag
    elsif @xep_tam_tu_do
      @arr46 = arr
    else
      _b4ce762b, _8eedd0f1 = _eca6a79f(@pt5)
      if _8eedd0f1 && _8eedd0f1 > 0.0
        @flag50 = true
        @arr46 = arr
      else
        @arr46 = _b4ce762b || arr
      end
    end
    _5a7c1be3 = @flag50 && !_1f2cf874
    if _5a7c1be3 || (@arr46 && @arr46[:instance]) != instance
      _066c900b
      _50ab81be if _5a7c1be3
      _f8e75e9d
    end
    _d8a427f3 = @arr46 || arr
    _290b52bf = !!(flag && arr && flag[:instance] != arr[:instance])
    if _d8a427f3
      begin
        if @flag50
          @flag21 = true
        elsif @flag25 || @xep_tam_tu_do
          cap = _7f17a5c5(_d8a427f3)
          @flag21 = !cap
          _066c900b if cap && @flag4
        else
          arr5 = _0feae552(_d8a427f3)
          if arr5 && arr5[:valid]
            _25080947(arr5, vec)
            build_grid(_d8a427f3)
            @flag21 = false
          else
            _33b33533 = _19030d1a(_d8a427f3)
            if _33b33533
              _98834989(_33b33533)
              _52bcd343(_33b33533)
            end
            arr4 = compute_push_back(_d8a427f3, true)
            if arr4.length.to_f >= KSU::TOL
              _98834989(arr4)
              _52bcd343(arr4)
              _63b8ba0b(_d8a427f3, vec, arr4)
              if compute_push_back(_d8a427f3, true).length.to_f < KSU::TOL
                build_grid(_d8a427f3)
                @flag21 = false
              elsif _290b52bf
                _9f96b850
                @flag21 = false
              else
                @flag21 = true
              end
            else
              build_grid(_d8a427f3)
              @flag21 = false
            end
          end
        end
      rescue
        @flag21 = false
      end
    end
    _03d703fa = !@xep_tam_tu_do && !@flag50 && _d8a427f3 && _11075c77(_d8a427f3)
    if (@flag21 || _03d703fa) && !@xep_tam_tu_do && !@flag50
      if _03d703fa || !@flag33
        _70a50d49
        @pt14 = _af333274
        @flag21 = false
      end
    else
      @flag33 = false
      _f8e75e9d
    end
    rebuild_preview
    view.invalidate
  end
  def draw(view)
    check_dirty
    KSU::View.draw_faces(@nesting, skip: skip, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false) if @arr20 && @arr20.any?
    KSU::View.draw_error_dots(view, @arr11) if @danh_dau_loi
    if @danh_dau_tam_bi_lan && !@flag56
      _0b16f3d7
      KSU::View.draw_polys(@arr18, color: KSU::View.warn_color, line: false) if @arr18.any?
    end
    KSU::Sheet.draw_borders(view, @nesting)
    draw_rect2d(view) if @flag46
    edge_color2 = KSU::View.edge_color
    mat = KSU::View.face_color
    warn = KSU::View.warning_color
    warning_face_color = KSU::View.warn_color
    if @panel2 && @panel2.valid? && !@flag56 &&
       (@sheet4.nil? || @sheet4.valid?) &&
       !@arr27.include?(@panel2)
      arr5 = [[@panel2, @sheet4]] + @arr41
      arr5.each do |vec, vec2|
        next unless vec && vec.valid?
        next if vec2 && !vec2.valid?
        next if @arr27.include?(vec)
        _9a1f1a22(vec, vec2, mat)
        partner_of = partner_of2(vec)
        next unless partner_of && partner_of.valid?
        arr3 = rec_by_def(partner_of.parent)
        _9a1f1a22(partner_of, arr3[:instance], mat) if arr3
      end
    end
    if @arr27.any?
      _4e78f5d5 = @flag56 && @flag21
      flag = _4e78f5d5 ? warn : edge_color2
      color = _4e78f5d5 ? warning_face_color : mat
      if @arr63
        _83ee7e20(@arr63, flag)
      else
        @arr27.each_with_index do |panel, ix|
          next unless panel && panel.valid?
          vec3 = @arr12[ix]
          next if vec3 && !vec3.valid?
          _9a1f1a22(panel, vec3, color, flag)
        end
      end
    end
    _eed07b86(@_955ee93a, @flag21 ? warning_face_color : mat) if @_955ee93a && @flag56
    mat3 = Sketchup::Color.new(mat.red, mat.green, mat.blue, [mat.alpha * 3, 255].min)
    mat4 = Sketchup::Color.new(warn.red, warn.green, warn.blue, [mat.alpha * 3, 255].min)
    mat2 = Sketchup::Color.new(warn.red, warn.green, warn.blue, mat.alpha)
    if @flag37 && @flag37.valid?
      arr = record_for(@flag37)
      if arr
        if KSU::Sheet.hidden?(@flag37)
          _eed07b86(arr, mat4)
          KSU::View.draw_brackets(view, arr[:top_corners], color: warn, active: KSU::Sheet.corner_index(@flag37, @nesting)) { |_a4ab9a59| @flag39 == _a4ab9a59 }
        else
          _eed07b86(arr, mat3)
          KSU::View.draw_brackets(view, arr[:top_corners]) { |_a4ab9a59| @flag39 == _a4ab9a59 }
          KSU::View._2873a79b(view, arr[:top_corners]) { |_a4ab9a59| @flag51 == _a4ab9a59 }
          draw_side_buttons(view, arr)
          KSU::View.draw_warn_button(view, KSU::View.center_of(arr[:top_corners]), hover: @flag12) if KSU::Sheet.empty?(@flag37)
        end
      end
    end
    if @sheet && @sheet.valid? && !@flag56 &&
       @sheet != @flag37
      _d5f2cd75 = record_for(@sheet)
      _eed07b86(_d5f2cd75, KSU::Sheet.hidden?(@sheet) ? mat2 : mat) if _d5f2cd75
    end
    unless @arr27.empty? || @arr28.empty?
      _ce2de26a = @flag56 && @flag21
      flag3 = _ce2de26a ? warning_face_color : mat
      flag2 = _ce2de26a ? warn : edge_color2
      if @flag56
        arr4 = []
        @arr27.each do |panel|
          partner_of = partner_of2(panel)
          next unless partner_of && partner_of.valid?
          next if @arr27.include?(partner_of)
          next if @arr57.any? { |panel3| panel3[:front] == panel }
          pts = @h26[partner_of.object_id]
          unless pts && pts.length >= 3
            arr2 = rec_by_def(partner_of.parent)
            next unless arr2
            pts = _8e5202c8(partner_of, arr2[:instance])
            next if pts.length < 3
            @h26[partner_of.object_id] = pts
          end
          arr4 << pts
        end
        _83ee7e20(arr4, flag2)
      else
        @arr27.each do |panel|
          partner_of = partner_of2(panel)
          next unless partner_of && partner_of.valid?
          next if @arr27.include?(partner_of)
          next if @arr57.any? { |panel3| panel3[:front] == panel }
          arr2 = rec_by_def(partner_of.parent)
          next unless arr2
          _9a1f1a22(partner_of, arr2[:instance], flag3, flag2)
        end
      end
    end
    _f42544d1(view) if @flag56
    _b903d1e6(view) unless @flag56
    draw_presets(view)
    draw_fields(view)
    draw_mode_hint(view, "#{@str || "Đang tối ưu"}... #{@num12}%") if @num12
  end
end
class KSU::Xeptam
  def self._3d509e12
    key = KSU::Gannhan.license_field("k").to_s
    return false if key.empty?
    KSU::Netcatcuoi._8e3f5229
    return false unless KSU::Engine._45e9b533
    KSU::Assign._91d00075(key)
  rescue
    false
  end
end
class KSU::Xeptam
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, _a4ab9a59| b ^ (0x3D + _a4ab9a59 * 0x57) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, _a4ab9a59| b ^ (_a4ab9a59 * 0x57 + 0x3D) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
