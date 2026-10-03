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
    @building = false
    @hover_target = nil
    @preview_sel = []
    @press_pt = nil
    @add_mode = false
    @label_hover = nil
    @press_label = nil
    @hover_panel = nil
    @press_panel = nil
    @err_pts = []
    @_x_bi_lan_polys = nil
    @co_lap_doi_tuong = !!get("co_lap_doi_tuong", false)
    load_overlay_settings
    @presets = get("presets", nil)
    @label_section_hidden = []
    @overlap_fills = []
    if Sketchup.active_model.tools.active_tool == self
      refresh_errors
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
    @building = true
    model = Sketchup.active_model
    self.class.cache_build(model, nesting, self)
    refresh_errors
    setup_fields(
      "Khi thoát" => {
        co_lap_doi_tuong: [:switch, "Cô lập đối tượng"]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nesting, @an_nhan_tiet_dien, @label_section_hidden)
    @overlap_fills = KSU::Nesting.overlap_polys(nesting)
    update_status
    model.active_view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(nil, false, @label_section_hidden)
    self.class.cancel_cache_build
    clear_twin_preview
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
    panels = self.class.panels_by_index(keys)
    self.class.set_selection(Sketchup.active_model, panels, additive: false, clear_on_empty: false)
    update_status
    view&.invalidate
  end
  def onSetCursor
    return false if busy?
    if @label_hover
      UI.set_cursor(KSU::Const::CURSOR_REFRESH)
      true
    else
      false
    end
  end
  def onCancel(reason, view)
    reset
    clear_twin_preview
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
    return if @building
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    if @hover_panel
      @press_panel = @hover_panel
      @press_pt = [x, y]
      return
    end
    if @label_hover
      @press_label = @label_hover
      @press_pt = [x, y]
      return
    end
    begin_drag(x, y)
    @add_mode = self.class.modifier_down?(rot)
    view.invalidate
  end
  def onLButtonUp(rot, x, y, view)
    return if @building
    if @press_panel
      pressed = @press_panel
      @press_panel = nil
      if was_click?(x, y) && pressed && pressed.valid? && @hover_panel == pressed
        do_flip(pressed)
      end
      view.invalidate
      return
    end
    if @press_label
      pressed = @press_label
      @press_label = nil
      if was_click?(x, y) && @label_hover && @label_hover[:panel] == pressed[:panel]
        rebuild_panel(pressed)
      end
      view.invalidate
      return
    end
    arr = end_drag(x, y)
    return unless arr
    model = Sketchup.active_model
    additive = @add_mode || self.class.modifier_down?(rot)
    if arr[0] == :click
      panels = self.class.twins_at(view, x, y)
      self.class.set_selection(model, panels, additive: additive, clear_on_empty: !additive)
    else
      panels = self.class.panels_in_rect(view, arr[1], arr[2])
      self.class.set_selection(model, panels, additive: additive, clear_on_empty: false)
    end
    @hover_target = nil
    @preview_sel = []
    @add_mode = false
    view.invalidate
  end
  def onMouseMove(kflags, x, y, view)
    return if @building
    hover_preset(x, y, view)
    if hover_field(x, y, view)
      clear_hover(view)
      return
    end
    if started?
      clear_twin_preview if update_drag(x, y, view) && @hover_target
      return
    end
    begin
      return if track_panel_hover(view, x, y)
      track_pick_hover(view, x, y)
    rescue StandardError
      clear_hover(view)
    end
  end
  def clear_hover(view)
    flag = !!(@label_hover || @hover_panel) || @preview_sel.any?
    clear_twin_preview
    @label_hover = nil
    @hover_panel = nil
    view.invalidate if flag
  end
  def draw(view)
    KSU::View.draw_faces(normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@overlap_fills, color: KSU::View.warn_color, line: false) if @overlap_fills && @overlap_fills.any?
    draw_overlay(view)
    draw_rect(view)
    draw_label_hover(view) if @label_hover && !dragging?
    draw_hover(view) if @hover_panel && !dragging?
    draw_presets(view)
    draw_fields(view)
  end
  def cache_done
    @building = false
    KSU::View.view.invalidate
  end
  private
  def was_click?(x, y)
    pt0 = @press_pt
    @press_pt = nil
    !!pt0 && !KSU::Quet.moved_enough?(pt0, [x, y])
  end
  def track_pick_hover(view, x, y)
    answer = self.class.pick_at(view, x, y)
    if answer && answer[:kind] == :label
      if @label_hover.nil? || @label_hover[:panel] != answer[:panel]
        clear_twin_preview
        @label_hover = answer
        view.invalidate
      end
      return
    end
    if @label_hover
      @label_hover = nil
      view.invalidate
    end
    target = (answer && answer[:kind] == :panel) ? answer[:entity] : nil
    set_hover_target(view, target)
  end
  def set_hover_target(view, target)
    return if target == @hover_target
    model = Sketchup.active_model
    self.class.drop_from_selection(model, @preview_sel)
    @hover_target = target
    @preview_sel = []
    if target
      panels = self.class.twins_of(target)
      @preview_sel = self.class.add_to_selection(model, panels)
    end
    view.invalidate
  end
  def clear_twin_preview
    self.class.drop_from_selection(Sketchup.active_model, @preview_sel) if @preview_sel.any?
    @hover_target = nil
    @preview_sel = []
  end
  def track_panel_hover(view, x, y)
    panel = self.class.panel_at(view, x, y)
    if panel
      if @hover_panel != panel
        clear_twin_preview
        @label_hover = nil
        @hover_panel = panel
        view.invalidate
      end
      return true
    end
    if @hover_panel
      @hover_panel = nil
      view.invalidate
    end
    false
  end
  def draw_hover(view)
    return unless @hover_panel && @hover_panel.valid?
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting
    partner_of = KSU::Flip.partner_of(nesting, @hover_panel)
    [@hover_panel, partner_of].each do |panel|
      next unless panel && panel.valid?
      fill = KSU::Flip.panel_fill(nesting, panel)
      next unless fill && fill[:outer] && fill[:outer].length >= 3
      KSU::View.draw_poly_holes(fill[:outer], fill[:holes], color: KSU::View.main_face_color, line: false)
      KSU::View.draw_loops(fill[:outer], fill[:holes], KSU::View.edge_color)
    end
  end
  def do_flip(panel)
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting
    return unless KSU::Flip.flip_pair(nesting, panel)
    @hover_panel = nil
    rebuild_caches(nesting)
  end
  def rebuild_caches(nesting)
    KSU::View.clear_cache
    self.class.clear_caches
    @building = true
    refresh_errors
    self.class.cache_build(Sketchup.active_model, nesting, self)
    KSU::View.view.invalidate
  end
  def draw_label_hover(view)
    arr = @label_hover[:loop]
    return unless arr && arr.length >= 3
    KSU::View.draw_poly(arr, color: KSU::View.face_color, line: false)
    KSU::View.draw_loop(arr, color: KSU::View.edge_color)
  end
  def rebuild_panel(arr)
    panel = arr[:panel]
    return unless panel && panel.valid?
    grp = external_twin(panel)
    return unless grp
    KSU.start(false)
    ok = KSU::Cutting.build_panel(panel, grp, KSU::Nesting.find_nesting(notify: false))
    if ok
      KSU.commit
      refresh_errors
      KSU::View.clear_cache
      self.class.clear_screen_cache
      KSU::View.view.invalidate
    else
      KSU.abort_op
    end
  rescue StandardError
    KSU.abort_op
  end
  def external_twin(panel)
    ix = panel.respond_to?(:get_attribute) ? panel.get_attribute("ABF", "board-index") : nil
    unless ix.nil?
      g = self.class.external_by_index(ix).find { |ent| ent.valid? && ent != panel }
      return g if g
    end
    name = self.class.name_of(panel)
    return nil if name.empty?
    self.class.external_by_name(name, panel).find { |ent| ent.valid? }
  end
  def refresh_errors
    @err_pts = KSU::Nesting.error_points(KSU::Nesting.find_nesting(notify: false))
    @_x_bi_lan_polys = nil
  end
end
class KSU::Chontam
  def self.validate_key(serial_key)
    KSU::Const.fetch_json(KSU::Loop.license_url(serial_key, "validate"))
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
