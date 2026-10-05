module KSU::Back
  private
  def sheets_by_stock
    @sel.select { |vec| vec && vec.valid? }.group_by { |vec| KSU::Sheet.stock_key(vec) }
  end
  def back_face2?(panel)
    KSU::Sheet.back_face?(panel)
  end
  def front_panel?(panel)
    return false unless panel && panel.valid?
    !KSU::Cutting.index_of(panel).nil? && !back_face2?(panel)
  end
  def back_of(vec)
    return nil unless vec && vec.valid? && front_panel?(vec)
    ix = KSU::Cutting.index_of(vec)
    @nesting.definition.entities.each do |grp|
      next unless KSU::Sheet.sheet?(grp)
      back = grp.definition.entities.find do |e|
        KSU.container?(e) && e != vec &&
          KSU::Cutting.index_of(e) == ix && back_face2?(e)
      end
      return [back, grp] if back
    end
    nil
  end
  def sync_back(panel2, pair, sheet2, sheet3, num = 0)
    vec, back_sheet = pair
    return unless vec && vec.valid? && sheet3 && sheet3.valid?
    vec2 = bottom_target(sheet2, back_sheet, sheet3)
    return unless vec2 && vec2.valid?
    vec = KSU::Nesting.move_to_sheet(vec, back_sheet, vec2, @nesting) if vec2 != back_sheet
    return unless vec && vec.valid?
    rotate_partner(vec, vec2, num) if num && num != 0
    place_mirror(panel2, vec, sheet3, vec2)
  end
  def rotate_partner(panel, grp, deg3)
    tr = @nesting.transformation * grp.transformation
    center = KSU::View.panel_world_box(panel, tr).center
    rad = -deg3 * Math::PI / 180.0
    tr2 = Geom::Transformation.rotation(center, Z_AXIS, rad)
    panel.transformation = tr.inverse * tr2 * tr * panel.transformation
  end
  def bottom_target(sheet2, back_sheet, sheet3)
    return back_sheet unless sheet3 && sheet3.valid?
    cached = @pack_cache && @pack_cache[sheet3.entityID]
    return cached if cached && cached.valid?
    vec = KSU::Sheet.bottom_of(sheet3, @nesting)
    if vec && vec.valid?
      drop_from_sheet(vec, sheet3)
      return move_onto_sheet(sheet3, vec)
    end
    flag = (back_sheet && back_sheet.valid?) ? back_sheet : KSU::Sheet.first_bottom(@nesting)
    return back_sheet unless flag && flag.valid?
    flag2 = (back_sheet && back_sheet.valid?) ? sheet2 : KSU::Sheet.top_of(flag, @nesting)
    return back_sheet unless flag2 && flag2.valid?
    bb3 = KSU::Sheet.world_bbox(flag2, @nesting)
    bb4 = KSU::Sheet.world_bbox(flag, @nesting)
    bb = KSU::Sheet.world_bbox(sheet3, @nesting)
    return back_sheet unless bb3 && bb4 && bb
    str = KSU::Sheet.sheet_no(sheet3.name.to_s)
    _7fe42625 = bb.center.x
    _41add7fc = bb.center.y + (bb4.center.y - bb3.center.y)
    grp = KSU::Sheet.clone_sheet_shell(flag, flag.transformation, @nesting)
    return back_sheet unless grp && grp.valid?
    grp.set_attribute("ABF", "is-bottom-sheet", true)
    bb2 = KSU::Sheet.world_bbox(grp, @nesting)
    if bb2
      vec2 = Geom::Vector3d.new(_7fe42625 - bb2.center.x, _41add7fc - bb2.center.y, 0)
      tr = vec2.transform(@nesting.transformation.inverse)
      grp.transformation = Geom::Transformation.translation(tr) * grp.transformation
    end
    grp.name = sheet3.name.to_s + "-bottom"
    grp.set_attribute("ABF", "sheet-id", str) if str
    move_onto_sheet(sheet3, grp)
  end
  def move_onto_sheet(sheet3, vec)
    return vec unless @pack_cache && sheet3 && sheet3.valid?
    @pack_cache[sheet3.entityID] = vec if vec && vec.valid?
    vec
  end
  def drop_from_sheet(grp, sheet3)
    return unless grp && grp.valid? && sheet3 && sheet3.valid?
    bb2 = KSU::Sheet.world_bbox(grp, @nesting)
    bb = KSU::Sheet.world_bbox(sheet3, @nesting)
    return unless bb2 && bb
    dx = bb.center.x - bb2.center.x
    return if dx.abs < 1e-6
    vec = Geom::Vector3d.new(dx, 0, 0).transform(@nesting.transformation.inverse)
    grp.transformation = Geom::Transformation.translation(vec) * grp.transformation
  end
  def place_mirror(panel2, grp2, grp3, grp)
    _84d8f6b3 = KSU::Sheet.world_bbox(grp3, @nesting)
    _53413887 = KSU::Sheet.world_bbox(grp, @nesting)
    tr = part_box(panel2, @nesting.transformation * grp3.transformation)
    bb = part_box(grp2, @nesting.transformation * grp.transformation)
    return unless _84d8f6b3 && _53413887 && tr && bb
    _821639ac, _98c3a7e0 = KSU::Sheet.inset_of(grp)
    hside, vside = KSU::Sheet.mark_corner(grp, @nesting)
    hside ||= :right
    vside ||= :bottom
    eoff_x, eoff_y = KSU::Sheet.edit_offset(grp3) || [0.0, 0.0]
    _bcd2a048, _48d3c7a6 = KSU::Sheet.mirror_pos(
      _84d8f6b3, _53413887, _821639ac, _98c3a7e0, hside, vside, eoff_x, eoff_y,
      tr.min.x, tr.max.x, tr.min.y, tr.max.y,
      bb.width, bb.height
    )
    vec = Geom::Vector3d.new(_bcd2a048 - bb.min.x, _48d3c7a6 - bb.min.y, 0)
    tr2 = vec.transform((@nesting.transformation * grp.transformation).inverse)
    grp2.transformation = Geom::Transformation.translation(tr2) * grp2.transformation
  end
  def part_box(panel, _7fa7da40)
    poly = @tach_nhom_2_mat && KSU::Cutting.cut_outline(panel, _7fa7da40 * panel.transformation)
    return KSU::View.panel_world_box(panel, _7fa7da40) unless poly && poly.length >= 3
    poly.each_with_object(Geom::BoundingBox.new) { |pt3, bbox| bbox.add(pt3) }
  end
end
KSU::Toiuu.include(KSU::Back)
module KSU::Back
  def self.xor_key
    0x99
  end
  def self.activation_error(err_code)
    KSU::Collide.activation_errors.fetch(err_code, "Mã kích hoạt không hợp lệ.")
  end
end
