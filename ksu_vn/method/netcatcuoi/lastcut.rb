module KSU::Lastcut
  private
  def _52c178c0(hide)
    arr = []
    if hide && @nesting && @nesting.valid?
      @sheets.each do |rec|
        sheet = rec[:instance]
        next unless sheet && sheet.valid?
        sheet.definition.entities.grep(Sketchup::Group).each do |g|
          arr << g if _75723f03(g) && !g.hidden?
        end
      end
    end
    arr2 = @arr37.select { |g| g && g.valid? && g.hidden? }
    return if arr.empty? && arr2.empty?
    KSU.start(false)
    arr2.each { |g| g.hidden = false }
    arr.each { |g| g.hidden = true }
    @arr37 = arr
    KSU.commit
  rescue
    KSU.abort_op
  end
  def _70785283(sheets)
    return unless @nesting && @nesting.valid?
    sheets = sheets.compact.uniq
    return if sheets.empty?
    tag = KSU::Cutting.layer("ABF_lastCut")
    h = @slots.group_by { |ent| ent[:sheet] }
    KSU.start
    sheets.each do |sheet|
      next unless sheet && sheet.valid?
      rec = @sheets.find { |s| s[:instance] == sheet }
      next unless rec
      _5d1a5ed6(sheet, rec, h[sheet] || [], tag)
    end
    KSU.commit
  rescue
    KSU.abort_op
  end
  def _5d1a5ed6(sheet, rec, entries, tag)
    sheet.definition.entities.grep(Sketchup::Group).each do |node|
      node.erase! if _75723f03(node)
    end
    arr = entries.map { |ent| ent[:points] }.select { |pts| pts && pts.length == 4 }
    if arr.empty?
      sheet.attribute_dictionary("ABF")&.delete_key("sheet-last-cut")
      return
    end
    data = _f89911a7(rec, arr)
    sheet.set_attribute("ABF", "sheet-last-cut", JSON.generate(data[:json]))
    return if data[:segments].empty?
    node = sheet.definition.entities.add_group
    node.name = "__ABF_lastCut"
    node.set_attribute("ABF", "is-last-cut", true)
    tr = (rec[:transform] * node.transformation).inverse
    data[:segments].each do |pt2, b|
      node.entities.add_line(pt2.transform(tr), b.transform(tr))
    end
    node.entities.grep(Sketchup::Face).each(&:erase!)
    KSU::Cutting.set_layer(node, tag)
  end
  def _f89911a7(rec, arr5)
    box = rec[:bbox]
    _bd21b165, _e55fd46f = KSU::Sheet.edit_offset(rec[:instance]) || [0.0, 0.0]
    num = box.min.x.to_f + _bd21b165
    num2 = box.min.y.to_f + _e55fd46f
    arr6 = arr5.map do |pts|
      b = KSU::Geom.bounds(pts)
      [b[:min_x] - num, b[:min_y] - num2, b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    loops = _662cf545(arr5)
    arr8 = loops.map { |arr4| arr4.map { |pt| [pt.x.to_f - num, pt.y.to_f - num2] } }
    arr7 = loops.map do |arr4|
      b = KSU::Geom.bounds(arr4)
      [b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    polylines = _a95ae5a0(loops, rec)
    arr9 = polylines.map { |members| members.map { |pt| [pt.x.to_f - _bd21b165, pt.y.to_f - _e55fd46f] } }
    segments = polylines.flat_map { |members| members.each_cons(2).to_a }
    resp = {
      "rects" => arr6,
      "cut_lines" => arr9,
      "polys" => arr8,
      "sizes" => arr7
    }
    { json: resp, segments: segments }
  end
  def _662cf545(arr8)
    arr5 = arr8.map do |pts|
      arr2 = pts.map { |pt| pt.x.to_f }
      arr3 = pts.map { |pt| pt.y.to_f }
      { x1: arr2.min, x2: arr2.max, y1: arr3.min, y2: arr3.max }
    end
    arr2 = KSU::Geom._a404e7b6(arr5.flat_map { |b| [b[:x1], b[:x2]] })
    arr3 = KSU::Geom._a404e7b6(arr5.flat_map { |b| [b[:y1], b[:y2]] })
    return [] if arr2.length < 2 || arr3.length < 2
    nx = arr2.length - 1
    ny = arr3.length - 1
    arr4 = _c839dc19(arr2, arr3) do |px, py|
      arr5.any? { |b| px > b[:x1] && px < b[:x2] && py > b[:y1] && py < b[:y2] }
    end
    arr6 = []
    (0..nx).each do |i|
      ny.times do |j|
        flag2 = i > 0 ? arr4[i - 1][j] : false
        flag3 = i < nx ? arr4[i][j] : false
        next if flag2 == flag3
        arr6 << [Geom::Point3d.new(arr2[i], arr3[j], @plane_z), Geom::Point3d.new(arr2[i], arr3[j + 1], @plane_z)]
      end
    end
    (0..ny).each do |j|
      nx.times do |i|
        flag4 = j > 0 ? arr4[i][j - 1] : false
        flag = j < ny ? arr4[i][j] : false
        next if flag4 == flag
        arr6 << [Geom::Point3d.new(arr2[i], arr3[j], @plane_z), Geom::Point3d.new(arr2[i + 1], arr3[j], @plane_z)]
      end
    end
    loops = KSU::Cutting.build_loops(arr6)
    loops.map { |arr7| _245e1bad(arr7) }.select { |arr7| arr7.length >= 3 }
  end
  def _a95ae5a0(loops, rec)
    box = rec[:bbox]
    dx, dy = KSU::Sheet.edit_offset(rec[:instance]) || [0.0, 0.0]
    num2 = box.min.x.to_f + [dx, 0.0].max
    num5 = box.min.y.to_f + [dy, 0.0].max
    rx = box.max.x.to_f + [dx, 0.0].min
    ry = box.max.y.to_f + [dy, 0.0].min
    num = KSU::Avail.sides(@tam_cach_le.to_f).max + 1.mm.to_f
    polylines = []
    loops.each do |arr|
      n = arr.length
      snap_edges = (0...n).map { |i| [arr[i], arr[(i + 1) % n]] }
      arr2 = snap_edges.map { |_9710d820, b| !_acfeef55(_9710d820, b, num2, num5, rx, ry, num) }
      if arr2.all?
        polylines << (arr + [arr[0]])
        next
      end
      next unless arr2.any?
      start = arr2.index(false)
      _7e53f420 = nil
      n.times do |k|
        ix = (start + k) % n
        if arr2[ix]
          _9710d820, b = snap_edges[ix]
          if _7e53f420
            _7e53f420 << b
          else
            _7e53f420 = [_9710d820, b]
          end
        elsif _7e53f420
          polylines << _7e53f420
          _7e53f420 = nil
        end
      end
      polylines << _7e53f420 if _7e53f420
    end
    polylines
  end
  def _acfeef55(pt, b, _3e7613f3, _9ba1a361, rx, ry, _0845fb1d)
    num = 0.01.mm.to_f
    if (pt.x - b.x).abs < num
      (pt.x - _3e7613f3).abs <= _0845fb1d || (pt.x - rx).abs <= _0845fb1d
    elsif (pt.y - b.y).abs < num
      (pt.y - _9ba1a361).abs <= _0845fb1d || (pt.y - ry).abs <= _0845fb1d
    else
      false
    end
  end
  def _245e1bad(arr)
    n = arr.length
    return arr if n < 3
    answer = []
    n.times do |i|
      pt = arr[(i - 1) % n]
      b = arr[i]
      color = arr[(i + 1) % n]
      cross = (b.x - pt.x) * (color.y - pt.y) - (b.y - pt.y) * (color.x - pt.x)
      answer << b if cross.abs > 1e-6
    end
    answer
  end
  def _c839dc19(arr2, arr)
    nx = arr2.length - 1
    ny = arr.length - 1
    cells = Array.new(nx) { Array.new(ny, false) }
    nx.times do |i|
      px = (arr2[i] + arr2[i + 1]) / 2.0
      ny.times do |j|
        py = (arr[j] + arr[j + 1]) / 2.0
        cells[i][j] = yield(px, py)
      end
    end
    cells
  end
  def _75723f03(entity)
    return false unless entity && entity.valid?
    return false unless KSU.container?(entity)
    return true if entity.get_attribute("ABF", "is-last-cut")
    entity.name.to_s == "__ABF_lastCut"
  end
  def panel_boxes(sheet, transform, flag2 = false)
    arr = []
    sheet.definition.entities.each do |panel|
      next unless KSU.container?(panel)
      next if _75723f03(panel)
      next if panel.name.to_s == "__ABF_sheetBorder"
      next if KSU::Sheet._27ecfdd1(panel)
      next unless KSU::Sheet.drawable?(panel)
      world_tr = transform * panel.transformation
      flag = flag2 ? nil : _3431a152(panel, world_tr)
      if flag && !flag.empty?
        arr.concat(flag)
      else
        bb = panel.definition.bounds
        bbox = Geom::BoundingBox.new
        (0..7).each { |i| bbox.add(bb.corner(i).transform(world_tr)) }
        arr << bbox
      end
    end
    arr
  end
  def _3431a152(panel, panel_tr)
    fill = KSU::Cutting.outline(panel, panel_tr)
    outer = fill && fill[:outer]
    return nil unless outer && outer.length >= 3
    holes = (fill[:holes] || []).select { |h| h && h.length >= 3 }
    loops = [outer] + holes
    arr2 = KSU::Geom._a404e7b6(loops.flat_map { |arr3| arr3.map { |pt| pt.x.to_f } })
    arr = KSU::Geom._a404e7b6(loops.flat_map { |arr3| arr3.map { |pt| pt.y.to_f } })
    return nil if arr2.length < 2 || arr.length < 2
    nx = arr2.length - 1
    ny = arr.length - 1
    return nil if nx * ny > 6000
    cells = _c839dc19(arr2, arr) do |px, py|
      KSU::View.in_poly?(px, py, outer) &&
        holes.none? { |h| KSU::View.in_poly?(px, py, h) }
    end
    _b9371681(cells, arr2, arr)
  end
  def _b9371681(cells, arr3, arr2)
    nx = cells.length
    ny = cells.first.length
    arr = Array.new(ny) { [] }
    ny.times do |j|
      i = 0
      while i < nx
        unless cells[i][j]
          i += 1
          next
        end
        k = i
        k += 1 while k < nx && cells[k][j]
        arr[j] << [i, k]
        i = k
      end
    end
    _b8f3387b = Array.new(ny) { |j| Array.new(arr[j].length, false) }
    arr4 = []
    ny.times do |j|
      arr[j].each_with_index do |start2, _f777bf99|
        next if _b8f3387b[j][_f777bf99]
        _b8f3387b[j][_f777bf99] = true
        _eac99076 = j
        loop do
          _79be379e = _eac99076 + 1
          break if _79be379e >= ny
          _a95eb156 = arr[_79be379e].index { |half| half == start2 }
          break unless _a95eb156 && !_b8f3387b[_79be379e][_a95eb156]
          _b8f3387b[_79be379e][_a95eb156] = true
          _eac99076 = _79be379e
        end
        bbox = Geom::BoundingBox.new
        bbox.add(Geom::Point3d.new(arr3[start2[0]], arr2[j], @plane_z))
        bbox.add(Geom::Point3d.new(arr3[start2[1]], arr2[_eac99076 + 1], @plane_z))
        arr4 << bbox
      end
    end
    arr4
  end
end
KSU::Netcatcuoi.include(KSU::Lastcut)
module KSU::Lastcut
  def self._af392092(key, default)
    data = KSU::Font.read_license
    data.key?(key) ? data[key] : default
  end
end
