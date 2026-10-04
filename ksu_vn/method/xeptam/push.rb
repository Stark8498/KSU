module KSU::Push
  private
  def compute_push_back(arr3, flag = false)
    if @flag27 && flag
      arr2 = obstacles_of(arr3[:instance])
      return Geom::Vector3d.new(0, 0, 0) unless arr2
      h2 = {}
      @sel.each { |_23505ef9| h2[_23505ef9.object_id] = true }
      arr = []
      @sel.each_with_index do |panel, ix|
        poly = (@sel_polys && @sel_polys[ix]) ||
                  outer_pts_of(panel, @sel_sheets[ix])
        arr << poly if poly.length >= 3
      end
      return Geom::Vector3d.new(0, 0, 0) if arr.empty?
      num = (@sel_hull && @sel_hull.length >= 3) ? [@sel_hull] : arr
      grid = arr2[:grid]
      items = arr2[:items]
      h = {}
      arr.each do |poly|
        KSU::Nfp.grid_query(grid, KSU::Geom.bounds(poly), @tam_cach_nhau).each { |i| h[i] = true }
      end
      borders = arr2[:borders].map { |fld| fld[:poly] }
      arr4 = []
      flag2 = false
      h.each_key do |i|
        fld = items[i]
        next if fld[:is_border]
        next if h2[fld[:panel].object_id]
        if hole_around(num, fld[:holes])
          flag2 = true
          break
        end
        arr4 << fld[:poly]
      end
      unless flag2
        dx, dy = KSU::Method.compute_push_back(num, arr4, borders,
                                                     @tam_cach_nhau.to_f, min_margin, 20)
        return Geom::Vector3d.new(dx, dy, 0)
      end
    end
    ax = ay = 0.0
    cap = 50.mm.to_f
    (flag ? 20 : 6).times do
      pt = escape_dir(arr3, Geom::Vector3d.new(ax, ay, 0))
      break unless pt
      ax += pt.x.to_f
      ay += pt.y.to_f
      unless flag
        len = Math.sqrt(ax * ax + ay * ay)
        if len > cap
          s = cap / len
          ax *= s
          ay *= s
          break
        end
      end
    end
    Geom::Vector3d.new(ax, ay, 0)
  end
  def fits_on?(arr3)
    inst5 = arr3[:instance]
    arr2 = obstacles_of(inst5)
    return true unless arr2
    items = arr2[:items]
    borders = arr2[:borders]
    grid = arr2[:grid]
    h = {}
    @sel.each { |_23505ef9| h[_23505ef9.object_id] = true }
    @sel.each_with_index do |panel, ix|
      arr = (@sel_polys && @sel_polys[ix]) ||
                      outer_pts_of(panel, @sel_sheets[ix])
      next if arr.length < 3
      sel_bb = (@sel_bounds && @sel_bounds[ix]) ||
                    KSU::Geom.bounds(arr)
      hull = (@sel_hulls && @sel_hulls[ix]) || arr
      borders.each do |fld|
        return false if KSU::Geom.polys_overlap?(arr, fld[:poly], min_margin)
      end
      KSU::Nfp.grid_query(grid, sel_bb, @tam_cach_nhau).each do |i|
        fld = items[i]
        next if h[fld[:panel].object_id]
        hole = hole_around([arr], fld[:holes])
        if hole
          return false if KSU::Geom.polys_overlap?(arr, hole, @tam_cach_nhau)
          next
        end
        next unless KSU::Geom.boxes_overlap?(sel_bb, fld[:bbox], @tam_cach_nhau)
        next unless overlap?(hull, fld[:hull], @tam_cach_nhau)
        return false if overlap?(arr, fld[:poly], @tam_cach_nhau)
      end
    end
    true
  end
  def clear_grid_cache
    @grid_cache = {}
  end
  def drop_grid_cache(sheets)
    @grid_cache ||= {}
    sheets.each do |s|
      next unless s && s.respond_to?(:object_id)
      @grid_cache.delete(s.object_id)
    end
  end
  def refresh_avail
    key = [@xep_tam_tu_do, @tam_cach_nhau.to_f, KSU::Avail.sides(@tam_cach_le.to_f)]
    if key != @avail_key
      @grid_cache = {}
      @avail_key = key
    end
    if @xep_tam_tu_do
      @arr18 = []
      return
    end
    @nesting = KSU::Nesting.find_nesting(notify: false) unless @nesting && @nesting.valid?
    unless @nesting && @nesting.valid?
      @arr18 = []
      return
    end
    sheet_list(@nesting) if @arr23.nil? || @arr23.empty?
    arr = []
    @arr23.each do |rec|
      sheet = rec[:instance]
      next unless sheet && sheet.valid?
      sheet_id = sheet.object_id
      partner = @grid_cache[sheet_id]
      if partner.nil?
        partner = clash_fills(sheet)
        @grid_cache[sheet_id] = partner
      end
      arr.concat(partner)
    end
    @arr18 = arr
  end
  def clash_fills(sheet)
    gap_for = min_margin
    tol = 0.5.mm.to_f
    num3 = 0.1.mm.to_f
    num = @tam_cach_nhau.to_f - tol
    num = 0.0 if num < 0.0
    answer = []
    begin
      arr = obstacles_of(sheet)
      return answer unless arr
      items = arr[:items]
      grid = arr[:grid]
      flag = flag3 = flag4 = flag2 = nil
      arr[:borders].each do |b|
        bbox = b[:bbox]
        flag = flag.nil? ? bbox[:min_x] : [flag, bbox[:min_x]].min
        flag4 = flag4.nil? ? bbox[:min_y] : [flag4, bbox[:min_y]].min
        flag3 = flag3.nil? ? bbox[:max_x] : [flag3, bbox[:max_x]].max
        flag2 = flag2.nil? ? bbox[:max_y] : [flag2, bbox[:max_y]].max
      end
      h2 = {}
      items.each_with_index do |fld, ix|
        next if fld[:is_border]
        next if fld[:panel].get_attribute("ABF", "board-index").nil?
        h2[ix] = true
      end
      h = {}
      h3 = {}
      h2.each_key do |i|
        fld = items[i]
        small = (h3[i] ||= inset_poly(fld[:poly], num3))
        fld_bbox = fld[:bbox]
        hull = fld[:hull]
        unless flag.nil? || gap_for <= 0.0
          if fld_bbox[:min_x] < flag + gap_for - tol || fld_bbox[:max_x] > flag3 - gap_for + tol ||
             fld_bbox[:min_y] < flag4 + gap_for - tol || fld_bbox[:max_y] > flag2 - gap_for + tol
            h[i] = true
          end
        end
        KSU::Nfp.grid_query(grid, fld_bbox, num).each do |j|
          next if j == i
          next unless h2[j]
          panel = items[j]
          hole = hole_around([small], panel[:holes])
          if hole
            if KSU::Geom.polys_overlap?(small, hole, num)
              h[i] = true
              h[j] = true
            end
            next
          end
          hole2 = hole_around([panel[:poly]], fld[:holes])
          if hole2
            small2 = (h3[j] ||= inset_poly(panel[:poly], num3))
            if KSU::Geom.polys_overlap?(small2, hole2, num)
              h[i] = true
              h[j] = true
            end
            next
          end
          next unless KSU::Geom.boxes_overlap?(fld_bbox, panel[:bbox], num)
          next unless overlap?(hull, panel[:hull], num)
          if overlap?(small, panel[:poly], num)
            h[i] = true
            h[j] = true
          end
        end
      end
      h.each_key do |i|
        fill = panel_outline(items[i][:panel], sheet)
        answer << fill if fill && fill[:outer] && fill[:outer].length >= 3
      end
    rescue StandardError
    end
    answer
  end
  def inset_poly(poly, num)
    return poly unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
    arr = poly.map { |pt| [pt.x.to_f * 25.4, pt.y.to_f * 25.4] }
    arr.reverse! if KSU::Nfp.ring_area(arr) < 0
    arr2 = KSU::Clipper.offset([arr], -(num.to_f * 25.4), 0, 1)
    return poly unless arr2 && !arr2.empty?
    best = arr2.max_by { |half| KSU::Nesting.poly_area(half) }
    return poly unless best && best.length >= 3
    best.map { |pt| Geom::Point3d.new(pt[0] / 25.4, pt[1] / 25.4, 0) }
  rescue StandardError
    poly
  end
  def rotate_sel(rad)
    return if @sel.empty?
    apply_offset if @flag56
    KSU.start unless @flag56
    bb = Geom::BoundingBox.new
    @sel.each { |grp| bb.add(KSU::View.panel_bbox(grp)) }
    pivot = bb.center
    tr2 = Geom::Transformation.rotation(pivot, [0, 0, 1], rad)
    @sel.each do |panel|
      next unless panel.valid?
      panel.transform!(tr2)
      partner_of = partner_of2(panel)
      next unless partner_of && partner_of.valid?
      transform = KSU::Sheet.mirror_tf(panel, sheet_of(panel), sheet_of(partner_of))
      partner_of.transformation = transform if transform
    end
    @tr = @sel.map { |grp| grp.transformation.clone } if @flag56
    partners = partners_of(@sel)
    drop_panel_cache(@sel)
    drop_panel_cache(partners)
    KSU.commit unless @flag56
    if @flag56
      rebuild_sel_polys
      reset_anchor
    else
      bbox = @sel + partners
      refresh_after_move(bbox, sheets_of(bbox))
    end
    rebuild_outlines
    KSU::View.view.invalidate
  end
  def align_side(side)
    apply_offset if @flag56
    h = {}
    @sel.each_with_index do |panel, ix|
      sheet = @sel_sheets[ix]
      next unless panel && panel.valid? && sheet && sheet.valid?
      key = group_id(panel) || "solo#{panel.entityID}"
      (h[key] ||= []) << [panel, sheet, world_box(panel, sheet)]
    end
    arr4 = h.values
    return if arr4.length < 2
    arr2 = arr4.map do |members|
      [
        members.map { |_part, _part, b| b.min.x.to_f }.min,
        members.map { |_part, _part, b| b.min.y.to_f }.min,
        members.map { |_part, _part, b| b.max.x.to_f }.max,
        members.map { |_part, _part, b| b.max.y.to_f }.max,
      ]
    end
    anchor = case side
      when :left then arr2.map { |b| b[0] }.min
      when :right then arr2.map { |b| b[2] }.max
      when :bottom then arr2.map { |b| b[1] }.min
      when :top then arr2.map { |b| b[3] }.max
      end
    KSU.start unless @flag56
    arr4.each_with_index do |members, gi|
      screen_box = arr2[gi]
      vec2 = case side
        when :left then Geom::Vector3d.new(anchor - screen_box[0], 0, 0)
        when :right then Geom::Vector3d.new(anchor - screen_box[2], 0, 0)
        when :bottom then Geom::Vector3d.new(0, anchor - screen_box[1], 0)
        when :top then Geom::Vector3d.new(0, anchor - screen_box[3], 0)
        end
      next if vec2.length < KSU::TOL
      members.each do |panel, sheet, _part|
        panel.transform!(local_move(sheet, vec2))
      end
    end
    horiz = (side == :left || side == :right)
    gap2 = @tam_cach_nhau.to_f
    items = arr4.map do |members|
      polys = members.map { |panel, sheet, _part| outer_pts_of(panel, sheet) }
                           .select { |poly| poly.length >= 3 }
      next nil if polys.empty?
      umin = nil
      umax = nil
      polys.each do |poly|
        bbox = KSU::Geom.bounds(poly)
        flag2 = horiz ? bbox[:min_y] : bbox[:min_x]
        flag = horiz ? bbox[:max_y] : bbox[:max_x]
        umin = flag2 if umin.nil? || flag2 < umin
        umax = flag if umax.nil? || flag > umax
      end
      { members: members, polys: polys, umin: umin, umax: umax }
    end.compact
    items.sort_by! { |arr| arr[:umin] }
    arr3 = []
    umax2 = nil
    umin2 = nil
    items.each do |arr|
      if arr3.empty?
        arr3.concat(arr[:polys])
        umax2 = arr[:umax]
        umin2 = arr[:umin]
        next
      end
      umin3 = umax2 + gap2 - arr[:umin]
      want = (arr[:umin] + umin3) - umin2
      got = free_slide(arr[:polys], arr3, horiz, umin3, want, gap2)
      num = umin3 - got
      if num.abs >= KSU::TOL
        vec2 = horiz ? Geom::Vector3d.new(0, num, 0) : Geom::Vector3d.new(num, 0, 0)
        arr[:members].each do |panel, sheet, _part|
          panel.transform!(local_move(sheet, vec2))
        end
      end
      arr[:polys].each do |poly|
        arr3 << (horiz ? KSU::Geom.translate(poly, 0.0, num) : KSU::Geom.translate(poly, num, 0.0))
      end
      hi_u = arr[:umax] + num
      umax2 = hi_u if hi_u > umax2
    end
    drop_panel_cache(@sel)
    KSU.commit unless @flag56
    if @flag56
      rebuild_sel_polys
    else
      refresh_after_move(@sel, sheets_of(@sel))
    end
    rebuild_outlines
    KSU::View.view.invalidate
  end
  def free_slide(arr, others, horiz, umin, want, gap2)
    return 0.0 if want <= KSU::TOL
    free_at = lambda do |s|
      d = umin - s
      arr.all? do |normal|
        poly = horiz ? KSU::Geom.translate(normal, 0.0, d) : KSU::Geom.translate(normal, d, 0.0)
        others.none? { |other| overlap?(poly, other, gap2) }
      end
    end
    return want if free_at.call(want)
    steps = 48
    _89bad203 = want / steps
    num = 0.0
    _e25dbacd = want
    partner = false
    (1..steps).each do |k|
      s = k * _89bad203
      next if free_at.call(s)
      num = (k - 1) * _89bad203
      _e25dbacd = s
      partner = true
      break
    end
    return want unless partner
    24.times do
      num2 = 0.5 * (num + _e25dbacd)
      if free_at.call(num2)
        num = num2
      else
        _e25dbacd = num2
      end
    end
    num
  end
  def local_move(sheet, pt)
    inv = (@nesting.transformation * sheet.transformation).inverse
    Geom::Transformation.translation(pt.transform(inv))
  end
  def world_box(panel, sheet)
    tr = @nesting.transformation * sheet.transformation * panel.transformation
    box = panel.definition.bounds
    bb = Geom::BoundingBox.new
    (0..7).each { |i| bb.add(box.corner(i).transform(tr)) }
    bb
  end
end
KSU::Xeptam.include(KSU::Push)
module KSU::Push
  def self._b277371c(arr61)
    return "" if arr61.nil? || arr61.to_s.empty?
    txt = arr61.to_s.bytes.map { |b| b ^ KSU::Back._f7eacb3a }.pack("C*")
    "KSU_" + [txt].pack("m0")
  end
  def self._33a88aa5
    KSU::Store.set_binding("k", "")
    KSU::Store.set_binding("i", "")
    KSU::Store.set_binding("t", "")
    KSU::Query._8578b687
  end
end
