class KSU::Giacong::Dxf
  TO_MM = 25.4
  def initialize(model2)
    @model2 = model2
    @h5 = {}
    @txt = String.new
    @handle_message = 100
  end
  def dxf_layer(layer)
    _5133d650, _4a6dab96, rgb = KSU::Giacong.layer_style(layer)
    unless _5133d650 == "0"
      @h5[_5133d650] ||= @model2 ? KSU::Giacong.pack_rgb(*rgb) : _4a6dab96
    end
    _5133d650
  end
  def write_polyline(box, layer, _7bc8e8cf)
    layer_name = dxf_layer(layer)
    @handle_message += 1
    @txt << "0\nLWPOLYLINE\n"
    @txt << "5\n" << @handle_message.to_s(16) << "\n"
    @txt << "100\nAcDbEntity\n"
    @txt << "8\n" << layer_name << "\n"
    @txt << "100\nAcDbPolyline\n"
    @txt << "90\n" << box.length.to_s << "\n"
    @txt << "66\n1\n70\n" << (_7bc8e8cf ? "1" : "0") << "\n"
    box.each do |pt|
      @txt << "10\n" << (pt.x * TO_MM).to_s << "\n"
      @txt << "20\n" << (pt.y * TO_MM).to_s << "\n"
      b = pt.bulge.to_f
      @txt << "42\n" << b.to_s << "\n" if b != 0
    end
  end
  def write_circle(center, r, layer)
    layer_name = dxf_layer(layer)
    @handle_message += 1
    @txt << "0\nCIRCLE\n"
    @txt << "5\n" << @handle_message.to_s(16) << "\n"
    @txt << "100\nAcDbEntity\n"
    @txt << "8\n" << layer_name << "\n"
    @txt << "100\nAcDbCircle\n"
    @txt << "10\n" << (center.x * TO_MM).to_s << "\n"
    @txt << "20\n" << (center.y * TO_MM).to_s << "\n"
    @txt << "40\n" << (r * TO_MM).to_s << "\n"
  end
  def store_post(file)
    _9ed8fa14 = String.new
    @h5.keys.sort_by { |n| [n[/\A\D*/], n[/\d+\z/].to_i] }.each do |name|
      color = @h5[name]
      @handle_message += 1
      _9ed8fa14 << "0\nLAYER\n"
      _9ed8fa14 << "5\n" << @handle_message.to_s(16) << "\n"
      _9ed8fa14 << "100\nAcDbSymbolTableRecord\n"
      _9ed8fa14 << "100\nAcDbLayerTableRecord\n"
      _9ed8fa14 << "2\n" << name << "\n"
      _9ed8fa14 << "70\n0\n"
      _9ed8fa14 << (@model2 ? "420\n" : "62\n") << color.to_s << "\n"
      _9ed8fa14 << "6\nContinuous\n"
      _9ed8fa14 << "390\n13\n"
    end
    out = KSU::Giacong::CHUNKS.sub("{layers}", _9ed8fa14.chomp("\n")).sub("{entities}", @txt.chomp("\n"))
    File.open(file, "w") { |f| f.write(out) }
    true
  rescue SystemCallError
    false
  end
end
