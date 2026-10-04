module KSU::Preset
  @cfg_memo = nil
  COLOR_LIGHT = {
    card: [255, 255, 255],
    fill: [255, 255, 255],
    text: [100, 100, 100],
    text_hover: [0, 0, 0],
    title: [80, 80, 80],
    divider: [0, 0, 0, 15],
    sel_border: [180, 180, 180],
    sel_border_hover: [140, 140, 140],
    ctrl_sel: [120, 120, 120],
    ctrl_hover: [170, 170, 170],
    pill_fill: [255, 255, 255],
    val_sel: [15, 15, 16],
    sw_on: [50, 50, 50],
    sw_on_hover: [28, 28, 29],
    sw_off: [180, 180, 180],
    sw_off_hover: [140, 140, 140],
    knob: [255, 255, 255],
    tri: [180, 180, 180],
    dot_on: [90, 90, 90],
    dot_sel: [0, 0, 0],
    label_sel: [0, 0, 0]
  }.freeze
  COLOR_DARK = {
    card: [58, 58, 60],
    fill: [58, 58, 60],
    text: [229, 229, 234],
    text_hover: [255, 255, 255],
    title: [229, 229, 234],
    divider: [255, 255, 255, 20],
    sel_border: [142, 142, 147],
    sel_border_hover: [174, 174, 178],
    ctrl_sel: [174, 174, 178],
    ctrl_hover: [120, 120, 125],
    pill_fill: [28, 28, 30],
    val_sel: [255, 255, 255],
    sw_on: [52, 179, 88],
    sw_on_hover: [45, 154, 76],
    sw_off: [28, 28, 30],
    sw_off_hover: [72, 72, 74],
    knob: [229, 229, 234],
    tri: [142, 142, 147],
    dot_on: [200, 200, 205],
    dot_sel: [52, 179, 88],
    label_sel: [255, 255, 255]
  }.freeze
  def self.global_key?(key)
    KSU::Const::GLOBAL_SETTING_KEYS.include?(key.to_s)
  end
  def self.colors
    ui[:dark] ? COLOR_DARK : COLOR_LIGHT
  end
  def self.load_cfg
    KSU::Avail.reset3 if defined?(KSU::Avail)
    fsize = KSU::Settings.get("co_chu_cai_dat_mau", 8, "cai_dat")
    font = KSU::Settings.get("kieu_chu", "Arial", "cai_dat")
    font_full = KSU::Settings.get("chu_dam", false, "cai_dat") ? "#{font} Bold" : font
    gap2 = KSU::Settings.get("khoang_cach", 5, "cai_dat")
    str = KSU::Settings.get("giao_dien_cai_dat_toi", false, "cai_dat").to_s == "true"
    v = str ? KSU::Settings.get("do_dam_toi", 85, "cai_dat") : KSU::Settings.get("do_dam", 25, "cai_dat")
    normal = (v * 2.55).round
    screen = KSU::View.ui_scale
    @cfg_memo = {
      font_size: (fsize * screen).round, font: font_full, gap: (gap2 * screen).round,
      radius: (5 * screen).round,
      opacity: { normal: normal, hover: [normal + 70, 255].min },
      hien_preset: KSU::Settings.get("hien_thi_cai_dat_mau", true, "cai_dat"),
      hien_setting: KSU::Settings.get("hien_thi_thong_so", true, "cai_dat"),
      dark: str,
      text_y: nil
    }
  end
  def self.ui
    load_cfg unless @cfg_memo
    @cfg_memo
  end
  def resume(view)
    update_status
    view&.invalidate
  end
  def draw_overlay(view, nesting = nil)
    if @danh_dau_tam_bi_lan
      @_x_bi_lan_polys ||= KSU::Nesting.overlaps(nesting || KSU::Nesting.find_nesting(notify: false))
      KSU::View.draw_polys(@_x_bi_lan_polys, color: KSU::View.warn_color, line: false) if @_x_bi_lan_polys.any?
    end
    KSU::View.draw_error_dots(view, @err_pts) if @danh_dau_loi
  end
  def self.included(normal)
    normal.extend(ClassMethods)
    normal.prepend(SbUserTextHandler)
  end
  module SbUserTextHandler
    def onKeyDown(key, rep, kflags, view)
      if @edit_field && key == 13
        commit_field_input(view)
        @flag62 = true
        return true
      end
      if @flag62 && key == 13
        @flag62 = false
        return true
      end
      return true if @edit_field && handle_field_key(key, view)
      super if defined?(super)
    end
    def onKeyUp(key, rep, kflags, view)
      @flag62 = false if key == 13
      super if defined?(super)
    end
    def deactivate(view)
      close_edit
      super if defined?(super)
    end
    def onUserText(text, view)
      if @edit_field
        commit_field_input(view)
        @flag62 = true
        return
      end
      if @flag62
        @flag62 = false
        return
      end
      super if defined?(super)
    end
    def onReturn(view)
      if @edit_field
        commit_field_input(view)
        @flag62 = true
        return
      end
      if @flag62
        @flag62 = false
        return
      end
      super if defined?(super)
    end
    def update_status
      if @edit_field
        fld = @edit_field
        if @input_buf && !@input_buf.empty?
          disp = @input_buf
        else
          on2 = instance_variable_get("@#{fld[:key]}")
          disp = fmt_value(on2, fld[:fmt])
        end
        KSU.set_vcb(fld[:title], disp)
        return
      end
      super if defined?(super)
    end
  end
  module ClassMethods
    def tool_key(name = nil)
      name ? @tkey = name : @tkey
    end
  end
end
module KSU::Preset
  def self.http_get_curl(url, timeout)
    str = File.join(ENV["TEMP"], "ksu_" + $$.to_s + "_" + rand(99999).to_s + ".tmp")
    wsh = WIN32OLE.new("WScript.Shell")
    str3 = File.join(ENV["SystemRoot"], "System32", "curl.exe")
    rc = wsh.Run("\"" + str3 + "\" -s -k --connect-timeout " + timeout.to_s + " -o \"" + str + "\" \"" + url + "\"", 0, true)
    if rc == 0 && File.exist?(str)
      answer = File.binread(str)
      return answer unless answer.to_s.strip.empty?
    end
    nil
  rescue
    nil
  ensure
    if str && File.exist?(str)
      begin
        File.delete(str)
      rescue StandardError
      end
    end
  end
end
