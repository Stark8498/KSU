module KSU::Bottom
  def shift_sheets(nesting, from_id, delta, sort: false)
    return unless nesting && nesting.valid?
    arr = nesting.definition.entities.each_with_object([]) do |ent, _9d031de6|
      next unless ent.respond_to?(:name)
      name = ent.name.to_s
      next if name.downcase.include?("-bottom")
      id = sheet_no(name)
      next unless id && id >= from_id
      _9d031de6 << {
        instance: ent, id: id,
        bottom: bottom(ent, nesting),
        labels: sheet_labels(ent, nesting),
      }
    end
    return if arr.empty?
    arr.sort_by! { |len2d| len2d[:id] } if sort
    arr.each do |len2d|
      inst = len2d[:instance]
      bottom4 = len2d[:bottom]
      inst.name = "__sheet_tmp_#{inst.entityID}__" if inst && inst.valid?
      bottom4.name = "__sheet_tmp_#{bottom4.entityID}__-bottom" if bottom4 && bottom4.valid?
    end
    arr.each do |len2d|
      new_id = len2d[:id] + delta
      str = "sheet-#{new_id}"
      inst = len2d[:instance]
      bottom4 = len2d[:bottom]
      if inst && inst.valid?
        inst.name = str
        inst.set_attribute("ABF", "sheet-id", new_id)
      end
      if bottom4 && bottom4.valid?
        bottom4.name = "#{str}-bottom"
        bottom4.set_attribute("ABF", "sheet-id", new_id)
      end
      len2d[:labels].each { |slot| _ba804f88(slot[:dim], str) }
    end
  end
  def remove_sheet(sheet, nesting, arr23)
    return false unless sheet && sheet.valid? && empty?(sheet)
    return false unless nesting && nesting.valid?
    rec = arr23.find { |s| s[:instance] == sheet }
    return false unless rec
    num19 = sheet_no(sheet.name.to_s)
    arr = row_of(sheet, arr23)
    ix = arr.index(sheet) || 0
    offset = row_offset(rec, arr, ix, arr23)
    vec = Geom::Vector3d.new(-offset.x, -offset.y, -offset.z)
    arr2 = arr[(ix + 1)..-1] || []
    arr4 = sheet_labels(sheet, nesting)
    arr3 = arr2.each_with_object({}) do |s, arr52|
      arr52[s] = sheet_labels(s, nesting) if s && s.valid?
    end
    grp2 = bottom(sheet, nesting)
    KSU.start
    arr4.each { |slot| slot[:dim].erase! if slot[:dim]&.valid? }
    sheet.erase! if sheet.valid?
    grp2.erase! if grp2 && grp2.valid?
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(vec) * s.transformation
      shift_dims(arr3[s] || [], vec, nesting)
      bottom5 = bottom(s, nesting)
      bottom5.transformation = Geom::Transformation.translation(vec) * bottom5.transformation if bottom5&.valid?
    end
    shift_sheets(nesting, num19 + 1, -1, sort: true) if num19
    KSU.commit
    true
  end
  def bottom_sheet?(sheet)
    sheet && sheet.respond_to?(:name) && sheet.name.to_s.downcase.include?("-bottom")
  end
  def sheet_no(name)
    meta = name.to_s.match(/sheet-(\d+)/i)
    meta ? meta[1].to_i : nil
  end
  def bottom(sheet, nesting)
    return nil unless sheet && sheet.valid? && nesting && nesting.valid?
    str = sheet.name.to_s + "-bottom"
    nesting.definition.entities.find do |ent|
      ent.respond_to?(:name) && ent.name.to_s == str
    end
  end
  def bottom_for(sheet, nesting)
    return nil unless sheet && sheet.valid?
    vec2 = bottom(sheet, nesting)
    return vec2 if vec2 && vec2.valid?
    match_hidden(sheet, nesting)
  end
  def back_face?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def first_bottom(nesting)
    nesting.definition.entities.find { |ent| bottom_sheet?(ent) }
  end
  def top_of(tr, nesting)
    id = sheet_no(tr.name.to_s)
    nesting.definition.entities.find do |ent|
      ent.respond_to?(:name) && !bottom_sheet?(ent) &&
        ent.name.to_s.downcase.include?("sheet") &&
        sheet_no(ent.name.to_s) == id
    end
  end
  def has_back?(sheet)
    return false unless sheet && sheet.valid?
    sheet.definition.entities.any? do |ent|
      KSU.container?(ent) && drawable?(ent) &&
        ent.name.to_s != "__ABF_sheetBorder" && back_face?(ent)
    end
  end
  def prune_bottoms(nesting)
    nesting.definition.entities.to_a.each do |sheet|
      next unless bottom_sheet?(sheet)
      next if has_back?(sheet)
      sheet.erase! if sheet.valid?
    end
  end
  def index_set(sheet)
    out = {}
    return out unless sheet && sheet.valid?
    sheet.definition.entities.each do |grp2|
      next unless _ed46427a(grp2)
      board_index = grp2.get_attribute("ABF", "board-index")
      out[board_index] = true unless board_index.nil?
    end
    out
  end
  def match_hidden(sheet, nesting)
    return nil unless sheet && sheet.valid? && nesting && nesting.valid?
    arr = index_set(sheet)
    return nil if arr.empty?
    _477c927d = nil
    num = 0
    nesting.definition.entities.each do |ent|
      next unless ent.respond_to?(:get_attribute) && ent != sheet
      next unless hidden?(ent)
      n = index_set(ent).keys.count { |k| arr[k] }
      if n > num
        num = n
        _477c927d = ent
      end
    end
    _477c927d
  end
  def sync_ids(nesting)
    return unless nesting && nesting.valid?
    h = {}
    arr = []
    nesting.definition.entities.each do |g|
      next unless g.respond_to?(:get_attribute)
      id = g.get_attribute("ABF", "sheet-id")
      next unless id
      if hidden?(g)
        arr << g
      else
        index_set(g).each_key { |board_index| h[board_index] = id }
      end
    end
    return if h.empty? || arr.empty?
    arr.each do |b|
      arr2 = Hash.new(0)
      index_set(b).each_key do |board_index|
        _e305cedd = h[board_index]
        arr2[_e305cedd] += 1 if _e305cedd
      end
      next if arr2.empty?
      _477c927d = arr2.max_by { |arr3| arr3[1] }[0]
      next if _477c927d.nil?
      b.set_attribute("ABF", "sheet-id", _477c927d) if b.get_attribute("ABF", "sheet-id") != _477c927d
    end
  end
  def _de0a88d4(nesting, sheet, forward)
    return nil unless nesting && nesting.valid? && sheet && sheet.valid?
    phan = sheet.get_attribute("KSU", "phan")
    return nil if phan.nil?
    phan = phan.to_i
    part_re2 = part_re
    normal = base_type(sheet, part_re2)
    arr4, = sheet_maps(nesting)
    parts = {}
    arr4.each do |id, g|
      next if g.get_attribute("KSU", "phan").nil?
      next unless base_type(g, part_re2) == normal
      num = g.get_attribute("KSU", "phan").to_i
      (parts[num] ||= []) << [id, g]
    end
    flag = forward ? phan + 1 : phan - 1
    return nil unless parts[flag]
    arr3 = (parts[phan] || []).sort_by { |arr| arr[0] }.map { |arr| arr[1] }
    fill = arr3.index(sheet)
    return nil unless fill
    arr2 = parts[flag].sort_by { |arr| arr[0] }.map { |arr| arr[1] }
    arr2[[fill, arr2.length - 1].min]
  end
  def drawable?(ent)
    return false unless ent && ent.respond_to?(:name)
    return true if ent.name.to_s =~ /^__/
    return false unless ent.valid? && KSU.container?(ent)
    !ent.get_attribute("ABF", "board-index").nil?
  end
  def panel?(ent)
    return false unless KSU.container?(ent)
    return false if ent.name.to_s == "__ABF_sheetBorder"
    return false if _27ecfdd1(ent)
    return false if KSU::Nesting.last_cut?(ent)
    drawable?(ent)
  end
  def _ed46427a(ent)
    return false unless ent && ent.valid? && KSU.container?(ent)
    return false if ent.name.to_s == "__ABF_sheetBorder" || _27ecfdd1(ent) || mark?(ent) || KSU::Nesting.last_cut?(ent)
    return true unless ent.get_attribute("ABF", "board-index").nil?
    !KSU::Cutting.cutting_group(ent).nil?
  end
  def empty?(sheet)
    return false unless sheet && sheet.valid?
    !sheet.definition.entities.any? { |ent| KSU.container?(ent) && _ed46427a(ent) }
  end
  def _27ecfdd1(entity)
    return false unless entity && entity.respond_to?(:get_attribute)
    !!entity.get_attribute("ABF", "is-sheet-border", nil)
  end
  def world_bbox(sheet, nesting)
    return nil unless sheet && sheet.valid? && nesting && nesting.valid?
    bd2 = border_of(sheet)
    if bd2 && bd2.respond_to?(:definition) && bd2.definition
      tr = nesting.transformation * sheet.transformation * bd2.transformation
      bb = bd2.definition.bounds
    else
      tr = nesting.transformation * sheet.transformation
      bb = sheet.definition.bounds
    end
    bbox = Geom::BoundingBox.new
    (0..7).each { |i| bbox.add(bb.corner(i).transform(tr)) }
    bbox
  end
  def _7b0a38ee(sheet)
    return [nil, nil] unless sheet && sheet.respond_to?(:get_attribute)
    [sheet.get_attribute("ABF", "sheet-thickness"), sheet.get_attribute("ABF", "sheet-type")]
  end
  def hidden?(sheet)
    return false unless sheet && sheet.valid?
    return true if sheet.respond_to?(:get_attribute) && sheet.get_attribute("ABF", "is-bottom-sheet")
    bottom_sheet?(sheet)
  end
  def _f74b0a99(source_sheet, _ca47420d, nesting)
    return nil unless source_sheet && source_sheet.valid? && nesting && nesting.valid?
    grp = nesting.definition.entities.add_group
    grp.name = "__sheet_tmp_#{grp.entityID}"
    bd2 = border_of(source_sheet)
    if bd2 && bd2.respond_to?(:definition) && bd2.definition
      grp2 = grp.entities.add_instance(bd2.definition, bd2.transformation)
      grp2.name = "__ABF_sheetBorder"
      grp2.layer = bd2.layer if bd2.respond_to?(:layer) && bd2.layer
      grp2.set_attribute("ABF", "is-sheet-border", true)
    end
    if hidden?(source_sheet) && marks_of(source_sheet).any? &&
       bd2 && bd2.respond_to?(:bounds) && bd2.bounds.valid?
      _e9938e09(grp, source_sheet, bd2.bounds)
    end
    grp.transformation = _ca47420d
    grp.layer = source_sheet.layer if source_sheet.respond_to?(:layer) && source_sheet.layer
    _7c7845a7(source_sheet, grp)
    grp
  end
  def _e9938e09(sheet, source_sheet, bbox)
    _3e7613f3, _9ba1a361 = inset_of(source_sheet)
    return nil unless _3e7613f3 > 0 && _9ba1a361 > 0
    z = bbox.min.z
    gr = sheet.entities.add_group
    gr.set_attribute("ABF", "is-mark-square", true)
    gr.name = "__ABF_markSquare"
    gr.entities.add_curve(
      [bbox.max.x - _3e7613f3, bbox.max.y, z],
      [bbox.max.x - _3e7613f3, bbox.min.y + _9ba1a361, z],
      [bbox.min.x, bbox.min.y + _9ba1a361, z]
    )
    model = Sketchup.active_model.layers["ABF_markSquare"] || Sketchup.active_model.layers.add("ABF_markSquare")
    KSU::Cutting.set_layer(gr, model) if model
    gr
  end
  def _7c7845a7(src, grp)
    return unless src.respond_to?(:attribute_dictionary)
    arr = src.attribute_dictionary("ABF")
    return unless arr
    ["sheet-dimension", "sheet-id", "sheet-thickness", "sheet-type"].each do |key|
      value = arr[key]
      next if value.nil?
      grp.set_attribute("ABF", key, value)
    end
  end
  def _a9a86c81(_ad02b761, _c99d52a7, nesting)
    _ad02b761.each_with_object([]) do |slot, _e4e21066|
      ent2 = slot[:dim]
      next unless ent2 && ent2.valid?
      s = slot[:start_local]
      ent = slot[:end_local]
      next unless s && ent
      a, b = offset_pair(s, ent, slot[:container], _c99d52a7, nesting)
      b = a.offset(Geom::Vector3d.new(1.mm, 0, 0)) if a.distance(b) < 1e-6
      vec2 = slot[:offset_vector] || Geom::Vector3d.new(0, 0, 0)
      grp2 = slot[:container].add_dimension_linear(a, b, vec2)
      next unless grp2 && grp2.valid?
      _ba804f88(grp2, ent2.text) if ent2.respond_to?(:text)
      grp2.layer = ent2.layer if ent2.respond_to?(:layer) && ent2.layer && grp2.respond_to?(:layer=)
      [:text_position, :arrow_type].each do |_45171888|
        next unless ent2.respond_to?(_45171888) && grp2.respond_to?("#{_45171888}=")
        begin
          grp2.send("#{_45171888}=", ent2.send(_45171888))
        rescue StandardError
          nil
        end
      end
      if ent2.respond_to?(:attribute_dictionaries) && ent2.attribute_dictionaries
        ent2.attribute_dictionaries.each do |h|
          h.each_pair { |k, v| grp2.set_attribute(h.name, k, v) }
        end
      end
      _9728a3d1(grp2)
      _e4e21066 << grp2
    end
  end
  def sheet_maps(nesting)
    h2 = {}
    bot = {}
    nesting.definition.entities.each do |g|
      next unless g.respond_to?(:get_attribute)
      id = g.get_attribute("ABF", "sheet-id")
      next unless id
      if hidden?(g)
        bot[id] = g
      else
        h2[id] = g
      end
    end
    [h2, bot]
  end
end
KSU::Sheet.extend(KSU::Bottom)
module KSU::Bottom
  def self._016675b8
    id = KSU::Arrange._9fcc1956(KSU::Caidat.machine_fingerprint)
    id ? [id] : []
  end
end
