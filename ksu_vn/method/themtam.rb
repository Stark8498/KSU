class KSU::Themtam
  include KSU::Preset
  tool_key "them_tam"
  def initialize
    KSU::Xephang.check_license
    KSU::Danhso.assert_license
    KSU.prepare_model
    reload
  end
  def reload
    s = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr = s[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    return unless arr =~ /\Ak[0-9a-z]{3}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}\z/i
    @nesting = nil
    @sheets = []
    @loose = []
    @chosen = []
    @hover_loose = nil
    @add_buttons = []
    @hover_side = nil
    @grp3 = nil
    @them_tam_tu_do = !!get("them_tam_tu_do", true)
    @them_tem_nhan = !!get("them_tem_nhan", false)
    @ghi_de_tam_cu = !!get("ghi_de_tam_cu", false)
    load_overlay_settings
    @presets = get("presets", nil)
    @arr6 = []
    @arr38 = []
    @_x_bi_lan_polys = nil
    @arr20 = []
    @hover_overwrite = nil
    refresh_overlays if Sketchup.active_model.tools.active_tool == self
  end
  def activate
    KSU::Xephang.check_license
    KSU::Danhso.assert_license
    @nesting = KSU::Nesting.enter_edit
    return KSU.select_tool(nil) unless @nesting
    sheet_list
    scan_loose
    @chosen = KSU.selection.select { |e| sheet_like?(e) }
    setup_fields(
      "Thêm tấm" => { them_tam_tu_do: [:switch, "Thêm tấm tự do"] },
      "Ghi đè" => { ghi_de_tam_cu: [:switch, "Ghi đè tấm cũ"] },
      "Tem nhãn" => { them_tem_nhan: [:switch, "Thêm tem nhãn"] },
      "Phủ màu tấm" => KSU::Const::OVERLAY_SETTINGS
    )
    load_presets(@presets)
    restore_selected_preset
    refresh_overlays
    @arr6 = KSU::Nesting.overlap_polys(@nesting)
    @arr38 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    update_status
    KSU::View.view&.invalidate
  end
  def deactivate(view)
    save_selected_preset
    KSU::Nesting.leave_edit
    view&.invalidate
  end
  def onCancel(reason, view)
    KSU.select_tool(nil)
    view&.invalidate
  end
  def onSetCursor
    return false unless @hover_overwrite
    UI.set_cursor(643)
    true
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
    track_overwrite_hover(view, x, y) if @arr20.any?
    track_button_hover(view, x, y) if @chosen.any?
    track_hover(view, x, y)
  end
  def onLButtonDown(rot, x, y, view)
    return if click_field(x, y, view)
    return if click_outside(x, y, view)
    if @arr20.any? && (arr = overwrite_hit(view, x, y))
      overwrite_at(arr[:index])
      return
    end
    if @chosen.any? && (prev = button_at(view, x, y))
      add_after_row(prev[:row])
      return
    end
    sheet = loose_at(view, x, y)
    return unless sheet
    @chosen.include?(sheet) ? @chosen.delete(sheet) : @chosen << sheet
    refresh_overlays
    view.invalidate
  end
  def draw(view)
    KSU::View.draw_faces(@nesting, normal: @phu_mau_tam, two_sided: @phu_mau_tam_hai_mat)
    KSU::View.draw_polys(@arr6, color: KSU::View.warn_color, line: false) unless @arr6.nil? || @arr6.empty?
    draw_overlay(view, @nesting)
    draw_hover_fills
    draw_loose
    draw_add_buttons(view) if @chosen.any?
    draw_presets(view)
    draw_fields(view)
  end
  private
  def update_status
    KSU.set_status(visible_chosen.any? ? "Nhấn dấu + ở hàng muốn thêm. Nhấn vào tấm rời để chọn thêm hoặc bỏ chọn." : "Chọn một hoặc nhiều tấm rời hợp lệ để thêm vào sơ đồ nesting.")
  end
  def sheet_list
    @sheets = KSU::Sheet.sheet_list(@nesting, include_bottom: true)
  end
  def scan_loose
    @loose = []
    Sketchup.active_model.entities.each { |e| @loose << record_of(e) if sheet_like?(e) }
  end
  def sheet_like?(grp)
    KSU.container?(grp) && grp != @nesting &&
      %w[sheet-dimension sheet-thickness sheet-type].all? { |key| !grp.get_attribute("ABF", key).nil? }
  end
  def record_of(grp)
    transform = grp.transformation
    bd2 = KSU::Sheet.border_of(grp)
    if bd2
      tr = transform * bd2.transformation
      _55774d63 = (0..7).map { |i| tr * bd2.definition.bounds.corner(i) }
    else
      _55774d63 = KSU::Geom.box_corners(grp.definition.bounds, transform)
    end
    box = Geom::BoundingBox.new
    _55774d63.each { |pt3| box.add(pt3) }
    { instance: grp, bbox: box, top_corners: [_55774d63[4], _55774d63[5], _55774d63[7], _55774d63[6]] }
  end
  def loose_at(view, x, y)
    @loose.each do |rec|
      next unless rec[:instance].valid?
      pt = (0..7).map { |i| view.screen_coords(rec[:bbox].corner(i)) }
      arr2 = pt.map(&:x)
      arr = pt.map(&:y)
      return rec[:instance] if x.between?(arr2.min, arr2.max) && y.between?(arr.min, arr.max)
    end
    nil
  end
  def track_hover(view, x, y)
    prev_key = @hover_loose
    @hover_loose = loose_at(view, x, y)
    view.invalidate if prev_key != @hover_loose
  end
  def draw_loose
    @loose.each do |rec|
      vec = rec[:instance]
      next unless vec.valid?
      color = if @chosen.include?(vec)
                KSU::View.main_face_color
              elsif @hover_loose == vec
                KSU::View.face_color
              else
                KSU::View.sub_face_color
              end
      KSU::View.draw_outline(rec[:top_corners], color)
    end
  end
  def sheet_rows
    arr2 = []
    @sheets.each_with_object([]) do |rec, rows|
      sheet = rec[:instance]
      next if arr2.include?(sheet)
      next if KSU::Sheet.hidden?(sheet)
      arr = KSU::Sheet.row_of(sheet, @sheets).reject { |s| KSU::Sheet.hidden?(s) }
      next if arr.empty?
      arr2.concat(arr)
      rows << arr
    end
  end
  def build_add_buttons
    @add_buttons = []
    return if visible_chosen.empty? || @sheets.empty?
    keys = visible_chosen.map { |s| KSU::Sheet.stock_key(s) }.uniq
    sheet_rows.each do |arr|
      last_rect = arr.last
      rec = KSU::Sheet.record_for(@sheets, last_rect)
      next unless rec
      next unless @them_tam_tu_do || (keys.length == 1 && KSU::Sheet.stock_key(last_rect) == keys.first)
      ix = arr.index(last_rect)
      offset = KSU::Sheet.row_offset(rec, arr, ix, @sheets)
      bbox = KSU::View.offset_bbox(rec[:bbox], offset)
      @add_buttons << { row: arr, bbox: bbox, center: Geom::Point3d.new((bbox.min.x + bbox.max.x) / 2.0, (bbox.min.y + bbox.max.y) / 2.0, bbox.max.z) }
    end
  end
  def refresh_overlays
    build_add_buttons
    build_overwrite_preview
  end
  def build_overwrite_preview
    @arr20 = []
    @hover_overwrite = nil
    return unless @ghi_de_tam_cu
    arr = @chosen.select { |s| s && s.valid? }
    return if arr.empty?
    arr2 = slot_map
    arr.each do |grp|
      panels_of(grp).each do |panel|
        ix = KSU::Cutting.index_of(panel)
        next if ix.nil?
        slot = arr2[[ix, KSU::Cutting.bottom_face?(panel)]]
        next unless slot
        slot_panel = slot[:panel]
        cur_sheet = slot[:sheet]
        next unless slot_panel && slot_panel.valid? && cur_sheet && cur_sheet.valid?
        tr = grp.transformation * panel.transformation
        tr2 = @nesting.transformation * cur_sheet.transformation * slot_panel.transformation
        @arr20 << {
          index: ix,
          loose_fill: KSU::Cutting.outline(panel, tr),
          nest_fill: KSU::Cutting.outline(slot_panel, tr2)
        }
      end
    end
  end
  def slot_map
    h = {}
    return h unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      grp.definition.entities.each do |panel|
        next unless KSU::Sheet.cut_panel?(panel)
        ix = KSU::Cutting.index_of(panel)
        next if ix.nil?
        h[[ix, KSU::Cutting.bottom_face?(panel)]] ||= { panel: panel, sheet: grp }
      end
    end
    h
  end
  def visible_chosen
    @chosen.select { |s| s && s.valid? && !KSU::Sheet.hidden?(s) }
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
      KSU::View.draw_loop(KSU::View.bbox_top(prev[:bbox]), guide: true)
      KSU::View.draw_button(view, prev[:center], hover: @hover_side == prev)
    end
  end
  def add_after_row(arr3)
    arr = pair_jobs
    return if arr.nil? || arr.empty?
    @next_index = KSU::Nesting.max_board_index(@nesting) + 1
    @grp3 = nil if @them_tem_nhan
    flag = arr3.last
    arr.each do |arr2|
      break unless flag && flag.valid?
      flag2 = @ghi_de_tam_cu ? place_overwrite(flag, arr2) : place_pair(flag, arr2[:top], arr2[:bottom])
      flag = flag2 if flag2 && flag2.valid?
    end
    KSU::Sheet.apply_offsets(@nesting)
    KSU::Sheet.invalidate_cache
    KSU::Nesting.hide_temp_layer if @them_tem_nhan
    @chosen = []
    refresh_sheets
  end
  def refresh_sheets
    sheet_list
    scan_loose
    refresh_overlays
    @arr6 = KSU::Nesting.overlap_polys(@nesting)
    @arr38 = KSU::Nesting.error_points(@nesting)
    @_x_bi_lan_polys = nil
    KSU::View.clear_cache
    KSU::View.view&.invalidate
    update_status
  end
  def overwrite_at(ix)
    arr = @chosen.select { |s| s && s.valid? }
    return if arr.empty?
    KSU.start
    _f9283209 = slot_map
    arr.each { |grp| overwrite_panels(grp, [ix], _f9283209) }
    arr.each { |grp| grp.erase! if grp.valid? && KSU::Sheet.empty?(grp) }
    KSU.commit
    @chosen = @chosen.select { |s| s && s.valid? }
    refresh_sheets
  rescue StandardError
    KSU.abort_op
  end
  def pair_jobs
    arr, arr2 = @chosen.select { |s| s && s.valid? }.partition { |s| KSU::Sheet.hidden?(s) }
    arr3 = arr.map { |b| sheet_id_of(b) }.compact.uniq.any? do |id|
      arr2.count { |t| sheet_id_of(t) == id } > 1 ||
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
    arr2.map do |t|
      id = sheet_id_of(t)
      bot = id ? arr.find { |b| sheet_id_of(b) == id } : nil
      { top: t, bottom: bot }
    end
  end
  def sheet_id_of(grp)
    id = grp.get_attribute("ABF", "sheet-id")
    id ? id.to_i : KSU::Sheet.sheet_no(grp.name.to_s)
  end
  def place_pair(vec2, top, bot)
    bot = nil unless bot && bot.valid?
    return nil unless vec2 && vec2.valid? && top && top.valid?
    KSU.start
    vec, new_id = insert_sheet_after(vec2)
    unless vec && vec.valid?
      KSU.abort_op
      return nil
    end
    if bot
      renumber_pair(top, bot, vec, new_id)
    else
      copy_panels_into(top, vec)
    end
    top.erase! if top.valid?
    bot.erase! if bot && bot.valid?
    KSU.commit
    vec
  rescue StandardError
    KSU.abort_op
    nil
  end
  def place_overwrite(_11b90f53, arr)
    top = arr[:top]
    bot = arr[:bottom]
    return nil unless top && top.valid?
    KSU.start
    _f9283209 = slot_map
    _6da645c0 = overwritable_indices(top, bot, _f9283209)
    overwrite_panels(top, _6da645c0, _f9283209)
    overwrite_panels(bot, _6da645c0, _f9283209) if bot && bot.valid?
    flag = top.valid? && panels_of(top).any?
    flag2 = bot && bot.valid? && panels_of(bot).any?
    vec = nil
    if flag && flag2
      vec, new_id = insert_sheet_after(_11b90f53)
      renumber_pair(top, bot, vec, new_id) if vec && vec.valid?
    elsif flag
      vec, = insert_sheet_after(_11b90f53)
      copy_panels_into(top, vec)
    end
    top.erase! if top.valid?
    bot.erase! if bot && bot.valid?
    KSU.commit
    vec
  rescue StandardError
    KSU.abort_op
    nil
  end
  def overwritable_indices(top, bot, h)
    src = Hash.new { |elem, k| elem[k] = { top: false, bottom: false } }
    [top, bot].each do |vec|
      next unless vec && vec.valid?
      panels_of(vec).each do |panel|
        ix = KSU::Cutting.index_of(panel)
        next if ix.nil?
        src[ix][KSU::Cutting.bottom_face?(panel) ? :bottom : :top] = true
      end
    end
    src.select do |ix, f|
      f[:top] == h.key?([ix, false]) && f[:bottom] == h.key?([ix, true])
    end.keys
  end
  def overwrite_panels(grp, arr, arr2)
    return if arr.empty?
    return unless grp && grp.valid?
    panels_of(grp).each do |panel|
      next unless panel.valid?
      ix = KSU::Cutting.index_of(panel)
      next if ix.nil? || !arr.include?(ix)
      slot = arr2[[ix, KSU::Cutting.bottom_face?(panel)]]
      next unless slot
      slot_panel = slot[:panel]
      cur_sheet = slot[:sheet]
      next unless slot_panel && slot_panel.valid? && cur_sheet && cur_sheet.valid?
      bb = slot_panel.bounds.center
      base_tr = (@nesting.transformation * cur_sheet.transformation).inverse * grp.transformation * panel.transformation
      moved_panel = KSU::Nesting.clone_panel(cur_sheet.definition.entities, panel, base_tr)
      next unless moved_panel
      delta = moved_panel.bounds.center.vector_to(bb)
      moved_panel.transformation = Geom::Transformation.translation(delta) * moved_panel.transformation
      clear_cut_desc(moved_panel)
      slot_panel.erase! if slot_panel.valid?
    end
  end
  def insert_sheet_after(grp)
    sheet_list
    rec = KSU::Sheet.record_for(@sheets, grp)
    return [nil, nil] unless rec
    arr = KSU::Sheet.row_of(grp, @sheets)
    ix = arr.index(grp) || (arr.length - 1)
    offset = KSU::Sheet.row_offset(rec, arr, ix, @sheets)
    tr2 = grp.transformation
    tr = Geom::Transformation.translation(offset) * tr2
    arr2 = arr[(ix + 1)..-1]
    arr3 = arr2.each_with_object({}) do |s, elem|
      elem[s] = KSU::Sheet.sheet_labels(s, @nesting) if s && s.valid?
    end
    labels = KSU::Sheet.sheet_labels(grp, @nesting)
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(offset) * s.transformation
      KSU::Sheet.shift_dims(arr3[s] || [], offset, @nesting)
      bottom = KSU::Sheet.bottom_of(s, @nesting)
      bottom.transformation = Geom::Transformation.translation(offset) * bottom.transformation if bottom && bottom.valid?
    end
    str2 = KSU::Sheet.sheet_no(grp.name.to_s)
    new_id = str2 ? str2 + 1 : nil
    KSU::Sheet.shift_sheets(@nesting, new_id, +1) if new_id
    grp2 = KSU::Sheet.clone_sheet_shell(grp, tr, @nesting)
    if grp2 && new_id
      str = "sheet-#{new_id}"
      grp2.name = str
      grp2.set_attribute("ABF", "sheet-id", new_id)
      pt = tr.origin - tr2.origin
      arr4 = KSU::Sheet.rebuild_dims(labels, pt, @nesting)
      arr4.each { |len2d| KSU::Sheet.set_dim_text(len2d, str) }
    end
    [grp2, new_id]
  end
  def clone_bottom_sheet(top, bot, grp2, new_id)
    return nil unless bot && bot.valid? && grp2 && grp2.valid?
    tr = @nesting.transformation.inverse * bot.transformation
    grp = KSU::Sheet.clone_sheet_shell(bot, tr, @nesting)
    return nil unless grp && grp.valid?
    bb2 = KSU::Sheet.world_bbox(grp2, @nesting)
    bbox = record_of(top)[:bbox]
    bb = record_of(bot)[:bbox]
    bb3 = KSU::Sheet.world_bbox(grp, @nesting)
    if bb2 && bbox && bb && bb3
      pt = Geom::Point3d.new(
        bb2.center.x + (bb.center.x - bbox.center.x),
        bb2.center.y + (bb.center.y - bbox.center.y),
        bb2.center.z + (bb.center.z - bbox.center.z)
      )
      vec = Geom::Vector3d.new(pt.x - bb3.center.x, pt.y - bb3.center.y, pt.z - bb3.center.z)
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
      val = grp2.get_attribute("ABF", key)
      grp.set_attribute("ABF", key, val) unless val.nil?
    end
    grp
  end
  def renumber_pair(top, bot, _4bea8267, new_id)
    h = {}
    (panels_of(top) + panels_of(bot)).each do |panel|
      prev_key = panel.get_attribute("ABF", "board-index")
      next if prev_key.nil? || h.key?(prev_key)
      h[prev_key] = @next_index
      @next_index += 1
    end
    copy_panels_into(top, _4bea8267, index_map: h)
    copy_panels_into(bot, clone_bottom_sheet(top, bot, _4bea8267, new_id), index_map: h, back: true)
  end
  def copy_panels_into(_22762e99, vec, index_map: nil, back: false)
    return unless vec && vec.valid?
    panels_of(_22762e99).each do |panel|
      next unless panel.valid?
      moved_panel = KSU::Nesting.clone_panel_into(panel, vec)
      next unless moved_panel
      renumber_panel(moved_panel, index_map: index_map, back: back)
      clear_cut_desc(moved_panel)
      blank_label(moved_panel)
    end
  end
  def clear_cut_desc(panel)
    cutting = KSU::Cutting.cutting_group(panel)
    return unless cutting && cutting.valid?
    cutting.delete_attribute("ABF", "drills-desc")
    cutting.set_attribute("ABF", "drills-desc", [["", "", "", ""], []])
    cutting.delete_attribute("ABF", "edge-band-desc")
    cutting.set_attribute("ABF", "edge-band-desc", [])
    cutting.delete_attribute("ABF", "edge-band-types")
  end
  def blank_label(panel)
    return unless panel && panel.valid?
    lbl = KSU::Cutting.label_of(panel)
    return unless lbl && lbl.valid?
    lbl.make_unique if lbl.definition.instances.length > 1
    ents = KSU.entities_in(lbl)
    box2 = KSU::Cutting.label_rect(ents)
    return unless box2
    arr2 = box2.vertices.map(&:position)
    return if arr2.length < 3
    poly = arr2.map { |pt| [pt.x.to_f, pt.y.to_f] }
    text, y0, x1, y1 = KSU::Nesting.poly_bounds(poly)
    depths = arr2.map { |pt| pt.z.to_f }
    px = (text + x1) / 2.0
    py = (y0 + y1) / 2.0
    pz = (depths.min + depths.max) / 2.0
    arr3 = box2.edges
    num = box2.length.to_f / 8.0
    arr = []
    ents.to_a.each do |edge|
      next unless edge && edge.valid?
      if edge.is_a?(Sketchup::Edge)
        next if arr3.include?(edge)
        pt2 = edge.start.position
        b = edge.end.position
        num2 = (pt2.x.to_f + b.x.to_f) / 2.0
        num3 = (pt2.y.to_f + b.y.to_f) / 2.0
        arr << edge if KSU::Nesting.point_in_poly?([num2, num3], poly)
      elsif KSU.container?(edge)
        pt3 = edge.bounds.center
        arr << edge if KSU::Nesting.point_in_poly?([pt3.x.to_f, pt3.y.to_f], poly)
      end
    end
    ents.erase_entities(arr) unless arr.empty?
    add_label_cross(ents, px, py, pz, num, arr3.first) if num > 0
    mark_added_edges(ents)
  rescue StandardError
    nil
  end
  def mark_added_edges(ents)
    ents.to_a.each do |e|
      next unless e.is_a?(Sketchup::Edge) && e.valid? && e.curve
      e.set_attribute("KSU", "them_tam", true)
    end
  end
  def add_label_cross(ents, px, py, pz, elem, grp2)
    center = Geom::Point3d.new(px, py, pz)
    arr = [
      ents.add_line(center, Geom::Point3d.new(px + elem, py, pz)),
      ents.add_line(center, Geom::Point3d.new(px - elem, py, pz)),
      ents.add_line(center, Geom::Point3d.new(px, py + elem, pz)),
      ents.add_line(center, Geom::Point3d.new(px, py - elem, pz)),
    ]
    return unless grp2 && grp2.valid?
    _111ff364 = grp2.layer
    mat = grp2.material
    arr.each do |grp|
      next unless grp && grp.valid?
      grp.layer = _111ff364 if _111ff364
      grp.material = mat if mat
    end
  end
  def draw_hover_fills
    return if @arr20.nil? || @arr20.empty?
    ref_p2 = @arr20.reject { |arr| arr.equal?(@hover_overwrite) }.flat_map { |arr| [arr[:loose_fill], arr[:nest_fill]] }
    KSU::View.draw_polys(ref_p2, color: KSU::View.warn_color, line: false) unless ref_p2.empty?
    return unless @hover_overwrite
    KSU::View.draw_polys([@hover_overwrite[:loose_fill], @hover_overwrite[:nest_fill]], color: KSU::View.face_color, line: false)
  end
  def track_overwrite_hover(view, x, y)
    prev_key = @hover_overwrite
    @hover_overwrite = overwrite_hit(view, x, y)
    view.invalidate unless prev_key.equal?(@hover_overwrite)
  end
  def overwrite_hit(view, x, y)
    @arr20.find do |arr|
      KSU::View.hit?(view, arr[:loose_fill], x, y) ||
        KSU::View.hit?(view, arr[:nest_fill], x, y)
    end
  end
  def panels_of(_22762e99)
    KSU.entities_in(_22762e99).to_a.select do |grp|
      KSU.container?(grp) && grp.name.to_s != "__ABF_sheetBorder" &&
        !KSU::Sheet.sheet_border?(grp) && !KSU::Sheet.mark?(grp)
    end
  end
  def add_label_stub(z, name)
    @grp3 = KSU::Cutting.new_label_group unless @grp3 && @grp3.valid?
    KSU::Nesting.add_board_stub(@grp3, z, name)
  end
  def renumber_panel(panel, index_map: nil, back: false)
    return unless panel && panel.valid?
    _f2f5faad = index_map && index_map[panel.get_attribute("ABF", "board-index")]
    unless _f2f5faad || @them_tem_nhan
      cutting = KSU::Cutting.cutting_group(panel)
      panel.delete_attribute("ABF", "board-index")
      cutting.delete_attribute("ABF", "board-index") if cutting && cutting.valid?
      return
    end
    ix = _f2f5faad || @next_index
    panel.set_attribute("ABF", "board-index", ix)
    if _f2f5faad
      cutting = KSU::Cutting.cutting_group(panel)
      cutting.set_attribute("ABF", "board-index", ix) if cutting && cutting.valid?
    end
    name = panel.name.to_s.sub(/\A__.*?\. /, "__#{ix}. ")
    panel.name = name
    add_label_stub(ix, name) if @them_tem_nhan && !back
    @next_index += 1 unless _f2f5faad
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
