# Startup hook, so a run needs no typing into the Ruby Console.
#
#   "SketchUp.exe" -RubyStartup C:\...\tools\khoidong.rb "C:\...\thu.skp"
#
# The model file matters: without one SketchUp stops at the Welcome window and
# never gets as far as running this.
#
# This file runs before SketchUp has finished loading its extensions, so it
# waits rather than counting seconds. Where KSU is installed it must be loaded
# FIRST, or the comparison would load the readable tree on top of it and end up
# comparing a copy with itself.

HERE = File.dirname(File.expand_path(__FILE__)) unless defined?(HERE)

module KSUKhoiDong
  TRIES = 30

  def self.arm
    @n = 0
    @t = UI.start_timer(1.0, true) { tick }
  end

  def self.tick
    @n += 1
    return give_up if @n > TRIES
    return unless Sketchup.active_model
    # An installed KSU has to finish loading before we ask it anything. Where
    # none is installed there is nothing to wait for.
    pending = Sketchup.extensions.find { |e| e.name.to_s == "KSU" } &&
              !defined?(KSU::Geom)
    return if pending
    done
    # thu_su first: it loads the tree and reports what failed to load, which is
    # what you want to read when the comparison then cannot run. Where KSU is
    # already installed it declines, and doisanh uses that copy instead.
    ["thu_su.rb", "doisanh.rb"].each do |f|
      begin
        load File.join(HERE, f)
      rescue ScriptError, StandardError => e
        File.open(File.join(HERE, "doisanh_loi.txt"), "a:UTF-8") do |out|
          out.write("#{f}: #{e.class}: #{e.message}\n" +
                    e.backtrace.first(20).join("\n") + "\n")
        end
      end
    end
  end

  def self.give_up
    done
    File.open(File.join(HERE, "doisanh_loi.txt"), "w:UTF-8") do |f|
      f.write("qua #{TRIES} giay van chua san sang\n" \
              "model=#{!Sketchup.active_model.nil?} " \
              "KSU::Geom=#{defined?(KSU::Geom) ? 'co' : 'khong'}\n")
    end
  end

  def self.done
    UI.stop_timer(@t) if @t
    @t = nil
  end
end

KSUKhoiDong.arm
