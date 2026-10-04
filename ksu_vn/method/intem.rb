module KSU::Intem
  def self.open
    KSU::Xuatdxf.check_license
    KSU::Settings.assert_license
    KSU::Settings.open_window("in_tem")
  end
  def self.handle_action(dlg, action, id)
    case action
    when "load_data", "reload_data"
      load_data(dlg)
    when "save_setting"
      k, v = id.to_s.split("@", 2)
      return if k.to_s.empty?
      KSU::Settings.set(k, KSU::Settings.parse_value(v), "in_tem")
    when "select_parts"
      KSU::Nest.parse_rows(id)
    when "export_request"
      export_request(dlg, id)
    when "pdf_begin"
      @str4 = JSON.parse(id.to_s) rescue nil
      @arr29 = []
    when "pdf_svg"
      (@arr29 ||= []) << id.to_s
    when "pdf_save"
      save_pdf
    when "img_begin"
      @arr56 = []
      @str5 = String.new
    when "img_data"
      (@str5 ||= String.new) << id.to_s
    when "img_page"
      (@arr56 ||= []) << { id: id.to_s, data: (@str5 || String.new) }
      @str5 = String.new
    when "img_save"
      _ca3f45aa
    when "pdf_error"
      @arr29 = nil
      @_6f39e9e3 = nil
      @arr56 = nil
      @str5 = nil
      @_c46b131f = nil
      UI.messagebox("Không xuất được dữ liệu: #{id}")
    end
  end
  def self.export_request(dlg, fmt)
    str = fmt.to_s == "jpg"
    name = KSU::Xuatdxf._2b17a799(Sketchup.active_model.title)
    name = "KSU" if name.empty?
    name += "__" + Time.now.strftime("%H-%M-%S") + (str ? ".jpg" : ".pdf")
    path = UI.savepanel("Xuất tem", KSU.model_dir, name)
    return unless path
    entity = File.extname(path).downcase
    entity = str ? ".jpg" : ".pdf" unless [".jpg", ".jpeg", ".png", ".pdf"].include?(entity)
    path += entity unless File.extname(path).downcase == entity
    if entity == ".pdf"
      @_6f39e9e3 = path
      KSU::Settings.send_to_dialog(dlg, "in_tem", "intemDoExport", "'pdf'")
    else
      @_c46b131f = path
      KSU::Settings.send_to_dialog(dlg, "in_tem", "intemDoExport", entity == ".png" ? "'png'" : "'jpg'")
    end
  end
  def self.save_pdf
    arr2 = @arr29
    arr = @str4
    path = @_6f39e9e3
    @arr29 = nil
    @str4 = nil
    @_6f39e9e3 = nil
    return if !arr2 || arr2.empty? || !path || !arr
    font = KSU::Ttf.import("C:/Windows/Fonts/arial.ttf")
    font_bold = KSU::Ttf.import("C:/Windows/Fonts/arialbd.ttf")
    s = KSU::Pdf::S
    pw = arr["kr"].to_f * s
    ph = arr["kc"].to_f * s
    rot = !!arr["rot"]
    w = arr["w"].to_f
    h = arr["h"].to_f
    arr3 = arr2.map do |svg|
      { svg: svg, w: w, h: h, pw: pw, ph: ph, rot: rot }
    end
    placements = KSU::Pdf.build_doc(arr3, font, font_bold)
    File.open(path, "wb") { |f| f.write(placements) }
  rescue StandardError => ent
    UI.messagebox("Lỗi ghi PDF: #{ent.message}")
  end
  def self._ca3f45aa
    arr = @arr56
    path = @_c46b131f
    @arr56 = nil
    @str5 = nil
    @_c46b131f = nil
    return if !arr || arr.empty? || !path
    entity = File.extname(path)
    normal = path.delete_suffix(entity)
    if arr.size == 1
      File.open(path, "wb") { |f| f.write(arr[0][:data].unpack1("m0")) }
    else
      arr.each do |group_rgb|
        out = "#{normal}_#{group_rgb[:id]}#{entity}"
        File.open(out, "wb") { |f| f.write(group_rgb[:data].unpack1("m0")) }
      end
    end
  rescue StandardError => ent
    UI.messagebox("Lỗi ghi ảnh: #{ent.message}")
  end
  def self.load_data(dlg)
    data = scan
    data[:mat_order] = Array(KSU::Settings.get("thu_tu_vat_lieu", [], "in_tem")).map(&:to_s)
    data[:settings] = {
      "tu_dong_xoay" => !!KSU::Settings.get("tu_dong_xoay", true, "in_tem"),
      "kieu_tem" => KSU::Settings.get("kieu_tem", "tem01", "in_tem").to_s,
      "kho_tem_rong" => KSU::Settings.get("kho_tem_rong", 60.0, "in_tem").to_f,
      "kho_tem_cao" => KSU::Settings.get("kho_tem_cao", 40.0, "in_tem").to_f,
      "do_dam_canh" => KSU::Settings.get("do_dam_canh", 3, "in_tem").to_i,
      "ghi_chu_them" => KSU::Settings.get("ghi_chu_them", "", "in_tem").to_s,
      "ghi_chu_them_2" => KSU::Settings.get("ghi_chu_them_2", "", "in_tem").to_s,
      "co_chu" => KSU::Settings.get("co_chu", 100, "in_tem").to_i,
      "tach_co_chu" => !!KSU::Settings.get("tach_co_chu", false, "in_tem"),
      "co_chu_tieu_de" => KSU::Settings.get("co_chu_tieu_de", 2.0, "in_tem").to_f,
      "co_chu_thong_tin" => KSU::Settings.get("co_chu_thong_tin", 2.0, "in_tem").to_f,
      "co_chu_ky_hieu" => KSU::Settings.get("co_chu_ky_hieu", 2.0, "in_tem").to_f,
      "co_chu_id" => KSU::Settings.get("co_chu_id", 2.0, "in_tem").to_f,
      "co_chu_ghi_chu" => KSU::Settings.get("co_chu_ghi_chu", 2.0, "in_tem").to_f,
      "ghi_chu_preset" => Array(KSU::Settings.get("ghi_chu_preset", [], "in_tem")).map(&:to_s),
      "ghi_chu_preset_2" => Array(KSU::Settings.get("ghi_chu_preset_2", [], "in_tem")).map(&:to_s),
      "them_ma_qr" => !!KSU::Settings.get("them_ma_qr", false, "in_tem"),
      "hien_vat_lieu" => !!KSU::Settings.get("hien_vat_lieu", false, "in_tem"),
      "hien_kich_thuoc" => !!KSU::Settings.get("hien_kich_thuoc", false, "in_tem"),
      "moc_khoan_ngang" => !!KSU::Settings.get("moc_khoan_ngang", false, "in_tem"),
      "ma_dan_canh" => !!KSU::Settings.get("ma_dan_canh", true, "in_tem"),
      "tach_ma_canh" => !!KSU::Settings.get("tach_ma_canh", false, "in_tem"),
      "ma_canh_ten" => !!KSU::Settings.get("ma_canh_ten", true, "in_tem"),
      "ma_canh_do_day_canh" => !!KSU::Settings.get("ma_canh_do_day_canh", true, "in_tem"),
      "ngan_cach" => KSU::Settings.get("ngan_cach", "-", "in_tem").to_s,
      "kieu_ma_canh" => KSU::Settings.get("kieu_ma_canh", "so", "in_tem").to_s,
      "goc_bat_dau" => KSU::Settings.get("goc_bat_dau", "trai_duoi", "in_tem").to_s,
      "thu_tu_in" => KSU::Settings.get("thu_tu_in", "so_tam", "in_tem").to_s,
      "sap_xep" => KSU::Settings.get("sap_xep", "tang_dan", "in_tem").to_s,
      "goc_xoay" => KSU::Settings.get("goc_xoay", 0, "in_tem").to_i,
      "ty_le_zoom" => KSU::Settings.get("ty_le_zoom", 240, "in_tem").to_i,
      "mot_cot" => !!KSU::Settings.get("mot_cot", false, "in_tem")
    }
    KSU::Settings.send_to_dialog(dlg, "in_tem", "intemLoad", data.to_json)
  end
end
module KSU::Intem
  def self.check_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack("m0")[0].bytes.each_with_index.map { |b, i| b ^ (0x3D + i * 0x57) }.pack("C*")
    arr = arr2[/"k":"KSU_(.*?)"/, 1].to_s.unpack("m0")[0].bytes.map { |b| b ^ 0x99 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[\da-zA-Z]{3}-[\da-zA-Z]{4}-[\da-zA-Z]{4}-[\da-zA-Z]{4}\z/
  end
  def self.assert_license
    arr2 = File.read(File.join(ENV["LOCALAPPDATA"] || ENV["APPDATA"], "KSU", "license.dat")).strip.unpack1("m0").bytes.map.with_index { |b, i| b ^ (i * 0x57 + 0x3D) }.pack("C*")
    arr = arr2[/"k":"KSU_([^"]+)"/, 1].to_s.unpack1("m0").bytes.map { |b| b ^ 153 }.pack("C*")
    raise "KSU" unless arr =~ /\Ak[0-9A-Za-z]{3}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}\z/
  end
end
