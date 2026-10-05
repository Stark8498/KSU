module KSU::Push
  private
  def compute_push_back(rec5)
    if @flag4
      arr = obstacles_of(rec5[:instance])
      return Geom::Vector3d.new(0, 0, 0) unless arr
      arr4 = @sel.to_h { |pt3| [pt3.object_id, true] }
      arr2 = @sel.each_with_index.map { |panel, ix| (@sel_polys && @sel_polys[ix]) || outer_pts_of(panel, @sel_sheets[ix]) }
                              .select { |poly| poly.length >= 3 }
      return Geom::Vector3d.new(0, 0, 0) if arr2.empty?
      num = (@sel_hull && @sel_hull.length >= 3) ? [@sel_hull] : arr2
      grid = arr[:grid]
      items = arr[:items]
      h = {}
      arr2.each do |poly|
        KSU::Nfp.grid_query(grid, KSU::Geom.bounds(poly), @tam_cach_nhau).each { |i| h[i] = true }
      end
      borders = arr[:borders].map { |fld| fld[:poly] }
      flat = num.flatten(1)
      arr3 = []
      flag = false
      h.each_key do |i|
        fld = items[i]
        next if fld[:is_border]
        next if arr4[fld[:panel].object_id]
        if KSU::Nesting.holes_bounds(flat, fld[:holes])
          flag = true
          break
        end
        arr3 << fld[:poly]
      end
      unless flag
        dx, dy = KSU::Method.compute_push_back(num, arr3, borders,
                                                     @tam_cach_nhau.to_f, min_margin, 20)
        return Geom::Vector3d.new(dx, dy, 0)
      end
    end
    ax = ay = 0.0
    20.times do
      pt = escape_dir(rec5, Geom::Vector3d.new(ax, ay, 0))
      break unless pt
      ax += pt.x.to_f
      ay += pt.y.to_f
    end
    Geom::Vector3d.new(ax, ay, 0)
  end
  def fits_on?(rec5)
    inst5 = rec5[:instance]
    arr2 = obstacles_of(inst5)
    return true unless arr2
    items = arr2[:items]
    borders = arr2[:borders]
    grid = arr2[:grid]
    arr3 = @sel.to_h { |pt3| [pt3.object_id, true] }
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
        next if arr3[fld[:panel].object_id]
        _5020f2e5 = KSU::Nesting.holes_bounds(arr, fld[:holes])
        if _5020f2e5
          return false if KSU::Geom.polys_overlap?(arr, _5020f2e5, @tam_cach_nhau)
          next
        end
        next unless KSU::Geom.boxes_overlap?(sel_bb, fld[:bbox], @tam_cach_nhau)
        next unless KSU::Nesting.polygons_overlap?(hull, fld[:hull], @tam_cach_nhau)
        return false if KSU::Nesting.polygons_overlap?(arr, fld[:poly], @tam_cach_nhau)
      end
    end
    true
  end
  def clear_grid_cache
    @grid_cache = {}
  end
  def drop_grid_cache(sheets)
    @grid_cache ||= {}
    sheets.each { |s| @grid_cache.delete(s.object_id) if s }
  end
  def refresh_avail
    key = [@xep_tam_tu_do, @tam_cach_nhau.to_f, KSU::Avail.avail_map(@tam_cach_le.to_f)]
    if key != @avail_key
      @grid_cache = {}
      @avail_key = key
    end
    return @arr8 = [] if @xep_tam_tu_do
    @nesting = KSU::Nesting.find_nesting(notify: false) unless @nesting && @nesting.valid?
    return @arr8 = [] unless @nesting && @nesting.valid?
    sheet_list(@nesting) if @arr24.nil? || @arr24.empty?
    arr = []
    @arr24.each do |rec|
      vec = rec[:instance]
      next unless vec && vec.valid?
      arr.concat(@grid_cache[vec.object_id] ||= clash_fills(vec))
    end
    @arr8 = arr
  end
  def clash_fills(sheet)
    gap_for = min_margin
    tol = 0.5.mm.to_f
    eps = 0.1.mm.to_f
    num = @tam_cach_nhau.to_f - tol
    num = 0.0 if num < 0.0
    ok = []
    begin
      arr2 = obstacles_of(sheet)
      return ok unless arr2
      items = arr2[:items]
      grid = arr2[:grid]
      arr = arr2[:borders].map { |b| b[:bbox] }
      _0fdc7e1e, arr5 = arr.map { |b| b[:min_x] }.min, arr.map { |b| b[:max_x] }.max
      _33e31bae, arr4 = arr.map { |b| b[:min_y] }.min, arr.map { |b| b[:max_y] }.max
      arr3 = items.each_index.select { |ix3| !items[ix3][:is_border] && !items[ix3][:panel].get_attribute("ABF", "board-index").nil? }
                            .to_h { |ix3| [ix3, true] }
      h = {}
      h2 = {}
      arr3.each_key do |i|
        fld = items[i]
        _ac7c1b6d = (h2[i] ||= KSU::Nesting.grow_polygon(fld[:poly], eps))
        fld_bbox = fld[:bbox]
        hull = fld[:hull]
        unless _0fdc7e1e.nil? || gap_for <= 0.0
          if fld_bbox[:min_x] < _0fdc7e1e + gap_for - tol || fld_bbox[:max_x] > arr5 - gap_for + tol ||
             fld_bbox[:min_y] < _33e31bae + gap_for - tol || fld_bbox[:max_y] > arr4 - gap_for + tol
            h[i] = true
          end
        end
        KSU::Nfp.grid_query(grid, fld_bbox, num).each do |ix|
          next if ix == i
          next unless arr3[ix]
          panel = items[ix]
          hit = if (_5020f2e5 = KSU::Nesting.holes_bounds(_ac7c1b6d, panel[:holes]))
              KSU::Geom.polys_overlap?(_ac7c1b6d, _5020f2e5, num)
            elsif (_5020f2e5 = KSU::Nesting.holes_bounds(panel[:poly], fld[:holes]))
              KSU::Geom.polys_overlap?((h2[ix] ||= KSU::Nesting.grow_polygon(panel[:poly], eps)), _5020f2e5, num)
            else
              KSU::Geom.boxes_overlap?(fld_bbox, panel[:bbox], num) &&
                KSU::Nesting.polygons_overlap?(hull, panel[:hull], num) &&
                KSU::Nesting.polygons_overlap?(_ac7c1b6d, panel[:poly], num)
            end
          next unless hit
          h[i] = true
          h[ix] = true
        end
      end
      h.each_key do |i|
        fill = panel_outline(items[i][:panel], sheet)
        ok << fill if fill && fill[:outer] && fill[:outer].length >= 3
      end
    rescue StandardError
    end
    ok
  end
  def rotate_sel(rad)
    return if @sel.empty?
    apply_offset if @flag22
    KSU.start unless @flag22
    bb = Geom::BoundingBox.new
    @sel.each { |pt3| bb.add(KSU::View.panel_bbox(pt3)) }
    pivot = bb.center
    tr = Geom::Transformation.rotation(pivot, [0, 0, 1], rad)
    @sel.each do |panel|
      next unless panel.valid?
      panel.transform!(tr)
      partner_of = partner_of2(panel)
      next unless partner_of && partner_of.valid?
      _ac3b3b9d = KSU::Sheet.mirror_tf(panel, sheet_of(panel), sheet_of(partner_of))
      partner_of.transformation = _ac3b3b9d if _ac3b3b9d
    end
    partners = partners_of(@sel)
    drop_panel_cache(@sel + partners)
    KSU.commit unless @flag22
    if @flag22
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
    apply_offset if @flag22
    h = {}
    @sel.each_with_index do |panel, ix|
      vec = @sel_sheets[ix]
      next unless panel && panel.valid? && vec && vec.valid?
      key = group_id(panel) || "solo#{panel.entityID}"
      (h[key] ||= []) << [panel, vec, KSU::Geom.world_box(panel.definition.bounds, panel_tf(panel, vec))]
    end
    arr3 = h.values
    return if arr3.length < 2
    arr2 = arr3.map do |members|
      [
        members.map { |_item, _item, b| b.min.x.to_f }.min,
        members.map { |_item, _item, b| b.min.y.to_f }.min,
        members.map { |_item, _item, b| b.max.x.to_f }.max,
        members.map { |_item, _item, b| b.max.y.to_f }.max,
      ]
    end
    _ba5231eb = case side
      when :left then arr2.map { |b| b[0] }.min
      when :right then arr2.map { |b| b[2] }.max
      when :bottom then arr2.map { |b| b[1] }.min
      when :top then arr2.map { |b| b[3] }.max
      end
    KSU.start unless @flag22
    arr3.each_with_index do |members, gi|
      screen_box = arr2[gi]
      vec2 = case side
        when :left then Geom::Vector3d.new(_ba5231eb - screen_box[0], 0, 0)
        when :right then Geom::Vector3d.new(_ba5231eb - screen_box[2], 0, 0)
        when :bottom then Geom::Vector3d.new(0, _ba5231eb - screen_box[1], 0)
        when :top then Geom::Vector3d.new(0, _ba5231eb - screen_box[3], 0)
        end
      next if vec2.length < KSU::TOL
      members.each { |panel, vec, _item| panel.transform!(local_move(vec, vec2)) }
    end
    horiz = (side == :left || side == :right)
    gap2 = @tam_cach_nhau.to_f
    items = arr3.map do |members|
      polys = members.map { |panel, vec, _item| outer_pts_of(panel, vec) }
                           .select { |poly| poly.length >= 3 }
      next nil if polys.empty?
      arr5 = polys.map { |poly| KSU::Geom.bounds(poly) }
      umin = arr5.map { |bbox| horiz ? bbox[:min_y] : bbox[:min_x] }.min
      umax = arr5.map { |bbox| horiz ? bbox[:max_y] : bbox[:max_x] }.max
      { members: members, polys: polys, umin: umin, umax: umax }
    end.compact
    items.sort_by! { |arr| arr[:umin] }
    arr4 = []
    _3738c003 = nil
    umin2 = nil
    items.each do |arr|
      if arr4.empty?
        arr4.concat(arr[:polys])
        _3738c003 = arr[:umax]
        umin2 = arr[:umin]
        next
      end
      _152904a8 = _3738c003 + gap2 - arr[:umin]
      want = (arr[:umin] + _152904a8) - umin2
      _4e69d4a6 = free_slide(arr[:polys], arr4, horiz, _152904a8, want, gap2)
      num = _152904a8 - _4e69d4a6
      if num.abs >= KSU::TOL
        vec2 = horiz ? Geom::Vector3d.new(0, num, 0) : Geom::Vector3d.new(num, 0, 0)
        arr[:members].each { |panel, vec, _item| panel.transform!(local_move(vec, vec2)) }
      end
      arr[:polys].each { |poly| arr4 << (horiz ? KSU::Geom.translate(poly, 0.0, num) : KSU::Geom.translate(poly, num, 0.0)) }
      hi_u = arr[:umax] + num
      _3738c003 = hi_u if hi_u > _3738c003
    end
    drop_panel_cache(@sel)
    KSU.commit unless @flag22
    if @flag22
      rebuild_sel_polys
    else
      refresh_after_move(@sel, sheets_of(@sel))
    end
    rebuild_outlines
    KSU::View.view.invalidate
  end
  def free_slide(arr, _99a1df81, horiz, _152904a8, want, gap2)
    return 0.0 if want <= KSU::TOL
    free_at = lambda do |s|
      _75614023 = _152904a8 - s
      arr.all? do |normal|
        poly = horiz ? KSU::Geom.translate(normal, 0.0, _75614023) : KSU::Geom.translate(normal, _75614023, 0.0)
        _99a1df81.none? { |meet| KSU::Nesting.polygons_overlap?(poly, meet, gap2) }
      end
    end
    return want if free_at.call(want)
    _5d951b22 = want / 48
    k = (1..48).find { |ix| !free_at.call(ix * _5d951b22) }
    return want unless k
    _09dce564 = (k - 1) * _5d951b22
    _a5ffa708 = k * _5d951b22
    24.times do
      num = 0.5 * (_09dce564 + _a5ffa708)
      free_at.call(num) ? (_09dce564 = num) : (_a5ffa708 = num)
    end
    _09dce564
  end
  def local_move(grp, pt)
    inv = (@nesting.transformation * grp.transformation).inverse
    Geom::Transformation.translation(pt.transform(inv))
  end
end
KSU::Xeptam.include(KSU::Push)
module KSU::Push
  def self.pack_value(arr32)
    return "" if arr32.nil? || arr32.to_s.empty?
    txt = arr32.to_s.bytes.map { |b| b ^ KSU::Back.xor_key }.pack("C*")
    "KSU_" + [txt].pack("m0")
  end
  def self.clear_license
    KSU::Store.set_binding("k", "")
    KSU::Store.set_binding("i", "")
    KSU::Store.set_binding("t", "")
    KSU::Query.drop_id_cache2
  end
end
