module KSU::Launch
  def handle_action(dlg, action, payload)
    case action
    when "load_data", "reload_data"
      Sketchup.add_observer(@observer = KSU::Nest::ModelWatch.new) unless @observer
      return if labelling
      @sel_snapshot = KSU.selection
      send_materials(dlg, material_rows(@sel_snapshot))
    when "save_setting" then apply_override(payload, "nesting")
    when "save_rows" then apply_saved_cfg(payload)
    when "select_parts" then select_ids(payload)
    when "search_parts" then parse_keywords(payload)
    when "sync_parts" then send_state(dlg)
    when "load_layout" then parse_thickness(dlg)
    when "engine_cb" then KSU::Nesting::Engine.instance.on_engine_message(payload)
    when "nest_run"
      snap = @sel_snapshot
      UI.start_timer(0, false) { start_labelling(parse_keyed_rows(payload), snap) }
    end
  end
  def apply_saved_cfg(payload)
    str = JSON.parse(payload.to_s) rescue nil
    prev_key = JSON.parse(KSU::Settings.get("cau_hinh_vat_lieu", "", "nesting")) rescue nil
    if str.is_a?(Hash) && prev_key.is_a?(Hash)
      layers = ->(elem) { elem.keys.select { |k| elem[k].is_a?(Array) && elem[k][1].is_a?(Numeric) }.sort_by.with_index { |k, i| [elem[k][1], i] } }
      fill = layers.(str)
      keys = layers.(prev_key).map { |k| str.key?(k) ? fill.shift : k }.compact + fill
      arr = prev_key.merge(str)
      keys.each_with_index { |k, i| arr[k] = arr[k].dup.tap { |arr2| arr2[1] = i } }
      payload = JSON.generate(arr)
    end
    KSU::Settings.set("cau_hinh_vat_lieu", payload.to_s, "nesting")
  end
  def apply_override(payload, _c2a4afd5)
    str, v = payload.to_s.split("@", 2)
    return if str.to_s.empty?
    flag = KSU::Preset.global_key?(str) ? "cai_dat" : _c2a4afd5
    KSU::Settings.set(str, KSU::Settings.parse_value(v), flag)
    return flag unless flag == "cai_dat"
    KSU::Preset.load_cfg
    tool = Sketchup.active_model.tools.active_tool
    tool.reload_settings if tool.respond_to?(:reload_settings) && !tool.is_a?(KSU::Nest::Progress)
    KSU::View.refresh
  end
  def send_materials(dlg, materials)
    arr = KSU::Settings.load
    _ee07a6d0 = lambda do |k, len2d, _315c2e0c|
      elem = arr[_315c2e0c]
      elem.is_a?(Hash) && elem.key?(k) ? KSU::Settings.coerce(elem[k], len2d) : KSU::Settings.get(k, len2d, _315c2e0c)
    end
    mm = _ee07a6d0.call("tam_cach_le_rieng", 3.5, "nesting")
    defs = { "bo_qua_doi_tuong_an" => true, "tam_cach_nhau_rieng" => 6.5, "tam_cach_le_rieng" => mm,
                "tach_cach_le_rieng" => false, "chieu_rong_van" => 1220.0, "chieu_dai_van" => 2440.0,
                "tu_dong_hau_ky" => true, "goc_don_van" => "trai_duoi", "thu_tu_don" => "mac_dinh",
                "tach_nhom_2_mat" => true, "ghep_cap_toi_uu" => true, "nhom_cap_am_duong" => false,
                "sap_xep_danh_sach" => "mac_dinh" }
    KSU::Store::MARGIN_SIDES.each_key { |s| defs["tam_cach_le_#{s}_rieng"] = mm }
    settings = defs.to_h do |k, len2d|
      next [k, len2d] if k == "tam_cach_le_rieng"
      v = _ee07a6d0.call(k, len2d, "nesting")
      [k, [true, false].include?(len2d) ? !!v : v]
    end
    settings["thong_bao_mo"] = !!_ee07a6d0.call("thong_bao_mo", false, "cai_dat")
    partner = KSU::Nesting.find_nesting(notify: false)
    KSU::Settings.send_to_dialog(dlg, "nesting", "nestingLoad", { settings: settings, materials: materials, has_nesting: !!(partner && partner.valid?), notes: @arr31 || [] }.to_json)
  end
  def parse_thickness(dlg)
    return if labelling
    KSU::Settings.send_to_dialog(dlg, "nesting", "nestingLayout", { layout: active_nesting }.to_json)
  end
  def active_nesting
    nesting = KSU::Nesting.find_nesting(notify: false)
    return nil unless nesting && nesting.valid?
    h5 = {}
    groups = KSU::Sheet.sheet_maps(nesting).flat_map { |arr| arr.sort_by { |id, _| id.to_i }.map(&:last) }
    sheets = groups.select(&:valid?).map { |gr| group_shapes(gr, nesting.transformation, h5) }
    { sheets: sheets, layers: h5.keys, colors: parse_rows(h5.keys) }.merge(nesting_payload(nesting))
  rescue StandardError
    nil
  end
  def group_shapes(gr, _ebfef7c4, h5)
    tr = _ebfef7c4 * gr.transformation
    pt = lambda { |arr2| arr2.map { |x, y| pt2 = Geom::Point3d.new(x, y, 0).transform(tr); [(pt2.x.to_f * 25.4).round(2), (pt2.y.to_f * 25.4).round(2)] } }
    ents = KSU::Giacong.sheet_entities(gr)
    bd2 = ents.find { |arr| arr[:border] }
    ent2 = gr.get_attribute("ABF", "sheet-dimension", [1220, 2440])
    w, elem = ent2[0].to_f / 25.4, ent2[1].to_f / 25.4
    sheet_type = gr.get_attribute("ABF", "sheet-type").to_s
    mat = gr.get_attribute("KSU", "sheet-material").to_s
    lines = ents.filter_map do |arr|
      str = arr[:layer].to_s
      next if arr[:border] || KSU::Giacong.info_layer?(str)
      [arr[:closed] ? 1 : 0, h5[str] ||= h5.length, pt.call(arr[:pts])]
    end
    { id: gr.get_attribute("ABF", "sheet-id"), key: sheet_type.empty? ? mat : sheet_type, bottom: KSU::Sheet.hidden?(gr),
      paper: pt.call(bd2 ? bd2[:pts] : [[0, 0], [w, 0], [w, elem], [0, elem]]), lines: lines }
  end
  def parse_rows(side_names)
    arr = ((KSU::Cnc::Library.config_copy["layer_colors"] rescue nil) || {}).merge(KSU::Cnc::Library.default_layer_colors)
    meta = { model: Sketchup.active_model, colors: {} }
    side_names.map { |name| arr[name].to_s.empty? ? KSU::Cnc::Canvas.layer_color(name, meta) : arr[name].to_s }
  end
  def pts(out)
    out.map { |pt| [(pt.x.to_f * 25.4).round(2), (pt.y.to_f * 25.4).round(2)] }
  end
  def alpha_of(color)
    num = color.alpha
    num = num > 1 ? num / 255.0 : num.to_f
    format("rgba(%d,%d,%d,%.3f)", color.red, color.green, color.blue, num)
  end
  def panel_payload(panels, arr2)
    panels.map do |arr|
      { pts: pts(arr[:polygon]), holes: (arr[:holes] || []).map { |elem| pts(elem) }, id: part_id(arr[:entity]),
        two: arr[:back] || (!arr[:board_index].nil? && !!arr2[arr[:board_index]]),
        group: !!arr[:entity].get_attribute("KSU", "group-id") }
    end
  end
  def tones
    { normal: KSU::View.panel_normal_color, group: KSU::View.panel_group_color, two: KSU::View.panel_two_color,
      warn_face: KSU::View.warn_color, warn: KSU::View.warning_color }.transform_values { |c| alpha_of(c) }
  rescue StandardError
    {}
  end
  def nesting_payload(nesting)
    _af31a278 = panel_payload(KSU::Nesting.panel_list(nesting), KSU::Nesting.two_sided_set(nesting))
    error_text = begin
      pts(KSU::Nesting.error_points(nesting))
    rescue StandardError
      []
    end
    _2fde9bd2 = begin
      plan_parts(nesting).map { |f| { pts: pts(f[:outer]), holes: (f[:holes] || []).map { |elem| pts(elem) } } }
    rescue StandardError
      []
    end
    { fills: _af31a278, loi: error_text, lan: _2fde9bd2, tones: tones }
  rescue StandardError
    { fills: [], loi: [], lan: [], tones: {} }
  end
  def entity_label(entity)
    name = entity.respond_to?(:name) ? entity.name.to_s.strip : ""
    return name unless name.empty?
    entity.respond_to?(:definition) && entity.definition ? entity.definition.name.to_s.strip : ""
  end
  def group_by_label(nesting)
    h2 = Hash.new { |elem, k| elem[k] = [] }
    h = Hash.new { |elem, k| elem[k] = [] }
    queue = Sketchup.active_model.entities.to_a.map { |grp| [grp, 0] }
    until queue.empty?
      grp, depth = queue.shift
      next unless KSU.container?(grp) && grp.valid? && grp != nesting
      name = entity_label(grp)
      next if name == "__ABF_Nesting" || grp.get_attribute("ABF", "is-nesting-root")
      ix = grp.get_attribute("ABF", "board-index")
      h[name] << grp if (depth.zero? || !ix.nil?) && !name.empty?
      h2[ix.to_i] << grp unless ix.nil?
      next unless ix.nil?
      (KSU.entities_in(grp) || []).each { |c| queue << [c, depth + 1] if KSU.container?(c) }
    end
    [h2, h]
  end
  def send_state(dlg)
    nesting = KSU::Nesting.find_nesting(notify: false) unless labelling
    unless nesting && nesting.valid?
      send_materials(dlg, material_rows(@sel_snapshot)) unless labelling
      return KSU::Settings.send_to_dialog(dlg, "nesting", "nestingSynced", {}.to_json)
    end
    @arr31 = []
    arr2, arr = group_by_label(nesting)
    done, arr28, fail = 0, [], []
    KSU.start(false)
    nesting.definition.entities.to_a.each do |sheet|
      next unless KSU::Sheet.sheet?(sheet) && !KSU::Sheet.bottom_sheet?(sheet)
      (KSU.entities_in(sheet) || []).to_a.each do |panel|
        next unless KSU::Sheet.part_group?(panel) && !KSU::Cutting.bottom_face?(panel)
        name = entity_label(panel)
        ix = panel.get_attribute("ABF", "board-index")
        lbl = part_id(panel)
        num = (ix.nil? ? [] : arr2[ix.to_i]).find { |vec| vec.valid? && vec != panel }
        num ||= arr[name].find { |vec| vec.valid? && vec != panel } unless name.empty?
        next arr28 << lbl unless num
        KSU::Cutting.build_panel(panel, num, nesting) ? done += 1 : fail << lbl
      end
    end
    KSU.commit
    KSU::View.clear_cache
    Sketchup.active_model.active_view.invalidate
    notify("Đã đồng bộ #{done} chi tiết vào sơ đồ.") if done > 0
    notify("Không tìm thấy model thực tế của tấm #{tail_pt(arr28)}.", arr28) unless arr28.empty?
    notify("Có vấn đề khi đọc dữ liệu tấm #{tail_pt(fail)}.", fail) unless fail.empty?
    part_ids_of(nesting)
    send_materials(dlg, material_rows(@sel_snapshot))
    KSU::Settings.send_to_dialog(dlg, "nesting", "nestingSynced", {}.to_json)
  rescue StandardError => vec
    KSU.abort_op
    notify("Lỗi: #{vec.message}")
    KSU::Settings.send_to_dialog(dlg, "nesting", "nestingSynced", {}.to_json)
  end
  def material_rows(saved_sel)
    h = {}
    model = collect_parts(saved_sel.empty? ? Sketchup.active_model.entities : saved_sel, [], h).each_with_object({}) do |grp, by2|
      mat, thickness_mm = sheet_type = part_from_face(grp, h[grp.entityID], false)
      next unless sheet_type.is_a?(Array)
      key = "#{mat}#{thickness_mm}"
      half = (by2[key] ||= { key: key, material: mat, thickness_mm: thickness_mm, eids: [], dims: [] })
      half[:eids] << grp.entityID
      half[:dims] << start_from_dialog(grp, h[grp.entityID])
    end
    material_orders(fill_sizes(model.values))
  end
  def start_from_dialog(grp, _5a718701)
    tf, b2 = _5a718701
    n = b2[0].normal.transform(tf)
    arr = KSU::Cutting.kids_with_attr(grp, "is-label")
    if arr
      _71fbc725 = arr[0].transformation.xaxis.transform(tf)
    else
      _71fbc725 = KSU::Label.face_axes(b2[0], tf)[:line_vec]
      _71fbc725 = _71fbc725.cross(n) if [90, 270].include?(grp.get_attribute("ABF", "label-rotation").to_i)
    end
    pt = b2[0].outer_loop.vertices.map { |v| v.position.transform(tf) }
    [_71fbc725.cross(n), _71fbc725].map { |len2d| (KSU::Thongke::Quet.long_axis(pt, len2d) * 25.4).round(1) } << grp.name.to_s.downcase
  rescue StandardError
    [0.0, 0.0, grp.name.to_s.downcase]
  end
  def material_orders(rows)
    arr2 = JSON.parse(KSU::Settings.get("cau_hinh_vat_lieu", "", "nesting")) rescue {}
    orders = rows.each_with_index.map do |half, n|
      arr = arr2[half[:key]] if arr2.is_a?(Hash)
      arr = [] unless arr.is_a?(Array)
      half.merge!(ord: n, on: arr[0] != false, rot: arr[2] == true, kw: arr[3].is_a?(String) ? arr[3] : "")
      arr[1] if arr[1].is_a?(Numeric)
    end
    rows.replace(rows.sort_by.with_index { |_item, i| [orders[i] ? 0 : 1, orders[i].to_f, i] })
  end
  def parse_keywords(str)
    arr = str.to_s.split(/[,\n]/).map { |t| t.strip.downcase }.reject(&:empty?)
    return if arr.empty?
    arr3, arr2 = arr.partition { |t| t =~ /\A\d+\z/ }
    KSU.select_only(collect_parts(Sketchup.active_model.entities).select do |grp|
      next true if !arr3.empty? && arr3.include?(grp.get_attribute("ABF", "board-index").to_s)
      next false if arr2.empty?
      name = grp.name.to_s.downcase
      mat = grp.material&.name.to_s.downcase
      arr2.any? { |kw| name.include?(kw) || mat.include?(kw) }
    end)
    KSU::View.view.invalidate
  rescue StandardError
  end
  def select_ids(resp)
    str = JSON.parse(resp.to_s)
    return unless str.is_a?(Array) && !str.empty?
    KSU.select_only(Array(Sketchup.active_model.find_entity_by_id(*str.map(&:to_i))).compact.select(&:valid?))
    KSU::View.view.invalidate
  rescue StandardError
  end
  def parse_keyed_rows(resp)
    str = JSON.parse(resp.to_s) rescue []
    str.is_a?(Array) ? str.select { |half| half.is_a?(Hash) && !half["key"].to_s.empty? } : []
  end
  def start_labelling(rows, saved_sel)
    return if labelling
    @arr31 = []
    KSU.select_only([])
    job_cfg = job_settings
    unless rows.empty?
      materials, mat_order, rotate_cfg, arr = %i[materials mat_order rotate_cfg rotate_by_name].map { |str| job_cfg[str] = {} }
      rows.each_with_index do |half, i2|
        str = half["key"].to_s
        materials[str] = true if half["on"]
        mat_order[str] = i2
        rotate_cfg[str] = arr[half["name"].to_s] = { on: half["rot"] == true, kw: half["kw"].to_s }
      end
    end
    m_left, m_right, top, m_bottom = margins_of(job_cfg)
    return if job_cfg[:sheet_w] - m_left - m_right <= 0 || job_cfg[:sheet_h] - top - m_bottom <= 0
    Sketchup.active_model.then { |meta| meta.close_active while meta.active_path } rescue nil
    Sketchup.active_model.select_tool(nil) if Sketchup.active_model.tools.active_tool
    KSU.start_batch
    relabel_nesting
    start_collect(job_cfg, true, saved_sel)
  rescue StandardError => e
    one_group(e)
  end
end
KSU::Nest.extend(KSU::Launch)
