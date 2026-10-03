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
    _97011c68 = @nesting
    _513e6514 = @sheets
    _b849fe49 = @label_section_hidden
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
    @slots = []
    @free_rects = {}
    @nesting = nil
    @sheets = []
    @flag56 = false
    @inst3 = nil
    @pt9 = nil
    @pt = nil
    @_1cb11a43 = nil
    @arr26 = nil
    @cur_pt = nil
    @plane_z = 0.0
    @id = nil
    @flag60 = nil
    @h5 = {}
    @flag19 = false
    @entry = nil
    @edge = nil
    @flag61 = nil
    @arr16 = nil
    @flag31 = nil
    @arr65 = nil
    @arr37 = []
    @err_pts = []
    @_x_bi_lan_polys = nil
    if Sketchup.active_model.tools.active_tool == self
      @nesting = _97011c68
      @sheets = _513e6514
      @label_section_hidden = _b849fe49
      @h5 = {}
      @err_pts = KSU::Nesting.error_points(@nesting)
      find_free_rects if @mode == 1
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
    _ca5147c6
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
    _52c178c0(true)
    find_free_rects if @mode == 1
    update_status
    KSU::View.view.invalidate
  end
  def deactivate(view)
    save_selected_preset
    _52c178c0(false)
    _70785283(@sheets.map { |rec| rec[:instance] })
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def reload_settings
    super
    @h5 = {}
    find_free_rects if @mode == 1
    KSU::View.refresh
  end
  def commit_field_input(view)
    answer = super
    find_free_rects if @mode == 1
    view&.invalidate
    answer
  end
  def onSetCursor
    return false if busy?
    if @flag19
      UI.set_cursor(cursor_for(@edge))
      return true
    end
    if !@flag56 && @arr65
      UI.set_cursor(cursor_for(@arr65[:edge]))
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
      @flag29 = true
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
    @flag29 = false
    view&.invalidate
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onMouseMove(rot, x, y, view)
    @flag29 = (rot & MK_SHIFT) != 0
    hover_field(x, y, view)
    hover_mode(x, y, view)
    hover_preset(x, y, view)
    @cur_pt = KSU::View.pick_on_plane(view, x, y, @plane_z)
    if @flag19 && @cur_pt
      resize_to_cursor(view)
    elsif @flag56 && @inst3 && @cur_pt
      @pt = _d204c38c(@cur_pt, @_1cb11a43, view)
      @pt = _81184680(@pt9, @pt) if @pt9
      @flag60 = @pt
    else
      hover_button(view, x, y)
      @arr65 = edge_at(view, x, y)
      @flag60 = @arr65 ? nil : _63677f15(view, x, y)
    end
    view.invalidate
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    return if click_mode(x, y, view)
    return if begin_resize(view, x, y)
    if @mode == 1
      arr = _bb230f13(view, x, y)
      if arr
        ctrl = (rot & MK_SHIFT) != 0
        if arr[:kind] == :remove
          ctrl ? @slots.clear : @slots.delete(arr[:entry])
        elsif ctrl
          add_all
        else
          @slots << { sheet: arr[:sheet], points: arr[:points] }
        end
        find_free_rects
        view.invalidate
      end
      return
    end
    if @flag56
      _d4767c0f
      view.invalidate
      return
    end
    arr = _bb230f13(view, x, y)
    if arr && arr[:kind] == :remove
      @slots.delete(arr[:entry])
      view.invalidate
      return
    end
    rec = _0ed68c30(view, x, y)
    return unless rec
    @_1cb11a43 = limits_of(rec)
    @arr26 = panel_boxes(rec[:instance], rec[:transform])
    _d41bb15d = KSU::View.pick_on_plane(view, x, y, @plane_z)
    _d41bb15d = _d204c38c(_d41bb15d, @_1cb11a43, view)
    return unless _d41bb15d
    @flag56 = true
    @inst3 = rec[:instance]
    @pt9 = _d41bb15d
    @pt = _d41bb15d
    @arr65 = nil
    view.invalidate
  end
  def onLButtonUp(kflags, x, y, view)
    return unless @flag19
    _cd5e80f4
    view.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    draw_overlay(view, @nesting)
    _b6a93f39(view)
    _786169a2(view)
    if @mode == 1
      _8964db66(view)
    else
      _f7ec2498(view)
    end
    KSU::View.draw_cross(@flag60, size_px: 6) if @flag60 && !busy?
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
      @flag56 = false
      @pt9 = nil
      @pt = nil
      @inst3 = nil
      @arr26 = nil
    else
      @free_rects = {}
    end
    @flag60 = nil
    Sketchup.active_model&.active_view&.invalidate
  end
  def update_status
    KSU.set_status("Nhấn Tab để chuyển chế độ.")
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting)
    @plane_z = @sheets.empty? ? 0.0 : @sheets.first[:bbox].center.z.to_f
  end
  def _0ed68c30(view, x, y)
    @sheets.find do |rec|
      bbox = rec[:bbox]
      pts = (0..7).map { |i| view.screen_coords(bbox.corner(i)) }
      arr2 = pts.map(&:x)
      arr = pts.map(&:y)
      x.between?(arr2.min, arr2.max) && y.between?(arr.min, arr.max)
    end
  end
  def limits_of(rec)
    @h5[rec[:instance].entityID] ||= _c6224ad4(rec)
  end
  def _c6224ad4(rec)
    bbox = rec[:bbox]
    gap2 = @tam_cach_nhau.to_f
    num2, num, _7ebf0e82, _b51d21a5 = usable_rect(rec)
    if num2 > _7ebf0e82
      num2 = _7ebf0e82 = (bbox.min.x.to_f + bbox.max.x.to_f) / 2.0
    end
    if num > _b51d21a5
      num = _b51d21a5 = (bbox.min.y.to_f + bbox.max.y.to_f) / 2.0
    end
    x = [{ v: num2, lo: num, hi: _b51d21a5 }, { v: _7ebf0e82, lo: num, hi: _b51d21a5 }]
    y = [{ v: num, lo: num2, hi: _7ebf0e82 }, { v: _b51d21a5, lo: num2, hi: _7ebf0e82 }]
    _93f5a81b(rec, gap2).each do |arr|
      n = arr.length
      n.times do |i|
        pt = arr[i]
        b = arr[(i + 1) % n]
        if (pt.x - b.x).abs < 1e-6
          x << { v: pt.x.to_f, lo: [pt.y.to_f, b.y.to_f].min, hi: [pt.y.to_f, b.y.to_f].max }
        elsif (pt.y - b.y).abs < 1e-6
          y << { v: pt.y.to_f, lo: [pt.x.to_f, b.x.to_f].min, hi: [pt.x.to_f, b.x.to_f].max }
        end
      end
    end
    {
      x: x.select { |s| s[:v] >= num2 - 1e-6 && s[:v] <= _7ebf0e82 + 1e-6 },
      y: y.select { |s| s[:v] >= num - 1e-6 && s[:v] <= _b51d21a5 + 1e-6 },
      xs: num2, xe: _7ebf0e82, ys: num, ye: _b51d21a5
    }
  end
  def _93f5a81b(rec, gap2)
    arr2 = panel_boxes(rec[:instance], rec[:transform]).map do |bb|
      points({ x1: bb.min.x.to_f - gap2, y1: bb.min.y.to_f - gap2, x2: bb.max.x.to_f + gap2, y2: bb.max.y.to_f + gap2 })
    end
    return [] if arr2.empty?
    _662cf545(arr2)
  end
  def _d204c38c(pt, arr, view)
    return pt unless pt && arr
    x = [[pt.x.to_f, arr[:xs]].max, arr[:xe]].min
    y = [[pt.y.to_f, arr[:ys]].max, arr[:ye]].min
    _0845fb1d = _ae750226(view, pt)
    nx = arr[:x].select { |s| y >= s[:lo] - _0845fb1d && y <= s[:hi] + _0845fb1d }.map { |s| s[:v] }.min_by { |v| (v - x).abs }
    ny = arr[:y].select { |s| x >= s[:lo] - _0845fb1d && x <= s[:hi] + _0845fb1d }.map { |s| s[:v] }.min_by { |v| (v - y).abs }
    x = nx if nx && (nx - x).abs <= _0845fb1d
    y = ny if ny && (ny - y).abs <= _0845fb1d
    Geom::Point3d.new(x, y, @plane_z)
  end
  def _ae750226(view, _d41bb15d)
    view.pixels_to_model(12, _d41bb15d).to_f
  rescue StandardError
    @tam_cach_le.to_f
  end
  def _63677f15(view, x, y)
    return nil unless @mode == 0 && @cur_pt
    rec = _0ed68c30(view, x, y)
    return nil unless rec
    _d204c38c(@cur_pt, limits_of(rec), view)
  end
  def _d4767c0f
    rect = _d5a5cc33
    return unless rect && _a9ca2ebd(rect)
    @slots << { sheet: @inst3, points: rect }
    @flag56 = false
    @inst3 = nil
    @pt9 = nil
    @pt = nil
    @_1cb11a43 = nil
    @arr26 = nil
  end
  def _d5a5cc33
    return nil unless @pt9 && @pt
    x212 = @pt9.x.to_f
    num2 = @pt9.y.to_f
    x2 = @pt.x.to_f
    y2 = @pt.y.to_f
    tol = 0.01.mm.to_f
    return nil if (x212 - x2).abs <= tol && (num2 - y2).abs <= tol
    points({ x1: [x212, x2].min, y1: [num2, y2].min, x2: [x212, x2].max, y2: [num2, y2].max })
  end
  def _a9ca2ebd(pts)
    bbox = Geom::BoundingBox.new
    pts.each { |_23505ef9| bbox.add(_23505ef9) }
    lo = @chieu_rong_toi_thieu.to_f
    bbox.width > lo && bbox.height > lo
  end
  def _ca5147c6
    @slots = []
    @sheets.each do |rec|
      sheet = rec[:instance]
      next unless sheet && sheet.valid?
      id_str = sheet.get_attribute("ABF", "sheet-last-cut", nil)
      if id_str
        _1bba59fa(sheet, rec, id_str)
      else
        _ca2351da(sheet, rec)
      end
    end
  rescue
    @slots = []
  end
  def _1bba59fa(sheet, rec, id_str)
    data = begin
      JSON.parse(id_str)
    rescue StandardError
      nil
    end
    return unless data && data["rects"].is_a?(Array)
    box = rec[:bbox]
    _bd21b165, _e55fd46f = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    num2 = box.min.x.to_f + _bd21b165
    num4 = box.min.y.to_f + _e55fd46f
    data["rects"].each do |half|
      next unless half.is_a?(Array) && half.length >= 4
      x = num2 + half[0].to_f
      y = num4 + half[1].to_f
      w = half[2].to_f
      h = half[3].to_f
      next if w <= 0 || h <= 0
      @slots << { sheet: sheet, points: points({ x1: x, y1: y, x2: x + w, y2: y + h }) }
    end
  end
  def _ca2351da(sheet, rec)
    transform = rec[:transform]
    sheet.definition.entities.each do |node|
      next unless _75723f03(node)
      ents = KSU.entities_in(node)
      tr = transform * node.transformation
      out = ents.grep(Sketchup::Edge).flat_map do |edge|
        [edge.start.position.transform(tr), edge.end.position.transform(tr)]
      end
      next if out.empty?
      bbox = Geom::BoundingBox.new
      out.each { |_23505ef9| bbox.add(_23505ef9) }
      @slots << {
        sheet: sheet,
        points: points({ x1: bbox.min.x, y1: bbox.min.y, x2: bbox.max.x, y2: bbox.max.y })
      }
    end
  end
end
class KSU::Netcatcuoi
  def self._8e3f5229
    key = KSU::Gannhan.license_field("k").to_s
    str2 = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i")).to_s
    return if key.empty? || str2.empty?
    new_id = KSU::Mirror._4b6ac4b0.to_s
    return if new_id.empty? || KSU::Xephang.normalize_id(new_id) == str2
    return unless KSU::Field.activation_ok?(KSU::Corner._4ac4c12f(key))
    KSU::Store.set_binding("i", new_id)
    KSU::Store.set_binding("t", Time.now.iso8601)
    KSU::Toiuuvan._e899e740
    true
  rescue
    nil
  end
end
class KSU::Netcatcuoi
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
