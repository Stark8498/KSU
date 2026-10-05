module KSU::Field
  def setup_fields(defs)
    @field_defs = defs
    @hover_ix = nil
    @hover_part = nil
    @edit_field = nil
    @open_ix = nil
    @input_buf = nil
    @caret = 0
    @blink_timer = nil
    @caret_on = true
    @vcb_done = false
  end
  def draw_fields(view)
    return unless KSU::Preset.ui[:hien_setting]
    return unless @field_defs
    @view_ref = view
    items = visible_fields
    return if items.empty?
    view.line_stipple = ""
    layout = field_layout(items, view)
    opac = opacity
    draw_panel_bg(view, items, layout, pad, opac)
    items.each_with_index do |fld, i|
      box2 = layout[i]
      hovered = @hover_ix == i
      is_sel = @open_ix == i
      border = is_sel ? palette[:ctrl_sel] : (hovered ? palette[:ctrl_hover] : nil)
      draw_divider(view, layout[i - 1], box2) if i > 0 && !fld[:group_start]
      pad_x = size * (fld[:sub] ? 2.6 : 1.2)
      draw_sub_tick(view, box2, fld, items[i + 1])
      pad2 = size * 1.0
      ty = text_mid_y(view, box2)
      draw_text(view, fld[:title], box2[:x] + pad_x, ty, palette[:title], TextAlignLeft)
      draw_lock(view, lock_rect(view, fld, box2), fld[:lock_open], @hover_part == i) if fld[:lock]
      ent2 = !!fld[:lock_open]
      border = nil if ent2
      width = fld[:type] == :switch ? size * 4 : close_color_picker
      height = row_h2
      arr = {
        x: box2[:x] + box2[:width] - width - pad2,
        y: box2[:y] + box2[:height] / 2.0 - height / 2.0,
        width: width, height: height
      }
      if fld[:type] == :switch
        draw_switch(view, arr, fld[:on], hovered)
      elsif fld[:type] == :text
        draw_round_rect(view, arr, height / 2.0, border: border || palette[:divider], fill: palette[:pill_fill], line_width: 1, outset: 1)
        lbl = fld[:label].to_s
        lbl = "..." if lbl.empty?
        lbl = lbl[0, 13] + "..." if lbl.length > 16
        view.draw_text(
          Geom::Point3d.new(arr[:x] + arr[:width] / 2.0, ty, 0),
          lbl, size: size, font: font_name,
          color: Sketchup::Color.new(*palette[:text]), align: TextAlignCenter
        )
      else
        draw_round_rect(view, arr, height / 2.0, border: border || palette[:divider], fill: palette[:pill_fill], line_width: 1, outset: 1)
        flag = ent2 ? palette[:tri] : (is_sel ? palette[:val_sel] : palette[:text])
        pt = Geom::Point3d.new(arr[:x] + arr[:width] / 2.0, ty, 0)
        flag2 = is_sel && @input_buf && !@input_buf.empty?
        text = flag2 ? @input_buf : fld[:label]
        view.draw_text(pt, text,
                       size: size, font: font_name,
                       color: Sketchup::Color.new(*flag),
                       align: TextAlignCenter)
        if flag2 && @caret_on
          topts = { size: size, font: font_name }
          anchor = Geom::Point3d.new(0, 0, 0)
          txt_w = view.text_bounds(anchor, text, topts).width
          ch = view.text_bounds(anchor, "0", topts).height
          kids = text[0...(@caret || text.length)]
          stroke_w = kids.nil? || kids.empty? ? 0 : view.text_bounds(anchor, kids, topts).width
          px = arr[:x] + arr[:width] / 2.0 - txt_w / 2.0 + stroke_w
          py = arr[:y] + arr[:height] / 2.0
          view.line_width = 1
          view.drawing_color = Sketchup::Color.new(*flag)
          view.draw2d(GL_LINES,
                      Geom::Point3d.new(px, py - ch / 2.0, 0),
                      Geom::Point3d.new(px, py + ch / 2.0, 0))
        end
      end
    end
  end
  def hover_field(x, y, view)
    return false unless KSU::Preset.ui[:hien_setting]
    return false unless @field_defs
    @view_ref = view
    prev_field = @hover_ix
    prev_part = @hover_part
    @hover_ix = nil
    @hover_part = nil
    items = visible_fields
    layout = field_layout(items, view)
    items.each_with_index do |fld, i|
      if in_rect?(x, y, layout[i])
        @hover_ix = i
        @hover_part = i if fld[:lock] && in_rect?(x, y, lock_rect(view, fld, layout[i]))
        break
      end
    end
    view.invalidate if prev_field != @hover_ix || prev_part != @hover_part
    !@hover_ix.nil?
  end
  def busy?
    !@hover_ix.nil? || !@hover_mode_ix.nil? ||
      !@hover_flat.nil? || !@hover_toggle.nil? || !@hover_sec.nil?
  end
  def click_field(x, y, view = nil)
    if @state && @state[:sections]&.any?
      slot_rects.each do |slot|
        next unless slot[:type] == :header
        if in_rect?(x, y, slot[:rect])
          name = slot[:name]
          @collapsed_map[name] = !@collapsed_map[name]
          @layout_memo = nil
          save_collapsed
          (view || @view_ref)&.invalidate
          return true
        end
      end
    end
    return false unless KSU::Preset.ui[:hien_setting]
    return false unless @field_defs
    view ||= @view_ref
    return false unless view
    items = visible_fields
    layout = field_layout(items, view)
    items.each_with_index do |fld, i|
      next unless in_rect?(x, y, layout[i])
      if fld[:lock]
        on_lock = in_rect?(x, y, lock_rect(view, fld, layout[i]))
        if on_lock || fld[:lock_open]
          if on_lock
            val = !instance_variable_get("@#{fld[:lock]}")
            instance_variable_set("@#{fld[:lock]}", val)
            set(fld[:lock], val)
          end
          cancel_edit
          view.invalidate
          return true
        end
      end
      if fld[:type] == :switch
        ivar = "@#{fld[:key]}"
        val = !instance_variable_get(ivar)
        instance_variable_set(ivar, val)
        set(fld[:key], val)
        cancel_edit
      elsif fld[:type] == :select
        ivar = "@#{fld[:key]}"
        keys = fld[:options].keys
        ix = keys.index(instance_variable_get(ivar)) || 0
        val = keys[(ix + 1) % keys.length]
        instance_variable_set(ivar, val)
        set(fld[:key], val)
        cancel_edit
      elsif fld[:type] == :text
        open_tool_settings
        cancel_edit
      elsif @open_ix == i
        cancel_edit
        update_status
      else
        @edit_field = fld
        @open_ix = i
        @input_buf = ""
        @caret = 0
        @caret_on = true
        start_caret_blink
        KSU.set_vcb(fld[:title], fld[:label])
      end
      view.invalidate
      return true
    end
    if @edit_field
      cancel_edit
      update_status
      view.invalidate
    end
    false
  end
  def open_tool_settings
    key = self.class.tool_key
    KSU::Settings.open_settings(key, nil, true) if key
  end
  def handle_field_key(key, view)
    fld = @edit_field
    return false unless fld
    is_float = fld[:fmt] == :mm || !instance_variable_get("@#{fld[:key]}").is_a?(Integer)
    allow_neg = fld[:min].nil? || fld[:min] < 0
    @input_buf ||= ""
    @caret ||= @input_buf.length
    case key
    when 27
      cancel_edit
      update_status
      view.invalidate
      return true
    when 37
      @caret -= 1 if @caret > 0
    when 39
      @caret += 1 if @caret < @input_buf.length
    when 36, 38
      @caret = 0
    when 35, 40
      @caret = @input_buf.length
    when 8
      if @caret > 0
        @input_buf = @input_buf[0...@caret - 1] + @input_buf[@caret..-1]
        @caret -= 1
      end
    when 46
      if @caret < @input_buf.length
        @input_buf = @input_buf[0...@caret] + @input_buf[@caret + 1..-1]
      end
    when 48..57
      insert_char((key - 48).to_s)
    when 96..105
      insert_char((key - 96).to_s)
    when 190, 110, 188
      insert_char(".") if is_float && !@input_buf.include?(".")
    when 189, 109
      insert_char("-") if allow_neg && @caret == 0 && !@input_buf.start_with?("-")
    else
      return false
    end
    @caret_on = true
    view.invalidate
    true
  end
  def insert_char(ch)
    @input_buf = @input_buf[0...@caret] + ch + @input_buf[@caret..-1]
    @caret += 1
  end
  def commit_field_input(view)
    fld = @edit_field
    return false unless fld
    ivar = "@#{fld[:key]}"
    flag = instance_variable_get(ivar).is_a?(Integer)
    txt = (@input_buf || "").strip
    begin
      raise if txt.empty?
      if fld[:fmt] == :mm
        val = txt.to_l.to_mm.to_f.round(2)
        raise if val == 0 && !txt.match?(/\A[0\s]*\z/)
      elsif flag
        raise unless txt.match?(/\A-?\d+\z/)
        val = txt.to_i
      else
        raise unless txt.match?(/\A-?\d*\.?\d+\z/)
        val = txt.to_f
      end
      val = fld[:min] if fld[:min] && val < fld[:min]
      val = fld[:max] if fld[:max] && val > fld[:max]
      instance_variable_set(ivar, fld[:fmt] == :mm ? val.mm : val)
      set(fld[:key], val)
      reload_settings if KSU::Preset.global_key?(fld[:key])
    rescue
    end
    cancel_edit
    update_status
    view.invalidate
    true
  end
  private
  def size
    KSU::Preset.ui[:font_size]
  end
  def radius
    KSU::Preset.ui[:radius]
  end
  def font_name
    KSU::Preset.ui[:font]
  end
  def cache_text_y(view)
    ui = KSU::Preset.ui
    ui[:text_y] ||= begin
      topts = { size: ui[:font_size], font: ui[:font] }
      bnds = view.text_bounds(Geom::Point3d.new(0, 0, 0), "Ag", topts)
      bnds.height / 2.0
    end
  end
  def gap
    KSU::Preset.ui[:gap]
  end
  def opacity
    KSU::Preset.ui[:opacity]
  end
  def row_size
    { width: size * 22 + 5, height: size * 2.85 }
  end
  def close_color_picker
    size * 7.5
  end
  def row_h2
    size * 1.85
  end
  def pad
    size * 0.3
  end
  def hair
    size * 0.1
  end
  def sec_gap
    size * 0.5
  end
  def margin_top
    (5 * KSU::View.ui_scale).round
  end
  def field_colors(is_sel, hovered)
    opac = opacity
    arr = palette
    if is_sel && hovered
      [arr[:sel_border_hover], arr[:fill], arr[:text], 2]
    elsif is_sel
      [arr[:sel_border], arr[:fill], arr[:text], 2]
    elsif hovered
      [nil, arr[:fill] + [opac[:hover]], arr[:text_hover], 1]
    else
      [nil, arr[:fill] + [opac[:normal]], arr[:text], 1]
    end
  end
  def palette
    KSU::Preset.colors
  end
  def draw_round_rect(view, half, r, border:, fill:, line_width: 1, outset: 0)
    x, y, w, elem = half[:x], half[:y], half[:width], half[:height]
    scr = [
      [x + r, y + r, Math::PI],
      [x + w - r, y + r, Math::PI * 1.5],
      [x + w - r, y + elem - r, 0],
      [x + r, y + elem - r, Math::PI / 2]
    ]
    _e7c3b158 = lambda do |_fb5a2a17|
      scr.flat_map { |px, py, a0|
        9.times.map { |i|
          a = a0 + i * Math::PI / 16
          Geom::Point3d.new(px + Math.cos(a) * _fb5a2a17, py + Math.sin(a) * _fb5a2a17, 0)
        }
      }
    end
    pts2 = _e7c3b158.call(r)
    if fill
      view.drawing_color = Sketchup::Color.new(*fill)
      view.draw2d(GL_POLYGON, pts2)
    end
    return unless border
    view.line_width = line_width
    view.drawing_color = Sketchup::Color.new(*border)
    view.draw2d(GL_LINE_LOOP, outset > 0 ? _e7c3b158.call(r + outset) : pts2)
  end
  def draw_switch(view, box2, on, hovered)
    tx, ty, txt_w, _c86c0371 = box2[:x], box2[:y], box2[:width], box2[:height]
    half = _c86c0371 / 2.0
    draw_round_rect(view, box2, half, border: nil, fill: palette[on ? (hovered ? :sw_on_hover : :sw_on) : (hovered ? :sw_off_hover : :sw_off)])
    rr = _c86c0371 / 2.0 - 2 * KSU::View.ui_scale
    flag = on ? tx + txt_w - half : tx + half
    ccy = ty + _c86c0371 / 2.0
    view.drawing_color = Sketchup::Color.new(*palette[:knob])
    view.draw2d(GL_POLYGON, KSU::View.circle_pts(flag, ccy, rr, segments: 24))
  end
  def text_mid_y(view, box2)
    box2[:y] + box2[:height] / 2.0 - cache_text_y(view)
  end
  def draw_text(view, text, x, ty, color, align)
    view.draw_text(Geom::Point3d.new(x, ty, 0), text, size: size, font: font_name, color: Sketchup::Color.new(*color), align: align)
  end
  def draw_divider(view, prev, box2)
    my = (prev[:y] + prev[:height] + box2[:y]) / 2.0
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = Sketchup::Color.new(*palette[:divider])
    view.draw2d(GL_LINES, Geom::Point3d.new(box2[:x] + size, my, 0), Geom::Point3d.new(box2[:x] + box2[:width] - size, my, 0))
  end
  def fmt_value(on2, fmt)
    case fmt
    when :mm
      num = on2.to_mm.round(2)
      num == num.to_i ? num.to_i.to_s : num.to_s
    else
      on2.is_a?(Integer) ? on2.to_s : on2.round(2).to_s
    end
  end
  def cancel_edit
    @edit_field = nil
    @open_ix = nil
    @input_buf = nil
    @caret = 0
    close_edit
  end
  def start_caret_blink
    @blink_timer ||= UI.start_timer(0.5, true) do
      @caret_on = !@caret_on
      @view_ref&.invalidate
    end
  end
  def close_edit
    UI.stop_timer(@blink_timer) if @blink_timer
    @blink_timer = nil
    @caret_on = true
  end
  def visible_fields
    return [] unless @field_defs
    items = []
    @field_defs.each do |sec3, keys|
      group_start = true
      keys.each do |key, job|
        row = job.is_a?(Array) ? job : [job, key.to_s.tr("_", " ")]
        fmt, title, cond, v_min, max = row
        ivar = "@#{key}"
        next unless instance_variable_defined?(ivar)
        on2 = instance_variable_get(ivar)
        if fmt == :select
          opts2 = cond || {}
          next if v_min && !cond_met?(v_min)
          disp = opts2[on2] || on2.to_s
          items << { type: :select, key: key.to_s, title: title, label: disp,
                     fmt: fmt, options: opts2, group_start: group_start }
          group_start = false
          next
        end
        next if cond && !cond_met?(cond)
        if fmt == :switch
          disp = on2 ? "ON" : "OFF"
          items << { type: :switch, key: key.to_s, title: title, label: disp,
                     fmt: fmt, on: !!on2, group_start: group_start }
        elsif fmt == :text
          items << { type: :text, key: key.to_s, title: title, label: on2.to_s, fmt: fmt, group_start: group_start }
        else
          next unless on2.is_a?(Numeric)
          disp = fmt_value(on2, fmt)
          lock = row[5].is_a?(String) ? row[5] : nil
          lock_open = lock ? !!instance_variable_get("@#{lock}") : false
          items << { type: :value, key: key.to_s, title: title, label: disp,
                     fmt: fmt, min: v_min, max: max, group_start: group_start,
                     lock: lock, lock_open: lock_open, sub: row[5] == :sub }
        end
        group_start = false
      end
    end
    items
  end
  def lock_rect(view, fld, box2)
    pad_x = size * 1.2
    txt_w = view.text_bounds(Geom::Point3d.new(0, 0, 0), fld[:title], size: size, font: font_name).width
    rsz = size * 1.6
    { x: box2[:x] + pad_x + txt_w + size * 0.5,
      y: box2[:y] + box2[:height] / 2.0 - rsz / 2.0,
      width: rsz, height: rsz }
  end
  def draw_sub_tick(view, box2, fld, f_adj)
    return unless fld[:sub]
    x = box2[:x] + size * 1.75
    _2e55af75 = box2[:y] + box2[:height] / 2.0
    gap2 = hair
    view.line_stipple = ""
    view.line_width = 1
    view.drawing_color = Sketchup::Color.new(*palette[:divider])
    y_end = f_adj && f_adj[:sub] ? box2[:y] + box2[:height] + gap2 : _2e55af75
    view.draw2d(GL_LINES, Geom::Point3d.new(x, box2[:y] - gap2, 0), Geom::Point3d.new(x, y_end, 0))
    view.draw2d(GL_LINES, Geom::Point3d.new(x, _2e55af75, 0), Geom::Point3d.new(x + size * 0.55, _2e55af75, 0))
  end
  def draw_lock(view, rect, lock_open, hover)
    view.line_stipple = ""
    view.line_width = hover ? 2 : 1
    view.drawing_color = Sketchup::Color.new(*(hover ? palette[:title] : palette[:tri]))
    half = rect[:height] * 0.26
    py = rect[:y] + rect[:height] / 2.0
    px = rect[:x] + rect[:width] / 2.0
    view.draw2d(GL_LINES, Geom::Point3d.new(px - half, py, 0), Geom::Point3d.new(px + half, py, 0))
    return if lock_open
    view.draw2d(GL_LINES, Geom::Point3d.new(px, py - half, 0), Geom::Point3d.new(px, py + half, 0))
  end
  def cond_met?(cond)
    cond.is_a?(Proc) ? instance_exec(&cond) : !!instance_variable_get("@#{cond}")
  end
  def field_layout(items, view)
    w, elem = row_size.values_at(:width, :height)
    gap_for = margin_top
    x = view.vpwidth - gap_for - w
    y = gap_for + pad
    items.each_with_index.map do |fld, i|
      y += fld[:group_start] ? pad + sec_gap + pad : hair if i > 0
      box = { x: x, y: y, width: w, height: elem }
      y += elem
      box
    end
  end
  def draw_panel_bg(view, items, layout, pad_x, opac)
    groups = []
    items.each_with_index do |fld, i|
      if groups.empty? || fld[:group_start]
        groups << [i, i]
      else
        groups.last[1] = i
      end
    end
    groups.each do |a, b|
      p_ref = layout[a]
      p1 = layout[b]
      grp_box = { x: p_ref[:x], y: p_ref[:y] - pad_x, width: p_ref[:width], height: (p1[:y] + p1[:height]) - p_ref[:y] + 2 * pad_x }
      view.line_stipple = ""
      draw_round_rect(view, grp_box, radius, border: palette[:divider], fill: palette[:card] + [opac[:normal]], line_width: 1)
    end
  end
end
KSU::Preset.include(KSU::Field)
module KSU::Field
  def self.activation_ok?(resp)
    return false unless resp
    err_code = resp["code"] || resp.dig("data", "code")
    resp["success"] == true || resp["code"] == "key_activated" || err_code == "instance_already_activated"
  end
end
