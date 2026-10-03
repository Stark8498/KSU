module KSU::Avail
  extend self
  def two_sided_margin
    KSU::Avail.margins[2]
  end
  def two_sided_gap(gap_for)
    two_sided_margin.mm.to_f
  end
  def two_sided?(sheet)
    return false unless sheet && sheet.respond_to?(:get_attribute) && sheet.valid?
    !!sheet.get_attribute("KSU", "two-sided-sheet")
  end
  def reset3
    @margins_memo = nil
  end
  def margins
    @margins_memo ||= begin
      edge = KSU::Settings.get("tam_cach_le", 3.5, "cai_dat").to_f
      if KSU::Settings.get("tach_cach_le", false, "cai_dat").to_s == "true"
        [edge, [KSU::Settings.get("tam_cach_le_trai", edge, "cai_dat").to_f,
                 KSU::Settings.get("tam_cach_le_phai", edge, "cai_dat").to_f,
                 KSU::Settings.get("tam_cach_le_tren", edge, "cai_dat").to_f,
                 KSU::Settings.get("tam_cach_le_duoi", edge, "cai_dat").to_f],
         KSU::Settings.get("tam_cach_le_hai_mat", edge, "cai_dat").to_f]
      else
        [edge, nil, edge]
      end
    end
  end
  def set_override(screen_box)
    @override = screen_box
  end
  def override
    @override
  end
  def sides_mm(num)
    edge, screen_box = KSU::Avail.margins
    return [num.to_f] * 4 unless screen_box && (num.to_f - edge).abs < 1.0e-6
    screen_box.dup
  end
  def sides(gap_for)
    h = KSU::Avail.override
    return h.dup if h
    edge, screen_box = KSU::Avail.margins
    return [gap_for.to_f] * 4 unless screen_box && (gap_for.to_f - edge.mm.to_f).abs < 1.0e-9
    screen_box.map { |v| v.mm.to_f }
  end
  def sides_for(sheet, gap_for)
    _b41d8800, half, thick, b = KSU::Avail.sides(gap_for)
    if sheet && sheet.valid? && KSU::Sheet.hidden?(sheet)
      return [half, _b41d8800, thick, b]
    end
    [_b41d8800, half, thick, b]
  end
  def gaps_for(sheet, gap_for)
    _b41d8800, half, thick, b = KSU::Avail.sides_for(sheet, gap_for)
    return [_b41d8800, b] unless KSU::Avail.two_sided?(sheet)
    g = two_sided_margin.mm.to_f
    [g, g]
  end
  def clamp_move(sheet, arr, gap_for)
    return arr unless KSU::Avail.two_sided?(sheet)
    _b41d8800, half, thick, b = KSU::Avail.sides_for(sheet, gap_for)
    gap2 = two_sided_margin.mm.to_f
    dx = arr[0].to_f
    dy3 = arr[1].to_f
    dx3 = (dx > 0 ? _b41d8800 : half) - gap2
    dy = (dy3 > 0 ? b : thick) - gap2
    dx = (dx > 0 ? [dx - dx3, 0.0].max : [dx + dx3, 0.0].min) if dx3 > 0
    dy3 = (dy3 > 0 ? [dy3 - dy, 0.0].max : [dy3 + dy, 0.0].min) if dy > 0
    [dx, dy3]
  end
  def shrink_poly(poly, num3, num5, num6, num4)
    return poly if num3.abs < 1.0e-9 && num5.abs < 1.0e-9 && num6.abs < 1.0e-9 && num4.abs < 1.0e-9
    bbox = KSU::Geom.bounds(poly)
    tol = 0.1.mm
    poly.map do |pt|
      x = pt.x.to_f
      y = pt.y.to_f
      x += num3 if (x - bbox[:min_x]).abs < tol
      x -= num5 if (x - bbox[:max_x]).abs < tol
      y += num4 if (y - bbox[:min_y]).abs < tol
      y -= num6 if (y - bbox[:max_y]).abs < tol
      Geom::Point3d.new(x, y, pt.z.to_f)
    end
  end
  def needs_extra_gap?(sheet)
    return false unless sheet && sheet.valid?
    return false unless KSU::Sheet.edit_offset(sheet).nil?
    return true if KSU::Avail.two_sided?(sheet)
    KSU::Sheet.marks_of(sheet).any?
  end
  def usable_size(sheet, gap_for)
    stroke_w, sheet_h = sheet_size(sheet)
    return [nil, nil] unless stroke_w && sheet_h
    _b41d8800, half, thick, b = KSU::Avail.sides_for(sheet, gap_for)
    usable_w = stroke_w - _b41d8800 - half
    usable_h = sheet_h - thick - b
    if needs_extra_gap?(sheet)
      len2d = two_sided_gap(gap_for)
      usable_w -= len2d
      usable_h -= len2d
    end
    [usable_w, usable_h]
  end
end
KSU::Avail.reset3
KSU::Avail.set_override(nil)
KSU::Nesting.include(KSU::Avail)
