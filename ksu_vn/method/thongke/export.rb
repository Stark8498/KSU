require "zlib"
module KSU::Thongke::Xuat
  XML_HEAD = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>".freeze
  NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main".freeze
  ST_HEAD = 1
  ST_TEXT = 4
  ST_CENTER = 5
  def self.export_file(title, arr)
    name = title.to_s.gsub(/[\\\/:*?"<>|]/, "_").then { |n| n.empty? ? "thong_ke" : n }
    path = UI.savepanel("Xuất thống kê", KSU.model_dir, name + ".xlsx")
    return false unless path
    path += ".xlsx" unless path.downcase.end_with?(".xlsx")
    sheets = [cost_sheet(arr["chi_phi"] || {}), parts_sheet(arr["cau_kien"] || {})]
    File.open(path, "wb") { |f| f.write(to_segments(sheets)) }
    true
  rescue StandardError => e
    UI.messagebox("Không xuất được file: " + e.message)
    false
  end
  def self.copy_image(str2)
    path = File.join(ENV["TEMP"], "ksu_thong_ke.png")
    File.binwrite(path, str2.unpack1("m"))
    str = "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; " \
            "$i = [System.Drawing.Image]::FromFile('#{path}'); [System.Windows.Forms.Clipboard]::SetImage($i); $i.Dispose()"
    WIN32OLE.new("WScript.Shell").Run("powershell -NoProfile -STA -WindowStyle Hidden -Command \"#{str}\"", 0, true)
  rescue StandardError => e
    UI.messagebox("Không chụp được: " + e.message)
  end
  def self.num(v)
    v.is_a?(Numeric) ? v : v.to_s
  end
  def self.cells(title, total, formula)
    [["", ST_HEAD], [title.to_s, 2], *Array.new(5) { ["", 2] }, [num(total), 3, formula]]
  end
  def self.cost_sheet(cls2)
    rows = [{ cells: ["", "Loại", "Mô tả chi tiết", "Số lượng", "Đơn vị", "Hệ số", "Đơn giá", "Thành tiền"].map { |elem| [elem, ST_HEAD] } }]
    arr2 = []
    (cls2["sections"] || []).each do |arr3|
      num2 = rows.size + 1
      arr2 << "H#{num2}"
      items = arr3["items"] || []
      rows << { cells: cells(arr3["title"], arr3["tong"], items.empty? ? nil : "SUM(H#{num2 + 1}:H#{num2 + items.size})") }
      items.each_with_index do |arr, i|
        half = num2 + 1 + i
        lines = arr["mota"].to_s
        rows << { cells: [
          [i + 1, ST_CENTER], [arr["loai"].to_s, ST_TEXT], [lines, ST_TEXT],
          [num(arr["sl"]), ST_CENTER], [arr["dv"].to_s, ST_CENTER], [num(arr["he_so"]), ST_CENTER],
          [num(arr["gia"]), 6], [num(arr["tien"]), 6, "D#{half}*F#{half}*G#{half}"]
        ], lines: lines.count("\n") + 1 }
      end
    end
    rows << { cells: cells("Tổng chi phí", cls2["tong"], arr2.empty? ? nil : "SUM(#{arr2.join(",")})") }
    { name: "Chi phí", cols: [5, 30, 26, 12, 10, 8, 14, 16], rows: rows }
  end
  def self.parts_sheet(arr)
    cells = arr["headers"] || []
    name_col = cells.index("Tên")
    rows = [{ cells: cells.map { |elem| [elem.to_s, ST_HEAD] } }]
    (arr["rows"] || []).each do |arr2|
      rows << { cells: arr2.each_with_index.map { |v, c| [num(v), c == name_col ? ST_TEXT : ST_CENTER] } }
    end
    { name: "Cấu kiện", cols: [6, 6, 30, 10, 10, 8, 16, 10, 10, 10], rows: rows }
  end
  def self.xml_escape(text)
    text.to_s.gsub(/[&<>\x00-\x08\x0B\x0C\x0E-\x1F]/, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;")
  end
  def self.col_name(idx)
    ch = (idx % 26 + 65).chr
    idx < 26 ? ch : col_name(idx / 26 - 1) + ch
  end
  def self.cell_xml(entity_ref, str, style_ix, formula)
    head_off = "<c r=\"#{entity_ref}\" s=\"#{style_ix}\""
    return "#{head_off}><f>#{xml_escape(formula)}</f><v>#{str.is_a?(Numeric) ? str : 0}</v></c>" if formula
    return "#{head_off}><v>#{str}</v></c>" if str.is_a?(Numeric)
    return "#{head_off}/>" if str.to_s.empty?
    "#{head_off} t=\"inlineStr\"><is><t xml:space=\"preserve\">#{xml_escape(str)}</t></is></c>"
  end
  def self.cols_xml(arr2)
    _7cd9af62 = XML_HEAD + "<worksheet xmlns=\"#{NS_MAIN}\"><sheetViews><sheetView workbookViewId=\"0\">" \
      "<pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews><cols>"
    arr2[:cols].each.with_index(1) { |w, i| _7cd9af62 << "<col min=\"#{i}\" max=\"#{i}\" width=\"#{w}\" customWidth=\"1\"/>" }
    _7cd9af62 << "</cols><sheetData>"
    arr2[:rows].each.with_index(1) do |arr, half|
      _7cd9af62 << "<row r=\"#{half}\"#{arr[:lines].to_i > 1 ? " ht=\"#{arr[:lines] * 15}\" customHeight=\"1\"" : ""}>"
      arr[:cells].each_with_index do |(val, style_ix, formula), c|
        _7cd9af62 << cell_xml(col_name(c) + half.to_s, val, style_ix, formula)
      end
      _7cd9af62 << "</row>"
    end
    _7cd9af62 << "</sheetData></worksheet>"
  end
  def self.sheet_xml(sheets)
    entries = sheets.map.with_index(1) { |arr, i| "<sheet name=\"#{xml_escape(arr[:name])}\" sheetId=\"#{i}\" r:id=\"rId#{i}\"/>" }
    XML_HEAD + "<workbook xmlns=\"#{NS_MAIN}\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">" \
      "<sheets>#{entries.join}</sheets><calcPr fullCalcOnLoad=\"1\"/></workbook>"
  end
  def self.workbook_xml(entries)
    items = entries.map do |id, sheet_type, target|
      "<Relationship Id=\"rId#{id}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/#{sheet_type}\" Target=\"#{target}\"/>"
    end
    XML_HEAD + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">#{items.join}</Relationships>"
  end
  def self.rels_xml(arr)
    entries = arr.map do |i|
      "<Override PartName=\"/xl/worksheets/sheet#{i}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
    end
    XML_HEAD +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" \
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" \
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" \
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" \
    "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" \
    "#{entries.join}</Types>"
  end
  def self.styles_xml
    arr = [
      [0, 1, 2, "center"], [0, 1, 2, "left"], [3, 1, 2, "right"],
      [0, 0, 0, "left", " wrapText=\"1\""], [0, 0, 0, "center"], [3, 0, 0, "right"]
    ]
    arr2 = arr.map do |fmt, font_full, fill, align, _0d017c2d|
      "<xf numFmtId=\"#{fmt}\" fontId=\"#{font_full}\" fillId=\"#{fill}\" borderId=\"1\" xfId=\"0\"" \
      " applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\" applyAlignment=\"1\">" \
      "<alignment horizontal=\"#{align}\" vertical=\"center\"#{_0d017c2d}/></xf>"
    end
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
    "<cellXfs count=\"7\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\" xfId=\"0\"/>#{arr2.join}</cellXfs>" \
    "<cellStyles count=\"1\"><cellStyle name=\"Normal\" xfId=\"0\" builtinId=\"0\"/></cellStyles>" \
    "</styleSheet>"
  end
  def self.to_segments(sheets)
    num = 1..sheets.size
    arr = num.map { |i| [i, "worksheet", "worksheets/sheet#{i}.xml"] } << [num.size + 1, "styles", "styles.xml"]
    build_doc([
      ["[Content_Types].xml", rels_xml(num)],
      ["_rels/.rels", workbook_xml([[1, "officeDocument", "xl/workbook.xml"]])],
      ["xl/workbook.xml", sheet_xml(sheets)],
      ["xl/_rels/workbook.xml.rels", workbook_xml(arr)],
      ["xl/styles.xml", styles_xml]
    ] + sheets.map.with_index(1) { |sheet, i| ["xl/worksheets/sheet#{i}.xml", cols_xml(sheet)] })
  end
  def self.build_doc(arr)
    at = Time.now
    dos_t = (at.hour << 11) | (at.min << 5) | (at.sec / 2)
    dos_d = ((at.year - 1980) << 9) | (at.month << 5) | at.day
    out, str = "".b, "".b
    arr.each do |name, txt3|
      data, _eb89de03 = txt3.b, name.b
      head_off = [0x0800, 0, dos_t, dos_d, Zlib.crc32(data), data.bytesize, data.bytesize, _eb89de03.bytesize]
      str << ["PK\u0001\u0002", 20, 20, *head_off, 0, 0, 0, 0, 0, out.bytesize].pack("a4vvvvvvVVVvvvvvVV") << _eb89de03
      out << ["PK\u0003\u0004", 20, *head_off, 0].pack("a4vvvvvVVVvv") << _eb89de03 << data
    end
    out + str + ["PK\u0005\u0006", 0, 0, arr.size, arr.size, str.bytesize, out.bytesize, 0].pack("a4vvvvVVv")
  end
end
