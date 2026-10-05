module KSU::Const
  EPS = 1.0e-6
  LOOP_AREA_MIN = 4.0
  SHEET_H_PADDING = 500.mm
  SHEET_V_PADDING = 700.mm
  OVERLAY_SETTINGS = {
    phu_mau_tam: [:switch, "Phủ màu tấm thường"],
    phu_mau_tam_hai_mat: [:switch, "Phủ màu tấm hai mặt"],
    danh_dau_loi: [:switch, "Đánh dấu điểm bị lỗi"],
    danh_dau_tam_bi_lan: [:switch, "Đánh dấu tấm bị lấn"]
  }.freeze
  GLOBAL_SETTING_KEYS = %w[phu_mau_tam phu_mau_tam_hai_mat danh_dau_tam_bi_lan danh_dau_loi tam_cach_nhau tam_cach_le tach_cach_le tam_cach_le_trai tam_cach_le_phai tam_cach_le_tren tam_cach_le_duoi tam_cach_le_hai_mat thong_bao_mo].freeze
end
require "json"
module KSU::Const
  def self.fetch_json(url)
    JSON.parse(KSU::Themtam.http_fetch(url))
  rescue
    nil
  end
end
