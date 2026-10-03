require "fileutils"
_ver = RUBY_VERSION >= "3.0" ? "3.2" : "2.7"
_src = File.join(__dir__, "clibs", _ver, "ksu.so")
_base = ENV["TEMP"] || ENV["TMP"] || Dir.pwd
_sig = "#{_ver}_#{File.size(_src)}_#{File.mtime(_src).to_i}"
_tmp = File.join(_base, "ksu_clibs_#{_sig}")
Dir.glob(File.join(_base, "ksu_clibs_*")).each do |dir|
  next if dir == _tmp
  begin
    FileUtils.rm_rf(dir)
  rescue StandardError
  end
end
FileUtils.mkdir_p(_tmp)
_dst = File.join(_tmp, "ksu.so")
unless File.exist?(_dst) && File.size(_dst) == File.size(_src)
  _part = "#{_dst}.#{Process.pid}.part"
  FileUtils.copy(_src, _part)
  begin
    File.rename(_part, _dst)
  rescue StandardError
    FileUtils.rm_f(_part) rescue nil
  end
end
require File.join(_tmp, "ksu")
