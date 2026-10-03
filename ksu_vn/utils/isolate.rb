module KSU::Isolate
  def self.start(keep = nil)
    model = Sketchup.active_model
    keep_list = keep ? Array(keep) : KSU.selection
    KSU.start
    model.active_entities.each do |ent|
      next unless KSU.container?(ent)
      next if ent.hidden?
      next if keep_list.include?(ent)
      ent.hidden = true
    end
    KSU.commit
  end
end
require "open-uri"
require "openssl"
module KSU::Isolate
  def self.http_get(url, timeout)
    URI.open(url, read_timeout: timeout) { |io| return io.read }
  rescue
    URI.open(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, read_timeout: timeout) { |io| return io.read }
  end
end
