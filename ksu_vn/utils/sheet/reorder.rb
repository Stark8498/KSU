module KSU::Reorder
  def next_type(nesting, forward, sheet_ix)
    return nil unless nesting && nesting.valid?
    h, = sheet_maps(nesting)
    return nil unless h[sheet_ix]
    keys = h.keys.sort
    cur_type = h[sheet_ix].get_attribute("ABF", "sheet-type")
    box = keys.index(sheet_ix)
    random = forward ? (box + 1...keys.size).to_a : (box - 1).downto(0).to_a
    random.each do |i|
      thick = h[keys[i]].get_attribute("ABF", "sheet-type")
      return thick if thick != cur_type
    end
    nil
  end
  def swap_type_block(nesting, forward, sheet_ix)
    return nil unless nesting && nesting.valid?
    h2, bot = sheet_maps(nesting)
    return nil unless h2[sheet_ix]
    keys = h2.keys.sort
    h = {}
    keys.each { |id| h[id] = h2[id].get_attribute("ABF", "sheet-type") }
    cur_type = h[sheet_ix]
    other_type = next_type(nesting, forward, sheet_ix)
    return nil unless other_type
    arr = keys.select { |id| h[id] == cur_type }
    arr2 = keys.select { |id| h[id] == other_type }
    flag = forward ? arr.first : arr2.first
    _bdf6b67b = arr.index(sheet_ix)
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
    arr5[_bdf6b67b]
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
    keys = arr.keys.sort
    part_re2 = part_re
    rows = keys.group_by { |id| arr[id].get_attribute("ABF", "sheet-type").to_s }
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
    _02493448 = keys.min
    flag.each do |thick|
      rows[thick].each do |_c7528123|
        arr[_c7528123].set_attribute("ABF", "sheet-id", _02493448)
        bot[_c7528123].set_attribute("ABF", "sheet-id", _02493448) if bot[_c7528123] && bot[_c7528123].valid?
        _02493448 += 1
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
    keys = arr.keys.sort
    part_re2 = part_re
    suffix = part_suffix
    groups = keys.group_by { |id| base_type(arr[id], part_re2) }
    materials = groups.keys
    num = 0
    materials.each do |normal|
      arr2 = groups[normal].each_slice(per_row).to_a
      label_sel = arr2.size > 1
      arr2.each_with_index do |arr3, _14ea4fab|
        flag = label_sel ? "#{normal}-#{suffix}#{_14ea4fab + 1}" : normal
        arr3.each do |id|
          [arr[id], bot[id]].each do |g|
            next unless g && g.valid?
            num += 1 if g.get_attribute("ABF", "sheet-type").to_s != flag
            g.set_attribute("ABF", "sheet-type", flag)
            if label_sel
              g.set_attribute("KSU", "sheet-type", normal)
              g.set_attribute("KSU", "phan", _14ea4fab + 1)
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
    pad = nesting.get_attribute("KSU", "sheet-id-pad", false)
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
    arr4 = ents.grep(Sketchup::DimensionLinear)
    arr4.each do |len2d|
      next if len2d.deleted? || !len2d.valid?
      next if len2d.get_attribute("KSU", "sheet-label") == true
      next if len2d.get_attribute("KSU", "row-label") == true
      thick = len2d.text.to_s
      next if thick =~ /\A(?:sheet-)?\d+\z/i
      next if type_set[thick]
      str3 = thick
    end
    str3 ||= "Mặt sau"
    ents.erase_entities(arr4) unless arr4.empty?
    arr, bot = sheet_maps(nesting)
    return if arr.empty?
    keys = arr.keys.sort
    sheet_w, _dcd13e53 = sheet_dim(arr[keys.first], nesting)
    pt2 = nesting.transformation.origin
    h = keys.group_by { |id| arr[id].get_attribute("ABF", "sheet-type") }
    arr6 = h.keys
    _c9b1448a = KSU::Settings.get("tuy_chinh_khoang_cach", true, "xep_hang")
    if _c9b1448a
      _6baff1da = KSU::Settings.get("giua_cac_hang", 700, "xep_hang").mm
      _3a4c25ca = KSU::Settings.get("giua_cac_mat", 350, "xep_hang").mm
      _88097773 = KSU::Settings.get("giua_cac_phan", 500, "xep_hang").mm
    else
      _6baff1da = KSU::Const::SHEET_V_PADDING
      _3a4c25ca = KSU::Const::SHEET_V_PADDING / 2.0
      _88097773 = KSU::Const::SHEET_V_PADDING
    end
    num15 = 0.0
    num2 = 0
    box = {}
    _ab80cc5b = nil
    arr6.each do |sheet_type|
      normal = sheet_type.to_s.sub(part_re3, "")
      num15 += (normal == _ab80cc5b ? _88097773 : _6baff1da) unless _ab80cc5b.nil?
      arr2 = h[sheet_type]
      num2 = [num2, arr2.size].max
      flag = false
      oy = num15
      arr2.each_with_index do |id, fill|
        ox = fill * (sheet_w + KSU::Const::SHEET_H_PADDING)
        arr[id].transformation = Geom::Transformation.translation([ox, oy, 0])
        box[id] = [ox, oy]
        flag = true if bot[id]
      end
      num15 += _dcd13e53
      if flag
        by2 = oy + _dcd13e53 + _3a4c25ca
        arr2.each do |id|
          next unless bot[id]
          bx2 = box[id][0]
          bot[id].transformation = Geom::Transformation.translation([bx2, by2, 0])
        end
        num15 = by2 + _dcd13e53
      end
      _ab80cc5b = normal
    end
    _7bc2ff7d = num15
    _865b7251 = KSU::Settings.get("hien_do_day", false, "xep_hang")
    _620ee4af = KSU::Settings.get("hien_so_van", false, "xep_hang")
    _8be1afcd = KSU::Settings.get("cho_phep_xuong_dong", true, "xep_hang")
    _c2afcd7c = KSU::Settings.get("xoa_nhan_mat_sau", true, "xep_hang")
    arr6.each do |sheet_type|
      arr2 = h[sheet_type]
      grp = arr[arr2.first]
      pt3 = grp.transformation.origin.y.to_f
      thickness_mm = grp.get_attribute("ABF", "sheet-thickness")
      lbl = _06da7172(grp, sheet_type.to_s, thickness_mm, arr2.size, _865b7251, _620ee4af, _8be1afcd)
      _edd17adf(ents, lbl, pt3, _dcd13e53)
      arr2.each do |id|
        num = _ef09a8a7(id, keys.max, pad)
        flag2 = prefix.nil? ? nil : label(num, prefix, suffix2)
        _babc606e(ents, arr[id], id, sheet_w, flag2)
        arr[id].name = "__#{sheet_type}-sheet-#{id}"
        bot[id].name = "__#{sheet_type}-sheet-#{id}-bottom" if bot[id]
      end
      next if _c2afcd7c
      _5bf9a6dd = arr2.find { |id| bot[id] }
      next unless _5bf9a6dd
      by2 = bot[_5bf9a6dd].transformation.origin.y.to_f
      _45dac008(ents, str3, num2, by2, sheet_w, _dcd13e53)
    end
    nesting.transformation = Geom::Transformation.translation(
      [-num2 * (sheet_w + KSU::Const::SHEET_H_PADDING) + KSU::Const::SHEET_H_PADDING,
       -_7bc2ff7d - (2.5.m - KSU::Const::SHEET_V_PADDING), 0]
    )
    pt = nesting.transformation.origin - pt2
    return unless pt.length > 0.001
    arr7 = ents.select { |ent| ent.is_a?(Sketchup::Group) && ent.get_attribute("ABF", "board-index") }
    return if arr7.empty?
    vec = Geom::Vector3d.new(-pt.x, -pt.y, -pt.z)
    ents.transform_entities(Geom::Transformation.translation(vec), arr7)
  end
  def _babc606e(ents, grp2, id, sheet_w, text = nil)
    start_x = grp2.transformation.origin.x.to_f
    ly0 = grp2.transformation.origin.y.to_f
    ent2 = ents.add_dimension_linear(
      [start_x + sheet_w / 2.0 - 0.1.mm, ly0 - 5.cm, 0],
      [start_x + sheet_w / 2.0 + 0.1.mm, ly0 - 5.cm, 0], [0, -0.1.mm, 0]
    )
    ent2.arrow_type = Sketchup::Dimension::ARROW_NONE
    _ba804f88(ent2, text || "sheet-#{id}")
    ent2.set_attribute("KSU", "sheet-label", true)
  end
  def _edd17adf(ents, sheet_type, oy, _dcd13e53)
    ent2 = ents.add_dimension_linear(
      [-KSU::Const::SHEET_H_PADDING - 0.1.mm, oy + _dcd13e53 / 2.0, 0],
      [-KSU::Const::SHEET_H_PADDING, oy + _dcd13e53 / 2.0, 0], [0, 0.1.mm, 0]
    )
    ent2.text = sheet_type.to_s
    ent2.has_aligned_text = true
    ent2.arrow_type = Sketchup::Dimension::ARROW_NONE
    ent2.text_position = Sketchup::DimensionLinear::TEXT_OUTSIDE_START
    ent2.set_attribute("KSU", "row-label", true)
  end
  def _06da7172(sheet, sheet_type, thickness_mm, want, _1e94f865, _f35ddd0a, _91035266)
    _ad1ad2d8 = _a7dc970c(thickness_mm)
    head_off = _f4f71a73(sheet, sheet_type, _ad1ad2d8)
    if head_off.empty? && _ad1ad2d8
      head_off = _ad1ad2d8
      _ad1ad2d8 = nil
    end
    phan = _c989e8e4(sheet, sheet_type)
    head_off = "#{head_off}-#{part_suffix}#{phan}" if phan > 0
    arr2 = []
    arr2 << _ad1ad2d8 if _1e94f865 && _ad1ad2d8
    arr2 << "#{want} ván" if _f35ddd0a
    return head_off if arr2.empty?
    str = arr2.join(" - ")
    return str if head_off.empty?
    _91035266 ? "#{head_off}\n#{str}" : "#{head_off} - #{str}"
  end
  def _f4f71a73(sheet, sheet_type, _ad1ad2d8)
    mat = sheet.get_attribute("KSU", "sheet-material")
    return mat.to_s.strip unless mat.nil?
    str = sheet.get_attribute("KSU", "sheet-type")
    normal = str.nil? || str.to_s.empty? ? sheet_type.sub(part_re, "") : str.to_s
    return normal.strip if _ad1ad2d8.nil?
    _bd935f02(normal)
  end
  def _c989e8e4(sheet, sheet_type)
    phan = sheet.get_attribute("KSU", "phan")
    phan.nil? ? part_no(sheet_type) : phan.to_i
  end
  def _bd935f02(normal)
    normal.sub(/\s*-?\s*\d+(?:[.,]\d+)?\s*mm\s*\z/i, "").strip
  end
  def _a7dc970c(thickness_mm)
    return nil if thickness_mm.nil?
    f = thickness_mm.to_f
    return nil if f <= 0
    num = f == f.round ? f.round.to_s : f.to_s
    "#{num}mm"
  end
  def _45dac008(ents, text, _cea5e419, _463aada7, sheet_w, _dcd13e53)
    _d141766a = _cea5e419 * (sheet_w + KSU::Const::SHEET_H_PADDING)
    _1dd94f2a = _463aada7 + _dcd13e53 / 2.0
    ent2 = ents.add_dimension_linear(
      [_d141766a - 0.1.mm, _1dd94f2a, 0], [_d141766a + 0.1.mm, _1dd94f2a, 0], [0, 0.1.mm, 0]
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
  def _ef09a8a7(id, str, pad_x)
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
    out = h.map do |id, g|
      { id: id, gr: g, x: g.transformation.origin.x.to_f, y: g.transformation.origin.y.to_f }
    end
    tol = arr5 * 0.5
    rows = []
    ordered = _2ad1250d ? out.sort_by { |ent| ent[:y] } : out.sort_by { |ent| -ent[:y] }
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
      num = _ef09a8a7(new_id, want, pad_x)
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
      _babc606e(ents, arr[:gr], arr[:new_id], sheet_w, arr[:label])
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
