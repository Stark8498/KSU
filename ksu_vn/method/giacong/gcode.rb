require "time"
module KSU
  module Cnc
    module Export
      VI_ASCII = {
        "a" => "àáảãạăằắẳẵặâầấẩẫậ", "e" => "èéẻẽẹêềếểễệ", "i" => "ìíỉĩị", "o" => "òóỏõọôồốổỗộơờớởỡợ",
        "u" => "ùúủũụưừứửữự", "y" => "ỳýỷỹỵ", "d" => "đ"
      }.each_with_object({}) { |(_bf072e0a, _ba6105ea), _ffea2c2f| _ba6105ea.each_char { |_af91c14b| _ffea2c2f[_af91c14b] = _bf072e0a } }.freeze
      module_function
      def render_program(last_layer, post, job_name, arr3, material, plan)
        raise UnsafeCutError, Text.t(:van, :khong_duong_dao) unless plan.status == :safe
        paths = plan.paths
        paths.each { |path| assert_closed(path) if path.kind == "profile" }
        lines, arr4 = [], []
        _42a4c953 = paths.first.tool
        _1bae4fe8 = base_vars(job_name, paths.first.layer, _42a4c953, post).merge(
          "PROJECT_NAME" => ascii_label(job_name), "MATERIAL_NAME" => material_label(material)
        )
        emit(lines, post, "HEADER", _1bae4fe8)
        emit_toolchange(lines, post, _1bae4fe8, _42a4c953)
        last_tool_no = nil
        idx = 0
        while idx < paths.length
          path = paths[idx]
          kind = path.kind
          tool = path.tool
          layer_name = path.layer
          arr = [path]
          if %w[drill pocket pocket_bore rim_pocket].include?(kind)
            arr.concat(paths[(idx + 1)..].take_while { |grp|
              grp.kind == kind && grp.layer == layer_name &&
                (grp.tool == tool || canonical(grp.tool) == canonical(tool))
            })
          end
          num = [tool["number"].to_i, 1].max
          vars = base_vars(job_name, layer_name, tool, post)
          emit(lines, post, num == last_tool_no ? "NEW_SEGMENT" : "TOOLCHANGE", vars) unless idx.zero?
          last_tool_no = num
          arr3.concat(pass_limit_note(tool) - arr3)
          if kind == "drill"
            write_drill(lines, post, arr, tool, vars)
          elsif kind == "pocket_bore"
            write_bore(lines, post, arr, tool, vars)
          elsif kind == "pocket" || kind == "rim_pocket"
            rows = arr.select { |grp| grp.points.length >= 2 }
            raise UnsafeCutError, Text.t(:duong, :van_de_layer, layer: layer_name) if rows.empty?
            arr2 = pass_depths(tool)
            rows.each do |grp|
              outline = grp.closed && grp.points.length >= 4 ? grp.points : []
              arr5 = to_pairs(grp.points)
              next if arr5.length < 2
              arr2.each { |depth| write_pocket(lines, post, arr5, outline, tool, vars, depth) }
            end
          elsif kind == "profile"
            start = lines.length
            lock = path.metadata[:elem_lock]
            arr2 = pass_depths(tool)
            pass_starts = if lock && lock[:enabled] == true
                       write_locked(lines, post, path, tool, vars, lock, arr2)
                     else
                       write_closed(lines, post, path.points, tool, vars, arr2)
                     end
            arr4 << { layer: layer_name, start_index: start, end_index: lines.length, expected_passes: arr2.length,
                        start_xy: path.points.first, pass_reviews: pass_starts }
          elsif kind == "open_cut" && mark_square?(layer_name)
            write_mark(lines, post, path, tool, vars)
          elsif kind != "open_cut" && path.closed
            write_closed(lines, post, path.points, tool, vars, pass_depths(tool))
          else
            write_open(lines, post, path.points, tool, vars)
          end
          idx += arr.length
        end
        _935f8384 = base_vars(job_name, last_layer, paths.last.tool, post).merge("ZH" => post_float(post, "park_z", 50.0))
        emit(lines, post, "FOOTER", _935f8384)
        eol = Post.line_ending(post)
        _e71d2c44, h = tighten_arcs(number_lines(lines, post).join(eol) + eol, eol)
        result = _e71d2c44.join(eol)
        rows = eol == "\n" ? split_lines(result, eol) : _e71d2c44
        h = rows.map { |grp| parse_move(grp, nil) } unless rows == _e71d2c44
        arr4.each { |_dc76b888| assert_pass_closure(h, _dc76b888) }
        result
      end
      def canonical(arr)
        case arr
        when Hash then arr.to_h { |key, row| [key.to_s, canonical(row)] }.sort.to_h
        when Array then arr.map { |row| canonical(row) }
        when Symbol then arr.to_s
        else arr
        end
      end
      def write_closed(lines, post, out, tool, vars, arr)
        assert_ramp_fits(out, tool, arr)
        closed = out.length > 2 && same_xy?(out.first, out.last)
        arr.each_with_index.with_object([]) do |(depth, _2b9ddb2e), pass_starts|
          move_to_start(lines, post, vars, x: out.first[0], y: out.first[1], tool: tool)
          rest = write_entry(lines, post, out, tool, vars, depth)
          num = rest.length >= 2 ? rest : out
          pass_starts << pass_start_point(tool, num) if closed
          write_path(lines, post, vars, num, tool, _2b9ddb2e == arr.length - 1 ? slow_length(tool) : 0.0)
          rapid(lines, post, vars, z: z(tool))
        end
      end
      def write_open(lines, post, out, tool, vars)
        arr = simplify_open(out.map { |arr2| [arr2[0].to_f, arr2[1].to_f] })
        return if arr.length < 2
        arr3 = pass_depths(tool)
        assert_ramp_fits(arr, tool, arr3)
        arr3.each do |depth|
          move_to_start(lines, post, vars, x: arr.first[0], y: arr.first[1], tool: tool)
          rest = write_entry(lines, post, arr, tool, vars, depth)
          write_path(lines, post, vars, rest, tool, 0.0) if rest.length >= 2
          rapid(lines, post, vars, z: z(tool))
        end
      end
      def write_locked(lines, post, path, tool, vars, lock, arr)
        out = ring(path.points.map { |pt| [pt[0].to_f, pt[1].to_f] })
        fail = Text.t(:duong, :van_de_layer, layer: path.layer)
        raise UnsafeCutError, fail if out.length < 4
        elems = lock[:elems]
        schema = lock[:schema].to_s
        per_row, _540fe238 = schema_tolerance(schema)
        if per_row && lock[:start_checked] == true && lock[:start_err_mm].to_f <= EXACT_START_MM &&
           lock[:cache_schema].to_s == _540fe238 && same_points?(lock[:plan_points], out)
          raise UnsafeCutError, fail if Array(elems).empty?
        else
          _b7d2a364 = Locked.align(elems, out,
                                 align_tol_mm: per_row ? EXACT_START_MM : (lock[:align_tol_mm] || 0.03).to_f,
                                 shape_tol_mm: per_row || 0.02,
                                 sample_tol_mm: (lock[:sample_tol_mm] || (per_row ? ARC_SAMPLE_MM : 0.005)).to_f)
          raise UnsafeCutError, fail unless _b7d2a364.ok && (!per_row || _b7d2a364.align_error_mm.to_f <= EXACT_START_MM)
          elems = _b7d2a364.elems
        end
        assert_ramp_fits(out, tool, arr)
        slow_len = slow_length(tool)
        index_paths = {}
        arr.each_with_index.with_object([]) do |(depth, _2b9ddb2e), pass_starts|
          move_to_start(lines, post, vars, x: out.first[0], y: out.first[1], tool: tool)
          rest = write_entry(lines, post, out, tool, vars, depth)
          num = rest.length >= 2 ? rest : out
          pass_starts << pass_start_point(tool, num)
          num2 = slow_len <= 1.0e-9 && num.length == out.length &&
                  num.zip(out).all? { |a, b| Calc.distance(a, b) <= 0.001 }
          raise UnsafeCutError, Text.t(:duong, :khong_giam_toc, layer: path.layer) if !num2 && schema == REGION_SCHEMA
          key = num2 || (_2b9ddb2e == arr.length - 1 ? slow_len : 0.0)
          num3 = lines.length
          if index_paths.key?(key)
            lines.concat(index_paths[key])
          elsif num2
            write_elements(lines, post, vars, elems, tool["feed"])
          else
            cut_path(lines, post, vars, num, tool, key)
          end
          index_paths[key] ||= lines[num3..]
          rapid(lines, post, vars, z: z(tool))
        end
      end
      def write_elements(lines, post, vars, elems, feed)
        _744d6cbf = Text.t(:duong, :van_de)
        raise UnsafeCutError, _744d6cbf if elems.empty?
        cur = elems.first[:s].map(&:to_f)
        first = true
        elems.each do |arr2|
          arr = arr2[:s].map(&:to_f)
          arr3 = arr2[:e].map(&:to_f)
          raise UnsafeCutError, _744d6cbf if Calc.distance(cur, arr) > WRITER_TOLERANCE_MM
          case arr2[:type]
          when :line
            num = lines.length
            feed_move(lines, post, vars, x: arr3[0], y: arr3[1], feed: feed, first: first)
            assert_move_matches(lines[num..], :line, arr, arr3, nil, nil)
            cur = arr3
          when :arc
            center = arr2[:c].map(&:to_f)
            cw = !arr2[:ccw]
            _1bf23692 = [center[0] * 2.0 - arr[0], center[1] * 2.0 - arr[1]] if arr2[:full_circle]
            arr29 = _1bf23692 ? [[arr, _1bf23692], [_1bf23692, arr]] : [[arr, arr3]]
            arr29.each do |arr5, arr6|
              arr4 = []
              arc_move(arr4, post, vars, x: arr6[0], y: arr6[1], i: center[0] - arr5[0],
                                                j: center[1] - arr5[1], feed: feed, clockwise: cw, first: first)
              raise UnsafeCutError, Text.t(:post, :cung_khong_an_toan, post: post["post_name"]) unless arc_is_safe?(arr4, arr5)
              assert_move_matches(arr4, :arc, arr5, arr6, center, cw)
              lines.concat(arr4)
              first = false
              cur = arr6
            end
          else
            raise UnsafeCutError, _744d6cbf
          end
          first = false
        end
      end
      def write_bore(lines, post, paths, tool, vars)
        entries = paths.map { |path| path.points.first }.compact
        raise UnsafeCutError, Text.t(:duong, :van_de) if entries.empty?
        entries.product(pass_depths(tool)).each do |arr, depth|
          move_to_start(lines, post, vars, x: arr[0], y: arr[1], tool: tool)
          write_bore_entry(lines, post, vars, tool, depth)
          rapid(lines, post, vars, z: z(tool))
        end
      end
      def write_pocket(lines, post, path, outline, tool, vars, depth)
        x, y = path.first
        if %w[helix helix_ramp].include?(tool["entry_mode"].to_s) && write_helix_entry(lines, post, outline, tool, vars, depth, path.first)
          feed_move(lines, post, vars, x: x, y: y, z: depth, feed: tool["feed"], first: false)
          rest = path
        else
          move_to_start(lines, post, vars, x: x, y: y, tool: tool)
          assert_ramp_fits(path, tool, [depth])
          rest = write_entry(lines, post, path, tool, vars, depth)
        end
        write_path(lines, post, vars, rest, tool, 0.0) if rest.length >= 2
        rapid(lines, post, vars, z: z(tool))
      end
      def slow_feed(tool)
        num = tool["toc_do_giam_toc"].to_f
        num.positive? ? num : tool["feed"].to_f
      end
      def slow_length(tool)
        tool["tu_dong_giam_toc"] == true ? [tool["khoang_cach_giam_toc"].to_f, 0.0].max : 0.0
      end
      def write_path(lines, post, vars, out, tool, slow_len)
        num3 = lines.length
        num2 = tool["feed"].to_f
        _d06e500c = slow_feed(tool)
        arr2 = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        return if arr2.length < 2
        key = arr2.flatten(1).push(slow_len).pack("G*")
        h6 = @path_memo
        flag = h6 && h6[0].equal?(post) && h6[1].equal?(vars) && h6[2].equal?(tool)
        return lines.concat(h6[4]) if flag && h6[3] == key
        arr3 = Compressor.compress(arr2, tolerance_mm: 0.025)
        return if arr3.empty?
        total = Calc.kahan_sum(arr3.map { |arr| arr[:length] })
        slow_dist = [slow_len, total].min
        fast_dist = total - slow_dist
        if slow_dist > 1.0e-6 && fast_dist > 1.0e-6 && fast_dist < total - 1.0e-6
          arr3 = Compressor.split_at_length(arr3, fast_dist)
        end
        num = 0.0
        last_feed = nil
        arr3.each do |arr|
          length = arr[:length]
          next if length <= 1.0e-7
          feed = slow_dist > 1.0e-6 && num >= fast_dist - 1.0e-6 ? _d06e500c : num2
          first2 = last_feed.nil? || (feed - last_feed).abs > 1.0e-6
          run_batch = arr[:finish]
          if arr[:type] == :arc
            start = arr[:start]
            center = arr[:center]
            arr4 = []
            arc_move(arr4, post, vars, x: run_batch[0], y: run_batch[1], i: center[0] - start[0], j: center[1] - start[1],
                                              feed: feed, clockwise: !!arr[:clockwise], first: first2)
            if arc_is_safe?(arr4, start)
              lines.concat(arr4)
            else
              boundary = Array(arr[:source_points])
              (boundary.length >= 2 ? boundary.drop(1) : [run_batch]).each_with_index do |pt, num4|
                feed_move(lines, post, vars, x: pt[0], y: pt[1], feed: feed, first: first2 && num4.zero?)
              end
            end
          else
            feed_move(lines, post, vars, x: run_batch[0], y: run_batch[1], feed: feed, first: first2)
          end
          last_feed = feed
          num += length
        end
        @path_memo = [post, vars, tool, key, lines[num3..]]
      rescue StandardError => err
        lines.slice!(num3..)
        raise if err.is_a?(UnsafeCutError)
        arr5 = arr2.each_cons(2).map { |a, b| Calc.distance(b, a) }
        total = Calc.kahan_sum(arr5)
        slow_dist = [slow_len, total].min
        fast_dist = total - slow_dist
        num = 0.0
        first = true
        arr5.each_with_index do |length, idx|
          next if length <= 1.0e-7
          feed = slow_dist > 1.0e-6 && num >= fast_dist - 1.0e-6 ? _d06e500c : num2
          feed_move(lines, post, vars, x: arr2[idx + 1][0], y: arr2[idx + 1][1], feed: feed, first: first)
          first = false
          num += length
        end
      end
      def cut_path(lines, post, vars, out, tool, slow_len)
        rows = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        return if rows.length < 2
        arr2 = rows.each_cons(2).map { |row0, last_rect| Calc.distance(last_rect, row0) }
        total = Calc.kahan_sum(arr2)
        slow_dist = [slow_len, total].min
        fast_dist = total - slow_dist
        num = 0.0
        first = true
        rows.each_cons(2).with_index do |(row0, last_rect), idx|
          length = arr2[idx]
          next if length <= 1.0e-9
          _65539b98 = row0
          if slow_dist > 1.0e-9 && num < fast_dist - 1.0e-9 && num + length > fast_dist + 1.0e-9
            arr = Calc.lerp(row0, last_rect, (fast_dist - num) / length)
            feed_move(lines, post, vars, x: arr[0], y: arr[1], feed: tool["feed"], first: first)
            first = false
            _65539b98 = arr
          end
          feed = slow_dist > 1.0e-9 && num + length >= fast_dist - 1.0e-9 ? slow_feed(tool) : tool["feed"].to_f
          unless same_xy?(_65539b98, last_rect)
            feed_move(lines, post, vars, x: last_rect[0], y: last_rect[1], feed: feed, first: first)
            first = false
          end
          num += length
        end
      end
      def rapid(lines, post, vars, x: nil, y: nil, z: nil)
        assert_finite("G00", "X" => x, "Y" => y, "Z" => z)
        emit(lines, post, "RAPID_MOVE", move_vars(vars, x: x, y: y, z: z))
      end
      def feed_move(lines, post, vars, x: nil, y: nil, z: nil, feed:, first: false)
        assert_finite("G01", "X" => x, "Y" => y, "Z" => z, "F" => feed)
        blk = first ? "FIRST_FEED_MOVE" : "FEED_MOVE"
        flag = z ? [] : lines
        emit(flag, post, blk, move_vars(vars, x: x, y: y, z: z, f: feed))
        raise UnsafeCutError, Text.t(:post, :thieu_z, post: post["post_name"], block: blk) if z && !has_z?(flag)
        z ? lines.concat(flag) : lines
      end
      def arc_move(lines, post, vars, x:, y:, i:, j:, feed:, clockwise:, first:)
        assert_finite(clockwise ? "G02" : "G03", "X" => x, "Y" => y, "I" => i, "J" => j, "F" => feed)
        emit(lines, post, arc_block_name(clockwise, first), move_vars(vars, x: x, y: y, i: i, j: j, f: feed))
      end
      def helix_move(lines, post, vars, x:, y:, z:, i:, feed:, first:)
        assert_finite("G02", "X" => x, "Y" => y, "Z" => z, "I" => i, "J" => 0.0, "F" => feed)
        blk = first ? "FIRST_CW_ARC_MOVE" : "CW_ARC_MOVE"
        arr = []
        emit(arr, post, blk, move_vars(vars, x: x, y: y, z: z, i: i, j: 0.0, f: feed))
        raise UnsafeCutError, Text.t(:post, :thieu_z, post: post["post_name"], block: blk) unless has_z?(arr)
        lines.concat(arr)
      end
      def assert_finite(meta, vars)
        vars.each do |axis, num|
          raise UnsafeCutError, Text.t(:duong, :toa_do_loi, lenh: meta, truc: axis) unless num.nil? || num.to_f.finite?
        end
      end
      def arc_block_name(cw, first)
        "#{first ? 'FIRST_' : ''}#{cw ? "CW" : "CCW"}_ARC_MOVE"
      end
      def move_vars(normal, x: nil, y: nil, z: nil, i: nil, j: nil, f: nil)
        unless @vars_memo.equal?(normal)
          @arr22 = normal.merge("SAFE_Z" => normal["SAFEZ"], "APPROACH_Z" => normal["APPROACHZ"])
          @vars_memo = normal
        end
        @arr22.merge!("X" => x, "Y" => y, "Z" => z, "I" => i, "J" => j, "F" => f, "CUT_Z" => z)
      end
      def emit(lines, post, block, vars)
        arr28 = []
        arr = Post.render_block(post, block, vars, arr28)
        return if arr.empty? && block == "NEW_SEGMENT"
        raise UnsafeCutError, Text.t(:post, :thieu_block, post: post["post_name"], block: block) if arr.empty?
        return lines.concat(arr) unless arr.any? { |arr2| arr2.include?("[") }
        if arr28.all?("[N]") && post["blocks"][block].is_a?(Array) && arr.all?(&:valid_encoding?)
          num = arr.inject(0) { |acc2, arr2| acc2 + arr2.count("[") }
          return lines.concat(arr) if num == arr28.length
        end
        arr3 = arr.flat_map { |arr2| arr2.scan(/\[[A-Z0-9_]+\]/i) }.uniq
        if arr3.include?("[N]")
          n_marks = post["blocks"][block].map { |arr2| arr2.scan("[N]").length }.inject(0, :+)
          partner = arr.map { |arr2| arr2.scan("[N]").length }.inject(0, :+)
          arr3.delete("[N]") if n_marks.positive? && partner <= n_marks
        end
        unless arr3.empty?
          raise UnsafeCutError, Text.t(:post, :bien_chua_thay, post: post["post_name"], block: block, bien: arr3.join(", "))
        end
        lines.concat(arr)
      end
      def emit_toolchange(lines, post, vars, tool)
        return if post["blocks"]["HEADER"].any? { |str| str.match?(/\[(?:T|TOOL_NUMBER)\]/i) }
        arr = Post.render_block(post, "TOOLCHANGE", vars)
        raise UnsafeCutError, Text.t(:post, :thieu_goi_dao, post: post["post_name"], so: [tool["number"].to_i, 1].max) if arr.empty?
        apply_face_materials = ->(str) { str.strip.gsub(/\s+/, " ").upcase }
        code_stamp = arr.map(&apply_face_materials).reject(&:empty?)
        lines.concat(arr) if code_stamp.empty? || !(code_stamp - lines.map(&apply_face_materials)).empty?
      end
      def base_vars(job_name, _59340cd9, tool, post)
        assert_tool_number(post, tool)
        z5 = z(tool)
        str = post["work_offset"].to_s.upcase.strip
        {
          "DATE" => Date.today.strftime("%d/%m/%Y"), "TIME" => Time.now.strftime("%H:%M:%S"),
          "TP_FILENAME" => ascii_label(job_name), "TOOLPATH_NAME" => ascii_label(_59340cd9),
          "TOOLNAME" => ascii_label(tool["name"]), "TOOL_NUMBER" => tool["number"].to_i,
          "TOOL_DIAMETER" => tool["diameter"].to_f, "TOOL_DIAMETER_2" => tool["diameter_2"].to_f,
          "TOOL_ANGLE" => tool["angle"].to_f, "TOOL_PASS" => tool["stepdown"].to_f,
          "TOOL_STEPOVER_PERCENT" => tool["step_pct"].to_f, "TOOL_COLOR" => tool["draw_color"].to_s,
          "T" => tool["number"].to_i, "S" => tool["rpm"].to_i, "F" => tool["feed"].to_f,
          "X" => 0.0, "Y" => 0.0, "Z" => z5, "I" => 0.0, "J" => 0.0,
          "ZH" => post_float(post, "home_z", 50.0), "XH" => post_float(post, "park_x", 0.0),
          "YH" => post_float(post, "park_y", 0.0),
          "WORK_OFFSET" => %w[G54 G55 G56 G57 G58 G59].include?(str) ? str : '', "SAFEZ" => z5
        }
      end
      def assert_tool_number(post, tool)
        number = [tool["number"].to_i, 1].max
        hi = post["max_tool_number"].to_i
        return unless hi.positive? && number > hi
        raise UnsafeCutError, Text.t(:post, :gioi_han_dao, post: post["post_name"], max: hi, dao: tool["name"], so: number)
      end
      def post_float(post, key, fallback)
        str = post[key]
        return fallback if str.nil? || str.to_s.strip.empty?
        Float(str)
      rescue ArgumentError, TypeError
        fallback
      end
      def ascii_label(text)
        to_ascii(text).tr("()", "[]").split.join(" ")
      end
      def to_ascii(text)
        String(text).each_char.map do |str|
          _99d69ef4 = str.downcase
          str2 = VI_ASCII[_99d69ef4]
          next(str == _99d69ef4 ? str2 : str2.upcase) if str2
          str.ord < 128 ? str : "_"
        end.join
      rescue StandardError
        String(text)
      end
      def number_lines(lines, post)
        return lines unless Post.numbered_lines?(post)
        number = post["line_number_start"].to_i
        num = [post["line_number_increment"].to_i, 1].max
        lines.map do |axis|
          _ade31fbe = Post.fill_tokens(axis, "N" => Post.format_token(post, "N", number))
          number += num if axis.include?("[N]")
          _ade31fbe
        end
      end
      def split_lines(result, eol)
        eol == "\r" ? result.split("\r", -1) : result.gsub("\r\n", "\n").split("\n", -1)
      end
      def assert_closed(path)
        out = path.points
        return if path.closed && out.length >= 4 && Calc.distance(out.first, out.last) <= CLOSED_GAP_MM
        raise UnsafeCutError, Text.t(:duong, :khong_khep_kin, layer: path.layer)
      end
      def pass_start_point(tool, arr)
        row0 = [arr.first[0].to_f, arr.first[1].to_f]
        gap2 = Calc.distance(row0, arr.last)
        return row0 if gap2.finite? && gap2 <= CLOSED_GAP_MM
        raise UnsafeCutError, Text.t(:duong, :van_de_cau_hinh, ten: ten(tool))
      end
      def assert_pass_closure(h, arr)
        _744d6cbf = Text.t(:post, :bien_khong_kin, layer: arr[:layer])
        rows = h[arr[:start_index]...arr[:end_index]] || []
        raise UnsafeCutError, _744d6cbf if rows.empty?
        start = arr[:start_xy]
        x, y = start
        mode = _cff6bef7 = nil
        done = 0
        rows.each do |partner, h2|
          mode = partner || mode
          x, y = h2.fetch("X", x), h2.fetch("Y", y)
          arr2 = h2.key?("X") || h2.key?("Y") || ([2, 3].include?(mode) && h2.keys.any? { |axis| %w[I J R].include?(axis) })
          if [1, 2, 3].include?(mode) && arr2
            _cff6bef7 = [x, y]
          elsif mode == 0 && h2.key?("Z") && _cff6bef7
            _37953fc6 = arr[:pass_reviews][done] || start
            gap2 = Calc.distance(_cff6bef7, _37953fc6)
            raise UnsafeCutError, _744d6cbf if !gap2.finite? || gap2 > CLOSED_GAP_MM
            done += 1
            _cff6bef7 = nil
          end
        end
        raise UnsafeCutError, _744d6cbf if _cff6bef7 || done != arr[:expected_passes]
      end
      def assert_cuts(txt3, _08f3e958)
        name = File.basename(_08f3e958)
        raise UnsafeCutError, Text.t(:post, :file_khong_cat, file: name) unless txt3.match?(/(?<![A-Za-z])G0?[123](?![0-9.])/i)
        arr = txt3.scan(/\[[A-Z0-9_]+\]/i).uniq.sort
        raise UnsafeCutError, Text.t(:post, :file_bien_chua_thay, file: name, bien: arr.join(", ")) unless arr.empty?
      end
      def assert_not_g90_1(result, post)
        arr = result.each_line(Post.line_ending(post) == "\r" ? "\r" : "\n").map do |axis|
          axis.include?("(") || axis.include?(";") ? axis.gsub(/\([^)]*\)/, '').split(";", 2).first.to_s : axis
        end.join("\n")
        return unless arr.match?(/(?<![A-Za-z])G90\.1(?![0-9])/i) &&
                      arr.match?(/(?<![A-Za-z])G0?[23](?![0-9.])[^\n]*(?<![A-Za-z])[IJ]/i)
        raise UnsafeCutError, Text.t(:post, :g90_1)
      end
      def assert_move_matches(arr4, _ddd00a97, arr, arr3, arr2, cw)
        _9fc2d2da = Text.t(:post, :lech_bien)
        mode = partner = nil
        arr4.each do |axis|
          mode, h = parse_move(axis, mode)
          partner = [mode, h] if h.keys.any? { |axis2| %w[X Y I J R].include?(axis2) }
        end
        raise UnsafeCutError, _9fc2d2da unless partner
        mode, h = partner
        raise UnsafeCutError, _9fc2d2da unless mode == (_ddd00a97 == :line ? 1 : (cw ? 2 : 3))
        _43dc33e0, y_end = h.fetch("X", arr[0]), h.fetch("Y", arr[1])
        raise UnsafeCutError, _9fc2d2da if Math.hypot(_43dc33e0 - arr3[0], y_end - arr3[1]) > WRITER_TOLERANCE_MM
        return if _ddd00a97 == :line
        raise UnsafeCutError, _9fc2d2da unless h.key?("I") || h.key?("J")
        cx, _678e79b2 = arr[0] + h.fetch("I", 0.0), arr[1] + h.fetch("J", 0.0)
        raise UnsafeCutError, _9fc2d2da if Math.hypot(cx - arr2[0], _678e79b2 - arr2[1]) > WRITER_TOLERANCE_MM
        _8ec5a9b7 = Calc.distance(arr, arr2)
        _9599fdb0 = Math.hypot(arr[0] - cx, arr[1] - _678e79b2)
        _a2ea9541 = Math.hypot(_43dc33e0 - cx, y_end - _678e79b2)
        num = [(_9599fdb0 - _8ec5a9b7).abs, (_a2ea9541 - _8ec5a9b7).abs, (_9599fdb0 - _a2ea9541).abs].max
        raise UnsafeCutError, _9fc2d2da if num > WRITER_TOLERANCE_MM
      end
      def arc_is_safe?(arr2, arr)
        x, y = arr[0].to_f, arr[1].to_f
        mode = nil
        flag = false
        arr2.each do |axis|
          mode, h = parse_move(axis, mode)
          _43dc33e0, y_end = h.fetch("X", x), h.fetch("Y", y)
          if [2, 3].include?(mode)
            flag = true
            return false unless [x, y, _43dc33e0, y_end].all?(&:finite?)
            tol = arc_tolerance_of(axis)
            if h.key?("I") || h.key?("J")
              cx, _678e79b2 = x + h.fetch("I", 0.0), y + h.fetch("J", 0.0)
              return false unless [cx, _678e79b2].all?(&:finite?)
              _33109134 = Math.hypot(x - cx, y - _678e79b2)
              _1be704c2 = Math.hypot(_43dc33e0 - cx, y_end - _678e79b2)
              return false if _33109134 < MIN_ARC_R_MM || (_33109134 - _1be704c2).abs > tol
            elsif h.key?("R")
              r = h["R"].abs
              chord = Math.hypot(_43dc33e0 - x, y_end - y)
              return false if r < MIN_ARC_R_MM || chord <= 1.0e-9 || chord > 2.0 * r + tol
            else
              return false
            end
          end
          x = _43dc33e0
          y = y_end
        end
        flag
      end
      def post_supports_helix?(post, vars, r, depth, feed)
        _b575af80 = move_vars(vars, x: r, y: 0.0, z: depth, i: -r, j: 0.0, f: feed)
        %w[FIRST_CW_ARC_MOVE CW_ARC_MOVE].all? do |blk|
          arr = Post.render_block(post, blk, _b575af80)
          !arr.empty? && has_z?(arr)
        end
      end
      def has_z?(rows)
        rows.any? { |row| axis_words(row).key?("Z") }
      end
      def parse_move(axis, mode)
        arr, arr2 = [], {}
        th_txt = /(?<![A-Za-z])(?:G\s*([-+]?\d+(?:\.\d+)?)|([XYZIJKRF])\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)))/i
        strip_comments(axis).scan(th_txt) do |num2, str, num|
          num2 ? arr << num2.to_f : (arr2[str.upcase] = num.to_f)
        end
        partner = arr.rindex { |num| [0.0, 1.0, 2.0, 3.0].include?(num) }
        [partner ? arr[partner].to_i : mode, arr2, arr]
      end
      def strip_comments(axis)
        return axis unless axis.include?("(") || axis.include?(";")
        axis = axis.gsub(/\([^()]*\)/, '') while axis.match?(/\([^()]*\)/)
        axis.split(";", 2).first.to_s
      end
      def axis_words(axis)
        parse_move(axis, nil)[1]
      end
      def axis_digits(axis, arr)
        axis.scan(/([XYIJR])\s*[-+]?(?:\d+(?:\.(\d*))?|\.([0-9]+))/i).filter_map do |str, row0, _55d3a52b|
          (row0 || _55d3a52b).to_s.length if arr.include?(str.upcase)
        end
      end
      def arc_tolerance_of(axis)
        digits = (axis_digits(axis, %w[X Y I J R]).min || 3).clamp(3, 6)
        [0.0002, 10.0**(-digits) * 3.0].max
      end
      def tighten_arcs(result, eol)
        x = y = 0.0
        flag3, flag = true, false
        mode = nil
        h = []
        h4 = Hash.new { |h6, row| h6[row] = parse_move(row, nil) }
        h3 = Hash.new { |h6, row| h6[row] = arc_tolerance_of(row) }
        arr2 = split_lines(result, eol).map.with_index(1) do |axis, number|
          h << h4[axis]
          partner, h2, arr = h.last
          flag = true if arr.include?(90.1)
          flag = false if arr.include?(91.1)
          flag3 = true if arr.include?(90.0)
          flag3 = false if arr.include?(91.0)
          mode = partner || mode
          flag2 = h2.key?("X") ? (flag3 ? h2["X"] : x + h2["X"]) : x
          y_end = h2.key?("Y") ? (flag3 ? h2["Y"] : y + h2["Y"]) : y
          if [2, 3].include?(mode) && h2.keys.any? { |axis3| %w[X Y I J R].include?(axis3) }
            tol = h3[axis]
            _c3dd1bab = Text.t(:post, :cung_loi, dong: number)
            raise UnsafeCutError, _c3dd1bab unless [x, y, flag2, y_end].all?(&:finite?)
            if h2.key?("I") || h2.key?("J")
              cx = flag ? h2.fetch("I", x) : x + h2.fetch("I", 0.0)
              flag4 = flag ? h2.fetch("J", y) : y + h2.fetch("J", 0.0)
              raise UnsafeCutError, _c3dd1bab unless [cx, flag4].all?(&:finite?)
              _9599fdb0 = Math.hypot(x - cx, y - flag4)
              num = (_9599fdb0 - Math.hypot(flag2 - cx, y_end - flag4)).abs
              if num > tol || _9599fdb0 < MIN_ARC_R_MM
                flag5 = axis_digits(axis, %w[I J])
                flag5 = axis_digits(axis, %w[X Y]) if flag5.empty?
                digits = (flag5.max || 4).clamp(3, 6)
                center = arc_fit_error(x, y, flag2, y_end, cx, flag4, digits, tol)
                raise UnsafeCutError, _c3dd1bab unless center
                flag7 = Calc.round_to(flag ? center[0] : center[0] - x, digits)
                flag6 = Calc.round_to(flag ? center[1] : center[1] - y, digits)
                flag9 = flag ? flag7 : x + flag7
                flag8 = flag ? flag6 : y + flag6
                _f5f80624 = Math.hypot(x - flag9, y - flag8)
                num2 = (_f5f80624 - Math.hypot(flag2 - flag9, y_end - flag8)).abs
                raise UnsafeCutError, _c3dd1bab if _f5f80624 < MIN_ARC_R_MM || num2 > tol
                axis = set_axis_value(axis, "I", flag7, digits)
                axis = set_axis_value(axis, "J", flag6, digits)
                h[-1] = parse_move(axis, nil)
              end
            elsif h2.key?("R")
              r = h2["R"].abs
              chord = Math.hypot(flag2 - x, y_end - y)
              if r < MIN_ARC_R_MM || chord <= 1.0e-9 || chord > 2.0 * r + tol
                raise UnsafeCutError, Text.t(:post, :cung_r, dong: number)
              end
            else
              raise UnsafeCutError, _c3dd1bab
            end
          end
          x, y = flag2, y_end
          axis
        end
        [arr2, h]
      end
      def arc_fit_error(x, y, _43dc33e0, y_end, _2cb6303b, _82b7c66d, digits, tol)
        _fa4482a3, _db5cf9ab = _43dc33e0 - x, y_end - y
        chord = Math.hypot(_fa4482a3, _db5cf9ab)
        return nil if chord <= 1.0e-9
        _12a9205b, _619826f2 = (x + _43dc33e0) * 0.5, (y + y_end) * 0.5
        _5869632a, _785c570a = -_db5cf9ab / chord, _fa4482a3 / chord
        offset_path = (_2cb6303b - _12a9205b) * _5869632a + (_82b7c66d - _619826f2) * _785c570a
        _b86f881f, _a977cbe6 = _12a9205b + offset_path * _5869632a, _619826f2 + offset_path * _785c570a
        return nil if Math.hypot(_b86f881f - _2cb6303b, _a977cbe6 - _82b7c66d) > 0.25
        num = 10.0**(-digits)
        _ff2dfcfd = Calc.round_to(_b86f881f, digits)
        _58e4d5f7 = Calc.round_to(_a977cbe6, digits)
        num2 = _fa4482a3 * (_82b7c66d - _619826f2) - _db5cf9ab * (_2cb6303b - _12a9205b)
        best = nil
        (-16..16).each do |dx|
          (-16..16).each do |dy|
            px, py = _ff2dfcfd + dx * num, _58e4d5f7 + dy * num
            ctrl = Math.hypot(px - _2cb6303b, py - _82b7c66d)
            next if ctrl > 0.25
            next if num2.abs > num && (_fa4482a3 * (py - _619826f2) - _db5cf9ab * (px - _12a9205b)) * num2 < 0.0
            _33109134 = Math.hypot(x - px, y - py)
            next if _33109134 < MIN_ARC_R_MM
            num3 = (_33109134 - Math.hypot(_43dc33e0 - px, y_end - py)).abs
            next if num3 > tol
            path = { error: num3, center_shift: ctrl, x: Calc.round_to(px, digits), y: Calc.round_to(py, digits) }
            best = path if better_arc?(path, best)
          end
        end
        best && [best[:x], best[:y]]
      end
      def better_arc?(path, best)
        return true unless best
        %i[center_shift error x].each do |key|
          delta = path[key] - best[key]
          return true if delta < -ARC_EQ_EPS
          return false if delta > ARC_EQ_EPS
        end
        path[:y] < best[:y] - ARC_EQ_EPS
      end
      def set_axis_value(axis, axis4, val, digits)
        _b8a0ce04 = format("%.#{digits}f", val)
        num = [axis.index(";"), axis.index("(")].compact.min || axis.length
        err_code, arr = axis[0...num], axis[num..]
        _98a1729e = /(#{axis4}\s*)[-+]?(?:\d+(?:\.\d*)?|\.\d+)/i
        err_code = err_code.match?(_98a1729e) ? err_code.sub(_98a1729e) { "#{$1}#{_b8a0ce04}" } : "#{err_code.rstrip} #{axis4}#{_b8a0ce04}"
        arr.empty? ? err_code : "#{err_code.rstrip} #{arr}".rstrip
      end
    end
  end
end
