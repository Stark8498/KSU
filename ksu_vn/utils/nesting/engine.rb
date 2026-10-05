module KSU::Nesting
  class Engine
    def self.instance
      @instance ||= new
    end
    def initialize
      @arr10, @h19, @num7 = [], {}, 0
    end
    def start2(width_mm:, height_mm:, spacing_mm:, rotate90:, use_holes:, parts_groups:,
               on_done:, on_progress: nil, on_place_progress: nil, two_sided: nil, orders: nil,
               pair: true)
      @on_done = on_done
      @on_progress = on_progress
      @on_place_progress = on_place_progress
      @arr10 = []
      @pending = "start(#{width_mm}, #{height_mm}, #{spacing_mm}, " \
                    "#{rotate90.inspect}, #{!!use_holes}, #{parts_groups.inspect}, #{(two_sided || []).inspect}, " \
                    "#{(orders || []).inspect}, #{pair != false});"
      @num7 = 1
      run_pending
    end
    def start_jobs(jobs:, on_job_done:, on_job_progress: nil, on_job_place_progress: nil, on_job_place: nil)
      @on_job_done = on_job_done
      @on_job_progress = on_job_progress
      @on_job_place_progress = on_job_place_progress
      @on_job_place = on_job_place
      @keep_existing = true
      @h19 = {}
      entries = jobs.map do |arr|
        "{w:#{arr[:w]},h:#{arr[:h]},w2:#{arr[:w2] || 0},h2:#{arr[:h2] || 0}," \
        "sp:#{arr[:sp]},rot:#{arr[:rot].inspect}," \
        "holes:#{!!arr[:holes]},parts:#{arr[:parts].inspect}," \
        "two:#{(arr[:two] || []).inspect},ord:#{(arr[:ord] || []).inspect}," \
        "own:#{(arr[:own] || []).inspect},outer:#{(arr[:outer] || []).inspect}," \
        "pair:#{arr[:pair] != false}}"
      end
      @pending = "startJobs([#{entries.join(',')}]);"
      @num7 = entries.size
      host = KSU::Settings.tool_windows
      if host
        start_engine(host)
      else
        @flag45 = false
        run_pending
      end
    end
    def on_engine_message(resp)
      name, *str = JSON.parse(resp.to_s)
      case name
      when "error" then puts "KSU Nesting engine: #{str[0]}"
      when "need_js"
        host = KSU::Settings.tool_windows
        if host && @prev_jobs
          @pending, @js_host = @prev_jobs, nil
          start_engine(host)
        end
      else on_engine_event(name, str)
      end
    rescue StandardError
      nil
    end
    def stop_engine
      if @flag45
        host = KSU::Settings.tool_windows
        KSU::Settings.send_to_dialog(host, "nesting", "nestingEngine", { cancel: true }.to_json) if host
        @flag45 = false
      end
      @keep_existing = false
      @num7 = 0
      @on_done = @on_progress = @on_place_progress = @on_job_done = @on_job_progress = @on_job_place_progress = @on_job_place = @prev_jobs = nil
      @h19 = {}
      drain_queue
    rescue StandardError
      nil
    end
    def stop
      @keep_existing = false
      drain_queue
    end
    private
    def on_engine_event(name, arr, meet0 = false)
      case name
      when "on_job_progress" then @on_job_progress&.call(arr[0].to_i, arr[1].to_i)
      when "on_job_place_progress" then @on_job_place_progress&.call(arr[0].to_i, arr[1].to_i, arr[2].to_i)
      when "on_job_place" then @on_job_place&.call(arr[0].to_i, arr[1].to_i, arr[2].to_s)
      when "on_job_fail" then @h19[arr[0].to_i] = arr[1]
      when "on_job_nested"
        cb = @on_job_done
        @num7 -= 1
        close_later if meet0 && @num7 <= 0
        cb.call(arr[0].to_i, arr[1], @h19.delete(arr[0].to_i)) if cb
      end
    end
    def start_engine(host)
      @flag45 = true
      @prev_jobs = @pending
      to_json_row = { start: @pending }
      unless @js_host.equal?(host)
        to_json_row[:js] = ENGINE_JS
        @js_host = host
      end
      @pending = nil
      KSU::Settings.send_to_dialog(host, "nesting", "nestingEngine", to_json_row.to_json)
    end
    def close_later
      UI.start_timer(0, false) { drain_queue }
    end
    def drain_queue
      return if @num7 > 0 || @keep_existing
      @flag12 = false
      @pending = nil
      dlg, @dlg2 = @dlg2, nil
      dlg.close if dlg
    rescue StandardError
      nil
    end
    def run_pending
      if @dlg2
        @dlg2.show unless @dlg2.visible?
        if @flag12
          script, @pending = @pending, nil
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
        @flag12 = true
        if @pending
          @dlg2.execute_script(@pending)
          @pending = nil
        end
      end
      @dlg2.add_action_callback("on_nested") do |dlg, data|
        cb = @on_done
        @num7 = 0
        close_later
        cb.call(data, @arr10) if cb
      end
      @dlg2.add_action_callback("on_progress") do |dlg, num2|
        cb = @on_progress
        cb.call(num2.to_i) if cb
      end
      @dlg2.add_action_callback("on_place_progress") do |dlg, done, total|
        cb = @on_place_progress
        cb.call(done.to_i, total.to_i) if cb
      end
      @dlg2.add_action_callback("on_fail_to_nest_parts") do |dlg, ix, parts|
        @arr10 << [ix, parts]
      end
      %w[on_job_nested on_job_progress on_job_place_progress on_job_place on_job_fail].each do |name|
        @dlg2.add_action_callback(name) { |dlg, *_e2fd4a2e| on_engine_event(name, _e2fd4a2e, true) }
      end
      load_html
      num = Sketchup.version.to_f >= 25.0 ? 0 : 9999
      @dlg2.set_position(num, num)
      @dlg2.show
    end
    def load_html
      normal = "file:///" + File.expand_path("../../html", __dir__).gsub("\\", "/") + "/"
      th_txt = Time.now.to_i.to_s
      build_html = "<!DOCTYPE html><html><head>" \
                "<meta charset=\"utf-8\">" \
                "<meta http-equiv=\"Cache-Control\" content=\"no-cache, no-store, must-revalidate\">" \
                "<base href=\"#{normal}\">" \
                "<script src=\"js/clip.js?v=#{th_txt}\"></script>" \
                "<script src=\"js/geo.js?v=#{th_txt}\"></script>" \
                "<script>#{ENGINE_JS}</script>" \
                "</head><body></body></html>"
      @flag12 = false
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
