# HANDOFF — Phát triển KSU: sửa lỗi và thêm tính năng

Tài liệu cho người **viết mã trên cây KSU đã đọc được**: kiến trúc, các đường
nối mà grep không thấy, vòng lặp thử, và bộ đồ thị gọi hàm đi kèm.

Đây **không phải** tài liệu dịch ngược; việc đó nằm ở
[HANDOFF-giai-hex.md](HANDOFF-giai-hex.md), đọc file đó khi cần biết *một cái
tên từ đâu ra*. File này chỉ nói chuyện sửa mã.

Cây đọc được ở mức **100 % tên method, 95 % số lượt định danh**; phần còn hex là
biến cục bộ ít dùng, nên hầu hết chỗ bạn mở ra sẽ đọc được bình thường. Gặp một
`_1a2b3c4d` thì `python tools/usage.py _1a2b3c4d` cho biết nó ở đâu.

| | |
|---|---|
| **Sản phẩm** | Extension SketchUp (Windows), tối ưu sơ đồ cắt ván |
| **Phiên bản** | KSU **2.3.2** — [ksu_vn.rb](ksu_vn.rb) |
| **Cây mã** | 128 file `.rb`, 38.201 dòng · 3.065 method · 8.052 cạnh gọi |
| **Phân tầng** | `method/` 79 file · `utils/` 40 file · `system/` 3 file |
| **Giao diện** | 18 trang HTML + Vue 2, trong `ksu_vn/html/` |
| **Nhân tính toán** | `clibs/*/ksu.so` (C) + một engine JS nhúng (§7) |
| **Đồ thị** | `python tools/dothi.py --dung` → `tools/dothi.json` (§10) |
| **Đo ngày** | 05/10/2026 |

> **Khác 2.1.5, phải biết trước khi sửa.** 2.3.2 thêm 39 file, trong đó nặng
> nhất là nhân CNC `method/giacong/` (24 file, ~12.700 dòng): quét model → nối
> net thành đường chạy dao → bù bán kính dao → sinh file NC theo post
> processor. Cùng với nó là `method/toiuu/`, `method/catcuoi/`,
> `method/thongke/*` và `utils/{marquee,normalize}.rb`.
>
> **Bản tiếng Việt cũ vẫn nằm đó.** `method/toiuuvan*`, `method/netcatcuoi*`,
> `method/danhsovan.rb`, `utils/chuanhoa.rb`, `utils/nesting/bilan.rb` là bản
> trước của chính những đơn vị trên, đóng gói nguyên xi từ bản dựng 2.1.5 —
> và **chúng mở cùng một module** với bản mới (`module KSU::Back` có ở cả
> `toiuu/back.rb` lẫn `toiuuvan/back.rb`). Trong cây đọc được, method của bản
> cũ mang đuôi `_v1` để hai bên không đè nhau. Chúng gọi hai method không tồn
> tại ở đâu cả nên gần như chắc là mã chết, nhưng **chưa kiểm trong SketchUp**:
> đừng xoá trước khi kiểm. Chi tiết ở §2 và §8 của
> [HANDOFF-giai-hex.md](HANDOFF-giai-hex.md).

---

## 1. Nạp cây: thứ tự, và một điểm bất nhất phải biết

[ksu_vn.rb](ksu_vn.rb) là file SketchUp thấy. Nó **không** nạp mã trực tiếp: nó
chép `clibs/<ruby>/loader.so` sang `%TEMP%` theo vân tay `size_mtime`, `require`
bản chép đó, rồi mới đăng ký extension trỏ vào `ksu_vn/main`.
[ksu_vn/clibs.rb](ksu_vn/clibs.rb) làm y hệt với `ksu.so`.

> **Vì sao chép ra TEMP:** `.so` đang nạp thì Windows khoá file, bản cập nhật
> không ghi đè được. Chép theo vân tay cho phép cập nhật tại chỗ, và thư mục
> `ksu_loader_*` / `ksu_clibs_*` cũ bị xoá ở lần chạy sau.

[ksu_vn/main.rb](ksu_vn/main.rb) nạp theo thứ tự:

```
clibs  →  system  →  utils  →  method
```

Nhưng `KSU.reload` ([main.rb:8](ksu_vn/main.rb#L8)) nạp lại theo thứ tự **khác**:

```ruby
layers = { "utils" => 0, "system" => 1, "method" => 2 }
```

tức `utils → system → method`. Hai thứ tự này ngược nhau ở cặp đầu.

> **Hệ quả thực tế:** một phụ thuộc lúc-nạp mới giữa `system/` và `utils/` có
> thể chạy khi khởi động mà hỏng khi `KSU.reload`, hoặc ngược lại — và bạn sẽ
> thấy nó dưới dạng một lỗi chỉ xuất hiện sau khi sửa mã, không bao giờ xuất
> hiện lúc mở SketchUp. Khi thêm một hằng đọc ở *thân module*, thử cả hai
> đường: khởi động lại SketchUp **và** `KSU.reload`.

---

## 2. Cơ chế gộp module — điều quan trọng nhất trong cây này

Mỗi thư mục con là **một module bị xẻ ra nhiều file**. File con khai báo một
module đứng riêng rồi **tự gộp mình vào module cha ở cuối file**:

```ruby
# ksu_vn/method/xeptam/drag.rb:482 — sau 481 dòng định nghĩa KSU::Drag
KSU::Xeptam.include(KSU::Drag)
```

> Ở nhiều file, dòng gộp **không** phải dòng cuối: module được mở lại ngay
> dưới nó để thêm một mảnh bản quyền. Đó là cố ý, xem §8.

Có **34 lần gộp như vậy vào 10 module cha**. Danh sách đầy đủ:

| Cha | Gộp từ |
|---|---|
| `KSU::Xeptam` | Arrange, Collide, Drag, Engine, Group, Mirror, Push |
| `KSU::Nesting` | Avail, Bilan, Corner, Edit, Optimize, Pack |
| `KSU::Nest` | Collect, Draw, Launch |
| `KSU::Toiuuvan` | Back, Engine, Postproc |
| `KSU::Sheet` | Bottom, Mark, Overlay, Reorder |
| `KSU::Preset` | Field, Mode, Store |
| `KSU::Chongbay` | Assign, Shape |
| `KSU::Netcatcuoi` | Lastcut, Resize |
| `KSU::Cutting` | Detail, Loop |
| `KSU::View` | Query, Widget |

Ba điều rút ra, và cả ba đều là cách để mất một buổi nếu không biết:

1. **`KSU::Drag` không phải namespace ai gọi tới.** Không có lời gọi
   `KSU::Drag.foo` nào trong cây. Người ta gọi `KSU::Xeptam.foo`. Tên module
   con chỉ là nhãn của file.
2. **Lời gọi trần đi ngang qua các file anh em.** Một `nfp_snap(...)` trong
   `drag.rb` có thể nằm ở `collide.rb`. Grep theo file sẽ không ra; dùng
   `python tools/dothi.py --goi <ten>`.
3. **Gộp bằng `include` thì method là *instance*, bằng `extend` thì là
   *class*.** `KSU::Nest` dùng `extend` (và có `extend self`), nên mọi thứ gọi
   là `KSU::Nest.x`. `KSU::Xeptam` dùng `include`, nên phải có một thể hiện —
   nó là Tool, SketchUp tạo thể hiện qua `select_tool`.

### 2.1. Cơ chế gộp thứ hai: hook `included`

[utils/preset.rb:90](ksu_vn/utils/preset.rb#L90):

```ruby
def self.included(normal)
  normal.extend(ClassMethods)
  normal.prepend(SbUserTextHandler)
end
```

Ruby chạy cái này cho **mọi lớp** có `include KSU::Preset` — 10 lớp: 9 công cụ
Tool cộng `KSU::Nest::Progress`. Nên mỗi lớp đó lặng lẽ có thêm:

- `tool_key` (class method) — khai khoá cài đặt, xem §6;
- một `onKeyDown` **prepend** chen trước `onKeyDown` của chính nó.

> `prepend` chứ không phải `include`: `SbUserTextHandler#onKeyDown` chạy
> **trước**, và gọi `super` để nhường lại. Nếu bạn sửa `onKeyDown` của một
> công cụ mà phím Enter vẫn không vào đúng nhánh, thủ phạm là cái prepend này,
> không phải mã bạn vừa sửa.

---

## 3. Phân tầng và chiều phụ thuộc

```
method/   43 file, 15.263 dòng   — một thư mục mỗi công cụ, là UI + nghiệp vụ
utils/    37 file,  8.417 dòng   — hình học, vẽ, nhãn, sơ đồ cắt, PDF, preset
system/    3 file,    898 dòng   — cài đặt, cập nhật, add-on
```

Chiều phụ thuộc **gần như sạch**, và chỗ bẩn thì bẩn có lý do. Đếm được **22
cạnh đi ngược** từ `utils/` lên `method/`, nhưng phân loại ra thì:

| Số cạnh | Là gì |
|---|---|
| 18 | mạch kiểm bản quyền bị rải cố ý (§8) — không phải nợ kiến trúc |
| 3 | `SbUserTextHandler` → `Netcatcuoi#commit_field_input` — đồ thị bắt trúng bản đè thay vì bản gốc, xem §10.2 |
| **1** | `KSU::Const.fetch_json` → `KSU::Themtam.http_fetch` — **phụ thuộc ngược thật sự duy nhất** |

Nghĩa là nếu bỏ mạch bản quyền ra, cây này phân tầng đúng. Đo lại bất cứ lúc
nào:

```
python tools/dothi.py --file utils/sheet.rb      # xem cột "phu thuoc RA"
```

Hai file đáng chú ý:

- [utils/other.rb](ksu_vn/utils/other.rb) — hạt nhân thật sự. `KSU.start` /
  `KSU.commit` / `KSU.abort_op` bọc `start_operation` của SketchUp (một bước
  undo), `KSU.container?`, `KSU.entities_in`, `KSU.select_tool`. Đây là 6 method
  bị gọi nhiều nhất cả cây — xem `--diem-nong`.
- [utils/geom.rb](ksu_vn/utils/geom.rb) — hình học thuần, **0 phụ thuộc ra**.
  Lá duy nhất trong cây. Sửa ở đây an toàn nhất về mặt lan toả, nguy hiểm nhất
  về mặt số lượng (17 method, 60+ nơi gọi).

> **Quy tắc trước khi sửa bất cứ gì trong `utils/`:** chạy
> `python tools/dothi.py --ai-goi <ten>`. Nếu ra >10 file, cái bạn đang sửa là
> hạ tầng, không phải chi tiết.

---

## 4. 14 công cụ

Bảng điều phối nằm ở `TOOL_LABELS` / `TOOL_DATA` trong
[main.rb:31](ksu_vn/main.rb#L31). Mỗi mục là
`khoá → [tên icon, lambda khởi động, lớp Tool (nếu có)]`.

| Khoá | Vào từ | Kiểu | Thư mục mã |
|---|---|---|---|
| `xep_tam` | `KSU::Xeptam` | Tool | `method/xeptam/` (8 file) |
| `chon_tam` | `KSU::Chontam` | Tool | `method/chontam/` |
| `them_tam` | `KSU::Themtam` | Tool | `method/themtam.rb` |
| `xep_hang` | `KSU::Xephang` | Tool | `method/xephang.rb` |
| `danh_so_van` | `KSU::Danhsovan` | Tool | `method/danhsovan.rb` |
| `gan_nhan` | `KSU::Gannhan` | Tool | `method/gannhan.rb` |
| `chong_bay` | `KSU::Chongbay` | Tool | `method/chongbay/` |
| `net_cat_cuoi` | `KSU::Netcatcuoi` | Tool | `method/netcatcuoi/` |
| `toi_uu_van` | `KSU::Toiuuvan` | Tool | `method/toiuuvan/` |
| `nesting` | `KSU::Nest.open` | Dialog | `method/nesting/` |
| `thong_ke` | `KSU::Thongke.open` | Dialog | `method/thongke/` |
| `in_tem` | `KSU::Intem.open` | Dialog | `method/intem/` |
| `xuat_dxf` | `KSU::Xuatdxf.open` | Dialog | `method/xuatdxf/` |
| `cai_dat` | `KSU::Settings.open_settings` | Dialog | `system/setting.rb` |

Hai kiểu khác nhau hẳn:

- **Tool** — lớp cài giao diện Tool của SketchUp (`activate`, `draw`,
  `onLButtonDown`…). Vẽ trực tiếp lên viewport, không có cửa sổ riêng. 9 cái.
- **Dialog** — mở `UI::HtmlDialog`, mã Ruby chỉ phục vụ trang web. 5 cái.

Lấy lát cắt một công cụ (file riêng, phụ thuộc ra, ai gọi ngược vào, khoá cài
đặt, khoá thuộc tính, hành động từ trang HTML):

```
python tools/dothi.py --tinhnang xuat_dxf
```

---

## 5. Giao diện: hai tầng, và cây cầu `skp()`

14 file trong `ksu_vn/html/`, tất cả dùng Vue 2
([html/js/vue.min.js](ksu_vn/html/js/vue.min.js)). Chúng chia làm **hai loại
hoàn toàn khác nhau**, và nhầm loại là nguồn bug phổ biến:

### 5.1. Loại A — 10 trang chỉ là tab cài đặt

`caidat, chongbay, chontam, danhsovan, gannhan, netcatcuoi, themtam, toiuuvan,
xephang, xeptam`

Chúng chạy **bên trong** cửa sổ Cài đặt, trong iframe, và chỉ phát đúng một
thứ: `save_setting`, qua [html/js/setting.js](ksu_vn/html/js/setting.js). Không
có `skp()`, không có `tool_call`. Thêm một ô cài đặt ở đây **không cần đụng
Ruby** — chỉ cần khoá trong settings.json (§6).

### 5.2. Loại B — 4 trang là ứng dụng thật

`nesting, intem, thongke, xuatdxf`

Chúng có hàm cầu riêng và một bộ điều phối hành động ở phía Ruby. Đường đi đầy
đủ của một cú bấm nút:

```
  skp('export_request', arg)            ksu_vn/html/xuatdxf.html
    → window.parent.postMessage({ action:'tool_call', tabId:'xuat_dxf', ... })
      → relay                           ksu_vn/method/caidat.rb:260
        → add_action_callback("tool_call")   ksu_vn/system/setting.rb:423
          → Settings.on_dialog_action(kind, action, id)    setting.rb:604
            → KSU::Xuatdxf.handle_action(dlg, action, id)  xuatdxf.rb:9
              → case action; when "export_request" ...
```

Chiều ngược lại (Ruby → trang):

```
  Settings.send_to_dialog(dlg, kind, action, resp)         setting.rb:618
    → window.callTabFn(kind, action, resp)
```

> **Không một phép kiểm tĩnh nào bắc qua được chỗ này.** `verify_graph.py` chỉ
> soi lời gọi Ruby; chuỗi `'export_request'` trong HTML và nhãn
> `when "export_request"` trong Ruby không liên quan gì nhau về mặt cú pháp.
> Đổi tên một bên mà quên bên kia thì nút im lặng không làm gì, không có lỗi,
> không có log.
>
> `python tools/dothi.py --seam` ghép hai đầu theo tên và báo lệch. Hiện tại
> **4/4 trang khớp hoàn toàn, 0 hành động lạc** — giữ nguyên con số đó.

Bảng điều phối cấp trên nằm ở `Settings.on_dialog_action`; nhánh `else` giao
cho `KSU::Addon.dispatch`, tức cơ chế add-on bên ngoài (§11).

Ngoài ra có **30 `add_action_callback`** cấp hệ thống: 21 cái ở
[system/setting.rb:420+](ksu_vn/system/setting.rb#L420) (tab, preset, xuất/nhập
cài đặt, kích hoạt, cập nhật, gỡ cài), 9 cái ở engine nesting (§7).

---

## 6. Dữ liệu sống ở đâu

Ba kho khác nhau, mỗi kho có vòng đời riêng. Nhầm kho là lớp bug thứ hai.

### 6.1. `settings.json` — cấu hình theo máy

`%LOCALAPPDATA%\KSU\settings.json`, bản sao lưu cạnh nó. **98 khoá.**

```ruby
KSU::Settings.get(key, default, section)   # section = khoá công cụ
KSU::Settings.set(key, value, section)
```

`section` chính là `tool_key` khai ở đầu mỗi lớp công cụ
(`tool_key "xep_tam"`). Khoá nào nằm trong
`KSU::Const::GLOBAL_SETTING_KEYS` thì dùng chung, không theo section — đổi nó
thì **mọi** công cụ phải nạp lại, và `save_setting` xử việc đó bằng
`tool.reload_settings if tool.respond_to?(:reload_settings)`.

Xem toàn bộ khoá và nơi đọc/ghi: `python tools/dothi.py --seam`.

### 6.2. Thuộc tính gắn trên model SketchUp — dữ liệu của bản vẽ

**74 khoá**, trong 4 từ điển:

| Từ điển | Lượt dùng | Là gì |
|---|---|---|
| `ABF` | 264 | Định dạng trao đổi cho máy CNC — **không phải của KSU** |
| `KSU` | 52 | Dữ liệu riêng của plugin này |
| `ZSU` | 6 | Đọc từ plugin anh em để tương thích |
| `_temp_` | 1 | Cờ rác để ép SketchUp ghi nhận một bước undo |

> **`ABF` là hợp đồng với bên ngoài.** Khoá như `ABF/sheet-id`,
> `ABF/is-cutting-lines`, `ABF/cutting-layer-postfix` được phần mềm CAM khác
> đọc. Đổi tên hay đổi ngữ nghĩa một khoá `ABF` là phá tương thích với file
> khách hàng đã có, và không phép kiểm nào trong repo thấy được. Thêm thì được,
> đổi thì không.
>
> `_temp_` ở [utils/other.rb:12](ksu_vn/utils/other.rb#L12) là một thủ thuật:
> ghi một thuộc tính vô nghĩa để `start_operation`/`commit_operation` có thứ
> để ghi, nếu không SketchUp bỏ qua bước undo rỗng.

### 6.3. Preset — bộ cài đặt đặt tên, lưu trong `settings.json`

`KSU::Preset` (gộp từ `Field`, `Mode`, `Store`) dựng **giao diện vẽ thẳng lên
viewport** cho các công cụ Tool: thẻ, công tắc, ô nhập số, bảng màu sáng/tối
(`COLOR_LIGHT` / `COLOR_DARK` ở đầu [utils/preset.rb](ksu_vn/utils/preset.rb)).
Đây là lý do 9 công cụ Tool không cần trang HTML nào để có bảng điều khiển.

---

## 7. Nhân tính toán: hai cái, không phải một

### 7.1. `ksu.so` — nhân hình học C

[clibs.rb](ksu_vn/clibs.rb) nạp nó; nó gắn method thẳng lên `KSU::Clibs` và
`KSU::Clipper`. **8 tên này là chữ gốc của tác giả** (C extension gắn method
theo tên nên trình làm rối không đụng được):

`convex_hull` · `polygons_overlap?` · `pack_bl` · `nfp` · `nfp_snap` ·
`inflate` · `contact_refine` · `build_loops`

Cộng thêm `KSU::Clipper.union` / `.minkowski`.

Không có mã nguồn Ruby cho chúng. Mọi nơi gọi đều bọc
`defined?(KSU::Clipper) && KSU::Clipper.respond_to?(:union)` — giữ thói quen
đó, vì bản `.so` có thể thiếu trên máy khác.

```
python tools/dothi.py --seam     # mục "loi goi vao nhan native"
```

### 7.2. Engine nesting — **JavaScript, trong một cửa sổ 0×0**

Đây là chỗ bất ngờ nhất của cây mã.
[utils/nesting/kcore.rb](ksu_vn/utils/nesting/kcore.rb) là **7 dòng, 34 KB**:
một hằng `ENGINE_JS` chứa toàn bộ thuật toán xếp hình đã minify.
[utils/nesting/engine.rb](ksu_vn/utils/nesting/engine.rb) mở một
`UI::HtmlDialog` `width: 0, height: 0`, đẩy ra ngoài màn hình
(`set_position(9999, 9999)`, hoặc `(0, 0)` từ SketchUp 25 trở lên), nạp JS đó,
rồi nhận kết quả qua 9 callback: `on_nested`, `on_progress`,
`on_place_progress`, `on_fail_to_nest_parts`, và 4 biến thể `on_job_*`.

Hai hệ quả:

- **Nesting là bất đồng bộ.** Không có đường gọi tĩnh nào từ `KSU::Nest.open`
  tới kết quả; luồng đứt ở ranh giới dialog rồi nối lại ở callback. Kiểm chứng:
  `python tools/dothi.py --duong "KSU::Nest#open" "KSU::Pack#pack_native"` →
  "khong co duong goi".
- **`pack_bl` (native) phục vụ đường khác.** `KSU::Pack#pack_native` được gọi
  từ `toi_uu_van` (hậu kỳ) và `xep_tam` (kéo thả), **không** từ lần nesting đầu.
  Hai bộ xếp hình khác nhau cho hai tình huống khác nhau — đừng sửa một cái rồi
  tưởng đã sửa cả hai.

---

## 8. Mạch kiểm bản quyền — bị rải cố ý

**51 method, nằm rải ở 32 file, 41 cái trong số đó là `def` cuối cùng của
file.** Tác giả bẻ vụn phép kiểm và nhét mỗi mảnh vào một module không liên
quan. Vài ví dụ thật:

| Ở đâu | Tên | Thật ra làm gì |
|---|---|---|
| `method/xeptam/mirror.rb:466` | `machine_id` | lấy mã máy |
| `method/xeptam/drag.rb:484` | `licensed?` | cổng kiểm chính |
| `utils/sheet.rb:173` | `id_hash` | băm mã máy |
| `utils/sheet/reorder.rb:411` | `id_cache` | bộ nhớ đệm kết quả |
| `utils/nesting/corner.rb:623` | `deactivate_now` | gỡ kích hoạt |
| `utils/cutting/loop.rb:309` | `license_url` | dựng URL máy chủ |
| `utils/font/data.rb:6` | `read_license` | đọc file giấy phép |

Thêm vào đó, **mọi** lớp công cụ có một cặp `check_license` / `assert_license`
ở cuối file, và `KSU.with_license` ở [main.rb:78](ksu_vn/main.rb#L78) bọc toàn
bộ 14 lệnh.

### 8.1. Thủ thuật "mở lại sau khi gộp"

Mảnh bản quyền hầu như luôn nằm trong một khối **mở lại module, đặt sau dòng
gộp**:

```ruby
end
KSU::Xeptam.include(KSU::Drag)      # dòng 482 — Drag gộp vào Xeptam ở đây

module KSU::Drag                    # mở lại, SAU khi đã gộp
  def self.licensed?                # nên method này KHÔNG vào Xeptam
    str = KSU::Sheet.id_hash(KSU::Reorder.id_cache[1] ||= KSU::Mirror.machine_id.to_s)
    ...
  end
end
```

Vì `include` chụp ảnh tại thời điểm chạy, `def self.` thêm sau đó **không** lọt
vào module cha. Kết quả: `KSU::Xeptam.licensed?` không tồn tại, chỉ
`KSU::Drag.licensed?` có. Và mỗi lần gọi lại nhảy sang một module khác:

```
KSU::Drag.licensed?
  → KSU::Sheet.id_hash          utils/sheet.rb:173
  → KSU::Reorder.id_cache       utils/sheet/reorder.rb:411
  → KSU::Mirror.machine_id      method/xeptam/mirror.rb:466
      → KSU::Arrange.normalize_hw_id
      → KSU::Caidat.machine_fingerprint
  → KSU::Xeptam.license_gate    method/xeptam.rb:703
```

Không hop nào ở trong module mà tên nó gợi ý. Đó là điểm của thiết kế.

> **Ba điều phải nhớ:**
>
> 1. **Đây không phải mã lộn xộn — đây là thiết kế.** Rải ra để khó vá. Đừng
>    "dọn dẹp" bằng cách gom về một file; làm thế là phá đúng cái tính chất mà
>    nó được viết ra để có.
> 2. **Tên module ở đây vô nghĩa.** `machine_id` nằm trong `Mirror` không phải
>    vì nó liên quan đến lật gương. Tên module là do người đọc mã đặt (xem
>    [HANDOFF-giai-hex.md](HANDOFF-giai-hex.md) §3); vị trí thì do tác giả chọn
>    để giấu.
> 3. **Đừng tưởng một def cuối file là phần của file đó.** Thấy một method lạc
>    lõng ở dòng cuối, kiểm tra nó trong danh sách này trước:
>    `python tools/dothi.py --seam` → mục `BAN QUYEN`.

---

## 9. Vòng lặp phát triển

### 9.1. Sửa và thử lại trong SketchUp

Gõ vào Ruby Console:

```ruby
KSU.reload
```

Nạp lại cả cây theo `utils → system → method`, gom lỗi và in ra một lượt, rồi
gọi lại `KSU::Addon.import`. In `[KSU.reload] OK (n file)` nếu sạch.

**Không nạp lại được bằng `KSU.reload`:** `ksu_vn.rb`, `main.rb`, `clibs.rb`.
Ba file đó phải khởi động lại SketchUp. Thanh công cụ cũng chỉ dựng một lần
(`unless file_loaded?`), nên đổi `TOOL_DATA` thì phải khởi động lại.

### 9.2. Thử nhanh ngoài SketchUp

```
ruby tools/napthu.rb .
```

Nạp cả cây với stub thay cho API SketchUp. **Đây là phép kiểm rẻ nhất và nên
chạy sau mỗi lần sửa**: nó bắt lồng module sai, `include` module chưa tồn tại,
hằng đọc lúc nạp, và thứ tự nạp hỏng. Hiện in `NAP OK`, 62/62 module, 73 hằng.

Nó **không** bắt được lỗi hành vi — không có stub nào biết nesting là gì.

### 9.3. Chạy thật, không gõ tay

```
"SketchUp.exe" -RubyStartup <repo>\tools\khoidong.rb "<duong-dan>\thu.skp"
```

[tools/khoidong.rb](tools/khoidong.rb) chờ SketchUp nạp xong extension rồi tự
chạy. Bắt buộc truyền file `.skp`, nếu không SketchUp dừng ở màn hình Welcome.

### 9.4. Phép kiểm phải xanh trước khi commit

```
ruby   tools/napthu.rb .            # cây nạp được
python tools/codegraph.py . tools/graph.json
python tools/verify_graph.py        # 0 loi goi treo
python tools/dothi.py --dung
python tools/dothi.py --seam        # 0 hanh dong lac giua HTML va Ruby
```

Hai phép kiểm dưới đây là của việc **đổi tên**, không phải của việc sửa mã —
khi bạn sửa logic thì chúng **sẽ** đỏ, và đỏ là đúng:

```
python tools/kiemchuoi.py           # moi chuoi giong moc c45104c
python tools/verify_structure.py    # cau truc giong moc c45104c
```

> Khi đã thêm tính năng thật, hai phép kiểm này mất nghĩa so với mốc `c45104c`.
> Lúc đó chọn mốc mới: cả hai nhận tham số revision.

---

## 10. Đồ thị mã — `tools/dothi.py`

Dựng trước khi dùng (dưới một giây, bị `.gitignore` nên không có sẵn):

```
python tools/dothi.py --dung
```

| Lệnh | Trả lời câu hỏi |
|---|---|
| `--ai-goi TEN [--sau N]` | **Sửa cái này thì hỏng ở đâu?** — người gọi, đệ quy |
| `--goi TEN [--sau N]` | **Cái này dựa vào gì?** — bị gọi, đệ quy |
| `--duong A B` | Có đường gọi từ A tới B không, đi qua đâu |
| `--tinhnang KHOA` | Lát cắt một công cụ: file riêng, phụ thuộc, khoá cấu hình |
| `--file DUONGDAN` | Thẻ một file: def, ai gọi vào, gọi ra đâu |
| `--seam` | Mọi đường nối ra ngoài Ruby: lệnh, HTML↔Ruby, settings, thuộc tính model, native, bản quyền |
| `--diem-nong` | Def rủi ro cao nhất · mã chết · lời gọi mơ hồ |
| `--tim CHUOI` | Tìm def theo mảnh tên |

Khác với [tools/codegraph.py](tools/codegraph.py) ở chỗ: file kia là **bản kiểm
kê** phục vụ `verify_graph.py` ("có những gì"), file này là **đồ thị gọi hàm**
phục vụ việc sửa ("ai gọi ai"). Hai file độc lập; cái cũ không bị đụng tới.

### 10.1. Nó mô hình hoá được gì

Lời gọi có namespace · lời gọi trần theo chuỗi tra cứu Ruby · gộp module (§2) ·
hook `included` (§2.1) · `class << self` · `self.class.x` · chuỗi
`Ns.instance.x` · kế thừa · **197 quan hệ override** · 8 method native.

### 10.2. Nó **không** thấy gì — đọc kỹ chỗ này

Một đồ thị tĩnh trên Ruby có giới hạn thật, và biết giới hạn thì mới tin được
phần còn lại:

- **Lời gọi qua receiver không đoán được kiểu** (`@engine.stop`, `row.width`).
  Công cụ **cố tình không vẽ cạnh** ở đây — một cạnh sai còn tệ hơn thiếu cạnh
  khi người ta dùng đồ thị để quyết định sửa cái gì. Nó chỉ dùng những tên đó
  để lọc danh sách mã chết, và báo riêng ở `--diem-nong`.
- **Lời gọi mơ hồ** — một tên, nhiều def, không biết cái nào. Hiện chỉ còn **3
  chỗ**: `back_of`, `sync_back`, `back_face2?`. Được liệt kê riêng, không vẽ
  cạnh.
- **Ranh giới JS.** Engine nesting (§7.2) và cầu `skp()` (§5.2) không có cạnh
  gọi; `--seam` ghép hai đầu theo tên thay vì theo cú pháp.
- **`send` với tên dựng động.** Có `respond_to?(:x)` / `send(:x)` với symbol
  tĩnh thì bắt được; dựng tên từ chuỗi lúc chạy thì không.

### 10.3. Mã chết — 10 ứng viên, đã soát tay

Đã kiểm từng cái bằng grep: không nơi nào tham chiếu, kể cả trong heredoc JS.

```
KSU::Addon.register · .items · .dispatch_keys     ← API cho add-on ngoài, xem §11
KSU::Danhsovan.online?            KSU::Edit.clear_bindings
KSU::Font#digit_y_range           KSU::Resize.valid_key_format?
KSU::Settings.dlg3                KSU::Settings.presets_of
KSU::Field#commit_field_input     ← có 2 lớp con đè lên, xem bên dưới
```

Ba cái `KSU::Addon.*` **không phải mã chết**: đó là bề mặt cho add-on bên thứ
ba gọi vào (§11). Bảy cái còn lại là ứng viên xoá thật, nhưng hãy xoá có chủ
đích chứ không phải vì danh sách này nói thế.

`KSU::Field#commit_field_input` là trường hợp đồ thị kém chính xác: nó là bản
gốc, `Netcatcuoi` và `Xephang` đè lên, và phép phân giải tĩnh bắt trúng bản đè
trước. Nó có chạy.

---

## 11. Add-on: mở rộng mà không sửa cây

[system/addon.rb](ksu_vn/system/addon.rb) cho phép mã bên ngoài thêm một lệnh
vào thanh công cụ KSU: `KSU::Addon.register`, `.labels`, `.keys`, `.launch`,
`.icon_of`, `.visible?`, `.dispatch`. `KSU.merge_before_last` chèn các lệnh
add-on vào **trước mục cuối cùng** (tức trước "Cài đặt"), nên Cài đặt luôn ở
cuối thanh.

> Nếu tính năng bạn định thêm là một lệnh độc lập, cân nhắc viết nó thành
> add-on thay vì sửa `TOOL_DATA`: không phải đụng `main.rb`, không phải khởi
> động lại để thấy thay đổi thanh công cụ, và lần cập nhật plugin sau không
> ghi đè mất.

---

## 12. Thêm một tính năng: hai công thức

### 12.1. Thêm một ô cài đặt cho công cụ đã có

1. Thêm ô vào `ksu_vn/html/<icon>.html` (loại A, §5.1) với khoá mới.
2. Đọc nó ở Ruby: `KSU::Settings.get("khoa_moi", mac_dinh, "<tool_key>")`.
3. Nếu nó phải ảnh hưởng mọi công cụ, thêm khoá vào
   `KSU::Const::GLOBAL_SETTING_KEYS` và cài `reload_settings` cho công cụ.
4. `KSU.reload`, mở lại Cài đặt.

Không cần callback mới: `save_setting` đã có sẵn cho mọi tab.

### 12.2. Thêm một hành động cho một trang loại B

1. `skp('ten_hanh_dong', payload)` trong `ksu_vn/html/<icon>.html`.
2. `when "ten_hanh_dong"` trong `handle_action` của module tương ứng
   (`method/<ten>.rb`, hoặc `method/nesting/launch.rb` với nesting).
3. Trả dữ liệu về trang bằng `KSU::Settings.send_to_dialog(dlg, kind, action, resp)`.
4. `python tools/dothi.py --dung && python tools/dothi.py --seam` — mục cầu nối
   phải không có dòng `[!]` nào.

Bước 4 là bước người ta hay bỏ, và đúng cái bước đó bắt lỗi gõ sai tên hành
động — lỗi mà trình duyệt lẫn Ruby đều im lặng bỏ qua.

---

## 13. Cạm bẫy đã biết

| Triệu chứng | Nguyên nhân |
|---|---|
| Sửa `TOOL_DATA` mà thanh công cụ không đổi | `build_ui` chạy một lần (`unless file_loaded?`); phải khởi động lại SketchUp |
| Nút trên dialog bấm không làm gì, không lỗi | Tên trong `skp()` không khớp nhãn `when` — chạy `--seam` |
| Lỗi chỉ xuất hiện sau `KSU.reload`, không khi khởi động | Thứ tự nạp hai đường khác nhau (§1) |
| Enter trong ô nhập không vào nhánh của bạn | `SbUserTextHandler` prepend chen trước `onKeyDown` (§2.1) |
| Grep không thấy nơi định nghĩa một lời gọi trần | Nó ở file anh em, gộp qua `include` ở dòng cuối (§2) |
| Một method "vô nghĩa" ở cuối file | Mảnh của mạch bản quyền (§8) |
| Đổi khoá `ABF/*` làm hỏng file khách | `ABF` là hợp đồng với CAM bên ngoài (§6.2) |
| Undo nuốt mất thao tác | Thiếu cặp `KSU.start` / `KSU.commit`, hoặc thiếu `abort_op` ở nhánh lỗi |
| `verify_graph.py` xanh nhưng mã vẫn hỏng | Nó chỉ soi lời gọi Ruby; ranh giới JS nó không thấy (§5.2, §7.2) |

---

## 14. Nợ kỹ thuật đã ghi nhận

- **`tools/codegraph.py` quét cả `tools/*.rb`** (94 file thay vì 89), nên 51
  def của bộ công cụ lọt vào `defsite` của `graph.json` — **28 cái tên** mà cây
  plugin không hề định nghĩa. Phần lớn đến từ các stub API SketchUp trong
  `napthu.rb`: `active_model`, `format_length`, `file_loaded?`, `cm`, `feet`,
  `inch`, `degrees`, `const_missing`…

  Hệ quả cụ thể: `verify_graph.py` coi một lời gọi tới `format_length` là hợp
  lệ vì "có def tên đó" — nhưng def đó là stub trong `tools/napthu.rb`, không
  phải mã plugin. Phép kiểm dễ dãi hơn mức nó tự nhận. Sửa: cho `codegraph.py`
  dùng `kscommon.ruby_files()` như mọi công cụ khác.
- **Một phụ thuộc ngược thật** (§3): `KSU::Const.fetch_json` gọi lên
  `KSU::Themtam.http_fetch`. Một tiện ích tầng dưới mượn mã HTTP của một công
  cụ tầng trên; nên chuyển hàm đó xuống `utils/`.
- **7 method không ai gọi** (§10.3) — xoá được, nhưng cần quyết định.
- **`utils/nesting/kcore.rb`: 34 KB JS đã minify, không có bản gốc.** Không sửa
  được thuật toán nesting chính, chỉ thay được tham số truyền vào. Nếu cần đổi
  thuật toán, đó là một dự án riêng, không phải một lần sửa.
- **Hai thứ tự nạp khác nhau** (§1) — nên hợp nhất thành một.

---

## 15. Bắt đầu từ đâu

Lần đầu mở repo:

```
ruby   tools/napthu.rb .                   # cây lành chưa
python tools/dothi.py --dung               # dung do thi
python tools/dothi.py --seam               # xem toan bo be mat ngoai
python tools/dothi.py --diem-nong          # biet cho nao dung duoc
python tools/dothi.py --tinhnang <khoa>    # lat cat cai sap sua
```

Rồi đọc theo thứ tự: [main.rb](ksu_vn/main.rb) (14 lệnh) →
[utils/other.rb](ksu_vn/utils/other.rb) (hạt nhân) →
[system/setting.rb](ksu_vn/system/setting.rb) (cài đặt + dialog) → thư mục của
công cụ bạn cần sửa.
