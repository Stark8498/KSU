module KSU::Launch
  def handle_action(dlg, action, id)
    case action
    when "load_data", "reload_data"
      @_93d34efc = KSU.selection
      _31540a9a(dlg, _d1ef9374(@_93d34efc))
    when "save_setting"
      k, v = id.to_s.split("@", 2)
      return if k.to_s.empty?
      flag = KSU::Preset.global_key?(k) ? "cai_dat" : "nesting"
      KSU::Settings.set(k, KSU::Settings.parse_value(v), flag)
      if flag == "cai_dat"
        KSU::Preset.load_cfg
        if KSU::Preset.global_key?(k)
          tool = Sketchup.active_model.tools.active_tool
          tool.reload_settings if tool.respond_to?(:reload_settings)
        end
        KSU::View.refresh
      end
    when "save_rows"
      KSU::Settings.set("cau_hinh_vat_lieu", id.to_s, "nesting")
    when "select_parts"
      _1582b880(id)
    when "search_parts"
      _e3264765(id)
    when "nest_run"
      rows = _e534023c(id)
      _797647b5 = @_93d34efc
      dlg.close if dlg
      UI.start_timer(0, false) { _f75e3e4f(rows, _797647b5) }
    end
  end
  def _31540a9a(dlg, materials)
    settings = {
      "chieu_rong_van" => KSU::Settings.get("chieu_rong_van", 1220.0, "nesting"),
      "chieu_dai_van" => KSU::Settings.get("chieu_dai_van", 2440.0, "nesting"),
      "tu_dong_hau_ky" => !!KSU::Settings.get("tu_dong_hau_ky", true, "nesting"),
      "goc_don_van" => KSU::Settings.get("goc_don_van", "trai_duoi", "nesting").to_s,
      "thu_tu_don" => KSU::Settings.get("thu_tu_don", "mac_dinh", "nesting").to_s,
      "tach_nhom_2_mat" => !!KSU::Settings.get("tach_nhom_2_mat", true, "nesting"),
      "ghep_cap_toi_uu" => !!KSU::Settings.get("ghep_cap_toi_uu", true, "nesting"),
      "nhom_cap_am_duong" => !!KSU::Settings.get("nhom_cap_am_duong", false, "nesting"),
      "don_ve_dau_hang" => !!KSU::Settings.get("don_ve_dau_hang", true, "nesting"),
      "sap_xep_danh_sach" => KSU::Settings.get("sap_xep_danh_sach", "mac_dinh", "nesting").to_s
    }
    data = { settings: settings, materials: materials }
    KSU::Settings.send_to_dialog(dlg, "nesting", "nestingLoad", data.to_json)
  end
  def _d1ef9374(arr)
    src = arr && !arr.empty? ? arr : Sketchup.active_model.entities
    arr2 = []
    gather_boards(src, arr2, {})
    h = {}
    materials = []
    arr2.each do |g|
      tf = KSU::Cutting.tf_of(g)
      b2 = KSU::Cutting.board_faces(g, tf)
      next unless b2
      thickness_mm = _2c9761fb(b2, tf)
      next if thickness_mm < 1.0 || thickness_mm > 50.0
      _15cb29cb = KSU::Cutting.front_face(g, b2)
      mat = _6f88583c(g, _15cb29cb)
      key = "#{mat}#{thickness_mm}"
      unless h[key]
        h[key] = { key: key, material: mat, thickness_mm: thickness_mm, eids: [] }
        materials << key
      end
      h[key][:eids] << g.entityID
    end
    rows = materials.map { |k| h[k] }
    rows.sort_by! { |half| [half[:thickness_mm].to_f, half[:material].to_s.downcase] }
    _3758e659(rows)
    _49dd846c(rows)
    rows
  end
  def _49dd846c(rows)
    _884dee16 = begin
      JSON.parse(KSU::Settings.get("cau_hinh_vat_lieu", "", "nesting").to_s)
    rescue StandardError
      {}
    end
    _884dee16 = {} unless _884dee16.is_a?(Hash)
    rows.each do |half|
      color = _884dee16[half[:key]]
      half[:on] = !(color.is_a?(Array) && color[0] == false)
      half[:ord] = color.is_a?(Array) && color[1].is_a?(Numeric) ? color[1] : nil
      half[:rot] = color.is_a?(Array) && color[2] == true
      half[:kw] = color.is_a?(Array) && color[3].is_a?(String) ? color[3] : ""
    end
    ordered = rows.each_with_index.sort_by do |half, i|
      [half[:ord] ? 0 : 1, half[:ord].to_f, i]
    end.map { |half, _part| half }
    ordered.each { |half| half.delete(:ord) }
    rows.replace(ordered)
  end
  def _e3264765(str2)
    arr2 = str2.to_s.split(/[,\n]/).map { |thick| thick.strip }.reject(&:empty?)
    return if arr2.empty?
    keys = {}
    arr = []
    arr2.each do |thick|
      if thick =~ /\A\d+\z/
        keys[thick] = true
      else
        arr << thick.downcase
      end
    end
    arr3 = []
    gather_boards(Sketchup.active_model.entities, arr3, {})
    arr5 = arr3.select do |g|
      if !keys.empty? && keys[g.get_attribute("ABF", "board-index").to_s]
        true
      elsif arr.empty?
        false
      else
        name = g.name.to_s.downcase
        mat = g.material ? g.material.name.to_s.downcase : ""
        arr.any? { |_0cc812ea| name.include?(_0cc812ea) || (!mat.empty? && mat.include?(_0cc812ea)) }
      end
    end
    KSU.select_only(arr5)
    KSU::View.view.invalidate
  rescue StandardError
    nil
  end
  def _1582b880(resp)
    keys = begin
      JSON.parse(resp.to_s)
    rescue StandardError
      []
    end
    return unless keys.is_a?(Array) && !keys.empty?
    model = Sketchup.active_model
    ents = Array(model.find_entity_by_id(*keys.map(&:to_i)))
    ents = ents.compact.select { |ent| ent.respond_to?(:valid?) && ent.valid? }
    KSU.select_only(ents)
    model.active_view.invalidate
  rescue StandardError
    nil
  end
  def _e534023c(resp)
    arr = begin
      JSON.parse(resp.to_s)
    rescue StandardError
      []
    end
    return [] unless arr.is_a?(Array)
    arr.select { |half| half.is_a?(Hash) && !half["key"].to_s.empty? }
  end
  def _f75e3e4f(rows, _4effcb0e)
    return if @arr47 || @progress || @labelling || @collecting
    KSU.select_only([])
    cfg = job_settings
    unless rows.empty?
      materials = {}
      mat_order = {}
      rotate_cfg = {}
      h = {}
      rows.each_with_index do |half, i|
        materials[half["key"].to_s] = true if half["on"]
        mat_order[half["key"].to_s] = i
        color = { on: half["rot"] == true, kw: half["kw"].to_s }
        rotate_cfg[half["key"].to_s] = color
        h[half["name"].to_s] = color
      end
      cfg[:materials] = materials
      cfg[:mat_order] = mat_order
      cfg[:rotate_cfg] = rotate_cfg
      cfg[:rotate_by_name] = h
    end
    m_left, m_right, top, m_bottom = margins_of(cfg)
    if cfg[:sheet_w] - m_left - m_right <= 0 || cfg[:sheet_h] - top - m_bottom <= 0
      UI.messagebox("Có lỗi xảy ra khi nesting!")
      return
    end
    close_contexts
    erase_nesting
    start_collect(cfg, true, _4effcb0e)
  rescue StandardError => ent
    abort_collect
    UI.messagebox("Lỗi nesting: #{ent.message}")
  end
end
KSU::Nest.extend(KSU::Launch)
