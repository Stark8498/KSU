module KSU
  module Cnc
    module Planner
      Path = Struct.new(:kind, :layer, :tool, :points, :closed, :entry_style, :start_refs, :lead_shift_mm, :metadata)
      CutPlan = Struct.new(:shape_report, :paths, :depths, :warnings, :hard_issues) do
        def status
          return :blocked if !shape_report[:ok] || paths.empty?
          hard_issues.empty? ? :safe : :partial
        end
      end
      PlanIssue = Struct.new(:layer, :tool_number, :xy, :message, :diameter) do
        def to_s
          Text.t(:duong, :duong_dao, layer: layer, dao: tool_number ? Text.t(:duong, :dao, so: tool_number, d: Text.num(diameter.to_f.abs, 3)) : '',
                                     vi_tri: xy ? Text.position_text(xy[0], xy[1]) : '', ly_do: message)
        end
      end
      module Builder
        module_function
        def to_segments(vectors:, origin:, operations:, references:, run_scope: :file_export, repair_stats: nil, reuse: nil)
          Export.with_run_scope(run_scope) do
            Export.reset_path_cache unless run_scope == :sim_view
            out_rec = operations.map { |arr3| Export.build_chains(arr3[:vectors], repair_stats) }
            _a46f825d = Export.build_chains(references)
            bb2, bb = Frame.xy_columns(vectors)
            num = [((bb2.min - origin[0].to_f) + (bb2.max - origin[0].to_f)) / 2.0,
                               ((bb.min - origin[1].to_f) + (bb.max - origin[1].to_f)) / 2.0]
            show_result = Topology::Validator.validate(Topology::Engine.to_segments(out_rec.flatten + _a46f825d, origin))
            tool_index = Export.nesting_depth_all(out_rec, operations, _a46f825d).transform_values { |arr| arr[:depth] }
            paths = build_groups(operations.zip(out_rec), tool_index, origin, (arr2 = []), num, reuse)
            warnings = (show_result[:errors] + arr2.map(&:to_s)).map { |arr| Text.error_text(arr) } +
                          show_result[:warnings].map { |arr| Text.warning_text(arr) }
            CutPlan.new(show_result, paths, tool_index, warnings, arr2)
          end
        end
        def build_groups(grouped, tool_index, anchor, arr, references, index_paths = nil)
          grouped.each_with_object([]) do |(_e976ebfe, vectors), ok|
            _e2fd4a2e = [_e976ebfe, vectors, tool_index, anchor, references]
            paths, partner = index_paths ? index_paths.call(*_e2fd4a2e, -> { build_group(*_e2fd4a2e) }) : build_group(*_e2fd4a2e)
            ok.concat(paths)
            arr.concat(partner)
          end
        end
        def build_group(arr3, vectors, tool_index, anchor, references)
          ok = []
          arr = []
          tool = arr3[:tool]
          arr2 = vectors.sort_by.with_index { |vec, idx| [-tool_index[vec].to_i, idx] }
          h = {}
          str = tool["type"].to_s == "rim_pocket"
          (str ? Export.nested_outlines(arr2) : []).each do |_afea3aa9|
            outer, inner = _afea3aa9.values_at(:outer, :inner)
            h[outer.object_id] = h[inner.object_id] = true
            note_issue(ok, arr, outer, tool, anchor) do |layer_name|
              paths = Export.tool_fits?(outer, inner, tool, anchor) || []
              raise Export::UnsafeCutError, Text.t(:duong, :van_de) if paths.length < 2
              paths.each { |_d3fb9c5b| add_path(ok, "rim_pocket", layer_name, tool, _d3fb9c5b, closed_ring?(_d3fb9c5b)) }
            end
          end
          arr2.each do |vec|
            next if h[vec.object_id]
            note_issue(ok, arr, vec, tool, anchor) do |layer_name|
              raise Export::UnsafeCutError, Text.t(:duong, :hem_khong_cap) if str
              raise Export::UnsafeCutError, Text.t(:duong, :van_de) if vec.points.empty?
              add_vector(ok, vec, layer_name, tool, tool_index[vec].to_i.odd?, anchor, references)
            end
          end
          [ok, arr]
        end
        def note_issue(ok, _53e651f8, vec, tool, anchor)
          str = vec.layer_name.to_s
          flag = vec.points.first && Export.to_mm(vec.points.first, anchor)
          num = ok.length
          error = begin
            yield str
            Text.t(:duong, :van_de) if ok.length == num
          rescue StandardError => err
            flag = err.xy if err.is_a?(Export::UnsafeCutError) && err.xy
            err.is_a?(Export::UnsafeCutError) ? err.message : Text.t(:duong, :van_de)
          end
          _53e651f8 << PlanIssue.new(str, tool["number"], flag, error, tool["diameter"]) if error
        end
        def add_vector(ok, vec, layer_name, tool, nested, anchor, references)
          closed = Export.really_closed?(vec)
          arr = Export.orient_points(vec.points, tool, closed)
          if Export.drill_in_place?(tool, vec)
            add_point_path(ok, "drill", layer_name, tool, Export.to_mm(Export.drill_center(vec, tool), anchor))
          elsif Export.pocket?(tool, vec)
            arr4 = Export.rescue_outline(arr, tool, anchor, vec)
            raise Export::UnsafeCutError, Export.rescue_error unless arr4
            arr4[:paths].each { |arr2| add_path(ok, "pocket", layer_name, tool, arr2, closed_ring?(arr2)) }
            Array(arr4[:plunge_points]).each { |arr2| add_point_path(ok, "pocket_bore", layer_name, tool, arr2, "direct_plunge") }
          elsif Export.can_offset?(tool, vec)
            _e2fd4a2e = [vec, arr, tool, anchor, nested]
            row = Export.sim_view? ? Export.cached_path(*_e2fd4a2e) : Export.build_path(*_e2fd4a2e)
            unless row[:ok] && row[:path]
              raise Export::UnsafeCutError.new(row[:error] || Text.t(:duong, :van_de)).tap { |err| err.xy = row[:xy] }
            end
            arr3 = row[:path]
            path = row[:cut_side].to_s == "outside" ? Export.rotate_entry(arr3, tool) : arr3
            _841b2f48 = arr3.first && path.first && Calc.distance(path.first, arr3.first) > 0.01
            lock = Export.lock_check(row[:elem_lock], path)
            raise Export::UnsafeCutError, Text.t(:duong, :van_de) if Export.lock_enabled?(row[:elem_lock]) && !lock
            add_path(ok, "profile", layer_name, tool, path, true, entry_style: _841b2f48 ? "lead_arc_merged" : nil,
                        start_refs: row[:base], lead_shift_mm: row[:lead_shift_mm].to_f, metadata: { elem_lock: lock })
          elsif %w[inside outside auto flip_side follow_dir].include?(tool["cut_side"].to_s) && !closed && arr.length >= 2
            add_pocket(ok, layer_name, tool, arr.map { |pt| Export.to_mm(pt, anchor) }, nested, references)
          else
            if closed && arr.length > 1
              arr += [arr.first] unless Export.same_point?(arr.last, arr.first)
              arr = Export.rotate_points_to_corner(arr, tool["entry_corner"], anchor)
            end
            arr2 = arr.map { |pt| Export.to_mm(pt, anchor) }
            lead_shift_mm = closed && arr2.length > 3 ? tool["khoang_cach_xuong_dao"].to_f : 0.0
            arr2 = Export.shift_lead(arr2, -lead_shift_mm) if lead_shift_mm.abs >= 0.0001
            add_path(ok, "center", layer_name, tool, arr2, closed, lead_shift_mm: lead_shift_mm)
          end
        end
        def add_pocket(ok, layer_name, tool, base_xy, nested, references)
          r = tool["diameter"].to_f.abs * 0.5
          raise Export::UnsafeCutError, Text.t(:duong, :van_de) unless r.positive?
          str = Export.cut_side_of(tool, nested).to_s
          side = str == "inside" || (str == "auto" && nested) ? "inside" : "outside"
          offset_with_border = Open.offset_with_border(base_xy, r, side, references)
          raise Export::UnsafeCutError, Text.t(:duong, :van_de) unless offset_with_border && offset_with_border.length >= 2
          return add_path(ok, "open_cut", layer_name, tool, offset_with_border, false) unless Export.mark_square?(layer_name)
          ramp_len = tool["ramp_len_mm"] if tool["entry_mode"].to_s == "ramp_line" && tool["ramp_kind"].to_s != "spiral"
          arr = Mark.to_segments(offset_with_border, tool_radius: r, ramp_len_mm: ramp_len)
          raise Export::UnsafeCutError, arr[:reason] unless arr[:ok]
          add_path(ok, "open_cut", layer_name, tool, arr[:preview_points], false,
                   entry_style: tool["entry_mode"].to_s, metadata: { "back_square_mark" => arr })
        end
        def add_path(ok, kind, layer_name, tool, out, closed, entry_style: nil, start_refs: nil,
                     lead_shift_mm: 0.0, metadata: {})
          return if out.length < 2
          raise Export::UnsafeCutError, Text.t(:duong, :van_de) unless lead_shift_mm.finite?
          ok << Path.new(kind, layer_name, tool, to_xy(out), closed, entry_style,
                             to_xy(start_refs), lead_shift_mm, metadata)
        end
        def add_point_path(ok, kind, layer_name, tool, _d3fb9c5b, entry_style = nil)
          ok << Path.new(kind, layer_name, tool, to_xy([_d3fb9c5b]), false, entry_style, [], 0.0, {})
        end
        def to_xy(out)
          Array(out).map do |pt|
            _d3fb9c5b = [pt[0].to_f, pt[1].to_f]
            _d3fb9c5b[0].finite? && _d3fb9c5b[1].finite? ? _d3fb9c5b : raise(Export::UnsafeCutError, Text.t(:duong, :van_de))
          end
        end
        def closed_ring?(out)
          out.length >= 4 && Calc.distance(out.first, out.last) <= 0.01
        end
      end
    end
    module Review
      CORNERS = {
        "bottom_left" => [:min, :min, [1.0, 0.0]],
        "bottom_right" => [:max, :min, [0.0, 1.0]],
        "top_left" => [:min, :max, [0.0, -1.0]],
        "top_right" => [:max, :max, [-1.0, 0.0]],
        "bottom_center" => [:mid, :min, [1.0, 0.0]],
        "top_center" => [:mid, :max, [-1.0, 0.0]],
        "middle_left" => [:min, :mid, [0.0, -1.0]],
        "middle_right" => [:max, :mid, [0.0, 1.0]]
      }.freeze
      module_function
      def open_points(out)
        rows = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        rows.pop while rows.length > 1 && Calc.distance(rows.first, rows.last) <= 0.01
        rows
      end
      def corner_target(out, corner)
        open_points(out).transpose.zip(CORNERS[corner]).map do |vars, mode|
          case mode
          when :min then vars.min
          when :max then vars.max
          else (vars.min + vars.max) * 0.5
          end
        end
      end
      def corner_index(out, target, corner)
        rows = open_points(out)
        return nil if rows.length < 2
        arr5 = CORNERS[corner][2]
        _bd7bf87a = Calc.shoelace_area(rows).positive? ? arr5 : [-arr5[0], -arr5[1]]
        arr2 = Calc.corner_dir(corner)
        arr3, arr6 = [], []
        rows.each_index do |idx|
          row0 = rows[idx]
          last_rect = rows[(idx + 1) % rows.length]
          dx = last_rect[0] - row0[0]
          dy = last_rect[1] - row0[1]
          len2 = dx * dx + dy * dy
          next if len2 <= 1.0e-18
          t = [[((target[0] - row0[0]) * dx + (target[1] - row0[1]) * dy) / len2, 0.0].max, 1.0].min
          point = [row0[0] + dx * t, row0[1] + dy * t]
          _fbf0cf8d = point[0] - target[0]
          _7e1c7e1d = point[1] - target[1]
          distance = Math.hypot(_fbf0cf8d, _7e1c7e1d)
          length = Math.sqrt(len2)
          num2 = -1.0
          num2 = ((_fbf0cf8d / distance) * arr2[0] + (_7e1c7e1d / distance) * arr2[1]).abs if arr2 && distance > 1.0e-12
          arr3 << {
            index: idx, t: t, point: point, distance: distance,
            tangent_align: ((dx / length) * _bd7bf87a[0] + (dy / length) * _bd7bf87a[1]), midline_align: num2
          }
          next unless arr2
          _78dcb2bf = row0[0] - target[0]
          _9ff9e93b = row0[1] - target[1]
          num = arr2[0] * dy - arr2[1] * dx
          next unless num.abs > 1.0e-12
          num3 = (_78dcb2bf * dy - _9ff9e93b * dx) / num
          s = (_78dcb2bf * arr2[1] - _9ff9e93b * arr2[0]) / num
          next unless s >= -1.0e-9 && s <= 1.0 + 1.0e-9
          s = [[s, 0.0].max, 1.0].min
          arr6 << { index: idx, t: s, point: [row0[0] + dx * s, row0[1] + dy * s], distance: num3.abs }
        end
        return nil if arr3.empty?
        arr4 = arr3.map { |arr| arr[:distance] }.min
        tol = arr2 ? [[0.25, arr4 * 0.03].max, 1.0].min : [1.0, arr4 * 0.03].max
        arr7 = arr3.select { |arr| arr[:distance] <= arr4 + tol }
        return arr7.max_by { |arr| [arr[:tangent_align], -arr[:distance], -arr[:index]] } unless arr2
        arr8 = arr6.select { |arr| arr[:distance] <= arr4 + tol }
        arr8.min_by { |arr| [arr[:distance], arr[:index], arr[:t]] } || arr7.max_by do |arr|
          [arr[:midline_align], -arr[:distance], arr[:t] > 1.0e-9 && arr[:t] < 1.0 - 1.0e-9 ? 1 : 0, -arr[:index]]
        end
      end
    end
    module Check
      module_function
      def assert_plan_ok(plan)
        arr = (plan.shape_report[:ok] ? [] : plan.shape_report[:errors]) + plan.hard_issues.map(&:to_s)
        arr << Text.t(:van, :khong_duong_dao) if arr.empty? && plan.paths.empty?
        plan.paths.each { |path| arr.concat(path_open?(path)) if path.closed }
        raise Export::UnsafeCutError, arr.uniq.join("\n") unless arr.empty?
      end
      def path_open?(path)
        out = path.points
        lock_open = Calc.distance(out.first, out.last) > 0.01
        return [] unless path_direction_ok?(path, out) || lock_open || Polygon.polygon_ok?(out)[:intersects] != false
        [Text.t(:duong, :loi_duong_dao, layer: path.layer, vi_tri: Text.position_text(out.first[0], out.first[1]))]
      end
      def path_direction_ok?(path, out)
        sweep = path.tool["cut_direction"].to_s
        num = %w[cw ccw].include?(sweep) ? Calc.shoelace_area(Review.open_points(out)) : 0.0
        reversed = num.abs >= 1.0e-9 && (num.positive? ? "ccw" : "cw") != sweep
        corner = path.tool["entry_corner"].to_s
        return reversed unless Review::CORNERS.key?(corner)
        border = path.start_refs.length >= 2 ? path.start_refs : out
        best = Review.corner_index(out, Review.corner_target(border, corner), corner)
        return better_start?(out, best, path.lead_shift_mm) || reversed if path.lead_shift_mm.abs >= 0.01
        reversed || (best && Calc.distance(out.first, best[:point]) > 1.0)
      end
      def better_start?(out, best, ctrl)
        return true unless best
        arr = out[0...-1]
        return false if arr.length < 3
        rows = Calc.distance(out.first, out.last) > 0.01 ? out + [out.first] : out
        _6b6d259b = rows.each_cons(2).inject(0.0) { |acc2, (a, b)| acc2 + Calc.distance(b, a) }
        return true unless _6b6d259b > 0.01
        _8cdb09bc = turn_total(arr, best[:point])
        return true unless _8cdb09bc
        _8cdb09bc %= _6b6d259b
        gap2 = (_8cdb09bc - ctrl % _6b6d259b).abs
        gap2 = _6b6d259b - gap2 if gap2 > _6b6d259b * 0.5
        !(gap2 <= [[_6b6d259b * 0.002, 0.5].max, 1.0].min)
      end
      def turn_total(out, arr)
        num = 0.0
        out.each_cons(2) do |(ax, ay), last_rect|
          dx = last_rect[0] - ax
          dy = last_rect[1] - ay
          len2 = dx * dx + dy * dy
          next if len2 <= 1.0e-18
          _c8614638 = [[((arr[0] - ax) * dx + (arr[1] - ay) * dy) / len2, 0.0].max, 1.0].min
          distance = Math.hypot(ax + dx * _c8614638 - arr[0], ay + dy * _c8614638 - arr[1])
          _84a46043 = Math.sqrt(len2)
          return num + _84a46043 * _c8614638 if distance <= 0.02
          num += _84a46043
        end
        nil
      end
    end
    module Frame
      module_function
      def to_segments(vectors, back_face:)
        groups = { part_border: [], sheet_border: [], back_marker: [], all_geometry: vectors }
        h = Hash.new { |h6, layer_name| h6[layer_name] = layer_role(layer_name) }
        vectors.each { |arr| groups[h[arr.layer_name]]&.push(arr) }
        (back_face ? %i[sheet_border back_marker part_border all_geometry] : %i[part_border sheet_border all_geometry]).each do |boundary|
          bb2, bb = xy_columns(groups[boundary])
          next unless bb2
          lx, _b0566a11 = bb2.minmax
          ly, _897789b7 = bb.minmax
          next if _b0566a11 - lx <= 0.001 || _897789b7 - ly <= 0.001
          bb5, flag = boundary == :part_border ? [bb2, bb] : xy_columns(groups[:part_border])
          return {
            source: boundary, origin: [lx, ly], global_bounds: [lx, ly, _b0566a11, _897789b7],
            width_mm: _b0566a11 - lx, height_mm: _897789b7 - ly,
            full_sheet: %i[sheet_border back_marker].include?(boundary),
            old_part_origin: bb5 && [bb5.min, flag.min]
          }
        end
        nil
      end
      def layer_role(layer_name)
        name = Util.alnum_upper(layer_name)
        { "SHEETBORDER" => :sheet_border, "MARKSQUARE" => :back_marker, "PARTBORDER" => :part_border }
          .find { |key, _| name.include?(key) }&.last
      end
      def xy_columns(rows)
        rows.flat_map(&:points).map { |pt| [pt.x.to_f * Export::MM_PER_INCH, pt.y.to_f * Export::MM_PER_INCH] }.transpose
      end
      def screen_box(rows, num = 0.0, bot = 0.0)
        _fab08cff, _bc9133af = xy_columns(rows)
        return unless _fab08cff
        text, x1 = _fab08cff.minmax
        y0, y1 = _bc9133af.minmax
        [text - num, y0 - bot, x1 - num, y1 - bot]
      end
      def face_mismatches(back, arr)
        h = Hash.new { |h6, layer_name| h6[layer_name] = layer_role(layer_name) }
        rows = back.group_by { |row| h[row.layer_name] }
        arr29 = rows[:part_border]
        left, bot, b2, _e4f12bf3 = screen_box(rows[:sheet_border] || [])
        box2 = screen_box(arr.select { |row| h[row.layer_name] == :sheet_border })
        return [] unless arr29 && left && box2 && b2 - left > 0.001 && _e4f12bf3 - bot > 0.001
        _f85ad947, _a02fcd28 = marker_center(rows[:back_marker] || []) || [b2, bot]
        _f85ad947 -= left
        _a02fcd28 -= bot
        flag2 = _f85ad947 > (b2 - left) / 2.0 ? _f85ad947 : _f85ad947 + box2[2] - box2[0]
        flag = _a02fcd28 < (_e4f12bf3 - bot) / 2.0 ? _a02fcd28 : _a02fcd28 - box2[3] + box2[1]
        idx = marker_boxes(arr, box2)
        _1dbfc5f8 = lambda do |_d5362565|
          text, y0, x1, y1 = screen_box(_d5362565, left, bot)
          text && row_near?(idx, [flag2 - x1, y0 - flag, flag2 - text, y1 - flag])
        end
        arr29.group_by(&:src_path_ids).values.filter_map do |loops|
          next if _1dbfc5f8.call(loops) || loops.all? { |_99b739cb| _1dbfc5f8.call([_99b739cb]) }
          text, y0, x1, y1 = screen_box(loops, left, bot)
          [(text + x1) / 2.0, (y0 + y1) / 2.0] if text
        end
      end
      def marker_center(rows)
        arr, _bc9133af = xy_columns(rows)
        return unless arr && arr.length >= 3
        text, x1 = arr.minmax
        y0, y1 = _bc9133af.minmax
        return if x1 - text <= 0.001 || y1 - y0 <= 0.001
        out = arr.zip(_bc9133af)
        scr = [[text, y0], [x1, y0], [x1, y1], [text, y1]]
        _96740fe0 = scr.index do |px, py|
          out.none? { |x, y| (x - px).abs < (x1 - text) * 0.25 && (y - py).abs < (y1 - y0) * 0.25 }
        end
        scr[(_96740fe0 + 2) % 4] if _96740fe0
      end
      def marker_boxes(rows, box2)
        arr = rows.map { |row| screen_box([row], box2[0], box2[1]) }
        arr.concat(rows.group_by(&:src_path_ids).values.map { |_124c7bd3| screen_box(_124c7bd3, box2[0], box2[1]) })
        arr.compact.group_by { |fld| fld[0].round }
      end
      def row_near?(idx, ids)
        key = ids[0].round
        (key - 1..key + 1).any? do |_07a84065|
          Array(idx[_07a84065]).any? { |fld| fld.zip(ids).all? { |a, b| (a - b).abs <= 0.01 } }
        end
      end
      def out_of_sheet?(x, y, box2)
        x < -50.0 || y < -50.0 ||
          (box2[:full_sheet] && (x > box2[:width_mm] + 50.0 || y > box2[:height_mm] + 50.0))
      end
      def assert_in_sheet(vectors, box2)
        left, bot = box2[:origin]
        b2 = box2[:full_sheet] && box2[:width_mm] + 50.0
        _e4f12bf3 = box2[:full_sheet] && box2[:height_mm] + 50.0
        vectors.each do |row|
          row.points.each do |pt|
            x = pt.x.to_f * Export::MM_PER_INCH - left
            y = pt.y.to_f * Export::MM_PER_INCH - bot
            next unless x < -50.0 || y < -50.0 || (b2 && (x > b2 || y > _e4f12bf3))
            raise Export::UnsafeCutError, Text.t(:ban_ve, :ngoai_khung, layer: row.layer_name, x: Text.num(x, 1), y: Text.num(y, 1))
          end
        end
      end
      def assert_plan_in_sheet(plan, box2)
        plan.paths.each do |path|
          path.points.each do |x, y|
            next unless out_of_sheet?(x, y, box2)
            raise Export::UnsafeCutError, Text.t(:duong, :ra_ngoai_khung, layer: path.layer, x: Text.num(x, 1), y: Text.num(y, 1))
          end
        end
      end
      def scan_moves(nc_text)
        flag6 = x = y = flag4 = flag2 = nil
        flag = true
        flag3 = flag5 = false
        arr2, arr, moves = [], [], []
        nc_text.each_line.with_index(1) do |_cf87de7d, _9e7c1068|
          err_code = strip_comment(_cf87de7d)
          next if err_code.empty?
          flag3 = true if err_code.match?(/(?<![A-Z])M0?[34](?![0-9.])/)
          flag3 = false if err_code.match?(/(?<![A-Z])M0?5(?![0-9.])/)
          flag = true if err_code.match?(/(?<![A-Z])G90(?![0-9.])/)
          flag = false if err_code.match?(/(?<![A-Z])G91(?![0-9.])/)
          next if err_code.match?(/(?<![A-Z])G53(?![0-9.])/)
          flag6 ||= err_code.match?(/(?<![A-Z])G0?[0123](?![0-9.])/)
          next unless flag6
          _6fad70a9 = err_code[/(?<![A-Z])X\s*(-?\d+(?:\.\d+)?)/, 1]&.then { |text| Float(text) }
          _6aac3c71 = err_code[/(?<![A-Z])Y\s*(-?\d+(?:\.\d+)?)/, 1]&.then { |text| Float(text) }
          next unless _6fad70a9 || _6aac3c71
          flag4 = flag ? _6fad70a9 : (flag4 || 0.0) + _6fad70a9 if _6fad70a9
          flag2 = flag ? _6aac3c71 : (flag2 || 0.0) + _6aac3c71 if _6aac3c71
          moves.push(_9e7c1068, flag4, flag2)
          next unless flag3
          flag5 = true unless flag
          x = flag ? _6fad70a9 : (x || 0.0) + _6fad70a9 if _6fad70a9
          y = flag ? _6aac3c71 : (y || 0.0) + _6aac3c71 if _6aac3c71
          arr2 << x if x
          arr << y if y
        end
        { min_x: arr2.min, min_y: arr.min, max_x: arr2.max, max_y: arr.max, empty: arr2.empty? && arr.empty?,
          relative: flag5, moves: moves }
      end
      def bounds_in_sheet?(bnds, box2)
        bnds[:min_x] && bnds[:min_y] &&
          !out_of_sheet?(bnds[:min_x], bnds[:min_y], box2) && !out_of_sheet?(bnds[:max_x], bnds[:max_y], box2)
      end
      def shift_program(nc_text, box2)
        saved = box2[:old_part_origin]
        return [nc_text, nil] unless box2[:full_sheet] && saved
        id_str = scan_moves(nc_text)
        return [nc_text, id_str] if id_str[:empty] || bounds_in_sheet?(id_str, box2)
        raise Export::UnsafeCutError, Text.t(:mat_sau, :g91) if id_str[:relative]
        dx, dy = saved[0] - box2[:origin][0], saved[1] - box2[:origin][1]
        return [nc_text, id_str] if dx.abs <= 1.0 && dy.abs <= 1.0
        row_w, _bf071a8c = box2.values_at(:width_mm, :height_mm)
        lx, ly, _b0566a11, _897789b7 = id_str.values_at(:min_x, :min_y, :max_x, :max_y)
        return [nc_text, id_str] unless lx && ly &&
                            (_b0566a11 - lx - row_w).abs <= 1.0 && (_897789b7 - ly - _bf071a8c).abs <= 1.0 &&
                            (lx + dx).abs <= 1.0 && (ly + dy).abs <= 1.0 &&
                            (_b0566a11 + dx - row_w).abs <= 1.0 && (_897789b7 + dy - _bf071a8c).abs <= 1.0
        _fc68f84f = shift_moves(nc_text, dx, dy)
        bbox = scan_moves(_fc68f84f)
        raise Export::UnsafeCutError, Text.t(:mat_sau, :vuot_khung) unless bounds_in_sheet?(bbox, box2)
        [_fc68f84f, bbox]
      end
      def shift_moves(nc_text, dx, dy)
        num = nil
        flag = true
        flag3 = flag2 = false
        nc_text.each_line.map do |_cf87de7d|
          err_code = strip_comment(_cf87de7d)
          flag3 = true if err_code.match?(/(?<![A-Z])M0?[34](?![0-9.])/)
          flag3 = false if err_code.match?(/(?<![A-Z])M0?5(?![0-9.])/)
          flag = true if err_code.match?(/(?<![A-Z])G90(?![0-9.])/)
          flag = false if err_code.match?(/(?<![A-Z])G91(?![0-9.])/)
          flag2 = true if err_code.match?(/(?<![A-Z])G90\.1(?![0-9.])/)
          flag2 = false if err_code.match?(/(?<![A-Z])G91\.1(?![0-9.])/)
          num = err_code[/(?<![A-Z])G0?([0123])(?![0-9.])/, 1]&.to_i || num
          next _cf87de7d unless flag3 && num && !err_code.match?(/(?<![A-Z])G53(?![0-9.])/)
          raise Export::UnsafeCutError, Text.t(:mat_sau, :g91) unless flag
          ok = shift_axis(shift_axis(_cf87de7d, "X", dx), "Y", dy)
          next ok unless flag2 && [2, 3].include?(num)
          shift_axis(shift_axis(ok, "I", dx), "J", dy)
        end.join
      end
      def shift_axis(axis, axis5, delta)
        axis.sub(/(?<![A-Z])(#{axis5}\s*)(-?\d+(?:\.\d+)?)/i) do
          val = Regexp.last_match(2)
          digits = val.include?(".") ? val.split(".", 2).last.length : 3
          "#{Regexp.last_match(1)}#{format("%.#{digits.clamp(3, 6)}f", val.to_f + delta)}"
        end
      end
      def assert_moves_in_sheet(nc_text, box2, bnds = nil)
        (bnds || scan_moves(nc_text))[:moves].each_slice(3) do |_9e7c1068, x, y|
          next unless out_of_sheet?(x || 0.0, y || 0.0, box2)
          raise Export::UnsafeCutError, Text.t(:van, :nc_ngoai_khung, dong: _9e7c1068)
        end
      end
      def strip_comment(str)
        (str.include?("(") ? str.gsub(/\([^)]*\)/, '') : str).split(";", 2).first.to_s.upcase.strip
      end
    end
  end
end
