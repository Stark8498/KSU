module KSU::Store
  MARGIN_SIDES = { trai: "Lề trái", phai: "Lề phải", tren: "Lề trên", duoi: "Lề dưới" }.freeze
  def load_side_margins(margin, suffix = "")
    MARGIN_SIDES.each_key do |s|
      instance_variable_set("@tam_cach_le_#{s}#{suffix}",
                            get("tam_cach_le_#{s}#{suffix}", margin).to_f.mm)
    end
  end
  def margin_rows(margin, kids, suffix = "", two_sided = false)
    rows = { "tam_cach_le#{suffix}".to_sym =>
                  [:mm, "Tấm cách lề", margin, 0, 100, "tach_cach_le#{suffix}"] }
    MARGIN_SIDES.each do |s, name|
      rows["tam_cach_le_#{s}#{suffix}".to_sym] = [:mm, name, kids, 0, 100, :sub]
    end
    rows[:tam_cach_le_hai_mat] = [:mm, "Lề hai mặt", kids, 0, 100, :sub] if two_sided
    rows
  end
  def get(key, default)
    key6 = KSU::Preset.global_key?(key) ? "cai_dat" : self.class.tool_key
    KSU::Settings.get(key, default, key6)
  end
  def set(key, val)
    key7 = KSU::Preset.global_key?(key) ? "cai_dat" : self.class.tool_key
    KSU::Settings.set(key, val, key7)
    KSU::Settings.push_to_dialog(key7, key, val)
  end
  def load_overlay_settings
    @phu_mau_tam = !!get("phu_mau_tam", true)
    @phu_mau_tam_hai_mat = !!get("phu_mau_tam_hai_mat", true)
    @danh_dau_tam_bi_lan = !!get("danh_dau_tam_bi_lan", false)
    @danh_dau_loi = !!get("danh_dau_loi", true)
  end
  def apply_preset(s)
    apply_settings(s)
  end
  def click_outside(x, y, view)
    id = hit_preset(x, y)
    return false unless id
    unless id == :deselected
      idx = id.to_s.split("_").last.to_i
      apply_preset(@presets[idx]["settings"]) if @presets && @presets[idx]
    end
    view.invalidate
    true
  end
  def load_ivar(key, s, &conv)
    str = s[key.to_s]
    return if str.nil?
    str = conv.call(str) if conv
    instance_variable_set("@#{key}", str)
  end
  def apply_settings(s)
    return unless @field_defs
    @field_defs.each_value do |keys|
      keys.each do |key, job|
        next if KSU::Preset.global_key?(key)
        fmt = job.is_a?(Array) ? job.first : job
        conv2 = case fmt
               when :mm then ->(v) { v.to_f.mm }
               when nil
                 instance_variable_get("@#{key}").is_a?(Integer) ? ->(v) { v.to_i } : ->(v) { v.to_f }
               when :color
                 ->(v) { v.is_a?(Array) ? v.join(",") : v }
               end
        load_ivar(key, s, &conv2)
      end
    end
  end
  def load_presets(preset2)
    return unless preset2
    arr = []
    groups = {}
    preset2.each_with_index do |arr2, i|
      next if arr2["disabled"]
      choice = { id: "preset_#{i}".to_sym, label: arr2["name"] }
      sub = arr2["group"]
      if sub && !sub.empty?
        (groups[sub] ||= []) << choice
      else
        arr << choice
      end
    end
    sections = []
    sections << { name: "Cài đặt mẫu", choices: arr } if arr.any?
    groups.each { |grp2, _4ae5e797| sections << { name: grp2, choices: _4ae5e797 } }
    meta = margin_top
    @state = { x: meta, y: meta, sections: sections, selected: nil }
    @hover_flat = nil
    @hover_toggle = nil
    @collapsed_map = {}
    @hover_sec = nil
    @layout_memo = nil
    load_collapsed
  end
  def draw_presets(view)
    return unless KSU::Preset.ui[:hien_preset]
    return unless @state && @state[:sections]&.any?
    rects = slot_rects
    opac = opacity
    prev = nil
    rects.each do |slot|
      if slot[:type] == :card
        draw_round_rect(view, slot[:rect], radius, border: nil, fill: palette[:card] + [opac[:normal]], line_width: 1)
        prev = nil
      elsif slot[:type] == :header
        draw_section_header(view, slot)
        prev = nil
      else
        draw_divider(view, prev, slot[:rect]) if prev
        draw_preset_item(view, slot)
        prev = slot[:rect]
      end
    end
  end
  def hover_preset(x, y, view)
    return unless KSU::Preset.ui[:hien_preset]
    return unless @state && @state[:sections]&.any?
    prev2 = @hover_flat
    prev_sec = @hover_sec
    prev_tog = @hover_toggle
    @hover_flat = nil
    @hover_sec = nil
    @hover_toggle = nil
    slot_rects.each do |slot|
      if slot[:type] == :header
        if in_rect?(x, y, slot[:rect])
          @hover_sec = slot[:name]
          break
        end
      elsif slot[:type] == :button
        if in_rect?(x, y, toggle_rect(slot[:rect]))
          @hover_toggle = slot[:flat_index]
          @hover_flat = slot[:flat_index]
          break
        elsif in_rect?(x, y, slot[:rect])
          @hover_flat = slot[:flat_index]
          break
        end
      end
    end
    view.invalidate if prev2 != @hover_flat || prev_sec != @hover_sec || prev_tog != @hover_toggle
  end
  def hit_preset(x, y)
    return unless KSU::Preset.ui[:hien_preset]
    return unless @state
    slot_rects.each do |slot|
      next unless slot[:type] == :button
      if in_rect?(x, y, toggle_rect(slot[:rect]))
        choice = slot[:choice]
        idx = choice[:id].to_s.split("_").last.to_i
        pname = @presets && @presets[idx] ? @presets[idx]["name"] : nil
        key = self.class.tool_key
        KSU::Settings.open_settings(key, pname) if key
        return nil
      elsif in_rect?(x, y, slot[:rect])
        choice = slot[:choice]
        if @state[:selected] == choice[:id]
          @state[:selected] = nil
          @state[:modified] = false
          return :deselected
        end
        @state[:selected] = choice[:id]
        @state[:modified] = false
        return choice[:id]
      end
    end
    nil
  end
  def save_selected_preset
    if @state && @state[:selected] && @presets
      idx = @state[:selected].to_s.split("_").last.to_i
      pname = @presets[idx] && @presets[idx]["name"]
      set("cai_dat_mau", pname)
    else
      set("cai_dat_mau", nil)
    end
  end
  def restore_selected_preset
    KSU::Preset.load_cfg
    pname2 = get("cai_dat_mau", nil)
    return unless pname2 && @presets
    idx = @presets.find_index { |arr| arr["name"] == pname2 }
    return unless idx
    if @state
      @state[:selected] = "preset_#{idx}".to_sym
      @state[:modified] = false
    end
    apply_preset(@presets[idx]["settings"])
  end
  def slot_rects
    @layout_memo ||= build_layout
  end
  def build_layout
    return [] unless @state && @state[:sections]
    arr2 = @state
    rsz = row_size
    y = arr2[:y] + pad
    flat_index = 0
    entries = []
    @state[:sections].each_with_index do |key, si|
      y += pad + sec_gap + pad if si > 0
      arr = []
      rect = { x: arr2[:x], y: y, **rsz }
      collapsed2 = @collapsed_map[key[:name]]
      arr << { type: :header, name: key[:name], rect: rect, collapsed: collapsed2 }
      y += rsz[:height]
      unless collapsed2
        key[:choices].each_with_index do |choice, ci3|
          y += ci3 == 0 ? pad : hair
          rect = { x: arr2[:x], y: y, **rsz }
          arr << { type: :button, choice: choice, rect: rect, flat_index: flat_index }
          y += rsz[:height]
          flat_index += 1
        end
      else
        flat_index += key[:choices].size
      end
      row0 = arr.first[:rect]
      last_rect = arr.last[:rect]
      entries << { type: :card, rect: { x: arr2[:x], y: row0[:y] - pad, width: rsz[:width],
                                           height: (last_rect[:y] + last_rect[:height]) - row0[:y] + 2 * pad } }
      entries.concat(arr)
    end
    entries
  end
  def draw_section_header(view, slot)
    box2 = slot[:rect]
    hovered = @hover_sec == slot[:name]
    collapsed2 = slot[:collapsed]
    title_col2 = hovered ? palette[:text_hover] : palette[:title]
    opac = opacity
    card_base = ((opac[:normal] + 255) / 2.0).round
    card_alpha = hovered ? [card_base + 35, 255].min : card_base
    cls2 = pad
    hdr_box = { x: box2[:x], y: box2[:y] - cls2, width: box2[:width], height: box2[:height] + cls2 }
    if collapsed2
      draw_round_rect(view, hdr_box, radius, border: nil, fill: palette[:card] + [card_alpha])
    else
      half = radius
      bx2, by2, bw2, bh2 = hdr_box[:x], hdr_box[:y], hdr_box[:width], hdr_box[:height]
      pts2 = [
        [bx2 + half, by2 + half, Math::PI],
        [bx2 + bw2 - half, by2 + half, Math::PI * 1.5]
      ].flat_map { |px, py, a1b|
        9.times.map { |i|
          a = a1b + i * Math::PI / 16
          Geom::Point3d.new(px + Math.cos(a) * half, py + Math.sin(a) * half, 0)
        }
      }
      pts2 << Geom::Point3d.new(bx2 + bw2, by2 + bh2, 0)
      pts2 << Geom::Point3d.new(bx2, by2 + bh2, 0)
      view.drawing_color = Sketchup::Color.new(*(palette[:card] + [card_alpha]))
      view.draw2d(GL_POLYGON, pts2)
    end
    pad_x = size * 1.2
    draw_text(view, slot[:name], box2[:x] + pad_x, text_mid_y(view, box2), title_col2, TextAlignLeft)
    _d5b3640b = size * 1.0
    icx = box2[:x] + box2[:width] - pad_x - _d5b3640b * 0.5
    icy = box2[:y] + box2[:height] / 2.0
    tri_col = hovered ? palette[:text_hover] : palette[:tri]
    if collapsed2
      tri_pts = [
        Geom::Point3d.new(icx - _d5b3640b * 0.4, icy - _d5b3640b * 0.5, 0),
        Geom::Point3d.new(icx + _d5b3640b * 0.4, icy, 0),
        Geom::Point3d.new(icx - _d5b3640b * 0.4, icy + _d5b3640b * 0.5, 0),
      ]
    else
      tri_pts = [
        Geom::Point3d.new(icx - _d5b3640b * 0.5, icy - _d5b3640b * 0.35, 0),
        Geom::Point3d.new(icx + _d5b3640b * 0.5, icy - _d5b3640b * 0.35, 0),
        Geom::Point3d.new(icx, icy + _d5b3640b * 0.45, 0),
      ]
    end
    view.drawing_color = Sketchup::Color.new(*tri_col)
    view.draw2d(GL_POLYGON, tri_pts)
  end
  def draw_preset_item(view, slot)
    box2 = slot[:rect]
    choice = slot[:choice]
    is_sel = @state[:selected] == choice[:id]
    flat_ix = slot[:flat_index]
    hovered = @hover_flat == flat_ix && @hover_toggle != flat_ix
    on_toggle = @hover_toggle == flat_ix
    pad_x = size * 1.2
    dot_r = size * 0.7
    dot_pad = size * 0.25
    dot = { x: box2[:x] + pad_x, y: box2[:y] + box2[:height] / 2.0 - dot_pad / 2.0, width: dot_r, height: dot_pad }
    dot_col, _52469724 = if on_toggle
                                     [palette[:dot_sel], palette[:dot_sel]]
                                   elsif is_sel || hovered
                                     [palette[:dot_on], palette[:label_sel]]
                                   else
                                     [palette[:tri], palette[:tri]]
                                   end
    draw_round_rect(view, dot, dot_pad / 2.0, border: nil, fill: dot_col)
    draw_text(view, choice[:label], dot[:x] + dot_r + size * 0.6, text_mid_y(view, box2), _52469724, TextAlignLeft)
    knob_r = size * 0.7
    knob_x = box2[:x] + box2[:width] - size * 1.0 - knob_r
    knob_y = box2[:y] + box2[:height] / 2.0
    knob_pts = KSU::View.circle_pts(knob_x, knob_y, knob_r, segments: 24)
    if is_sel
      view.drawing_color = Sketchup::Color.new(*(hovered ? palette[:sw_on_hover] : palette[:sw_on]))
      view.draw2d(GL_POLYGON, knob_pts)
      view.drawing_color = Sketchup::Color.new(*palette[:knob])
      view.draw2d(GL_POLYGON, KSU::View.circle_pts(knob_x, knob_y, knob_r * 0.4, segments: 16))
    else
      view.line_width = 1
      view.drawing_color = Sketchup::Color.new(*(hovered ? palette[:sel_border_hover] : palette[:tri]))
      view.draw2d(GL_LINE_LOOP, knob_pts)
    end
  end
  def toggle_rect(box2)
    { x: box2[:x], y: box2[:y], width: size * 1.2 + size * 1.5, height: box2[:height] }
  end
  def in_rect?(x, y, half)
    x.between?(half[:x], half[:x] + half[:width]) && y.between?(half[:y], half[:y] + half[:height])
  end
  def load_collapsed
    section = self.class.tool_key
    return unless section
    collapsed2 = KSU::Settings.get_raw("collapsed_groups", {}, section) || {}
    collapsed2.each { |name, on2| @collapsed_map[name] = on2 if on2 }
  end
  def save_collapsed
    section = self.class.tool_key
    return unless section
    KSU::Settings.set("collapsed_groups", @collapsed_map, section)
  end
end
KSU::Preset.include(KSU::Store)
module KSU::Store
  def self.set_binding(key, val)
    data = KSU::Push.pack_value(val)
    KSU::Mode.write_binding_key(key, data)
  end
end
