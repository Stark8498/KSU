module KSU::Pack
  def pack_native(arr29, width_mm, height_mm, gap2, allow_rot)
    any_rot = arr29.map { |len2d| allow_rot && !!len2d[:rotatable] }
    id_str = KSU::Method.pack_bl(arr29.map { |len2d| len2d[:w] }, arr29.map { |len2d| len2d[:h] },
                                 width_mm, height_mm, gap2, any_rot, 1000, 0, start_corner_index)
    h = {}
    id_str.each_with_index do |(placements, x, y, w, elem), i|
      next if placements < 0
      len2d = arr29[i]
      rot = (w - len2d[:w]).abs > 1e-6 ? 90 : 0
      (h[placements] ||= []) << { panel: len2d[:panel], source_sheet: len2d[:sheet], bbox: len2d[:bbox],
                                    lx: x, ly: y, w: w, h: elem, rot: rot }
    end
    h.keys.sort.map { |k| h[k] }
  end
  def place_leftovers(arr2, arr, width_mm, height_mm, gap2, allow_rot)
    return [arr2, arr] if arr2.empty? || arr.empty?
    arr3 = arr2.map { |placements| { placements: placements } }
    arr4 = []
    arr.sort_by { |len2d| -(len2d[:w] * len2d[:h]) }.each do |grp|
      arr4 << grp unless arr3.any? { |_925b31fd| try_place(_925b31fd, grp, width_mm, height_mm, gap2, allow_rot) }
    end
    [arr3.map { |s| s[:placements] }, arr4]
  end
  def used_area(placements)
    placements.inject(0.0) { |s, members| s + members[:w].to_f * members[:h].to_f }
  end
  def sort_by_x(arr)
    arr.sort_by do |s|
      rec = sheet_recs.find { |i| i[:instance] == s }
      rec ? rec[:bbox].center.x.to_f : 0.0
    end
  end
  def try_place(arr3, grp, width_mm, height_mm, gap2, allow_rot)
    arr2 = [{ w: grp[:w], h: grp[:h], rot: 0 }]
    arr2 << { w: grp[:h], h: grp[:w], rot: 90 } if allow_rot && grp[:rotatable] && (grp[:w] - grp[:h]).abs > 1e-6
    best = nil
    arr2.each do |arr|
      next if arr[:w] > width_mm + 1e-6 || arr[:h] > height_mm + 1e-6
      box = free_spot(arr3[:placements], arr[:w], arr[:h], width_mm, height_mm, gap2)
      next unless box
      if best.nil? || box[:y] < best[:y] - 1e-6 || ((box[:y] - best[:y]).abs < 1e-6 && box[:x] < best[:x])
        best = { x: box[:x], y: box[:y], orient: arr }
      end
    end
    return false unless best
    arr = best[:orient]
    arr3[:placements] << { panel: grp[:panel], source_sheet: grp[:sheet], bbox: grp[:bbox],
                               lx: best[:x], ly: best[:y], w: arr[:w], h: arr[:h], rot: arr[:rot] }
    true
  end
  def free_spot(_758e8d28, pw, ph, width_mm, height_mm, gap2)
    box = KSU::Nesting.find_spot(_758e8d28, pw, ph, width_mm, height_mm, gap2)
    box && { x: box[0], y: box[1] }
  end
  def apply_plan(sheets, arr3, gap_for)
    root_tr = @nesting.transformation
    arr3.each_with_index do |arr2, i|
      grp = sheets[i]
      next unless grp
      arr = sheet_recs.find { |s| s[:instance] == grp }
      next unless arr
      tr = root_tr * grp.transformation
      arr2.each do |members|
        place_panel(members, grp, tr, arr[:bbox], gap_for, root_tr)
      end
    end
  end
  def place_panel(members, grp, tr2, bb, gap_for, root_tr)
    panel = members[:panel]
    return unless panel && panel.valid?
    source_sheet = members[:source_sheet]
    tr3 = root_tr * source_sheet.transformation
    bbox = members[:bbox]
    px = bbox.center.x.to_f
    py = bbox.center.y.to_f
    rot_tf = if members[:rot] != 0
        Geom::Transformation.rotation(Geom::Point3d.new(px, py, bbox.center.z), Z_AXIS, members[:rot] * Math::PI / 180.0)
      else
        Geom::Transformation.new
      end
    _fbf0cf8d, _7e1c7e1d = KSU::Sheet.edit_offset(grp) || [0.0, 0.0]
    gx, gy = KSU::Avail.gaps_for(grp, gap_for)
    dx = bb.min.x.to_f + [_fbf0cf8d, 0.0].max + gx + members[:lx] - (px - members[:w] / 2.0)
    dy = bb.min.y.to_f + [_7e1c7e1d, 0.0].max + gy + members[:ly] - (py - members[:h] / 2.0)
    rvec = Geom::Transformation.translation(Geom::Vector3d.new(dx, dy, 0)) * rot_tf
    tr = tr2.inverse * rvec * tr3 * panel.transformation
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
    num, num2 = KSU::Sheet.edit_offset(sheet) || [0.0, 0.0]
    [bbox.width.to_f - num.abs, bbox.height.to_f - num2.abs]
  end
end
KSU::Nesting.include(KSU::Pack)
