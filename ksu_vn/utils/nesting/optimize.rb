module KSU::Optimize
  def rotate_allowed?
    !!@cho_phep_xoay
  end
  def fill_first_row?
    @don_ve_dau_hang.nil? ? true : !!@don_ve_dau_hang
  end
  def start_corner_index
    %w[trai_duoi phai_duoi phai_tren trai_tren].index(@goc_don_van.to_s) || 0
  end
  def sheet_recs
    @sheet_memo ||= KSU::Sheet.sheet_list(@nesting)
  end
  def reload_sheets
    @sheet_memo = KSU::Sheet.sheet_list(@nesting)
  end
  def drop_empty_sheets
    200.times do
      reload_sheets
      target = sheet_recs.find do |s|
        inst = s[:instance]
        inst && inst.valid? && !KSU::Sheet.hidden?(inst) && KSU::Sheet.empty?(inst)
      end
      break unless target
      break unless KSU::Sheet.remove_sheet(target[:instance], @nesting, sheet_recs)
    end
    reload_sheets
  end
  def pack_group(sheets)
    stroke_w, sheet_h = sheet_size(edited_sheet(sheets))
    return unless stroke_w && sheet_h
    arr4 = collect_parts(sheets)
    return if arr4.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    arr5, _f700cbca = arr4.partition { |arr7| arr7[:two_sided] }
    unless @tach_nhom_2_mat != false && !arr5.empty?
      arr3 = pack_native(arr4, width_mm, height_mm, gap2, rotate_allowed?)
      return if arr3.empty?
      apply_plan(ensure_sheets(sheets, arr3.length), arr3, gap_for)
      return
    end
    arr2 = pack_native(arr5, width_mm, height_mm, gap2, rotate_allowed?)
    arr2, arr6 = place_leftovers(arr2, _f700cbca, width_mm, height_mm, gap2, rotate_allowed?)
    arr = arr6.empty? ? [] : pack_native(arr6, width_mm, height_mm, gap2, rotate_allowed?)
    arr2 = arr2.sort_by { |placements| -used_area(placements) } unless arr2.empty?
    arr = arr.sort_by { |placements| -used_area(placements) } unless arr.empty?
    if fill_first_row?
      num = arr2.empty? ? [] : ensure_sheets(sheets, arr2.length)
      num2 = arr.empty? ? [] : add_sheets(arr.length, sheets)
      @added.concat(num2)
    else
      num2 = arr.empty? ? [] : ensure_sheets(sheets, arr.length)
      num = arr2.empty? ? [] : add_sheets(arr2.length, sheets)
      @added.concat(num)
      arr = arr.reverse
    end
    reload_sheets
    num = sort_by_x(num)
    num2 = sort_by_x(num2)
    apply_plan(num2, arr, gap_for) unless arr.empty?
    apply_plan(num, arr2, gap_for) unless arr2.empty?
  end
  def ensure_sheets(h, want)
    arr = h.dup
    if want > arr.length
      addon_data = add_sheets(want - arr.length, h)
      @added.concat(addon_data)
      arr.concat(addon_data)
      reload_sheets
    end
    arr
  end
  def add_sheets(want, sheet_map)
    arr = []
    return arr if want <= 0
    grp = rightmost(sheet_map)
    return arr unless grp
    arr2 = KSU::Sheet.row_of(grp, sheet_recs)
    grp3 = arr2.last || grp
    rec = sheet_recs.find { |s| s[:instance] == grp3 }
    return arr unless rec
    ix = arr2.index(grp3) || (arr2.length - 1)
    pt = KSU::Sheet.row_offset(rec, arr2, ix, sheet_recs)
    base_tr = grp3.transformation
    labels = KSU::Sheet.sheet_labels(grp, @nesting)
    pt2 = grp.transformation.origin
    str = KSU::Sheet.sheet_no(grp.name.to_s)
    KSU::Sheet.shift_sheets(@nesting, str + 1, want) if str
    want.times do |k|
      n = k + 1
      vec = Geom::Vector3d.new(pt.x * n, pt.y * n, pt.z * n)
      tr = Geom::Transformation.translation(vec) * base_tr
      grp2 = KSU::Sheet.clone_sheet_shell(grp, tr, @nesting)
      next unless grp2 && grp2.valid?
      new_id = str ? str + n : max_sheet_no
      str2 = "sheet-#{new_id}"
      grp2.name = str2
      grp2.set_attribute("ABF", "sheet-id", new_id)
      KSU::Sheet.rebuild_dims(labels, tr.origin - pt2, @nesting).each { |len2d| KSU::Sheet.set_dim_text(len2d, str2) }
      arr << grp2
    end
    arr
  end
  def rightmost(entries)
    best = nil
    max_x = nil
    entries.each do |s|
      next unless s && s.valid?
      rec = sheet_recs.find { |i| i[:instance] == s }
      next unless rec
      _c5211475 = rec[:bbox].max.x
      if max_x.nil? || _c5211475 > max_x
        max_x = _c5211475
        best = s
      end
    end
    best
  end
  def max_sheet_no
    hi = 0
    @nesting.definition.entities.each do |grp|
      next unless grp.respond_to?(:name) && grp.name.to_s.downcase.include?("sheet")
      id = KSU::Sheet.sheet_no(grp.name.to_s)
      hi = id if id && id > hi
    end
    hi + 1
  end
  def collect_parts(sheets)
    two_sided_flags = KSU::Nesting.two_sided_set(@nesting)
    sheets.flat_map do |grp|
      rec = sheet_recs.find { |s| s[:instance] == grp }
      next [] unless rec
      grp.definition.entities.filter_map do |panel|
        slot_for(panel, grp, rec[:transform], two_sided_flags) if movable?(panel)
      end
    end
  end
  def movable?(panel)
    KSU.container?(panel) && panel.name.to_s != "__ABF_sheetBorder" && !KSU::Sheet.sheet_border?(panel) &&
      !KSU::Sheet.mark?(panel) && !KSU::Nesting.last_cut?(panel) && KSU::Sheet.drawable?(panel) &&
      !back_face2?(panel)
  end
  def slot_for(panel, sheet, sheet_tr, two_sided_flags)
    bbox = KSU::View.panel_world_box(panel, sheet_tr)
    fill = KSU::Cutting.outline(panel, sheet_tr * panel.transformation)
    holes = fill && fill[:holes] && !fill[:holes].empty? ? fill[:holes] : nil
    outer = fill && fill[:outer] && fill[:outer].length >= 3 ? fill[:outer] : nil
    { panel: panel, sheet: sheet, bbox: bbox, w: bbox.width.to_f, h: bbox.height.to_f, outer: outer, holes: holes,
      rotatable: rotatable2(panel, sheet),
      two_sided: !(ix = panel.get_attribute("ABF", "board-index")).nil? && !!two_sided_flags[ix],
      cano: cano(panel, sheet_tr) }
  end
  def cano(panel, sheet_tr)
    groups = KSU::Cutting.kids_with_attr(panel, "is-label")
    return 0.0 unless groups
    pt = groups[0].transformation.xaxis.transform(sheet_tr * panel.transformation)
    len = Math.sqrt(pt.x.to_f**2 + pt.y.to_f**2)
    return 0.0 if len < 1e-9
    ang = Math.atan2(-pt.x.to_f, -pt.y.to_f)
    deg = ang * 180.0 / Math::PI
    deg += 360.0 if deg < 0
    num = (deg / 90.0).round * 90.0
    (deg - num).abs < 0.05 ? num % 360.0 : deg
  rescue StandardError
    0.0
  end
  def rotatable2(panel, grp)
    return rot_for_panel(panel, grp) if @arr39.is_a?(Hash)
    arr = @xoay_theo_vat_lieu ? rot_by_material(@danh_sach_vat_lieu) : []
    arr2 = @xoay_theo_tu_khoa ? rot_by_material(@danh_sach_tu_khoa) : []
    return true if arr.empty? && arr2.empty?
    if !arr.empty? && grp && grp.respond_to?(:get_attribute)
      lbl = grp.get_attribute("ABF", "sheet-type").to_s.downcase
      return true if !lbl.empty? && arr.any? { |kw| lbl.include?(kw) }
    end
    if !arr2.empty? && panel && panel.respond_to?(:name)
      name = panel.name.to_s.downcase
      return true if arr2.any? { |kw| name.include?(kw) }
    end
    false
  end
  def rot_for_panel(panel, grp)
    sheet_type = grp && grp.respond_to?(:get_attribute) ? grp.get_attribute("ABF", "sheet-type").to_s : ""
    arr = @arr39[sheet_type]
    return false unless arr
    return true if arr[:on]
    name = panel.name.to_s.downcase
    rot_by_material(arr[:kw]).any? { |kw| name.include?(kw) }
  end
  def rot_by_material(stream)
    stream.to_s.split(/[,\n]/).map { |s| s.strip.downcase }.reject(&:empty?)
  end
end
KSU::Nesting.include(KSU::Optimize)
require "json"
module KSU::Optimize
  def self.write_license(data)
    KSU::View.seed_license_file
    File.write(KSU::Cutting.license_path, KSU::Nfp.pack_key(JSON.generate(data)))
    File.delete(KSU::Collide.license_json) if File.exist?(KSU::Collide.license_json)
  end
end
