require "json"
require "fileutils"
module KSU::Xuatdxf
  def self.open
    KSU::Settings.check_license
    KSU::Xeptam.assert_license
    KSU::Settings.open_window("xuat_dxf")
  end
  def self.handle_action(dlg, action, id)
    case action
    when "load_data", "reload_data"
      n = KSU::Nesting.find_nesting(notify: false)
      load_data(dlg, n ? collect_in_rect(n) : { materials: [], sheets: [] })
    when "save_setting"
      k, v = id.to_s.split("@", 2)
      return if k.to_s.empty?
      KSU::Settings.set(k, KSU::Settings.parse_value(v), "xuat_dxf")
    when "save_materials"
      KSU::Settings.set("vat_lieu_chon", id.to_s, "xuat_dxf")
    when "export_request"
      export_request(id)
    end
  end
  def self.load_data(dlg, collect_in_rect)
    arr = _89a2e173(collect_in_rect)
    arr[:settings] = {
      "ty_le_zoom" => KSU::Settings.get("ty_le_zoom", 220, "xuat_dxf").to_i,
      "goc_xoay" => KSU::Settings.get("goc_xoay", 0, "xuat_dxf").to_i,
      "che_do_xem" => KSU::Settings.get("che_do_xem", "so_do", "xuat_dxf").to_s,
      "hien_tiet_dien" => !!KSU::Settings.get("hien_tiet_dien", true, "xuat_dxf"),
      "hien_mau_layer" => !!KSU::Settings.get("hien_mau_layer", true, "xuat_dxf"),
      "hien_mat_sau" => !!KSU::Settings.get("hien_mat_sau", false, "xuat_dxf"),
      "toi_uu_xuong_dao" => !!KSU::Settings.get("toi_uu_xuong_dao", false, "xuat_dxf"),
      "khoang_cach_goc" => KSU::Settings.get("khoang_cach_goc", 50.0, "xuat_dxf").to_f
    }
    KSU::Settings.send_to_dialog(dlg, "xuat_dxf", "xbvLoad", arr.to_json)
  end
  def self.export_request(_3c8ec851 = nil)
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting && nesting.valid?
    _1cb4f865(nesting)
    collect_in_rect = collect_in_rect(nesting)
    sheets = set_selection(collect_in_rect[:sheets], _3c8ec851)
    if sheets.empty?
      UI.messagebox("Chưa chọn loại ván nào để xuất.")
      return
    end
    title = _2b17a799(Sketchup.active_model.title)
    title = "KSU" if title.empty?
    dir = UI.savepanel("Xuất DXF", KSU.model_dir, title + "__" + Time.now.strftime("%H-%M-%S"))
    return unless dir
    ok = _4db09033(dir, collect_in_rect, sheets)
    UI.openURL("file:///" + dir.gsub("\\", "/")) if ok
  rescue StandardError => ent
    UI.messagebox("Lỗi xuất DXF: #{ent.message}")
  end
  def self._1cb4f865(nesting)
    arr = []
    nesting.definition.entities.each do |sheet|
      next unless KSU.container?(sheet)
      next unless sheet.get_attribute("ABF", "sheet-id")
      (KSU.entities_in(sheet) || []).each do |ent|
        if ent.get_attribute("ABF", "is-sheet-id") || ent.get_attribute("ABF", "is-sheet-material")
          arr << ent
        end
      end
    end
    model = Sketchup.active_model
    arr9 = ["ABF_sheetId", "ABF_sheetMaterial"].map { |n| model.layers[n] }.compact
    return if arr.empty? && arr9.empty?
    KSU.start
    arr.each { |ent| ent.erase! if ent.valid? }
    arr9.each do |_b41d8800|
      begin
        model.layers.remove(_b41d8800)
      rescue StandardError
        nil
      end
    end
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def self.set_selection(sheets, str)
    _9535dc0b = begin
      JSON.parse(str.to_s)
    rescue StandardError
      nil
    end
    unless _9535dc0b.is_a?(Array) && !_9535dc0b.empty?
      h2 = _4d1bd02d
      return sheets.select { |s| h2.key?(s[:key]) ? h2[s[:key]] : true }
    end
    h3 = {}
    _9535dc0b.each do |half|
      next unless half.is_a?(Hash)
      h3["#{half["id"]}|#{half["bottom"] ? 1 : 0}"] = half
    end
    out = []
    sheets.each do |s|
      half = h3["#{s[:id]}|#{s[:bottom] ? 1 : 0}"]
      next if half && half["on"] == false
      if half && half["off"].is_a?(Array) && !half["off"].empty?
        h = {}
        half["off"].each { |pid| h[pid.to_s] = true }
        s = s.merge(ents: s[:ents].reject { |ent| ent[:pid] && h[ent[:pid].to_s] })
      end
      out << s
    end
    out
  end
  def self._091b9335(s)
    _2b17a799(s[:key]).gsub(/_+/, "_")
  end
  def self._c57d63ae(s, arr)
    normal = _091b9335(s) + "_" + s[:id].to_s.rjust(3, "0")
    normal += s[:bottom] ? "_01" : "_02" if arr[s[:key]]
    normal + ".dxf"
  end
  def self._4db09033(dir, collect_in_rect, sheets)
    FileUtils.mkdir_p(dir)
    arr2 = sheets.map { |s| s[:key] }.uniq
    h = {}
    sheets.each { |s| h[s[:key]] = true if s[:bottom] }
    str4 = KSU::Settings.get("toi_uu_xuong_dao", false, "xuat_dxf").to_s == "true"
    ok = true
    arr2.each_with_index do |key, i|
      node = sheets.select { |s| s[:key] == key }
      str = File.join(dir, (i + 1).to_s.rjust(3, "0") + "_" + _091b9335(node.first))
      FileUtils.mkdir_p(str)
      str3 = str
      str2 = str
      if h[key]
        str3 = File.join(str, "TOP")
        str2 = File.join(str, "BOTTOM")
        FileUtils.mkdir_p(str3)
        FileUtils.mkdir_p(str2)
      end
      node.each do |s|
        _f60dec30(s) if str4
        layer_name = KSU::Xuatdxf::Dxf.new(collect_in_rect[:true_color])
        _de24fd0f(layer_name, s[:ents], str4)
        inst2 = s[:bottom] ? str2 : str3
        ok = false unless layer_name.write_file(File.join(inst2, _c57d63ae(s, h)))
      end
    end
    ok
  end
  def self._de24fd0f(layer_name, ents, flag = false)
    ents.each do |entity|
      pts = entity[:pts].map { |arr2| KSU::Xuatdxf::PtEx.new(arr2[0], arr2[1], 0) }
      if entity[:via_module]
        if entity[:closed]
          color = _a54bea0f(pts)
          if color
            layer_name.write_circle(color[:center], color[:radius], entity[:layer])
            next
          end
        end
        pts = _074e3371(pts)
      end
      if flag && entity[:entry] && entity[:closed]
        pts = pts[0...-1] if pts.size > 2 && pts.first == pts.last
        pts = _f8552d5f(_bb0c6429(pts), entity[:entry][0], entity[:entry][1])
      end
      layer_name.write_polyline(pts, entity[:layer], entity[:closed])
    end
  end
end
module KSU::Xuatdxf
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (87 * i + 61) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.each_with_index.map { |b, i| b ^ (61 + i * 87) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
