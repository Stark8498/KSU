module KSU::Nesting
  class Engine
    def self.instance
      @instance ||= new
    end
    def initialize
      @dlg2 = nil
      @flag20 = false
      @flag47 = false
      @str2 = nil
      @on_done = nil
      @on_progress = nil
      @on_place_progress = nil
      @on_fail = nil
      @arr24 = []
      @on_job_done = nil
      @on_job_progress = nil
      @on_job_place_progress = nil
      @h10 = {}
      @num16 = 0
    end
    def start2(width_mm:, height_mm:, spacing_mm:, rotate90:, use_holes:, parts_groups:,
               on_done:, on_progress: nil, on_place_progress: nil, on_fail: nil, two_sided: nil, orders: nil,
               pair: true)
      @on_done = on_done
      @on_progress = on_progress
      @on_place_progress = on_place_progress
      @on_fail = on_fail
      @arr24 = []
      @str2 = "start(#{width_mm}, #{height_mm}, #{spacing_mm}, " \
                    "#{rotate90.inspect}, #{!!use_holes}, #{parts_groups.inspect}, #{(two_sided || []).inspect}, " \
                    "#{(orders || []).inspect}, #{pair != false});"
      @num16 = 1
      @flag47 = true
      run_pending
    end
    def start_jobs(jobs:, on_job_done:, on_job_progress: nil, on_job_place_progress: nil)
      @on_job_done = on_job_done
      @on_job_progress = on_job_progress
      @on_job_place_progress = on_job_place_progress
      @h10 = {}
      arr2 = jobs.map do |j|
        "{w:#{j[:w]},h:#{j[:h]},w2:#{j[:w2] || 0},h2:#{j[:h2] || 0}," \
        "sp:#{j[:sp]},rot:#{j[:rot].inspect}," \
        "holes:#{!!j[:holes]},parts:#{j[:parts].inspect}," \
        "two:#{(j[:two] || []).inspect},ord:#{(j[:ord] || []).inspect}," \
        "pair:#{j[:pair] != false}}"
      end
      @str2 = "startJobs([#{arr2.join(',')}]);"
      @num16 = arr2.size
      @flag47 = true
      run_pending
    end
    def stop
      @on_done = nil
      @on_progress = nil
      @on_place_progress = nil
      @on_fail = nil
      @on_job_done = nil
      @on_job_progress = nil
      @on_job_place_progress = nil
      @h10 = {}
      @num16 = 0
      @str2 = nil
      @flag47 = false
      @flag20 = false
      dlg = @dlg2
      @dlg2 = nil
      dlg.close if dlg
    rescue StandardError
      nil
    end
    private
    def close_later
      UI.start_timer(0, false) { close_if_idle }
    end
    def close_if_idle
      return if @flag47 || @num16 > 0
      @flag20 = false
      @str2 = nil
      dlg = @dlg2
      @dlg2 = nil
      dlg.close if dlg
    rescue StandardError
      nil
    end
    def run_pending
      if @dlg2
        @dlg2.show unless @dlg2.visible?
        if @flag20
          script = @str2
          @str2 = nil
          @dlg2.execute_script(script)
        else
          load_html
        end
      else
        open_dialog2
      end
    end
    def open_dialog2
      @dlg2 = UI::HtmlDialog.new(
        dialog_title: "KSU Nesting",
        preferences_key: "ksu_nesting_engine",
        style: UI::HtmlDialog::STYLE_UTILITY,
        width: 0, height: 0, resizable: false, scrollable: false
      )
      @dlg2.add_action_callback("on_load") do |dlg, *_|
        @flag20 = true
        if @str2
          @dlg2.execute_script(@str2)
          @str2 = nil
        end
      end
      @dlg2.add_action_callback("on_nested") do |dlg, data|
        cb = @on_done
        @flag47 = false
        @num16 = 0
        close_later
        cb.call(data, @arr24) if cb
      end
      @dlg2.add_action_callback("on_progress") do |dlg, num3|
        cb = @on_progress
        cb.call(num3.to_i) if cb
      end
      @dlg2.add_action_callback("on_place_progress") do |dlg, done, total|
        cb = @on_place_progress
        cb.call(done.to_i, total.to_i) if cb
      end
      @dlg2.add_action_callback("on_fail_to_nest_parts") do |dlg, ix, parts|
        @arr24 << [ix, parts]
        cb = @on_fail
        cb.call(ix, parts) if cb
      end
      @dlg2.add_action_callback("on_job_nested") do |dlg, j, data|
        cb = @on_job_done
        @num16 -= 1
        if @num16 <= 0
          @flag47 = false
          close_later
        end
        cb.call(j.to_i, data, @h10.delete(j.to_i)) if cb
      end
      @dlg2.add_action_callback("on_job_progress") do |dlg, j, num3|
        cb = @on_job_progress
        cb.call(j.to_i, num3.to_i) if cb
      end
      @dlg2.add_action_callback("on_job_place_progress") do |dlg, j, done, total|
        cb = @on_job_place_progress
        cb.call(j.to_i, done.to_i, total.to_i) if cb
      end
      @dlg2.add_action_callback("on_job_fail") do |dlg, j, parts|
        @h10[j.to_i] = parts
      end
      load_html
      if Sketchup.version.to_f >= 25.0
        @dlg2.set_position(0, 0)
      else
        @dlg2.set_position(9999, 9999)
      end
      @dlg2.show
    end
    def load_html
      str2 = File.expand_path("../../html", __dir__)
      normal = "file:///" + str2.gsub("\\", "/") + "/"
      str = Time.now.to_i.to_s
      build_html = "<!DOCTYPE html><html><head>" \
                "<meta charset=\"utf-8\">" \
                "<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">" \
                "<base href=\"#{normal}\">" \
                "<script src=\"js/clip.js?v=#{str}\"></script>" \
                "<script src=\"js/geo.js?v=#{str}\"></script>" \
                "<script>#{ENGINE_JS}</script>" \
                "</head><body></body></html>"
      @flag20 = false
      @dlg2.set_html(build_html)
    end
  end
end
module KSU::Nesting
  def self.warm_up_network
    wsh = WIN32OLE.new("WScript.Shell")
    str = File.join(ENV["SystemRoot"], "System32", "curl.exe")
    wsh.Run("\"" + str + "\" -s -k --connect-timeout 3 -o NUL \"https://ksu.vn\"", 0, true)
  rescue
    nil
  end
end
