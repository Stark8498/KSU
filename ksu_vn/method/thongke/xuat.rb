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
  def self.export_file_v1(title, arr)
    name = title.to_s.gsub(/[\\\/:*?"<>|]/, "_")
    name = "thong_ke" if name.empty?
    path = UI.savepanel("Xuất thống kê", KSU.model_dir, name + ".xlsx")
    return false unless path
    path += ".xlsx" unless path.downcase.end_with?(".xlsx")
    sheets = [
      cost_sheet_v1(arr["chi_phi"] || {}),
      parts_sheet_v1(arr["cau_kien"] || {}),
    ]
    File.open(path, "wb") { |f| f.write(build_doc_v1(sheets)) }
    true
  rescue StandardError => ent
    UI.messagebox("Không xuất được file: " + ent.message)
    false
  end
  def self.copy_image_v1(str2)
    path = File.join(ENV["TEMP"], "ksu_thong_ke.png")
    File.open(path, "wb") { |f| f.write(str2.unpack("m")[0]) }
    str = "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; " \
            "$i = [System.Drawing.Image]::FromFile('#{path}'); [System.Windows.Forms.Clipboard]::SetImage($i); $i.Dispose()"
    wsh = WIN32OLE.new("WScript.Shell")
    wsh.Run("powershell -NoProfile -STA -WindowStyle Hidden -Command \"#{str}\"", 0, true)
  rescue StandardError => ent
    UI.messagebox("Không chụp được: " + ent.message)
  end
  def self.num_v1(v)
    v.is_a?(Numeric) ? v : v.to_s
  end
  def self.build_cells(title, total, formula = nil)
    cells = [["", ST_HEAD], [title.to_s, ST_SEC_TEXT]]
    5.times { cells << ["", ST_SEC_TEXT] }
    cells << [num_v1(total), ST_SEC_NUM, formula]
    cells
  end
  def self.cost_sheet_v1(cls2)
    rows = [{ cells: CHI_PHI_HEAD.map { |h| [h, ST_HEAD] } }]
    arr2 = []
    (cls2["sections"] || []).each do |arr3|
      num2 = rows.size + 1
      arr2 << "H#{num2}"
      items = arr3["items"] || []
      row0 = num2 + 1
      formula = items.empty? ? nil : "SUM(H#{row0}:H#{num2 + items.size})"
      rows << { cells: build_cells(arr3["title"], arr3["tong"], formula) }
      items.each_with_index do |arr, i|
        half = row0 + i
        lines = arr["mota"].to_s
        rows << {
          cells: [
            [i + 1, ST_CENTER], [arr["loai"].to_s, ST_TEXT], [lines, ST_TEXT],
            [num_v1(arr["sl"]), ST_CENTER], [arr["dv"].to_s, ST_CENTER], [num_v1(arr["he_so"]), ST_CENTER],
            [num_v1(arr["gia"]), ST_MONEY], [num_v1(arr["tien"]), ST_MONEY, "D#{half}*F#{half}*G#{half}"],
          ],
          lines: lines.count("\n") + 1,
        }
      end
    end
    total = arr2.empty? ? nil : "SUM(#{arr2.join(",")})"
    rows << { cells: build_cells("Tổng chi phí", cls2["tong"], total) }
    { name: "Chi phí", cols: CHI_PHI_COLS, rows: rows }
  end
  def self.parts_sheet_v1(arr)
    cells = arr["headers"] || []
    name_col = cells.index("Tên")
    rows = [{ cells: cells.map { |h| [h.to_s, ST_HEAD] } }]
    (arr["rows"] || []).each do |arr2|
      rows << {
        cells: arr2.each_with_index.map { |v, color| [num_v1(v), color == name_col ? ST_TEXT : ST_CENTER] },
      }
    end
    { name: "Cấu kiện", cols: CAU_KIEN_COLS, rows: rows }
  end
  def self.xml_escape_v1(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
  end
  def self.col_name_v1(idx)
    name = ""
    i = idx
    loop do
      name = ((i % 26) + 65).chr + name
      i = i / 26 - 1
      break if i < 0
    end
    name
  end
  def self.cell_xml_v1(pt, value, style_ix, formula = nil)
    if formula
      partner = value.is_a?(Numeric) ? value : 0
      return "<c r=\"#{pt}\" s=\"#{style_ix}\"><f>#{xml_escape_v1(formula)}</f><v>#{partner}</v></c>"
    end
    return "<c r=\"#{pt}\" s=\"#{style_ix}\"><v>#{value}</v></c>" if value.is_a?(Numeric)
    text = value.to_s
    return "<c r=\"#{pt}\" s=\"#{style_ix}\"/>" if text.empty?
    "<c r=\"#{pt}\" s=\"#{style_ix}\" t=\"inlineStr\"><is><t xml:space=\"preserve\">#{xml_escape_v1(text)}</t></is></c>"
  end
  def self.cols_xml_v1(arr)
    arr2 = arr.each_with_index.map { |w, i|
      "<col min=\"#{i + 1}\" max=\"#{i + 1}\" width=\"#{w}\" customWidth=\"1\"/>"
    }.join
    "<cols>#{arr2}</cols>"
  end
  def self.sheet_xml_v1(sheet)
    xml = XML_HEAD + "<worksheet xmlns=\"#{NS_MAIN}\">"
    xml += "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
    xml += cols_xml_v1(sheet[:cols])
    xml += "<sheetData>"
    sheet[:rows].each_with_index do |arr, half|
      count_by_length = arr[:lines] || 1
      attr = count_by_length > 1 ? " ht=\"#{count_by_length * 15}\" customHeight=\"1\"" : ""
      xml += "<row r=\"#{half + 1}\"#{attr}>"
      arr[:cells].each_with_index do |(value, style_ix, formula), color|
        xml += cell_xml_v1(col_name_v1(color) + (half + 1).to_s, value, style_ix, formula)
      end
      xml += "</row>"
    end
    xml + "</sheetData></worksheet>"
  end
  def self.workbook_xml_v1(sheets)
    arr = sheets.each_with_index.map { |sheet, i|
      "<sheet name=\"#{xml_escape_v1(sheet[:name])}\" sheetId=\"#{i + 1}\" r:id=\"rId#{i + 1}\"/>"
    }.join
    XML_HEAD + "<workbook xmlns=\"#{NS_MAIN}\" xmlns:r=\"#{NS_REL}\"><sheets>#{arr}</sheets><calcPr fullCalcOnLoad=\"1\"/></workbook>"
  end
  def self.rels_xml_v1(sheets)
    arr = sheets.each_with_index.map { |_part, i|
      "<Relationship Id=\"rId#{i + 1}\" Type=\"#{NS_REL}/worksheet\" Target=\"worksheets/sheet#{i + 1}.xml\"/>"
    }.join
    arr += "<Relationship Id=\"rId#{sheets.size + 1}\" Type=\"#{NS_REL}/styles\" Target=\"styles.xml\"/>"
    XML_HEAD + "<Relationships xmlns=\"#{NS_PKG}\">#{arr}</Relationships>"
  end
  def self.content_types_xml(sheets)
    arr = sheets.each_with_index.map { |_part, i|
      "<Override PartName=\"/xl/worksheets/sheet#{i + 1}.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
    }.join
    XML_HEAD +
    "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" \
    "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" \
    "<Default Extension=\"xml\" ContentType=\"application/xml\"/>" \
    "<Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>" \
    "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>" \
    "#{arr}</Types>"
  end
  def self.xf(fmt, font_full, fill, align, flag2 = false)
    flag = flag2 ? " wrapText=\"1\"" : ""
    "<xf numFmtId=\"#{fmt}\" fontId=\"#{font_full}\" fillId=\"#{fill}\" borderId=\"1\" xfId=\"0\"" \
    " applyNumberFormat=\"1\" applyFont=\"1\" applyFill=\"1\" applyBorder=\"1\" applyAlignment=\"1\">" \
    "<alignment horizontal=\"#{align}\" vertical=\"center\"#{flag}/></xf>"
  end
  def self.styles_xml_v1
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
  def self.root_rels_xml
    XML_HEAD +
    "<Relationships xmlns=\"#{NS_PKG}\">" \
    "<Relationship Id=\"rId1\" Type=\"#{NS_REL}/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>"
  end
  def self.build_doc_v1(sheets)
    arr = []
    arr << ["[Content_Types].xml", content_types_xml(sheets)]
    arr << ["_rels/.rels", root_rels_xml]
    arr << ["xl/workbook.xml", workbook_xml_v1(sheets)]
    arr << ["xl/_rels/workbook.xml.rels", rels_xml_v1(sheets)]
    arr << ["xl/styles.xml", styles_xml_v1]
    sheets.each_with_index { |sheet, i| arr << ["xl/worksheets/sheet#{i + 1}.xml", sheet_xml_v1(sheet)] }
    write_zip(arr)
  end
  def self.dos_time
    at = Time.now
    dos_t = (at.hour << 11) | (at.min << 5) | (at.sec / 2)
    dos_d = ((at.year - 1980) << 9) | (at.month << 5) | at.day
    [dos_t, dos_d]
  end
  def self.write_zip(arr)
    dos_t, dos_d = dos_time
    out = "".b
    str = "".b
    arr.each do |name, txt3|
      data = txt3.to_s.b
      name_b = name.b
      crc = Zlib.crc32(data)
      isect_off = out.bytesize
      out << ["PK\u0003\u0004", 20, 0x0800, 0, dos_t, dos_d, crc, data.bytesize, data.bytesize, name_b.bytesize, 0].pack("a4vvvvvVVVvv")
      out << name_b
      out << data
      str << ["PK\u0001\u0002", 20, 20, 0x0800, 0, dos_t, dos_d, crc, data.bytesize, data.bytesize, name_b.bytesize, 0, 0, 0, 0, 0, isect_off].pack("a4vvvvvvVVVvvvvvVV")
      str << name_b
    end
    start = out.bytesize
    out << str
    out << ["PK\u0005\u0006", 0, 0, arr.size, arr.size, str.bytesize, start, 0].pack("a4vvvvVVv")
    out
  end
end
