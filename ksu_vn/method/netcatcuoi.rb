require "json"
class KSU::Netcatcuoi
  include KSU::Preset
  tool_key "net_cat_cuoi"
  def initialize
    KSU::Toiuuvan.check_license
    KSU::Nest.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    k = s[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
    prev_nesting = @nesting
    prev_sheets = @sheets
    prev_hidden = @label_section_hidden
    @chieu_rong_toi_thieu = get("chieu_rong_toi_thieu", 300.0).to_f.mm
    @tam_cach_nhau = get("tam_cach_nhau", 6.5).to_f.mm
    @tam_cach_le = get("tam_cach_le", 3.5).to_f.mm
    edge = @tam_cach_le.to_mm
    @tach_cach_le = !!get("tach_cach_le", false)
    load_side_margins(edge)
    load_overlay_settings
    @presets = get("presets", nil)
    @label_section_hidden = []
    @mode = get("che_do", 0).to_i
    @rects = []
    @free_rects = {}
    @nesting = nil
    @sheets = []
    @flag35 = false
    @inst3 = nil
    @pt6 = nil
    @pt3 = nil
    @limits = nil
    @arr27 = nil
    @cur_pt = nil
    @plane_z = 0.0
    @id = nil
    @flag39 = nil
    @h9 = {}
    @flag11 = false
    @entry = nil
    @edge = nil
    @flag42 = nil
    @arr15 = nil
    @flag18 = nil
    @arr42 = nil
    @hidden_cuts = []
    @err_pts = []
    @_x_bi_lan_polys = nil
    if Sketchup.active_model.tools.active_tool == self
      @nesting = prev_nesting
      @sheets = prev_sheets
      @label_section_hidden = prev_hidden
      @h9 = {}
      @err_pts = KSU::Nesting.error_points(@nesting)
      find_free_rects_v1 if @mode == 1
      @label_section_hidden = KSU::Cutting.apply_label_hiding(
        @nesting, @an_nhan_tiet_dien, @label_section_hidden
      )
    end
  end
  def enableVCB?
    true
  end
  def activate
    KSU::Toiuuvan.check_license
    KSU::Nest.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    load_slots
    @err_pts = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
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
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    hide_last_cuts_v1(true)
    find_free_rects_v1 if @mode == 1
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    hide_last_cuts_v1(false)
    save_last_cuts_v1(@sheets.map { |rec| rec[:instance] })
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def reload_settings
    super
    @h9 = {}
    find_free_rects_v1 if @mode == 1
    KSU::View.refresh
  end
  def commit_field_input(view)
    answer = super
    find_free_rects_v1 if @mode == 1
    view&.invalidate
    answer
  end
  def onSetCursor
    return false if busy?
    if @flag11
      UI.set_cursor(cursor_for_v1(@edge))
      return true
    end
    if !@flag35 && @arr42
      UI.set_cursor(cursor_for_v1(@arr42[:edge]))
      return true
    end
    if @mode == 0
      UI.set_cursor(KSU::Const::CURSOR_PENCIL)
      return true
    end
    false
  end
  def onKeyDown(key, rep, kflags, view)
    if key == 192
      KSU::Settings.open_settings("net_cat_cuoi")
      return
    end
    if key == CONSTRAIN_MODIFIER_KEY
      @flag17 = true
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
    @flag17 = false
    view&.invalidate
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @flag17 = (rot & MK_SHIFT) != 0
    hover_field(x, y, view)
    hover_mode(x, y, view)
    hover_preset(x, y, view)
    @cur_pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    if @flag11 && @cur_pt
      resize_to_cursor(view)
    elsif @flag35 && @inst3 && @cur_pt
      @pt3 = snap_point(@cur_pt, @limits, view)
      @pt3 = clamp_point_v1(@pt6, @pt3) if @pt6
      @flag39 = @pt3
    else
      hover_button_v1(view, x, y)
      @arr42 = edge_at_v1(view, x, y)
      @flag39 = @arr42 ? nil : snap_preview(view, x, y)
    end
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    return if click_mode(x, y, view)
    return if begin_resize_v1(view, x, y)
    if @mode == 1
      arr = button_hit_v1(view, x, y)
      if arr
        ctrl = (rot & MK_SHIFT) != 0
        if arr[:kind] == :remove
          ctrl ? @rects.clear : @rects.delete(arr[:entry])
        elsif ctrl
          add_all_v1
        else
          @rects << { sheet: arr[:sheet], points: arr[:points] }
        end
        find_free_rects_v1
        view.invalidate
      end
      return
    end
    if @flag35
      commit_rect
      view.invalidate
      return
    end
    arr = button_hit_v1(view, x, y)
    if arr && arr[:kind] == :remove
      @rects.delete(arr[:entry])
      view.invalidate
      return
    end
    rec = sheet_at_screen(view, x, y)
    return unless rec
    @limits = limits_of(rec)
    @arr27 = panel_boxes_v1(rec[:instance], rec[:transform])
    pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    pt = snap_point(pt, @limits, view)
    return unless pt
    @flag35 = true
    @inst3 = rec[:instance]
    @pt6 = pt
    @pt3 = pt
    @arr42 = nil
    view.invalidate
  end
  def onLButtonUp(kflags, x, y, view)
    return unless @flag11
    end_resize_v1
    view.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    draw_overlay(view, @nesting)
    draw_slots(view)
    draw_bad_rect(view)
    if @mode == 1
      draw_free_rects_v1(view)
    else
      draw_new_rect(view)
    end
    KSU::View.draw_cross(@flag39, size_px: 6) if @flag39 && !busy?
    draw_sheet_buttons_v1(view)
    draw_modes(view)
    draw_presets(view)
    draw_fields(view)
  end
  private
  def switch_mode(i)
    @mode = i
    set("che_do", @mode)
    if @mode == 1
      find_free_rects_v1
      @flag35 = false
      @pt6 = nil
      @pt3 = nil
      @inst3 = nil
      @arr27 = nil
    else
      @free_rects = {}
    end
    @flag39 = nil
    Sketchup.active_model&.active_view&.invalidate
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
      bbox = rec[:bbox]
      pts = (0..7).map { |i| view.screen_coords(bbox.corner(i)) }
      arr = pts.map(&:x)
      arr2 = pts.map(&:y)
      x.between?(arr.min, arr.max) && y.between?(arr2.min, arr2.max)
    end
  end
  def limits_of(rec)
    @h9[rec[:instance].entityID] ||= build_limits(rec)
  end
  def build_limits(rec)
    bbox = rec[:bbox]
    gap2 = @tam_cach_nhau.to_f
    num, num2, x_hi2, y_hi2 = usable_rect_v1(rec)
    if num > x_hi2
      num = x_hi2 = (bbox.min.x.to_f + bbox.max.x.to_f) / 2.0
    end
    if num2 > y_hi2
      num2 = y_hi2 = (bbox.min.y.to_f + bbox.max.y.to_f) / 2.0
    end
    x = [{ v: num, lo: num2, hi: y_hi2 }, { v: x_hi2, lo: num2, hi: y_hi2 }]
    y = [{ v: num2, lo: num, hi: x_hi2 }, { v: y_hi2, lo: num, hi: x_hi2 }]
    panel_guides(rec, gap2).each do |arr|
      n = arr.length
      n.times do |i|
        v = arr[i]
        b = arr[(i + 1) % n]
        if (v.x - b.x).abs < 1e-6
          x << { v: v.x.to_f, lo: [v.y.to_f, b.y.to_f].min, hi: [v.y.to_f, b.y.to_f].max }
        elsif (v.y - b.y).abs < 1e-6
          y << { v: v.y.to_f, lo: [v.x.to_f, b.x.to_f].min, hi: [v.x.to_f, b.x.to_f].max }
        end
      end
    end
    {
      x: x.select { |s| s[:v] >= num - 1e-6 && s[:v] <= x_hi2 + 1e-6 },
      y: y.select { |s| s[:v] >= num2 - 1e-6 && s[:v] <= y_hi2 + 1e-6 },
      xs: num, xe: x_hi2, ys: num2, ye: y_hi2
    }
  end
  def panel_guides(rec, gap2)
    arr = panel_boxes_v1(rec[:instance], rec[:transform]).map do |bb|
      points_v1({ x1: bb.min.x.to_f - gap2, y1: bb.min.y.to_f - gap2, x2: bb.max.x.to_f + gap2, y2: bb.max.y.to_f + gap2 })
    end
    return [] if arr.empty?
    merge_rects_v1(arr)
  end
  def snap_point(pt, arr, view)
    return pt unless pt && arr
    x = [[pt.x.to_f, arr[:xs]].max, arr[:xe]].min
    y = [[pt.y.to_f, arr[:ys]].max, arr[:ye]].min
    _0845fb1d = snap_tol(view, pt)
    nx = arr[:x].select { |s| y >= s[:lo] - _0845fb1d && y <= s[:hi] + _0845fb1d }.map { |s| s[:v] }.min_by { |v| (v - x).abs }
    ny = arr[:y].select { |s| x >= s[:lo] - _0845fb1d && x <= s[:hi] + _0845fb1d }.map { |s| s[:v] }.min_by { |v| (v - y).abs }
    x = nx if nx && (nx - x).abs <= _0845fb1d
    y = ny if ny && (ny - y).abs <= _0845fb1d
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
    rect_v1 = drag_rect
    return unless rect_v1 && big_enough?(rect_v1)
    @rects << { sheet: @inst3, points: rect_v1 }
    @flag35 = false
    @inst3 = nil
    @pt6 = nil
    @pt3 = nil
    @limits = nil
    @arr27 = nil
  end
  def drag_rect
    return nil unless @pt6 && @pt3
    num = @pt6.x.to_f
    num2 = @pt6.y.to_f
    x2 = @pt3.x.to_f
    num3 = @pt3.y.to_f
    tol = 0.01.mm.to_f
    return nil if (num - x2).abs <= tol && (num2 - num3).abs <= tol
    points_v1({ x1: [num, x2].min, y1: [num2, num3].min, x2: [num, x2].max, y2: [num2, num3].max })
  end
  def big_enough?(pts)
    bbox = Geom::BoundingBox.new
    pts.each { |pt4| bbox.add(pt4) }
    lo = @chieu_rong_toi_thieu.to_f
    bbox.width > lo && bbox.height > lo
  end
  def load_slots
    @rects = []
    @sheets.each do |rec|
      sheet = rec[:instance]
      next unless sheet && sheet.valid?
      id_str = sheet.get_attribute("ABF", "sheet-last-cut", nil)
      if id_str
        load_slots_json(sheet, rec, id_str)
      else
        load_slots_geom(sheet, rec)
      end
    end
  rescue
    @rects = []
  end
  def load_slots_json(sheet, rec, id_str)
    data = begin
      JSON.parse(id_str)
    rescue StandardError
      nil
    end
    return unless data && data["rects"].is_a?(Array)
    box = rec[:bbox]
    off_x, off_y = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    num2 = box.min.x.to_f + off_x
    num = box.min.y.to_f + off_y
    data["rects"].each do |half|
      next unless half.is_a?(Array) && half.length >= 4
      x = num2 + half[0].to_f
      y = num + half[1].to_f
      w = half[2].to_f
      h = half[3].to_f
      next if w <= 0 || h <= 0
      @rects << { sheet: sheet, points: points_v1({ x1: x, y1: y, x2: x + w, y2: y + h }) }
    end
  end
  def load_slots_geom(sheet, rec)
    transform = rec[:transform]
    sheet.definition.entities.each do |node|
      next unless last_cut_group?(node)
      ents = KSU.entities_in(node)
      tr = transform * node.transformation
      out = ents.grep(Sketchup::Edge).flat_map do |edge|
        [edge.start.position.transform(tr), edge.end.position.transform(tr)]
      end
      next if out.empty?
      bbox = Geom::BoundingBox.new
      out.each { |pt4| bbox.add(pt4) }
      @rects << {
        sheet: sheet,
        points: points_v1({ x1: bbox.min.x, y1: bbox.min.y, x2: bbox.max.x, y2: bbox.max.y })
      }
    end
  end
end
class KSU::Netcatcuoi
  def self.rebind_license
    key = KSU::Gannhan.license_field("k").to_s
    str = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i")).to_s
    return if key.empty? || str.empty?
    new_id = KSU::Mirror.machine_id.to_s
    return if new_id.empty? || KSU::Xephang.normalize_id(new_id) == str
    return unless KSU::Field.activation_ok?(KSU::Corner.deactivate_now(key))
    KSU::Store.set_binding("i", new_id)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuuvan.drop_id_cache
    true
  rescue
    nil
  end
end
class KSU::Netcatcuoi
  def self.check_license
    arr = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr2 = arr[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr2 =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (61 + i * 87) }.pack("C*")
    arr2 = arr[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr2 =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
