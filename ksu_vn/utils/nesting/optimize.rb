module KSU::Optimize
  def rotate_allowed?
    !!@cho_phep_xoay
  end
  def rotate_by_keyword?
    !!@xoay_theo_tu_khoa
  end
  def keyword_list
    @danh_sach_tu_khoa.to_s
  end
  def rotate_by_material?
    !!@xoay_theo_vat_lieu
  end
  def material_list
    @danh_sach_vat_lieu.to_s
  end
  def split_two_sided?
    @tach_nhom_2_mat.nil? ? true : !!@tach_nhom_2_mat
  end
  def pack_to_row_start?
    @don_ve_dau_hang.nil? ? true : !!@don_ve_dau_hang
  end
  def start_corner
    v = @goc_don_van.to_s
    v.empty? ? "trai_duoi" : v
  end
  def pack_seed
    case start_corner
    when "phai_duoi" then 1
    when "phai_tren" then 2
    when "trai_tren" then 3
    else 0
    end
  end
  def sheet_recs
    @sheet_memo ||= KSU::Sheet.sheet_list(@nesting)
  end
  def reload_sheets
    @sheet_memo = KSU::Sheet.sheet_list(@nesting)
  end
  def run(groups)
    @added = []
    @pack_cache = {}
    KSU.start
    groups.each_value { |sheets| pack_group(sheets) }
    KSU::Sheet.prune_bottoms(@nesting)
    KSU.commit
    drop_empty_sheets
    @added.select { |s| s && s.valid? }
  end
  def drop_empty_sheets
    num = 0
    loop do
      num += 1
      break if num > 200
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
    arr3 = collect_parts(sheets)
    return if arr3.empty?
    gap_for = @tam_cach_le.to_f
    gap2 = @tam_cach_nhau.to_f
    width_mm, height_mm = usable_size(edited_sheet(sheets), gap_for)
    arr6 = arr3.select { |arr4| arr4[:two_sided] }
    unless split_two_sided? && !arr6.empty?
      arr5 = pack_native(arr3, width_mm, height_mm, gap2, rotate_allowed?)
      return if arr5.empty?
      num3 = ensure_sheets(sheets, arr5.length)
      apply_plan(num3, arr5, gap_for)
      return
    end
    arr8 = arr3.reject { |arr4| arr4[:two_sided] }
    arr = pack_native(arr6, width_mm, height_mm, gap2, rotate_allowed?)
    arr, arr7 = place_leftovers(arr, arr8, width_mm, height_mm, gap2, rotate_allowed?)
    arr2 = arr7.empty? ? [] : pack_native(arr7, width_mm, height_mm, gap2, rotate_allowed?)
    arr = arr.sort_by { |placements| -used_area(placements) } unless arr.empty?
    arr2 = arr2.sort_by { |placements| -used_area(placements) } unless arr2.empty?
    if pack_to_row_start?
      num = arr.empty? ? [] : ensure_sheets(sheets, arr.length)
      num2 = arr2.empty? ? [] : add_sheets(arr2.length, sheets)
      @added.concat(num2)
    else
      num2 = arr2.empty? ? [] : ensure_sheets(sheets, arr2.length)
      num = arr.empty? ? [] : add_sheets(arr.length, sheets)
      @added.concat(num)
      arr2 = arr2.reverse
    end
    reload_sheets
    num = sort_by_x(num)
    num2 = sort_by_x(num2)
    apply_plan(num2, arr2, gap_for) unless arr2.empty?
    apply_plan(num, arr, gap_for) unless arr.empty?
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
  def add_sheets(want, sheets)
    arr = []
    return arr if want <= 0
    grp = rightmost(sheets)
    return arr unless grp
    arr2 = KSU::Sheet.row_of(grp, sheet_recs)
    grp3 = arr2.last || grp
    rec = sheet_recs.find { |s| s[:instance] == grp3 }
    return arr unless rec
    ix = arr2.index(grp3) || (arr2.length - 1)
    pt = KSU::Sheet.row_offset(rec, arr2, ix, sheet_recs)
    base_tr = grp3.transformation
    labels = KSU::Sheet.sheet_labels(grp, @nesting)
    pt3 = grp.transformation.origin
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
      pt2 = tr.origin - pt3
      arr3 = KSU::Sheet.rebuild_dims(labels, pt2, @nesting)
      arr3.each { |len2d| KSU::Sheet.set_dim_text(len2d, str2) }
      arr << grp2
    end
    arr
  end
  def rightmost(arr3)
    best = nil
    max_x = nil
    arr3.each do |s|
      next unless s && s.valid?
      rec = sheet_recs.find { |i| i[:instance] == s }
      next unless rec
      x = rec[:bbox].max.x
      if max_x.nil? || x > max_x
        max_x = x
        best = s
      end
    end
    best
  end
  def max_sheet_no
    hi = 0
    @nesting.definition.entities.each do |ent|
      next unless ent.respond_to?(:name) && ent.name.to_s.downcase.include?("sheet")
      id = KSU::Sheet.sheet_no(ent.name.to_s)
      n = id.to_s[/\d+/]
      hi = n.to_i if n && n.to_i > hi
    end
    hi + 1
  end
  def collect_parts(sheets)
    parts = []
    two_sided_flags = KSU::Nesting.two_sided_set(@nesting)
    sheets.each do |sheet|
      rec = sheet_recs.find { |s| s[:instance] == sheet }
      next unless rec
      sheet_tr = rec[:transform]
      sheet.definition.entities.each do |panel|
        next unless movable?(panel)
        parts << slot_for(panel, sheet, sheet_tr, two_sided_flags)
      end
    end
    parts
  end
  def movable?(panel)
    return false unless KSU.container?(panel)
    return false if panel.name.to_s == "__ABF_sheetBorder"
    return false if KSU::Sheet.sheet_border?(panel)
    return false if KSU::Sheet.mark?(panel)
    return false if KSU::Nesting.last_cut?(panel)
    return false unless KSU::Sheet.drawable?(panel)
    return false if back_face2?(panel)
    true
  end
  def slot_for(panel, sheet, sheet_tr, two_sided_flags)
    bbox = KSU::View.panel_world_box(panel, sheet_tr)
    fill = KSU::Cutting.outline(panel, sheet_tr * panel.transformation)
    holes = fill && fill[:holes] && !fill[:holes].empty? ? fill[:holes] : nil
    outer = fill && fill[:outer] && fill[:outer].length >= 3 ? fill[:outer] : nil
    {
      panel: panel,
      sheet: sheet,
      bbox: bbox,
      w: bbox.width.to_f,
      h: bbox.height.to_f,
      outer: outer,
      holes: holes,
      rotatable: rotatable2(panel, sheet),
      two_sided: !(ix = panel.get_attribute("ABF", "board-index")).nil? && !!two_sided_flags[ix],
      cano: cano(panel, sheet_tr),
    }
  end
  def cano(panel, sheet_tr)
    arr = KSU::Cutting.kids_with_attr(panel, "is-label")
    return 0.0 unless arr
    vec = arr[0].transformation.xaxis.transform(sheet_tr * panel.transformation)
    len = Math.sqrt(vec.x.to_f**2 + vec.y.to_f**2)
    return 0.0 if len < 1e-9
    ang = Math.atan2(-vec.x.to_f, -vec.y.to_f)
    deg = ang * 180.0 / Math::PI
    deg += 360.0 if deg < 0
    num = (deg / 90.0).round * 90.0
    (deg - num).abs < 0.05 ? num % 360.0 : deg
  rescue StandardError
    0.0
  end
  def rotatable2(panel, sheet)
    return rot_for_panel(panel, sheet) if @arr31.is_a?(Hash)
    arr2 = rotate_by_material? ? rot_by_material(material_list) : []
    arr = rotate_by_keyword? ? rot_by_material(keyword_list) : []
    return true if arr2.empty? && arr.empty?
    if !arr2.empty? && sheet && sheet.respond_to?(:get_attribute)
      lbl = sheet.get_attribute("ABF", "sheet-type").to_s.downcase
      return true if !lbl.empty? && arr2.any? { |kw| lbl.include?(kw) }
    end
    if !arr.empty? && panel && panel.respond_to?(:name)
      name = panel.name.to_s.downcase
      return true if arr.any? { |kw| name.include?(kw) }
    end
    false
  end
  def rot_for_panel(panel, sheet)
    sheet_type = sheet && sheet.respond_to?(:get_attribute) ? sheet.get_attribute("ABF", "sheet-type").to_s : ""
    color = @arr31[sheet_type]
    return false unless color
    return true if color[:on]
    arr2 = rot_by_material(color[:kw])
    return false if arr2.empty?
    name = panel.name.to_s.downcase
    arr2.any? { |kw| name.include?(kw) }
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
