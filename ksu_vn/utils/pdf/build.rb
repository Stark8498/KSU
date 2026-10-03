module KSU::Pdf
  module_function
  S = 72.0 / 25.4
  def build_pdf(arr4, font, font_bold)
    used = {}
    used_bold = {}
    arr5 = arr4.map do |group_rgb|
      page_stream(group_rgb, font, font_bold, used, used_bold)
    end
    arr = []
    add = lambda { |obj| arr << obj; arr.size }
    catalog_id = add.call(nil)
    pages_id = add.call(nil)
    font_id = write_font(add, font, used, "Arial", arr)
    bold_id = write_font(add, font_bold, used_bold, "Arial-Bold", arr)
    arr3 = []
    arr5.each_with_index do |_0bc8ddc6, i|
      group_rgb = arr4[i]
      content_id = add.call(stream_obj(_0bc8ddc6))
      page_id = add.call(
        "<< /Type /Page /Parent #{pages_id} 0 R /MediaBox [0 0 #{num(group_rgb[:pw])} #{num(group_rgb[:ph])}] " \
        "/Resources << /Font << /F1 #{font_id} 0 R /F2 #{bold_id} 0 R >> >> /Contents #{content_id} 0 R >>"
      )
      arr3 << "#{page_id} 0 R"
    end
    arr[catalog_id - 1] = "<< /Type /Catalog /Pages #{pages_id} 0 R >>"
    arr[pages_id - 1] = "<< /Type /Pages /Kids [#{arr3.join(' ')}] /Count #{arr3.size} >>"
    serialize(arr)
  end
  def write_font(add, font_full, h, name, arr)
    type0_id = add.call(nil)
    cid_id = add.call(nil)
    desc_id = add.call(nil)
    file_id = add.call(nil)
    tounicode_id = add.call(nil)
    arr2 = h.keys.sort
    w = arr2.map { |g| "#{g} [#{(KSU::Ttf.advance(font_full, g).to_f * 1000 / font_full[:upm]).round}]" }.join(" ")
    upm = 1000.0 / font_full[:upm]
    data = font_full[:data]
    str = "<< /Type /Font /Subtype /Type0 /BaseFont /#{name} /Encoding /Identity-H " \
      "/DescendantFonts [#{cid_id} 0 R] /ToUnicode #{tounicode_id} 0 R >>"
    box = "[#{(font_full[:xmin] * upm).round} #{(font_full[:ymin] * upm).round} " \
      "#{(font_full[:xmax] * upm).round} #{(font_full[:ymax] * upm).round}]"
    str2 = "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /#{name} " \
      "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> " \
      "/FontDescriptor #{desc_id} 0 R /CIDToGIDMap /Identity /DW 500 /W [#{w}] >>"
    str3 = "<< /Type /FontDescriptor /FontName /#{name} /Flags 4 /FontBBox #{box} " \
      "/ItalicAngle 0 /Ascent #{(font_full[:ascent] * upm).round} /Descent #{(font_full[:descent] * upm).round} " \
      "/CapHeight #{(font_full[:ascent] * upm).round} /StemV 80 /FontFile2 #{file_id} 0 R >>"
    file_obj = { dict: "<< /Length #{data.bytesize} /Length1 #{data.bytesize} >>", stream: data }
    tounicode_obj = stream_obj(cmap_stream(h))
    arr[type0_id - 1] = str
    arr[cid_id - 1] = str2
    arr[desc_id - 1] = str3
    arr[file_id - 1] = file_obj
    arr[tounicode_id - 1] = tounicode_obj
    type0_id
  end
  def cmap_stream(arr)
    count_by_length = arr.map { |g, cls2| "<#{format('%04X', g)}> <#{format("%04X", cls2)}>" }
    "/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n" \
    "/CMapName /Adobe-Identity-UCS def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n" \
    "#{count_by_length.size} beginbfchar\n#{count_by_length.join("\n")}\nendbfchar\nendcmap\nCMapName currentdict /CMap defineresource pop\nend\nend"
  end
  def page_stream(group_rgb, font, font_bold, used, used_bold)
    h = group_rgb[:h]
    w = group_rgb[:w]
    ops = []
    ops << "q"
    if group_rgb[:rot]
      ops << "0 -1 1 0 0 #{num(w * S)} cm"
    end
    ops << "#{num(S)} 0 0 #{num(-S)} 0 #{num(h * S)} cm"
    ops.concat(KSU::Svg._3c7812cc(group_rgb[:svg], font, font_bold, used, used_bold))
    ops << "Q"
    ops.join("\n")
  end
  def stream_obj(stream)
    { dict: "<< /Length #{stream.bytesize} >>", stream: stream }
  end
  def serialize(arr)
    out = String.new("%PDF-1.4\n%ÿÿÿÿ\n", encoding: "BINARY")
    arr2 = []
    arr.each_with_index do |obj, i|
      arr2[i] = out.bytesize
      out << "#{i + 1} 0 obj\n"
      if obj.is_a?(Hash)
        out << obj[:dict].dup.force_encoding("BINARY") << "\nstream\n"
        out << obj[:stream].dup.force_encoding("BINARY") << "\nendstream"
      else
        out << obj.dup.force_encoding("BINARY")
      end
      out << "\nendobj\n"
    end
    xref_at = out.bytesize
    total = arr.size + 1
    out << "xref\n0 #{total}\n0000000000 65535 f \n"
    arr2.each { |_65570dfe| out << format("%010d 00000 n \n", _65570dfe) }
    out << "trailer\n<< /Size #{total} /Root 1 0 R >>\nstartxref\n#{xref_at}\n%%EOF"
    out
  end
  def num(v)
    half = (v * 100).round / 100.0
    half == half.to_i ? half.to_i.to_s : half.to_s
  end
end
