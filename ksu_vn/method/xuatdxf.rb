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
    arr = export_list(collect_in_rect)
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
  def self.export_request(only_keys = nil)
    nesting = KSU::Nesting.find_nesting(notify: false)
    return unless nesting && nesting.valid?
    drop_temp_layers(nesting)
    collect_in_rect = collect_in_rect(nesting)
    sheets = set_selection(collect_in_rect[:sheets], only_keys)
    if sheets.empty?
      UI.messagebox("Chưa chọn loại ván nào để xuất.")
      return
    end
    title = ascii_name(Sketchup.active_model.title)
    title = "KSU" if title.empty?
    dir = UI.savepanel("Xuất DXF", KSU.model_dir, title + "__" + Time.now.strftime("%H-%M-%S"))
    return unless dir
    ok = write_dxf_files(dir, collect_in_rect, sheets)
    UI.openURL("file:///" + dir.gsub("\\", "/")) if ok
  rescue StandardError => ent
    UI.messagebox("Lỗi xuất DXF: #{ent.message}")
  end
  def self.drop_temp_layers(nesting)
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
    arr9.each do |layer2|
      begin
        model.layers.remove(layer2)
      rescue StandardError
        nil
      end
    end
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def self.set_selection(sheets, only_keys)
    rows2 = begin
      JSON.parse(only_keys.to_s)
    rescue StandardError
      nil
    end
    unless rows2.is_a?(Array) && !rows2.empty?
      on = layer_flags
      return sheets.select { |s| on.key?(s[:key]) ? on[s[:key]] : true }
    end
    h3 = {}
    rows2.each do |half|
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
  def self.base_name(s)
    ascii_name(s[:key]).gsub(/_+/, "_")
  end
  def self.dxf_name(s, arr)
    normal = base_name(s) + "_" + s[:id].to_s.rjust(3, "0")
    normal += s[:bottom] ? "_01" : "_02" if arr[s[:key]]
    normal + ".dxf"
  end
  def self.write_dxf_files(dir, collect_in_rect, sheets)
    FileUtils.mkdir_p(dir)
    arr2 = sheets.map { |s| s[:key] }.uniq
    h = {}
    sheets.each { |s| h[s[:key]] = true if s[:bottom] }
    str4 = KSU::Settings.get("toi_uu_xuong_dao", false, "xuat_dxf").to_s == "true"
    ok = true
    arr2.each_with_index do |key, i|
      node = sheets.select { |s| s[:key] == key }
      str = File.join(dir, (i + 1).to_s.rjust(3, "0") + "_" + base_name(node.first))
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
        set_entries(s) if str4
        layer_name = KSU::Xuatdxf::Dxf.new(collect_in_rect[:true_color])
        write_one_dxf(layer_name, s[:ents], str4)
        inst2 = s[:bottom] ? str2 : str3
        ok = false unless layer_name.write_file(File.join(inst2, dxf_name(s, h)))
      end
    end
    ok
  end
  def self.write_one_dxf(layer_name, ents, flag = false)
    ents.each do |entity|
      pts = entity[:pts].map { |arr2| KSU::Xuatdxf::PtEx.new(arr2[0], arr2[1], 0) }
      if entity[:via_module]
        if entity[:closed]
          color = circle?(pts)
          if color
            layer_name.write_circle(color[:center], color[:radius], entity[:layer])
            next
          end
        end
        pts = simplify_bulge(pts)
      end
      if flag && entity[:entry] && entity[:closed]
        pts = pts[0...-1] if pts.size > 2 && pts.first == pts.last
        pts = split_at(ring_len(pts), entity[:entry][0], entity[:entry][1])
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
