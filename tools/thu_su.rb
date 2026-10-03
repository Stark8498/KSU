# Load the renamed tree inside SketchUp and report what Ruby itself says.
#
# Paste into the Ruby Console:
#   load "C:/Users/Phucs/Downloads/ksu_vn/tools/thu_su.rb"
#
# Why this exists: the checks that run outside SketchUp prove the diff is a
# rename and nothing else, and that every called name is defined SOMEWHERE.
# Neither is the same as "it still runs". Ruby resolves a call through the real
# ancestor chain, so include, extend, prepend and `class << self` are accounted
# for here and only here. Nothing in this file touches a model: it loads the
# tree and then asks questions about it.
#
# The report lands next to this file, as thu_su.txt.

module KSUProbe
  ROOT = File.expand_path("..", File.dirname(__FILE__))
  REPORT = File.join(File.dirname(__FILE__), "thu_su.txt")

  def self.run
    out = []
    out << "SketchUp #{Sketchup.version}  Ruby #{RUBY_VERSION}  #{Time.now}"
    out << "cay: #{ROOT}"
    out << ""

    # Refuse to run next to the shipped extension. Loading these files over an
    # already-loaded KSU would redefine every method of a plugin the user may
    # be in the middle of using, and the result would say nothing about either
    # copy.
    live = Sketchup.extensions.find { |e| e.name.to_s == "KSU" && e.loaded? }
    if live && !live.extension_path.to_s.start_with?(ROOT.tr("\\", "/"))
      out << "DUNG LAI: ban KSU cai san dang nap trong phien nay"
      out << "  #{live.extension_path}"
      out << "  Mo mot SketchUp KHAC (ban 2024 khong co KSU) roi chay lai."
      return finish(out, false)
    end

    $LOAD_PATH.unshift(ROOT) unless $LOAD_PATH.include?(ROOT)

    # --- 1. does the tree load at all ---
    t0 = Time.now
    begin
      Sketchup.require "ksu_vn/main"
      out << "1 NAP: OK (#{((Time.now - t0) * 1000).round} ms)"
    rescue ScriptError, StandardError => e
      out << "1 NAP: VO -- #{e.class}: #{e.message}"
      e.backtrace.first(12).each { |b| out << "    #{b}" }
      return finish(out, false)
    end

    data = File.open(File.join(File.dirname(__FILE__), "goi.json"),
                     "r:UTF-8") { |f| f.read }
    want = parse(data)

    # --- 2. every module the source defines must exist ---
    missing_mod = want[:modules].reject { |n| resolve(n) }
    out << "2 MODULE: #{want[:modules].length - missing_mod.length}/" \
           "#{want[:modules].length} co mat"
    missing_mod.first(20).each { |n| out << "    thieu: #{n}" }

    # --- 3. every call site must resolve, the way Ruby resolves it ---
    bad = []
    want[:calls].each do |c|
      owner = resolve(c["ns"])
      if owner.nil?
        bad << [c, "khong co namespace"]
        next
      end
      next if owner.respond_to?(c["m"])
      # A private or protected method is still defined; only a name that
      # exists nowhere on the object is a break.
      names = owner.methods + owner.private_methods + owner.protected_methods
      next if names.include?(c["m"].to_sym)
      bad << [c, "khong phan giai duoc"]
    end
    out << "3 LOI GOI: #{want[:calls].length - bad.length}/" \
           "#{want[:calls].length} phan giai duoc"
    bad.first(40).each do |c, why|
      out << "    #{c['f']}:#{c['l']}  #{c['ns']}.#{c['m']}  -- #{why}"
    end

    # --- 4. instance methods of every module, so a renamed def that nothing
    #        calls by namespace still has to be a legal, callable method ---
    n_meth = 0
    want[:modules].each do |n|
      m = resolve(n)
      next unless m.is_a?(Module)
      n_meth += m.instance_methods(false).length +
                m.private_instance_methods(false).length +
                m.singleton_methods(false).length
    end
    out << "4 METHOD: #{n_meth} method dinh nghia trong cac module KSU"

    ok = missing_mod.empty? && bad.empty?
    out << ""
    out << (ok ? "=> KHONG THAY LOI" : "=> CO LOI, xem tren")
    finish(out, ok)
  end

  # The namespace as written, walked one constant at a time, so a missing
  # middle segment is reported rather than raised.
  def self.resolve(name)
    name.split("::").inject(Object) do |mod, part|
      return nil unless mod.is_a?(Module) && mod.const_defined?(part, false)
      mod.const_get(part, false)
    end
  rescue NameError
    nil
  end

  # SketchUp's Ruby has no bundled JSON on every version, and this file is
  # written by tools/sinhgoi.py in one fixed shape, so a small reader beats a
  # dependency that may not be there.
  def self.parse(src)
    calls = src.scan(
      /\{\s*"ns":\s*"([^"]+)",\s*"m":\s*"([^"]+)",\s*"f":\s*"([^"]+)",\s*"l":\s*(\d+)/
    ).map { |ns, m, f, l| { "ns" => ns, "m" => m, "f" => f, "l" => l.to_i } }
    mods = src[/"modules":\s*\[(.*?)\]/m, 1].to_s.scan(/"([^"]+)"/).flatten
    { calls: calls, modules: mods }
  end

  def self.finish(lines, ok)
    text = lines.join("\n") + "\n"
    File.open(REPORT, "w:UTF-8") { |f| f.write(text) }
    puts text
    ok
  end
end

KSUProbe.run
