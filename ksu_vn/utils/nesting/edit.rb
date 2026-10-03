module KSU::Edit
  def sort_key(name)
    s = name.to_s.sub(/\A__\d+\.?\s*/, "").sub(/\A__/, "")
    s.downcase.scan(/\d+|\D+/).map { |thick| thick =~ /\A\d/ ? [1, thick.to_i, ""] : [0, 0, thick] }
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
    if opts.keys.include?("EdgeProfileWidth") && opts["EdgeProfileWidth"] > 1
      opts["EdgeProfileWidth"] = 1
    end
  rescue
    nil
  end
  def restore_profiles
    opts = Sketchup.active_model.rendering_options
    opts["Profiles"] = @prev_profiles unless @prev_profiles.nil?
    opts["EdgeProfileWidth"] = @prev_profile_w if @prev_profile_w
    opts["DrawSilhouettes"] = @prev_silhouettes unless @prev_silhouettes.nil?
    @prev_profiles = nil
    @prev_profile_w = nil
    @prev_silhouettes = nil
  rescue
    nil
  end
  def panel_list(nesting)
    return [] unless nesting && nesting.valid?
    out = []
    tr = nesting.transformation
    nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      next unless sheet.name.to_s.downcase.include?("sheet")
      is_bottom = KSU::Sheet.bottom_sheet?(sheet)
      sheet_tr = tr * sheet.transformation
      sheet.definition.entities.each do |panel|
        next unless KSU::Sheet.panel?(panel)
        next if is_bottom && !KSU::Cutting.cutting_group(panel)
        panel_tr = sheet_tr * panel.transformation
        fill = KSU::Cutting.outline(panel, panel_tr)
        polygon = fill[:outer]
        next unless polygon && polygon.length >= 3
        out << { entity: panel, polygon: polygon, holes: fill[:holes], board_index: panel.get_attribute("ABF", "board-index"), back: is_bottom || KSU::Cutting.bottom_face?(panel) }
      end
    end
    out
  end
  def two_sided_set(nesting)
    out = {}
    return out unless nesting && nesting.valid?
    nesting.definition.entities.each do |sheet|
      next unless KSU::Sheet.sheet?(sheet)
      sheet.definition.entities.each do |panel|
        next unless KSU.container?(panel)
        next unless KSU::Cutting.bottom_face?(panel)
        ix = panel.get_attribute("ABF", "board-index")
        out[ix] = true unless ix.nil?
      end
    end
    out
  end
  def overlap_polys(nesting)
    polys = []
    return polys unless nesting && nesting.valid?
    collect_label_polys(nesting, nesting.transformation, polys)
    polys
  end
  def collect_label_polys(ents3, transform3, polys)
    ents = KSU.entities_in(ents3)
    return unless ents
    ents.each do |ent|
      next unless ent.valid? && KSU.container?(ent)
      name = ent.name.to_s
      def_name = (ent.respond_to?(:definition) && ent.definition) ? ent.definition.name.to_s : ""
      transform = transform3 * ent.transformation
      if name.include?("_ABF_Label") || def_name.include?("_ABF_Label")
        kids = KSU.entities_in(ent)
        next unless kids
        seen = {}
        kids.each do |edge|
          next unless edge.is_a?(Sketchup::Edge) && edge.valid?
          lp = edge.curve
          next unless lp
          next if seen[lp.entityID]
          next unless edge.get_attribute("KSU", "them_tam")
          seen[lp.entityID] = true
          arr = curve_pts(lp, transform)
          polys << arr if arr && arr.length >= 3
        end
      else
        collect_label_polys(ent, transform, polys)
      end
    end
  end
  def curve_pts(lp, transform)
    pts = lp.vertices.map { |v| transform * v.position }
    pts.pop if pts.length >= 2 && pts.first.distance(pts.last).to_f < 1e-6
    pts
  end
  def error_points(nesting, limit = 20)
    out = []
    return out unless nesting && nesting.valid?
    _108666c3(nesting, nesting.transformation, out, limit)
    out
  end
  def _108666c3(ents3, transform, out, limit)
    ents = KSU.entities_in(ents3)
    return unless ents
    ents.each do |entity|
      if entity.is_a?(Sketchup::Edge)
        next unless entity.layer.name == "ABF_cuttingLines"
        next unless entity.curve && entity == entity.curve.edges.first
        _7276832b(entity.curve, transform, out, limit)
      elsif KSU.container?(entity)
        _108666c3(entity, transform * entity.transformation, out, limit)
      end
    end
  end
  def _7276832b(lp, transform, out, limit)
    snap_edges = lp.edges
    (0...snap_edges.length - 1).each do |i|
      skip1, skip2 = snap_edges[i], snap_edges[i + 1]
      v = _59205066(skip1, skip2)
      next unless v
      pt = _f84d71f4(skip1.other_vertex(v).position, v.position, skip2.other_vertex(v).position)
      next unless pt && pt < limit
      out << v.position.transform(transform)
    end
  end
  def _f84d71f4(p1, p2, p3)
    vec = (p1 - p2).normalize
    _298717ec = (p3 - p2).normalize
    dot = [[-1.0, vec.dot(_298717ec)].max, 1.0].min
    Math.acos(dot).radians
  rescue
    nil
  end
  def _59205066(skip1, skip2)
    _97a0777d, _1ef55664 = skip1.start, skip1.end
    _66bc2bf1, _7ed768a8 = skip2.start, skip2.end
    return _97a0777d if _97a0777d == _66bc2bf1 || _97a0777d == _7ed768a8
    return _1ef55664 if _1ef55664 == _66bc2bf1 || _1ef55664 == _7ed768a8
    nil
  end
  def find_nesting(notify: true)
    model = Sketchup.active_model
    nesting = model.entities.find { |ent| ent.respond_to?(:name) && ent.name == "__ABF_Nesting" }
    return nesting if nesting
    model.definitions.each do |len2d|
      next if len2d.image?
      len2d.instances.each { |inst| return inst if inst.name == "__ABF_Nesting" }
    end
    UI.messagebox("Không tìm thấy group nesting!") if notify
    nil
  end
  def _d7b62fb6
    Sketchup.active_model.entities.grep(Sketchup::Group).find { |ent| ent.get_attribute("ABF", "is-nesting-root") }
  end
  def _88f4d2bb(entity)
    return false unless entity && entity.respond_to?(:name)
    return false if entity.name.to_s == "__ABF_sheetBorder"
    KSU::Sheet.drawable?(entity)
  end
  def clone_panel(ents, panel, tr)
    return nil unless panel && panel.valid? && ents
    grp2 = panel.definition
    name = panel.respond_to?(:name) ? panel.name : nil
    flag2 = panel.respond_to?(:layer) ? panel.layer : nil
    flag = panel.respond_to?(:material) ? panel.material : nil
    arr = []
    panel.attribute_dictionaries&.each do |h2|
      h = {}
      h2.each_pair { |k, v| h[k] = v }
      arr << [h2.name, h]
    end
    if panel.is_a?(Sketchup::Group)
      panel.erase!
      grp = ents.add_group
      grp.entities.add_instance(grp2, Geom::Transformation.new).explode
      grp.transformation = tr
    else
      grp = ents.add_instance(grp2, tr)
      panel.erase!
    end
    grp.name = name if name
    grp.layer = flag2 if flag2
    grp.material = flag if flag
    arr.each { |_072ce009, h| h.each { |k, v| grp.set_attribute(_072ce009, k, v) } }
    grp
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
  def add_board_stub(node, z, name = nil)
    return unless node && node.valid?
    screen_box = node.entities.add_group
    screen_box.name = name.to_s if name
    font = screen_box.entities.add_face([0, 0, 0], [1.mm, 0, 0], [1.mm, 1.mm, 0], [0, 1.mm, 0])
    return unless font
    font.pushpull(1.mm)
    screen_box.set_attribute("ABF", "board-index", z)
    screen_box.set_attribute("ABF", "is-board", true)
    temp_layer = KSU::Cutting.layer("KSU_TEMP")
    screen_box.layer = temp_layer if temp_layer
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
