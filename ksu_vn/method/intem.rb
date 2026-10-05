module KSU::Intem
  def self.open
    KSU::Giacong.check_license
    KSU::Settings.assert_license
    KSU::Settings.open_window("in_tem")
  end
  def self.handle_action(dlg, action, payload)
    case action
    when "load_data", "reload_data" then load_data(dlg)
    when "save_setting" then KSU::Nest.apply_override(payload, "in_tem")
    when "select_parts" then KSU::Nest.select_ids(payload)
    when "export_request" then export_request(dlg, payload)
    when "pick_logo" then pick_logo(dlg)
    when "save_eb" then save_edge_order(payload)
    when "pdf_begin" then @_02410c50, @str3 = (JSON.parse(payload.to_s) rescue nil), []
    when "pdf_svg" then (@str3 ||= []) << payload.to_s
    when "pdf_save" then save_pdf
    when "img_begin" then @arr12, @arr14 = [], String.new
    when "img_data" then (@arr14 ||= String.new) << payload.to_s
    when "img_page"
      (@arr12 ||= []) << { id: payload.to_s, data: (@arr14 || String.new) }
      @arr14 = String.new
    when "img_save" then reset_scan
    when "pdf_error"
      @str3 = @_21b8a1e1 = @arr12 = @arr14 = @_e1bb75d3 = nil
      UI.messagebox("Không xuất được dữ liệu: #{payload}")
    end
  end
  def self.export_request(dlg, fmt)
    str = fmt.to_s == "jpg" ? ".jpg" : ".pdf"
    name = KSU::Giacong.entity_name(Sketchup.active_model.title)
    name = (name.empty? ? "KSU" : name) + "__" + Time.now.strftime("%H-%M-%S") + str
    path = UI.savepanel("Xuất tem", KSU.model_dir, name)
    return unless path
    entity = File.extname(path).downcase
    path += (entity = str) unless [".jpg", ".jpeg", ".png", ".pdf"].include?(entity)
    entity == ".pdf" ? (@_21b8a1e1 = path) : (@_e1bb75d3 = path)
    KSU::Settings.send_to_dialog(dlg, "in_tem", "intemDoExport", entity == ".pdf" ? "'pdf'" : entity == ".png" ? "'png'" : "'jpg'")
  end
  def self.pick_logo(dlg)
    path = UI.openpanel("Chọn logo", KSU.model_dir, "Ảnh|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.webp;*.svg||")
    return unless path && File.file?(path)
    entity = File.extname(path).downcase.delete(".")
    _13ec31f8 = { "jpg" => "jpeg", "svg" => "svg+xml" }.fetch(entity, entity)
    KSU::Settings.send_to_dialog(dlg, "in_tem", "intemLogo", "data:image/#{_13ec31f8};base64,#{[File.binread(path)].pack("m0")}".to_json)
  rescue StandardError => e
    UI.messagebox("Không đọc được ảnh: #{e.message}")
  end
  def self.save_edge_order(payload)
    job_cfg = JSON.parse(payload.to_s)
    return unless job_cfg.is_a?(Hash)
    KSU.start(false)
    Sketchup.active_model.set_attribute("KSU", "in_tem_dan_canh", JSON.generate("order" => Array(job_cfg["order"]).map(&:to_s), "off" => Array(job_cfg["off"]).map(&:to_s)))
    KSU.commit
  rescue StandardError
    KSU.abort_op
  end
  def self.save_pdf
    arr2, arr, path = @str3, @_02410c50, @_21b8a1e1
    @str3 = @_02410c50 = @_21b8a1e1 = nil
    return if !arr2 || arr2.empty? || !path || !arr
    _73aefde1, _1bba0f00 = KSU::Ttf.import("C:/Windows/Fonts/arial.ttf"), KSU::Ttf.import("C:/Windows/Fonts/arialbd.ttf")
    group_rgb = { pw: arr["kr"].to_f, ph: arr["kc"].to_f, rot: arr["rot"], w: arr["w"].to_f, h: arr["h"].to_f }
    File.binwrite(path, KSU::Pdf.to_segments(arr2, group_rgb, _73aefde1, _1bba0f00))
  rescue StandardError => e
    UI.messagebox("Lỗi ghi PDF: #{e.message}")
  end
  def self.reset_scan
    arr, path = @arr12, @_e1bb75d3
    @arr12 = @arr14 = @_e1bb75d3 = nil
    return if !arr || arr.empty? || !path
    entity = File.extname(path)
    arr.each { |group_rgb| File.open(arr.size > 1 ? "#{path.delete_suffix(entity)}_#{group_rgb[:id]}#{entity}" : path, "wb") { |f| f.write(group_rgb[:data].unpack1("m0")) } }
  rescue StandardError => e
    UI.messagebox("Lỗi ghi ảnh: #{e.message}")
  end
  def self.load_data(dlg)
    max_eb = (JSON.parse(Sketchup.active_model.get_attribute("KSU", "in_tem_dan_canh", "{}").to_s) rescue nil)
    data = scan.merge(mat_order: Array(KSU::Settings.get("thu_tu_vat_lieu", [], "in_tem")).map(&:to_s), eb_cfg: max_eb.is_a?(Hash) ? max_eb : {})
    data[:settings] = {
      "tu_dong_xoay" => true, "kieu_tem" => "tem01", "kho_tem_rong" => 60.0, "kho_tem_cao" => 40.0, "do_dam_canh" => 3,
      "ghi_chu_them" => "", "ghi_chu_them_2" => "", "co_chu" => 100, "tach_co_chu" => false, "co_chu_tieu_de" => 2.0,
      "co_chu_thong_tin" => 2.0, "co_chu_ky_hieu" => 2.0, "co_chu_id" => 2.0, "co_chu_ghi_chu" => 2.0,
      "ghi_chu_preset" => [], "ghi_chu_preset_2" => [], "them_ma_qr" => false, "tach_ma_qr" => false,
      "ma_qr_id" => true, "ma_qr_ten" => true, "ma_qr_code_1" => true, "ma_qr_code_2" => true, "ma_qr_code_3" => true, "hien_vat_lieu" => false,
      "hien_kich_thuoc" => false, "moc_khoan_ngang" => false, "ma_dan_canh" => true, "tach_ma_canh" => false,
      "ma_canh_ten" => true, "ma_canh_do_day_canh" => true, "ngan_cach" => "-", "kieu_ma_canh" => "so",
      "goc_bat_dau" => "trai_duoi", "thu_tu_in" => "so_tam", "sap_xep" => "tang_dan", "goc_xoay" => 1, "ty_le_zoom" => 240, "mot_cot" => false,
      "bia_ghi_chu" => false, "bia_logo" => "", "bia_noi_dung" => "", "vi_tri_bia" => 0
    }.to_h do |k, len2d|
      v = KSU::Settings.get(k, len2d, "in_tem")
      [k, len2d.is_a?(Array) ? Array(v).map(&:to_s) : [true, false].include?(len2d) ? !!v : v]
    end
    data[:settings]["thong_bao_mo"] = KSU::Settings.get("thong_bao_mo", false, "cai_dat").to_s != "false"
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
