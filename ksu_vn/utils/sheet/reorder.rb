module KSU::Reorder
  def next_type(nesting, forward, sheet_ix)
    return nil unless nesting && nesting.valid?
    h, = sheet_maps(nesting)
    return nil unless h[sheet_ix]
    arr = h.keys.sort
    cur_type = h[sheet_ix].get_attribute("ABF", "sheet-type")
    box = arr.index(sheet_ix)
    random = forward ? (box + 1...arr.size).to_a : (box - 1).downto(0).to_a
    random.each do |i|
      thick = h[arr[i]].get_attribute("ABF", "sheet-type")
      return thick if thick != cur_type
    end
    nil
  end
  def swap_type_block(nesting, forward, sheet_ix)
    return nil unless nesting && nesting.valid?
    h2, bot = sheet_maps(nesting)
    return nil unless h2[sheet_ix]
    arr3 = h2.keys.sort
    h = {}
    arr3.each { |id| h[id] = h2[id].get_attribute("ABF", "sheet-type") }
    cur_type = h[sheet_ix]
    other_type = next_type(nesting, forward, sheet_ix)
    return nil unless other_type
    arr = arr3.select { |id| h[id] == cur_type }
    arr2 = arr3.select { |id| h[id] == other_type }
    flag = forward ? arr.first : arr2.first
    ix = arr.index(sheet_ix)
    materials = forward ? (arr2 + arr) : (arr + arr2)
    materials.each_with_index do |id, i|
      new_id = flag + i
      h2[id].set_attribute("ABF", "sheet-id", new_id)
      bot[id].set_attribute("ABF", "sheet-id", new_id) if bot[id]
    end
    renumber_ids(nesting)
    h3, = sheet_maps(nesting)
    arr5 = h3.keys.sort.select do |id|
      h3[id].get_attribute("ABF", "sheet-type") == cur_type
    end
    arr5[ix]
  end
  def erase_sheet(nesting, sheet_ix)
    return false unless nesting && nesting.valid?
    arr2, bot = sheet_maps(nesting)
    sheet = arr2[sheet_ix]
    return false unless sheet && sheet.valid?
    return false unless empty?(sheet)
    sheet.erase!
    bot[sheet_ix].erase! if bot[sheet_ix] && bot[sheet_ix].valid?
    renumber_ids(nesting)
    true
  end
  def part_suffix
    s = KSU::Settings.get("hau_to_phan_manh", "P", "xep_hang").to_s.strip
    s.empty? ? "P" : s
  end
  def part_re
    /-(?:part|#{Regexp.escape(part_suffix)})\d+\z/
  end
  def base_type(g, part_re2)
    str = g.get_attribute("KSU", "sheet-type")
    return str.to_s unless str.nil? || str.to_s.empty?
    g.get_attribute("ABF", "sheet-type").to_s.sub(part_re2, "")
  end
  def renumber_all(nesting)
    return 0 unless nesting && nesting.valid?
    arr, = sheet_maps(nesting)
    return 0 if arr.empty?
    layout_rows(nesting, [arr.size, 1].max)
  end
  def part_no(sheet_type)
    meta = sheet_type.to_s.match(/-(?:part|#{Regexp.escape(part_suffix)})(\d+)\z/)
    meta ? meta[1].to_i : 0
  end
  def sort_sheets(nesting, by:, bottom_up:)
    return 0 unless nesting && nesting.valid?
    arr, bot = sheet_maps(nesting)
    return 0 if arr.empty?
    arr4 = arr.keys.sort
    part_re2 = part_re
    rows = arr4.group_by { |id| arr[id].get_attribute("ABF", "sheet-type").to_s }
    seen = rows.keys
    ordered = seen.sort_by do |thick|
      normal = thick.sub(part_re2, "")
      grp = part_no(thick)
      if by.to_s == "do_day"
        thickness_mm = arr[rows[thick].first].get_attribute("ABF", "sheet-thickness").to_f
        [thickness_mm, normal, grp]
      else
        [normal, grp]
      end
    end
    flag = bottom_up ? ordered : ordered.reverse
    next_id = arr4.min
    flag.each do |thick|
      rows[thick].each do |k|
        arr[k].set_attribute("ABF", "sheet-id", next_id)
        bot[k].set_attribute("ABF", "sheet-id", next_id) if bot[k] && bot[k].valid?
        next_id += 1
      end
    end
    renumber_ids(nesting)
    seen.size
  end
  def layout_rows(nesting, per_row)
    return 0 unless nesting && nesting.valid?
    return 0 unless per_row && per_row > 0
    arr, bot = sheet_maps(nesting)
    return 0 if arr.empty?
    arr5 = arr.keys.sort
    part_re2 = part_re
    suffix = part_suffix
    groups = arr5.group_by { |id| base_type(arr[id], part_re2) }
    materials = groups.keys
    num = 0
    materials.each do |normal|
      arr2 = groups[normal].each_slice(per_row).to_a
      label_sel = arr2.size > 1
      arr2.each_with_index do |arr3, pi|
        flag = label_sel ? "#{normal}-#{suffix}#{pi + 1}" : normal
        arr3.each do |id|
          [arr[id], bot[id]].each do |g|
            next unless g && g.valid?
            num += 1 if g.get_attribute("ABF", "sheet-type").to_s != flag
            g.set_attribute("ABF", "sheet-type", flag)
            if label_sel
              g.set_attribute("KSU", "sheet-type", normal)
              g.set_attribute("KSU", "phan", pi + 1)
            else
              g.delete_attribute("KSU", "sheet-type")
              g.delete_attribute("KSU", "phan")
            end
          end
        end
      end
    end
    renumber_ids(nesting)
    num
  end
  def sheet_dim(sheet, nesting)
    arr = sheet.get_attribute("ABF", "sheet-dimension")
    return [arr[0].mm.to_f, arr[1].mm.to_f] if arr && arr[0] && arr[1]
    bbox = world_bbox(sheet, nesting)
    [bbox.width.to_f, bbox.height.to_f]
  end
  def renumber_ids(nesting)
    return unless nesting && nesting.valid?
    sync_ids(nesting)
    ents = nesting.definition.entities
    prefix = nesting.get_attribute("KSU", "sheet-id-prefix", nil)
    suffix2 = nesting.get_attribute("KSU", "sheet-id-suffix", "")
    zero_pad = nesting.get_attribute("KSU", "sheet-id-pad", false)
    part_re3 = part_re
    type_set = {}
    ents.each do |g|
      next unless g.respond_to?(:get_attribute)
      next unless g.get_attribute("ABF", "sheet-id")
      next if hidden?(g)
      thick = g.get_attribute("ABF", "sheet-type").to_s
      type_set[thick] = true
      type_set[thick.sub(part_re3, "")] = true
    end
    str3 = nil
    base_xy = ents.grep(Sketchup::DimensionLinear)
    base_xy.each do |len2d|
      next if len2d.deleted? || !len2d.valid?
      next if len2d.get_attribute("KSU", "sheet-label") == true
      next if len2d.get_attribute("KSU", "row-label") == true
      thick = len2d.text.to_s
      next if thick =~ /\A(?:sheet-)?\d+\z/i
      next if type_set[thick]
      str3 = thick
    end
    str3 ||= "Mặt sau"
    ents.erase_entities(base_xy) unless base_xy.empty?
    arr, bot = sheet_maps(nesting)
    return if arr.empty?
    arr5 = arr.keys.sort
    sheet_w, row_h = sheet_dim(arr[arr5.first], nesting)
    pt2 = nesting.transformation.origin
    h = arr5.group_by { |id| arr[id].get_attribute("ABF", "sheet-type") }
    arr6 = h.keys
    custom = KSU::Settings.get("tuy_chinh_khoang_cach", true, "xep_hang")
    if custom
      gap_row = KSU::Settings.get("giua_cac_hang", 700, "xep_hang").mm
      gap_face = KSU::Settings.get("giua_cac_mat", 350, "xep_hang").mm
      gap_part = KSU::Settings.get("giua_cac_phan", 500, "xep_hang").mm
    else
      gap_row = KSU::Const::SHEET_V_PADDING
      gap_face = KSU::Const::SHEET_V_PADDING / 2.0
      gap_part = KSU::Const::SHEET_V_PADDING
    end
    num17 = 0.0
    num2 = 0
    box = {}
    prev_type = nil
    arr6.each do |sheet_type|
      normal = sheet_type.to_s.sub(part_re3, "")
      num17 += (normal == prev_type ? gap_part : gap_row) unless prev_type.nil?
      arr2 = h[sheet_type]
      num2 = [num2, arr2.size].max
      flag = false
      oy = num17
      arr2.each_with_index do |id, fill|
        ox = fill * (sheet_w + KSU::Const::SHEET_H_PADDING)
        arr[id].transformation = Geom::Transformation.translation([ox, oy, 0])
        box[id] = [ox, oy]
        flag = true if bot[id]
      end
      num17 += row_h
      if flag
        by2 = oy + row_h + gap_face
        arr2.each do |id|
          next unless bot[id]
          bx2 = box[id][0]
          bot[id].transformation = Geom::Transformation.translation([bx2, by2, 0])
        end
        num17 = by2 + row_h
      end
      prev_type = normal
    end
    total_h = num17
    th_on = KSU::Settings.get("hien_do_day", false, "xep_hang")
    num_on = KSU::Settings.get("hien_so_van", false, "xep_hang")
    wrap_on = KSU::Settings.get("cho_phep_xuong_dong", true, "xep_hang")
    drop_back = KSU::Settings.get("xoa_nhan_mat_sau", true, "xep_hang")
    arr6.each do |sheet_type|
      arr2 = h[sheet_type]
      row0 = arr[arr2.first]
      ty = row0.transformation.origin.y.to_f
      thickness_mm = row0.get_attribute("ABF", "sheet-thickness")
      lbl = row_caption(row0, sheet_type.to_s, thickness_mm, arr2.size, th_on, num_on, wrap_on)
      add_row_label(ents, lbl, ty, row_h)
      arr2.each do |id|
        num = pad_id(id, arr5.max, zero_pad)
        flag2 = prefix.nil? ? nil : label(num, prefix, suffix2)
        add_sheet_label(ents, arr[id], id, sheet_w, flag2)
        arr[id].name = "__#{sheet_type}-sheet-#{id}"
        bot[id].name = "__#{sheet_type}-sheet-#{id}-bottom" if bot[id]
      end
      next if drop_back
      bot_id = arr2.find { |id| bot[id] }
      next unless bot_id
      by2 = bot[bot_id].transformation.origin.y.to_f
      add_bottom_label(ents, str3, num2, by2, sheet_w, row_h)
    end
    nesting.transformation = Geom::Transformation.translation(
      [-num2 * (sheet_w + KSU::Const::SHEET_H_PADDING) + KSU::Const::SHEET_H_PADDING,
       -total_h - (2.5.m - KSU::Const::SHEET_V_PADDING), 0]
    )
    pt = nesting.transformation.origin - pt2
    return unless pt.length > 0.001
    arr7 = ents.select { |ent| ent.is_a?(Sketchup::Group) && ent.get_attribute("ABF", "board-index") }
    return if arr7.empty?
    vec = Geom::Vector3d.new(-pt.x, -pt.y, -pt.z)
    ents.transform_entities(Geom::Transformation.translation(vec), arr7)
  end
  def add_sheet_label(ents, sheet_grp, id, sheet_w, text = nil)
    start_x = sheet_grp.transformation.origin.x.to_f
    ly0 = sheet_grp.transformation.origin.y.to_f
    ent2 = ents.add_dimension_linear(
      [start_x + sheet_w / 2.0 - 0.1.mm, ly0 - 5.cm, 0],
      [start_x + sheet_w / 2.0 + 0.1.mm, ly0 - 5.cm, 0], [0, -0.1.mm, 0]
    )
    ent2.arrow_type = Sketchup::Dimension::ARROW_NONE
    set_dim_text(ent2, text || "sheet-#{id}")
    ent2.set_attribute("KSU", "sheet-label", true)
  end
  def add_row_label(ents, sheet_type, oy, row_h)
    ent2 = ents.add_dimension_linear(
      [-KSU::Const::SHEET_H_PADDING - 0.1.mm, oy + row_h / 2.0, 0],
      [-KSU::Const::SHEET_H_PADDING, oy + row_h / 2.0, 0], [0, 0.1.mm, 0]
    )
    ent2.text = sheet_type.to_s
    ent2.has_aligned_text = true
    ent2.arrow_type = Sketchup::Dimension::ARROW_NONE
    ent2.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_START
    ent2.set_attribute("KSU", "row-label", true)
  end
  def row_caption(sheet, sheet_type, thickness_mm, want, show_th, show_count, wrap)
    th_txt = thickness_text(thickness_mm)
    head_off = material_text(sheet, sheet_type, th_txt)
    if head_off.empty? && th_txt
      head_off = th_txt
      th_txt = nil
    end
    phan = part_no_of(sheet, sheet_type)
    head_off = "#{head_off}-#{part_suffix}#{phan}" if phan > 0
    arr2 = []
    arr2 << th_txt if show_th && th_txt
    arr2 << "#{want} ván" if show_count
    return head_off if arr2.empty?
    tail_pt = arr2.join(" - ")
    return tail_pt if head_off.empty?
    wrap ? "#{head_off}\n#{tail_pt}" : "#{head_off} - #{tail_pt}"
  end
  def material_text(sheet, sheet_type, th_txt)
    mat = sheet.get_attribute("KSU", "sheet-material")
    return mat.to_s.strip unless mat.nil?
    str = sheet.get_attribute("KSU", "sheet-type")
    normal = str.nil? || str.to_s.empty? ? sheet_type.sub(part_re, "") : str.to_s
    return normal.strip if th_txt.nil?
    strip_thickness(normal)
  end
  def part_no_of(sheet, sheet_type)
    phan = sheet.get_attribute("KSU", "phan")
    phan.nil? ? part_no(sheet_type) : phan.to_i
  end
  def strip_thickness(normal)
    normal.sub(/\s*-?\s*\d+(?:[.,]\d+)?\s*mm\s*\z/i, "").strip
  end
  def thickness_text(thickness_mm)
    return nil if thickness_mm.nil?
    f = thickness_mm.to_f
    return nil if f <= 0
    num = f == f.round ? f.round.to_s : f.to_s
    "#{num}mm"
  end
  def add_bottom_label(ents, text, col, by, sheet_w, row_h)
    lx = col * (sheet_w + KSU::Const::SHEET_H_PADDING)
    ly = by + row_h / 2.0
    ent2 = ents.add_dimension_linear(
      [lx - 0.1.mm, ly, 0], [lx + 0.1.mm, ly, 0], [0, 0.1.mm, 0]
    )
    ent2.text = text
    ent2.has_aligned_text = true
    ent2.arrow_type = Sketchup::Dimension::ARROW_NONE
    ent2.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_END
  end
  def label(num, prefix, suffix)
    lbl = num.to_s
    lbl = "#{prefix}#{lbl}" unless prefix.to_s.empty?
    lbl = "#{lbl}#{suffix}" unless suffix.to_s.empty?
    lbl
  end
  def pad_id(id, str, pad_x)
    return id.to_s unless pad_x
    id.to_s.rjust(str.to_s.length, "0")
  end
  def number_plan(nesting, prefix = "", suffix = "", pad_x = false, _2ad1250d = false)
    return nil unless nesting && nesting.valid?
    h, bot = sheet_maps(nesting)
    return nil if h.empty?
    type_set = {}
    h.each_value { |g| type_set[g.get_attribute("ABF", "sheet-type").to_s] = true }
    sheet_w, arr5 = sheet_dim(h.values.first, nesting)
    arr3 = h.map do |id, g|
      { id: id, gr: g, x: g.transformation.origin.x.to_f, y: g.transformation.origin.y.to_f }
    end
    tol = arr5 * 0.5
    rows = []
    ordered = _2ad1250d ? arr3.sort_by { |ent| ent[:y] } : arr3.sort_by { |ent| -ent[:y] }
    ordered.each do |ent|
      if rows.empty? || (rows.last.first[:y] - ent[:y]).abs > tol
        rows << [ent]
      else
        rows.last << ent
      end
    end
    arr2 = rows.flat_map { |half| half.sort_by { |ent| ent[:x] } }
    want = arr2.size
    transform = nesting.transformation
    plan = arr2.each_with_index.map do |ent, i|
      new_id = i + 1
      num = pad_id(new_id, want, pad_x)
      {
        gr: ent[:gr],
        bottom: bot[ent[:id]],
        type: ent[:gr].get_attribute("ABF", "sheet-type"),
        new_id: new_id,
        label: label(num, prefix, suffix),
        point: Geom::Point3d.new(ent[:x] + sheet_w / 2.0, ent[:y], 0).transform(transform),
      }
    end
    { sheet_w: sheet_w, type_set: type_set, plan: plan }
  end
  def apply_numbers(nesting, prefix = "", suffix = "", pad_x = false, _2ad1250d = false)
    sync_ids(nesting)
    data = number_plan(nesting, prefix, suffix, pad_x, _2ad1250d)
    return 0 unless data
    plan = data[:plan]
    sheet_w = data[:sheet_w]
    type_set = data[:type_set]
    ents = nesting.definition.entities
    nesting.set_attribute("KSU", "sheet-id-prefix", prefix)
    nesting.set_attribute("KSU", "sheet-id-suffix", suffix)
    nesting.set_attribute("KSU", "sheet-id-pad", pad_x)
    arr2 = ents.grep(Sketchup::DimensionLinear).select do |len2d|
      next false unless len2d.valid? && !len2d.deleted?
      next true if len2d.get_attribute("KSU", "sheet-label") == true
      thick = len2d.text.to_s
      thick =~ /\A(?:sheet-)?\d+\z/i && !type_set[thick]
    end
    ents.erase_entities(arr2) unless arr2.empty?
    plan.each do |arr|
      arr[:gr].set_attribute("ABF", "sheet-id", arr[:new_id])
      arr[:gr].name = "__#{arr[:type]}-sheet-#{arr[:new_id]}"
      if arr[:bottom] && arr[:bottom].valid?
        arr[:bottom].set_attribute("ABF", "sheet-id", arr[:new_id])
        arr[:bottom].name = "__#{arr[:type]}-sheet-#{arr[:new_id]}-bottom"
      end
      add_sheet_label(ents, arr[:gr], arr[:new_id], sheet_w, arr[:label])
    end
    plan.size
  end
end
KSU::Sheet.extend(KSU::Reorder)
module KSU::Reorder
  @_f9ff0de9 = []
  def self._f9ff0de9
    @_f9ff0de9
  end
  def self._b25875c4(err_code)
    UI.messagebox "Gỡ kích hoạt thất bại! " + KSU::Back._cd99bb15(err_code)
    false
  end
end
