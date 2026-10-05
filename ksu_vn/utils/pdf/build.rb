module KSU::Pdf
  module_function
  S = 72.0 / 25.4
  def to_segments(arr7, group_rgb, _73aefde1, _1bba0f00)
    arr3 = [["F1", _73aefde1, {}, "Arial"], ["F2", _1bba0f00, {}, "Arial-Bold"]]
    _f11ffc5b = ["q", ("0 -1 1 0 0 #{KSU::Svg.n(group_rgb[:w] * S, 100.0)} cm" if group_rgb[:rot]),
             "#{KSU::Svg.n(S, 100.0)} 0 0 #{KSU::Svg.n(-S, 100.0)} 0 #{KSU::Svg.n(group_rgb[:h] * S, 100.0)} cm"].compact
    used = {}
    arr5 = arr7.map { |svg_text| (_f11ffc5b + KSU::Svg.parse_svg(svg_text, arr3, used) + ["Q"]).join("\n") }
    arr = ["<< /Type /Catalog /Pages 2 0 R >>", nil]
    arr2 = used.map { |str, _65321c4e| "/#{_65321c4e} #{arr.push(cmap_stream(str.unpack1("m0"))).size} 0 R" }.join(" ")
    arr6 = "/Resources << /Font << #{arr3.map { |k, *f| "/#{k} #{font_object(arr, *f)} 0 R" }.join(" ")} >>" \
             "#{" /XObject << #{arr2} >>" unless arr2.empty?} >> /Contents "
    str2 = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{KSU::Svg.n(group_rgb[:pw] * S, 100.0)} #{KSU::Svg.n(group_rgb[:ph] * S, 100.0)}] #{arr6}"
    arr4 = arr5.map { |_2c999bab| arr.push(stream_object(_2c999bab), "#{str2}#{arr.size + 1} 0 R >>").size }
    arr[1] = "<< /Type /Pages /Kids [#{arr4.map { |k| "#{k} 0 R" }.join(" ")}] /Count #{arr4.size} >>"
    build_pdf(arr)
  end
  def font_object(arr, font_full, taken, name)
    entity_ref = arr.size + 1
    w = taken.keys.sort.map { |grp2| "#{grp2} [#{(KSU::Ttf.glyph_width(font_full, grp2).to_f * 1000 / font_full[:upm]).round}]" }.join(" ")
    upm, data = 1000.0 / font_full[:upm], font_full[:data]
    *box, _87c335b7, descent = %i[xmin ymin xmax ymax ascent descent].map { |k| (font_full[k] * upm).round }
    arr.push(
      "<< /Type /Font /Subtype /Type0 /BaseFont /#{name} /Encoding /Identity-H /DescendantFonts [#{entity_ref + 1} 0 R] /ToUnicode #{entity_ref + 4} 0 R >>",
      "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /#{name} /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> " \
      "/FontDescriptor #{entity_ref + 2} 0 R /CIDToGIDMap /Identity /DW 500 /W [#{w}] >>",
      "<< /Type /FontDescriptor /FontName /#{name} /Flags 4 /FontBBox [#{box.join(" ")}] /ItalicAngle 0 " \
      "/Ascent #{_87c335b7} /Descent #{descent} /CapHeight #{_87c335b7} /StemV 80 /FontFile2 #{entity_ref + 3} 0 R >>",
      stream_object(data, "/Length #{data.bytesize} /Length1 #{data.bytesize}"),
      stream_object("/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n" \
        "/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n" \
        "#{taken.size} beginbfchar\n#{taken.map { |grp2, cls2| "<#{format('%04X', grp2)}> <#{format("%04X", cls2)}>" }.join("\n")}\n" \
        "endbfchar\nendcmap\nCMapName currentdict /CMap defineresource pop\nend\nend")
    )
    entity_ref
  end
  def cmap_stream(_0042589e)
    i, w, elem, num = 2, 0, 0, 3
    while i + 9 < _0042589e.bytesize && _0042589e.getbyte(i) == 0xFF
      meta = _0042589e.getbyte(i + 1)
      if meta.between?(0xC0, 0xC2)
        elem, w = _0042589e.byteslice(i + 5, 4).unpack("nn")
        num = _0042589e.getbyte(i + 9)
        break
      end
      i += 2 + _0042589e.byteslice(i + 2, 2).unpack1("n")
    end
    _4ae5e797 = { 1 => "/DeviceGray", 4 => "/DeviceCMYK" }.fetch(num, "/DeviceRGB")
    stream_object(_0042589e, "/Type /XObject /Subtype /Image /Width #{w} /Height #{elem} /ColorSpace #{_4ae5e797} " \
                          "/BitsPerComponent 8 /Filter /DCTDecode /Length #{_0042589e.bytesize}")
  end
  def stream_object(stream, str = "/Length #{stream.bytesize}")
    "<< #{str} >>\nstream\n".b << stream.b << "\nendstream"
  end
  def build_pdf(arr)
    out, rows = "%PDF-1.4\n%ÿÿÿÿ\n".b, ""
    arr.each_with_index do |obj, i|
      rows << format("%010d 00000 n \n", out.bytesize)
      out << "#{i + 1} 0 obj\n" << obj.b << "\nendobj\n"
    end
    xref_at = out.bytesize
    out << "xref\n0 #{arr.size + 1}\n0000000000 65535 f \n" << rows
    out << "trailer\n<< /Size #{arr.size + 1} /Root 1 0 R >>\nstartxref\n#{xref_at}\n%%EOF"
  end
end
