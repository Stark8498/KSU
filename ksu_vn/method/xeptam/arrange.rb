module KSU::Arrange
  private
  def sheet_at2(view, x, y)
    return nil unless @nesting && @nesting.valid?
    arr = @arr24.select do |rec|
      vec = rec[:instance]
      vec && vec.valid? && !KSU::Sheet.hidden?(vec)
    end
    hit = arr.find do |rec|
      rect = name_rect(view, rec)
      rect && KSU::View.in_rect?(x, y, rect)
    end
    hit ||= arr.find do |rec|
      KSU::View.hit_sheet_top?(view, x, y, rec) || near_outline?(view, x, y, rec)
    end
    hit && hit[:instance]
  end
  def side_button_pt(rec, side)
    text, x1, y0, y1, z = KSU::View.extents(rec[:top_corners])
    py = (y0 + y1) / 2.0
    side == :left ? Geom::Point3d.new(text - 250.mm, py, z) : Geom::Point3d.new(x1 + 250.mm, py, z)
  end
  def draw_side_buttons(view, rec)
    [:left, :right].each do |side|
      KSU::View.draw_button(view, side_button_pt(rec, side), hover: @hover_side == side)
    end
  end
  def hit_side_button(view, x, y)
    return nil if KSU::Sheet.hidden?(@flag29)
    rec = record_for(@flag29)
    return nil unless rec
    [:left, :right].find { |side| KSU::View.button_hit?(view, side_button_pt(rec, side), x, y) }
  end
  def hit_delete_button(view, x, y)
    return false if KSU::Sheet.hidden?(@flag29)
    return false unless KSU::Sheet.empty?(@flag29)
    rec = record_for(@flag29)
    return false unless rec
    KSU::View.button_hit?(view, KSU::View.center_of(rec[:top_corners]), x, y)
  end
  def delete_sheet
    return unless KSU::Sheet.empty?(@flag29)
    sheet_ix = @flag29.get_attribute("ABF", "sheet-id")
    return unless sheet_ix
    KSU.start
    ok = KSU::Sheet.erase_sheet(@nesting, sheet_ix)
    KSU.commit
    return unless ok
    @flag40 = false
    select_sheet_id(nil)
  end
  def move_sheet(side)
    grp = @flag29
    rec = record_for(grp)
    return unless rec
    arr = KSU::Sheet.row_of(grp, @arr24)
    ix = arr.index(grp) || 0
    offset = KSU::Sheet.row_offset(rec, arr, ix, @arr24)
    tr2 = grp.transformation
    grp3 = KSU::Sheet.bottom_of(grp, @nesting)
    tr = (grp3&.valid?) ? grp3.transformation : nil
    arr2, tr3, base_tr2 = if side == :right
        [
          arr[(ix + 1)..-1] || [],
          Geom::Transformation.translation(offset) * tr2,
          tr ? Geom::Transformation.translation(offset) * tr : nil,
        ]
      else
        [arr[ix..-1] || [], tr2, tr]
      end
    arr3 = arr2.each_with_object({}) do |s, elem|
      elem[s] = KSU::Sheet.sheet_labels(s, @nesting) if s && s.valid?
    end
    labels = KSU::Sheet.sheet_labels(grp, @nesting)
    KSU.start
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(offset) * s.transformation
      KSU::Sheet.shift_dims(arr3[s] || [], offset, @nesting)
      bottom = KSU::Sheet.bottom_of(s, @nesting)
      bottom.transformation = Geom::Transformation.translation(offset) * bottom.transformation if bottom&.valid?
    end
    str2 = KSU::Sheet.sheet_no(grp.name.to_s)
    new_id = str2 ? (side == :left ? str2 : str2 + 1) : nil
    KSU::Sheet.shift_sheets(@nesting, new_id, +1) if new_id
    grp2 = KSU::Sheet.clone_sheet_shell(grp, tr3, @nesting)
    if grp2
      if new_id
        str = "sheet-#{new_id}"
        grp2.name = str
        grp2.set_attribute("ABF", "sheet-id", new_id)
      end
      pt = tr3.origin - tr2.origin
      arr4 = KSU::Sheet.rebuild_dims(labels, pt, @nesting)
      arr4.each { |len2d| KSU::Sheet.set_dim_text(len2d, str) } if new_id
      if grp3 && base_tr2
        grp4 = KSU::Sheet.clone_sheet_shell(grp3, base_tr2, @nesting)
        if grp4
          if new_id
            grp4.name = "#{str}-bottom"
            grp4.set_attribute("ABF", "sheet-id", new_id)
          else
            grp4.name = grp2.name.to_s + "-bottom"
          end
        end
      end
    end
    KSU.commit
    @flag29 = grp2 if grp2 && grp2.valid?
    sheet_list(@nesting)
    rebuild_geom
  end
  def name_rect(view, rec)
    outer = rec[:top_corners].map { |pt3| view.screen_coords(pt3) }
    arr = outer.map(&:x)
    arr2 = outer.map(&:y)
    cx = (arr.min + arr.max) / 2.0
    _e4f12bf3 = arr2.max + 2
    row_w = [rec[:instance].name.to_s.length * 7, 56].max
    { left: cx - row_w / 2.0, right: cx + row_w / 2.0, top: _e4f12bf3, bottom: _e4f12bf3 + 20 }
  end
  def near_outline?(view, x, y, rec)
    outer = rec[:top_corners].map { |pt3| view.screen_coords(pt3) }
    n = outer.length
    n.times.any? { |i| KSU::View.near_seg?(x, y, outer[i], outer[(i + 1) % n], 8) }
  end
  def reorder_sheet(dir)
    bbox = false
    case dir
    when :first then bbox = true while reorder_step(:prev)
    when :last then bbox = true while reorder_step(:next)
    else bbox = reorder_step(dir)
    end
    rebuild_overlaps if bbox
  end
  def reorder_step(dir)
    sheets = KSU::Sheet.row_of(@flag29, @arr24)
    ix = sheets.index(@flag29)
    return false unless ix
    target = case dir
      when :prev then ix > 0 ? sheets[ix - 1] : nil
      when :next then ix < sheets.length - 1 ? sheets[ix + 1] : nil
      end
    return false unless target
    swap_sheets(@flag29, target)
    @flag29 = target if target.valid?
    sheet_list(@nesting)
    true
  end
  def swap_sheets(vec, vec2)
    return if vec == vec2
    return unless vec && vec.valid? && vec2 && vec2.valid?
    KSU.start
    both_front = !(KSU::Sheet.bottom_sheet?(vec) || KSU::Sheet.bottom_sheet?(vec2))
    flag = both_front ? KSU::Sheet.bottom_for(vec, @nesting) : nil
    flag2 = both_front ? KSU::Sheet.bottom_for(vec2, @nesting) : nil
    swap_panels(vec, vec2)
    if both_front
      shift_bottoms(vec, vec2, flag, flag2)
      swap_edit_offsets(vec, vec2)
    end
    KSU.commit
  end
  def swap_edit_offsets(_32df3318, _9f80dd61)
    off_a = KSU::Sheet.edit_offset(_32df3318)
    off_b = KSU::Sheet.edit_offset(_9f80dd61)
    return if off_a.nil? && off_b.nil?
    [[_32df3318, off_b], [_9f80dd61, off_a]].each do |s, table_off|
      table_off ? s.set_attribute("KSU", "nest_edit_offset", table_off) : s.delete_attribute("KSU", "nest_edit_offset")
    end
  end
  def swap_panels(_32df3318, _9f80dd61)
    arr, ents = [_32df3318, _9f80dd61].map { |s| s.definition.entities.to_a.select { |e| KSU::Nesting.nest_panel?(e) } }
    arr.each { |vec| KSU::Nesting.clone_panel_into(vec, _9f80dd61) if vec.valid? }
    ents.each { |vec| KSU::Nesting.clone_panel_into(vec, _32df3318) if vec.valid? }
  end
  def shift_bottoms(grp4, grp3, grp, grp2)
    return unless grp || grp2
    delta = grp3.transformation.origin - grp4.transformation.origin
    str = KSU::Sheet.sheet_no(grp4.name.to_s)
    str2 = KSU::Sheet.sheet_no(grp3.name.to_s)
    if grp && grp.valid?
      grp.transformation = Geom::Transformation.translation(delta) * grp.transformation
      grp.name = grp3.name.to_s + "-bottom"
      grp.set_attribute("ABF", "sheet-id", str2) if str2
    end
    if grp2 && grp2.valid?
      grp2.transformation = Geom::Transformation.translation(Geom::Vector3d.new(-delta.x, -delta.y, -delta.z)) * grp2.transformation
      grp2.name = grp4.name.to_s + "-bottom"
      grp2.set_attribute("ABF", "sheet-id", str) if str
    end
  end
  def push_back(rec5, pt, pt3)
    num = pt3.length.to_f
    return if num < KSU::TOL || pt.length.to_f < KSU::TOL
    tx = -pt3.y.to_f / num
    ty = pt3.x.to_f / num
    num2 = pt.x.to_f * tx + pt.y.to_f * ty
    return if num2.abs < KSU::TOL
    pt2 = Geom::Vector3d.new(tx * num2, ty * num2, 0)
    shift_by(pt2)
    arr = compute_push_back(rec5)
    num3 = arr.length.to_f
    return if num3 < KSU::TOL
    shift_by(num3 > num + KSU::TOL ? Geom::Vector3d.new(-pt2.x.to_f, -pt2.y.to_f, 0) : arr)
  end
  def swap_sheet_type(dir)
    forward = dir == :up
    return swap_part_type(forward) unless @flag29.get_attribute("KSU", "phan").nil?
    sheet_ix = @flag29.get_attribute("ABF", "sheet-id")
    return unless sheet_ix
    return unless KSU::Sheet.next_type(@nesting, forward, sheet_ix)
    KSU.start
    new_id = KSU::Sheet.swap_type_block(@nesting, forward, sheet_ix)
    KSU.commit
    select_sheet_id(new_id)
  end
  def swap_part_type(forward)
    target = KSU::Sheet.next_part_sheet(@nesting, @flag29, forward)
    return unless target && target.valid?
    swap_sheets(@flag29, target)
    @flag29 = target if target.valid?
    sheet_list(@nesting)
    rebuild_overlaps
  end
  def select_sheet_id(new_id)
    sheet_list(@nesting)
    @flag29 = nil
    if new_id
      arr, = KSU::Sheet.sheet_maps(@nesting)
      @flag29 = arr[new_id] if arr[new_id] && arr[new_id].valid?
    end
    rebuild_overlaps
  end
end
KSU::Xeptam.include(KSU::Arrange)
require "digest"
module KSU::Arrange
  def self.normalize_hw_id(id_str)
    return nil unless KSU::Detail.has_id?(id_str)
    Digest::SHA256.hexdigest(id_str.to_s).upcase[0, 16].scan(/.{4}/).join("-")
  end
end
