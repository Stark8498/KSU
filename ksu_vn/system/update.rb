module KSU::Update
  BACKUP_DIR = File.join(KSU::Settings::SETTINGS_DIR, "backup")
  def self.remove_installed
    plugins_dir = Sketchup.find_support_file("Plugins")
    str = File.join(plugins_dir, "ksu_vn")
    FileUtils.rm_rf(str) if Dir.exist?(str)
    str2 = File.join(plugins_dir, "ksu_vn.rb")
    File.delete(str2) if File.exist?(str2)
  end
  def self.restore_from_backup
    begin
      plugins_dir = Sketchup.find_support_file("Plugins")
      str3 = File.join(plugins_dir, "ksu_vn")
      str4 = File.join(plugins_dir, "ksu_vn.rb")
      return false unless plugins_dir
      str = File.join(BACKUP_DIR, "ksu_vn")
      str2 = File.join(BACKUP_DIR, "ksu_vn.rb")
      unless Dir.exist?(str) || File.exist?(str2)
        UI.messagebox("Không tìm thấy phiên bản dự phòng nào.")
        return false
      end
      msg2 = "Bạn có chắc muốn phục hồi phiên bản cũ?"
      msg2 += " Điều này sẽ xóa phiên bản hiện tại và thay thế bằng phiên bản sao lưu gần nhất."
      msg2 += " Các thông số cài đặt sẽ không bị ảnh hưởng."
      answer = UI.messagebox(msg2, MB_YESNO)
      return false unless answer == IDYES
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
    rescue => ent
      UI.messagebox("Lỗi khi phục hồi: #{ent.message}")
      false
    end
  end
  def self.backup
    begin
      plugins_dir = Sketchup.find_support_file("Plugins")
      return false unless plugins_dir
      FileUtils.mkdir_p(BACKUP_DIR)
      str3 = File.join(plugins_dir, "ksu_vn")
      str = File.join(BACKUP_DIR, "ksu_vn")
      if Dir.exist?(str3)
        FileUtils.rm_rf(str) if Dir.exist?(str)
        FileUtils.cp_r(str3, str)
      end
      str4 = File.join(plugins_dir, "ksu_vn.rb")
      str2 = File.join(BACKUP_DIR, "ksu_vn.rb")
      if File.exist?(str4)
        File.delete(str2) if File.exist?(str2)
        FileUtils.cp(str4, str2)
      end
      true
    rescue => ent
      msg2 = "Có lỗi khi sao lưu phiên bản hiện tại. Bạn có muốn tiếp tục cập nhật?"
      answer = UI.messagebox(msg2, MB_YESNO)
      answer == IDYES
    end
  end
  def self.uninstall
    msg2 = "Bạn có chắc muốn gỡ KSU khỏi SketchUp?"
    answer = UI.messagebox(msg2, MB_YESNO)
    return unless answer == IDYES
    remove_installed
    UI.messagebox(
      "Đã gỡ phần mềm thành công!" \
      " Khởi động lại SketchUp để hoàn tất."
    )
  end
  def self.check_update
    url = "https://ksu.vn/wp-content/uploads/update.json"
    begin
      body = KSU::Themtam.http_fetch(url)
      resp = JSON.parse(body)
      latest = resp["version"]
      current = KSU::VERSION
      cur_parts = current.split(".").map(&:to_i)
      new_parts = latest.split(".").map(&:to_i)
      msg2 = "Phiên bản phần mềm trên máy hiện tại là #{current}."
      if (cur_parts <=> new_parts) == -1
        msg2 += "\nPhiên bản phần mềm mới nhất là #{latest}.\nBạn có muốn bắt đầu cập nhật không?"
        answer = UI.messagebox(msg2, MB_YESNO)
        if answer == IDYES && backup == true
          str2 = "https://ksu.vn/wp-content/uploads/ksu_vn_signed.rbz"
          str = File.join(Dir.tmpdir, "ksu_vn_signed.rbz")
          begin
            URI.open(str2, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |remote|
              File.open(str, "wb") { |io| io.write(remote.read) }
            end
            begin
              remove_installed
              Sketchup.install_from_archive(str, flag = false)
              UI.messagebox "Cập nhật thành công! Khởi động lại SketchUp để hoàn tất."
            rescue Interrupt
              UI.messagebox "Người dùng hủy cài đặt."
            rescue => ent
              UI.messagebox "Lỗi khi cài đặt: #{ent.message}"
            end
          rescue => ent
            UI.messagebox "Không thể tải file: #{ent.message}"
          end
        end
      else
        msg2 += "\nBạn đang sử dụng phiên bản mới nhất của phần mềm."
        UI.messagebox(msg2)
      end
    rescue => ent
      UI.messagebox "Có lỗi xảy ra: #{ent.message}"
    end
  end
end
module KSU::Update
  def self.disk_id2
    qry = KSU.wmi_connect.ExecQuery("SELECT * FROM Win32_DiskDrive WHERE InterfaceType = 'IDE' OR InterfaceType = 'SCSI'")
    qry.each do |row2|
      next unless row2.SerialNumber
      return KSU::Xephang.normalize_id(row2.SerialNumber)
    end
    nil
  rescue
    nil
  end
end
