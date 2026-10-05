module KSU
  module Cnc
    module Text
      TEXT = {
        giao_dien: {
          loi: "Lỗi: %{ly_do}", canh_bao: "Cảnh báo: %{ly_do}",
          khong_mo: "Lỗi: không mở được Gia công.", dang_nesting: "Lỗi: nesting đang chạy, chờ nesting xong rồi thử lại.",
          khong_tao_layer: "Lỗi: không tạo được layer %{layer}.",
          khong_an_hien: "Lỗi: không ẩn hiện được layer %{layer}.",
          khong_chon_phoi: "Lỗi: không chọn được phôi của layer %{layer}.",
          khong_sua_net: "Lỗi: không sửa được nét.",
          chua_du_lieu: "Chưa có dữ liệu.",
          chon_thu_muc: "Xuất NC", chon_thu_muc_dxf: "Xuất DXF", xuat_cau_hinh: "Xuất cấu hình", nhap_cau_hinh: "Nhập cấu hình",
          loc_cau_hinh: "JSON Files|*.json||", chon_post: "Nhập post processor", loc_post: "PP Files|*.pp;*.txt||"
        },
        quet: {
          khong_du_lieu: "Lỗi: chưa có dữ liệu nesting.", khong_quet_duoc: "Lỗi: không quét được nesting.",
          dang_sua: "sơ đồ nesting đang mở trong một công cụ chỉnh sửa của KSU, hãy thoát công cụ đó rồi bấm Cập nhật."
        },
        chong_bay: { chua_gan: "layer chống bay %{layer} chưa gán cấu hình dao." },
        ten: {
          chua_dat_ten: "chưa đặt tên", xoan_bien: "xoắn theo biên", xoan_tam: "xoắn theo tâm", doc_gap_khuc: "dốc gấp khúc"
        },
        dao: {
          chua_co_dao: "chưa có dao vật lý nào.", dong_dao_sai: "dao vật lý dòng %{dong} không hợp lệ.",
          trung_so: "số dao T%{so} bị trùng giữa %{a} và %{b}.",
          chua_co_cau_hinh: "chưa có cấu hình đường dao nào.",
          dong_cau_hinh_sai: "cấu hình đường dao dòng %{dong} không hợp lệ.",
          trung_ten: "tên cấu hình %{ten} bị trùng.",
          chua_chon_dao: "cấu hình %{ten} chưa chọn dao.",
          khoan_nhap_nho: "bước khoan nhấp %{buoc} mm của cấu hình %{ten} quá nhỏ so với độ sâu khoan.",
          qua_nhieu_luot: "Cảnh báo: cấu hình %{ten} cần hơn %{max} lượt để cắt sâu %{sau} mm.",
          xoan_bien_can_kin: "cấu hình %{ten} dùng xoắn theo biên nên chỉ chạy được đường kín.",
          doc_khong_ha: "kiểu %{kieu} của cấu hình %{ten} không hạ được dao, hãy tăng góc dốc.",
          goc_doc_nho: "góc dốc của cấu hình %{ten} quá nhỏ cho %{kieu}, cần từ %{goc} độ trở lên.",
          file_hong: "file cấu hình dao %{file} bị hỏng.", file_sai: "file này không phải cấu hình Gia công.",
          khong_luu: "Lỗi: không lưu được cấu hình dao.",
          khong_nhap: "Lỗi: không nhập được file cấu hình.", khong_xuat: "Lỗi: không xuất được file cấu hình."
        },
        post: {
          chua_nap_ten: "Chưa nạp post", chua_nap: "chưa nạp post cho máy, hãy nạp file PP của máy rồi xuất lại.",
          khong_nap_duoc: "Lỗi: không nạp được post.", khong_xoa_duoc: "Lỗi: không xóa được post.",
          khong_dung_mau: "Lỗi: không dựng được mã mẫu của post.",
          khong_thay_file: "không tìm thấy file post %{file}.",
          da_bi_sua: "file post %{file} đã bị sửa sau khi nạp, hãy nạp lại post.",
          bi_hong: "post đã lưu bị hỏng, hãy nạp lại file PP của máy.",
          thieu_khoa: "post thiếu %{khoa}.", don_vi_mm: "post phải dùng đơn vị mm.",
          xuong_dong: "không xác định được kiểu xuống dòng của post, hãy nạp lại post.",
          xuong_dong_la: "post %{post} dùng LINE_ENDING = %{gia_tri} chưa được hỗ trợ.",
          khong_co_block: "post không có khối lệnh G-code nào.", thieu_block: "post %{post} thiếu khối %{block}.",
          thieu_khai_bao: "post %{post} dùng [%{token}] nhưng chưa khai %{khoa}.",
          thieu_var: "post %{post} dùng [%{token}] nhưng thiếu VAR %{var}.",
          thieu_z: "post %{post} không xuất Z trong khối %{block}, hãy thêm [Z] vào khối đó.",
          bien_chua_thay: "post %{post} còn biến %{bien} chưa thay trong khối %{block}.",
          thieu_goi_dao: "post %{post} không có lệnh gọi dao T%{so}, cần thêm [T] vào HEADER hoặc khối TOOLCHANGE.",
          gioi_han_dao: "post %{post} chỉ nhận dao T1-T%{max}, dao %{dao} đang là T%{so}, hãy đổi số dao hoặc chọn post khác.",
          khong_xoan_tam: "post %{post} không hỗ trợ xoắn theo tâm vì lệnh cung không có Z, hãy đổi kiểu hạ dao.",
          g90_1: "post dùng G90.1 nên tâm cung là tọa độ tuyệt đối, hãy bỏ G90.1 khỏi post.",
          cung_khong_an_toan: "post %{post} xuất cung tròn G2/G3 sai tâm hoặc bán kính, hãy kiểm tra khối lệnh cung tròn của post.",
          lech_bien: "post làm lệch lệnh cắt khỏi biên tấm, hãy kiểm tra số chữ số thập phân và lệnh G1/G2/G3 của post.",
          bien_khong_kin: 'layer %{layer} có đường cắt biên sau post không khép kín, ' \
                          'hãy kiểm tra số chữ số thập phân và lệnh nhấc dao G0 của post.',
          file_khong_cat: "file %{file} không có lệnh cắt G1/G2/G3.",
          file_bien_chua_thay: "file %{file} còn biến post %{bien} chưa thay.",
          cung_loi: "cung G02/G03 ở dòng %{dong} của file NC không hợp lệ, hãy kiểm tra post.",
          cung_r: "cung G02/G03 ở dòng %{dong} dùng R sai, hãy cho post xuất cung bằng I/J."
        },
        cai_dat: { khong_ghi_file: "không ghi được file cài đặt.", khong_luu: "Lỗi: không lưu được cài đặt chung." },
        xuat: {
          da_xuat: "Đã xuất %{so} file NC.\nThư mục: %{thu_muc}",
          con_canh_bao: "Cảnh báo: còn %{so} cảnh báo khác chưa hiện.",
          da_sua_ban_ve: "Cảnh báo: đã %{viec} trong bản vẽ.",
          noi_kin: "tự nối kín %{so} đường", bo_trung: "bỏ %{so} đoạn trùng", bo_khong: "bỏ %{so} đoạn dài 0",
          layer_bo_qua: "Cảnh báo: layer %{layer} chưa gán cấu hình dao.",
          qua_day: "Cảnh báo: cấu hình %{ten} cắt sâu %{sau} mm, vượt độ dày %{day} mm của ván %{van}.",
          van_mo_phong: "Cảnh báo: mô phỏng báo lỗi ở ván %{van}.",
          van_bo_qua: "Cảnh báo: ván %{van} chưa có đường dao nào.",
          hoi_tiep: "Tiếp tục xuất NC?",
          khong_con_van: "Lỗi: chưa tích vật liệu nào để xuất.",
          khong_xuat_duoc: "Lỗi: không xuất được.", khong_xuat_vi: "Lỗi: không xuất được vì %{ly_do}",
          khong_ghi_dxf: "Lỗi: không ghi được file %{file}, hãy đóng file nếu đang mở rồi xuất lại.",
          van_loi: "có ván lỗi.\n%{danh_sach}",
          log_van: "Ván %{van}:", log_dong: "- %{loi}", log_trong: "Không có cảnh báo."
        },
        van: {
          dong: "- ván %{van}, %{loi}",
          ten_van: "%{so}%{mat}%{nhom}", mat: " mặt sau", nhom: " của nhóm %{nhom}",
          khong_goc: "không xác định được gốc tọa độ.", khong_do_day: "không xác định được độ dày ván.",
          lech_do_day: "hai mặt ván khác độ dày (%{a} mm và %{b} mm), hãy bật Ghi đè độ dày ván rồi nhập độ dày.",
          da_xoa: "dữ liệu ván không đồng bộ, cần cập nhật.",
          nc_ngoai_khung: "dòng %{dong} của file NC nằm ngoài khung ván.",
          khong_duong_dao: "không có đường dao nào để xuất.",
          nhieu_vat_lieu: "có nhiều vật liệu (%{vat_lieu}), hãy để mỗi ván một vật liệu.",
          trung_thu_muc: "hai nhóm ván khác tên cùng ghi vào thư mục %{thu_muc}.",
          trung_so_van: "nhóm %{nhom} có hai ván cùng số %{so}, hãy sửa lại số ván.",
          ten_file_sai: "tên file NC %{file} không hợp lệ.",
          trung_file: "hai ván cùng ghi vào file %{file}, hãy kiểm tra lại số ván.",
          ghi_loi: "file %{file} ghi bị lỗi, hãy xuất lại."
        },
        ban_ve: {
          ngoai_khung: "layer %{layer} có nét nằm ngoài khung ván tại X%{x} Y%{y}.",
          kin_bi_ho: "layer %{layer} có đường kín bị hở %{khoang} mm tại X%{x} Y%{y}.",
          dien_tich_0: "layer %{layer} có đường kín diện tích bằng 0 tại X%{x} Y%{y}."
        },
        duong: {
          van_de: "có vấn đề khi dựng đường dao.", van_de_layer: "layer %{layer} có vấn đề khi dựng đường dao.",
          van_de_cau_hinh: "có vấn đề khi dựng đường dao của cấu hình %{ten}.",
          loi_duong_dao: "layer %{layer} có vấn đề khi dựng đường dao%{vi_tri}.",
          duong_dao: "layer %{layer}%{dao}%{vi_tri} %{ly_do}",
          dao: ", dao T%{so} Ø%{d} mm", vi_tri: " tại X%{x} Y%{y}",
          ra_ngoai_khung: "layer %{layer} có đường dao ra ngoài khung ván tại X%{x} Y%{y}.",
          dao_qua_lon: "quá lớn so với biên dạng.",
          bien_tu_cat: "có biên dạng tự cắt nhau.",
          an_lem_ban_ve: "có đường dao cắt vào tấm, biên dạng có thể bị lỗi.",
          an_lem_dao: "có đường dao cắt vào tấm, biên dạng có thể bị lỗi.",
          lo_khoan: "có lỗ khoan không phải đường tròn kín.",
          khoan_lon_hon_lo: "lớn hơn đường kính lỗ Ø%{lo} mm.",
          hem_khong_cap: "không ghép được cặp hèm.",
          khong_khep_kin: "layer %{layer} có đường cắt biên không khép kín.",
          khong_giam_toc: 'layer %{layer} có biên không dùng được tự động giảm tốc hoặc hạ dao dốc, ' \
                          'hãy tắt giảm tốc hoặc chọn kiểu cắm thẳng.',
          toa_do_loi: "lệnh %{lenh} có giá trị %{truc} không hợp lệ."
        },
        mat_sau: {
          lech_mat_truoc: "Cảnh báo: ván %{van} có tấm lệch tọa độ so với mặt trước tại %{vi_tri}.", diem: "X%{x} Y%{y}",
          thieu_khung: "Cảnh báo: ván %{van} thiếu layer ABF_sheetBorder hoặc ABF_markSquare.",
          g91: "file NC dùng tọa độ tương đối G91 khi cắt nên không tự chỉnh được gốc mặt sau.",
          vuot_khung: "file NC mặt sau vẫn vượt khung ván sau khi chỉnh gốc.",
          khong_dung_dau: "có biên dạng cắt góc via mặt sau bị lỗi.",
          doc_ngan: "có biên dạng cắt góc via mặt sau bị lỗi.", doc_dai: "có biên dạng cắt góc via mặt sau bị lỗi.",
          khong_xoan: 'cấu hình %{ten} không dùng được kiểu %{kieu} cho dấu mặt sau vì đây là đường hở, ' \
                      'hãy chọn cắm thẳng, dốc thường hoặc dốc gấp khúc.'
        },
        mo_phong: {
          khong_dung: "Lỗi: không dựng được mô phỏng.", khong_dung_van: "Lỗi: có lỗi xảy ra khi mô phỏng.",
          khong_dung_duong_dao: "Lỗi: có lỗi xảy ra khi mô phỏng.", cho_qua_lau: "Lỗi: có lỗi xảy ra khi mô phỏng.",
          khong_thay_van: "Lỗi: dữ liệu ván không đồng bộ, cần cập nhật.",
          bi_chan_duong_dao: "Lỗi: phát hiện có đường dao lỗi.",
          bi_chan_trong: "Cảnh báo: ván này chưa có đường dao nào.",
          bi_chan_hinh: "Lỗi: ván này không xuất được vì hình học bị lỗi.",
          qua_day: "Cảnh báo: cấu hình %{ten} cắt sâu %{sau} mm, vượt độ dày ván %{day} mm."
        }
      }.freeze
      TEXT.each_value { |_124c7bd3| _124c7bd3.each_value(&:freeze).freeze }
      UI_KEYS = {
        khong_quet_duoc: %i[quet khong_quet_duoc], chua_du_lieu: %i[giao_dien chua_du_lieu],
        cho_qua_lau: %i[mo_phong cho_qua_lau], khong_dung_duong_dao: %i[mo_phong khong_dung_duong_dao]
      }.freeze
      module_function
      def t(_124c7bd3, key, **arr)
        arr.empty? ? TEXT[_124c7bd3][key] : format(TEXT[_124c7bd3][key], arr)
      end
      def error_text(ly_do)
        t(:giao_dien, :loi, ly_do: ly_do)
      end
      def warning_text(ly_do)
        t(:giao_dien, :canh_bao, ly_do: ly_do)
      end
      def term(key)
        TEXT[:ten][key]
      end
      def num(num2, digits = 2)
        format("%.#{digits}f", num2.to_f).sub(/(?:(\.\d*[1-9])|\.)0*\z/, "\\1").sub(/\A-0\z/, "0")
      end
      def position_text(x, y)
        t(:duong, :vi_tri, x: num(x, 1), y: num(y, 1))
      end
      def gi
        UI_KEYS.transform_values { |_124c7bd3, key| TEXT[_124c7bd3][key] }
      end
    end
  end
end
