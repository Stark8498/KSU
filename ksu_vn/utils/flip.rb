module KSU::Flip
  extend self
  def flip_pair(nesting, vec)
    return false unless nesting && nesting.valid? && vec && vec.valid?
    return false unless KSU::Cutting.bottom_face?(vec)
    vec2 = partner_of(nesting, vec)
    return false unless vec2 && vec2.valid?
    grp2 = sheet_of(nesting, vec)
    grp = sheet_of(nesting, vec2)
    return false unless grp2 && grp
    KSU.start
    begin
      max_eb = edgeband_groups(vec2, grp)
      tr_a = move_panel(nesting, vec2, grp, vec, grp2)
      tr_b = move_panel(nesting, vec, grp2, vec2, grp)
      unless tr_a && tr_b
        KSU.abort_op
        return false
      end
      attrs_a = attr_snapshot(vec2)
      attrs_b = attr_snapshot(vec)
      ents2 = KSU::Nesting.clone_panel(grp2.definition.entities, vec2, tr_a)
      ents = KSU::Nesting.clone_panel(grp.definition.entities, vec, tr_b)
      restore_attrs(ents2, attrs_b)
      restore_attrs(ents, attrs_a)
      drop_named(ents, "ABF_cuttingLines")
      drop_named(ents2, "ABF_partBorder")
      apply_edgeband(ents, max_eb)
      KSU.commit
      true
    rescue StandardError
      KSU.abort_op
      false
    end
  end
  def partner_of(nesting, panel)
    KSU::Cutting.partner_panel(nesting, panel)
  end
  def hit_targets(nesting)
    arr = []
    return arr unless nesting && nesting.valid?
    nesting.definition.entities.each do |sheet|
      next unless KSU::Sheet.sheet?(sheet)
      next unless KSU::Sheet.bottom_sheet?(sheet)
      transform = nesting.transformation * sheet.transformation
      sheet.definition.entities.each do |grp|
        next unless KSU.container?(grp) && KSU::Cutting.bottom_face?(grp)
        arr << { panel: grp, fill: KSU::Cutting.outline(grp, transform * grp.transformation) }
      end
    end
    arr
  end
  def hit_panel(view, src, x, y)
    src.each do |bf|
      panel = bf[:panel]
      next unless panel && panel.valid?
      return panel if KSU::View.hit?(view, bf[:fill], x, y)
    end
    nil
  end
  def panel_fill(nesting, panel)
    return nil unless nesting && nesting.valid? && panel && panel.valid?
    sheet = sheet_of(nesting, panel)
    return nil unless sheet
    KSU::Cutting.outline(panel, nesting.transformation * sheet.transformation * panel.transformation)
  end
  def sheet_of(nesting, panel)
    return nil unless nesting && nesting.valid? && panel && panel.valid?
    defn = panel.parent
    nesting.definition.entities.find do |ent|
      KSU.container?(ent) && ent.respond_to?(:definition) && ent.definition == defn
    end
  end
  def _cae3470a(ent)
    return false unless KSU.container?(ent)
    return true if ent.respond_to?(:get_attribute) && ent.get_attribute("ABF", "is-edge-banding-notation")
    ent.name.to_s.include?("_ABF_edgeBanding")
  end
  def edgeband_groups(panel, sheet)
    return [] unless panel && panel.valid? && sheet && sheet.valid?
    ents2 = panel.definition.entities.select { |ent| _cae3470a(ent) }
    return [] if ents2.empty?
    tr = panel.transformation
    _884dee16 = ents2.map { |ent| [ent, ent.transformation.clone] }
    bbox = _884dee16.map do |ent, _eef8786a|
      ents = KSU::Nesting.clone_panel(sheet.definition.entities, ent, tr * _eef8786a)
      [ents, _eef8786a]
    end
    tr2 = Geom::Transformation.scaling(panel.definition.bounds.center, 1, -1, 1)
    bbox.map { |ents, _eef8786a| [ents, tr * tr2 * _eef8786a] }
  end
  def drop_named(panel, _2cb52d46)
    return unless panel && panel.valid?
    vec = KSU::Cutting.cutting_group(panel)
    return unless vec && vec.valid?
    KSU::Cutting.set_layer(vec, KSU::Cutting.layer(_2cb52d46))
  end
  def apply_edgeband(panel, arr)
    return unless panel && panel.valid?
    arr.each do |inst, _b5060b46|
      next unless inst && inst.valid?
      KSU::Nesting.clone_panel(panel.definition.entities, inst, panel.transformation.inverse * _b5060b46)
    end
  end
  def attr_snapshot(entity)
    arr = []
    return arr unless entity && entity.valid?
    entity.attribute_dictionaries&.each do |h2|
      h = {}
      h2.each_pair { |k, v| h[k] = v }
      arr << [h2.name, h]
    end
    arr
  end
  def restore_attrs(inst, arr)
    return unless inst && inst.valid?
    inst.attribute_dictionaries&.map(&:name)&.each { |n| inst.delete_attribute(n) }
    arr.each { |name, arr2| arr2.each { |k, v| inst.set_attribute(name, k, v) } }
  end
  def move_panel(nesting, panel, grp3, grp, grp2)
    return nil unless panel && panel.valid? && grp && grp.valid?
    tr = nesting.transformation * grp3.transformation * panel.transformation
    _3beb117f = _4863ef50(panel, tr)
    tr3 = nesting.transformation * grp2.transformation * grp.transformation
    _263973eb = _4863ef50(grp, tr3)
    tr2 = Geom::Transformation.translation(_263973eb - _3beb117f) * tr
    (nesting.transformation * grp2.transformation).inverse * tr2
  end
  def _4863ef50(panel, transform)
    poly = KSU::Cutting.cut_outline(panel, transform)
    return panel.definition.bounds.center.transform(transform) unless poly && poly.length >= 3
    bbox = Geom::BoundingBox.new
    poly.each { |_23505ef9| bbox.add(_23505ef9) }
    bbox.center
  end
end
require "json"
module KSU::Flip
  def self._8351e254
    return KSU::Chongbay.read_bindings unless File.exist?(KSU::Collide._2b15ac41)
    _29e00ce2 = begin
      File.read(KSU::Collide._2b15ac41)
    rescue StandardError
      nil
    end
    return nil if _29e00ce2.nil?
    begin
      JSON.parse(_29e00ce2)
    rescue StandardError
      {}
    end
  end
  def self.prompt_activate
    key = KSU::Widget._e4d69360
    return unless key
    KSU::View.show_activation_result(key, KSU::Settings.activate_key(key))
  end
end
