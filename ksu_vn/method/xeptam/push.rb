module KSU::Push
  private
  def compute_push_back(arr3, flag = false)
    if @flag27 && flag
      arr2 = _1adb886a(arr3[:instance])
      return Geom::Vector3d.new(0, 0, 0) unless arr2
      h2 = {}
      @arr27.each { |_23505ef9| h2[_23505ef9.object_id] = true }
      arr = []
      @arr27.each_with_index do |panel, ix|
        poly = (@arr63 && @arr63[ix]) ||
                  _8e5202c8(panel, @arr12[ix])
        arr << poly if poly.length >= 3
      end
      return Geom::Vector3d.new(0, 0, 0) if arr.empty?
      num = (@arr53 && @arr53.length >= 3) ? [@arr53] : arr
      grid = arr2[:grid]
      items = arr2[:items]
      h = {}
      arr.each do |poly|
        KSU::Nfp._a6cf3d0d(grid, KSU::Geom.bounds(poly), @tam_cach_nhau).each { |_a4ab9a59| h[_a4ab9a59] = true }
      end
      borders = arr2[:borders].map { |fld| fld[:poly] }
      arr4 = []
      flag2 = false
      h.each_key do |_a4ab9a59|
        fld = items[_a4ab9a59]
        next if fld[:is_border]
        next if h2[fld[:panel].object_id]
        if _79fb30a5(num, fld[:holes])
          flag2 = true
          break
        end
        arr4 << fld[:poly]
      end
      unless flag2
        dx, dy = KSU::Method.compute_push_back(num, arr4, borders,
                                                     @tam_cach_nhau.to_f, _970aa8ae, 20)
        return Geom::Vector3d.new(dx, dy, 0)
      end
    end
    ax = ay = 0.0
    cap = 50.mm.to_f
    (flag ? 20 : 6).times do
      pt = _4237de17(arr3, Geom::Vector3d.new(ax, ay, 0))
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
  def _7f17a5c5(arr3)
    instance = arr3[:instance]
    arr2 = _1adb886a(instance)
    return true unless arr2
    items = arr2[:items]
    borders = arr2[:borders]
    grid = arr2[:grid]
    h = {}
    @arr27.each { |_23505ef9| h[_23505ef9.object_id] = true }
    @arr27.each_with_index do |panel, ix|
      arr = (@arr63 && @arr63[ix]) ||
                      _8e5202c8(panel, @arr12[ix])
      next if arr.length < 3
      _f38e85e6 = (@arr55 && @arr55[ix]) ||
                    KSU::Geom.bounds(arr)
      _6a5c7d09 = (@arr19 && @arr19[ix]) || arr
      borders.each do |fld|
        return false if KSU::Geom._0c91518b(arr, fld[:poly], _970aa8ae)
      end
      KSU::Nfp._a6cf3d0d(grid, _f38e85e6, @tam_cach_nhau).each do |_a4ab9a59|
        fld = items[_a4ab9a59]
        next if h[fld[:panel].object_id]
        _33f52d3e = _79fb30a5([arr], fld[:holes])
        if _33f52d3e
          return false if KSU::Geom._0c91518b(arr, _33f52d3e, @tam_cach_nhau)
          next
        end
        next unless KSU::Geom.boxes_overlap?(_f38e85e6, fld[:bbox], @tam_cach_nhau)
        next unless _af0cebe5(_6a5c7d09, fld[:hull], @tam_cach_nhau)
        return false if _af0cebe5(arr, fld[:poly], @tam_cach_nhau)
      end
    end
    true
  end
  def _5b9cf20b
    @h23 = {}
  end
  def _1cc6124b(sheets)
    @h23 ||= {}
    sheets.each do |s|
      next unless s && s.respond_to?(:object_id)
      @h23.delete(s.object_id)
    end
  end
  def _0b16f3d7
    key = [@xep_tam_tu_do, @tam_cach_nhau.to_f, KSU::Avail.sides(@tam_cach_le.to_f)]
    if key != @_02765833
      @h23 = {}
      @_02765833 = key
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
    @arr23.each do |arr2|
      vec = arr2[:instance]
      next unless vec && vec.valid?
      sheet = vec.object_id
      partner = @h23[sheet]
      if partner.nil?
        partner = _726c65ba(vec)
        @h23[sheet] = partner
      end
      arr.concat(partner)
    end
    @arr18 = arr
  end
  def _726c65ba(_73dc38ac)
    gap_for = _970aa8ae
    tol = 0.5.mm.to_f
    tol2 = 0.1.mm.to_f
    num = @tam_cach_nhau.to_f - tol
    num = 0.0 if num < 0.0
    answer = []
    begin
      arr = _1adb886a(_73dc38ac)
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
      h2.each_key do |_a4ab9a59|
        fld = items[_a4ab9a59]
        _2e113abe = (h3[_a4ab9a59] ||= _5dc6e713(fld[:poly], tol2))
        fld_bbox = fld[:bbox]
        hull = fld[:hull]
        unless flag.nil? || gap_for <= 0.0
          if fld_bbox[:min_x] < flag + gap_for - tol || fld_bbox[:max_x] > flag3 - gap_for + tol ||
             fld_bbox[:min_y] < flag4 + gap_for - tol || fld_bbox[:max_y] > flag2 - gap_for + tol
            h[_a4ab9a59] = true
          end
        end
        KSU::Nfp._a6cf3d0d(grid, fld_bbox, num).each do |j|
          next if j == _a4ab9a59
          next unless h2[j]
          panel = items[j]
          _33f52d3e = _79fb30a5([_2e113abe], panel[:holes])
          if _33f52d3e
            if KSU::Geom._0c91518b(_2e113abe, _33f52d3e, num)
              h[_a4ab9a59] = true
              h[j] = true
            end
            next
          end
          _3e1d5f51 = _79fb30a5([panel[:poly]], fld[:holes])
          if _3e1d5f51
            _982c8eb9 = (h3[j] ||= _5dc6e713(panel[:poly], tol2))
            if KSU::Geom._0c91518b(_982c8eb9, _3e1d5f51, num)
              h[_a4ab9a59] = true
              h[j] = true
            end
            next
          end
          next unless KSU::Geom.boxes_overlap?(fld_bbox, panel[:bbox], num)
          next unless _af0cebe5(hull, panel[:hull], num)
          if _af0cebe5(_2e113abe, panel[:poly], num)
            h[_a4ab9a59] = true
            h[j] = true
          end
        end
      end
      h.each_key do |_a4ab9a59|
        fill = _89bccf8d(items[_a4ab9a59][:panel], _73dc38ac)
        answer << fill if fill && fill[:outer] && fill[:outer].length >= 3
      end
    rescue StandardError
    end
    answer
  end
  def _5dc6e713(poly, tol)
    return poly unless defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:offset)
    arr = poly.map { |pt| [pt.x.to_f * 25.4, pt.y.to_f * 25.4] }
    arr.reverse! if KSU::Nfp._3b7ac698(arr) < 0
    arr2 = KSU::Clipper.offset([arr], -(tol.to_f * 25.4), 0, 1)
    return poly unless arr2 && !arr2.empty?
    arr3 = arr2.max_by { |half| KSU::Nesting.poly_area(half) }
    return poly unless arr3 && arr3.length >= 3
    arr3.map { |pt| Geom::Point3d.new(pt[0] / 25.4, pt[1] / 25.4, 0) }
  rescue StandardError
    poly
  end
  def _3ea06bed(_f222cc53)
    return if @arr27.empty?
    _8f5311bb if @flag56
    KSU.start unless @flag56
    bb = Geom::BoundingBox.new
    @arr27.each { |grp| bb.add(KSU::View._fa674c93(grp)) }
    _32310dba = bb.center
    tr2 = Geom::Transformation.rotation(_32310dba, [0, 0, 1], _f222cc53)
    @arr27.each do |panel|
      next unless panel.valid?
      panel.transform!(tr2)
      partner_of = partner_of2(panel)
      next unless partner_of && partner_of.valid?
      transform = KSU::Sheet.mirror_tf(panel, sheet_of(panel), sheet_of(partner_of))
      partner_of.transformation = transform if transform
    end
    @tr = @arr27.map { |grp| grp.transformation.clone } if @flag56
    _b1981961 = partners_of(@arr27)
    _8f1f5186(@arr27)
    _8f1f5186(_b1981961)
    KSU.commit unless @flag56
    if @flag56
      _4f4ecb72
      _9004d10e
    else
      bbox = @arr27 + _b1981961
      refresh_after_move(bbox, sheets_of(bbox))
    end
    _285eca92
    KSU::View.view.invalidate
  end
  def _2bff4638(side)
    _8f5311bb if @flag56
    h = {}
    @arr27.each_with_index do |panel, ix|
      vec = @arr12[ix]
      next unless panel && panel.valid? && vec && vec.valid?
      key = group_id(panel) || "solo#{panel.entityID}"
      (h[key] ||= []) << [panel, vec, _c7b0bc62(panel, vec)]
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
    arr4.each_with_index do |members, _1c4e86f2|
      screen_box = arr2[_1c4e86f2]
      vec2 = case side
        when :left then Geom::Vector3d.new(anchor - screen_box[0], 0, 0)
        when :right then Geom::Vector3d.new(anchor - screen_box[2], 0, 0)
        when :bottom then Geom::Vector3d.new(0, anchor - screen_box[1], 0)
        when :top then Geom::Vector3d.new(0, anchor - screen_box[3], 0)
        end
      next if vec2.length < KSU::TOL
      members.each do |panel, vec, _part|
        panel.transform!(_d1eefbfb(vec, vec2))
      end
    end
    _32c9a9b9 = (side == :left || side == :right)
    gap2 = @tam_cach_nhau.to_f
    items = arr4.map do |members|
      polys = members.map { |panel, vec, _part| _8e5202c8(panel, vec) }
                           .select { |poly| poly.length >= 3 }
      next nil if polys.empty?
      umin = nil
      umax = nil
      polys.each do |poly|
        bbox = KSU::Geom.bounds(poly)
        flag2 = _32c9a9b9 ? bbox[:min_y] : bbox[:min_x]
        flag = _32c9a9b9 ? bbox[:max_y] : bbox[:max_x]
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
      _7ddb69ec = (arr[:umin] + umin3) - umin2
      _9acecc6a = _e099da59(arr[:polys], arr3, _32c9a9b9, umin3, _7ddb69ec, gap2)
      num = umin3 - _9acecc6a
      if num.abs >= KSU::TOL
        vec2 = _32c9a9b9 ? Geom::Vector3d.new(0, num, 0) : Geom::Vector3d.new(num, 0, 0)
        arr[:members].each do |panel, vec, _part|
          panel.transform!(_d1eefbfb(vec, vec2))
        end
      end
      arr[:polys].each do |poly|
        arr3 << (_32c9a9b9 ? KSU::Geom.translate(poly, 0.0, num) : KSU::Geom.translate(poly, num, 0.0))
      end
      _9708309a = arr[:umax] + num
      umax2 = _9708309a if _9708309a > umax2
    end
    _8f1f5186(@arr27)
    KSU.commit unless @flag56
    if @flag56
      _4f4ecb72
    else
      refresh_after_move(@arr27, sheets_of(@arr27))
    end
    _285eca92
    KSU::View.view.invalidate
  end
  def _e099da59(arr, _7f4cfb48, _32c9a9b9, umin, _7ddb69ec, gap2)
    return 0.0 if _7ddb69ec <= KSU::TOL
    _13b5e235 = lambda do |s|
      _8a2a4def = umin - s
      arr.all? do |normal|
        poly = _32c9a9b9 ? KSU::Geom.translate(normal, 0.0, _8a2a4def) : KSU::Geom.translate(normal, _8a2a4def, 0.0)
        _7f4cfb48.none? { |_9ba5a7e0| _af0cebe5(poly, _9ba5a7e0, gap2) }
      end
    end
    return _7ddb69ec if _13b5e235.call(_7ddb69ec)
    num3 = 48
    _89bad203 = _7ddb69ec / num3
    num = 0.0
    _e25dbacd = _7ddb69ec
    partner = false
    (1..num3).each do |k|
      s = k * _89bad203
      next if _13b5e235.call(s)
      num = (k - 1) * _89bad203
      _e25dbacd = s
      partner = true
      break
    end
    return _7ddb69ec unless partner
    24.times do
      num2 = 0.5 * (num + _e25dbacd)
      if _13b5e235.call(num2)
        num = num2
      else
        _e25dbacd = num2
      end
    end
    num
  end
  def _d1eefbfb(grp, pt)
    inv = (@nesting.transformation * grp.transformation).inverse
    Geom::Transformation.translation(pt.transform(inv))
  end
  def _c7b0bc62(panel, grp)
    tf = @nesting.transformation * grp.transformation * panel.transformation
    box = panel.definition.bounds
    bb = Geom::BoundingBox.new
    (0..7).each { |_a4ab9a59| bb.add(box.corner(_a4ab9a59).transform(tf)) }
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
