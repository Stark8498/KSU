module KSU::Edit
  def sort_key(name)
    s = name.to_s.sub(/\A__\d+\.?\s*/, "").sub(/\A__/, "")
    s.downcase.scan(/\d+|\D+/).map { |t| t =~ /\A\d/ ? [1, t.to_i, ""] : [0, 0, t] }
  end
  def last_cut?(entity)
    return false unless entity && entity.valid?
    return true if entity.get_attribute("ABF", "is-last-cut")
    entity.name.to_s == "__ABF_lastCut"
  end
  def enter_edit
    nesting = find_nesting
    return nil unless nesting
    KSU::View.load_colors
    KSU::View.clear_cache
    KSU::Preset.load_cfg if defined?(KSU::Preset)
    mute_profiles
    KSU::Sheet.invalidate_cache
    KSU::Sheet.apply_offsets(nesting)
    @prev_persp = KSU::View.enter_top_view(nesting)
    nesting
  end
  def leave_edit
    nesting = find_nesting(notify: false)
    KSU::Sheet.clear_offsets(nesting) if nesting
    KSU::Sheet.invalidate_cache
    KSU::View.clear_cache
    restore_profiles
    KSU::View.restore_perspective(@prev_persp)
  end
  def mute_profiles
    opts = Sketchup.active_model.rendering_options
    @prev_profiles = opts["Profiles"] if opts.keys.include?("Profiles")
    @prev_profile_w = opts["EdgeProfileWidth"] if opts.keys.include?("EdgeProfileWidth")
    @prev_silhouettes = opts["DrawSilhouettes"] if opts.keys.include?("DrawSilhouettes")
    opts["Profiles"] = false if opts.keys.include?("Profiles")
    opts["DrawSilhouettes"] = false if opts.keys.include?("DrawSilhouettes")
    opts["EdgeProfileWidth"] = 1 if opts.keys.include?("EdgeProfileWidth") && opts["EdgeProfileWidth"] > 1
  rescue
    nil
  end
  def restore_profiles
    opts = Sketchup.active_model.rendering_options
    opts["Profiles"] = @prev_profiles unless @prev_profiles.nil?
    opts["EdgeProfileWidth"] = @prev_profile_w if @prev_profile_w
    opts["DrawSilhouettes"] = @prev_silhouettes unless @prev_silhouettes.nil?
    @prev_profiles = @prev_profile_w = @prev_silhouettes = nil
  rescue
    nil
  end
  def panel_list(nesting)
    return [] unless nesting && nesting.valid?
    tr = nesting.transformation
    nesting.definition.entities.flat_map do |grp|
      next [] unless KSU.container?(grp) && grp.name.to_s.downcase.include?("sheet")
      sheet_transform(grp, tr)
    end
  end
  def sheet_transform(grp, _c8b30203)
    is_bottom = KSU::Sheet.bottom_sheet?(grp)
    sheet_tr = _c8b30203 * grp.transformation
    grp.definition.entities.filter_map do |panel|
      next unless KSU::Sheet.part_group?(panel)
      next if is_bottom && !KSU::Cutting.cutting_group(panel)
      fill = KSU::Cutting.outline(panel, sheet_tr * panel.transformation)
      polygon = fill[:outer]
      next unless polygon && polygon.length >= 3
      { entity: panel, polygon: polygon, holes: fill[:holes], board_index: panel.get_attribute("ABF", "board-index"), back: is_bottom || KSU::Cutting.bottom_face?(panel) }
    end
  end
  def two_sided_set(nesting)
    h = {}
    return h unless nesting && nesting.valid?
    nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      grp.definition.entities.each do |panel|
        next unless KSU.container?(panel) && KSU::Cutting.bottom_face?(panel)
        ix = panel.get_attribute("ABF", "board-index")
        h[ix] = true unless ix.nil?
      end
    end
    h
  end
  def overlap_polys(nesting)
    polys = []
    return polys unless nesting && nesting.valid?
    collect_label_polys(nesting, nesting.transformation, polys)
    polys
  end
  def collect_label_polys(ents3, _ac3b3b9d, polys)
    ents = KSU.entities_in(ents3)
    return unless ents
    ents.each do |grp|
      next unless grp.valid? && KSU.container?(grp)
      str = grp.name.to_s
      def_name = (grp.respond_to?(:definition) && grp.definition) ? grp.definition.name.to_s : ""
      transform = _ac3b3b9d * grp.transformation
      if str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
        arr2 = KSU.entities_in(grp)
        next unless arr2
        h = {}
        arr2.each do |edge|
          next unless edge.is_a?(Sketchup::Edge) && edge.valid?
          lp = edge.curve
          next unless lp
          next if h[lp.entityID]
          next unless edge.get_attribute("KSU", "them_tam")
          h[lp.entityID] = true
          arr = curve_pts(lp, transform)
          polys << arr if arr && arr.length >= 3
        end
      else
        collect_label_polys(grp, transform, polys)
      end
    end
  end
  def curve_pts(lp, _ac3b3b9d)
    pt = lp.vertices.map { |v| _ac3b3b9d * v.position }
    pt.pop if pt.length >= 2 && pt.first.distance(pt.last).to_f < 1e-6
    pt
  end
  def error_points(nesting, limit = 20, _4c11a852 = nil)
    out = []
    return out unless nesting && nesting.valid?
    model = Sketchup.active_model.layers["ABF_cuttingLines"]
    return out unless model && model.name == "ABF_cuttingLines"
    walk_entities(nesting, nesting.transformation, out, limit, model, _4c11a852, nil)
    out
  end
  def walk_entities(ents3, _ac3b3b9d, out, limit, layer_name, _4c11a852 = nil, _86048f49 = nil)
    ents = KSU.entities_in(ents3)
    return unless ents
    ents.each do |grp|
      if grp.is_a?(Sketchup::Edge)
        next unless grp.layer == layer_name
        lp = grp.curve
        next unless lp && grp == lp.first_edge
        num = out.length
        sharp_pts(lp, _ac3b3b9d, out, limit)
        _4c11a852 << _86048f49 if _4c11a852 && _86048f49 && out.length > num
      elsif KSU.container?(grp)
        id = grp.get_attribute("ABF", "board-index")
        walk_entities(grp, _ac3b3b9d * grp.transformation, out, limit, layer_name, _4c11a852, id.nil? ? _86048f49 : id.to_s)
      end
    end
  end
  def sharp_pts(lp, _ac3b3b9d, out, limit)
    snap_edges = lp.edges
    ((snap_edges.length >= 3 ? -1 : 0)...snap_edges.length - 1).each do |i|
      skip1, skip2 = snap_edges[i], snap_edges[i + 1]
      v = shared_vertex(skip1, skip2)
      next unless v
      deg4 = corner_deg(skip1.other_vertex(v).position, v.position, skip2.other_vertex(v).position)
      next unless deg4 && deg4 < limit
      out << v.position.transform(_ac3b3b9d)
    end
  end
  def corner_deg(p1, p2, p3)
    vec = (p1 - p2).normalize
    _11f053b2 = (p3 - p2).normalize
    dot = [[-1.0, vec.dot(_11f053b2)].max, 1.0].min
    Math.acos(dot).radians
  rescue
    nil
  end
  def shared_vertex(skip1, skip2)
    a0v, a1v = skip1.start, skip1.end
    b0v, b1v = skip2.start, skip2.end
    return a0v if a0v == b0v || a0v == b1v
    return a1v if a1v == b0v || a1v == b1v
    nil
  end
  def find_nesting(notify: true)
    model = Sketchup.active_model
    nesting = model.entities.find { |grp| grp.respond_to?(:name) && grp.name == "__ABF_Nesting" }
    return nesting if nesting
    model.definitions.each do |len2d|
      next if len2d.image?
      len2d.instances.each { |inst| return inst if inst.name == "__ABF_Nesting" }
    end
    UI.messagebox("Không tìm thấy group nesting!") if notify
    nil
  end
  def nesting_root
    Sketchup.active_model.entities.grep(Sketchup::Group).find { |grp| grp.get_attribute("ABF", "is-nesting-root") }
  end
  def nest_panel?(entity)
    return false unless entity && entity.respond_to?(:name)
    return false if entity.name.to_s == "__ABF_sheetBorder"
    KSU::Sheet.drawable?(entity)
  end
  def clone_panel(ents, panel, _11485ef7)
    return nil unless panel && panel.valid? && ents
    grp = panel.definition
    name = panel.respond_to?(:name) ? panel.name : nil
    flag = panel.respond_to?(:layer) ? panel.layer : nil
    material = panel.respond_to?(:material) ? panel.material : nil
    arr = []
    panel.attribute_dictionaries&.each do |h|
      h7 = {}
      h.each_pair { |k, v| h7[k] = v }
      arr << [h.name, h7]
    end
    if panel.is_a?(Sketchup::Group)
      panel.erase!
      moved_panel = ents.add_group
      moved_panel.entities.add_instance(grp, Geom::Transformation.new).explode
      moved_panel.transformation = _11485ef7
    else
      moved_panel = ents.add_instance(grp, _11485ef7)
      panel.erase!
    end
    moved_panel.name = name if name
    moved_panel.layer = flag if flag
    moved_panel.material = material if material
    arr.each { |dict, h7| h7.each { |k, v| moved_panel.set_attribute(dict, k, v) } }
    moved_panel
  end
  def move_to_sheet(panel, grp2, grp, nesting)
    tr3 = grp2 ? grp2.transformation : Geom::Transformation.new
    tr = grp ? grp.transformation : Geom::Transformation.new
    tr2 = tr.inverse * tr3 * panel.transformation
    ents = grp ? grp.definition.entities : nesting.definition.entities
    clone_panel(ents, panel, tr2)
  end
  def clone_panel_into(panel, grp)
    clone_panel(grp.definition.entities, panel, panel.transformation)
  end
  def max_board_index(nesting)
    hi = 0
    return hi unless nesting && nesting.valid?
    nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      ents = KSU.entities_in(sheet)
      next unless ents
      ents.each do |panel|
        next unless KSU.container?(panel)
        ix = panel.get_attribute("ABF", "board-index")
        hi = ix.to_i if ix && ix.to_i > hi
      end
    end
    hi
  end
  def add_board_stub(grp, z, name = nil)
    return unless grp && grp.valid?
    screen_box = grp.entities.add_group
    screen_box.name = name.to_s if name
    font = screen_box.entities.add_face([0, 0, 0], [1.mm, 0, 0], [1.mm, 1.mm, 0], [0, 1.mm, 0])
    return unless font
    font.pushpull(1.mm)
    screen_box.set_attribute("ABF", "board-index", z)
    screen_box.set_attribute("ABF", "is-board", true)
    _77a00f52 = KSU::Cutting.layer("KSU_TEMP")
    screen_box.layer = _77a00f52 if _77a00f52
    screen_box
  end
  def hide_temp_layer
    tag = Sketchup.active_model.layers["KSU_TEMP"]
    tag.visible = false if tag
  end
end
KSU::Nesting.extend(KSU::Edit)
module KSU::Edit
  def self.clear_bindings
    KSU::Mode.write_binding_key("k", "")
    KSU::Mode.write_binding_key("i", "")
    KSU::Mode.write_binding_key("t", "")
  end
end
