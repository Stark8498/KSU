module KSU::Avail
  extend self
  def two_sided_margin
    KSU::Avail.margins[2]
  end
  def two_sided?(grp)
    return false unless grp && grp.respond_to?(:get_attribute) && grp.valid?
    !!grp.get_attribute("KSU", "two-sided-sheet")
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
  def avail_map(gap_for)
    h = KSU::Avail.override
    return h.dup if h
    edge, screen_box = KSU::Avail.margins
    return [gap_for.to_f] * 4 unless screen_box && (gap_for.to_f - edge.mm.to_f).abs < 1.0e-9
    screen_box.map { |v| v.mm.to_f }
  end
  def sides_for(vec, gap_for)
    _6f2569f7, half, t, b = KSU::Avail.avail_map(gap_for)
    return [half, _6f2569f7, t, b] if vec && vec.valid? && KSU::Sheet.hidden?(vec)
    [_6f2569f7, half, t, b]
  end
  def gaps_for(sheet, gap_for)
    _6f2569f7, half, thick, b = KSU::Avail.sides_for(sheet, gap_for)
    return [_6f2569f7, b] unless KSU::Avail.two_sided?(sheet)
    [two_sided_margin.mm.to_f] * 2
  end
  def clamp_move(sheet, table_off, gap_for)
    return table_off unless KSU::Avail.two_sided?(sheet)
    _6f2569f7, half, t, b = KSU::Avail.sides_for(sheet, gap_for)
    gap2 = two_sided_margin.mm.to_f
    flag, num = table_off[0].to_f, table_off[1].to_f
    dx = (flag > 0 ? _6f2569f7 : half) - gap2
    dy = (num > 0 ? b : t) - gap2
    flag = (flag > 0 ? [flag - dx, 0.0].max : [flag + dx, 0.0].min) if dx > 0
    num = (num > 0 ? [num - dy, 0.0].max : [num + dy, 0.0].min) if dy > 0
    [flag, num]
  end
  def shrink_poly(poly, num, num3, num2, glyph_len)
    return poly if num.abs < 1.0e-9 && num3.abs < 1.0e-9 && num2.abs < 1.0e-9 && glyph_len.abs < 1.0e-9
    bbox = KSU::Geom.bounds(poly)
    eps = 0.1.mm
    poly.map do |pt|
      x = pt.x.to_f
      y = pt.y.to_f
      x += num if (x - bbox[:min_x]).abs < eps
      x -= num3 if (x - bbox[:max_x]).abs < eps
      y += glyph_len if (y - bbox[:min_y]).abs < eps
      y -= num2 if (y - bbox[:max_y]).abs < eps
      Geom::Point3d.new(x, y, pt.z.to_f)
    end
  end
  def needs_extra_gap?(vec)
    return false unless vec && vec.valid?
    return false unless KSU::Sheet.edit_offset(vec).nil?
    return true if KSU::Avail.two_sided?(vec)
    KSU::Sheet.marks_of(vec).any?
  end
  def usable_size(sheet, gap_for)
    stroke_w, sheet_h = sheet_size(sheet)
    return [nil, nil] unless stroke_w && sheet_h
    _6f2569f7, half, t, b = KSU::Avail.sides_for(sheet, gap_for)
    len2d = needs_extra_gap?(sheet) ? two_sided_margin.mm.to_f : 0.0
    [stroke_w - _6f2569f7 - half - len2d, sheet_h - t - b - len2d]
  end
end
KSU::Avail.reset3
KSU::Avail.set_override(nil)
KSU::Nesting.include(KSU::Avail)
