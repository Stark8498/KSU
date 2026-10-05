module KSU::Update
  BACKUP_DIR = File.join(KSU::Settings::SETTINGS_DIR, "backup")
  def self.remove_installed
    plugins_dir = Sketchup.find_support_file("Plugins")
    str2 = File.join(plugins_dir, "ksu_vn")
    FileUtils.rm_rf(str2) if Dir.exist?(str2)
    str = File.join(plugins_dir, "ksu_vn.rb")
    File.delete(str) if File.exist?(str)
  end
  def self.restore_from_backup
    plugins_dir = Sketchup.find_support_file("Plugins")
    str3 = File.join(plugins_dir, "ksu_vn")
    str4 = File.join(plugins_dir, "ksu_vn.rb")
    str = File.join(BACKUP_DIR, "ksu_vn")
    str2 = File.join(BACKUP_DIR, "ksu_vn.rb")
    unless Dir.exist?(str) || File.exist?(str2)
      UI.messagebox("Không tìm thấy phiên bản dự phòng nào.")
      return false
    end
    return false unless UI.messagebox("Bạn có chắc muốn phục hồi phiên bản cũ? Điều này sẽ xóa phiên bản hiện tại và thay thế bằng phiên bản sao lưu gần nhất. Các thông số cài đặt sẽ không bị ảnh hưởng.", MB_YESNO) == IDYES
    if Dir.exist?(str) && File.exist?(str2)
      remove_installed
      FileUtils.mkdir_p(str3)
      FileUtils.cp_r(File.join(str, "."), str3)
      FileUtils.cp(str2, str4)
      UI.messagebox("Phục hồi thành công! Khởi động lại SketchUp để hoàn tất.")
      true
    else
      UI.messagebox("Không tìm thấy bản sao lưu nào.")
      false
    end
  rescue => e
    UI.messagebox("Lỗi khi phục hồi: #{e.message}")
    false
  end
  def self.backup
    plugins_dir = Sketchup.find_support_file("Plugins")
    return false unless plugins_dir
    FileUtils.mkdir_p(BACKUP_DIR)
    str3 = File.join(plugins_dir, "ksu_vn")
    str2 = File.join(BACKUP_DIR, "ksu_vn")
    if Dir.exist?(str3)
      FileUtils.rm_rf(str2) if Dir.exist?(str2)
      FileUtils.cp_r(str3, str2)
    end
    str4 = File.join(plugins_dir, "ksu_vn.rb")
    str = File.join(BACKUP_DIR, "ksu_vn.rb")
    if File.exist?(str4)
      File.delete(str) if File.exist?(str)
      FileUtils.cp(str4, str)
    end
    true
  rescue
    UI.messagebox("Có lỗi khi sao lưu phiên bản hiện tại. Bạn có muốn tiếp tục cập nhật?", MB_YESNO) == IDYES
  end
  def self.uninstall
    return unless UI.messagebox("Bạn có chắc muốn gỡ KSU khỏi SketchUp?", MB_YESNO) == IDYES
    remove_installed
    UI.messagebox("Đã gỡ phần mềm thành công! Khởi động lại SketchUp để hoàn tất.")
  end
  def self.check_update
    resp = JSON.parse(KSU::Themtam.http_fetch("https://ksu.vn/wp-content/uploads/update.json"))
    edge2 = resp["version"]
    edge = KSU::VERSION
    arr = edge.split(".").map(&:to_i)
    arr2 = edge2.split(".").map(&:to_i)
    msg2 = "Phiên bản phần mềm trên máy hiện tại là #{edge}."
    if (arr <=> arr2) == -1
      msg2 += "\nPhiên bản phần mềm mới nhất là #{edge2}.\nBạn có muốn bắt đầu cập nhật không?"
      if UI.messagebox(msg2, MB_YESNO) == IDYES && backup == true
        str = File.join(Dir.tmpdir, "ksu_vn_signed.rbz")
        begin
          URI.open("https://ksu.vn/wp-content/uploads/ksu_vn_signed.rbz", ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |_e64490fc|
            File.open(str, "wb") { |f| f.write(_e64490fc.read) }
          end
          begin
            remove_installed
            Sketchup.install_from_archive(str, false)
            UI.messagebox "Cập nhật thành công! Khởi động lại SketchUp để hoàn tất."
          rescue Interrupt
            UI.messagebox "Người dùng hủy cài đặt."
          rescue => e
            UI.messagebox "Lỗi khi cài đặt: #{e.message}"
          end
        rescue => e
          UI.messagebox "Không thể tải file: #{e.message}"
        end
      end
    else
      msg2 += "\nBạn đang sử dụng phiên bản mới nhất của phần mềm."
      UI.messagebox(msg2)
    end
  rescue => e
    UI.messagebox "Có lỗi xảy ra: #{e.message}"
  end
end
module KSU::Update
  def self.disk_id2
    rows = KSU.wmi_connect.ExecQuery("SELECT * FROM Win32_DiskDrive WHERE InterfaceType = 'IDE' OR InterfaceType = 'SCSI'")
    rows.each do |row2|
      next unless row2.SerialNumber
      return KSU::Xephang.normalize_id(row2.SerialNumber)
    end
    nil
  rescue
    nil
  end
end
