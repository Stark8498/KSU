require "zlib"
module KSU::Thongke::Xuat
  XML_HEAD = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>".freeze
  NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main".freeze
  NS_REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships".freeze
  NS_PKG = "http://schemas.openxmlformats.org/package/2006/relationships".freeze
  ST_HEAD = 1
  ST_SEC_TEXT = 2
  ST_SEC_NUM = 3
  ST_TEXT = 4
  ST_CENTER = 5
  ST_MONEY = 6
  CHI_PHI_HEAD = ["", "Loại", "Mô tả chi tiết", "Số lượng", "Đơn vị", "Hệ số", "Đơn giá", "Thành tiền"].freeze
  CHI_PHI_COLS = [5, 30, 26, 12, 10, 8, 14, 16].freeze
  CAU_KIEN_COLS = [6, 6, 30, 10, 10, 8, 16, 10, 10, 10].freeze
  def self.export_file(title, arr)
    name = title.to_s.gsub(/[\\\/:*?"<>|]/, "_")
    name = "thong_ke" if name.empty?
    path = UI.savepanel("Xuất thống kê", KSU.model_dir, name + ".xlsx")
    return false unless path
    path += ".xlsx" unless path.downcase.end_with?(".xlsx")
    sheets = [
      _a105a0f4(arr["chi_phi"] || {}),
      _31eafa5f(arr["cau_kien"] || {}),
    ]
    File.open(path, "wb") { |f| f.write(build_pdf(sheets)) }
    true
  rescue StandardError => ent
    UI.messagebox("Không xuất được file: " + ent.message)
    false
  end
  def self._beb63a90(str2)
    path = File.join(ENV["TEMP"], "ksu_thong_ke.png")
    File.open(path, "wb") { |f| f.write(str2.unpack("m")[0]) }
    str = "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; " \
            "$i = [System.Drawing.Image]::FromFile('#{path}'); [System.Windows.Forms.Clipboard]::SetImage($i); $i.Dispose()"
    wsh = WIN32OLE.new("WScript.Shell")
    wsh.Run("powershell -NoProfile -STA -WindowStyle Hidden -Command \"#{str}\"", 0, true)
  rescue StandardError => ent
    UI.messagebox("Không chụp được: " + ent.message)
  end
  def self.num(v)
    v.is_a?(Numeric) ? v : v.to_s
  end
  def self.build_cells(title, total, _c41450bb = nil)
    cells = [["", ST_HEAD], [title.to_s, ST_SEC_TEXT]]
    5.times { cells << ["", ST_SEC_TEXT] }
    cells << [num(total), ST_SEC_NUM, _c41450bb]
    cells
  end
  def self._a105a0f4(cls2)
    rows = [{ cells: CHI_PHI_HEAD.map { |h| [h, ST_HEAD] } }]
    arr2 = []
    (cls2["sections"] || []).each do |arr3|
      num11 = rows.size + 1
      arr2 << "H#{num11}"
      items = arr3["items"] || []
      _a925e834 = num11 + 1
      num2 = items.empty? ? nil : "SUM(H#{_a925e834}:H#{num11 + items.size})"
      rows << { cells: build_cells(arr3["title"], arr3["tong"], num2) }
      items.each_with_index do |arr, i|
        half = _a925e834 + i
        lines = arr["mota"].to_s
        rows << {
          cells: [
            [i + 1, ST_CENTER], [arr["loai"].to_s, ST_TEXT], [lines, ST_TEXT],
            [num(arr["sl"]), ST_CENTER], [arr["dv"].to_s, ST_CENTER], [num(arr["he_so"]), ST_CENTER],
            [num(arr["gia"]), ST_MONEY], [num(arr["tien"]), ST_MONEY, "D#{half}*F#{half}*G#{half}"],
          ],
          lines: lines.count("\n") + 1,
        }
      end
    end
    total = arr2.empty? ? nil : "SUM(#{arr2.join(",")})"
    rows << { cells: build_cells("Tổng chi phí", cls2["tong"], total) }
    { name: "Chi phí", cols: CHI_PHI_COLS, rows: rows }
  end
  def self._31eafa5f(arr)
    cells = arr["headers"] || []
    _5ffa637f = cells.index("Tên")
    rows = [{ cells: cells.map { |h| [h.to_s, ST_HEAD] } }]
    (arr["rows"] || []).each do |arr2|
      rows << {
        cells: arr2.each_with_index.map { |v, color| [num(v), color == _5ffa637f ? ST_TEXT : ST_CENTER] },
      }
    end
    { name: "Cấu kiện", cols: CAU_KIEN_COLS, rows: rows }
  end
  def self._c9faf4c6(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
  end
  def self._20ca4ec8(idx)
    name = ""
    i = idx
    loop do
      name = ((i % 26) + 65).chr + name
      i = i / 26 - 1
      break if i < 0
    end
    name
  end
  def self._ec5d6377(pt, value, _e7b2b17b, _c41450bb = nil)
    if _c41450bb
      partner = value.is_a?(Numeric) ? value : 0
      return "<c r=\"#{pt}\" s=\"#{_e7b2b17b}\"><f>#{_c9faf4c6(_c41450bb)}</f><v>#{partner}</v></c>"
    end
    return "<c r=\"#{pt}\" s=\"#{_e7b2b17b}\"><v>#{value}</v></c>" if value.is_a?(Numeric)
    text = value.to_s
    return "<c r=\"#{pt}\" s=\"#{_e7b2b17b}\"/>" if text.empty?
    "<c r=\"#{pt}\" s=\"#{_e7b2b17b}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">#{_c9faf4c6(text)}</t></is></c>"
  end
  def self._278dd154(arr)
    out = arr.each_with_index.map { |w, i|
      "<col min=\"#{i + 1}\" max=\"#{i + 1}\" width=\"#{w}\" customWidth=\"1\"/>"
    }.join
    "<cols>#{out}</cols>"
  end
  def self._4ae1e5d9(sheet)
    _bd6ab6e1 = XML_HEAD + "<worksheet xmlns=\"#{NS_MAIN}\">"
    _bd6ab6e1 += "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
    _bd6ab6e1 += _278dd154(sheet[:cols])
    _bd6ab6e1 += "<sheetData>"
    sheet[:rows].each_with_index do |arr, half|
      count_by_length = arr[:lines] || 1
      attr = count_by_length > 1 ? " ht=\"#{count_by_length * 15}\" customHeight=\"1\"" : ""
      _bd6ab6e1 += "<row r=\"#{half + 1}\"#{attr}>"
      arr[:cells].each_with_index do |(value, _e7b2b17b, _c41450bb), color|
        _bd6ab6e1 += _ec5d6377(_20ca4ec8(color) + (half + 1).to_s, value, _e7b2b17b, _c41450bb)
      end
      _bd6ab6e1 += "</row>"
    end
    _bd6ab6e1 + "</sheetData></worksheet>"
  end
  def self._46b90971(sheets)
    out = sheets.each_with_index.map { |sheet, i|
      "<sheet name=\"#{_c9faf4c6(sheet[:name])}\" sheetId=\"#{i + 1}\" r:id=\"rId#{i + 1}\"/>"
    }.join
    XML_HEAD + "<workbook xmlns=\"#{NS_MAIN}\" xmlns:r=\"#{NS_REL}\"><sheets>#{out}</sheets><calcPr fullCalcOnLoad=\"1\"/></workbook>"
  end
  def self._e4092e6c(sheets)
    out = sheets.each_with_index.map { |_part, i|
      "<Relationship Id=\"rId#{i + 1}\" Type=\"#{NS_REL}/worksheet\" Target=\"worksheets/sheet#{i + 1}.xml\"/>"
    }.join
    out += "<Relationship Id=\"rId#{sheets.size + 1}\" Type=\"#{NS_REL}/styles\" Target=\"styles.xml\"/>"
    XML_HEAD + "<Relationships xmlns=\"#{NS_PKG}\">#{out}</Relationships>"
  end
  def self._7fb3dc0f(sheets)
    out = sheets.each_with_index.map { |_part, i|
      "<Override PartName=\"/xl/worksheets/sheet#{i + 1}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
    }.join
    XML_HEAD +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" \
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" \
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" \
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" \
    "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" \
    "#{out}</Types>"
  end
  def self.xf(fmt, font_full, fill, align, flag = false)
    flag2 = flag ? " wrapText=\"1\"" : ""
    "<xf numFmtId=\"#{fmt}\" fontId=\"#{font_full}\" fillId=\"#{fill}\" borderId=\"1\" xfId=\"0\"" \
    " applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\" applyAlignment=\"1\">" \
    "<alignment horizontal=\"#{align}\" vertical=\"center\"#{flag2}/></xf>"
  end
  def self._7144b643
    arr = [
      "<xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>",
      xf(0, 1, 2, "center"),
      xf(0, 1, 2, "left"),
      xf(3, 1, 2, "right"),
      xf(0, 0, 0, "left", true),
      xf(0, 0, 0, "center"),
      xf(3, 0, 0, "right"),
    ]
    axis = "<color rgb=\"FFBFBFBF\"/>"
    XML_HEAD +
    "<styleSheet xmlns=\"#{NS_MAIN}\">" \
    "<fonts count=\"2\"><font><sz val=\"10\"/><name val=\"Arial\"/></font>" \
    "<font><b/><sz val=\"10\"/><name val=\"Arial\"/></font></fonts>" \
    "<fills count=\"3\"><fill><patternFill patternType=\"none\"/></fill>" \
    "<fill><patternFill patternType=\"gray125\"/></fill>" \
    "<fill><patternFill patternType=\"solid\"><fgColor rgb=\"FFE0E0E0\"/><bgColor indexed=\"64\"/></patternFill></fill></fills>" \
    "<borders count=\"2\"><border/>" \
    "<border><left style=\"thin\">#{axis}</left><right style=\"thin\">#{axis}</right>" \
    "<top style=\"thin\">#{axis}</top><bottom style=\"thin\">#{axis}</bottom></border></borders>" \
    "<cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs>" \
    "<cellXfs count=\"#{arr.size}\">#{arr.join}</cellXfs>" \
    "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>" \
    "</styleSheet>"
  end
  def self._8e83909c
    XML_HEAD +
    "<Relationships xmlns=\"#{NS_PKG}\">" \
    "<Relationship Id=\"rId1\" Type=\"#{NS_REL}/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
  end
  def self.build_pdf(sheets)
    arr = []
    arr << ["[Content_Types].xml", _7fb3dc0f(sheets)]
    arr << ["_rels/.rels", _8e83909c]
    arr << ["xl/workbook.xml", _46b90971(sheets)]
    arr << ["xl/_rels/workbook.xml.rels", _e4092e6c(sheets)]
    arr << ["xl/styles.xml", _7144b643]
    sheets.each_with_index { |sheet, i| arr << ["xl/worksheets/sheet#{i + 1}.xml", _4ae1e5d9(sheet)] }
    _713c8e2b(arr)
  end
  def self._e8a07557
    at = Time.now
    _07eaaf5b = (at.hour << 11) | (at.min << 5) | (at.sec / 2)
    _93f68fd8 = ((at.year - 1980) << 9) | (at.month << 5) | at.day
    [_07eaaf5b, _93f68fd8]
  end
  def self._713c8e2b(arr)
    _07eaaf5b, _93f68fd8 = _e8a07557
    out = "".b
    str = "".b
    arr.each do |name, txt3|
      data = txt3.to_s.b
      _46300933 = name.b
      _c39cdbeb = Zlib.crc32(data)
      _8a2a0205 = out.bytesize
      out << ["PK\u0003\u0004", 20, 0x0800, 0, _07eaaf5b, _93f68fd8, _c39cdbeb, data.bytesize, data.bytesize, _46300933.bytesize, 0].pack("a4vvvvvVVVvv")
      out << _46300933
      out << data
      str << ["PK\u0001\u0002", 20, 20, 0x0800, 0, _07eaaf5b, _93f68fd8, _c39cdbeb, data.bytesize, data.bytesize, _46300933.bytesize, 0, 0, 0, 0, 0, _8a2a0205].pack("a4vvvvvvVVVvvvvvVV")
      str << _46300933
    end
    start = out.bytesize
    out << str
    out << ["PK\u0005\u0006", 0, 0, arr.size, arr.size, str.bytesize, start, 0].pack("a4vvvvVVv")
    out
  end
end
