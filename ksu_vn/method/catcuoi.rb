require "json"
class KSU::Catcuoi
  include KSU::Preset
  tool_key "net_cat_cuoi"
  def initialize
    KSU::Toiuu.check_license
    KSU::Nest.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    arr2 = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless arr2 =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
    prev_nesting = @nesting
    prev_sheets = @sheets
    @chieu_rong_toi_thieu = get("chieu_rong_toi_thieu", 300.0).mm
    @tam_cach_nhau = get("tam_cach_nhau", 6.5).mm
    @tam_cach_le = get("tam_cach_le", 3.5).mm
    @tach_cach_le = !!get("tach_cach_le", false)
    load_side_margins(@tam_cach_le.to_mm)
    load_overlay_settings
    @presets = get("presets", nil)
    @mode = get("che_do", 0)
    @rects = []
    @free_rects = {}
    @sheets = []
    @h8 = {}
    @hidden_cuts = []
    @arr38 = []
    @plane_z = 0.0
    @flag22 = @flag31 = false
    @nesting = @cur_pt = @id = @flag46 = @arr = @_x_bi_lan_polys = nil
    @inst3 = @cache = @hover = @limits = @arr11 = nil
    @entry = @edge = @flag3 = @arr44 = @flag6 = nil
    if Sketchup.active_model.tools.active_tool == self
      @nesting = prev_nesting
      @sheets = prev_sheets
      @arr38 = KSU::Nesting.error_points(@nesting)
      find_free_rects if @mode == 1
    end
  end
  def enableVCB?
    true
  end
  def activate
    KSU::Toiuu.check_license
    KSU::Nest.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    load_slots
    @arr38 = KSU::Nesting.error_points(@nesting)
    init_modes(
      ["Thủ công", "Tự động"],
      active_proc: -> { @mode },
      on_click: ->(i) { switch_mode(i) }
    )
    setup_fields(
      "Chiều rộng tối thiểu" => {
        chieu_rong_toi_thieu: [:mm, "Chiều rộng tối thiểu", nil, 0, 10000],
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS,
      "Khoảng cách" => {
        tam_cach_nhau: [:mm, "Tấm cách nhau", nil, 0, 100]
      }.merge(margin_rows(nil, -> { @tach_cach_le }))
    )
    load_presets(@presets)
    restore_selected_preset
    hide_last_cuts(true)
    find_free_rects if @mode == 1
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    hide_last_cuts(false)
    save_last_cuts(@sheets.map { |rec| rec[:instance] })
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def reload_settings
    super
    @h8 = {}
    find_free_rects if @mode == 1
    KSU::View.refresh
  end
  def commit_field_input(view)
    ok = super
    find_free_rects if @mode == 1
    view&.invalidate
    ok
  end
  def onSetCursor
    return false if busy?
    id = if @flag31 then cursor_for(@edge)
            elsif !@flag22 && @arr then cursor_for(@arr[:edge])
            elsif @mode == 0 then 632
            end
    return false unless id
    UI.set_cursor(id)
    true
  end
  def onKeyDown(key, rep, kflags, view)
    if key == 192
      KSU::Settings.open_settings("net_cat_cuoi")
      return
    end
    if key == CONSTRAIN_MODIFIER_KEY
      @flag36 = true
      view&.invalidate
      return
    end
    if key == 9
      switch_mode(1 - @mode)
      return
    end
    return unless key == 32
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onKeyUp(key, rep, kflags, view)
    return unless key == CONSTRAIN_MODIFIER_KEY
    @flag36 = false
    view&.invalidate
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @flag36 = (rot & MK_SHIFT) != 0
    hover_field(x, y, view)
    hover_mode(x, y, view)
    hover_preset(x, y, view)
    @cur_pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    if @flag31 && @cur_pt
      draw_entry
    elsif @flag22 && @inst3 && @cur_pt
      @hover = snap_point(@cur_pt, @limits, view)
      @hover = clamp_point(@cache, @hover) if @cache
      @flag46 = @hover
    else
      hover_button(view, x, y)
      @arr = edge_at(view, x, y)
      @flag46 = @arr ? nil : snap_preview(view, x, y)
    end
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    return if click_mode(x, y, view)
    return if begin_resize(view, x, y)
    if @mode == 1
      _945ac34d = button_hit(view, x, y)
      if _945ac34d
        ctrl = (rot & MK_SHIFT) != 0
        if _945ac34d[:kind] == :remove
          ctrl ? @rects.clear : @rects.delete(_945ac34d[:entry])
        elsif ctrl
          add_all
        else
          @rects << { sheet: _945ac34d[:sheet], points: _945ac34d[:points] }
        end
        find_free_rects
        view.invalidate
      end
      return
    end
    if @flag22
      commit_rect
      view.invalidate
      return
    end
    _945ac34d = button_hit(view, x, y)
    if _945ac34d && _945ac34d[:kind] == :remove
      @rects.delete(_945ac34d[:entry])
      view.invalidate
      return
    end
    rec = sheet_at_screen(view, x, y)
    return unless rec
    @limits = limits_of(rec)
    @arr11 = panel_boxes(rec[:instance], rec[:transform])
    pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    pt = snap_point(pt, @limits, view)
    return unless pt
    @flag22 = true
    @inst3 = rec[:instance]
    @cache = @hover = pt
    @arr = nil
    view.invalidate
  end
  def onLButtonUp(kflags, x, y, view)
    return unless @flag31
    end_resize
    view.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    draw_overlay(view, @nesting)
    draw_sheet_rects
    draw_cut_line
    @mode == 1 ? draw_free_rects : draw_drag_rect
    KSU::View.draw_cross(@flag46, size_px: 6) if @flag46 && !busy?
    draw_sheet_buttons(view)
    draw_modes(view)
    draw_presets(view)
    draw_fields(view)
  end
  private
  def switch_mode(i)
    @mode = i
    set("che_do", @mode)
    if @mode == 1
      find_free_rects
      @flag22 = false
      @cache = @hover = @inst3 = @arr11 = nil
    else
      @free_rects = {}
    end
    @flag46 = nil
    KSU::View.view&.invalidate
  end
  def update_status
    KSU.set_status("Nhấn Tab để chuyển chế độ.")
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting)
    @plane_z = @sheets.empty? ? 0.0 : @sheets.first[:bbox].center.z.to_f
  end
  def sheet_at_screen(view, x, y)
    @sheets.find do |rec|
      pt = KSU::Geom.box_corners(rec[:bbox]).map { |pt3| view.screen_coords(pt3) }
      arr2 = pt.map(&:x)
      arr = pt.map(&:y)
      x.between?(arr2.min, arr2.max) && y.between?(arr.min, arr.max)
    end
  end
  def limits_of(rec)
    @h8[rec[:instance].entityID] ||= build_limits(rec)
  end
  def build_limits(rec)
    bbox = rec[:bbox]
    num2, num, x_hi2, y_hi2 = usable_rect(rec)
    num2 = x_hi2 = (bbox.min.x.to_f + bbox.max.x.to_f) / 2.0 if num2 > x_hi2
    num = y_hi2 = (bbox.min.y.to_f + bbox.max.y.to_f) / 2.0 if num > y_hi2
    x = [{ v: num2, lo: num, hi: y_hi2 }, { v: x_hi2, lo: num, hi: y_hi2 }]
    y = [{ v: num, lo: num2, hi: x_hi2 }, { v: y_hi2, lo: num2, hi: x_hi2 }]
    panel_guides(rec, @tam_cach_nhau.to_f).each do |arr|
      arr.zip(arr.rotate).each do |pt, b|
        if (pt.x - b.x).abs < 1e-6
          x << { v: pt.x.to_f, lo: [pt.y.to_f, b.y.to_f].min, hi: [pt.y.to_f, b.y.to_f].max }
        elsif (pt.y - b.y).abs < 1e-6
          y << { v: pt.y.to_f, lo: [pt.x.to_f, b.x.to_f].min, hi: [pt.x.to_f, b.x.to_f].max }
        end
      end
    end
    {
      x: x.select { |s| s[:v] >= num2 - 1e-6 && s[:v] <= x_hi2 + 1e-6 },
      y: y.select { |s| s[:v] >= num - 1e-6 && s[:v] <= y_hi2 + 1e-6 },
      xs: num2, xe: x_hi2, ys: num, ye: y_hi2
    }
  end
  def panel_guides(rec, gap2)
    arr = panel_boxes(rec[:instance], rec[:transform]).map do |bb|
      points({ x1: bb.min.x.to_f - gap2, y1: bb.min.y.to_f - gap2, x2: bb.max.x.to_f + gap2, y2: bb.max.y.to_f + gap2 })
    end
    merge_rects(arr)
  end
  def snap_point(pt, arr, view)
    return pt unless pt && arr
    x = [[pt.x.to_f, arr[:xs]].max, arr[:xe]].min
    y = [[pt.y.to_f, arr[:ys]].max, arr[:ye]].min
    _15bc30f3 = snap_tol(view, pt)
    nx = arr[:x].select { |s| y >= s[:lo] - _15bc30f3 && y <= s[:hi] + _15bc30f3 }.map { |s| s[:v] }.min_by { |v| (v - x).abs }
    ny = arr[:y].select { |s| x >= s[:lo] - _15bc30f3 && x <= s[:hi] + _15bc30f3 }.map { |s| s[:v] }.min_by { |v| (v - y).abs }
    x = nx if nx && (nx - x).abs <= _15bc30f3
    y = ny if ny && (ny - y).abs <= _15bc30f3
    Geom::Point3d.new(x, y, @plane_z)
  end
  def snap_tol(view, pt)
    view.pixels_to_model(12, pt).to_f
  rescue StandardError
    @tam_cach_le.to_f
  end
  def snap_preview(view, x, y)
    return nil unless @mode == 0 && @cur_pt
    rec = sheet_at_screen(view, x, y)
    return nil unless rec
    snap_point(@cur_pt, limits_of(rec), view)
  end
  def commit_rect
    rect = drag_rect
    return unless rect && big_enough?(rect)
    @rects << { sheet: @inst3, points: rect }
    @flag22 = false
    @inst3 = @cache = @hover = @limits = @arr11 = nil
  end
  def drag_rect
    return nil unless @cache && @hover
    x1, x2, y1, y2 = xy_bounds([@cache, @hover])
    tol = 0.01.mm.to_f
    return nil if x2 - x1 <= tol && y2 - y1 <= tol
    points({ x1: x1, y1: y1, x2: x2, y2: y2 })
  end
  def big_enough?(arr)
    bbox = Geom::BoundingBox.new
    arr.each { |pt3| bbox.add(pt3) }
    lo = @chieu_rong_toi_thieu.to_f
    bbox.width > lo && bbox.height > lo
  end
  def load_slots
    @rects = []
    @sheets.each do |rec|
      grp = rec[:instance]
      next unless grp && grp.valid?
      id_str = grp.get_attribute("ABF", "sheet-last-cut", nil)
      id_str ? load_slots_json(grp, rec, id_str) : load_slots_geom(grp, rec)
    end
  rescue
    @rects = []
  end
  def load_slots_json(sheet, rec, id_str)
    data = JSON.parse(id_str) rescue nil
    return unless data && data["rects"].is_a?(Array)
    _821639ac, _98c3a7e0 = sheet_offset(rec)
    data["rects"].each do |half|
      next unless half.is_a?(Array) && half.length >= 4
      x = _821639ac + half[0].to_f
      y = _98c3a7e0 + half[1].to_f
      w = half[2].to_f
      elem = half[3].to_f
      next if w <= 0 || elem <= 0
      @rects << { sheet: sheet, points: points({ x1: x, y1: y, x2: x + w, y2: y + elem }) }
    end
  end
  def load_slots_geom(grp2, rec)
    grp2.definition.entities.each do |grp|
      next unless KSU.container?(grp) && KSU::Nesting.last_cut?(grp)
      tr = rec[:transform] * grp.transformation
      out = KSU.entities_in(grp).grep(Sketchup::Edge).flat_map do |edge|
        [edge.start.position.transform(tr), edge.end.position.transform(tr)]
      end
      next if out.empty?
      bbox = Geom::BoundingBox.new
      out.each { |pt3| bbox.add(pt3) }
      @rects << { sheet: grp2, points: points({ x1: bbox.min.x, y1: bbox.min.y, x2: bbox.max.x, y2: bbox.max.y }) }
    end
  end
end
class KSU::Catcuoi
  def self.rebind_license
    key = KSU::Gannhan.license_field("k").to_s
    str = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i")).to_s
    return if key.empty? || str.empty?
    new_id = KSU::Mirror.machine_id.to_s
    return if new_id.empty? || KSU::Xephang.normalize_id(new_id) == str
    return unless KSU::Field.activation_ok?(KSU::Corner.deactivate_now(key))
    KSU::Store.set_binding("i", new_id)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuu.drop_id_cache
    true
  rescue
    nil
  end
end
class KSU::Catcuoi
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
