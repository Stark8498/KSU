module KSU::Isolate
  def self.start(keep = nil)
    flag = keep ? Array(keep) : KSU.selection
    KSU.start
    Sketchup.active_model.active_entities.each do |e|
      next unless KSU.container?(e)
      next if e.hidden?
      next if flag.include?(e)
      e.hidden = true
    end
    KSU.commit
  end
end
require "open-uri"
require "openssl"
module KSU::Isolate
  def self.http_get(url, timeout)
    URI.open(url, read_timeout: timeout) { |f| return f.read }
  rescue
    URI.open(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, read_timeout: timeout) { |f| return f.read }
  end
end
