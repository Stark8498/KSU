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
      t = h[arr[i]].get_attribute("ABF", "sheet-type")
      return t if t != cur_type
    end
    nil
  end
  def swap_type_block(nesting, forward, sheet_ix)
    return nil unless nesting && nesting.valid?
    h2, bot = sheet_maps(nesting)
    return nil unless h2[sheet_ix]
    arr2 = h2.keys.sort
    h = {}
    arr2.each { |id| h[id] = h2[id].get_attribute("ABF", "sheet-type") }
    cur_type = h[sheet_ix]
    other_type = next_type(nesting, forward, sheet_ix)
    return nil unless other_type
    arr = arr2.select { |id| h[id] == cur_type }
    arr3 = arr2.select { |id| h[id] == other_type }
    flag = forward ? arr.first : arr3.first
    ix = arr.index(sheet_ix)
    materials = forward ? (arr3 + arr) : (arr + arr3)
    materials.each_with_index do |id, i|
      new_id = flag + i
      h2[id].set_attribute("ABF", "sheet-id", new_id)
      bot[id].set_attribute("ABF", "sheet-id", new_id) if bot[id]
    end
    renumber_ids(nesting)
    h3, = sheet_maps(nesting)
    arr4 = h3.keys.sort.select do |id|
      h3[id].get_attribute("ABF", "sheet-type") == cur_type
    end
    arr4[ix]
  end
  def erase_sheet(nesting, sheet_ix)
    return false unless nesting && nesting.valid?
    arr, bot = sheet_maps(nesting)
    grp = arr[sheet_ix]
    return false unless grp && grp.valid?
    return false unless empty?(grp)
    grp.erase!
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
  def base_type(grp, part_re2)
    str = grp.get_attribute("KSU", "sheet-type")
    return str.to_s unless str.nil? || str.to_s.empty?
    grp.get_attribute("ABF", "sheet-type").to_s.sub(part_re2, "")
  end
  def renumber_all(nesting)
    return 0 unless nesting && nesting.valid?
    arr, = sheet_maps(nesting)
    return 0 if arr.empty?
    layout_rows(nesting, arr.size)
  end
  def part_no(sheet_type)
    meta = sheet_type.to_s.match(/-(?:part|#{Regexp.escape(part_suffix)})(\d+)\z/)
    meta ? meta[1].to_i : 0
  end
  def sort_sheets(nesting, by:, bottom_up:)
    return 0 unless nesting && nesting.valid?
    arr, bot = sheet_maps(nesting)
    return 0 if arr.empty?
    arr2 = arr.keys.sort
    part_re2 = part_re
    rows = arr2.group_by { |id| arr[id].get_attribute("ABF", "sheet-type").to_s }
    arr3 = rows.keys
    ordered = arr3.sort_by do |t|
      normal = t.sub(part_re2, "")
      grp = part_no(t)
      if by.to_s == "do_day"
        thickness_mm = arr[rows[t].first].get_attribute("ABF", "sheet-thickness").to_f
        [thickness_mm, normal, grp]
      else
        [normal, grp]
      end
    end
    flag = bottom_up ? ordered : ordered.reverse
    f_adj = arr2.min
    flag.each do |t|
      rows[t].each do |_7eed91e8|
        arr[_7eed91e8].set_attribute("ABF", "sheet-id", f_adj)
        bot[_7eed91e8].set_attribute("ABF", "sheet-id", f_adj) if bot[_7eed91e8] && bot[_7eed91e8].valid?
        f_adj += 1
      end
    end
    renumber_ids(nesting)
    arr3.size
  end
  def layout_rows(nesting, per_row)
    return 0 unless nesting && nesting.valid?
    return 0 unless per_row && per_row > 0
    arr, bot = sheet_maps(nesting)
    return 0 if arr.empty?
    arr3 = arr.keys.sort
    part_re2 = part_re
    suffix = part_suffix
    groups = arr3.group_by { |id| base_type(arr[id], part_re2) }
    num = 0
    groups.each do |normal, arr4|
      arr2 = arr4.each_slice(per_row).to_a
      label_sel = arr2.size > 1
      arr2.each_with_index do |flag10, ci3|
        flag = label_sel ? "#{normal}-#{suffix}#{ci3 + 1}" : normal
        flag10.each do |id|
          [arr[id], bot[id]].each do |grp|
            next unless grp && grp.valid?
            num += 1 if grp.get_attribute("ABF", "sheet-type").to_s != flag
            grp.set_attribute("ABF", "sheet-type", flag)
            if label_sel
              grp.set_attribute("KSU", "sheet-type", normal)
              grp.set_attribute("KSU", "phan", ci3 + 1)
            else
              grp.delete_attribute("KSU", "sheet-type")
              grp.delete_attribute("KSU", "phan")
            end
          end
        end
      end
    end
    renumber_ids(nesting)
    num
  end
  def sheet_dim(grp, nesting)
    arr = grp.get_attribute("ABF", "sheet-dimension")
    return [arr[0].mm.to_f, arr[1].mm.to_f] if arr && arr[0] && arr[1]
    bbox = world_bbox(grp, nesting)
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
    ents.each do |grp|
      next unless grp.respond_to?(:get_attribute)
      next unless grp.get_attribute("ABF", "sheet-id")
      next if hidden?(grp)
      t = grp.get_attribute("ABF", "sheet-type").to_s
      type_set[t] = true
      type_set[t.sub(part_re3, "")] = true
    end
    str = nil
    dim_ents = ents.grep(Sketchup::DimensionLinear)
    dim_ents.each do |len2d|
      next if len2d.deleted? || !len2d.valid?
      next if len2d.get_attribute("KSU", "sheet-label") == true
      next if len2d.get_attribute("KSU", "row-label") == true
      t = len2d.text.to_s
      next if t =~ /\A(?:sheet-)?\d+\z/i
      next if type_set[t]
      str = t
    end
    str ||= "Mặt sau"
    ents.erase_entities(dim_ents) unless dim_ents.empty?
    arr2, bot = sheet_maps(nesting)
    return if arr2.empty?
    arr3 = arr2.keys.sort
    sheet_w, _769bd952 = sheet_dim(arr2[arr3.first], nesting)
    pt2 = nesting.transformation.origin
    h = arr3.group_by { |id| arr2[id].get_attribute("ABF", "sheet-type") }
    arr4 = h.keys
    custom = KSU::Settings.get("tuy_chinh_khoang_cach", true, "xep_hang")
    if custom
      gap_row = KSU::Settings.get("giua_cac_hang", 700, "xep_hang").mm
      gap_face = KSU::Settings.get("giua_cac_mat", 350, "xep_hang").mm
      _0151a74a = KSU::Settings.get("giua_cac_phan", 500, "xep_hang").mm
    else
      gap_row = KSU::Const::SHEET_V_PADDING
      gap_face = KSU::Const::SHEET_V_PADDING / 2.0
      _0151a74a = KSU::Const::SHEET_V_PADDING
    end
    num2 = 0.0
    num3 = 0
    box = {}
    prev_type = nil
    arr4.each do |sheet_type|
      normal = sheet_type.to_s.sub(part_re3, "")
      num2 += (normal == prev_type ? _0151a74a : gap_row) unless prev_type.nil?
      arr = h[sheet_type]
      num3 = [num3, arr.size].max
      flag = false
      oy = num2
      arr.each_with_index do |id, fill|
        ox = fill * (sheet_w + KSU::Const::SHEET_H_PADDING)
        arr2[id].transformation = Geom::Transformation.translation([ox, oy, 0])
        box[id] = [ox, oy]
        flag = true if bot[id]
      end
      num2 += _769bd952
      if flag
        by2 = oy + _769bd952 + gap_face
        arr.each do |id|
          next unless bot[id]
          bx2 = box[id][0]
          bot[id].transformation = Geom::Transformation.translation([bx2, by2, 0])
        end
        num2 = by2 + _769bd952
      end
      prev_type = normal
    end
    th_on = KSU::Settings.get("hien_do_day", false, "xep_hang")
    num_on = KSU::Settings.get("hien_so_van", false, "xep_hang")
    wrap_on = KSU::Settings.get("cho_phep_xuong_dong", true, "xep_hang")
    drop_back = KSU::Settings.get("xoa_nhan_mat_sau", true, "xep_hang")
    arr4.each do |sheet_type|
      arr = h[sheet_type]
      row0 = arr2[arr.first]
      ty = row0.transformation.origin.y.to_f
      thickness_mm = row0.get_attribute("ABF", "sheet-thickness")
      lbl = row_caption(row0, sheet_type.to_s, thickness_mm, arr.size, th_on, num_on, wrap_on)
      add_row_label(ents, lbl, ty, _769bd952)
      arr.each do |id|
        num = pad_id(id, arr3.max, zero_pad)
        flag2 = prefix.nil? ? nil : label(num, prefix, suffix2)
        add_sheet_label(ents, arr2[id], id, sheet_w, flag2)
        arr2[id].name = "__#{sheet_type}-sheet-#{id}"
        bot[id].name = "__#{sheet_type}-sheet-#{id}-bottom" if bot[id]
      end
      next if drop_back
      bot_id = arr.find { |id| bot[id] }
      next unless bot_id
      by2 = bot[bot_id].transformation.origin.y.to_f
      add_bottom_label(ents, str, num3, by2, sheet_w, _769bd952)
    end
    nesting.transformation = Geom::Transformation.translation(
      [-num3 * (sheet_w + KSU::Const::SHEET_H_PADDING) + KSU::Const::SHEET_H_PADDING,
       -num2 - (2.5.m - KSU::Const::SHEET_V_PADDING), 0]
    )
    pt = nesting.transformation.origin - pt2
    return unless pt.length > 0.001
    arr5 = ents.select { |grp2| grp2.is_a?(Sketchup::Group) && grp2.get_attribute("ABF", "board-index") }
    return if arr5.empty?
    vec = Geom::Vector3d.new(-pt.x, -pt.y, -pt.z)
    ents.transform_entities(Geom::Transformation.translation(vec), arr5)
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
  def add_row_label(ents, sheet_type, oy, _769bd952)
    ent2 = ents.add_dimension_linear(
      [-KSU::Const::SHEET_H_PADDING - 0.1.mm, oy + _769bd952 / 2.0, 0],
      [-KSU::Const::SHEET_H_PADDING, oy + _769bd952 / 2.0, 0], [0, 0.1.mm, 0]
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
    arr = []
    arr << th_txt if show_th && th_txt
    arr << "#{want} ván" if show_count
    return head_off if arr.empty?
    tail_pt = arr.join(" - ")
    return tail_pt if head_off.empty?
    wrap ? "#{head_off}\n#{tail_pt}" : "#{head_off} - #{tail_pt}"
  end
  def material_text(grp, sheet_type, th_txt)
    mat = grp.get_attribute("KSU", "sheet-material")
    return mat.to_s.strip unless mat.nil?
    str = grp.get_attribute("KSU", "sheet-type")
    normal = str.nil? || str.to_s.empty? ? sheet_type.sub(part_re, "") : str.to_s
    return normal.strip if th_txt.nil?
    strip_thickness(normal)
  end
  def part_no_of(grp, sheet_type)
    phan = grp.get_attribute("KSU", "phan")
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
  def add_bottom_label(ents, text, _5ce22cfd, by, sheet_w, _769bd952)
    lx = _5ce22cfd * (sheet_w + KSU::Const::SHEET_H_PADDING)
    ly = by + _769bd952 / 2.0
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
  def number_plan(nesting, prefix = "", suffix = "", pad_x = false, by_row = false)
    return nil unless nesting && nesting.valid?
    h, bot = sheet_maps(nesting)
    return nil if h.empty?
    type_set = {}
    h.each_value { |grp| type_set[grp.get_attribute("ABF", "sheet-type").to_s] = true }
    sheet_w, arr3 = sheet_dim(h.values.first, nesting)
    entries = h.map do |id, grp|
      { id: id, gr: grp, x: grp.transformation.origin.x.to_f, y: grp.transformation.origin.y.to_f }
    end
    tol = arr3 * 0.5
    rows = []
    ordered = by_row ? entries.sort_by { |arr| arr[:y] } : entries.sort_by { |arr| -arr[:y] }
    ordered.each do |arr|
      if rows.empty? || (rows.last.first[:y] - arr[:y]).abs > tol
        rows << [arr]
      else
        rows.last << arr
      end
    end
    arr2 = rows.flat_map { |half| half.sort_by { |arr| arr[:x] } }
    want = arr2.size
    tr = nesting.transformation
    plan = arr2.each_with_index.map do |arr, i|
      new_id = i + 1
      num = pad_id(new_id, want, pad_x)
      {
        gr: arr[:gr],
        bottom: bot[arr[:id]],
        type: arr[:gr].get_attribute("ABF", "sheet-type"),
        new_id: new_id,
        label: label(num, prefix, suffix),
        point: Geom::Point3d.new(arr[:x] + sheet_w / 2.0, arr[:y], 0).transform(tr),
      }
    end
    { sheet_w: sheet_w, type_set: type_set, plan: plan }
  end
  def apply_numbers(nesting, prefix = "", suffix = "", pad_x = false, by_row = false)
    sync_ids(nesting)
    data = number_plan(nesting, prefix, suffix, pad_x, by_row)
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
      t = len2d.text.to_s
      t =~ /\A(?:sheet-)?\d+\z/i && !type_set[t]
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
  @id_cache = []
  def self.id_cache
    @id_cache
  end
  def self.deactivate_error(err_code)
    UI.messagebox "Gỡ kích hoạt thất bại! " + KSU::Back.activation_error(err_code)
    false
  end
end
