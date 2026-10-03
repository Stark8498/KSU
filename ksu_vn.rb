require "sketchup.rb"
require "extensions.rb"
require "fileutils"

module KSU
  VERSION = "2.1.5"
  unless file_loaded?(__FILE__)
    runtime = RUBY_VERSION >= "3.0" ? "3.2" : "2.7"
    root = File.dirname(File.expand_path(__FILE__))
    source = File.join(root, "ksu_vn", "clibs", runtime, "loader.so")
    base = ENV["TEMP"] || ENV["TMP"] || Dir.pwd
    fingerprint = "#{File.size(source)}_#{File.mtime(source).to_i}"
    cache = File.join(base, "ksu_loader_#{runtime}_#{fingerprint}")
    destination = File.join(cache, "loader.so")
    unless File.exist?(destination)
      Dir.glob(File.join(base, "ksu_loader_*")).each do |folder|
        FileUtils.rm_rf(folder) rescue nil
      end
      FileUtils.mkdir_p(cache)
      FileUtils.cp(source, "#{destination}.part")
      File.rename("#{destination}.part", destination)
    end
    require File.join(cache, "loader")
    extension = SketchupExtension.new("KSU", "ksu_vn/main")
    extension.version = VERSION
    extension.creator = "Đặng Tiến Dũng"
    extension.copyright = "ksu.vn"
    extension.description = "Bộ công cụ hỗ trợ tối ưu sơ đồ cắt ván."
    Sketchup.register_extension(extension, true)
  end
  file_loaded(__FILE__)
end
