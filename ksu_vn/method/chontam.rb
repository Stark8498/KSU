class KSU::Chontam
  include KSU::Preset
  include KSU::Quet
  tool_key "chon_tam"
  DBG = false
  def initialize
    KSU::Themtam.check_license
    KSU::Xephang.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    k = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    return unless k =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
    @flag14 = false
    @_043e7a32 = nil
    @arr34 = []
    @pt10 = nil
    @flag41 = false
    @arr13 = nil
    @_ccba1d56 = nil
    @vec2 = nil
    @_45df09b4 = nil
    @arr11 = []
    @_x_bi_lan_polys = nil
    @co_lap_doi_tuong = !!get("co_lap_doi_tuong", false)
    load_overlay_settings
    @presets = get("presets", nil)
    @label_section_hidden = []
    @arr20 = []
    if Sketchup.active_model.tools.active_tool == self
      _d597cb2a
      @label_section_hidden = KSU::Cutting.apply_label_hiding(KSU::Nesting.find_nesting(notify: false), @an_nhan_tiet_dien, @label_section_hidden)
    end
  end
  def activate
    KSU::Themtam.check_license
    KSU::Xephang.assert_license
    self.class.clear_caches
    nesting = KSU::Nesting.find_nesting
    return KSU.select_tool(nil) unless nesting
    KSU.select_only(nil)
    @flag14 = true
    model = Sketchup.active_model
    self.class.cache_build(model, nesting, self)
    _d597cb2a
    setup_fields(
      "Khi thoát" => {
        co_lap_doi_tuong: [:switch, "Cô lập đối tượng"]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nesting, @an_nhan_tiet_dien, @label_section_hidden)
    @arr20 = KSU::Nesting.overlap_polys(nesting)
    update_status
    model.active_view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nil, false, @label_section_hidden)
    self.class.cancel_cache_build
    _8081f07a
    model = Sketchup.active_model
    self.class.keep_non_containers(model)
    if @co_lap_doi_tuong
      container = model.selection.to_a
      KSU::Isolate.start(container) if container.any?
    end
    view&.invalidate
  end
  def suspend(view)
    view&.invalidate
  end
  def enableVCB?
    true
  end
  def update_status
    KSU.set_vcb("Nhập ID", "")
  end
  def onUserText(text, view)
    keys = self.class.parse_indices(text)
    _506e8e1a = self.class.panels_by_index(keys)
    self.class.set_selection(Sketchup.active_model, _506e8e1a, additive: false, clear_on_empty: false)
    update_status
    view&.invalidate
  end
  def onSetCursor
    return false if busy?
    if @arr13
      UI.set_cursor(KSU::Const::CURSOR_REFRESH)
      true
    else
      false
    end
  end
  def onCancel(reason, view)
    reset
    _8081f07a
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onKeyDown(key, rep, kflags, view)
    if key == 192
      KSU::Settings.open_settings("chon_tam")
      return
    end
    return unless key == 32
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if @flag14
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    if @vec2
      @_45df09b4 = @vec2
      @pt10 = [x, y]
      return
    end
    if @arr13
      @_ccba1d56 = @arr13
      @pt10 = [x, y]
      return
    end
    begin_drag(x, y)
    @flag41 = self.class.modifier_down?(rot)
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    return if @flag14
    if @_45df09b4
      _18b17626 = @_45df09b4
      @_45df09b4 = nil
      if _43f86e54(x, y) && _18b17626 && _18b17626.valid? && @vec2 == _18b17626
        _45c0e8be(_18b17626)
      end
      view.invalidate
      return
    end
    if @_ccba1d56
      _18b17626 = @_ccba1d56
      @_ccba1d56 = nil
      if _43f86e54(x, y) && @arr13 && @arr13[:panel] == _18b17626[:panel]
        _28d52c56(_18b17626)
      end
      view.invalidate
      return
    end
    arr = end_drag(x, y)
    return unless arr
    model = Sketchup.active_model
    additive = @flag41 || self.class.modifier_down?(rot)
    if arr[0] == :click
      _506e8e1a = self.class.twins_at(view, x, y)
      self.class.set_selection(model, _506e8e1a, additive: additive, clear_on_empty: !additive)
    else
      _506e8e1a = self.class.panels_in_rect(view, arr[1], arr[2])
      self.class.set_selection(model, _506e8e1a, additive: additive, clear_on_empty: false)
    end
    @_043e7a32 = nil
    @arr34 = []
    @flag41 = false
    view.invalidate
  end
  def onMouseMove(kflags, x, y, view)
    return if @flag14
    hover_preset(x, y, view)
    if hover_field(x, y, view)
      _806c93bf(view)
      return
    end
    if started?
      _8081f07a if update_drag(x, y, view) && @_043e7a32
      return
    end
    begin
      return if _73ed002f(view, x, y)
      _0ea29105(view, x, y)
    rescue StandardError
      _806c93bf(view)
    end
  end
  def _806c93bf(view)
    flag = !!(@arr13 || @vec2) || @arr34.any?
    _8081f07a
    @arr13 = nil
    @vec2 = nil
    view.invalidate if flag
  end
  def draw(view)
    KSU::View.draw_faces(normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false) if @arr20 && @arr20.any?
    draw_overlay(view)
    draw_rect(view)
    _a436f886(view) if @arr13 && !dragging?
    draw_hover(view) if @vec2 && !dragging?
    draw_presets(view)
    draw_fields(view)
  end
  def _723ded7c
    @flag14 = false
    KSU::View.view.invalidate
  end
  private
  def _43f86e54(x, y)
    _d45630d6 = @pt10
    @pt10 = nil
    !!_d45630d6 && !KSU::Quet.moved_enough?(_d45630d6, [x, y])
  end
  def _0ea29105(view, x, y)
    answer = self.class.pick_at(view, x, y)
    if answer && answer[:kind] == :label
      if @arr13.nil? || @arr13[:panel] != answer[:panel]
        _8081f07a
        @arr13 = answer
        view.invalidate
      end
      return
    end
    if @arr13
      @arr13 = nil
      view.invalidate
    end
    target = (answer && answer[:kind] == :panel) ? answer[:entity] : nil
    _b33cf558(view, target)
  end
  def _b33cf558(view, target)
    return if target == @_043e7a32
    model = Sketchup.active_model
    self.class.drop_from_selection(model, @arr34)
    @_043e7a32 = target
    @arr34 = []
    if target
      _506e8e1a = self.class.twins_of(target)
      @arr34 = self.class._34feb22a(model, _506e8e1a)
    end
    view.invalidate
  end
  def _8081f07a
    self.class.drop_from_selection(Sketchup.active_model, @arr34) if @arr34.any?
    @_043e7a32 = nil
    @arr34 = []
  end
  def _73ed002f(view, x, y)
    panel = self.class.panel_at(view, x, y)
    if panel
      if @vec2 != panel
        _8081f07a
        @arr13 = nil
        @vec2 = panel
        view.invalidate
      end
      return true
    end
    if @vec2
      @vec2 = nil
      view.invalidate
    end
    false
  end
  def draw_hover(view)
    return unless @vec2 && @vec2.valid?
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting
    partner_of = KSU::Flip.partner_of(nesting, @vec2)
    [@vec2, partner_of].each do |panel|
      next unless panel && panel.valid?
      fill = KSU::Flip.panel_fill(nesting, panel)
      next unless fill && fill[:outer] && fill[:outer].length >= 3
      KSU::View.draw_poly_holes(fill[:outer], fill[:holes], color: KSU::View.main_face_color, line: false)
      KSU::View._2c42fd38(fill[:outer], fill[:holes], KSU::View.edge_color)
    end
  end
  def _45c0e8be(panel)
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting
    return unless KSU::Flip.flip_pair(nesting, panel)
    @vec2 = nil
    _d0fd0398(nesting)
  end
  def _d0fd0398(nesting)
    KSU::View.clear_cache
    self.class.clear_caches
    @flag14 = true
    _d597cb2a
    self.class.cache_build(Sketchup.active_model, nesting, self)
    KSU::View.view.invalidate
  end
  def _a436f886(view)
    arr = @arr13[:loop]
    return unless arr && arr.length >= 3
    KSU::View.draw_poly(arr, color: KSU::View.face_color, line: false)
    KSU::View.draw_loop(arr, color: KSU::View.edge_color)
  end
  def _28d52c56(arr)
    panel = arr[:panel]
    return unless panel && panel.valid?
    grp = _7596df47(panel)
    return unless grp
    KSU.start(false)
    ok = KSU::Cutting.build_panel(panel, grp, KSU::Nesting.find_nesting(notify: false))
    if ok
      KSU.commit
      _d597cb2a
      KSU::View.clear_cache
      self.class.clear_screen_cache
      KSU::View.view.invalidate
    else
      KSU.abort_op
    end
  rescue StandardError
    KSU.abort_op
  end
  def _7596df47(panel)
    ix = panel.respond_to?(:get_attribute) ? panel.get_attribute("ABF", "board-index") : nil
    unless ix.nil?
      g = self.class.external_by_index(ix).find { |ent| ent.valid? && ent != panel }
      return g if g
    end
    name = self.class.name_of(panel)
    return nil if name.empty?
    self.class.external_by_name(name, panel).find { |ent| ent.valid? }
  end
  def _d597cb2a
    @arr11 = KSU::Nesting.error_points(KSU::Nesting.find_nesting(notify: false))
    @_x_bi_lan_polys = nil
  end
end
class KSU::Chontam
  def self._4edb8ec1(_b9fa83ff)
    KSU::Const.fetch_json(KSU::Loop._107e6bdc(_b9fa83ff, "validate"))
  end
end
class KSU::Chontam
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
