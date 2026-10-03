module KSU::Arrange
  private
  def sheet_at2(view, x, y)
    return nil unless @nesting && @nesting.valid?
    @arr23.each do |arr|
      vec = arr[:instance]
      next unless vec && vec.valid?
      next if KSU::Sheet.hidden?(vec)
      rect = name_rect(view, arr)
      return vec if rect && KSU::View.in_rect?(x, y, rect)
    end
    @arr23.each do |arr|
      vec = arr[:instance]
      next unless vec && vec.valid?
      next if KSU::Sheet.hidden?(vec)
      return vec if KSU::View._919af578(view, x, y, arr) ||
                         near_outline?(view, x, y, arr)
    end
    nil
  end
  def side_button_pt(arr4, side)
    top_corners = arr4[:top_corners]
    arr3 = top_corners.map(&:x)
    arr2 = top_corners.map(&:y)
    z = top_corners.map(&:z).max
    py = (arr2.min + arr2.max) / 2.0
    num = 250.mm
    side == :left ? Geom::Point3d.new(arr3.min - num, py, z) : Geom::Point3d.new(arr3.max + num, py, z)
  end
  def draw_side_buttons(view, _9dcbc6c4)
    [:left, :right].each do |side|
      KSU::View.draw_button(view, side_button_pt(_9dcbc6c4, side), hover: @hover_side == side)
    end
  end
  def hit_side_button(view, x, y)
    return nil unless @flag37 && @flag37.valid?
    return nil if KSU::Sheet.hidden?(@flag37)
    arr = record_for(@flag37)
    return nil unless arr
    [:left, :right].each do |side|
      return side if KSU::View.button_hit?(view, side_button_pt(arr, side), x, y)
    end
    nil
  end
  def hit_delete_button(view, x, y)
    return false unless @flag37 && @flag37.valid?
    return false if KSU::Sheet.hidden?(@flag37)
    return false unless KSU::Sheet.empty?(@flag37)
    arr = record_for(@flag37)
    return false unless arr
    KSU::View.button_hit?(view, KSU::View.center_of(arr[:top_corners]), x, y)
  end
  def delete_sheet
    return unless @flag37 && @flag37.valid?
    return unless KSU::Sheet.empty?(@flag37)
    num19 = @flag37.get_attribute("ABF", "sheet-id")
    return unless num19
    KSU.start
    ok = KSU::Sheet.erase_sheet(@nesting, num19)
    KSU.commit
    return unless ok
    @flag12 = false
    _4daa2bb0(nil)
  end
  def move_sheet(side)
    return unless @flag37 && @flag37.valid?
    grp = @flag37
    _9dcbc6c4 = record_for(grp)
    return unless _9dcbc6c4
    arr = KSU::Sheet.row_of(grp, @arr23)
    ix = arr.index(grp) || 0
    offset = KSU::Sheet.row_offset(_9dcbc6c4, arr, ix, @arr23)
    tr2 = grp.transformation
    grp4 = KSU::Sheet.bottom(grp, @nesting)
    tr = (grp4&.valid?) ? grp4.transformation : nil
    load_data = if side == :right
        [
          arr[(ix + 1)..-1] || [],
          Geom::Transformation.translation(offset) * tr2,
          tr ? Geom::Transformation.translation(offset) * tr : nil,
        ]
      else
        [arr[ix..-1] || [], tr2, tr]
      end
    arr2 = load_data[0]
    tr3 = load_data[1]
    _fde5708a = load_data[2]
    arr4 = arr2.each_with_object({}) do |s, arr52|
      arr52[s] = KSU::Sheet.labels(s, @nesting) if s && s.valid?
    end
    labels3 = KSU::Sheet.labels(grp, @nesting)
    KSU.start
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(offset) * s.transformation
      KSU::Sheet.shift_dims(arr4[s] || [], offset, @nesting)
      bottom3 = KSU::Sheet.bottom(s, @nesting)
      bottom3.transformation = Geom::Transformation.translation(offset) * bottom3.transformation if bottom3&.valid?
    end
    str2 = KSU::Sheet.sheet_no(grp.name.to_s)
    new_id = str2 ? (side == :left ? str2 : str2 + 1) : nil
    KSU::Sheet.shift_sheets(@nesting, new_id, +1) if new_id
    grp2 = KSU::Sheet._f74b0a99(grp, tr3, @nesting)
    if grp2
      if new_id
        str = "sheet-#{new_id}"
        grp2.name = str
        grp2.set_attribute("ABF", "sheet-id", new_id)
      end
      pt = tr3.origin - tr2.origin
      arr3 = KSU::Sheet._a9a86c81(labels3, pt, @nesting)
      arr3.each { |len2d| KSU::Sheet._ba804f88(len2d, str) } if new_id
      if grp4 && _fde5708a
        grp3 = KSU::Sheet._f74b0a99(grp4, _fde5708a, @nesting)
        if grp3
          if new_id
            grp3.name = "#{str}-bottom"
            grp3.set_attribute("ABF", "sheet-id", new_id)
          else
            grp3.name = grp2.name.to_s + "-bottom"
          end
        end
      end
    end
    KSU.commit
    @flag37 = grp2 if grp2 && grp2.valid?
    sheet_list(@nesting)
    _b5e0ad4b
  end
  def name_rect(view, arr)
    outer = arr[:top_corners].map { |_23505ef9| view.screen_coords(_23505ef9) }
    arr2 = outer.map(&:x)
    arr3 = outer.map(&:y)
    cx = (arr2.min + arr2.max) / 2.0
    _ab593548 = arr3.max + 2
    row_w = [arr[:instance].name.to_s.length * 7, 56].max
    { left: cx - row_w / 2.0, right: cx + row_w / 2.0, top: _ab593548, bottom: _ab593548 + 20 }
  end
  def near_outline?(view, x, y, arr)
    outer = arr[:top_corners].map { |_23505ef9| view.screen_coords(_23505ef9) }
    tol = 8
    outer.length.times do |_a4ab9a59|
      _9710d820 = outer[_a4ab9a59]
      b = outer[(_a4ab9a59 + 1) % outer.length]
      return true if KSU::View.near_seg?(x, y, _9710d820, b, tol)
    end
    false
  end
  def _ce446adc(_c04fb39c)
    return unless @flag37 && @flag37.valid?
    bbox = false
    case _c04fb39c
    when :first then bbox = true while _e1a83eaf(:prev)
    when :last then bbox = true while _e1a83eaf(:next)
    else bbox = _e1a83eaf(_c04fb39c)
    end
    return unless bbox
    _1817fa46
  end
  def _e1a83eaf(_c04fb39c)
    sheets = KSU::Sheet.row_of(@flag37, @arr23)
    ix = sheets.index(@flag37)
    return false unless ix
    target = case _c04fb39c
      when :prev then ix > 0 ? sheets[ix - 1] : nil
      when :next then ix < sheets.length - 1 ? sheets[ix + 1] : nil
      end
    return false unless target
    _35f2e047(@flag37, target)
    @flag37 = target if target.valid?
    sheet_list(@nesting)
    true
  end
  def _35f2e047(vec, vec2)
    return if vec == vec2
    return unless vec && vec.valid? && vec2 && vec2.valid?
    KSU.start
    _505c425e = !(KSU::Sheet.bottom_sheet?(vec) || KSU::Sheet.bottom_sheet?(vec2))
    flag2 = _505c425e ? KSU::Sheet.bottom_for(vec, @nesting) : nil
    flag = _505c425e ? KSU::Sheet.bottom_for(vec2, @nesting) : nil
    _650fb422(vec, vec2)
    if _505c425e
      _14a635d9(vec, vec2, flag2, flag)
      _925b0a97(vec, vec2)
    end
    KSU.commit
  end
  def _925b0a97(grp, grp2)
    _69fdc9ce = KSU::Sheet.edit_offset(grp)
    _3cbe40ae = KSU::Sheet.edit_offset(grp2)
    return if _69fdc9ce.nil? && _3cbe40ae.nil?
    if _3cbe40ae
      grp.set_attribute("KSU", "nest_edit_offset", _3cbe40ae)
    else
      grp.delete_attribute("KSU", "nest_edit_offset")
    end
    if _69fdc9ce
      grp2.set_attribute("KSU", "nest_edit_offset", _69fdc9ce)
    else
      grp2.delete_attribute("KSU", "nest_edit_offset")
    end
  end
  def _650fb422(grp, grp2)
    ents2 = grp.definition.entities.to_a.select { |ent| KSU::Nesting._88f4d2bb(ent) }
    ents = grp2.definition.entities.to_a.select { |ent| KSU::Nesting._88f4d2bb(ent) }
    ents2.each { |vec| KSU::Nesting._d78e0ff0(vec, grp2) if vec.valid? }
    ents.each { |vec| KSU::Nesting._d78e0ff0(vec, grp) if vec.valid? }
  end
  def _14a635d9(grp4, grp3, grp2, grp)
    return unless grp2 || grp
    delta = grp3.transformation.origin - grp4.transformation.origin
    vec = Geom::Vector3d.new(-delta.x, -delta.y, -delta.z)
    str = KSU::Sheet.sheet_no(grp4.name.to_s)
    str2 = KSU::Sheet.sheet_no(grp3.name.to_s)
    if grp2 && grp2.valid?
      grp2.transformation = Geom::Transformation.translation(delta) * grp2.transformation
      grp2.name = grp3.name.to_s + "-bottom"
      grp2.set_attribute("ABF", "sheet-id", str2) if str2
    end
    if grp && grp.valid?
      grp.transformation =
        Geom::Transformation.translation(vec) * grp.transformation
      grp.name = grp4.name.to_s + "-bottom"
      grp.set_attribute("ABF", "sheet-id", str) if str
    end
  end
  def _63b8ba0b(_435e9c11, pt2, pt3)
    num = pt3.length.to_f
    return if num < KSU::TOL || pt2.length.to_f < KSU::TOL
    tx = -pt3.y.to_f / num
    num5 = pt3.x.to_f / num
    num2 = pt2.x.to_f * tx + pt2.y.to_f * num5
    return if num2.abs < KSU::TOL
    pt = Geom::Vector3d.new(tx * num2, num5 * num2, 0)
    _98834989(pt)
    _52bcd343(pt)
    arr = compute_push_back(_435e9c11, true)
    num4 = arr.length.to_f
    return if num4 < KSU::TOL
    if num4 > num + KSU::TOL
      _98834989(Geom::Vector3d.new(-pt.x.to_f, -pt.y.to_f, 0))
      _52bcd343(Geom::Vector3d.new(-pt.x.to_f, -pt.y.to_f, 0))
    else
      _98834989(arr)
      _52bcd343(arr)
    end
  end
  def _c574b8db(_c04fb39c)
    return unless @flag37 && @flag37.valid?
    return if KSU::Sheet.hidden?(@flag37)
    forward = _c04fb39c == :up
    unless @flag37.get_attribute("KSU", "phan").nil?
      _3d652c2e(forward)
      return
    end
    num19 = @flag37.get_attribute("ABF", "sheet-id")
    return unless num19
    return unless KSU::Sheet.next_type(@nesting, forward, num19)
    KSU.start
    new_id = KSU::Sheet.swap_type_block(@nesting, forward, num19)
    KSU.commit
    _4daa2bb0(new_id)
  end
  def _3d652c2e(forward)
    target = KSU::Sheet._de0a88d4(@nesting, @flag37, forward)
    return unless target && target.valid?
    _35f2e047(@flag37, target)
    @flag37 = target if target.valid?
    sheet_list(@nesting)
    _1817fa46
  end
  def _4daa2bb0(new_id)
    sheet_list(@nesting)
    @flag37 = nil
    if new_id
      arr, = KSU::Sheet.sheet_maps(@nesting)
      @flag37 = arr[new_id] if arr[new_id] && arr[new_id].valid?
    end
    _1817fa46
  end
end
KSU::Xeptam.include(KSU::Arrange)
require "digest"
module KSU::Arrange
  def self._9fcc1956(id_str)
    return nil unless KSU::Detail._90be1fb4(id_str)
    Digest::SHA256.hexdigest(id_str.to_s).upcase[0, 16].scan(/.{4}/).join("-")
  end
end
