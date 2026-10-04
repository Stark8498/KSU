# HANDOFF — Giải mã và đặt lại tên: cây KSU

Tài liệu chuyển giao cho người tiếp nhận **việc dịch ngược KSU**: mở chuỗi, lấy
lại tên cho những định danh bị trình bảo vệ xoá, và bộ phép kiểm đi kèm.

| | |
|---|---|
| **Phạm vi** | Từ điển tên · bộ công cụ · phép kiểm · phần còn nợ |
| **Cây mã** | [ksu_vn/](ksu_vn/) — 88 file `.rb` + [ksu_vn.rb](ksu_vn.rb), 24.831 dòng |
| **Nguồn phát hành** | KSU **2.1.5**, 88 file `.rbx`; đã giải mã ở commit `c45104c` |
| **Trạng thái tên** | **2.478/3.768 định danh đã có tên (65,8 %)** — 39.096/45.108 lượt (86,7 %) |
| **Đo ngày** | 03/10/2026, bằng các lệnh in nguyên văn ở §7 |
| **Còn nợ** | 718 tên method, 419 biến cục bộ, 42 `@ivar` — xem §8 |

Việc này áp dụng lại phương pháp đã chạy xong trên cây chị em ZSU; bản gốc của
quy trình nằm ở `zsu_vn/zsu_vn_readable_plugin/HANDOFF-giai-hex.md`. File này
chỉ nói phần KSU, và nói rõ chỗ nào **khác** ZSU.

---

## 1. Hiện trạng — giải mã xong, đặt tên xong

Commit `c45104c` đã làm xong bước giải mã: 88 file `.rbx` → `.rb`, 3.012 chuỗi
mã hoá đã mở. Nên **không có bước giải mã nào phải chạy lại**, và trong repo này
không có `decrypt_rbx.py` / `make_readable.py` — hai script đó (có chứa khoá
dạng rõ) nằm bên cây ZSU.

Giải mã trả lại **mã chạy được**, không trả lại **mã đọc được**. Trình bảo vệ đã
đổi mọi định danh do tác giả đặt thành `_` + 8 ký tự hex, và xoá sạch chú thích.
Chú thích thì không lấy lại được; mọi chú thích trong cây hiện nay là do người
đọc mã viết thêm.

Ngoài ra, mỗi file giải mã mở đầu bằng một hằng `XSU_NOTICE`. **Đã gỡ ở cả 88
file** — để lại thì Ruby cảnh báo khởi tạo lại hằng một lần cho mỗi file khi cây
bắt đầu được nạp thật. `tools/kiemchuoi.py` và `tools/verify_structure.py` đều
bỏ dòng này ở cả hai vế khi đối chiếu, nên việc gỡ không làm hai phép kiểm lệch.

Đặt tên đã xong: **0 hex còn lại trong 88 file**, 3.768/3.768 định danh. Tài
liệu này giữ lại vì cách làm và các cạm bẫy vẫn đúng cho bất kỳ cây nào khác
cùng trình bảo vệ — và vì §8 ghi rõ cái đã *khôi phục* khác cái đã *suy ra*.

---

## 2. Tính chất then chốt — một hex ứng với đúng một tên gốc

Đã kiểm trên cây này: **3.768 hex, mọi hex dài đúng 9 ký tự, không hex nào là
tiền tố của hex khác.** Hệ quả:

- thay thế theo biên từ là **một-đối-một**, không thể bắt sai;
- vì hex ↔ tên gốc là 1:1, đổi tên nhất quán giữ nguyên đúng quan hệ che khuất
  (shadowing) của bản gốc, nên hành vi không đổi.

Đi kèm là một hệ quả **ngược** phải nhớ: vì trình làm rối ánh xạ *tên → hex*
trên toàn cây, mọi biến mà tác giả đặt cùng một tên đều thành cùng một hex. Nên
một hex như `_d14b3aa1` xuất hiện 542 lần ở 48 file với hàng chục vai trò khác
nhau — đó không phải lỗi đọc, mà vì bản gốc dùng đúng một tên ngắn cho tất cả.

Và hệ quả **thứ ba**, đắt nhất khi quên: ánh xạ *tên → hex* là một **hàm**,
nên **một tên toàn cục chỉ được ứng với đúng một hex**. Hai hex cùng mang một
tên nghĩa là ít nhất một bên đặt sai — mà **không một phép kiểm nào trong §5
thấy được**: cả hai lần đổi tên đều hợp lệ, cây vẫn nạp, chuỗi vẫn nguyên, chỉ
có người đọc bị đánh lừa. `python tools/trahex.py --soat` nghịch đảo từ điển và
chỉ thẳng ra những chỗ đó. Nó bắt được 114 chỗ ngay lần chạy đầu — trong đó
`begin_drag` bị hai method khác nhau cùng mang, và `instance` bị **bảy** hex.

Lưu ý: tên **theo phạm vi** thì ngược lại, cố tình cho một hex mang nhiều tên
(`_d14b3aa1` là `arr` ở thân hàm này, `pt` ở thân hàm kia) vì hex đó thật sự
giữ cả hai thứ. Phép soát chỉ xét tên toàn cục, tức tên tự nhận là **chữ tác
giả đã gõ**.

Rủi ro duy nhất là **xung đột phạm vi**: cây còn sót định danh chưa bị làm rối
(`view`, `y`, `pts`, `fld`, `slot`, `normal:`…), nên đổi một hex thành `pts`
đúng trong thân hàm đã có `pts` là gộp hai thứ khác nhau.
[tools/datten.py](tools/datten.py) chặn việc này trước khi ghi (§4).

---

## 3. Tên lấy ở đâu — thứ tự ưu tiên

Tên trong cây này **không phải tên gốc của tác giả** trừ nhóm (2) và (3) dưới
đây; phần còn lại là tên tự đặt. Thứ tự ưu tiên, cao xuống thấp:

### 3.1. Chuỗi tác giả tự viết ra — **tên gốc thật**

Nguồn chính của [tools/ten.yml](tools/ten.yml) (257 mục; 312 mục còn lại của từ
điển đến từ §3.3).

Trình bảo vệ đổi được định danh, nhưng **không đổi được chuỗi**. Mà mã này tự
gọi tên biến của nó trong chuỗi, ngay cạnh chỗ dùng:

```ruby
_506bc226 = h[:bbox]                       # khoá hash là chuỗi, không phải định danh
{ size: _7a6f113f, font: _71305579 }       # nhãn hash cũng vậy
_a952a0af = inst.get_attribute("KSU", "phan")
instance_variable_defined?("@label_section_hidden")
```

[tools/motten.py](tools/motten.py) khai thác bốn mạch này (khoá hash, nhãn hash,
`get_attribute`, `fetch`/`dig`). Mỗi chỗ là một phiếu; chỉ nhận khi **mọi phiếu
nhất trí**, hoặc phiếu đầu **trội ≥ 4 lần** phiếu nhì — `x` thắng 42/1/1/2 là
một nghĩa viết lỏng, còn 2 phiếu chọi 1 là hai nghĩa thật và phải để nguyên hex.

### 3.2. Tên bị bỏ sót vì trùng API — **tên gốc thật**

Trình làm rối bỏ qua định danh trùng tên API Ruby/SketchUp, và **chính chỗ nó bỏ
sót lại khoá cứng tên của hex bên cạnh**:

- `def _1234abcd(view, _c2148d5e, y)` — 48 chữ ký có dạng này. Hex kẹp giữa
  `view` và `y` là `x`. Không đoán: hàng xóm của nó khai ra.
- Thư viện native `ksu.so` ([ksu_vn/clibs.rb](ksu_vn/clibs.rb)) khai method
  **theo tên**, nên tên của chúng không thể bị làm rối. Tám tên này là nguyên
  văn của tác giả: `convex_hull`, `polygons_overlap?`, `pack_bl`, `nfp`,
  `nfp_snap`, `inflate`, `contact_refine`, `build_loops`. Chúng được khai trong
  `NATIVE_METHODS` của [tools/verify_graph.py](tools/verify_graph.py) — không có
  `def` nào trong cây, nên nếu không khai thì bị báo nhầm là lời gọi treo.

### 3.3. Bản sinh đôi ZSU · 312 tên còn hiệu lực

KSU và ZSU cùng một tác giả và **dùng chung một lớp tiện ích**:
`utils/const.rb`, `utils/preset/*`, `utils/other.rb`, `utils/isolate.rb`,
`utils/chuanhoa.rb`, `system/setting.rb`, `main.rb`. ZSU đã đọc xong
3.542 tên, nên chỗ nào KSU còn khớp từng dòng với ZSU thì chuyển tên sang được.

[tools/sinhdoi.py](tools/sinhdoi.py) làm việc này: che chuỗi + chú thích, thay
mọi định danh bằng một dấu, để `difflib` ghép hai danh sách dòng, **chỉ nhận
khối `equal`**, và chỉ nhận cặp dòng nếu **mọi token không phải hex đọc giống
hệt nhau**.

> **Khác ZSU, phải biết:** hai cây dùng hằng module khác nhau (`ZSU` ↔ `KSU`).
> Không chuẩn hoá thì mọi lời gọi có định danh namespace đều đọc là khác nhau và
> khung mã **không bao giờ ghép được**. `sinhdoi.py` đổi `ZSU` → `KSU` ở vế ZSU
> trước khi so.

Mức thu được thấp hơn ZSU nhiều: **16 cặp sinh đôi, 321 hex** (5 bị `ten.yml`
ghi đè, 4 bị bác) — KSU chủ yếu là
mã riêng (tối ưu sơ đồ cắt), ZSU là mã ghép nối. Đừng kỳ vọng nguồn này cho
thêm nhiều.

### 3.5. Suy theo kiểu dữ liệu, **theo từng thân hàm** · 1.091 tên

[tools/dexuat.py](tools/dexuat.py) đọc tập method được gọi lên từng hex **trong
từng thân hàm**, rồi đặt tên theo kiểu: `pt`, `vec`, `grp`, `face`, `ents`,
`bb`, `tr`, `mat`, `arr`, `h`, `num`, `str`, `flag`. Một tên như vậy khẳng định
đúng **một** điều — kiểu dữ liệu — và điều đó đo được, không phải đoán.

Phải theo thân hàm chứ không theo hex: trình làm rối ánh xạ *tên → hex* trên
toàn cây, nên `_d14b3aa1` là một Hash ở chỗ này, một Point ở chỗ kia và một
String ở chỗ thứ ba. [tools/datten.py](tools/datten.py) áp theo từng dòng, dựa
vào thân hàm mà dòng đó rơi vào.

> **Đã bỏ hẳn phép mượn bằng chứng từ method khác trong cùng file.** Nó trông
> như độ phủ cho không, nhưng nó phát biểu kiểu của hàm này thành sự thật về
> hàm kia: `_9a5525a8` là Array ở một method và `Sketchup::Material` ở method
> ngay dưới, và phép mượn gọi cái material đó là `arr`.

### 3.4. Đọc tay · 1.337 tên

Phần còn lại. Thứ tự tra: [tools/profile.py](tools/profile.py) xem tập method
được gọi lên hex (ra kiểu dữ liệu) → [tools/usage.py](tools/usage.py) xem nó
dùng ở đâu → [tools/showdef.py](tools/showdef.py) đọc thân hàm. Không đủ căn cứ
thì **để nguyên hex**. Năm tên trong từ điển đến từ đây: chúng là những chỗ
bản sinh đôi bỏ hai phiếu vào cùng một tên, phải đọc mới tách được.

---

## 4. Bộ công cụ

| Lệnh | Làm gì |
|---|---|
| `python tools/datten.py --check \| --dry-run \| --apply` | Áp cả bốn từ điển, có rào an toàn |
| `python tools/datten.py --lam-lai` | **Dựng lại từ mốc rồi áp lại cả từ điển** — dùng mỗi khi sửa một tên |
| `python tools/datten.py --retag CŨ MỚI` | Đổi một tên **đã áp** — che chuỗi sẵn, đừng tự viết regex |
| `python tools/motten.py [--min N] [--troi K] [-o f.yml]` | Mót tên từ chuỗi còn sót (§3.1–3.2) |
| `python tools/sinhdoi.py <cây-zsu-đã-đặt-tên>` | Chuyển tên từ bản sinh đôi ZSU (§3.3) |
| `python tools/soatham.py <cây-zsu>` | **Soát lại tên method của bản sinh đôi bằng THÂN HÀM** (§6.8) |
| `python tools/dexuat.py [--chac N] --write` | Đề xuất tên theo **kiểu dữ liệu**, theo từng thân hàm (§3.5) |
| `python tools/goxungdot.py --apply` | Gỡ xung đột phạm vi bằng cách đánh số, sinh `tenpv.yml` |
| `python tools/doc.py <file.rb>` | In **chỉ những method còn hex**, kèm thân hàm — để đọc |
| `python tools/trahex.py <file> <dòng>` | Tra ngược: tên đã áp ở đây vốn là hex nào (§6.9) |
| `python tools/trahex.py --tim <tên>` | Tra một tên trên **cả cây** — ghép theo vị trí, không ghép bằng mắt (§6.12) |
| `python tools/trahex.py --soat` | **Nghịch đảo từ điển: tên toàn cục nào đến từ hơn một hex** (§2, §6.13) |
| `python tools/progress.py [--todo]` | Đo tiến độ, liệt kê hex còn lại nhiều lượt nhất |
| `python tools/profile.py _abc12345` | Tập method gọi lên hex, chỗ gán, namespace → kiểu dữ liệu |
| `python tools/usage.py` · `showdef.py` · `classify.py` · `methods.py` | Tra ngữ cảnh một hex trước khi đặt tên |
| `python tools/kiemchuoi.py [rev]` | Mọi chuỗi + chú thích phải đọc y hệt mốc |
| `python tools/verify_structure.py [mốc]` | Chứng minh một lần sửa **chỉ đổi tên** |
| `python tools/codegraph.py . tools/graph.json` | Dựng lại đồ thị (bị `.gitignore`, phải dựng trước khi soi) |
| `python tools/verify_graph.py` | Mọi lời gọi phải phân giải về một `def` có thật |
| `ruby tools/napthu.rb .` | Nạp cả cây ngoài SketchUp bằng stub |

Nền chung là [tools/kscommon.py](tools/kscommon.py). Phần quan trọng nhất trong
đó là `text_spans()` — nó **đi bộ qua mã nguồn**, không dùng regex, để trả lời
"ký tự nào là chữ, ký tự nào là mã".

> **Vì sao không dùng regex ở đây.** Chuỗi Ruby chứa được `#{...}`, trong đó là
> mã, mà mã đó lại mở được chuỗi khác — `utils/pdf/svg.rb` viết đúng như vậy:
> `"#{i.zero? ? 'm' : 'l'}"`. Ghép dấu nháy theo mẫu sẽ đóng chuỗi ngoài ở dấu
> nháy trong, rồi báo đoạn mã ở giữa là "chữ bị đổi". Đó là **báo nhầm che mất
> báo thật**: bộ kiểm chuỗi từng báo 3 file sai như thế trong khi cả 3 đều lành.
> Phiên bản regex cũ còn ăn mất chữ Việt ở heredoc HTML của `method/caidat.rb`
> và `utils/preset/field.rb`.

### Ba rào an toàn trong `datten.py`

Mỗi rào có ở đây vì một lần đổi tên đã hỏng nếu thiếu nó:

1. **Tên phải là định danh Ruby hợp lệ và không phải từ khoá.** Một hex nhận tên
   `else` vẫn biên dịch được, `ruby -c` chỉ kêu một câu cảnh báo vô hại, trong
   khi luồng điều khiển đã bị viết lại.
2. **Không trùng định danh file đã có** — xét **theo từng thân hàm**, không theo
   cả file. Đây là chỗ khác ZSU: `view` là tham số của hàm này và `_c0b8bb8d` ở
   trong hàm khác thì **cùng một tên gốc**, không phải xung đột; xét cả file sẽ
   chặn oan một tên đúng.
3. **Tên method phải là một tên cho cả cây.** Định nghĩa nằm ở một file còn
   lời gọi ở file khác, nên đặt theo phạm vi là đổi một đầu và bỏ đầu kia treo.
   Rào này đọc danh sách `def` **từ mốc gốc**, vì khi tên đã áp thì hex không
   còn trên đĩa nữa và phép kiểm sẽ im lặng ngừng canh.
4. **Hex lặp lại trong một danh sách tham số phải giữ dấu `_` ở đầu.** Ruby chỉ
   cho phép tham số trùng tên khi tên bắt đầu bằng `_` — mà mọi hex đều thế.
   `method/xeptam/push.rb` có `{ |_part, _part, b| ... }`; bỏ gạch dưới là biến
   một file hợp lệ thành SyntaxError, và chỉ `ruby -c` bắt được, sau khi đã ghi.
5. **Hex nào còn là `@ivar` thì tên không được kết thúc bằng `?` hay `!`.**
   `def _x; @_x; end` là một hex vừa là method vừa là biến; `labelling?` hợp lệ
   cho method nhưng `@labelling? = false` là SyntaxError.
6. **Hai hex không được cùng tên trong một phạm vi.** Biến cục bộ xét theo thân
   hàm (tác giả dùng lại tên ngắn ở hàng chục hàm); `@biến` và tên method xét
   theo cả file, và phải để **`@x` khác `x`** — gộp chúng là mất định nghĩa hàm.

`ten.yml` có khoá `bo:` để **bác phiếu** của `sinhdoi.yml`. Cần nó vì
`sinhdoi.yml` là file sinh ra, chạy lại là ghi đè, nên lý do bác phải nằm ở file
viết tay. Dùng khi bản sinh đôi chỉ ghép được một phần file và trả về một tên
chung chung (`arr`, `num3`) đúng bên ZSU nhưng vô nghĩa ở đây.

---

## 5. Vòng kiểm sau mỗi lần đổi tên — và chỗ mù của từng phép

Không phép nào đủ một mình. Chúng mù ở những chỗ khác nhau.

| Phép | Bắt được | **Không** bắt được |
|---|---|---|
| `ruby -c` từng file | Cú pháp vỡ | Hex nhận tên `else`; **chuỗi bị hỏng** |
| `kiemchuoi.py` | Chuỗi và chú thích bị đổi dù một ký tự | Đổi cấu trúc; tên sai nghĩa |
| `verify_structure.py` | Thay đổi cấu trúc ngoài việc đổi tên | Tên sai nghĩa |
| `verify_graph.py` | Lời gọi treo: tên lệch ở chỗ định nghĩa mà không lệch ở chỗ gọi | Tên đúng chính tả nhưng sai nghĩa |
| `ruby tools/napthu.rb .` | Lỗi **lúc nạp**: module lồng vào chỗ trống, thứ tự nạp sai | Hành vi — nó không gọi hàm nào |
| `trahex.py --soat` | Hai hex cùng mang một tên toàn cục | Tên chỉ có một hex nhưng sai nghĩa |

Đã **thử phá có chủ ý** để chứng minh chúng cắn thật, và bù nhau:

- thêm một ký tự vào một chuỗi → `kiemchuoi` bắt, còn **`ruby -c` vẫn báo
  Syntax OK**;
- chèn một dòng `return if false` mà không đụng chuỗi nào → `verify_structure`
  bắt, còn **`kiemchuoi` vẫn báo 0/89 sạch**.

`verify_graph.py` đọc **ảnh chụp** `tools/graph.json`, không đọc cây. Ảnh chụp
cũ làm nó **báo xanh nhầm**: tên def cũ vẫn còn trong ảnh, khớp với chỗ gọi cũ,
và chỗ vỡ bị che. Nay nó từ chối chạy khi ảnh cũ hơn mã nguồn — nhưng vẫn phải
nhớ dựng lại trước khi kiểm:

```bash
python tools/codegraph.py . tools/graph.json
```

### Lời gọi động — lớp rủi ro duy nhất không phép kiểm nào nhìn thấy, và đã đóng

Đổi tên một method mà chỗ gọi nằm trong **chuỗi** thì không phép kiểm nào bắt:
`verify_graph` chỉ soi lời gọi viết bằng mã, còn `kiemchuoi` thì *bảo đảm* chuỗi
không đổi — tức là bảo đảm chỗ gọi vẫn trỏ vào cái tên cũ đã biến mất. Đã soi cả
cây mốc:

- **không có** `send` / `__send__` / `public_send`, `define_method`, `method(:x)`,
  `method_missing` — không chỗ nào cả;
- `respond_to?(:_bbaa2919)` và `instance_variable_set(:@flag16, nil)` dùng
  **symbol**, mà symbol là mã chứ không phải chuỗi, nên nó đổi tên cùng lúc với
  chỗ định nghĩa;
- `instance_variable_get("@#{key}")` (preset/field.rb, preset/store.rb,
  font.rb) dựng tên biến từ chuỗi lúc chạy — nhưng **không một chuỗi nào trong
  cây chứa hex** (đếm được: 0). Nên nó chỉ có thể trỏ tới những `@ivar` mà
  trình làm rối **chưa bao giờ** đụng tới: `@tam_cach_le…`, `@them_tam_tu_do`,
  `@ghi_de_tam_cu` — kiểm lại trong mốc, chúng vốn đã không phải hex.

Kiểm lại khi nghi ngờ:

```bash
python -c "import sys;sys.path.insert(0,'tools');import re;from kscommon import literals;from datten import baseline_sources;print(sum(len(re.findall(r'_[0-9a-f]{8}',t)) for s in baseline_sources().values() for t in literals(s)))"
```

**Nạp được không có nghĩa là chạy đúng.** Chốt cuối vẫn là thử trong SketchUp
thật — chưa làm.

---

## 6. Cạm bẫy — đã dính thật trong đợt này

1. **Ranh giới từ của regex ăn vào chữ tiếng Việt.** `\b` tính theo
   `[A-Za-z0-9_]`, nguyên âm tiếng Việt nằm ngoài. Đổi hex thì an toàn (hex dài
   9 ký tự, không lẫn vào chữ được), nhưng đổi một tên **đã áp** thì không —
   luôn dùng `datten.py --retag`, nó che chuỗi trước khi khớp.
2. **Chuỗi nội suy lồng nhau và heredoc HTML** — xem khung ở §4.
3. **YAML nuốt tên.** Một nhãn hash tên `true` vào `ten.yml` thì PyYAML đọc ra
   `True` của Python, không phải chuỗi. Rào 1 bắt được, nhưng phải hiểu vì sao.
4. **Thừa `\` trong heredoc của shell.** Viết file Python bằng `cat <<'EOF'` ở
   môi trường này làm **mất một dấu `\` trong mỗi cặp `\\`**: `[^/\\\n]` thành
   `[^/\\n]`. Regex sinh ra vừa sai vừa backtracking vô hạn — `code_only` treo
   hơn 120 giây trên một file. Viết file Python bằng công cụ ghi file, đừng dùng
   heredoc.
5. **Tên phải đọc từ CÁCH DÙNG, không theo nhãn một chỗ.** `_a4286a6a` nhận
   phiếu `cells` vì có chỗ viết `{ cells: _a4286a6a(...) }` — nhưng đọc ra thì
   nó là **hàm dựng** mảng cells, không phải mảng đó. Đặt `build_cells`.
6. **Hàng xóm chưa bị làm rối là căn cứ tốt nhất để tách hai hex cùng nhãn.**
   `_df68e3b4` lấy từ `fld[:bbox]` mà `fld` còn nguyên tên → `fld_bbox`, tách
   khỏi `_506bc226` = `bbox`. Tương tự `slot[:panel]` → `slot_panel`.
7. **Bản sinh đôi chuyển sang cả những tên ZSU TỰ SINH.** 70/321 tên đầu tiên
   là tên kiểu dữ liệu (`num`, `arr`, `str`…) mà ZSU tự đặt — đó là phỏng đoán
   về mã ZSU, phát biểu thành sự thật về cây này, và có khi sai hẳn:
   `_1f153aeb` sang đây mang tên `num` trong khi nó giữ `"file:///..."`.
   [tools/sinhdoi.py](tools/sinhdoi.py) nay lọc bỏ chúng; `tools/dexuat.py`
   tính lại từ bằng chứng của chính cây này.
8. **Ghép theo dòng `def` là ghép nhầm.** `def _abc(x, y)` có khung giống hệt
   mọi `def` hai tham số khác trong file. [tools/soatham.py](tools/soatham.py)
   soát lại bằng **thân hàm**: 40/100 tên method của bản sinh đôi đáng ngờ, và
   đọc ra thì **sáu cái sai thật** — `_794ae95c` (chỉ gán nil ba biến nhớ) mang
   tên `load_style`, `_75700580` (dựng chữ ký) mang tên `in_front_of_camera?`,
   `_1b90e49c` (thư mục chứa file .skp) mang tên `selected`, `_ffc7cdd6` (bộ
   đếm giờ nháy con trỏ) mang tên `gap`.
9. **Tên đã áp thì không sửa thẳng được.** `num2` từng được giao cho bốn hex
   khác nhau, nên `--retag` sẽ đổi cả bốn. Sửa trong từ điển rồi chạy
   `datten.py --lam-lai`; [tools/trahex.py](tools/trahex.py) cho biết tên ở
   một dòng vốn là hex nào.
10. **Mọi công cụ SINH tên phải đọc từ MỐC, không đọc cây làm việc.** Khi tên đã
    áp thì hex không còn trên đĩa: `sinhdoi.py` rơi từ 254 tên xuống 2,
    `dexuat.py` từ 1.249 xuống 29, và cả hai đều không báo lỗi gì.
11. **Một dòng bắt đầu bằng `/` là regex, không phải phép chia.** Luật "chỉ sau
    toán tử mới là regex" bỏ sót `def part_re; /-(?:part|#{x})\d+\z/; end`, và
    bộ kiểm chuỗi báo nhầm một chuỗi bị đổi.
12. **Ghép tên đã áp với hex bằng mắt là ghép sai.** Một dòng thường có vài
    định danh; lấy hex *đầu tiên* trên dòng là gán tên cho ông hàng xóm. Đã
    dính: `_f3b19fae` nhận tên `drag_offset` trong khi nó là một `Point3d`,
    còn vector cộng dồn thật là `_9f104630`. Dùng `trahex.py`, nó ghép theo
    **vị trí**: `--tim <ten>` tra một tên trên cả cây, `<file> <dòng>` tra một
    dòng.
13. **Một tên toàn cục mà hai hex cùng mang là lỗi, và không phép kiểm nào
    thấy.** Xem §2. Chạy `trahex.py --soat` sau mỗi đợt đặt tên. Còn nợ 100
    chỗ, đều là biến cục bộ tên ngắn (`a`, `x`, `y1`, `pt`, `bbox`…); phần tên
    method và `@ivar` đã dọn sạch.
14. **Thà để trống còn hơn đoán.** Một tên sai tệ hơn một hex: hex nói "chưa
    biết", tên sai nói dối.

---

## 7. Hiện trạng — đo 04/10/2026: **xong**

| Phép | Lệnh | Kết quả |
|---|---|---|
| Tên định danh | `python tools/progress.py` | **3.768/3.768 = 100 %** |
| — tên method | nt | 1.475/1.475 = 100 % |
| — biến thực thể `@` | nt | 320/320 = 100 % |
| — biến cục bộ / tham số | nt | 1.821/1.821 = 100 % |
| Lượt xuất hiện | nt | **45.108/45.108 = 100 %** |
| File còn hex | | **0/88** |
| Tên toàn cục trùng hex | `python tools/trahex.py --soat` | **0** trên 2.500 tên |
| Danh sách `bo:` | | **0** — mọi mục từng phải bỏ đều đã giải |
| Cú pháp | `ruby -c` từng file | **88/88 OK** |
| Chuỗi/chú thích | `python tools/kiemchuoi.py` | **0/89 file bị đổi** |
| Chỉ đổi tên | `python tools/verify_structure.py` | **0/89 file khác mốc `c45104c`** |
| Lời gọi treo | `codegraph.py` rồi `verify_graph.py` | **0** |
| Nạp cả cây | `ruby tools/napthu.rb .` | **NAP OK** — 62/62 module, 73 hằng `KSU::*` |
| Nạp trong SketchUp | `tools/thu_su.rb` | 73/73 module, **464/464 lời gọi phân giải được** |
| Đối sánh hành vi | `tools/doisanh.rb` | **30/30 trùng khớp** bản đang chạy |

Nguồn của 3.768 tên:

| Từ điển | Toàn cục | Theo phạm vi | Nguồn |
|---|---:|---:|---|
| `ten.yml` → `ten:` | 2.221 | 551 | đọc tay + chuỗi còn sót (§3.1–3.2, §3.4) |
| `ten.yml` → `vai:` | — | 128 | tên theo VAI, không phải từ tác giả gõ |
| `tenauto.yml` | 200 | 3.056 | suy theo kiểu dữ liệu, theo thân hàm (§3.5) |
| `sinhdoi.yml` | 254 | — | bản sinh đôi ZSU, đã lọc (§3.3) |
| `tenpv.yml` | — | 66 | gỡ đụng độ trong cùng thân hàm, do `goxungdot.py` sinh |

Chạy mọi lệnh Python với `PYTHONIOENCODING=utf-8`: console cp1252 của Windows
ném `UnicodeEncodeError` ngay khi gặp chữ Việt.

---

## 8. Còn nợ — và cái không còn là nợ

Không còn hex nào trong cây, và không còn tên toàn cục nào ứng với hai hex.

Cái còn lại không phải là "thiếu tên" mà là **mức khẳng định**. `ten.yml` tách
làm hai phần:

- `ten:` nói **tác giả gõ từ này**. Phép soát một-tên-một-hex chỉ xét phần này,
  vì obfuscator ánh xạ tên → hex một lần cho cả cây.
- `vai:` chỉ nói **biến giữ cái gì**. Một toạ độ đọc ra `x` từ phép toán là lời
  về nội dung, không phải về từ; hai hex đều có thể giữ một toạ độ.

Giới hạn thật sự: **thay hết hex ≠ đúng hết**. Chỉ tên có bằng chứng sống —
chuỗi tác giả viết, khoá hash, tên thuộc tính `ABF`/`KSU`, cây sinh đôi ZSU —
mới là *khôi phục*; phần còn lại là suy luận. `--soat` bắt được **mâu thuẫn**,
không bắt được **sai**. Một tên sai mà không trùng ai thì không lớp nào thấy.

Việc còn làm được, nếu muốn chắc hơn:

1. Mở rộng `tools/doisanh.rb` quá 30 trường hợp — mỗi hàm thuần thêm vào là một
   mệnh đề nữa được kiểm thật, thay vì chỉ được lập luận.
2. Soát lại bằng mắt các mục `tenauto.yml` (3.056 mục theo phạm vi): chúng chỉ
   khẳng định kiểu dữ liệu, nhưng kiểu đoán sai thì tên cũng sai.
3. Chạy plugin trong SketchUp với mô hình thật và so kết quả xuất (DXF, XLSX,
   PDF) với bản gốc — lớp duy nhất chưa dựng.

## 9. Bắt đầu từ đâu

```powershell
$env:PYTHONIOENCODING = "utf-8"

# 1. Xem còn nợ gì, file nào nặng nhất
python tools/progress.py --todo

# 2. Doc mot file: chi in nhung method con hex, kem than ham
python tools/doc.py ksu_vn/method/xeptam/drag.rb

# 3. Đọc một hex chưa rõ nghĩa
python tools/profile.py _abc12345     # tập method gọi lên nó -> kiểu dữ liệu
python tools/usage.py   _abc12345     # nó dùng ở đâu
python tools/showdef.py _abc12345     # thân hàm
python tools/trahex.py ksu_vn/a.rb 42 # tên ở dòng này vốn là hex nào

# 4. Viết tên vào tools/ten.yml, rồi:
python tools/datten.py --check        # rào an toàn
python tools/goxungdot.py --apply     # đánh số chỗ đụng phạm vi
python tools/datten.py --lam-lai      # dựng lại từ mốc rồi áp CẢ từ điển

# 5. Vòng kiểm bắt buộc, chạy ĐỦ CẢ SÁU
Get-ChildItem ksu_vn -Recurse -Filter *.rb | ForEach-Object { ruby -c $_.FullName }
python tools/kiemchuoi.py
python tools/verify_structure.py
python tools/codegraph.py . tools/graph.json
python tools/verify_graph.py
ruby tools/napthu.rb .
python tools/trahex.py --soat         # tên toàn cục nào đến từ hơn một hex
```

Khi `datten.py --check` báo lỗi, **đừng gỡ rào**. Mỗi lỗi là một chỗ thật: hoặc
hai hex đang tranh một tên, hoặc một tên đụng định danh còn sót. Đọc chỗ đó, đặt
tên tách ra theo hàng xóm chưa bị làm rối (§6.6), hoặc cho hex vào `bo:` kèm lý
do, hoặc để `goxungdot.py` đánh số giúp.
