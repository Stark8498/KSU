module KSU::Back
  private
  def sheets_by_stock
    groups = Hash.new { |h, k| h[k] = [] }
    @sel.each do |sheet|
      next unless sheet && sheet.valid?
      groups[KSU::Sheet.stock_key(sheet)] << sheet
    end
    groups
  end
  def back_face2?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def front_panel?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.index_of(panel).nil? && !back_face2?(panel)
  end
  def back_of(vec)
    return nil unless vec && vec.valid? && front_panel?(vec)
    ix = KSU::Cutting.index_of(vec)
    return nil if ix.nil?
    @nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet) && sheet.name.to_s.downcase.include?("sheet")
      back = sheet.definition.entities.find do |ent|
        KSU.container?(ent) && ent != vec &&
          KSU::Cutting.index_of(ent) == ix && back_face2?(ent)
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
    rotate_partner(partner, vec, num) if num && num != 0
    place_mirror(panel2, partner, sheet3, vec)
  end
  def rotate_partner(panel, sheet, deg3)
    tr = @nesting.transformation * sheet.transformation
    center = KSU::View.panel_world_box(panel, tr).center
    rad = -deg3 * Math::PI / 180.0
    tr2 = Geom::Transformation.rotation(center, Z_AXIS, rad)
    panel.transformation = tr.inverse * tr2 * tr * panel.transformation
  end
  def bottom_target(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    partner = @pack_cache && @pack_cache[sheet3.entityID]
    return partner if partner && partner.valid?
    vec2 = KSU::Sheet.bottom_of(sheet3, @nesting)
    if vec2 && vec2.valid?
      drop_from_sheet(vec2, sheet3)
      return move_onto_sheet(sheet3, vec2)
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
    grp2 = KSU::Sheet.clone_sheet_shell(flag, flag.transformation, @nesting)
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
    move_onto_sheet(sheet3, grp2)
  end
  def move_onto_sheet(sheet3, tr)
    return tr unless @pack_cache && sheet3 && sheet3.valid?
    @pack_cache[sheet3.entityID] = tr if tr && tr.valid?
    tr
  end
  def drop_from_sheet(tr, sheet3)
    return unless tr && tr.valid? && sheet3 && sheet3.valid?
    bb = KSU::Sheet.world_bbox(tr, @nesting)
    bb2 = KSU::Sheet.world_bbox(sheet3, @nesting)
    return unless bb && bb2
    dx = bb2.center.x - bb.center.x
    return if dx.abs < 1e-6
    vec2 = Geom::Vector3d.new(dx, 0, 0).transform(@nesting.transformation.inverse)
    tr.transformation = Geom::Transformation.translation(vec2) * tr.transformation
  end
  def place_mirror(panel2, grp3, grp2, tr4)
    front_bb = KSU::Sheet.world_bbox(grp2, @nesting)
    back_bb = KSU::Sheet.world_bbox(tr4, @nesting)
    tr = part_box(panel2, @nesting.transformation * grp2.transformation)
    bb = part_box(grp3, @nesting.transformation * tr4.transformation)
    return unless front_bb && back_bb && tr && bb
    inset_x, inset_y = KSU::Sheet.inset_of(tr4)
    hside, vside = KSU::Sheet.mark_corner(tr4, @nesting)
    hside ||= :right
    vside ||= :bottom
    eoff_x, eoff_y = KSU::Sheet.edit_offset(grp2) || [0.0, 0.0]
    mx, my2 = KSU::Sheet.mirror_pos(
      front_bb, back_bb, inset_x, inset_y, hside, vside, eoff_x, eoff_y,
      tr.min.x, tr.max.x, tr.min.y, tr.max.y,
      bb.width, bb.height
    )
    vec = Geom::Vector3d.new(mx - bb.min.x, my2 - bb.min.y, 0)
    tr2 = vec.transform((@nesting.transformation * tr4.transformation).inverse)
    grp3.transformation = Geom::Transformation.translation(tr2) * grp3.transformation
  end
  def part_box(panel, tf)
    return KSU::View.panel_world_box(panel, tf) unless @tach_nhom_2_mat && @tu_dong_sua_vi_tri
    poly = KSU::Cutting.cut_outline(panel, tf * panel.transformation)
    return KSU::View.panel_world_box(panel, tf) unless poly && poly.length >= 3
    bbox = Geom::BoundingBox.new
    poly.each { |pt| bbox.add(pt) }
    bbox
  end
end
KSU::Toiuuvan.include(KSU::Back)
module KSU::Back
  def self.xor_key
    0x99
  end
  def self.activation_error(err_code)
    KSU::Collide.activation_errors.fetch(err_code, "Mã kích hoạt không hợp lệ.")
  end
end
