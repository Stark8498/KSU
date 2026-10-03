class KSU::Xuatdxf::Dxf
  TO_MM = 25.4
  def initialize(true_color)
    @true_color = true_color
    @arr9 = {}
    @txt = String.new
    @num14 = 100
  end
  def layer_for(kind)
    layer_name, color_ix, rgb = KSU::Xuatdxf.layer_spec(kind)
    unless layer_name == "0"
      @arr9[layer_name] ||= @true_color ? KSU::Xuatdxf.true_color_of(*rgb) : color_ix
    end
    layer_name
  end
  def write_polyline(box, kind, closed)
    _2cb52d46 = layer_for(kind)
    @num14 += 1
    @txt << "0\nLWPOLYLINE\n"
    @txt << "5\n" << @num14.to_s(16) << "\n"
    @txt << "100\nAcDbEntity\n"
    @txt << "8\n" << _2cb52d46 << "\n"
    @txt << "100\nAcDbPolyline\n"
    @txt << "90\n" << box.length.to_s << "\n"
    @txt << "66\n1\n70\n" << (closed ? "1" : "0") << "\n"
    box.each do |pt|
      @txt << "10\n" << (pt.x * TO_MM).to_s << "\n"
      @txt << "20\n" << (pt.y * TO_MM).to_s << "\n"
      b = pt.bulge.to_f
      @txt << "42\n" << b.to_s << "\n" if b != 0
    end
  end
  def write_circle(center, r, kind)
    _2cb52d46 = layer_for(kind)
    @num14 += 1
    @txt << "0\nCIRCLE\n"
    @txt << "5\n" << @num14.to_s(16) << "\n"
    @txt << "100\nAcDbEntity\n"
    @txt << "8\n" << _2cb52d46 << "\n"
    @txt << "100\nAcDbCircle\n"
    @txt << "10\n" << (center.x * TO_MM).to_s << "\n"
    @txt << "20\n" << (center.y * TO_MM).to_s << "\n"
    @txt << "40\n" << (r * TO_MM).to_s << "\n"
  end
  def write_file(file)
    layers_txt = String.new
    @arr9.keys.sort_by { |n| [n[/\A\D*/], n[/\d+\z/].to_i] }.each do |name|
      color = @arr9[name]
      @num14 += 1
      layers_txt << "0\nLAYER\n"
      layers_txt << "5\n" << @num14.to_s(16) << "\n"
      layers_txt << "100\nAcDbSymbolTableRecord\n"
      layers_txt << "100\nAcDbLayerTableRecord\n"
      layers_txt << "2\n" << name << "\n"
      layers_txt << "70\n0\n"
      layers_txt << (@true_color ? "420\n" : "62\n") << color.to_s << "\n"
      layers_txt << "6\nContinuous\n"
      layers_txt << "390\n13\n"
    end
    out = KSU::Xuatdxf::CHUNKS.sub("{layers}", layers_txt.chomp("\n")).sub("{entities}", @txt.chomp("\n"))
    File.open(file, "w") { |f| f.write(out) }
    true
  rescue SystemCallError
    UI.messagebox("Không ghi được file (kiểm tra quyền truy cập hoặc file đang mở).")
    false
  end
end
