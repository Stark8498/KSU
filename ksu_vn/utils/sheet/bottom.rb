module KSU::Bottom
  def shift_sheets(nesting, from_id, delta, sort: false)
    return unless nesting && nesting.valid?
    arr = nesting.definition.entities.each_with_object([]) do |grp, _9fe6030e|
      next unless grp.respond_to?(:name)
      name = grp.name.to_s
      next if name.downcase.include?("-bottom")
      id = sheet_no(name)
      next unless id && id >= from_id
      _9fe6030e << {
        instance: grp, id: id,
        bottom: bottom_of(grp, nesting),
        labels: sheet_labels(grp, nesting),
      }
    end
    return if arr.empty?
    arr.sort_by! { |len2d| len2d[:id] } if sort
    arr.each do |len2d|
      inst = len2d[:instance]
      bottom = len2d[:bottom]
      inst.name = "__sheet_tmp_#{inst.entityID}__" if inst && inst.valid?
      bottom.name = "__sheet_tmp_#{bottom.entityID}__-bottom" if bottom && bottom.valid?
    end
    arr.each do |len2d|
      new_id = len2d[:id] + delta
      str = "sheet-#{new_id}"
      inst = len2d[:instance]
      bottom = len2d[:bottom]
      if inst && inst.valid?
        inst.name = str
        inst.set_attribute("ABF", "sheet-id", new_id)
      end
      if bottom && bottom.valid?
        bottom.name = "#{str}-bottom"
        bottom.set_attribute("ABF", "sheet-id", new_id)
      end
      len2d[:labels].each { |slot| set_dim_text(slot[:dim], str) }
    end
  end
  def remove_sheet(grp, nesting, arr24)
    return false unless grp && grp.valid? && empty?(grp)
    return false unless nesting && nesting.valid?
    rec = arr24.find { |s| s[:instance] == grp }
    return false unless rec
    sheet_ix = sheet_no(grp.name.to_s)
    arr = row_of(grp, arr24)
    ix = arr.index(grp) || 0
    offset = row_offset(rec, arr, ix, arr24)
    vec = Geom::Vector3d.new(-offset.x, -offset.y, -offset.z)
    arr2 = arr[(ix + 1)..-1] || []
    arr3 = sheet_labels(grp, nesting)
    arr4 = arr2.each_with_object({}) do |s, elem|
      elem[s] = sheet_labels(s, nesting) if s && s.valid?
    end
    grp2 = bottom_of(grp, nesting)
    KSU.start
    arr3.each { |slot| slot[:dim].erase! if slot[:dim]&.valid? }
    grp.erase! if grp.valid?
    grp2.erase! if grp2 && grp2.valid?
    arr2.each do |s|
      next unless s && s.valid?
      s.transformation = Geom::Transformation.translation(vec) * s.transformation
      shift_dims(arr4[s] || [], vec, nesting)
      bottom = bottom_of(s, nesting)
      bottom.transformation = Geom::Transformation.translation(vec) * bottom.transformation if bottom&.valid?
    end
    shift_sheets(nesting, sheet_ix + 1, -1, sort: true) if sheet_ix
    KSU.commit
    true
  end
  def bottom_sheet?(grp)
    grp && grp.respond_to?(:name) && grp.name.to_s.downcase.include?("-bottom")
  end
  def sheet_no(name)
    meta = name.to_s.match(/sheet-(\d+)/i)
    meta ? meta[1].to_i : nil
  end
  def bottom_of(vec, nesting)
    return nil unless vec && vec.valid? && nesting && nesting.valid?
    str = vec.name.to_s + "-bottom"
    nesting.definition.entities.find do |grp|
      grp.respond_to?(:name) && grp.name.to_s == str
    end
  end
  def bottom_for(vec, nesting)
    return nil unless vec && vec.valid?
    vec2 = bottom_of(vec, nesting)
    return vec2 if vec2 && vec2.valid?
    match_hidden(vec, nesting)
  end
  def back_face?(panel)
    return false unless panel && panel.valid? && panel.respond_to?(:get_attribute)
    !!panel.get_attribute("ABF", "is-bottom-face")
  end
  def first_bottom(nesting)
    nesting.definition.entities.find { |e| bottom_sheet?(e) }
  end
  def top_of(grp2, nesting)
    id = sheet_no(grp2.name.to_s)
    nesting.definition.entities.find do |grp|
      grp.respond_to?(:name) && !bottom_sheet?(grp) &&
        grp.name.to_s.downcase.include?("sheet") &&
        sheet_no(grp.name.to_s) == id
    end
  end
  def has_back?(grp2)
    return false unless grp2 && grp2.valid?
    grp2.definition.entities.any? do |grp|
      KSU.container?(grp) && drawable?(grp) &&
        grp.name.to_s != "__ABF_sheetBorder" && back_face?(grp)
    end
  end
  def prune_bottoms(nesting)
    nesting.definition.entities.to_a.each do |grp|
      next unless bottom_sheet?(grp)
      next if has_back?(grp)
      grp.erase! if grp.valid?
    end
  end
  def index_set(grp)
    h = {}
    return h unless grp && grp.valid?
    grp.definition.entities.each do |grp2|
      next unless cut_panel?(grp2)
      board_index = grp2.get_attribute("ABF", "board-index")
      h[board_index] = true unless board_index.nil?
    end
    h
  end
  def match_hidden(vec, nesting)
    return nil unless vec && vec.valid? && nesting && nesting.valid?
    arr = index_set(vec)
    return nil if arr.empty?
    best = nil
    num = 0
    nesting.definition.entities.each do |e|
      next unless e.respond_to?(:get_attribute) && e != vec
      next unless hidden?(e)
      n = index_set(e).keys.count { |k| arr[k] }
      if n > num
        num = n
        best = e
      end
    end
    best
  end
  def sync_ids(nesting)
    return unless nesting && nesting.valid?
    h = {}
    arr2 = []
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:get_attribute)
      id = grp.get_attribute("ABF", "sheet-id")
      next unless id
      if hidden?(grp)
        arr2 << grp
      else
        index_set(grp).each_key { |board_index| h[board_index] = id }
      end
    end
    return if h.empty? || arr2.empty?
    arr2.each do |b|
      arr = Hash.new(0)
      index_set(b).each_key do |board_index|
        slot2 = h[board_index]
        arr[slot2] += 1 if slot2
      end
      next if arr.empty?
      best = arr.max_by { |arr3| arr3[1] }[0]
      b.set_attribute("ABF", "sheet-id", best) if b.get_attribute("ABF", "sheet-id") != best
    end
  end
  def next_part_sheet(nesting, grp, forward)
    return nil unless nesting && nesting.valid? && grp && grp.valid?
    phan = grp.get_attribute("KSU", "phan")
    return nil if phan.nil?
    phan = phan.to_i
    part_re2 = part_re
    normal = base_type(grp, part_re2)
    arr4, = sheet_maps(nesting)
    arr29 = {}
    arr4.each do |id, grp2|
      next if grp2.get_attribute("KSU", "phan").nil?
      next unless base_type(grp2, part_re2) == normal
      num = grp2.get_attribute("KSU", "phan").to_i
      (arr29[num] ||= []) << [id, grp2]
    end
    flag = forward ? phan + 1 : phan - 1
    return nil unless arr29[flag]
    arr3 = (arr29[phan] || []).sort_by { |arr| arr[0] }.map { |arr| arr[1] }
    fill = arr3.index(grp)
    return nil unless fill
    arr2 = arr29[flag].sort_by { |arr| arr[0] }.map { |arr| arr[1] }
    arr2[[fill, arr2.length - 1].min]
  end
  def drawable?(grp)
    return false unless grp && grp.respond_to?(:name)
    return true if grp.name.to_s =~ /^__/
    return false unless grp.valid? && KSU.container?(grp)
    !grp.get_attribute("ABF", "board-index").nil?
  end
  def part_group?(grp)
    return false unless KSU.container?(grp)
    return false if grp.name.to_s == "__ABF_sheetBorder"
    return false if sheet_border?(grp)
    return false if KSU::Nesting.last_cut?(grp)
    drawable?(grp)
  end
  def cut_panel?(grp)
    return false unless grp && grp.valid? && KSU.container?(grp)
    return false if grp.name.to_s == "__ABF_sheetBorder" || sheet_border?(grp) || mark?(grp) || KSU::Nesting.last_cut?(grp)
    return true unless grp.get_attribute("ABF", "board-index").nil?
    !KSU::Cutting.cutting_group(grp).nil?
  end
  def empty?(grp)
    return false unless grp && grp.valid?
    !grp.definition.entities.any? { |e| KSU.container?(e) && cut_panel?(e) }
  end
  def sheet_border?(entity)
    return false unless entity && entity.respond_to?(:get_attribute)
    !!entity.get_attribute("ABF", "is-sheet-border", nil)
  end
  def world_bbox(grp, nesting)
    return nil unless grp && grp.valid? && nesting && nesting.valid?
    bd2 = border_of(grp)
    if bd2 && bd2.respond_to?(:definition) && bd2.definition
      tr = nesting.transformation * grp.transformation * bd2.transformation
      bb = bd2.definition.bounds
    else
      tr = nesting.transformation * grp.transformation
      bb = grp.definition.bounds
    end
    KSU::Geom.world_box(bb, tr)
  end
  def stock_key(grp)
    return [nil, nil] unless grp && grp.respond_to?(:get_attribute)
    [grp.get_attribute("ABF", "sheet-thickness"), grp.get_attribute("ABF", "sheet-type")]
  end
  def hidden?(grp)
    return false unless grp && grp.valid?
    return true if grp.respond_to?(:get_attribute) && grp.get_attribute("ABF", "is-bottom-sheet")
    bottom_sheet?(grp)
  end
  def clone_sheet_shell(source_sheet, tr, nesting)
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
      add_mark_square(grp, source_sheet, bd2.bounds)
    end
    grp.transformation = tr
    grp.layer = source_sheet.layer if source_sheet.respond_to?(:layer) && source_sheet.layer
    copy_sheet_attrs(source_sheet, grp)
    grp
  end
  def add_mark_square(grp, source_sheet, bbox)
    _821639ac, _98c3a7e0 = inset_of(source_sheet)
    return nil unless _821639ac > 0 && _98c3a7e0 > 0
    z = bbox.min.z
    gr = grp.entities.add_group
    gr.set_attribute("ABF", "is-mark-square", true)
    gr.name = "__ABF_markSquare"
    gr.entities.add_curve(
      [bbox.max.x - _821639ac, bbox.max.y, z],
      [bbox.max.x - _821639ac, bbox.min.y + _98c3a7e0, z],
      [bbox.min.x, bbox.min.y + _98c3a7e0, z]
    )
    KSU::Cutting.set_layer(gr, KSU::Cutting.layer("ABF_markSquare"))
    gr
  end
  def copy_sheet_attrs(src, grp)
    return unless src.respond_to?(:attribute_dictionary)
    arr = src.attribute_dictionary("ABF")
    return unless arr
    ["sheet-dimension", "sheet-id", "sheet-thickness", "sheet-type"].each do |key|
      val = arr[key]
      next if val.nil?
      grp.set_attribute("ABF", key, val)
    end
  end
  def rebuild_dims(_efbb0ef5, offset, nesting)
    _efbb0ef5.each_with_object([]) do |slot, _81111174|
      ent2 = slot[:dim]
      next unless ent2 && ent2.valid?
      s = slot[:start_local]
      e = slot[:end_local]
      next unless s && e
      a, vec = offset_pair(s, e, slot[:container], offset, nesting)
      vec = a.offset(Geom::Vector3d.new(1.mm, 0, 0)) if a.distance(vec) < 1e-6
      vec2 = slot[:offset_vector] || Geom::Vector3d.new(0, 0, 0)
      grp = slot[:container].add_dimension_linear(a, vec, vec2)
      next unless grp && grp.valid?
      set_dim_text(grp, ent2.text) if ent2.respond_to?(:text)
      grp.layer = ent2.layer if ent2.respond_to?(:layer) && ent2.layer && grp.respond_to?(:layer=)
      [:text_position, :arrow_type].each do |attr|
        next unless ent2.respond_to?(attr) && grp.respond_to?("#{attr}=")
        begin
          grp.send("#{attr}=", ent2.send(attr))
        rescue StandardError
          nil
        end
      end
      if ent2.respond_to?(:attribute_dictionaries) && ent2.attribute_dictionaries
        ent2.attribute_dictionaries.each do |h|
          h.each_pair { |k, v| grp.set_attribute(h.name, k, v) }
        end
      end
      style_dim(grp)
      _81111174 << grp
    end
  end
  def sheet_maps(nesting)
    h = {}
    bot = {}
    nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:get_attribute)
      id = grp.get_attribute("ABF", "sheet-id")
      next unless id
      if hidden?(grp)
        bot[id] = grp
      else
        h[id] = grp
      end
    end
    [h, bot]
  end
end
KSU::Sheet.extend(KSU::Bottom)
module KSU::Bottom
  def self.bound_here?
    id = KSU::Arrange.normalize_hw_id(KSU::Caidat.machine_fingerprint)
    id ? [id] : []
  end
end
