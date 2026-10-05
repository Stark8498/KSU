module KSU::Svg
  module_function
  def parse_svg(svg_text, _87a3fd35, used)
    svg_text.scan(/<g\s[^>]*>|<\/g>|<(?:rect|line|path|polygon|circle|image)\s[^>]*\/>|<text\s[^>]*>.*?<\/text>/m).flat_map do |tag|
      case tag[/\A<\/?[a-z]+/]
      when "<g" then ["q"] + transform_ops(attr(tag, "transform").to_s)
      when "</g" then ["Q"]
      when "<rect" then rect(tag)
      when "<line" then axis(tag)
      when "<path" then path(tag)
      when "<polygon" then polygon(tag)
      when "<circle" then circle(tag)
      when "<image" then jpeg_image(tag, used)
      else text(tag, _87a3fd35)
      end
    end.unshift("0 0 0 rg", "0 0 0 RG", "2 J", "0 j")
  end
  def attr(tag, name)
    tag[/\s#{name}="([^"]*)"/, 1]
  end
  def n(v, s = 1000.0)
    half = (v.to_f * s).round / s
    half == half.to_i ? half.to_i.to_s : half.to_s
  end
  def transform_ops(tf)
    t = tf.match(/translate\(\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*\)/)
    return ["1 0 0 1 #{n(t[1])} #{n(t[2])} cm"] if t
    meta = tf.match(/rotate\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/)
    return [] unless meta
    a, px, py = meta[1].to_f * Math::PI / 180.0, meta[2].to_f, meta[3].to_f
    cos_a, sin_a = Math.cos(a), Math.sin(a)
    ["#{n(cos_a)} #{n(sin_a)} #{n(-sin_a)} #{n(cos_a)} #{n(px - px * cos_a + py * sin_a)} #{n(py - px * sin_a - py * cos_a)} cm"]
  end
  def shape_style(tag)
    fill, arr = [attr(tag, "fill"), attr(tag, "stroke")].map { |c| c unless c == "none" }
    stroke_w = attr(tag, "stroke-width")
    [[("#{rgb(fill)} rg" if fill), ("#{rgb(arr)} RG" if arr), ("#{n(stroke_w)} w" if arr && stroke_w)].compact,
     fill ? (arr ? "B" : "f") : (arr ? "S" : "n")]
  end
  def dash(tag)
    dash = attr(tag, "stroke-dasharray")
    "[#{dash.scan(/[^ ,]+/).map { |v| n(v) }.join(" ")}] 0 d" if dash
  end
  def rgb(arr)
    return "1 1 1" if arr == "#fff" || arr == "#ffffff"
    return "0 0 0" if !arr || arr == "#000" || arr == "#000000"
    v = arr[/^#([0-9a-fA-F]{6})$/, 1] || arr[/^#([0-9a-fA-F]{3})$/, 1]&.gsub(/./) { |elem| elem * 2 }
    v ? [0, 2, 4].map { |i| (v[i, 2].to_i(16) / 255.0).round(3) }.join(" ") : "0 0 0"
  end
  def rect(tag)
    x, y, w2, elem = %w[x y width height].map { |a| attr(tag, a).to_f }
    _5a718701, opac = shape_style(tag)
    return _5a718701 if opac == "n"
    half = [attr(tag, "rx").to_f, w2 / 2.0, elem / 2.0].min
    return _5a718701 + ["#{n(x)} #{n(y)} #{n(w2)} #{n(elem)} re", opac] if half <= 0
    k, x1, y1 = half * 0.5523, x + w2, y + elem
    _5a718701 + ["#{n(x + half)} #{n(y)} m", "#{n(x1 - half)} #{n(y)} l",
              "#{n(x1 - half + k)} #{n(y)} #{n(x1)} #{n(y + half - k)} #{n(x1)} #{n(y + half)} c",
              "#{n(x1)} #{n(y1 - half)} l",
              "#{n(x1)} #{n(y1 - half + k)} #{n(x1 - half + k)} #{n(y1)} #{n(x1 - half)} #{n(y1)} c",
              "#{n(x + half)} #{n(y1)} l",
              "#{n(x + half - k)} #{n(y1)} #{n(x)} #{n(y1 - half + k)} #{n(x)} #{n(y1 - half)} c",
              "#{n(x)} #{n(y + half)} l",
              "#{n(x)} #{n(y + half - k)} #{n(x + half - k)} #{n(y)} #{n(x + half)} #{n(y)} c", "h", opac]
  end
  def axis(tag)
    x1, y1, x2, arr = %w[x1 y1 x2 y2].map { |a| n(attr(tag, a)) }
    ops, cap, len2d = shape_style(tag)[0], attr(tag, "stroke-linecap"), dash(tag)
    ops << "2 J" if cap == "square"
    ops << "0 J" if cap == "butt" || (len2d && !cap)
    ops << len2d if len2d
    ops.push("#{x1} #{y1} m", "#{x2} #{arr} l", "S")
    cap || len2d ? ["q"] + ops + ["Q"] : ops
  end
  def path(tag)
    ops, opac, len2d = *shape_style(tag), dash(tag)
    ops << "0 J" << len2d if len2d
    attr(tag, "d").to_s.scan(/([MLZ])\s*(-?[\d.]+)?\s*(-?[\d.]+)?/).each do |cmd, a, b|
      ops << (cmd == "Z" ? "h" : "#{n(a)} #{n(b)} #{cmd.downcase}")
    end
    len2d ? ["q", *ops, opac, "Q"] : ops << opac
  end
  def polygon(tag)
    _5a718701, opac, arr = *shape_style(tag), attr(tag, "points").to_s.scan(/(-?[\d.]+)[,\s]+(-?[\d.]+)/)
    return _5a718701 if arr.empty? || opac == "n"
    _5a718701 + arr.each_with_index.map { |(x, y), i| "#{n(x)} #{n(y)} #{i.zero? ? 'm' : "l"}" } + ["h", opac]
  end
  def circle(tag)
    px, py, half = %w[cx cy r].map { |a| attr(tag, a).to_f }
    _5a718701, opac, k = *shape_style(tag), half * 0.5523
    _5a718701 + ["#{n(px + half)} #{n(py)} m",
              "#{n(px + half)} #{n(py + k)} #{n(px + k)} #{n(py + half)} #{n(px)} #{n(py + half)} c",
              "#{n(px - k)} #{n(py + half)} #{n(px - half)} #{n(py + k)} #{n(px - half)} #{n(py)} c",
              "#{n(px - half)} #{n(py - k)} #{n(px - k)} #{n(py - half)} #{n(px)} #{n(py - half)} c",
              "#{n(px + k)} #{n(py - half)} #{n(px + half)} #{n(py - k)} #{n(px + half)} #{n(py)} c", "h", opac]
  end
  def jpeg_image(tag, used)
    data = attr(tag, "href").to_s[/\Adata:image\/jpeg;base64,(.+)\z/, 1]
    return [] unless data
    name = (used[data] ||= "Im#{used.size + 1}")
    x, y, w3, elem = %w[x y width height].map { |a| attr(tag, a).to_f }
    ["q", "#{n(w3)} 0 0 #{n(-elem)} #{n(x)} #{n(y + elem)} cm", "/#{name} Do", "Q"]
  end
  def text(tag, arr2)
    x, y, rsz = %w[x y font-size].map { |a| attr(tag, a).to_f }
    _8d7dd1b9, font_full, taken = arr2[tag.include?("font-weight=\"bold\"") ? 1 : 0]
    color, str = "", 0
    unescape(tag.sub(/^<text\s[^>]*>/, "").sub(/<\/text>$/, "")).each_codepoint do |cls2|
      glyph = font_full[:cmap][cls2] || 0
      taken[glyph] = cls2
      color << format("%04X", glyph)
      str += KSU::Ttf.glyph_width(font_full, glyph).to_f * rsz / font_full[:upm]
    end
    tx = x - { "middle" => str / 2, "end" => str }.fetch(attr(tag, "text-anchor"), 0)
    ops = ["#{rgb(attr(tag, "fill"))} rg", "BT", "/#{_8d7dd1b9} #{n(rsz)} Tf", "1 0 0 -1 #{n(tx)} #{n(y)} Tm", "<#{color}> Tj", "ET"]
    str2 = transform_ops(attr(tag, "transform").to_s)
    str2.empty? ? ops : ["q"] + str2 + ops + ["Q"]
  end
  def unescape(s)
    s.gsub(/&(?:lt|gt|quot|amp);/, "&lt;" => "<", "&gt;" => ">", "&quot;" => "\"", "&amp;" => "&")
  end
end
