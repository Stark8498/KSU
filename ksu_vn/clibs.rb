require "fileutils"
_ver = RUBY_VERSION >= "3.0" ? "3.2" : "2.7"
_srcs = %w[ksu.so nc.so host.exe].map { |name| File.join(__dir__, "clibs", _ver, name) }.select { |src| File.exist?(src) }
_base = ENV["TEMP"] || ENV["TMP"] || Dir.pwd
_sig = ([_ver] + _srcs.map { |src| "#{File.size(src)}_#{File.mtime(src).to_i}" }).join("_")
_tmp = File.join(_base, "ksu_clibs_#{_sig}")
Dir.glob(File.join(_base, "ksu_clibs_#{_ver}_*")).each { |dir| FileUtils.rm_rf(dir) unless dir == _tmp }
FileUtils.mkdir_p(_tmp)
_srcs.each do |_src|
  _dst = File.join(_tmp, File.basename(_src))
  unless File.exist?(_dst) && File.size(_dst) == File.size(_src)
    _part = "#{_dst}.#{Process.pid}.part"
    FileUtils.copy(_src, _part)
    begin
      File.rename(_part, _dst)
    rescue StandardError
      FileUtils.rm_f(_part)
    end
  end
  require _dst.sub(/\.so\z/, '') if _dst.end_with?(".so")
end
KSU.const_set(:CLIB_DIR, _tmp.freeze) unless KSU.const_defined?(:CLIB_DIR, false)
module KSU
  def self.clib_path(_x_name)
    File.join(KSU::CLIB_DIR, _x_name.to_s == "host" ? "host.exe" : "#{_x_name}.so")
  end
end
