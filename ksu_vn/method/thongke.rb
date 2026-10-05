module KSU::Thongke
  def self.open
    KSU::Intem.check_license
    KSU::Chongbay.assert_license
    KSU::Settings.open_window("thong_ke")
  end
  def self.round_len(length)
    KSU::Cutting.depth(length, 4, 0.0254)
  end
  def self.handle_action(dlg, action, payload)
    case action
    when "load_data", "reload_data"
      load_data(dlg)
    when "save_setting"
      push_data(dlg) if KSU::Nest.apply_override(payload, "thong_ke") == "thong_ke" && @data
    when "change_unit"
      fld = JSON.parse(payload.to_s) rescue nil
      UI.messagebox("Lỗi: nesting đang chạy, chờ nesting xong rồi thử lại.") if fld && KSU.in_batch?
      KSU::Thongke::Phukien.set_unit(fld["name"], fld["unit"].to_s) if fld && !KSU.in_batch?
      load_data(dlg)
    when "export_request"
      str = JSON.parse(payload.to_s) rescue nil
      KSU::Thongke::Xuat.export_file(Sketchup.active_model.title.to_s.strip.then { |t| t.empty? ? "Chưa đặt tên" : t }, str) if str
    when "copy_image"
      KSU::Thongke::Xuat.copy_image(payload.to_s)
      KSU::Settings.send_to_dialog(dlg, "thong_ke", "tkSnapDone", "null")
    when "select_parts"
      select_parts(Array((JSON.parse(payload.to_s) rescue [])))
    end
  end
  def self.select_parts(_4c11a852)
    model = Sketchup.active_model
    partner = KSU::Thongke::Quet.walk_boards(model.entities, [], _4c11a852.to_h { |id| [id.to_i, true] })
    if partner.empty?
      model.close_active while model.active_path
      return KSU.select_only(nil)
    end
    best = partner.group_by { |_item, path| path.map(&:entityID) }.values.max_by(&:size)
    path = best[0][1]
    model.active_path = path.empty? ? nil : Sketchup::InstancePath.new(path)
    KSU.select_only(best.map(&:first))
  rescue StandardError
  end
  def self.push_data(dlg)
    settings = { "tu_dong_lam_tron" => true, "lam_tron_cau_kien" => true, "an_ten_dan_canh" => false }
      .to_h { |k, len2d| [k, KSU::Settings.get(k, len2d, "thong_ke").to_s == "true"] }
    settings["thong_bao_mo"] = KSU::Settings.get("thong_bao_mo", false, "cai_dat").to_s != "false"
    data = settings["tu_dong_lam_tron"] ? KSU::Thongke::Tonghop.round_sums(@data) : @data
    data = KSU::Thongke::Tonghop.round_parts(data) if settings["lam_tron_cau_kien"]
    KSU::Settings.send_to_dialog(dlg, "thong_ke", "tkLoad", data.merge(settings: settings).to_json)
  end
  def self.load_data(dlg)
    @data = KSU::Thongke::Tonghop.summary_rows
    push_data(dlg)
  end
end
