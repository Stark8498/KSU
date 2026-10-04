module KSU::Pack
  def pack_native(parts, width_mm, height_mm, gap2, allow_rot)
    seed = pack_seed
    num = 0
    num2 = 1000
    any_rot = parts.map { |len2d| allow_rot && !!len2d[:rotatable] }
    id_str = KSU::Method.pack_bl(parts.map { |len2d| len2d[:w] }, parts.map { |len2d| len2d[:h] },
                                 width_mm, height_mm, gap2, any_rot, num2, num, seed)
    h = {}
    id_str.each_with_index do |(placements, x, y, w, h23), i|
      next if placements < 0
      len2d = parts[i]
      rot = (w - len2d[:w]).abs > 1e-6 ? 90 : 0
      (h[placements] ||= []) << {
        panel: len2d[:panel], source_sheet: len2d[:sheet], bbox: len2d[:bbox],
        lx: x, ly: y, w: w, h: h23, rot: rot,
      }
    end
    h.keys.sort.map { |k| h[k] }
  end
  def place_leftovers(arr2, arr, width_mm, height_mm, gap2, allow_rot)
    return [arr2, arr] if arr2.empty? || arr.empty?
    arr3 = arr2.map { |placements| { placements: placements } }
    arr4 = []
    arr.sort_by { |len2d| -(len2d[:w] * len2d[:h]) }.each do |grp|
      flag = false
      arr3.each do |_e76e0098|
        if try_place(_e76e0098, grp, width_mm, height_mm, gap2, allow_rot)
          flag = true
          break
        end
      end
      arr4 << grp unless flag
    end
    [arr3.map { |s| s[:placements] }, arr4]
  end
  def used_area(placements)
    placements.inject(0.0) { |s, members| s + members[:w].to_f * members[:h].to_f }
  end
  def sort_by_x(arr3)
    arr3.sort_by do |s|
      rec = sheet_recs.find { |i| i[:instance] == s }
      rec ? rec[:bbox].center.x.to_f : 0.0
    end
  end
  def try_place(arr4, grp, width_mm, height_mm, gap2, allow_rot)
    arr5 = [{ w: grp[:w], h: grp[:h], rot: 0 }]
    arr5 << { w: grp[:h], h: grp[:w], rot: 90 } if allow_rot && grp[:rotatable] && (grp[:w] - grp[:h]).abs > 1e-6
    best = nil
    arr5.each do |arr2|
      next if arr2[:w] > width_mm + 1e-6 || arr2[:h] > height_mm + 1e-6
      box = free_spot(arr4[:placements], arr2[:w], arr2[:h], width_mm, height_mm, gap2)
      next unless box
      if best.nil? || box[:y] < best[:y] - 1e-6 || ((box[:y] - best[:y]).abs < 1e-6 && box[:x] < best[:x])
        best = { x: box[:x], y: box[:y], orient: arr2 }
      end
    end
    return false unless best
    arr2 = best[:orient]
    arr4[:placements] << {
      panel: grp[:panel], source_sheet: grp[:sheet], bbox: grp[:bbox],
      lx: best[:x], ly: best[:y], w: arr2[:w], h: arr2[:h], rot: arr2[:rot],
    }
    true
  end
  def free_spot(arr4, pw, ph, width_mm, height_mm, gap2)
    arr3 = [0.0]
    arr2 = [0.0]
    arr4.each do |arr|
      arr3 << arr[:lx] + arr[:w] + gap2
      arr2 << arr[:ly] + arr[:h] + gap2
    end
    arr3 = arr3.uniq.sort
    arr2 = arr2.uniq.sort
    arr2.each do |y|
      next if y + ph > height_mm + 1e-6
      arr3.each do |x|
        next if x + pw > width_mm + 1e-6
        x2 = x + pw
        y2 = y + ph
        flag = false
        arr4.each do |arr|
          x_hi = arr[:lx] + arr[:w]
          y_hi = arr[:ly] + arr[:h]
          unless x2 + gap2 <= arr[:lx] + 1e-6 ||
                 x_hi + gap2 <= x + 1e-6 ||
                 y2 + gap2 <= arr[:ly] + 1e-6 ||
                 y_hi + gap2 <= y + 1e-6
            flag = true
            break
          end
        end
        return { x: x, y: y } unless flag
      end
    end
    nil
  end
  def apply_plan(sheets, arr3, gap_for)
    root_tr = @nesting.transformation
    arr3.each_with_index do |arr2, i|
      grp = sheets[i]
      next unless grp
      arr = sheet_recs.find { |s| s[:instance] == grp }
      next unless arr
      bbox = arr[:bbox]
      tr2 = root_tr * grp.transformation
      arr2.each do |members|
        place_panel(members, grp, tr2, bbox, gap_for, root_tr)
      end
    end
  end
  def place_panel(members, grp, tr3, bbox3, gap_for, root_tr)
    panel = members[:panel]
    return unless panel && panel.valid?
    source_sheet = members[:source_sheet]
    tr2 = root_tr * source_sheet.transformation
    bbox = members[:bbox]
    px = bbox.center.x.to_f
    py = bbox.center.y.to_f
    rot_tf = if members[:rot] != 0
        rad = members[:rot] * Math::PI / 180.0
        Geom::Transformation.rotation(Geom::Point3d.new(px, py, bbox.center.z), Z_AXIS, rad)
      else
        Geom::Transformation.new
      end
    num4 = bbox3.min.x.to_f
    num3 = bbox3.min.y.to_f
    dx, dy2 = KSU::Sheet.edit_offset(grp) || [0.0, 0.0]
    _c9bc3f08 = num4 + [dx, 0.0].max
    _1d9bcdf1 = num3 + [dy2, 0.0].max
    _5ae18fa7, _b4835d15 = KSU::Avail.gaps_for(grp, gap_for)
    _a688a1a7 = px - members[:w] / 2.0
    _02d8215d = py - members[:h] / 2.0
    lx = _c9bc3f08 + _5ae18fa7 + members[:lx]
    ly = _1d9bcdf1 + _b4835d15 + members[:ly]
    dx2 = lx - _a688a1a7
    dy = ly - _02d8215d
    vec = Geom::Transformation.translation(Geom::Vector3d.new(dx2, dy, 0))
    _1233c2de = vec * rot_tf
    tr = tr3.inverse * _1233c2de * tr2 * panel.transformation
    pair = back_of(panel)
    if source_sheet == grp
      panel.transformation = tr
      ents = panel
    else
      ents = KSU::Nesting.clone_panel(grp.definition.entities, panel, tr)
    end
    sync_back(ents, pair, source_sheet, grp, members[:rot]) if pair && ents && ents.valid?
    ents
  end
  def edited_sheet(sheets)
    sheets.find { |s| s && s.valid? && KSU::Sheet.edit_offset(s) } || sheets.first
  end
  def sheet_size(sheet)
    rec = sheet_recs.find { |s| s[:instance] == sheet }
    return [nil, nil] unless rec
    bbox = rec[:bbox]
    num2, num = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    [bbox.width.to_f - num2.abs, bbox.height.to_f - num.abs]
  end
end
KSU::Nesting.include(KSU::Pack)
