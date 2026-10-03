require "json"
module KSU::Thongke
  def self.open
    KSU::Intem.check_license
    KSU::Chongbay.assert_license
    KSU::Settings.open_window("thong_ke")
  end
  def self.round_len(value)
    KSU::Cutting.depth(value, 4, 0.0254)
  end
  def self.model_title
    title = Sketchup.active_model.title.to_s.strip
    title.empty? ? "Chưa đặt tên" : title
  end
  def self.handle_action(dlg, action, id)
    case action
    when "load_data", "reload_data"
      load_data(dlg)
    when "save_setting"
      k, v = id.to_s.split("@", 2)
      return if k.to_s.empty?
      flag = KSU::Preset.global_key?(k) ? "cai_dat" : "thong_ke"
      KSU::Settings.set(k, KSU::Settings.parse_value(v), flag)
      push_data(dlg) if flag == "thong_ke" && @data
      if flag == "cai_dat"
        KSU::Preset.load_cfg
        tool = Sketchup.active_model.tools.active_tool
        tool.reload_settings if tool.respond_to?(:reload_settings)
        KSU::View.refresh
      end
    when "change_unit"
      fld = JSON.parse(id.to_s) rescue nil
      KSU::Thongke::Phukien.set_unit(fld["name"], fld["unit"].to_s) if fld
      load_data(dlg)
    when "export_request"
      str2 = JSON.parse(id.to_s) rescue nil
      KSU::Thongke::Xuat.export_file(model_title, str2) if str2
    when "copy_image"
      KSU::Thongke::Xuat._beb63a90(id.to_s)
      KSU::Settings.send_to_dialog(dlg, "thong_ke", "tkSnapDone", "null")
    when "select_parts"
      keys = JSON.parse(id.to_s) rescue []
      select_parts(Array(keys))
    end
  end
  def self.select_parts(keys)
    model = Sketchup.active_model
    partner = KSU::Thongke::Quet.boards_by_index(keys)
    if partner.empty?
      model.close_active while model.active_path
      return KSU.select_only(nil)
    end
    groups = partner.group_by { |_part, path| path.map(&:entityID) }
    best = groups.values.max_by(&:size)
    path = best[0][1]
    model.active_path = path.empty? ? nil : Sketchup::InstancePath.new(path)
    KSU.select_only(best.map(&:first))
  rescue StandardError
    nil
  end
  def self.bool_setting(key, default)
    KSU::Settings.get(key, default, "thong_ke").to_s == "true"
  end
  def self.push_data(dlg)
    settings = {
      "tu_dong_lam_tron" => bool_setting("tu_dong_lam_tron", true),
      "lam_tron_cau_kien" => bool_setting("lam_tron_cau_kien", true),
      "an_ten_dan_canh" => bool_setting("an_ten_dan_canh", false),
    }
    data = @data
    data = KSU::Thongke::Tonghop.round_sums(data) if settings["tu_dong_lam_tron"]
    data = KSU::Thongke::Tonghop.round_parts(data) if settings["lam_tron_cau_kien"]
    KSU::Settings.send_to_dialog(dlg, "thong_ke", "tkLoad", data.merge(settings: settings).to_json)
  end
  def self.load_data(dlg)
    @data = KSU::Thongke::Tonghop._984ac2f3
    push_data(dlg)
  end
end
