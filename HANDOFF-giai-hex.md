# HANDOFF — Giải mã và đặt lại tên: cây KSU

Tài liệu chuyển giao cho người tiếp nhận **việc dịch ngược KSU**: mở chuỗi, lấy
lại tên cho những định danh bị trình bảo vệ xoá, và bộ phép kiểm đi kèm.

| | |
|---|---|
| **Phạm vi** | Từ điển tên · bộ công cụ · phép kiểm · phần còn nợ |
| **Cây mã** | [ksu_vn/](ksu_vn/) — 127 file `.rb`, 38.201 dòng |
| **Nguồn phát hành** | KSU **2.3.2**, 127 file `.rbx`; đã giải mã ở commit `e72d0b2` |
| **Trạng thái tên** | **5.926/6.656 định danh (89,0 %)** — 77.596/81.719 lượt (95,0 %) |
| | **tên method 2.574/2.574 = 100 %** · `@ivar` 96,3 % · biến cục bộ 81,1 % |
| **Đo ngày** | 05/10/2026, bằng các lệnh in nguyên văn ở §7 |
| **Còn nợ** | 589 biến cục bộ, 17 `@ivar`, 158 chỗ tên nói quá — xem §8 |

Bản 2.1.5 đã đọc xong trước đó (3.768/3.768). Tài liệu này nói về **2.3.2**, và
nói rõ chỗ nào khác 2.1.5. Từ điển của 2.1.5 được giữ nguyên ở
[tools/v2.1.5/](tools/v2.1.5/) — khoá hex trong đó thuộc bản dựng cũ, đừng áp
thẳng (lý do ở §2).

---

## 1. Hiện trạng

Commit `e72d0b2` đã làm xong bước giải mã: 127 file `.rbx` → `.rb`, 5.377 chuỗi
mã hoá đã mở. **Không có bước giải mã nào phải chạy lại.**

Giải mã trả lại **mã chạy được**, không trả lại **mã đọc được**. Trình bảo vệ đã
đổi mọi định danh do tác giả đặt thành `_` + 8 ký tự hex, và xoá sạch chú thích.
Chú thích thì không lấy lại được; mọi chú thích trong cây hiện nay là do người
đọc mã viết thêm.

Mỗi file giải mã mở đầu bằng một hằng `XSU_NOTICE`. `datten.py` gỡ dòng này khi
áp tên — để lại thì Ruby cảnh báo khởi tạo lại hằng một lần cho mỗi file. Hệ quả
phải nhớ: **dòng N của cây làm việc là dòng N+1 của mốc.** `kiemchuoi.py` và
`verify_structure.py` đều bỏ dòng này ở cả hai vế nên không lệch.

Phần mới của 2.3.2 so với 2.1.5 là 39 file: nhân CNC `method/giacong/` (24
file, ~12.700 dòng), `method/catcuoi/`, `method/toiuu/`, `method/thongke/*` và
`utils/{marquee,normalize}.rb`, `utils/nesting/overlap.rb`.

---

## 2. HAI đợt làm rối trong một cây — điều quan trọng nhất của bản này

2.1.5 chỉ có **một** ánh xạ `tên → hex`, nên "một tên ứng với đúng một hex" là
bất biến cho cả cây. **2.3.2 thì không.** Đo được:

| | giữ nguyên hex của 2.1.5 |
|---|---:|
| `method/toiuuvan*`, `method/netcatcuoi*`, `method/danhsovan.rb` | **100 %** |
| file chỉ có trong 2.3.2 (`giacong/`, `toiuu/`, `catcuoi/`…) | **0 %** |
| toàn bộ file cũ, tính gộp | 22,2 % |

Nghĩa là 2.3.2 **không làm rối lại toàn cây**: những đơn vị tên tiếng Việt mà
bản mới thay thế được đóng gói **nguyên xi từ bản dựng 2.1.5**, còn mã mới và mã
sửa thì nhận một ánh xạ mới. Ba hệ quả, cái nào quên cũng trả giá:

1. **Không áp từ điển 2.1.5 theo hex.** Trong số các token hex ghép được giữa
   hai mốc, chỉ 27,7 % trùng hex. Áp theo hex là đặt sai tên ba trên bốn chỗ.
   Cái sống sót qua ranh giới phiên bản là **phép ghép dòng**, không phải hex —
   đó là lý do [tools/sinhban.py](tools/sinhban.py) tồn tại (§3.1).
2. **Bất biến một-tên-một-hex chỉ đúng TRONG MỘT ĐỢT.** Một từ tác giả dùng ở cả
   hai nửa thì có một hex ở nửa này và một hex khác ở nửa kia; đó không phải
   lỗi. `trahex.py --soat` nay tách hai loại: 497 chỗ bắc cầu giữa hai đợt
   (không phải lỗi) và 158 chỗ nằm trong cùng một đợt (phải đọc lại).
3. **Hai nửa MỞ CÙNG MỘT MODULE.** `module KSU::Back` có ở cả
   `method/toiuu/back.rb` lẫn `method/toiuuvan/back.rb`; `KSU::Chuanhoa` có ở cả
   `utils/normalize.rb` lẫn `utils/chuanhoa.rb`. Trong bản phát hành chúng không
   đụng nhau vì hex khác nhau — nhưng **đặt cùng một tên cho hai bên thì def sau
   đè def trước và một method biến mất**. Đợt này đã dính đúng 160 chỗ như vậy,
   và không phép kiểm nào cũ thấy được: `ruby -c` vẫn OK, `verify_structure` chỉ
   che định danh nên hình dạng vẫn khớp, `verify_graph` vẫn phân giải được vì
   *cái tên* vẫn tồn tại. Rào mới `same_module_clashes` trong
   [tools/datten.py](tools/datten.py) bắt loại này; bản 2.1.5 giữ hex cũ nay
   mang đuôi `_v1`.

Kiểm lại lúc nào cũng được:

```bash
python tools/trahex.py --soat          # tách hai đợt rồi mới kết luận
python tools/datten.py --check         # trong đó có rào cùng-module
```

Tính chất của **một** đợt thì vẫn như 2.1.5: mọi hex dài đúng 9 ký tự, không hex
nào là tiền tố của hex khác, nên thay theo biên từ là một-đối-một. Và vì ánh xạ
là `tên → hex`, mọi biến tác giả đặt cùng tên trong một đợt đều thành cùng một
hex — `_e2378ada` xuất hiện 263 lần với hàng chục vai trò khác nhau là chuyện
bình thường, không phải lỗi đọc.

---

## 3. Tên lấy ở đâu — thứ tự ưu tiên

Thứ tự nạp trong `datten.py` (file sau đè file trước):

```
sinhdoi.yml  <  tenauto.yml  <  sinhban.yml  <  ten.yml  <  tenpv.yml
```

| Từ điển | Toàn cục | Theo phạm vi | Nguồn |
|---|---:|---:|---|
| `sinhban.yml` → `ten:` | 3.144 | — | chuyển từ cây 2.1.5 đã đọc (§3.1) |
| `sinhban.yml` → `vai:` | 114 | — | nt, nhưng 2.1.5 chỉ nói VAI |
| `ten.yml` → `ten:` | 1.412 | — | đọc tay + mót từ chuỗi (§3.2–3.4) |
| `ten.yml` → `vai:` | 41 | — | tên theo VAI, không phải chữ tác giả gõ |
| `tenauto.yml` | 148 | 1.549 | suy theo kiểu dữ liệu, theo thân hàm |
| `sinhdoi.yml` | 245 | — | bản sinh đôi ZSU |
| `tenpv.yml` | — | 23 | gỡ đụng độ, do `goxungdot.py` sinh |

### 3.1. Bản sinh của chính nó: KSU 2.1.5 · 3.258 tên

Nguồn lớn nhất. [tools/sinhban.py](tools/sinhban.py) là phương pháp của
`sinhdoi.py` chĩa vào một nguồn khác: **bản 2.1.5 đã đọc xong của chính cây
này**. Cả 88 file của 2.1.5 vẫn còn trong 2.3.2 và 88,1 % số dòng không đổi, nên
phép ghép cho rất nhiều.

Bốn luật ghép giữ nguyên: che chuỗi + chú thích, thay mọi định danh bằng một
dấu, `difflib` chỉ nhận khối `equal`, và trong một cặp dòng **mọi token không
phải hex phải đọc giống hệt nhau**. Một hex chỉ nhận tên khi **mọi phiếu nhất
trí**.

Hai chỗ khác `sinhdoi.py`, cả hai đều quan trọng:

- **`ALIAS`**: 2.3.2 thêm bản tên tiếng Anh *bên cạnh* bản tiếng Việt
  (`toiuuvan.rb` → `toiuu.rb`, `netcatcuoi/` → `catcuoi/`, `thongke/xuat.rb` →
  `thongke/export.rb`, `chuanhoa.rb` → `normalize.rb`, `danhsovan.rb` →
  `danhso.rb`). Chúng ở đường dẫn khác nhau nên phép duyệt theo đường dẫn không
  bao giờ thử tới; khai trong `ALIAS` thì ghép được 80–90 % số dòng. **Nhưng
  đúng vì thế mà sinh ra bẫy §2.3** — đọc kỹ chỗ đó.
- **Mức khẳng định được chuyển theo VỊ TRÍ, không theo cái tên.** Cả 85 tên
  2.1.5 xếp dưới `vai:` cũng là `ten:` của một hex khác (`view`, `panel`,
  `bbox`, `thickness`…), nên hỏi "từ này khẳng định cái gì" là câu hỏi không có
  lời đáp — hỏi thế đã nâng oan 324 tên VAI thành chữ tác giả gõ. Hỏi theo vị
  trí thì có đáp án chính xác: `datten.py` thay một định danh bằng một định
  danh, nên mốc 2.1.5 và cây 2.1.5 đã đọc khớp nhau từng dòng từng token (kiểm
  rồi: 88/88 file, 84.688 vị trí, lệch 0). Token thứ i của dòng j do đó đến từ
  đúng token thứ i dòng j của mốc — một hex có mục từ điển đã biết, hoặc một
  định danh trình làm rối chưa bao giờ đụng tới (loại này là chữ tác giả, mạnh
  nhất).

Tên kiểu dữ liệu mà 2.1.5 tự sinh thì **bỏ**, không chuyển: `dexuat.py` tính lại
từ bằng chứng của chính 2.3.2, theo từng thân hàm. Chuyển sang là phát biểu một
phỏng đoán về 2.1.5 thành sự thật về 2.3.2 — đúng cái lỗi §6.7 ghi lại.

### 3.2. Chuỗi tác giả tự viết ra · 72 tên

Trình bảo vệ đổi được định danh nhưng **không đổi được chuỗi**, mà mã này tự gọi
tên biến của nó trong chuỗi, ngay cạnh chỗ dùng:

```ruby
{ sheets: _59bbde96, total: _59bbde96.length }   # nhãn hash
_a952a0af = inst.get_attribute("KSU", "phan")
```

[tools/motten.py](tools/motten.py) đọc bốn mạch này (khoá hash, nhãn hash,
`get_attribute`, `fetch`/`dig`). Chỉ nhận khi mọi phiếu nhất trí, hoặc phiếu đầu
**trội ≥ 4 lần** phiếu nhì. Đợt này mót được 165 tên, trong đó 72 tên cho hex
chưa ai đặt; 59 tên trùng khớp với `sinhban.yml`, và **34 tên lệch thì giữ bên
`sinhban.yml`** — vì 2.1.5 đã đọc tay và sửa chính lớp phiếu này (`build_cells`,
`fld_bbox`, `slot_panel` ở §6.5–6.6 là ba ví dụ ghi sẵn).

### 3.3. Tên bị bỏ sót vì trùng API — tên gốc thật

Trình làm rối bỏ qua định danh trùng tên API Ruby/SketchUp, và chính chỗ nó bỏ
sót lại khoá cứng tên của hex bên cạnh. Thư viện native khai method **theo tên**
nên tên của chúng không thể bị làm rối: tám tên cũ cộng 23 tên mới của nửa CNC
(`marching`, `rdp_keep`, `rescue_drift`, `planar_graph`…) đều khai trong
`NATIVE_METHODS` của [tools/verify_graph.py](tools/verify_graph.py).

### 3.4. Đọc tay · 1.412 tên

Phần còn lại, gần như trọn `method/giacong/` — 2.3.2 viết mới nên không bản nào
chuyển sang được. Thứ tự tra: [tools/profile.py](tools/profile.py) xem tập
method gọi lên hex → [tools/usage.py](tools/usage.py) xem nó dùng ở đâu →
[tools/doc.py](tools/doc.py) đọc thân hàm. Hằng module/class **không bị làm
rối**, nên khung `KSU::Cnc::{Util, Natural, Database, Naming, Latch, Reader,
Arc, Dogbone, Compressor, Locked, Calc, Clip, Rail, Gate, Canvas, Export,
Planner, Pool, Store…}` đọc được ngay và là chỗ bám tốt nhất để đặt tên.

Không đủ căn cứ thì **để nguyên hex**.

---

## 4. Bộ công cụ

| Lệnh | Làm gì |
|---|---|
| `python tools/datten.py --check \| --dry-run \| --apply` | Áp cả từ điển, có rào an toàn |
| `python tools/datten.py --lam-lai` | **Dựng lại từ mốc rồi áp lại cả từ điển** — dùng mỗi khi sửa một tên |
| `python tools/datten.py --retag CŨ MỚI` | Đổi một tên **đã áp** — che chuỗi sẵn, đừng tự viết regex |
| `python tools/sinhban.py <cây-2.1.5-đã-đặt-tên>` | **Chuyển tên từ bản 2.1.5 (§3.1)** |
| `python tools/motten.py [-o f.yml]` | Mót tên từ chuỗi còn sót (§3.2) |
| `python tools/sinhdoi.py <cây-zsu>` | Chuyển tên từ bản sinh đôi ZSU |
| `python tools/dexuat.py --write` | Đề xuất tên theo **kiểu dữ liệu**, theo từng thân hàm |
| `python tools/goxungdot.py --apply` | Gỡ xung đột phạm vi bằng cách đánh số, sinh `tenpv.yml` |
| `python tools/doc.py <file.rb>` | In **chỉ những method còn hex**, kèm thân hàm |
| `python tools/trahex.py <file> <dòng>` | Tra ngược: tên đã áp ở đây vốn là hex nào |
| `python tools/trahex.py --tim <tên>` | Tra một tên trên **cả cây**, ghép theo vị trí |
| `python tools/trahex.py --soat` | **Soát một-tên-một-hex, TÁCH THEO ĐỢT LÀM RỐI** (§2) |
| `python tools/progress.py [--todo]` | Đo tiến độ, liệt kê hex còn lại nhiều lượt nhất |
| `python tools/profile.py` · `usage.py` · `showdef.py` | Tra ngữ cảnh một hex trước khi đặt tên |
| `python tools/kiemchuoi.py` | Mọi chuỗi + chú thích phải đọc y hệt mốc |
| `python tools/verify_structure.py` | Chứng minh một lần sửa **chỉ đổi tên** |
| `python tools/codegraph.py . tools/graph.json` | Dựng lại đồ thị (bị `.gitignore`) |
| `python tools/verify_graph.py` | Mọi lời gọi phải phân giải về một `def` có thật |
| `ruby tools/napthu.rb .` | Nạp cả cây ngoài SketchUp bằng stub |
| `python tools/sinhdoisanh.py` | Sinh lại `doisanh_cases.rb` theo hex của mốc hiện tại |
| `ruby tools/doisanh.rb` | **Chỉ chạy trong Ruby Console của SketchUp** (§8) |

Nền chung là [tools/kscommon.py](tools/kscommon.py). Phần quan trọng nhất trong
đó là `text_spans()` — nó **đi bộ qua mã nguồn**, không dùng regex, để trả lời
"ký tự nào là chữ, ký tự nào là mã". Dùng nó, đừng tự ghép dấu nháy (§6.2).

### Rào an toàn trong `datten.py`

Mỗi rào có ở đây vì một lần đổi tên đã hỏng nếu thiếu nó. Sáu rào đầu là của
2.1.5; hai rào cuối thêm trong đợt này.

1. **Tên phải là định danh Ruby hợp lệ và không phải từ khoá.** Một hex nhận tên
   `else` vẫn biên dịch được trong khi luồng điều khiển đã bị viết lại.
2. **Không trùng định danh file đã có** — xét **theo từng thân hàm**.
3. **Tên method phải là một tên cho cả cây.** Định nghĩa ở file này, lời gọi ở
   file khác. Rào này đọc danh sách `def` **từ mốc**, vì khi tên đã áp thì hex
   không còn trên đĩa và phép kiểm sẽ im lặng ngừng canh.
4. **Hex lặp lại trong một danh sách tham số phải giữ dấu `_` ở đầu.** Ruby chỉ
   cho tham số trùng tên khi tên bắt đầu bằng `_`. Rào này nay **phân tích** danh
   sách tham số chứ không đếm hex thô: đếm thô báo oan hai chỗ hợp lệ —
   `(stream, len = "...#{stream.bytesize}")`, chỗ lặp nằm trong giá trị mặc
   định, và một đoạn ternary kẹp giữa hai toán tử `|` toàn `@ivar`.
5. **Hex nào còn là `@ivar` thì tên không được kết thúc bằng `?` hay `!`.**
6. **Hai hex không được cùng tên trong một phạm vi.**
7. **(mới) Hex nào còn là BIẾN CỤC BỘ hay THAM SỐ thì tên cũng không được kết
   thúc bằng `?`/`!`.** Rào 5 chỉ xét `@ivar` nên bỏ lọt: `elements_match?` vừa
   là method của `Clip` vừa là biến cục bộ ở `rescue.rb`, và
   `elements_match? = arr[:refit_check]` là SyntaxError — chỉ `ruby -c` bắt
   được, sau khi đã ghi ra đĩa.
8. **(mới) Hai hex ĐỊNH NGHĨA trong CÙNG MỘT MODULE không được cùng tên.**
   Đây là rào duy nhất có thể **xoá mất hành vi** thay vì làm vỡ bản dựng, và là
   rào không phép kiểm nào khác thấy. Xem §2.3.

`ten.yml` có khoá `bo:` để **bác phiếu** của từ điển sinh ra. Cần nó vì các file
đó chạy lại là ghi đè, nên lý do bác phải nằm ở file viết tay.

---

## 5. Vòng kiểm sau mỗi lần đổi tên — và chỗ mù của từng phép

Không phép nào đủ một mình. Chúng mù ở những chỗ khác nhau.

| Phép | Bắt được | **Không** bắt được |
|---|---|---|
| `ruby -c` từng file | Cú pháp vỡ | Hex nhận tên `else`; **chuỗi bị hỏng** |
| `kiemchuoi.py` | Chuỗi và chú thích bị đổi dù một ký tự | Đổi cấu trúc; tên sai nghĩa |
| `verify_structure.py` | Thay đổi cấu trúc ngoài việc đổi tên | Tên sai nghĩa; **def bị đè** |
| `verify_graph.py` | Lời gọi treo | Tên đúng chính tả nhưng sai nghĩa; **def bị đè** |
| `napthu.rb` | Lỗi **lúc nạp** | Hành vi — nó không gọi hàm nào |
| `datten.py --check` | Tám rào ở §4, kể cả **def bị đè** | Tên sai nghĩa mà không trùng ai |
| `trahex.py --soat` | Hai hex **cùng đợt** mang một tên | Tên chỉ có một hex nhưng sai nghĩa |
| `doisanh.rb` | **Hành vi thật sự đổi** | Chỉ phủ 30 hàm thuần (§8) |

Đã **thử phá có chủ ý** để chứng minh chúng cắn thật:

- thêm một ký tự vào một chuỗi → `kiemchuoi` bắt, còn `ruby -c` vẫn Syntax OK;
- chèn `return if false` mà không đụng chuỗi → `verify_structure` bắt, còn
  `kiemchuoi` vẫn sạch;
- đặt lại `_5ba6b2e6` thành `elements_match?` → rào 7 bắt ngay, còn rào 5 (chỉ
  xét `@ivar`) thì không — đúng cách lỗi này đã lọt lần đầu.

`verify_graph.py` đọc **ảnh chụp** `tools/graph.json`. Ảnh cũ làm nó báo xanh
nhầm, nên phải dựng lại trước khi kiểm:

```bash
python tools/codegraph.py . tools/graph.json
```

### Lời gọi động — lớp rủi ro không phép kiểm nào nhìn thấy

Đổi tên một method mà chỗ gọi nằm trong **chuỗi** thì không phép kiểm nào bắt.
Đã soi cả mốc 2.3.2: **không có** `send` / `__send__` / `public_send`,
`define_method`, `method(:x)`, `method_missing`. `respond_to?(:_bbaa2919)` dùng
**symbol**, mà symbol là mã nên đổi tên cùng lúc với chỗ định nghĩa.
`instance_variable_get("@#{key}")` dựng tên lúc chạy — nhưng **không một chuỗi
nào trong cây chứa hex** (đếm được: 0), nên nó chỉ trỏ tới những `@ivar` trình
làm rối chưa bao giờ đụng.

```bash
python -c "import sys;sys.path.insert(0,'tools');import re;from kscommon import literals;from datten import baseline_sources;print(sum(len(re.findall(r'_[0-9a-f]{8}',t)) for s in baseline_sources().values() for t in literals(s)))"
```

**Nạp được không có nghĩa là chạy đúng.** Chốt cuối vẫn là SketchUp thật (§8).

---

## 6. Cạm bẫy — đã dính thật

Mười bốn bẫy của 2.1.5 vẫn đúng nguyên. Dưới đây là bản rút gọn cộng những cái
mới của đợt này.

1. **Ranh giới từ của regex ăn vào chữ tiếng Việt.** `\b` tính theo
   `[A-Za-z0-9_]`, nguyên âm tiếng Việt nằm ngoài. Đổi hex thì an toàn; đổi một
   tên **đã áp** thì không — luôn dùng `datten.py --retag`.
2. **Chuỗi nội suy lồng nhau, heredoc HTML, và REGEX.** Chuỗi Ruby chứa được
   `#{...}`, trong đó là mã, mà mã đó lại mở được chuỗi khác. Và một dòng bắt
   đầu bằng `/` là regex chứ không phải phép chia. Dùng `code_only`, đừng ghép
   dấu nháy bằng mẫu.
3. **YAML nuốt tên.** Một tên `on` / `off` / `yes` / `no` / `true` vào từ điển
   thì PyYAML đọc ra boolean của Python chứ không phải chuỗi — rào 1 báo "không
   phải định danh Ruby hợp lệ", đúng về *giá trị* và sai về *cái tên*.
   `_0574ff7a` đúng là `on` (trạng thái công tắc ở `preset/field.rb`);
   `sinhban.py` nay tự bọc nháy những tên như vậy.
4. **Thừa `\` trong heredoc của shell.** Viết file Python bằng `cat <<'EOF'` ở
   môi trường này **mất một dấu `\` trong mỗi cặp `\\`**: `[^"\\]` thành `[^"\]`
   và regex vừa sai vừa treo. Viết file Python bằng công cụ ghi file.
5. **Tên phải đọc từ CÁCH DÙNG, không theo nhãn một chỗ.** `_a4286a6a` nhận
   phiếu `cells` vì có chỗ viết `{ cells: _a4286a6a(...) }` — nhưng nó là **hàm
   dựng** mảng cells. Cùng lỗi ấy ở 2.3.2: `_bc0dc9c4` nhận 10 phiếu `key` từ
   `{ key: Natural._bc0dc9c4(...) }` trong khi nó là hàm **sinh** khoá sắp xếp.
6. **Hàng xóm chưa bị làm rối là căn cứ tốt nhất.** `_2763c3ca` được 2.1.5 đọc
   là `thick`, và `sinhban.py` chuyển nguyên sang. Sai: hai vai một từ — hàm trả
   chuỗi dịch `Text.t(:quet, :khong_du_lieu)`, **và** tham số cắt nhau của đoạn
   thẳng, mà hàng xóm còn nguyên tên là `first_cross_t` / `seg_cross_t` và nó bị
   kiểm `.between?(0.0, 1.0)`. Tên đúng là `t`, 474 lượt.
7. **Bản sinh chuyển sang cả những tên TỰ SINH.** Lọc chúng ra, để `dexuat.py`
   tính lại từ bằng chứng của cây này.
8. **Ghép theo dòng `def` là ghép nhầm.** `def _abc(x, y)` có khung giống hệt
   mọi `def` hai tham số khác. `soatham.py` soát lại bằng **thân hàm**.
9. **Tên đã áp thì không sửa thẳng được.** Sửa trong từ điển rồi
   `datten.py --lam-lai`.
10. **Mọi công cụ SINH tên phải đọc từ MỐC, không đọc cây làm việc.** Khi tên đã
    áp thì hex không còn trên đĩa và các công cụ im lặng rơi về gần 0.
    `dexuat.py` có rào từ chối ghi khi số đề xuất tụt — nhưng **cũng tụt một
    cách chính đáng** khi từ điển tay vừa phủ thêm, lúc đó `--force` là đúng.
    `dexuat.py` nay đọc cả `sinhban.yml` vào tập "đã có tên" để khỏi đè một chữ
    tác giả bằng một kiểu dữ liệu.
11. **Ghép tên đã áp với hex bằng mắt là ghép sai.** Dùng `trahex.py`, nó ghép
    theo **vị trí**.
12. **(mới) Hai def cùng tên trong một module thì một cái biến mất.** §2.3. Đây
    là lỗi nặng nhất của đợt này — 160 chỗ, do `ALIAS` của `sinhban.py` chuyển
    một tên 2.1.5 sang cả bản cũ lẫn bản mới.
13. **(mới) `?`/`!` không chỉ vướng `@ivar`.** Rào 7 ở §4.
14. **(mới) `codegraph.py` và `verify_graph.py` từng đọc chuỗi và regex như mã.**
    Ruột của `"KSU.sheet-material"` báo thành lời gọi `KSU.sheet`, và
    `/_MAT_(?:TRUOC|SAU)/` báo thành method `_MAT_` — **lời gọi treo mà không
    một lần đổi tên nào sửa được**. Cả hai nay đọc qua `code_only`. Cái giá của
    loại báo nhầm này là nó **che mất báo thật**.
15. **(mới) `verify_graph` phải biết cái gì vốn đã treo.** 10 lời gọi treo còn
    lại đã treo **sẵn trong bản phát hành**, kiểm theo hex chứ không theo tên:
    `_c52ad8bc` (→ `apply_label_hiding`) và `_7b408093` (→ `sides`) được gọi mà
    không có `def` nào trong cả 127 file. Cả bốn chỗ gọi đều nằm trong ba đơn vị
    tiếng Việt đã bị thay thế. Chúng nằm trong `KNOWN_MISSING`, và danh sách đó
    chỉ được **ngắn đi**, không bao giờ dài ra.
16. **Thà để trống còn hơn đoán.** Một tên sai tệ hơn một hex: hex nói "chưa
    biết", tên sai nói dối.
17. **Hạ `ten:` xuống `vai:` KHÔNG trung tính nếu `tenauto.yml` gán hex đó theo
    phạm vi.** Một tên vai trò trần vào làm `*` mặc định và nhường lại từng
    thân hàm cho tên sinh tự động, nên `groups` tụt về `arr2`. `load_dicts`
    có ghi cảnh báo này. Luật: hex nào `tenauto.yml` gán theo phạm vi thì
    **buộc phải giữ** `ten:`, hạ bên kia của cặp. Kiểm bằng máy trước khi hạ.
18. **Mục `mau_thuan:` của `sinhban.yml` có giá trị TRỐNG, theo sau là chú
    thích.** `_2f9ede84:   # {...}` — regex `(_[0-9a-f]{8}): *(\S+)` bắt `#`
    làm tên rồi ghi ra `_2f9ede84: #`, mà YAML đọc lại thành rỗng, nên hex
    lặng lẽ rơi về tên của từ điển trước đó. Đọc các `.yml` này bằng `yaml`,
    đừng bằng regex.

---

## 7. Hiện trạng — đo 05/10/2026

| Phép | Lệnh | Kết quả |
|---|---|---|
| Tên định danh | `python tools/progress.py` | **5.926/6.656 = 89,0 %** |
| — tên method | nt | **2.574/2.574 = 100 %** |
| — biến thực thể `@` | nt | 447/464 = 96,3 % |
| — biến cục bộ / tham số | nt | 2.525/3.114 = 81,1 % |
| Lượt xuất hiện | nt | **77.596/81.719 = 95,0 %** |
| Cú pháp | `ruby -c` từng file | **127/127 OK** |
| Chuỗi/chú thích | `python tools/kiemchuoi.py` | **0/128 file bị đổi** |
| Chỉ đổi tên | `python tools/verify_structure.py` | **0/128 file khác mốc** |
| Tám rào | `python tools/datten.py --check` | **OK** |
| Def bị đè | rào cùng-module trong `--check` | **0** (2.936 def riêng biệt, bằng mốc) |
| Lời gọi treo | `codegraph.py` rồi `verify_graph.py` | **0** |
| Nạp cả cây | `ruby tools/napthu.rb .` | **NAP OK** — 74 hằng `KSU::*` |
| Một-tên-một-hex | `python tools/trahex.py --soat` | 579 bắc cầu hai đợt (OK) · **0 cùng đợt** |
| Đối sánh hành vi | `ruby tools/doisanh.rb` | **79/79 giống nhau từng byte** — phủ 17,1 % số method (§8) |

Chạy mọi lệnh Python với `PYTHONIOENCODING=utf-8`: console cp1252 của Windows
ném `UnicodeEncodeError` ngay khi gặp chữ Việt.

---

## 8. Còn nợ

Xếp theo mức quan trọng, cao xuống thấp.

1. **Đối sánh hành vi mới phủ 17,1 %.** `doisanh.rb` đã chạy hai bên: bản phát
   hành trên SketchUp 25 và cây đọc được trên SketchUp 24. **79/79 trường hợp
   giống nhau từng byte**, kể cả 49 ca trong `method/giacong/`. Nhưng 79 ca chỉ
   chạm 7 module — **504 trên 2.943 method** — và đều là hàm thuần: không ca nào
   đụng UI, đụng model, hay đụng đường xuất DXF/G-code. Thêm ca ở
   `tools/sinhdoisanh.py`, **đừng sửa tay `doisanh_cases.rb`**.

   Cách chạy: mở bản phát hành ở một SketchUp và cây đọc được ở một SketchUp
   khác (bản thứ hai **không được cài plugin** — `doisanh.rb` chọn bên bằng
   `defined?(KSU::Geom)`), `load` nó ở cả hai, rồi so `doisanh_goc.txt` với
   `doisanh_moi.txt`. Chỉ hai dòng đầu được phép khác.

   Đọc dòng `cnc-native:` trước đã. `KSU::Cnc::Calc` gọi sang phần mở rộng
   native khi có và lùi về Ruby khi không, mà cây này không kèm `.so`/`.dll`
   nào — nên lần chạy vừa rồi là `true` bên bản phát hành, `false` bên cây đọc
   được. `dedupe_loop`, `signed_area` và `circle_from_points` vì thế chạy hai
   nhánh mã khác nhau; chúng vẫn ra cùng kết quả, nghĩa là nhánh Ruby khớp với
   native trên các ca này. Nếu sau này chúng lệch nhau, đọc cờ này trước khi
   quy cho việc đổi tên.
2. **589 biến cục bộ + 17 `@ivar` còn hex** (5 % số lượt). `dexuat.py` nói
   "không đủ bằng chứng" cho 661 hex — chúng xuất hiện quá ít hoặc không có
   method nào gọi lên để suy ra kiểu.
3. **Soát lại `tenauto.yml`** (1.549 mục theo phạm vi): chúng chỉ khẳng định
   kiểu dữ liệu, nhưng kiểu đoán sai thì tên cũng sai.
4. **Ba đơn vị tiếng Việt đã chết.** `danhsovan.rb`, `netcatcuoi*`, `toiuuvan*`
   gọi hai method không tồn tại trong cả bản phát hành (§6.15) và đã có bản viết
   lại bên cạnh. Xoá chúng sẽ gỡ luôn 160 cái đuôi `_v1` và làm `KNOWN_MISSING`
   rỗng — nhưng **phải kiểm trong SketchUp trước**, vì chưa chắc chắn cái gì còn
   nạp chúng.

`--soat` nay **sạch**: không còn chỗ nào hai hex cùng một đợt mang một tên.
Cách đã làm, dùng lại được cho bản sau: đọc thân hàm cả hai bên; **đổi tên**
bên nào thân hàm nói ngược lại cái tên (trả boolean mà tên là danh từ, duyệt
vòng mà tên nói chuỗi hở, `.length` mà tên nói diện tích); **hạ xuống `vai:`**
khi cả hai bên đều hợp — khi đó cây giữ nguyên từ, chỉ lời khẳng định lùi lại.

Giới hạn thật sự, không đổi so với 2.1.5: **thay hết hex ≠ đúng hết.** Chỉ tên
có bằng chứng sống — chuỗi tác giả viết, khoá hash, tên thuộc tính, hàng xóm
chưa bị làm rối, bản 2.1.5 đã đọc — mới là *khôi phục*; phần còn lại là suy
luận. `--soat` bắt được **mâu thuẫn**, không bắt được **sai**.

---

## 9. Bắt đầu từ đâu

```powershell
$env:PYTHONIOENCODING = "utf-8"

# 1. Xem còn nợ gì, file nào nặng nhất
python tools/progress.py --todo

# 2. Đọc một file: chỉ in những method còn hex, kèm thân hàm
python tools/doc.py ksu_vn/method/giacong/pool.rb

# 3. Đọc một hex chưa rõ nghĩa
python tools/profile.py _abc12345     # tập method gọi lên nó -> kiểu dữ liệu
python tools/usage.py   _abc12345     # nó dùng ở đâu
python tools/trahex.py ksu_vn/a.rb 42 # tên ở dòng này vốn là hex nào

# 4. Viết tên vào tools/ten.yml, rồi:
python tools/datten.py --check        # tám rào
python tools/goxungdot.py --apply     # đánh số chỗ đụng phạm vi
python tools/datten.py --lam-lai      # dựng lại từ mốc rồi áp CẢ từ điển

# 5. Vòng kiểm bắt buộc, chạy ĐỦ CẢ SÁU
Get-ChildItem ksu_vn -Recurse -Filter *.rb | ForEach-Object { ruby -c $_.FullName }
python tools/kiemchuoi.py
python tools/verify_structure.py
python tools/codegraph.py . tools/graph.json
python tools/verify_graph.py
ruby tools/napthu.rb .
python tools/trahex.py --soat
```

Khi `datten.py --check` báo lỗi, **đừng gỡ rào**. Mỗi lỗi là một chỗ thật: hoặc
hai hex đang tranh một tên, hoặc một tên đụng định danh còn sót, hoặc — nặng
nhất — hai `def` sắp đè lên nhau trong một module. Đọc chỗ đó, tách tên theo
hàng xóm chưa bị làm rối (§6.6), hoặc cho hex vào `bo:` kèm lý do, hoặc để
`goxungdot.py` đánh số giúp.
