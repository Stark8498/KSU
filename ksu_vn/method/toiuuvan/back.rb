module KSU::Back
  private
  def sheets_by_stock_v1
    groups = Hash.new { |h, k| h[k] = [] }
    @sel.each do |sheet|
      next unless sheet && sheet.valid?
      groups[KSU::Sheet.stock_key(sheet)] << sheet
    end
    groups
  end
  def back_face2_v1?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def front_panel_v1?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.index_of(panel).nil? && !back_face2_v1?(panel)
  end
  def back_of_v1(vec)
    return nil unless vec && vec.valid? && front_panel_v1?(vec)
    ix = KSU::Cutting.index_of(vec)
    return nil if ix.nil?
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet) && sheet.name.to_s.downcase.include?("sheet")
      back = sheet.definition.entities.find do |ent|
        KSU.container?(ent) && ent != vec &&
          KSU::Cutting.index_of(ent) == ix && back_face2_v1?(ent)
      end
      return [back, sheet] if back
    end
    nil
  end
  def sync_back_v1(panel2, pair, sheet2, sheet3, num = 0)
    partner, back_sheet = pair
    return unless partner && partner.valid? && sheet3 && sheet3.valid?
    vec = bottom_target_v1(sheet2, back_sheet, sheet3)
    return unless vec && vec.valid?
    if vec != back_sheet
      partner = KSU::Nesting.move_to_sheet(partner, back_sheet, vec, @nesting)
    end
    return unless partner && partner.valid?
    rotate_partner_v1(partner, vec, num) if num && num != 0
    place_mirror_v1(panel2, partner, sheet3, vec)
  end
  def rotate_partner_v1(panel, sheet, deg3)
    tr = @nesting.transformation * sheet.transformation
    center = KSU::View.panel_world_box(panel, tr).center
    rad = -deg3 * Math::PI / 180.0
    tr2 = Geom::Transformation.rotation(center, Z_AXIS, rad)
    panel.transformation = tr.inverse * tr2 * tr * panel.transformation
  end
  def bottom_target_v1(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    partner = @pack_cache && @pack_cache[sheet3.entityID]
    return partner if partner && partner.valid?
    vec = KSU::Sheet.bottom_of(sheet3, @nesting)
    if vec && vec.valid?
      drop_from_sheet_v1(vec, sheet3)
      return move_onto_sheet_v1(sheet3, vec)
    end
    bottom = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return back_sheet unless bottom && bottom.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(bottom, @nesting)
    return back_sheet unless flag2 && flag2.valid?
    bb4 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb = KSU::Sheet.world_bbox(bottom, @nesting)
    bb3 = KSU::Sheet.world_bbox(sheet3, @nesting)
    return back_sheet unless bb4 && bb && bb3
    str = KSU::Sheet.sheet_no(sheet3.name.to_s)
    pt = Geom::Point3d.new(
      bb3.center.x,
      bb3.center.y + (bb.center.y - bb4.center.y),
      bb.center.z
    )
    grp = KSU::Sheet.clone_sheet_shell(bottom, bottom.transformation, @nesting)
    return back_sheet unless grp && grp.valid?
    grp.set_attribute("ABF", "is-bottom-sheet", true)
    bb2 = KSU::Sheet.world_bbox(grp, @nesting)
    if bb2
      vec2 = Geom::Vector3d.new(pt.x - bb2.center.x, pt.y - bb2.center.y, 0)
      tr = vec2.transform(@nesting.transformation.inverse)
      grp.transformation = Geom::Transformation.translation(tr) * grp.transformation
    end
    grp.name = sheet3.name.to_s + "-bottom"
    grp.set_attribute("ABF", "sheet-id", str) if str
    move_onto_sheet_v1(sheet3, grp)
  end
  def move_onto_sheet_v1(sheet3, vec)
    return vec unless @pack_cache && sheet3 && sheet3.valid?
    @pack_cache[sheet3.entityID] = vec if vec && vec.valid?
    vec
  end
  def drop_from_sheet_v1(grp, sheet3)
    return unless grp && grp.valid? && sheet3 && sheet3.valid?
    bb2 = KSU::Sheet.world_bbox(grp, @nesting)
    bb = KSU::Sheet.world_bbox(sheet3, @nesting)
    return unless bb2 && bb
    dx = bb.center.x - bb2.center.x
    return if dx.abs < 1e-6
    vec = Geom::Vector3d.new(dx, 0, 0).transform(@nesting.transformation.inverse)
    grp.transformation = Geom::Transformation.translation(vec) * grp.transformation
  end
  def place_mirror_v1(panel2, grp2, grp3, grp)
    _d0a341c6 = KSU::Sheet.world_bbox(grp3, @nesting)
    back_bb = KSU::Sheet.world_bbox(grp, @nesting)
    tr = part_box_v1(panel2, @nesting.transformation * grp3.transformation)
    bb = part_box_v1(grp2, @nesting.transformation * grp.transformation)
    return unless _d0a341c6 && back_bb && tr && bb
    _3e7613f3, _9ba1a361 = KSU::Sheet.inset_of(grp)
    hside, vside = KSU::Sheet.mark_corner(grp, @nesting)
    hside ||= :right
    vside ||= :bottom
    eoff_x, eoff_y = KSU::Sheet.edit_offset(grp3) || [0.0, 0.0]
    mx, my2 = KSU::Sheet.mirror_pos(
      _d0a341c6, back_bb, _3e7613f3, _9ba1a361, hside, vside, eoff_x, eoff_y,
      tr.min.x, tr.max.x, tr.min.y, tr.max.y,
      bb.width, bb.height
    )
    vec = Geom::Vector3d.new(mx - bb.min.x, my2 - bb.min.y, 0)
    tr2 = vec.transform((@nesting.transformation * grp.transformation).inverse)
    grp2.transformation = Geom::Transformation.translation(tr2) * grp2.transformation
  end
  def part_box_v1(panel, _6a989d41)
    return KSU::View.panel_world_box(panel, _6a989d41) unless @tach_nhom_2_mat && @tu_dong_sua_vi_tri
    poly = KSU::Cutting.cut_outline(panel, _6a989d41 * panel.transformation)
    return KSU::View.panel_world_box(panel, _6a989d41) unless poly && poly.length >= 3
    bbox = Geom::BoundingBox.new
    poly.each { |pt4| bbox.add(pt4) }
    bbox
  end
end
KSU::Toiuuvan.include(KSU::Back)
module KSU::Back
  def self.xor_key_v1
    0x99
  end
  def self.activation_error_v1(err_code)
    KSU::Collide.activation_errors.fetch(err_code, "Mã kích hoạt không hợp lệ.")
  end
end
