class KSU::Themtam
  include KSU::Preset
  tool_key "them_tam"
  def initialize
    KSU::Xephang.check_license
    KSU::Danhsovan.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    k = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless k =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @nesting = nil
    @sheets = []
    @loose = []
    @chosen = []
    @hover_loose = nil
    @add_buttons = []
    @hover_side = nil
    @grp = nil
    @them_tam_tu_do = !!get("them_tam_tu_do", true)
    @them_tem_nhan = !!get("them_tem_nhan", false)
    @ghi_de_tam_cu = !!get("ghi_de_tam_cu", false)
    load_overlay_settings
    @presets = get("presets", nil)
    @label_section_hidden = []
    @arr20 = []
    @arr11 = []
    @_x_bi_lan_polys = nil
    @overwrite_preview = []
    @arr38 = nil
    if Sketchup.active_model.tools.active_tool == self
      refresh_overlays
      @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    end
  end
  def activate
    KSU::Xephang.check_license
    KSU::Danhsovan.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    scan_loose
    pick_from_selection
    setup_fields(
      "Thêm tấm" => {
        them_tam_tu_do: [:switch, "Thêm tấm tự do"]
      },
      "Ghi đè" => {
        ghi_de_tam_cu: [:switch, "Ghi đè tấm cũ"]
      },
      "Tem nhãn" => {
        them_tem_nhan: [:switch, "Thêm tem nhãn"]
      },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    load_presets(@presets)
    restore_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, @an_nhan_tiet_dien, @label_section_hidden)
    refresh_overlays
    @arr20 = KSU::Nesting.overlap_polys(@nesting)
    @arr11 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    save_selected_preset
    @label_section_hidden = KSU::Cutting.apply_label_hiding(@nesting, false, @label_section_hidden)
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onSetCursor
    if @arr38
      UI.set_cursor(KSU::Const::CURSOR_REFRESH)
      true
    else
      false
    end
  end
  def onKeyDown(key, rep, kflags, view)
    case key
    when 192 then KSU::Settings.open_settings("them_tam")
    when 27, 32
      KSU.select_tool(nil)
      view&.invalidate
    end
  end
  def onMouseMove(kflags, x, y, view)
    hover_preset(x, y, view)
    return if hover_field(x, y, view)
    _435dfd9d(view, x, y) if @overwrite_preview.any?
    if @chosen.any?
      track_button_hover(view, x, y)
    end
    track_hover(view, x, y)
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    if @overwrite_preview.any?
      arr = _26cf11cf(view, x, y)
      if arr
        overwrite_at(arr[:index])
        return
      end
    end
    if @chosen.any?
      prev = button_at(view, x, y)
      if prev
        add_after_row(prev[:row])
        return
      end
    end
    sheet = loose_at(view, x, y)
    return unless sheet
    toggle_chosen(sheet)
    refresh_overlays
    view.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    _c9bca5df(view)
    draw_overlay(view, @nesting)
    _6ae58d17(view)
    draw_loose(view)
    draw_add_buttons(view) if @chosen.any?
    draw_presets(view)
    draw_fields(view)
  end
  private
  def update_status
    if visible_chosen.any?
      KSU.set_status("Nhấn dấu + ở hàng muốn thêm. Nhấn vào tấm rời để chọn thêm hoặc bỏ chọn.")
    else
      KSU.set_status("Chọn một hoặc nhiều tấm rời hợp lệ để thêm vào sơ đồ nesting.")
    end
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting, include_bottom: true)
  end
  def scan_loose
    @loose = []
    Sketchup.active_model.entities.each do |ent|
      next unless KSU.container?(ent)
      next if ent == @nesting
      next unless sheet_like?(ent)
      @loose << record_of(ent)
    end
  end
  def sheet_like?(entity)
    return false unless entity.respond_to?(:get_attribute)
    %w[sheet-dimension sheet-thickness sheet-type].all? do |key|
      !entity.get_attribute("ABF", key).nil?
    end
  end
  def record_of(sheet)
    transform = sheet.transformation
    bd2 = sheet.definition.entities.find { |color| KSU.container?(color) && color.name.to_s == "__ABF_sheetBorder" }
    if bd2 && bd2.respond_to?(:definition) && bd2.definition
      tr = transform * bd2.transformation
      arr = (0..7).map { |i| tr * bd2.definition.bounds.corner(i) }
    else
      bb = sheet.definition.bounds
      arr = (0..7).map { |i| bb.corner(i).transform(transform) }
    end
    box = Geom::BoundingBox.new
    arr.each { |_23505ef9| box.add(_23505ef9) }
    { instance: sheet, bbox: box, transform: transform, top_corners: [arr[4], arr[5], arr[7], arr[6]] }
  end
  def pick_from_selection
    arr = KSU.selection.select do |ent|
      KSU.container?(ent) && ent != @nesting && sheet_like?(ent)
    end
    @chosen = arr
  end
  def loose_at(view, x, y)
    @loose.each do |rec|
      next unless rec[:instance].valid?
      pts = (0..7).map { |i| view.screen_coords(rec[:bbox].corner(i)) }
      arr3 = pts.map(&:x)
      arr2 = pts.map(&:y)
      return rec[:instance] if x.between?(arr3.min, arr3.max) && y.between?(arr2.min, arr2.max)
    end
    nil
  end
  def toggle_chosen(sheet)
    if @chosen.include?(sheet)
      @chosen.delete(sheet)
    else
      @chosen << sheet
    end
  end
  def track_hover(view, x, y)
    prev_key = @hover_loose
    @hover_loose = loose_at(view, x, y)
    view.invalidate if prev_key != @hover_loose
  end
  def draw_loose(view)
    @loose.each do |rec|
      sheet = rec[:instance]
      next unless sheet.valid?
      color = if @chosen.include?(sheet)
                KSU::View.main_face_color
              elsif @hover_loose == sheet
                KSU::View.face_color
              else
                KSU::View.sub_face_color
              end
      KSU::View._d64f2233(rec[:top_corners], thickness: 50.mm.to_f, position: :outside, color: color)
    end
  end
  def sheet_rows
    rows = []
    seen = []
    @sheets.each do |rec|
      sheet = rec[:instance]
      next if seen.include?(sheet)
      next if KSU::Sheet.hidden?(sheet)
      arr = KSU::Sheet.row_of(sheet, @sheets).reject { |s| KSU::Sheet.hidden?(s) }
      next if arr.empty?
      seen.concat(arr)
      rows << arr
    end
    rows
  end
  def build_add_buttons
    @add_buttons = []
    return if visible_chosen.empty? || @sheets.empty?
    keys = visible_chosen.map { |s| KSU::Sheet._7b0a38ee(s) }.uniq
    sheet_rows.each do |arr|
      rect = arr.last
      rec = @sheets.find { |s| s[:instance] == rect }
      next unless rec
      unless @them_tam_tu_do
        next unless keys.length == 1 && KSU::Sheet._7b0a38ee(rect) == keys.first
      end
      ix = arr.index(rect)
      offset = KSU::Sheet.row_offset(rec, arr, ix, @sheets)
      bbox = KSU::View._bb1a9bd8(rec[:bbox], offset)
      @add_buttons << { row: arr, bbox: bbox, center: Geom::Point3d.new((bbox.min.x + bbox.max.x) / 2.0, (bbox.min.y + bbox.max.y) / 2.0, bbox.max.z) }
    end
  end
  def refresh_overlays
    build_add_buttons
    build_overwrite_preview
  end
  def overwrite?
    @ghi_de_tam_cu
  end
  def build_overwrite_preview
    @overwrite_preview = []
    @arr38 = nil
    return unless overwrite?
    arr = @chosen.select { |s| s && s.valid? }
    return if arr.empty?
    arr2 = slot_map
    arr.each do |sheet|
      panels_of(sheet).each do |panel|
        ix = KSU::Cutting.board_index(panel)
        next if ix.nil?
        slot = arr2[[ix, KSU::Cutting.bottom_face?(panel)]]
        next unless slot
        slot_panel = slot[:panel]
        cur_sheet = slot[:sheet]
        next unless slot_panel && slot_panel.valid? && cur_sheet && cur_sheet.valid?
        tr2 = sheet.transformation * panel.transformation
        tr = @nesting.transformation * cur_sheet.transformation * slot_panel.transformation
        @overwrite_preview << {
          index: ix,
          loose_fill: KSU::Cutting.outline(panel, tr2),
          nest_fill: KSU::Cutting.outline(slot_panel, tr)
        }
      end
    end
  end
  def slot_map
    h = {}
    return h unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      next unless sheet.name.to_s.downcase.include?("sheet")
      sheet.definition.entities.each do |panel|
        next unless KSU.container?(panel)
        next unless KSU::Sheet._ed46427a(panel)
        ix = KSU::Cutting.board_index(panel)
        next if ix.nil?
        key = [ix, KSU::Cutting.bottom_face?(panel)]
        h[key] ||= { panel: panel, sheet: sheet }
      end
    end
    h
  end
  def visible_chosen
    @chosen.select { |s| s && s.valid? && !hidden_sheet?(s) }
  end
  def track_button_hover(view, x, y)
    prev_key = @hover_side
    @hover_side = button_at(view, x, y)
    view.invalidate if prev_key != @hover_side
  end
  def button_at(view, x, y)
    @add_buttons.find { |prev| KSU::View.button_hit?(view, prev[:center], x, y) }
  end
  def draw_add_buttons(view)
    @add_buttons.each do |prev|
      KSU::View.draw_loop(KSU::View.top_corners(prev[:bbox]), guide: true)
      KSU::View.draw_button(view, prev[:center], hover: @hover_side == prev)
    end
  end
  def add_after_row(arr3)
    arr2 = pair_jobs
    return unless arr2
    return if arr2.empty?
    @_dfd63ec2 = KSU::Nesting._c5ab406d(@nesting) + 1
    @grp = nil if @them_tem_nhan
    flag = arr3.last
    arr2.each do |arr|
      break unless flag && flag.valid?
      vec = if overwrite?
          place_overwrite(flag, arr)
        elsif arr[:bottom]
          place_pair(flag, arr[:top], arr[:bottom])
        else
          place_one(flag, arr[:top])
        end
      flag = vec if vec && vec.valid?
    end
    KSU::Sheet.apply_offsets(@nesting)
    KSU::Sheet.invalidate_cache
    KSU::Nesting._339f1198 if @them_tem_nhan
    @chosen = []
    sheet_list
    scan_loose
    refresh_overlays
    @arr20 = KSU::Nesting.overlap_polys(@nesting)
    @arr11 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    KSU::View.clear_cache
    KSU::View.view&.invalidate
    update_status
  end
  def overwrite_at(ix)
    arr = @chosen.select { |s| s && s.valid? }
    return if arr.empty?
    KSU.start
    _9195f5ac = slot_map
    arr.each { |sheet| overwrite_panels(sheet, [ix], _9195f5ac) }
    arr.each { |sheet| sheet.erase! if sheet.valid? && KSU::Sheet.empty?(sheet) }
    KSU.commit
    @chosen = @chosen.select { |s| s && s.valid? }
    sheet_list
    scan_loose
    refresh_overlays
    @arr20 = KSU::Nesting.overlap_polys(@nesting)
    @arr11 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    KSU::View.clear_cache
    KSU::View.view&.invalidate
    update_status
  rescue StandardError
    KSU.abort_op
  end
  def pair_jobs
    arr4 = @chosen.select { |s| s && s.valid? }
    arr2 = []
    arr = []
    arr4.each do |s|
      hidden_sheet?(s) ? arr << s : arr2 << s
    end
    arr3 = arr.map { |b| sheet_id_of(b) }.compact.uniq.any? do |id|
      arr2.count { |thick| sheet_id_of(thick) == id } > 1 ||
        arr.count { |b| sheet_id_of(b) == id } > 1
    end
    if arr3
      UI.messagebox(
        "Phát hiện trùng ID trong các ván được chọn. " \
        "Mỗi tấm hai mặt cần đúng một mặt trước và một mặt sau cùng ID. " \
        "Hãy bỏ bớt các ván trùng ID rồi thử lại."
      )
      return nil
    end
    arr2.map do |thick|
      id = sheet_id_of(thick)
      bot = id ? arr.find { |b| sheet_id_of(b) == id } : nil
      { top: thick, bottom: bot }
    end
  end
  def hidden_sheet?(sheet)
    KSU::Sheet.hidden?(sheet)
  end
  def sheet_id_of(sheet)
    return nil unless sheet && sheet.respond_to?(:get_attribute)
    id = sheet.get_attribute("ABF", "sheet-id")
    return id.to_i if id
    KSU::Sheet.sheet_no(sheet.name.to_s)
  end
  def place_one(vec2, grp)
    return nil unless vec2 && vec2.valid? && grp && grp.valid?
    KSU.start
    vec, = _5c6a1c61(vec2)
    unless vec && vec.valid?
      KSU.abort_op
      return nil
    end
    _a761a084(grp, vec)
    grp.erase! if grp.valid?
    KSU.commit
    vec
  rescue StandardError
    KSU.abort_op
    nil
  end
  def place_pair(vec2, top, bottom)
    return place_one(vec2, top) unless bottom && bottom.valid?
    return nil unless vec2 && vec2.valid? && top && top.valid?
    KSU.start
    vec, new_id = _5c6a1c61(vec2)
    unless vec && vec.valid?
      KSU.abort_op
      return nil
    end
    index_map = _596e474d(top, bottom)
    _a761a084(top, vec, index_map: index_map)
    vec3 = _0895e188(top, bottom, vec, new_id)
    _a761a084(bottom, vec3, index_map: index_map, back: true) if vec3 && vec3.valid?
    top.erase! if top.valid?
    bottom.erase! if bottom.valid?
    KSU.commit
    vec
  rescue StandardError
    KSU.abort_op
    nil
  end
  def place_overwrite(_08248783, arr)
    top = arr[:top]
    bottom = arr[:bottom]
    return nil unless top && top.valid?
    KSU.start
    _9195f5ac = slot_map
    _8904ee37 = overwritable_indices(top, bottom, _9195f5ac)
    overwrite_panels(top, _8904ee37, _9195f5ac)
    overwrite_panels(bottom, _8904ee37, _9195f5ac) if bottom && bottom.valid?
    flag = top.valid? && panels_of(top).any?
    flag2 = bottom && bottom.valid? && panels_of(bottom).any?
    vec = nil
    if flag && flag2
      vec, new_id = _5c6a1c61(_08248783)
      if vec && vec.valid?
        index_map = _596e474d(top, bottom)
        _a761a084(top, vec, index_map: index_map)
        vec2 = _0895e188(top, bottom, vec, new_id)
        _a761a084(bottom, vec2, index_map: index_map, back: true) if vec2 && vec2.valid?
      end
    elsif flag
      vec, = _5c6a1c61(_08248783)
      _a761a084(top, vec) if vec && vec.valid?
    end
    top.erase! if top.valid?
    bottom.erase! if bottom && bottom.valid?
    KSU.commit
    vec
  rescue StandardError
    KSU.abort_op
    nil
  end
  def face_presence(top, bottom)
    src = Hash.new { |arr52, k| arr52[k] = { top: false, bottom: false } }
    [top, bottom].each do |sheet|
      next unless sheet && sheet.valid?
      panels_of(sheet).each do |panel|
        ix = KSU::Cutting.board_index(panel)
        next if ix.nil?
        if KSU::Cutting.bottom_face?(panel)
          src[ix][:bottom] = true
        else
          src[ix][:top] = true
        end
      end
    end
    src
  end
  def overwritable_indices(top, bottom, h)
    out = []
    face_presence(top, bottom).each do |ix, f|
      flag = h.key?([ix, false])
      flag2 = h.key?([ix, true])
      next unless flag || flag2
      next unless f[:top] == flag && f[:bottom] == flag2
      out << ix
    end
    out
  end
  def overwrite_panels(grp2, arr, arr2)
    return if arr.empty?
    return unless grp2 && grp2.valid?
    panels_of(grp2).each do |panel|
      next unless panel.valid?
      ix = KSU::Cutting.board_index(panel)
      next if ix.nil? || !arr.include?(ix)
      slot = arr2[[ix, KSU::Cutting.bottom_face?(panel)]]
      next unless slot
      slot_panel = slot[:panel]
      cur_sheet = slot[:sheet]
      next unless slot_panel && slot_panel.valid? && cur_sheet && cur_sheet.valid?
      bb = slot_panel.bounds.center
      base_tr = (@nesting.transformation * cur_sheet.transformation).inverse * grp2.transformation * panel.transformation
      grp = KSU::Nesting.clone_panel(cur_sheet.definition.entities, panel, base_tr)
      next unless grp
      delta = grp.bounds.center.vector_to(bb)
      grp.transformation = Geom::Transformation.translation(delta) * grp.transformation
      _00102883(grp)
      slot_panel.erase! if slot_panel.valid?
    end
  end
  def _5c6a1c61(grp)
    sheet_list
    rec = @sheets.find { |s| s[:instance] == grp }
    return [nil, nil] unless rec
    arr = KSU::Sheet.row_of(grp, @sheets)
    ix = arr.index(grp) || (arr.length - 1)
    offset = KSU::Sheet.row_offset(rec, arr, ix, @sheets)
    tr = grp.transformation
    tr2 = Geom::Transformation.translation(offset) * tr
    arr2 = arr[(ix + 1)..-1] || []
    arr4 = arr2.each_with_object({}) do |s, arr52|
      arr52[s] = KSU::Sheet.sheet_labels(s, @nesting) if s && s.valid?
    end
    labels2 = KSU::Sheet.sheet_labels(grp, @nesting)
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(offset) * s.transformation
      KSU::Sheet.shift_dims(arr4[s] || [], offset, @nesting)
      bottom2 = KSU::Sheet.bottom(s, @nesting)
      bottom2.transformation = Geom::Transformation.translation(offset) * bottom2.transformation if bottom2 && bottom2.valid?
    end
    str = KSU::Sheet.sheet_no(grp.name.to_s)
    new_id = str ? str + 1 : nil
    KSU::Sheet.shift_sheets(@nesting, new_id, +1) if new_id
    grp2 = KSU::Sheet._f74b0a99(grp, tr2, @nesting)
    if grp2 && new_id
      str2 = "sheet-#{new_id}"
      grp2.name = str2
      grp2.set_attribute("ABF", "sheet-id", new_id)
      pt = tr2.origin - tr.origin
      arr3 = KSU::Sheet._a9a86c81(labels2, pt, @nesting)
      arr3.each { |len2d| KSU::Sheet._ba804f88(len2d, str2) }
    end
    [grp2, new_id]
  end
  def _0895e188(top, bottom, grp2, new_id)
    return nil unless bottom && bottom.valid? && grp2 && grp2.valid?
    tr = @nesting.transformation.inverse * bottom.transformation
    grp = KSU::Sheet._f74b0a99(bottom, tr, @nesting)
    return nil unless grp && grp.valid?
    bb2 = KSU::Sheet.world_bbox(grp2, @nesting)
    bbox = record_of(top)[:bbox]
    bbox2 = record_of(bottom)[:bbox]
    bb = KSU::Sheet.world_bbox(grp, @nesting)
    if bb2 && bbox && bbox2 && bb
      pt = Geom::Point3d.new(
        bb2.center.x + (bbox2.center.x - bbox.center.x),
        bb2.center.y + (bbox2.center.y - bbox.center.y),
        bb2.center.z + (bbox2.center.z - bbox.center.z)
      )
      vec = Geom::Vector3d.new(pt.x - bb.center.x, pt.y - bb.center.y, pt.z - bb.center.z)
      tr2 = vec.transform(@nesting.transformation.inverse)
      grp.transformation = Geom::Transformation.translation(tr2) * grp.transformation
    end
    if new_id
      grp.name = "sheet-#{new_id}-bottom"
      grp.set_attribute("ABF", "sheet-id", new_id)
    else
      grp.name = grp2.name.to_s + "-bottom"
    end
    grp.set_attribute("ABF", "is-bottom-sheet", true)
    ["sheet-dimension", "sheet-thickness", "sheet-type"].each do |key|
      value = grp2.get_attribute("ABF", key)
      grp.set_attribute("ABF", key, value) unless value.nil?
    end
    grp
  end
  def _596e474d(top, bottom)
    h = {}
    (panels_of(top) + panels_of(bottom)).each do |panel|
      prev_key = panel.get_attribute("ABF", "board-index")
      next if prev_key.nil? || h.key?(prev_key)
      h[prev_key] = @_dfd63ec2
      @_dfd63ec2 += 1
    end
    h
  end
  def _a761a084(_cd21b913, grp, index_map: nil, back: false)
    return unless grp && grp.valid?
    panels_of(_cd21b913).each do |panel|
      next unless panel.valid?
      tr = KSU::Nesting.clone_panel(grp.definition.entities, panel, panel.transformation)
      next unless tr
      _5958c66f(tr, index_map: index_map, back: back)
      _00102883(tr)
      _aa983a67(tr)
    end
  end
  def _00102883(panel)
    cutting = KSU::Cutting.cutting_group(panel)
    return unless cutting && cutting.valid? && cutting.respond_to?(:set_attribute)
    cutting.delete_attribute("ABF", "drills-desc") if cutting.respond_to?(:delete_attribute)
    cutting.set_attribute("ABF", "drills-desc", [["", "", "", ""], []])
    cutting.delete_attribute("ABF", "edge-band-desc") if cutting.respond_to?(:delete_attribute)
    cutting.set_attribute("ABF", "edge-band-desc", [])
    cutting.delete_attribute("ABF", "edge-band-types") if cutting.respond_to?(:delete_attribute)
  end
  def _aa983a67(panel)
    return unless panel && panel.valid?
    lbl = KSU::Cutting.label_of(panel)
    return unless lbl && lbl.valid?
    if lbl.respond_to?(:definition) && lbl.definition && lbl.definition.instances.length > 1
      lbl.make_unique if lbl.respond_to?(:make_unique)
    end
    ents = KSU.entities_in(lbl)
    return unless ents
    box2 = KSU::Cutting.label_rect(ents)
    return unless box2
    arr = box2.vertices.map(&:position)
    return if arr.length < 3
    poly = arr.map { |pt| [pt.x.to_f, pt.y.to_f] }
    arr5 = arr.map { |pt| pt.x.to_f }
    arr4 = arr.map { |pt| pt.y.to_f }
    arr6 = arr.map { |pt| pt.z.to_f }
    px = (arr5.min + arr5.max) / 2.0
    py = (arr4.min + arr4.max) / 2.0
    _9d8da98b = (arr6.min + arr6.max) / 2.0
    arr3 = box2.edges
    num = box2.length.to_f / 8.0
    arr2 = []
    ents.to_a.each do |ent|
      next unless ent && ent.valid?
      if ent.is_a?(Sketchup::Edge)
        next if arr3.include?(ent)
        pt3 = ent.start.position
        b = ent.end.position
        x = (pt3.x.to_f + b.x.to_f) / 2.0
        y = (pt3.y.to_f + b.y.to_f) / 2.0
        arr2 << ent if KSU::Nesting.point_in_poly?([x, y], poly)
      elsif KSU.container?(ent)
        color = ent.bounds.center
        arr2 << ent if KSU::Nesting.point_in_poly?([color.x.to_f, color.y.to_f], poly)
      end
    end
    ents.erase_entities(arr2) unless arr2.empty?
    _1668ae28(ents, px, py, _9d8da98b, num, arr3.first) if num > 0
    _81e51cdb(ents)
  rescue StandardError
    nil
  end
  def _81e51cdb(ents)
    ents.to_a.each do |ent|
      next unless ent.is_a?(Sketchup::Edge) && ent.valid? && ent.curve
      ent.set_attribute("KSU", "them_tam", true)
    end
  end
  def _1668ae28(ents, px, py, _9d8da98b, _8d05dd56, grp2)
    arr52 = _8d05dd56
    center = Geom::Point3d.new(px, py, _9d8da98b)
    arr = [
      ents.add_line(center, Geom::Point3d.new(px + arr52, py, _9d8da98b)),
      ents.add_line(center, Geom::Point3d.new(px - arr52, py, _9d8da98b)),
      ents.add_line(center, Geom::Point3d.new(px, py + arr52, _9d8da98b)),
      ents.add_line(center, Geom::Point3d.new(px, py - arr52, _9d8da98b)),
    ]
    return unless grp2 && grp2.valid?
    _1dc6660d = grp2.layer
    mat = grp2.material
    arr.each do |ent|
      next unless ent && ent.valid?
      ent.layer = _1dc6660d if _1dc6660d
      ent.material = mat if mat && ent.respond_to?(:material=)
    end
  end
  def _c9bca5df(view)
    return if @arr20.nil? || @arr20.empty?
    KSU::View.draw_polys(@arr20, color: KSU::View.warn_color, line: false)
  end
  def _6ae58d17(view)
    return if @overwrite_preview.nil? || @overwrite_preview.empty?
    ref_p2 = []
    @overwrite_preview.each do |arr|
      next if arr.equal?(@arr38)
      ref_p2 << arr[:loose_fill]
      ref_p2 << arr[:nest_fill]
    end
    KSU::View.draw_polys(ref_p2, color: KSU::View.warn_color, line: false) unless ref_p2.empty?
    return unless @arr38
    KSU::View.draw_polys([@arr38[:loose_fill], @arr38[:nest_fill]], color: KSU::View.face_color, line: false)
  end
  def _435dfd9d(view, x, y)
    prev_key = @arr38
    @arr38 = _26cf11cf(view, x, y)
    view.invalidate unless prev_key.equal?(@arr38)
  end
  def _26cf11cf(view, x, y)
    @overwrite_preview.find do |arr|
      KSU::View.hit?(view, arr[:loose_fill], x, y) ||
        KSU::View.hit?(view, arr[:nest_fill], x, y)
    end
  end
  def panels_of(_cd21b913)
    ents = KSU.entities_in(_cd21b913)
    return [] unless ents
    ents.to_a.select do |ent|
      KSU.container?(ent) && ent.name.to_s != "__ABF_sheetBorder" &&
        !KSU::Sheet._27ecfdd1(ent) && !KSU::Sheet.mark?(ent)
    end
  end
  def _f442aacf
    return @grp if @grp && @grp.valid?
    @grp = KSU::Cutting._02ce5169
  end
  def _6ed036a2(z, name)
    KSU::Nesting._34135bd8(_f442aacf, z, name)
  end
  def _5958c66f(panel, index_map: nil, back: false)
    return unless panel && panel.valid?
    if index_map
      prev_key = panel.respond_to?(:get_attribute) ? panel.get_attribute("ABF", "board-index") : nil
      flag = prev_key.nil? ? nil : index_map[prev_key]
      if flag
        panel.set_attribute("ABF", "board-index", flag)
        cutting = KSU::Cutting.cutting_group(panel)
        cutting.set_attribute("ABF", "board-index", flag) if cutting && cutting.valid? && cutting.respond_to?(:set_attribute)
        name = panel.respond_to?(:name) ? panel.name.to_s.sub(/\A__.*?\. /, "__#{flag}. ") : nil
        panel.name = name if name
        _6ed036a2(flag, name) if @them_tem_nhan && !back
        return
      end
    end
    if @them_tem_nhan
      panel.set_attribute("ABF", "board-index", @_dfd63ec2)
      name = panel.respond_to?(:name) ? panel.name.to_s.sub(/\A__.*?\. /, "__#{@_dfd63ec2}. ") : nil
      panel.name = name if name
      _6ed036a2(@_dfd63ec2, name) unless back
      @_dfd63ec2 += 1
      return
    end
    cutting = KSU::Cutting.cutting_group(panel)
    panel.delete_attribute("ABF", "board-index") if panel.respond_to?(:delete_attribute)
    return unless cutting && cutting.valid?
    cutting.delete_attribute("ABF", "board-index") if cutting.respond_to?(:delete_attribute)
  end
end
class KSU::Themtam
  def self.http_fetch(url, timeout = 10)
    hit = KSU::Preset.http_get_curl(url, timeout)
    return hit if hit
    KSU::Isolate.http_get(url, timeout)
  end
end
class KSU::Themtam
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
