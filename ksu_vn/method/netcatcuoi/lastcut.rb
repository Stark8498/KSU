module KSU::Lastcut
  private
  def hide_last_cuts(hide)
    arr = []
    if hide && @nesting && @nesting.valid?
      @sheets.each do |rec|
        sheet = rec[:instance]
        next unless sheet && sheet.valid?
        sheet.definition.entities.grep(Sketchup::Group).each do |g|
          arr << g if last_cut_group?(g) && !g.hidden?
        end
      end
    end
    arr2 = @hidden_cuts.select { |g| g && g.valid? && g.hidden? }
    return if arr.empty? && arr2.empty?
    KSU.start(false)
    arr2.each { |g| g.hidden = false }
    arr.each { |g| g.hidden = true }
    @hidden_cuts = arr
    KSU.commit
  rescue
    KSU.abort_op
  end
  def save_last_cuts(sheets)
    return unless @nesting && @nesting.valid?
    sheets = sheets.compact.uniq
    return if sheets.empty?
    tag = KSU::Cutting.layer("ABF_lastCut")
    h = @rects.group_by { |ent| ent[:sheet] }
    KSU.start
    sheets.each do |sheet|
      next unless sheet && sheet.valid?
      rec = @sheets.find { |s| s[:instance] == sheet }
      next unless rec
      write_last_cut(sheet, rec, h[sheet] || [], tag)
    end
    KSU.commit
  rescue
    KSU.abort_op
  end
  def write_last_cut(sheet, rec, entries, tag)
    sheet.definition.entities.grep(Sketchup::Group).each do |node|
      node.erase! if last_cut_group?(node)
    end
    arr = entries.map { |ent| ent[:points] }.select { |pts| pts && pts.length == 4 }
    if arr.empty?
      sheet.attribute_dictionary("ABF")&.delete_key("sheet-last-cut")
      return
    end
    data = last_cut_json(rec, arr)
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
  def last_cut_json(rec, arr5)
    box = rec[:bbox]
    off_x, off_y = KSU::Sheet.edit_offset(rec[:instance]) || [0.0, 0.0]
    num = box.min.x.to_f + off_x
    num2 = box.min.y.to_f + off_y
    arr6 = arr5.map do |pts|
      b = KSU::Geom.bounds(pts)
      [b[:min_x] - num, b[:min_y] - num2, b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    loops = merge_rects(arr5)
    arr8 = loops.map { |arr4| arr4.map { |pt| [pt.x.to_f - num, pt.y.to_f - num2] } }
    arr7 = loops.map do |arr4|
      b = KSU::Geom.bounds(arr4)
      [b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    polylines = to_polylines(loops, rec)
    arr9 = polylines.map { |members| members.map { |pt| [pt.x.to_f - off_x, pt.y.to_f - off_y] } }
    segments = polylines.flat_map { |members| members.each_cons(2).to_a }
    resp = {
      "rects" => arr6,
      "cut_lines" => arr9,
      "polys" => arr8,
      "sizes" => arr7
    }
    { json: resp, segments: segments }
  end
  def merge_rects(arr8)
    arr5 = arr8.map do |pts|
      arr2 = pts.map { |pt| pt.x.to_f }
      arr3 = pts.map { |pt| pt.y.to_f }
      { x1: arr2.min, x2: arr2.max, y1: arr3.min, y2: arr3.max }
    end
    arr2 = KSU::Geom.merge_near(arr5.flat_map { |b| [b[:x1], b[:x2]] })
    arr3 = KSU::Geom.merge_near(arr5.flat_map { |b| [b[:y1], b[:y2]] })
    return [] if arr2.length < 2 || arr3.length < 2
    nx = arr2.length - 1
    ny = arr3.length - 1
    arr4 = cell_map(arr2, arr3) do |px, py|
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
    loops.map { |arr7| simplify_loop(arr7) }.select { |arr7| arr7.length >= 3 }
  end
  def to_polylines(loops, rec)
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
      arr2 = snap_edges.map { |a, b| !on_sheet_edge?(a, b, num2, num5, rx, ry, num) }
      if arr2.all?
        polylines << (arr + [arr[0]])
        next
      end
      next unless arr2.any?
      start = arr2.index(false)
      run2 = nil
      n.times do |k|
        ix = (start + k) % n
        if arr2[ix]
          a, b = snap_edges[ix]
          if run2
            run2 << b
          else
            run2 = [a, b]
          end
        elsif run2
          polylines << run2
          run2 = nil
        end
      end
      polylines << run2 if run2
    end
    polylines
  end
  def on_sheet_edge?(pt, b, sx, sy, rx, ry, tol)
    num = 0.01.mm.to_f
    if (pt.x - b.x).abs < num
      (pt.x - sx).abs <= tol || (pt.x - rx).abs <= tol
    elsif (pt.y - b.y).abs < num
      (pt.y - sy).abs <= tol || (pt.y - ry).abs <= tol
    else
      false
    end
  end
  def simplify_loop(arr)
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
  def cell_map(arr2, arr)
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
  def last_cut_group?(entity)
    return false unless entity && entity.valid?
    return false unless KSU.container?(entity)
    return true if entity.get_attribute("ABF", "is-last-cut")
    entity.name.to_s == "__ABF_lastCut"
  end
  def panel_boxes(sheet, transform, flag2 = false)
    arr = []
    sheet.definition.entities.each do |panel|
      next unless KSU.container?(panel)
      next if last_cut_group?(panel)
      next if panel.name.to_s == "__ABF_sheetBorder"
      next if KSU::Sheet.sheet_border?(panel)
      next unless KSU::Sheet.drawable?(panel)
      world_tr = transform * panel.transformation
      flag = flag2 ? nil : panel_cells(panel, world_tr)
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
  def panel_cells(panel, panel_tr)
    fill = KSU::Cutting.outline(panel, panel_tr)
    outer = fill && fill[:outer]
    return nil unless outer && outer.length >= 3
    holes = (fill[:holes] || []).select { |h| h && h.length >= 3 }
    loops = [outer] + holes
    arr2 = KSU::Geom.merge_near(loops.flat_map { |arr3| arr3.map { |pt| pt.x.to_f } })
    arr = KSU::Geom.merge_near(loops.flat_map { |arr3| arr3.map { |pt| pt.y.to_f } })
    return nil if arr2.length < 2 || arr.length < 2
    nx = arr2.length - 1
    ny = arr.length - 1
    return nil if nx * ny > 6000
    cells = cell_map(arr2, arr) do |px, py|
      KSU::View.in_poly?(px, py, outer) &&
        holes.none? { |h| KSU::View.in_poly?(px, py, h) }
    end
    rows_of_cells(cells, arr2, arr)
  end
  def rows_of_cells(cells, arr3, arr2)
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
