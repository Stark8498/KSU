# Load the whole tree outside SketchUp, to see whether it survives being
# required at all. This is a load test, not a behaviour test: it catches module
# nesting that resolves to nothing, an include of a module that does not exist
# yet, a constant read at load time, and anything the load order gets wrong.
#
# Constants missing OUTSIDE KSU are stubbed on demand, because that is the
# SketchUp API we are not providing. Anything missing UNDER KSU still raises --
# that is the part being tested.

ROOT = File.expand_path(ARGV[0] || ".")
$LOAD_PATH.unshift(ROOT)

module Stub
  def self.build(name)
    k = Class.new
    k.define_singleton_method(:name) { name }
    k.define_singleton_method(:to_s) { name }
    k.define_singleton_method(:method_missing) { |*| k }
    k.define_singleton_method(:respond_to_missing?) { |*| true }
    k.send(:define_method, :initialize) { |*| }
    k.send(:define_method, :method_missing) { |*| self }
    k.send(:define_method, :respond_to_missing?) { |*| true }
    k
  end
end

# On Module, not Object: Sketchup is a module, so a singleton method on Object
# never reaches Sketchup::Face.
class Module
  def const_missing(sym)
    raise NameError, "thieu hang duoi KSU: #{self}::#{sym}" if to_s.start_with?("KSU")
    const_set(sym, Stub.build("#{self}::#{sym}"))
  end
end

class Numeric
  def mm; self; end
  def cm; self; end
  def m; self; end
  def inch; self; end
  def feet; self; end
  def degrees; self; end
  def to_mm; self; end
  def to_l; self; end
  def to_inch; self; end
end

module Geom
  class Point3d
    def initialize(*); end
    def method_missing(*); self; end
    def respond_to_missing?(*); true; end
  end
  class Vector3d
    def initialize(*); end
    def method_missing(*); self; end
    def respond_to_missing?(*); true; end
  end
  class Transformation
    def initialize(*); end
    def method_missing(*); self; end
    def respond_to_missing?(*); true; end
  end
  def self.method_missing(*); nil; end
  def self.respond_to_missing?(*); true; end
end
ORIGIN = Geom::Point3d.new
X_AXIS = Geom::Vector3d.new
Y_AXIS = Geom::Vector3d.new
Z_AXIS = Geom::Vector3d.new

module Sketchup
  SKIP = ["ksu_vn/clibs"]      # native kernel, no Ruby source to load

  def self.require(path)
    return true if SKIP.include?(path)
    file = File.join(ROOT, "#{path}.rb")
    return false unless File.exist?(file)
    Kernel.require(file)
  end

  def self.method_missing(*); ANY; end
  def self.respond_to_missing?(*); true; end
  def self.version; "25.0.0"; end
  def self.active_model; nil; end
  def self.format_length(*); ""; end
end

# Anything the API hands back has to keep swallowing calls, or a chain like
# UI.menu("Plugins").add_submenu(...) dies on the second link.
ANY = Object.new
def ANY.method_missing(*); self; end
def ANY.respond_to_missing?(*); true; end

module UI
  def self.method_missing(*); ANY; end
  def self.respond_to_missing?(*); true; end
  def self.scale_factor; 1.0; end
end

def file_loaded?(_); false; end
def file_loaded(_); nil; end

# Stand in for the native kernel so const_missing does not raise on it.
module KSU
  module Clibs
    def self.method_missing(*); nil; end
    def self.respond_to_missing?(*); true; end
  end
  module Clipper
    def self.method_missing(*); nil; end
    def self.respond_to_missing?(*); true; end
  end
end

begin
  # main.rb is what the extension points at; it pulls in everything else.
  Sketchup.require "ksu_vn/main"
  puts "NAP OK"
rescue Exception => e
  puts "NAP HONG: #{e.class}: #{e.message}"
  e.backtrace.first(12).each { |b| puts "    #{b.to_s.sub(ROOT + File::SEPARATOR, '')}" }
  exit 1
end

# Moi namespace cay ma tu khai bang `module KSU::X`. Nap duoc ma thieu mot
# cai trong so nay nghia la file chua duoc khai vao method.rb/utils.rb.
want = %w[
  KSU::Arrange KSU::Assign KSU::Avail KSU::Back
  KSU::Bilan KSU::Bottom KSU::Caidat KSU::Chuanhoa
  KSU::Collect KSU::Collide KSU::Const KSU::Corner
  KSU::Cutting KSU::Detail KSU::Drag KSU::Draw
  KSU::Edit KSU::Engine KSU::Field KSU::Flip
  KSU::Font KSU::Geom KSU::Group KSU::Intem
  KSU::Isolate KSU::Label KSU::Lastcut KSU::Launch
  KSU::Loop KSU::Mark KSU::Mirror KSU::Mode
  KSU::Nest KSU::Nesting KSU::Nfp KSU::Optimize
  KSU::Overlay KSU::Pack KSU::Pdf KSU::Postproc
  KSU::Preset KSU::Push KSU::Query KSU::Quet
  KSU::Reorder KSU::Resize KSU::Settings KSU::Shape
  KSU::Sheet KSU::Simplify KSU::Store KSU::Svg
  KSU::Thongke KSU::Thongke::Phukien KSU::Thongke::Quet KSU::Thongke::Tonghop
  KSU::Thongke::Xuat KSU::Ttf KSU::Update KSU::View
  KSU::Widget KSU::Xuatdxf
]
missing = want.reject do |c|
  begin
    c.split("::").inject(Object) { |m, part| m.const_get(part, false) }
    true
  rescue Exception
    false
  end
end
if missing.empty?
  puts "  moi module moi deu co mat (#{want.size}/#{want.size})"
else
  puts "  THIEU module: #{missing.join(', ')}"
end
puts "  hang KSU::* da dinh nghia: #{KSU.constants.size}"
