module KSU::Svg
  module_function
  def svg_ops(svg, font, font_bold, used, used_bold)
    ops = ["0 0 0 rg", "0 0 0 RG", "2 J", "0 j"]
    arr2 = svg.scan(/<g\s[^>]*>|<\/g>|<rect\s[^>]*\/>|<line\s[^>]*\/>|<path\s[^>]*\/>|<polygon\s[^>]*\/>|<circle\s[^>]*\/>|<text\s[^>]*>.*?<\/text>/m)
    arr2.each do |str|
      if str.start_with?("<g")
        ops.concat(path_ops(str))
      elsif str.start_with?("</g")
        ops << "Q"
      elsif str.start_with?("<rect")
        ops.concat(rect(str))
      elsif str.start_with?("<line")
        ops.concat(axis(str))
      elsif str.start_with?("<path")
        ops.concat(path(str))
      elsif str.start_with?("<polygon")
        ops.concat(polygon(str))
      elsif str.start_with?("<circle")
        ops.concat(circle(str))
      elsif str.start_with?("<text")
        ops.concat(text(str, font, font_bold, used, used_bold))
      end
    end
    ops
  end
  def attr(node, name)
    meta = node.match(/\s#{name}="([^"]*)"/)
    meta ? meta[1] : nil
  end
  def n(v)
    f = v.to_f
    half = (f * 1000).round / 1000.0
    half == half.to_i ? half.to_i.to_s : half.to_s
  end
  def transform_ops(tf)
    thick = tf.match(/translate\(\s*(-?[\d.]+)[\s,]+(-?[\d.]+)\s*\)/)
    return ["1 0 0 1 #{n(thick[1])} #{n(thick[2])} cm"] if thick
    meta = tf.match(/rotate\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/)
    return [] unless meta
    num3 = meta[1].to_f * Math::PI / 180.0
    px = meta[2].to_f
    py = meta[3].to_f
    cos_a = Math.cos(num3)
    sin_a = Math.sin(num3)
    ent = px - px * cos_a + py * sin_a
    f = py - px * sin_a - py * cos_a
    ["#{n(cos_a)} #{n(sin_a)} #{n(-sin_a)} #{n(cos_a)} #{n(ent)} #{n(f)} cm"]
  end
  def path_ops(node)
    ["q"] + transform_ops(attr(node, "transform").to_s)
  end
  def paint_ops(node)
    fill = attr(node, "fill")
    stroke = attr(node, "stroke")
    has_fill = fill && fill != "none"
    has_stroke = stroke && stroke != "none"
    pre = []
    pre << "#{rgb(fill)} rg" if has_fill
    pre << "#{rgb(stroke)} RG" if has_stroke
    stroke_w = attr(node, "stroke-width")
    pre << "#{n(stroke_w)} w" if has_stroke && stroke_w
    opac = if has_fill && has_stroke then "B"
            elsif has_fill then "f"
            elsif has_stroke then "S"
            else "n" end
    [pre, opac]
  end
  def dash(node)
    dash = attr(node, "stroke-dasharray")
    return nil unless dash
    vals2 = dash.split(/[ ,]+/).reject(&:empty?).map { |v| n(v) }.join(" ")
    "[#{vals2}] 0 d"
  end
  def rgb(color)
    return "0 0 0" unless color
    if color == "#fff" || color == "#ffffff" then "1 1 1"
    elsif color == "#000" || color == "#000000" then "0 0 0"
    elsif (meta = color.match(/^#([0-9a-fA-F]{6})$/))
      v = meta[1]
      [0, 2, 4].map { |i| (v[i, 2].to_i(16) / 255.0).round(3) }.join(" ")
    elsif (meta = color.match(/^#([0-9a-fA-F]{3})$/))
      v = meta[1]
      (0..2).map { |i| ((v[i] * 2).to_i(16) / 255.0).round(3) }.join(" ")
    else "0 0 0" end
  end
  def rect(node)
    x = attr(node, "x").to_f
    y = attr(node, "y").to_f
    w = attr(node, "width").to_f
    h = attr(node, "height").to_f
    pre, opac = paint_ops(node)
    return pre if opac == "n"
    half = [attr(node, "rx").to_f, w / 2.0, h / 2.0].min
    return pre + ["#{n(x)} #{n(y)} #{n(w)} #{n(h)} re", opac] if half <= 0
    k = half * 0.5523
    x2 = x + w
    y_hi3 = y + h
    ops = ["#{n(x + half)} #{n(y)} m", "#{n(x2 - half)} #{n(y)} l"]
    ops << "#{n(x2 - half + k)} #{n(y)} #{n(x2)} #{n(y + half - k)} #{n(x2)} #{n(y + half)} c"
    ops << "#{n(x2)} #{n(y_hi3 - half)} l"
    ops << "#{n(x2)} #{n(y_hi3 - half + k)} #{n(x2 - half + k)} #{n(y_hi3)} #{n(x2 - half)} #{n(y_hi3)} c"
    ops << "#{n(x + half)} #{n(y_hi3)} l"
    ops << "#{n(x + half - k)} #{n(y_hi3)} #{n(x)} #{n(y_hi3 - half + k)} #{n(x)} #{n(y_hi3 - half)} c"
    ops << "#{n(x)} #{n(y + half)} l"
    ops << "#{n(x)} #{n(y + half - k)} #{n(x + half - k)} #{n(y)} #{n(x + half)} #{n(y)} c"
    ops << "h"
    pre + ops + [opac]
  end
  def axis(node)
    x219 = attr(node, "x1")
    y_hi3 = attr(node, "y1")
    x2 = attr(node, "x2")
    y2 = attr(node, "y2")
    ops, = paint_ops(node)
    cap = attr(node, "stroke-linecap")
    ops << "2 J" if cap == "square"
    ops << "0 J" if cap == "butt"
    len2d = dash(node)
    ops << "0 J" if len2d && !cap
    ops << len2d if len2d
    ops.concat(["#{n(x219)} #{n(y_hi3)} m", "#{n(x2)} #{n(y2)} l", "S"])
    cap || len2d ? ["q"] + ops + ["Q"] : ops
  end
  def path(node)
    ops, opac = paint_ops(node)
    len2d = dash(node)
    ops << "0 J" << len2d if len2d
    attr(node, "d").to_s.scan(/([MLZ])\s*(-?[\d.]+)?\s*(-?[\d.]+)?/).each do |cmd, sx2, b|
      case cmd
      when "M" then ops << "#{n(sx2)} #{n(b)} m"
      when "L" then ops << "#{n(sx2)} #{n(b)} l"
      when "Z" then ops << "h"
      end
    end
    ops << opac
    len2d ? ["q"] + ops + ["Q"] : ops
  end
  def polygon(node)
    pre, opac = paint_ops(node)
    pts = attr(node, "points").to_s.scan(/(-?[\d.]+)[,\s]+(-?[\d.]+)/)
    return pre if pts.empty? || opac == "n"
    ops = pts.each_with_index.map { |(x, y), i| "#{n(x)} #{n(y)} #{i.zero? ? 'm' : "l"}" }
    pre + ops + ["h", opac]
  end
  def circle(node)
    px = attr(node, "cx").to_f
    py = attr(node, "cy").to_f
    half = attr(node, "r").to_f
    pre, opac = paint_ops(node)
    k = half * 0.5523
    ops = ["#{n(px + half)} #{n(py)} m"]
    ops << "#{n(px + half)} #{n(py + k)} #{n(px + k)} #{n(py + half)} #{n(px)} #{n(py + half)} c"
    ops << "#{n(px - k)} #{n(py + half)} #{n(px - half)} #{n(py + k)} #{n(px - half)} #{n(py)} c"
    ops << "#{n(px - half)} #{n(py - k)} #{n(px - k)} #{n(py - half)} #{n(px)} #{n(py - half)} c"
    ops << "#{n(px + k)} #{n(py - half)} #{n(px + half)} #{n(py - k)} #{n(px + half)} #{n(py)} c"
    ops << "h"
    pre + ops + [opac]
  end
  def text(arr, font, font_bold, used, used_bold)
    x = attr(arr, "x").to_f
    y = attr(arr, "y").to_f
    rsz = attr(arr, "font-size").to_f
    flag = arr.include?("font-weight=\"bold\"")
    anchor = attr(arr, "text-anchor") || "start"
    font_full = flag ? font_bold : font
    flag3 = flag ? used_bold : used
    flag2 = flag ? "F2" : "F1"
    obj = arr.sub(/^<text\s[^>]*>/, "").sub(/<\/text>$/, "")
    stream = unescape(obj)
    color = ""
    num = 0
    stream.each_char do |ch|
      cls2 = ch.ord
      gid = KSU::Ttf.gid(font_full, cls2)
      flag3[gid] = cls2
      color << format("%04X", gid)
      num += KSU::Ttf.advance(font_full, gid).to_f * rsz / font_full[:upm]
    end
    tx = case anchor
            when "middle" then x - num / 2
            when "end" then x - num
            else x end
    fill = rgb(attr(arr, "fill"))
    ops = ["#{fill} rg", "BT", "/#{flag2} #{n(rsz)} Tf", "1 0 0 -1 #{n(tx)} #{n(y)} Tm", "<#{color}> Tj", "ET"]
    tf = transform_ops(attr(arr, "transform").to_s)
    tf.empty? ? ops : ["q"] + tf + ops + ["Q"]
  end
  def unescape(s)
    s.gsub("&lt;", "<").gsub("&gt;", ">").gsub("&quot;", "\"").gsub("&amp;", "&")
  end
end
