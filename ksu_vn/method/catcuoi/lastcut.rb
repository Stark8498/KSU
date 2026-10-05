module KSU::Lastcut
  private
  def hide_last_cuts(hide)
    arr = []
    if hide && @nesting && @nesting.valid?
      @sheets.each do |rec|
        grp = rec[:instance]
        next unless grp && grp.valid?
        arr.concat(grp.definition.entities.grep(Sketchup::Group).select { |vec| KSU::Nesting.last_cut?(vec) && !vec.hidden? })
      end
    end
    arr2 = @hidden_cuts.select { |vec| vec && vec.valid? && vec.hidden? }
    return if arr.empty? && arr2.empty?
    KSU.start(false)
    arr2.each { |vec| vec.hidden = false }
    arr.each { |vec| vec.hidden = true }
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
    h = @rects.group_by { |arr| arr[:sheet] }
    KSU.start
    sheets.each do |vec|
      next unless vec.valid?
      rec = KSU::Sheet.record_for(@sheets, vec)
      next unless rec
      write_last_cut(vec, rec, h[vec] || [], tag)
    end
    KSU.commit
  rescue
    KSU.abort_op
  end
  def write_last_cut(grp2, rec, entries, tag)
    grp2.definition.entities.grep(Sketchup::Group).each { |grp| grp.erase! if KSU::Nesting.last_cut?(grp) }
    return grp2.attribute_dictionary("ABF")&.delete_key("sheet-last-cut") if entries.empty?
    data = to_sheet_xy(rec, entries.map { |arr| arr[:points] })
    grp2.set_attribute("ABF", "sheet-last-cut", JSON.generate(data[:json]))
    return if data[:segments].empty?
    grp = grp2.definition.entities.add_group
    grp.name = "__ABF_lastCut"
    grp.set_attribute("ABF", "is-last-cut", true)
    tr = (rec[:transform] * grp.transformation).inverse
    data[:segments].each { |pt, b| grp.entities.add_line(pt.transform(tr), b.transform(tr)) }
    grp.entities.grep(Sketchup::Face).each(&:erase!)
    KSU::Cutting.set_layer(grp, tag)
  end
  def sheet_offset(rec)
    off_x, off_y = KSU::Sheet.edit_offset(rec[:instance]) || [0.0, 0.0]
    [rec[:bbox].min.x.to_f + off_x, rec[:bbox].min.y.to_f + off_y, off_x, off_y]
  end
  def to_sheet_xy(rec, arr2)
    _821639ac, _98c3a7e0, off_x, off_y = sheet_offset(rec)
    arr5 = arr2.map do |pts2|
      b = KSU::Geom.bounds(pts2)
      [b[:min_x] - _821639ac, b[:min_y] - _98c3a7e0, b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    loops = merge_rects(arr2)
    arr6 = loops.map { |arr| arr.map { |pt| [pt.x.to_f - _821639ac, pt.y.to_f - _98c3a7e0] } }
    arr3 = loops.map do |arr|
      b = KSU::Geom.bounds(arr)
      [b[:max_x] - b[:min_x], b[:max_y] - b[:min_y]]
    end
    polylines = to_polylines(loops, rec)
    arr4 = polylines.map { |members| members.map { |pt| [pt.x.to_f - off_x, pt.y.to_f - off_y] } }
    { json: { "rects" => arr5, "cut_lines" => arr4, "polys" => arr6, "sizes" => arr3 },
      segments: polylines.flat_map { |members| members.each_cons(2).to_a } }
  end
  def merge_rects(arr6)
    arr4 = arr6.map { |pts2| KSU::Geom.bounds(pts2) }
    arr2 = KSU::Geom.merge_near(arr4.flat_map { |b| [b[:min_x], b[:max_x]] })
    arr = KSU::Geom.merge_near(arr4.flat_map { |b| [b[:min_y], b[:max_y]] })
    return [] if arr2.length < 2 || arr.length < 2
    nx = arr2.length - 1
    ny = arr.length - 1
    arr3 = cell_map(arr2, arr) do |px, py|
      arr4.any? { |b| px > b[:min_x] && px < b[:max_x] && py > b[:min_y] && py < b[:max_y] }
    end
    segs = []
    (0..nx).each do |i|
      ny.times do |ix|
        flag2 = i > 0 ? arr3[i - 1][ix] : false
        flag3 = i < nx ? arr3[i][ix] : false
        next if flag2 == flag3
        segs << [Geom::Point3d.new(arr2[i], arr[ix], @plane_z), Geom::Point3d.new(arr2[i], arr[ix + 1], @plane_z)]
      end
    end
    (0..ny).each do |ix|
      nx.times do |i|
        flag4 = ix > 0 ? arr3[i][ix - 1] : false
        flag = ix < ny ? arr3[i][ix] : false
        next if flag4 == flag
        segs << [Geom::Point3d.new(arr2[i], arr[ix], @plane_z), Geom::Point3d.new(arr2[i + 1], arr[ix], @plane_z)]
      end
    end
    loops = KSU::Cutting.build_loops(segs)
    loops.map { |arr5| simplify_loop(arr5) }.select { |arr5| arr5.length >= 3 }
  end
  def to_polylines(loops, rec)
    box = rec[:bbox]
    _fbf0cf8d, _7e1c7e1d = KSU::Sheet.edit_offset(rec[:instance]) || [0.0, 0.0]
    num2 = box.min.x.to_f + [_fbf0cf8d, 0.0].max
    num3 = box.min.y.to_f + [_7e1c7e1d, 0.0].max
    rx = box.max.x.to_f + [_fbf0cf8d, 0.0].min
    ry = box.max.y.to_f + [_7e1c7e1d, 0.0].min
    num = KSU::Avail.avail_map(@tam_cach_le.to_f).max + 1.mm.to_f
    polylines = []
    loops.each do |arr|
      n = arr.length
      snap_edges = arr.zip(arr.rotate)
      inner = snap_edges.map { |a, b| !on_sheet_edge?(a, b, num2, num3, rx, ry, num) }
      if inner.all?
        polylines << (arr + [arr[0]])
        next
      end
      next unless inner.any?
      start = inner.index(false)
      _7a72dc50 = nil
      n.times do |k|
        ix = (start + k) % n
        if inner[ix]
          a, b = snap_edges[ix]
          (_7a72dc50 ||= [a]) << b
        elsif _7a72dc50
          polylines << _7a72dc50
          _7a72dc50 = nil
        end
      end
      polylines << _7a72dc50 if _7a72dc50
    end
    polylines
  end
  def on_sheet_edge?(pt, b, _821639ac, _98c3a7e0, rx, ry, _15bc30f3)
    num = 0.01.mm.to_f
    if (pt.x - b.x).abs < num
      (pt.x - _821639ac).abs <= _15bc30f3 || (pt.x - rx).abs <= _15bc30f3
    elsif (pt.y - b.y).abs < num
      (pt.y - _98c3a7e0).abs <= _15bc30f3 || (pt.y - ry).abs <= _15bc30f3
    else
      false
    end
  end
  def simplify_loop(arr)
    n = arr.length
    return arr if n < 3
    ok = []
    n.times do |i|
      pt = arr[(i - 1) % n]
      b = arr[i]
      pt2 = arr[(i + 1) % n]
      cross = (b.x - pt.x) * (pt2.y - pt.y) - (b.y - pt.y) * (pt2.x - pt.x)
      ok << b if cross.abs > 1e-6
    end
    ok
  end
  def cell_map(arr2, arr)
    nx = arr2.length - 1
    ny = arr.length - 1
    cells = Array.new(nx) { Array.new(ny, false) }
    nx.times do |i|
      px = (arr2[i] + arr2[i + 1]) / 2.0
      ny.times do |ix|
        py = (arr[ix] + arr[ix + 1]) / 2.0
        cells[i][ix] = yield(px, py)
      end
    end
    cells
  end
  def panel_boxes(grp, transform, flag2 = false)
    arr = []
    grp.definition.entities.each do |panel|
      next unless KSU::Sheet.part_group?(panel)
      world_tr = transform * panel.transformation
      flag = flag2 ? nil : panel_cells(panel, world_tr)
      if flag && !flag.empty?
        arr.concat(flag)
      else
        arr << KSU::Geom.world_box(panel.definition.bounds, world_tr)
      end
    end
    arr
  end
  def panel_cells(panel, panel_tr)
    fill = KSU::Cutting.outline(panel, panel_tr)
    outer = fill && fill[:outer]
    return nil unless outer && outer.length >= 3
    holes = (fill[:holes] || []).select { |elem| elem && elem.length >= 3 }
    loops = [outer] + holes
    arr2 = KSU::Geom.merge_near(loops.flat_map { |arr3| arr3.map { |pt| pt.x.to_f } })
    arr = KSU::Geom.merge_near(loops.flat_map { |arr3| arr3.map { |pt| pt.y.to_f } })
    return nil if arr2.length < 2 || arr.length < 2
    nx = arr2.length - 1
    ny = arr.length - 1
    return nil if nx * ny > 6000
    cells = cell_map(arr2, arr) do |px, py|
      KSU::View.in_poly?(px, py, outer) &&
        holes.none? { |elem| KSU::View.in_poly?(px, py, elem) }
    end
    rows_of_cells(cells, arr2, arr)
  end
  def rows_of_cells(cells, arr4, arr2)
    nx = cells.length
    ny = cells.first.length
    arr = Array.new(ny) { [] }
    ny.times do |ix|
      i = 0
      while i < nx
        unless cells[i][ix]
          i += 1
          next
        end
        k = i
        k += 1 while k < nx && cells[k][ix]
        arr[ix] << [i, k]
        i = k
      end
    end
    taken = Array.new(ny) { |ix| Array.new(arr[ix].length, false) }
    arr3 = []
    ny.times do |ix|
      arr[ix].each_with_index do |start2, ci2|
        next if taken[ix][ci2]
        taken[ix][ci2] = true
        j0 = ix
        loop do
          j1 = j0 + 1
          break if j1 >= ny
          k2 = arr[j1].index { |half| half == start2 }
          break unless k2 && !taken[j1][k2]
          taken[j1][k2] = true
          j0 = j1
        end
        bbox = Geom::BoundingBox.new
        bbox.add(Geom::Point3d.new(arr4[start2[0]], arr2[ix], @plane_z))
        bbox.add(Geom::Point3d.new(arr4[start2[1]], arr2[j0 + 1], @plane_z))
        arr3 << bbox
      end
    end
    arr3
  end
end
KSU::Catcuoi.include(KSU::Lastcut)
module KSU::Lastcut
  def self.license_value(key, default)
    data = KSU::Font.read_license
    data.key?(key) ? data[key] : default
  end
end
