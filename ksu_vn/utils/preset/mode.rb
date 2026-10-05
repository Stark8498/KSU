module KSU::Mode
  def init_modes(labels, active_proc:, on_click:)
    @modes = labels
    @active_fn = active_proc
    @click_fn = on_click
    @hover_mode_ix = nil
  end
  def draw_modes(view)
    return unless @modes
    view.line_stipple = ""
    layout = mode_layout(view)
    active_ix = @active_fn.call
    @modes.each_with_index do |lbl, i|
      box2 = layout[i]
      active = active_ix == i
      hovered = @hover_mode_ix == i && !active
      border, fill, text_color, lw = field_colors(active, hovered)
      draw_round_rect(view, box2, radius, border: border, fill: fill, line_width: lw, outset: 1)
      draw_text(view, lbl, box2[:x] + box2[:width] / 2.0, text_mid_y(view, box2), text_color, TextAlignCenter)
    end
  end
  def draw_mode_hint(view, text)
    view.line_stipple = ""
    pad_x = size * 5
    elem = size * 3.5
    topts = { size: size, font: font_name }
    w = view.text_bounds(Geom::Point3d.new(0, 0, 0), text, topts).width + pad_x
    box2 = { x: (view.vpwidth - w) / 2.0, y: (10 * KSU::View.ui_scale).round, width: w, height: elem }
    bd2, fill, text_color, lw = field_colors(true, false)
    draw_round_rect(view, box2, radius, border: bd2, fill: fill, line_width: lw, outset: 1)
    draw_text(view, text, box2[:x] + box2[:width] / 2.0, text_mid_y(view, box2), text_color, TextAlignCenter)
  end
  def hover_mode(x, y, view)
    return false unless @modes
    prev_key = @hover_mode_ix
    @hover_mode_ix = nil
    @hover_mode_ix = mode_layout(view).index { |box2| in_rect?(x, y, box2) }
    view.invalidate if prev_key != @hover_mode_ix
    !@hover_mode_ix.nil?
  end
  def click_mode(x, y, view)
    return false unless @modes
    active_ix = @active_fn.call
    i = mode_layout(view).index { |box2| in_rect?(x, y, box2) }
    return false unless i
    @click_fn.call(i) if active_ix != i
    true
  end
  def reload_settings
    @phu_mau_tam = !!get("phu_mau_tam", true) if instance_variable_defined?("@phu_mau_tam")
    @phu_mau_tam_hai_mat = !!get("phu_mau_tam_hai_mat", true) if instance_variable_defined?("@phu_mau_tam_hai_mat")
    @danh_dau_tam_bi_lan = !!get("danh_dau_tam_bi_lan", false) if instance_variable_defined?("@danh_dau_tam_bi_lan")
    @danh_dau_loi = !!get("danh_dau_loi", true) if instance_variable_defined?("@danh_dau_loi")
    @_x_bi_lan_polys = nil if instance_variable_defined?("@_x_bi_lan_polys")
    @tam_cach_nhau = get("tam_cach_nhau", 6.5).to_f.mm if instance_variable_defined?("@tam_cach_nhau")
    @tam_cach_le = get("tam_cach_le", 3.5).to_f.mm if instance_variable_defined?("@tam_cach_le")
    if instance_variable_defined?("@tach_cach_le")
      @tach_cach_le = !!get("tach_cach_le", false)
      edge = get("tam_cach_le", 3.5).to_f
      load_side_margins(edge)
      if instance_variable_defined?("@tam_cach_le_hai_mat")
        @tam_cach_le_hai_mat = get("tam_cach_le_hai_mat", edge).to_f.mm
      end
    end
  end
  private
  def mode_layout(view)
    elem = size * 3.5
    gap2 = gap
    pad_x = size * 5
    topts = { size: size, font: font_name }
    anchor = Geom::Point3d.new(0, 0, 0)
    arr = @modes.map { |_6f2569f7| view.text_bounds(anchor, _6f2569f7, topts).width + pad_x }.max
    num = arr * @modes.size + gap2 * (@modes.size - 1)
    start_x = (view.vpwidth - num) / 2.0
    y = margin_top
    x = start_x
    @modes.map do
      box = { x: x, y: y, width: arr, height: elem }
      x += arr + gap2
      box
    end
  end
end
KSU::Preset.include(KSU::Mode)
module KSU::Mode
  def self.write_binding_key(key, val)
    data = KSU::Font.read_license
    data[key] = val
    KSU::Optimize.write_license(data)
  end
end
