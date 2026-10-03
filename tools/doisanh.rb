# Run one fixed set of inputs through whichever copy of KSU this SketchUp has.
#
# Paste into the Ruby Console of BOTH instances:
#   load "C:/Users/Phucs/Downloads/ksu_vn/tools/doisanh.rb"
#
#   SketchUp 2025 -> the shipped plugin, methods still named in hex
#   SketchUp 2024 -> the readable tree, same methods renamed
#
# Each writes tools/doisanh_goc.txt or tools/doisanh_moi.txt. If the two files
# are identical, these methods compute what they computed before. That is the
# question no check outside SketchUp can answer: a rename cannot change
# behaviour in theory, and this is the theory being tested instead of asserted.
#
# Reads no model and writes no geometry. It only calls pure functions.

module KSUDoiSanh
  HERE = File.dirname(__FILE__)
  ROOT = File.expand_path("..", HERE)

  def self.run
    load File.join(HERE, "doisanh_cases.rb")

    # Nothing loaded yet means this is a SketchUp without the plugin, so the
    # readable tree is what we want here. Where the plugin IS loaded, leave it
    # alone: overwriting it would compare a copy with itself.
    unless defined?(KSU::Geom)
      $LOAD_PATH.unshift(ROOT) unless $LOAD_PATH.include?(ROOT)
      Sketchup.require "ksu_vn/main"
    end

    lines = []
    side = nil
    bad = 0

    CASES.each_with_index do |(mod_name, new_name, old_name, args), i|
      mod = resolve(mod_name)
      if mod.nil?
        lines << format("%02d  %s  -- KHONG CO MODULE", i, mod_name)
        bad += 1
        next
      end
      name = if mod.respond_to?(new_name) then new_name
             elsif mod.respond_to?(old_name) then old_name
             end
      if name.nil?
        lines << format("%02d  %s.%s  -- KHONG CO METHOD", i, mod_name, new_name)
        bad += 1
        next
      end
      # Which copy this is, decided by the first case that can tell them apart,
      # not by the SketchUp version: either tree could be loaded into either
      # one. A method the obfuscator skipped has the same name on both sides
      # and says nothing, so it must not be the one that decides.
      if side.nil? && new_name != old_name
        side = (name == new_name) ? "moi" : "goc"
      end

      begin
        value = mod.send(name, *args.call)
        lines << format("%02d  %s.%s = %s", i, mod_name, new_name, dump(value))
      rescue StandardError, ScriptError => e
        lines << format("%02d  %s.%s -- %s: %s", i, mod_name, new_name,
                        e.class, e.message)
        bad += 1
      end
    end

    side ||= "khong-ro"
    head = ["SketchUp #{Sketchup.version}  Ruby #{RUBY_VERSION}  #{Time.now}",
            "ban: #{side}   (#{CASES.length} truong hop, #{bad} loi)", ""]
    text = (head + lines).join("\n") + "\n"
    path = File.join(HERE, "doisanh_#{side}.txt")
    File.open(path, "w:UTF-8") { |f| f.write(text) }
    puts text
    puts "ghi: #{path}"
    path
  end

  def self.resolve(name)
    name.split("::").inject(Object) do |mod, part|
      return nil unless mod.is_a?(Module) && mod.const_defined?(part, false)
      mod.const_get(part, false)
    end
  rescue NameError
    nil
  end

  # One shape for a value, whatever it is, so the two files can be compared as
  # text. Floats are rounded: the two copies run the same arithmetic in the
  # same order, but the last bit of a double is not worth a false alarm.
  def self.dump(v)
    case v
    when nil, true, false then v.inspect
    when Float then format("%.9g", v)
    when Integer, String, Symbol then v.inspect
    when Geom::Point3d, Geom::Vector3d
      "(" + [v.x, v.y, v.z].map { |c| format("%.9g", c.to_f) }.join(", ") + ")"
    when Array then "[" + v.map { |e| dump(e) }.join(", ") + "]"
    when Hash
      "{" + v.keys.sort_by(&:to_s).map { |k| "#{k}: #{dump(v[k])}" }.join(", ") + "}"
    else "#<#{v.class}>"
    end
  end
end

KSUDoiSanh.run
