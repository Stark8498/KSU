module KSU::Back
  private
  def _e1ab909e
    groups = Hash.new { |h, k| h[k] = [] }
    @sel.each do |sheet|
      next unless sheet && sheet.valid?
      groups[KSU::Sheet._7b0a38ee(sheet)] << sheet
    end
    groups
  end
  def back_face2?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def front_panel?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.board_index(panel).nil? && !back_face2?(panel)
  end
  def back_of(panel)
    return nil unless panel && panel.valid? && front_panel?(panel)
    ix = KSU::Cutting.board_index(panel)
    return nil if ix.nil?
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet) && sheet.name.to_s.downcase.include?("sheet")
      back = sheet.definition.entities.find do |ent|
        KSU.container?(ent) && ent != panel &&
          KSU::Cutting.board_index(ent) == ix && back_face2?(ent)
      end
      return [back, sheet] if back
    end
    nil
  end
  def sync_back(panel2, pair, sheet2, sheet3, num = 0)
    partner, back_sheet = pair
    return unless partner && partner.valid? && sheet3 && sheet3.valid?
    vec = bottom_target(sheet2, back_sheet, sheet3)
    return unless vec && vec.valid?
    if vec != back_sheet
      partner = KSU::Nesting.move_to_sheet(partner, back_sheet, vec, @nesting)
    end
    return unless partner && partner.valid?
    _a7fa30d2(partner, vec, num) if num && num != 0
    place_mirror(panel2, partner, sheet3, vec)
  end
  def _a7fa30d2(panel, sheet, _74c34b47)
    tr = @nesting.transformation * sheet.transformation
    center = KSU::View._66e14707(panel, tr).center
    rad = -_74c34b47 * Math::PI / 180.0
    tr2 = Geom::Transformation.rotation(center, Z_AXIS, rad)
    panel.transformation = tr.inverse * tr2 * tr * panel.transformation
  end
  def bottom_target(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    partner = @h29 && @h29[sheet3.entityID]
    return partner if partner && partner.valid?
    vec2 = KSU::Sheet.bottom(sheet3, @nesting)
    if vec2 && vec2.valid?
      _3fccea3f(vec2, sheet3)
      return _76d37ecf(sheet3, vec2)
    end
    flag = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return back_sheet unless flag && flag.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(flag, @nesting)
    return back_sheet unless flag2 && flag2.valid?
    bb4 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb3 = KSU::Sheet.world_bbox(flag, @nesting)
    bb2 = KSU::Sheet.world_bbox(sheet3, @nesting)
    return back_sheet unless bb4 && bb3 && bb2
    str = KSU::Sheet.sheet_no(sheet3.name.to_s)
    pt = Geom::Point3d.new(
      bb2.center.x,
      bb2.center.y + (bb3.center.y - bb4.center.y),
      bb3.center.z
    )
    grp2 = KSU::Sheet._f74b0a99(flag, flag.transformation, @nesting)
    return back_sheet unless grp2 && grp2.valid?
    grp2.set_attribute("ABF", "is-bottom-sheet", true)
    bb = KSU::Sheet.world_bbox(grp2, @nesting)
    if bb
      vec3 = Geom::Vector3d.new(pt.x - bb.center.x, pt.y - bb.center.y, 0)
      tr = vec3.transform(@nesting.transformation.inverse)
      grp2.transformation = Geom::Transformation.translation(tr) * grp2.transformation
    end
    grp2.name = sheet3.name.to_s + "-bottom"
    grp2.set_attribute("ABF", "sheet-id", str) if str
    _76d37ecf(sheet3, grp2)
  end
  def _76d37ecf(sheet3, tr)
    return tr unless @h29 && sheet3 && sheet3.valid?
    @h29[sheet3.entityID] = tr if tr && tr.valid?
    tr
  end
  def _3fccea3f(tr, sheet3)
    return unless tr && tr.valid? && sheet3 && sheet3.valid?
    bb = KSU::Sheet.world_bbox(tr, @nesting)
    bb2 = KSU::Sheet.world_bbox(sheet3, @nesting)
    return unless bb && bb2
    dx = bb2.center.x - bb.center.x
    return if dx.abs < 1e-6
    vec2 = Geom::Vector3d.new(dx, 0, 0).transform(@nesting.transformation.inverse)
    tr.transformation = Geom::Transformation.translation(vec2) * tr.transformation
  end
  def place_mirror(panel2, grp3, sheet, tr4)
    _d0a341c6 = KSU::Sheet.world_bbox(sheet, @nesting)
    _cc2599da = KSU::Sheet.world_bbox(tr4, @nesting)
    tr = _cc53f14a(panel2, @nesting.transformation * sheet.transformation)
    bb = _cc53f14a(grp3, @nesting.transformation * tr4.transformation)
    return unless _d0a341c6 && _cc2599da && tr && bb
    _3e7613f3, _9ba1a361 = KSU::Sheet.inset_of(tr4)
    hside, vside = KSU::Sheet.mark_corner(tr4, @nesting)
    hside ||= :right
    vside ||= :bottom
    _7bb0b74c, _5e0b9d0f = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    _5f2b530c, _76baa4cb = KSU::Sheet._5134c34c(
      _d0a341c6, _cc2599da, _3e7613f3, _9ba1a361, hside, vside, _7bb0b74c, _5e0b9d0f,
      tr.min.x, tr.max.x, tr.min.y, tr.max.y,
      bb.width, bb.height
    )
    vec = Geom::Vector3d.new(_5f2b530c - bb.min.x, _76baa4cb - bb.min.y, 0)
    tr2 = vec.transform((@nesting.transformation * tr4.transformation).inverse)
    grp3.transformation = Geom::Transformation.translation(tr2) * grp3.transformation
  end
  def _cc53f14a(panel, _6a989d41)
    return KSU::View._66e14707(panel, _6a989d41) unless @tach_nhom_2_mat && @tu_dong_sua_vi_tri
    poly = KSU::Cutting.cut_outline(panel, _6a989d41 * panel.transformation)
    return KSU::View._66e14707(panel, _6a989d41) unless poly && poly.length >= 3
    bbox = Geom::BoundingBox.new
    poly.each { |_23505ef9| bbox.add(_23505ef9) }
    bbox
  end
end
KSU::Toiuuvan.include(KSU::Back)
module KSU::Back
  def self._f7eacb3a
    0x99
  end
  def self._cd99bb15(err_code)
    KSU::Collide._f812d741.fetch(err_code, "Mã kích hoạt không hợp lệ.")
  end
end
