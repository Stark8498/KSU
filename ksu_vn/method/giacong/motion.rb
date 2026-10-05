module KSU
  module Cnc
    module Export
      module_function
      def pocket_fits?(outline, diameter)
        polygon = dedupe(outline)
        return false if polygon.length < 3
        arr2 = polygon.map(&:first)
        arr = polygon.map(&:last)
        [arr2.max - arr2.min, arr.max - arr.min].min > diameter * 0.95
      end
      def pocket_paths(outline, tool, diameter)
        paths = pocket_fits?(outline, diameter) ? scan_lines(outline, step_over(tool, diameter)) : []
        arr2 = dedupe(orient(ring(outline), tool))
        return paths if arr2.length < 3
        last_rect = paths.last
        arr = last_rect && rotate_to_reachable(arr2, last_rect.last, outline)
        return paths << ring(rotate_to_corner(arr2, tool["entry_corner"])) unless arr
        last_rect << arr.first unless same_xy?(last_rect.last, arr.first)
        paths[-1] = to_pairs(last_rect.concat(arr[1..]))
        paths
      end
      def scan_lines(outline, step)
        polygon = dedupe(outline)
        return [] if polygon.length < 3
        lx, arr2 = polygon.map(&:first).minmax
        ly, arr = polygon.map(&:last).minmax
        row_w = arr2 - lx
        _bf071a8c = arr - ly
        return [] if row_w <= 0.001 || _bf071a8c <= 0.001
        oy4 = _bf071a8c >= row_w
        _fe479353, long_axis = oy4 ? [lx, row_w] : [ly, _bf071a8c]
        want = (long_axis / step).ceil
        return [] if want <= 1
        num = long_axis / want.to_f
        paths = []
        cur = nil
        (1...want).each do |idx|
          segments = crossings_at(polygon, _fe479353 + num * idx, oy4)
          next if segments.empty?
          at_start = idx.odd?
          segments.reverse! unless at_start
          segments.each do |seg|
            start, run_batch = at_start ? seg : seg.reverse
            if cur && segment_inside?(cur.last, start, polygon)
              cur << start unless same_xy?(cur.last, start)
              cur << run_batch unless same_xy?(cur.last, run_batch)
            else
              paths << to_pairs(cur) if cur
              cur = [start, run_batch]
            end
            at_start = !at_start if segments.length > 1
          end
        end
        paths << to_pairs(cur) if cur
        paths.select { |path| path.length >= 2 }
      end
      def crossings_at(polygon, index, oy4)
        flag = axis_crossings(polygon, index, oy4 ? 0 : 1, 1.0e-9)
        ordered = flag.each_with_object([]) do |val, vars|
          vars << val if vars.empty? || (vars.last - val).abs > 0.001
        end
        ordered.each_slice(2).filter_map do |row0, last_rect|
          next if last_rect.nil? || (last_rect - row0).abs <= 0.01
          oy4 ? [[index, row0], [index, last_rect]] : [[row0, index], [last_rect, index]]
        end
      end
      def axis_crossings(rows, val, axis, eps)
        panel = 1 - axis
        arr2 = []
        rows.each_index do |idx|
          arr = rows[idx]
          b = rows[(idx + 1) % rows.length]
          next if (b[axis] - arr[axis]).abs <= eps
          next unless (arr[axis] <= val && val < b[axis]) || (b[axis] <= val && val < arr[axis])
          arr2 << arr[panel] + (b[panel] - arr[panel]) * ((val - arr[axis]) / (b[axis] - arr[axis]))
        end
        arr2.sort
      end
      def link_scan_lines(arr4, region, tool)
        paths = []
        cur = nil
        arr4.each_with_index do |_625ebd43, num|
          arr3 = dedupe(_625ebd43)
          next if arr3.length < 3
          arr2 = ring(rotate_to_corner(arr3, tool["entry_corner"]))
          unless num.zero?
            pt = cur.last
            arr = segment_inside?(pt, arr2.first, region) && arr2
            arr ||= rotate_to_reachable(arr3, pt, region)
            if arr
              cur << arr.first unless same_xy?(cur.last, arr.first)
              cur.concat(arr[1..])
              next
            end
            paths << to_pairs(cur)
          end
          cur = arr2
        end
        paths << to_pairs(cur) if cur
        paths.select { |path| path.length >= 2 }
      end
      def rotate_to_reachable(arr, from_pt, region)
        start = arr.each_index.sort_by { |idx| Calc.distance(arr[idx], from_pt) }
                    .find { |idx| segment_inside?(from_pt, arr[idx], region) }
        start && ring(arr.rotate(start))
      end
      def segment_inside?(a, b, polygon)
        num = (Calc.distance(b, a) / 0.5).ceil.clamp(8, 200)
        (0..num).all? do |idx|
          pt = Calc.lerp(a, b, idx / num.to_f)
          Calc.in_polygon?(pt[0], pt[1], polygon)
        end
      end
      def inner_contour(boundary, tool, diameter)
        return nil if boundary.length < 3 || Calc.signed_area(boundary).abs <= 0.01
        cur = offset_native(boundary, diameter * 0.5, "inside")
        return nil unless valid_loop?(cur)
        return nil if self_intersects?(cur) || inverted?(cur, boundary, true)
        step = step_over(tool, diameter)
        loops = []
        500.times do
          outer_loop = dedupe(cur)
          break unless valid_loop?(outer_loop)
          break if self_intersects?(outer_loop) || inverted?(outer_loop, boundary, true)
          loops << ring(outer_loop)
          cur = spiral_contours(outer_loop, step, diameter)
          break unless cur
        end
        loops.empty? ? nil : loops
      end
      def spiral_contours(outer_loop, first_loop, diameter)
        area_sign = Calc.signed_area(outer_loop)
        lo = [diameter * 0.18, 0.20].max
        steps = [first_loop]
        steps << steps.last * 0.78 while steps.length < 10
        (steps.select { |_5d951b22| _5d951b22 >= lo } << lo).uniq.each do |path|
          arr = offset_native(outer_loop, path, "inside")
          next if !valid_loop?(arr) || self_intersects?(arr)
          num = Calc.signed_area(arr)
          next if area_sign * num <= 0.0 || num.abs >= area_sign.abs - 0.0001
          return arr if arr.all? { |pt| Calc.in_polygon?(pt[0], pt[1], outer_loop) }
        end
        nil
      end
      def valid_loop?(out)
        return false unless out && out.length >= 3 && Calc.signed_area(out).abs > 0.01
        out.all? { |pt| pt[0].finite? && pt[1].finite? }
      end
      def clear_pocket(boundary, tool, r, diameter)
        arr = offset_inside(boundary, r)
        return clear_split_pocket(boundary, tool, r, diameter, arr) || pocket_error(arr[:error]) unless arr[:ok]
        outline = ring(arr[:path])
        return pocket_error unless valid_loop?(outline) && !self_intersects?(outline)
        paths = pocket_paths(outline, tool, diameter)
        paths.empty? ? pocket_error : { paths: paths }
      end
      def clear_split_pocket(boundary, tool, r, diameter, arr2)
        arr = Array(arr2[:disconnected_loops]).filter_map do |loop_pts|
          outer_loop = dedupe(loop_pts)
          outer_loop = dedupe(smooth_loop(outer_loop, 0.02)) if outer_loop.length > 24
          next if outer_loop.length < 3 || self_intersects?(outer_loop) || Calc.signed_area(outer_loop).abs <= 0.01
          ring(outer_loop)
        end
        return nil if arr.length < 2
        paths = arr.flat_map do |outline|
          pocket_paths(outline, tool, diameter).tap { |rows| return nil if rows.empty? }
        end
        limit = [r - POCKET_CLEARANCE_MM, 0.0].max
        idx = inside_index(boundary, r)
        cache = {}
        _5a8d3b41 = [0]
        rest = (1...arr.length).to_a
        until rest.empty?
          best = nil
          _5a8d3b41.product(rest).each do |a, b|
            h = cache.fetch([a, b]) do
              cache[[a, b]] = link_gap(arr[a], arr[b], boundary, limit, idx)
            end
            best = h.merge(to_index: b) if h && (best.nil? || h[:length] < best[:length])
          end
          return nil unless best
          paths << [best[:from], best[:to]]
          _5a8d3b41 << best[:to_index]
          rest.delete(best[:to_index])
        end
        ok = { paths: paths, safety_checked: true }
        ok if paths_safe?(ok, boundary, r, nil, idx)
      end
      def link_gap(loop_a, loop_b, boundary, limit, idx)
        arr = bbox_link(loop_a, loop_b, boundary, limit, idx)
        per_row = arr ? arr[:length] : Float::INFINITY
        h7 = sample_points(loop_a).product(sample_points(loop_b)).filter_map do |row0, _55d3a52b|
          length = Calc.distance(_55d3a52b, row0)
          [length, row0, _55d3a52b] unless length <= 0.00001 || length >= per_row
        end
        h7.sort_by! { |arr2| arr2[0] }
        hit = h7.first(2000).find { |_3b599ee5, row0, _55d3a52b| link_clear?(row0, _55d3a52b, boundary, limit, idx) }
        hit ? { from: hit[1], to: hit[2], length: hit[0] } : arr
      end
      def bbox_link(loop_a, loop_b, boundary, limit, idx)
        arr2, arr5 = [loop_a, loop_b].map { |loop_pts| [loop_pts.map(&:first).minmax, loop_pts.map(&:last).minmax] }
        arr3 = []
        [1, 0].each do |axis|
          _fe479353 = [arr2[axis][0], arr5[axis][0]].max
          _aae2b052 = [arr2[axis][1], arr5[axis][1]].min
          next unless _aae2b052 >= _fe479353
          sample_between(_fe479353, _aae2b052).each do |val|
            spans_at(loop_a, val, axis).product(spans_at(loop_b, val, axis)).each do |arr, b|
              arr4, flag = arr[1] <= b[0] ? [arr, b] : (b[1] <= arr[0] ? [b, arr] : [nil, nil])
              next unless arr4
              start = arr4[1] - 0.002
              run_batch = flag[0] + 0.002
              a = axis == 1 ? [start, val] : [val, start]
              b3 = axis == 1 ? [run_batch, val] : [val, run_batch]
              arr3 << { from: a, to: b3, length: run_batch - start } if link_clear?(a, b3, boundary, limit, idx)
            end
          end
        end
        arr3.min_by { |arr6| arr6[:length] }
      end
      def sample_between(lo, hi)
        long_axis = hi - lo
        return [lo] if long_axis.abs <= 0.000001
        [0.5, 0.25, 0.75, 0.1, 0.9].map { |_5f343815| lo + long_axis * _5f343815 }.uniq
      end
      def spans_at(loop_pts, val, axis)
        arr2 = axis_crossings(dedupe(loop_pts), val, axis, 1.0e-12)
        arr2.each_slice(2).select { |arr| arr.length == 2 && arr[1] > arr[0] }
      end
      def sample_points(loop_pts)
        rows = dedupe(loop_pts)
        num = [1, (rows.length / 80.0).ceil].max
        (0...rows.length).step(num).flat_map do |idx|
          [rows[idx], Calc.lerp(rows[idx], rows[(idx + 1) % rows.length], 0.5)]
        end
      end
      def raster_pocket(boundary, tool, r, diameter)
        arr2 = boundary.map(&:first)
        arr = boundary.map(&:last)
        row_w = arr2.max - arr2.min
        _bf071a8c = arr.max - arr.min
        _818af234, _e9c7091a = [row_w, _bf071a8c].minmax
        return nil if _e9c7091a <= diameter + 0.01 || _818af234 < diameter - 0.001 || _818af234 > diameter + 0.05
        axis, bnds = row_w >= _bf071a8c ? [1, arr] : [0, arr2]
        _81d960e2 = bnds.min + r
        _a7411ce7 = bnds.max - r
        return nil if _a7411ce7 < _81d960e2 - 0.001
        limit = [r - 0.005, 0.0].max
        idx = inside_index(boundary, r)
        paths = []
        ([_81d960e2, _a7411ce7] + sample_between(_81d960e2, _a7411ce7)).uniq.each do |val|
          spans_at(boundary, val, axis).each do |_fe479353, _aae2b052|
            start = _fe479353 + r
            run_batch = _aae2b052 - r
            next if run_batch - start <= 0.01
            row0 = axis == 1 ? [start, val] : [val, start]
            last_rect = axis == 1 ? [run_batch, val] : [val, run_batch]
            paths << [row0, last_rect] if link_clear?(row0, last_rect, boundary, limit, idx)
          end
        end
        return nil if paths.empty?
        paths.uniq! { |path| path.flatten.map { |val| (val * 1000.0).round } }
        return nil unless trim_raster(paths, boundary, r, axis, bnds)
        corner = tool["entry_corner"].to_s.downcase
        paths.map!(&:reverse) if axis == 1 ? corner.include?("right") : (corner.include?("top") || corner.include?("upper"))
        { paths: paths, safety_checked: true }
      end
      def trim_raster(paths, rows, r, axis, bnds)
        segments = paths.flat_map { |path| to_pairs(path).each_cons(2).to_a }
        per_row = r + 0.01
        num2 = 0
        packed = lambda do |pt|
          flag = segments.any? { |a, b| Calc.segment_distance(pt, a, b) <= per_row }
          flag && (num2 += 1) <= 500_000
        end
        rows.zip(rows.rotate).each do |row0, last_rect|
          want = (Calc.distance(last_rect, row0) / 0.20).ceil.clamp(1, 50_000)
          0.upto(want) { |_5d951b22| return false unless packed.call(Calc.lerp(row0, last_rect, _5d951b22 / want.to_f)) }
        end
        _8ef7f40e = bnds.min + 0.05
        _e4f12bf3 = bnds.max - 1.0e-9
        while _8ef7f40e < _e4f12bf3
          spans_at(rows, _8ef7f40e, axis).each do |_fe479353, _aae2b052|
            want = ((_aae2b052 - _fe479353) / 0.50).ceil.clamp(1, 100_000)
            0.upto(want) do |_5d951b22|
              num = _fe479353 + (_aae2b052 - _fe479353) * (_5d951b22 / want.to_f)
              return false unless packed.call(axis == 1 ? [num, _8ef7f40e] : [_8ef7f40e, num])
            end
          end
          _8ef7f40e += 0.10
        end
        true
      end
      def rotate_entry(out, tool)
        arr2 = ring(out.map { |arr4| [arr4[0].to_f, arr4[1].to_f] })
        return arr2 if arr2.length < 4 || !auto_corner?(tool["entry_corner"])
        lock_open = arr2[0...-1]
        arr3 = Calc.kahan_sum(lock_open.zip(lock_open.rotate).map { |pt, f_adj| Calc.distance(f_adj, pt) })
        r = tool["diameter"].to_f.abs * 0.5
        num = r * Math::PI * 0.25
        return arr2 if arr3 <= 0.001 || !num.positive?
        arr = shift_lead(arr2, arr3 - [num, arr3 * 0.20].min)
        circle = lock_open.length >= 4 && Calc.circle_through(lock_open.first, lock_open[-1], lock_open[-2])
        if circle && (circle[:radius] - r).abs <= [0.25, r * 0.15].max
          center = circle[:center]
          run_batch = Calc.deg4(lock_open.first, center)
          delta = Calc.wrap_pi(run_batch - Calc.deg4(lock_open[-1], center))
          deg4 = delta.negative? ? run_batch + Math::PI * 0.25 : run_batch - Math::PI * 0.25
          h = [center[0] + circle[:radius] * Math.cos(deg4), center[1] + circle[:radius] * Math.sin(deg4)]
          _4516f300 = arr[0]
          per_row = (r * 0.05).clamp(0.25, 0.75)
          if Calc.distance(h, _4516f300) <= per_row &&
             Calc.distance(h, arr[1]) <= Calc.distance(_4516f300, arr[1]) + per_row &&
             Calc.distance(arr[-2], h) <= Calc.distance(arr[-2], _4516f300) + per_row
            arr[0] = h
            arr[-1] = h.dup
          end
        end
        same_shape?(arr, arr2) ? arr : arr2
      end
      def same_shape?(path, boundary)
        rows = ring(path.map { |arr| [arr[0].to_f, arr[1].to_f] })
        normal = ring(boundary.map { |arr| [arr[0].to_f, arr[1].to_f] })
        return false if rows.length < 4 || normal.length < 4
        [[rows.first, rows[1]], [rows[-2], rows.first]].all? do |row0, last_rect|
          length = Calc.distance(row0, last_rect)
          next true if length <= ZERO_LEN_MM
          steps = (length / 0.50).ceil.clamp(2, 256)
          (0..steps).all? { |idx| Calc.contour_distance(Calc.lerp(row0, last_rect, idx.to_f / steps), normal) <= 0.05 }
        end
      end
      def shift_lead(out, num)
        arr = out.map { |arr4| [arr4[0].to_f, arr4[1].to_f] }
        arr.pop while arr.length > 1 && same_xy?(arr.first, arr.last)
        return ring(arr) if arr.length < 3 || num.abs < 0.0001
        want = arr.length
        arr3 = (0...want).map { |i| Calc.distance(arr[(i + 1) % want], arr[i]) }
        _6b6d259b = Calc.kahan_sum(arr3)
        return ring(arr) if _6b6d259b <= 0.0001
        _692d1426 = num % _6b6d259b
        idx = (0...want).find do |i|
          hit = arr3[i] > 0.000001 && _692d1426 <= arr3[i]
          _692d1426 -= arr3[i] unless hit
          hit
        end
        return ring(arr) unless idx
        start = Calc.lerp(arr[idx], arr[(idx + 1) % want], _692d1426 / arr3[idx])
        arr2 = arr.rotate(idx + 1)
        arr2.shift while arr2.length > 1 && same_xy?(arr2.first, start)
        arr2.pop while arr2.length > 1 && same_xy?(arr2.last, start)
        arr2.unshift(start) << start
      end
      def split_ramp(out, ramp_len)
        arr = out.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
        return [[arr.first], arr] unless ramp_len.positive?
        prefix = [arr.first]
        num = 0.0
        arr.each_cons(2).with_index do |(a, b), idx|
          pts = Calc.distance(b, a)
          next if pts <= 1.0e-9
          if num + pts >= ramp_len
            _c9cee24f = Calc.lerp(a, b, (ramp_len - num) / pts)
            prefix << _c9cee24f unless same_xy?(prefix.last, _c9cee24f)
            return [prefix, [_c9cee24f] + arr[(idx + 1)..]]
          end
          prefix << b
          num += pts
        end
        [arr, []]
      end
      def segment_clear?(row0, last_rect, polygon)
        a = [row0[0].to_f, row0[1].to_f]
        b = [last_rect[0].to_f, last_rect[1].to_f]
        return false unless (a + b).all?(&:finite?)
        return false unless Calc.in_polygon?(a[0], a[1], polygon) && Calc.in_polygon?(b[0], b[1], polygon)
        payload2 = [0.0, 1.0]
        polygon.each_index do |idx|
          payload2.concat(Calc.segment_hit_params(a, b, polygon[idx], polygon[(idx + 1) % polygon.length]))
        end
        payload2 = payload2.map { |val| [[val, 0.0].max, 1.0].min }.sort.each_with_object([]) do |val, rows|
          rows << val if rows.empty? || (val - rows.last).abs > 1.0e-8
        end
        payload2.each_cons(2).all? do |left, b2|
          pt = Calc.lerp(a, b, (left + b2) * 0.5)
          Calc.in_polygon?(pt[0], pt[1], polygon)
        end
      end
      def path_length(out)
        out.each_cons(2).map { |a, b| Calc.distance(b, a) }.inject(0.0, :+)
      end
      def from_bottom?(tool)
        tool["goc_cao_do"].to_s == "bottom"
      end
      def board_thickness(tool)
        tool["do_day_van"].to_f
      end
      def z(tool)
        num = tool["cao_an_toan"].to_f
        from_bottom?(tool) ? board_thickness(tool) + num : num
      end
      def approach_z(tool)
        from_bottom?(tool) ? board_thickness(tool) + 1.0 : 1.0
      end
      def depth_value(tool, num)
        depth = num.to_f
        from_bottom?(tool) ? board_thickness(tool) - depth : -depth
      end
      def pass_depths(tool)
        cut_depth = tool["cut_depth"].to_f.abs
        if tool["type"].to_s == "drill" || tool["pass_mode"].to_s == "single" || cut_depth <= 1.0e-9
          return [depth_value(tool, tool["cut_depth"])]
        end
        if tool["pass_mode"].to_s == "count"
          pass_count = tool["pass_count"].to_i
          return (1..pass_count).map { |i| depth_value(tool, i == pass_count ? cut_depth : cut_depth * i / pass_count) }
        end
        num = [tool["stepdown"].to_f.abs, 0.01].max
        arr = []
        cur = [num, cut_depth].min
        while cur < cut_depth - 0.0001
          arr << depth_value(tool, cur)
          cur += num
        end
        arr << depth_value(tool, cut_depth)
      end
      def ten(tool)
        name = tool["name"].to_s.strip
        name.empty? ? "T#{tool['number'].to_i}" : name
      end
      def move_to_start(lines, post, vars, x:, y:, tool:)
        z6 = z(tool)
        approach = approach_z(tool)
        _7ebfe435 = vars.merge("SAFEZ" => z6, "APPROACHZ" => approach)
        rapid(lines, post, _7ebfe435, x: x, y: y, z: z6)
        rapid(lines, post, _7ebfe435, z: approach)
      end
      def write_bore_entry(lines, post, vars, tool, depth)
        feed_move(lines, post, vars, z: depth, feed: tool["plunge"] || tool["feed"], first: true)
      end
      def write_entry(lines, post, path, tool, vars, depth)
        return path if path.length < 2
        unless tool["entry_mode"].to_s == "ramp_line"
          write_bore_entry(lines, post, vars, tool, depth)
          return path
        end
        style_ix = tool["ramp_kind"].to_s
        return write_zigzag_entry(lines, post, path, tool, vars, depth) if style_ix == "spiral"
        prefix, rest = split_ramp(path, tool["ramp_len_mm"].to_f)
        total = path_length(prefix)
        if total <= 1.0e-9
          write_bore_entry(lines, post, vars, tool, depth)
          return path
        elsif style_ix == "zigzag"
          write_ramp_entry(lines, post, prefix, tool, vars, depth, total)
        else
          write_ramp_leg(lines, post, prefix, tool, vars, total, approach_z(tool), depth, true)
        end
        tail_pt = rest.empty? ? [prefix.last] : rest
        return tail_pt unless path.length > 2 && same_xy?(path.first, path.last)
        to_pairs(tail_pt + prefix[1..])
      end
      def assert_ramp_fits(path, tool, arr2)
        return if arr2.empty? || tool["entry_mode"].to_s != "ramp_line"
        lbl = ten(tool)
        _744d6cbf = Text.t(:duong, :van_de_cau_hinh, ten: lbl)
        raise UnsafeCutError, _744d6cbf if path.length < 2
        style_ix = tool["ramp_kind"].to_s
        approach = approach_z(tool)
        arr = arr2.map { |depth| approach - depth }.reject { |delta| delta <= 1.0e-9 }
        return if arr.empty?
        spiral = style_ix == "spiral"
        num2 = spiral && !(path.length > 2 && same_xy?(path.first, path.last))
        raise UnsafeCutError, Text.t(:dao, :xoan_bien_can_kin, ten: lbl) if num2
        pts = spiral ? path : split_ramp(path, tool["ramp_len_mm"].to_f).first
        raise UnsafeCutError, _744d6cbf if pts.length < 2
        total = Calc.kahan_sum(pts.each_cons(2).map { |a, b| Calc.distance(b, a) })
        raise UnsafeCutError, _744d6cbf unless total.finite? && total > 1.0e-9
        return unless spiral || style_ix == "zigzag"
        arr.each { |delta| ramp_passes(tool, spiral, delta, total) }
      end
      def ramp_passes(tool, spiral, delta, total)
        lbl = ten(tool)
        ramp_deg = tool["ramp_deg"].to_f
        name = Text.term(spiral ? :xoan_bien : :doc_gap_khuc)
        drop_jobs = ramp_deg.positive? ? total * Math.tan(ramp_deg * Math::PI / 180.0) : (spiral ? delta : delta / 2.0)
        raise UnsafeCutError, Text.t(:dao, :doc_khong_ha, kieu: name, ten: lbl) unless drop_jobs.finite? && drop_jobs > 1.0e-12
        want = [((delta / drop_jobs) - 1.0e-12).ceil, 1].max
        hi = spiral ? 200 : 400
        return [want, drop_jobs] if want <= hi
        lo = (Math.atan(delta / (total * hi)) * 180.0 / Math::PI * 10_000.0).ceil / 10_000.0
        raise UnsafeCutError, Text.t(:dao, :goc_doc_nho, ten: lbl, kieu: name, goc: Text.num(lo, 4))
      end
      def write_ramp(lines, post, vec, tool, vars, total, z, depth, spiral)
        want, drop_jobs = ramp_passes(tool, spiral, z - depth, total)
        back = spiral ? vec : vec.reverse
        want.times do |num|
          target = num == want - 1 ? depth : [depth, z - drop_jobs].max
          write_ramp_leg(lines, post, num.odd? ? back : vec, tool, vars, total, z, target, num.zero?)
          z = target
        end
        want
      end
      def write_ramp_leg(lines, post, out, tool, vars, total, z, target, row0)
        num = 0.0
        out.each_cons(2).with_index do |(a, b), idx|
          num += Calc.distance(b, a)
          feed_move(lines, post, vars, x: b[0], y: b[1], z: z + ((target - z) * (num / total)),
                                         feed: tool["plunge"], first: row0 && idx.zero?)
        end
      end
      def write_ramp_entry(lines, post, prefix, tool, vars, depth, total)
        z = approach_z(tool)
        return write_bore_entry(lines, post, vars, tool, depth) if z - depth <= 1.0e-9
        return if write_ramp(lines, post, prefix, tool, vars, total, z, depth, false).odd?
        prefix[1..].each do |b|
          feed_move(lines, post, vars, x: b[0], y: b[1], z: depth, feed: tool["plunge"], first: false)
        end
      end
      def write_zigzag_entry(lines, post, pts2, tool, vars, depth)
        total = path_length(pts2)
        z = approach_z(tool)
        if total <= 1.0e-9 || z - depth <= 1.0e-9
          write_bore_entry(lines, post, vars, tool, depth)
        else
          write_ramp(lines, post, pts2, tool, vars, total, z, depth, true)
        end
        pts2
      end
      def write_helix_entry(lines, post, outline, tool, vars, depth, start)
        polygon = dedupe(outline)
        return false if polygon.length < 3 || self_intersects?(polygon)
        arr2 = polygon.map(&:first)
        arr = polygon.map(&:last)
        center = [(arr2.min + arr2.max) * 0.5, (arr.min + arr.max) * 0.5]
        r = [tool["helix_r_mm"].to_f.abs, tool["diameter"].to_f.abs * 0.55].max
        return false unless r.finite? && r.positive? && Calc.in_polygon?(center[0], center[1], polygon)
        return false unless Calc.polygon_distance(center, polygon) >= r - 0.001
        slot = [center[0] + r, center[1]]
        return false unless segment_clear?(slot, start, polygon)
        feed = tool["plunge"] || tool["feed"]
        raise UnsafeCutError, Text.t(:post, :khong_xoan_tam, post: post["post_name"]) unless post_supports_helix?(post, vars, r, depth, feed)
        cur = approach_z(tool)
        num = [tool["helix_step_mm"].to_f.abs, 0.2].max
        rapid(lines, post, vars, x: slot[0], y: slot[1], z: z(tool))
        rapid(lines, post, vars, z: cur)
        row0 = true
        while cur - depth > 1.0e-6
          _97622c4d = [cur - num, depth].max
          helix_move(lines, post, vars, x: center[0] - r, y: center[1],
                                               z: cur + (_97622c4d - cur) * 0.5, i: -r, feed: feed, first: row0)
          row0 = false
          helix_move(lines, post, vars, x: slot[0], y: slot[1], z: _97622c4d, i: r, feed: feed, first: false)
          cur = _97622c4d
        end
        true
      end
      def orient(out, tool)
        outer_loop = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        closed = outer_loop.length > 2 && same_xy?(outer_loop.first, outer_loop.last)
        outer_loop.pop if closed
        return out if outer_loop.length < 3
        outer_loop.reverse! if reverse_needed?(tool, Calc.signed_area(outer_loop))
        closed ? ring(outer_loop) : outer_loop
      end
      def orient_points(out, tool, closed)
        outer_loop = out.dup
        return outer_loop unless closed || (outer_loop.length > 2 && same_point?(outer_loop.first, outer_loop.last))
        outer_loop.pop while outer_loop.length > 1 && same_point?(outer_loop.first, outer_loop.last)
        if outer_loop.length >= 3
          arr = Calc.kahan_sum(outer_loop.zip(outer_loop.rotate).map do |pt, pt2|
            pt.x.to_f * pt2.y.to_f - pt2.x.to_f * pt.y.to_f
          end) * 0.5
          outer_loop.reverse! if reverse_needed?(tool, arr)
        end
        ring3d(outer_loop)
      end
      def reverse_needed?(tool, num)
        sweep = tool["cut_direction"].to_s
        (sweep == "cw" && num.positive?) || (sweep == "ccw" && num.negative?)
      end
      def rotate_to_corner(out, corner, _f0757d0e = nil)
        return out if auto_corner?(corner)
        rows = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        closed = rows.length > 2 && same_xy?(rows.first, rows.last)
        rows.pop while rows.length > 1 && same_xy?(rows.first, rows.last)
        return out if rows.length < 2
        start_hit = corner_hit(rows, corner_target(_f0757d0e || rows, corner), corner)
        return out unless start_hit
        _de034776 = rotate_at_hit(rows, start_hit) { start_hit[:point] }
        closed ? ring(_de034776) : _de034776
      end
      def rotate_points_to_corner(out, corner, anchor)
        outer_loop = out.dup
        closed = outer_loop.length > 1 && same_point?(outer_loop.first, outer_loop.last)
        outer_loop.pop while outer_loop.length > 1 && same_point?(outer_loop.first, outer_loop.last)
        return out if outer_loop.length < 2 || auto_corner?(corner)
        arr2 = outer_loop.map { |pt| to_mm(pt, anchor) }
        start_hit = corner_hit(arr2, corner_target(arr2, corner), corner)
        return out unless start_hit
        arr = rotate_at_hit(outer_loop, start_hit) { to_model_point(start_hit[:point], anchor) }
        closed ? arr << arr.first : arr
      end
      def auto_corner?(corner)
        ['', "auto"].include?(corner.to_s)
      end
      def corner_target(arr3, corner)
        outer_loop = arr3.map { |pt| [pt[0].to_f, pt[1].to_f] }
        outer_loop.pop while outer_loop.length > 1 && same_xy?(outer_loop.first, outer_loop.last)
        return nil if outer_loop.empty?
        arr2 = outer_loop.map(&:first)
        arr = outer_loop.map(&:last)
        left, b2, bot, _e4f12bf3 = arr2.min, arr2.max, arr.min, arr.max
        case corner.to_s
        when "top_left" then [left, _e4f12bf3]
        when "top_center" then [(left + b2) * 0.5, _e4f12bf3]
        when "top_right" then [b2, _e4f12bf3]
        when "middle_right" then [b2, (bot + _e4f12bf3) * 0.5]
        when "bottom_right" then [b2, bot]
        when "bottom_center" then [(left + b2) * 0.5, bot]
        when "bottom_left" then [left, bot]
        when "middle_left" then [left, (bot + _e4f12bf3) * 0.5]
        end
      end
      def corner_hit(out, target, corner)
        return nil unless target
        outer_loop = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        outer_loop.pop while outer_loop.length > 1 && same_xy?(outer_loop.first, outer_loop.last)
        return nearest_hit(outer_loop, target) if outer_loop.length < 3
        _bd7bf87a = case corner.to_s
                       when "bottom_right", "middle_right" then [0.0, 1.0]
                       when "top_right", "top_center" then [-1.0, 0.0]
                       when "top_left", "middle_left" then [0.0, -1.0]
                       when "bottom_left", "bottom_center" then [1.0, 0.0]
                       end
        _bd7bf87a = [-_bd7bf87a[0], -_bd7bf87a[1]] if _bd7bf87a && !Calc.signed_area(outer_loop).positive?
        arr2 = Calc.corner_dir(corner)
        return nearest_hit(outer_loop, target) unless _bd7bf87a || arr2
        arr3 = []
        arr5 = []
        outer_loop.zip(outer_loop.rotate).each_with_index do |(row0, last_rect), idx|
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
          arr3 << {
            index: idx, t: t, point: point, distance: distance,
            tangent_align: _bd7bf87a ? (dx / length) * _bd7bf87a[0] + (dy / length) * _bd7bf87a[1] : -1.0,
            midline_align: arr2 && distance > 1.0e-12 ? ((_fbf0cf8d / distance) * arr2[0] + (_7e1c7e1d / distance) * arr2[1]).abs : -1.0
          }
          next unless arr2
          _78dcb2bf = row0[0] - target[0]
          _9ff9e93b = row0[1] - target[1]
          num = arr2[0] * dy - arr2[1] * dx
          next unless num.abs > 1.0e-12
          _b8051bfa = (_78dcb2bf * arr2[1] - _9ff9e93b * arr2[0]) / num
          next unless _b8051bfa >= -1.0e-9 && _b8051bfa <= 1.0 + 1.0e-9
          _b8051bfa = [[_b8051bfa, 0.0].max, 1.0].min
          arr5 << { index: idx, t: _b8051bfa, point: [row0[0] + dx * _b8051bfa, row0[1] + dy * _b8051bfa],
                    distance: ((_78dcb2bf * dy - _9ff9e93b * dx) / num).abs }
        end
        return nearest_hit(outer_loop, target) if arr3.empty?
        arr4 = arr3.map { |arr| arr[:distance] }.min
        per_row = arr4 + (arr2 ? [[0.25, arr4 * 0.03].max, 1.0].min : [1.0, arr4 * 0.03].max)
        arr6 = arr3.select { |arr| arr[:distance] <= per_row }
        if arr2
          hit = arr5.select { |arr| arr[:distance] <= per_row }.min_by { |arr| [arr[:distance], arr[:index], arr[:t]] }
          return refine_hit(outer_loop, target, hit) if hit
          best = arr6.max_by do |arr|
            [arr[:midline_align], -arr[:distance], arr[:t] > 1.0e-9 && arr[:t] < 1.0 - 1.0e-9 ? 1 : 0, -arr[:index]]
          end
        else
          best = arr6.max_by { |arr| [arr[:tangent_align], -arr[:distance], -arr[:index]] }
        end
        best || nearest_hit(outer_loop, target)
      end
      def refine_hit(rows, target, hit)
        return hit if rows.length < 4
        idx = hit[:index]
        _fcfdc47b = ->(pt) { Math.hypot(pt[0] - target[0], pt[1] - target[1]) }
        _80c5874d = _fcfdc47b.call(rows[idx])
        num = _fcfdc47b.call(rows[(idx + 1) % rows.length])
        return hit unless _80c5874d.finite? && num.finite?
        r = (_80c5874d + num) * 0.5
        tol = [[0.005, r * 0.002].max, 0.05].min
        return hit if r <= 1.0e-6 || (_80c5874d - num).abs > tol
        num2 = [_fcfdc47b.call(rows[(idx - 1) % rows.length]), _fcfdc47b.call(rows[(idx + 2) % rows.length])]
        return hit unless num2.any? { |val| val.finite? && (val - r).abs <= tol }
        _fbf0cf8d = hit[:point][0] - target[0]
        _7e1c7e1d = hit[:point][1] - target[1]
        length = Math.hypot(_fbf0cf8d, _7e1c7e1d)
        return hit unless length > 1.0e-9
        hit.merge(point: [target[0] + r * _fbf0cf8d / length, target[1] + r * _7e1c7e1d / length])
      end
      def nearest_hit(outer_loop, target)
        return nil if outer_loop.length < 2
        best = nil
        num = 1.0e-9
        outer_loop.zip(outer_loop.rotate).each_with_index do |(row0, last_rect), idx|
          dx = last_rect[0] - row0[0]
          dy = last_rect[1] - row0[1]
          len2 = dx * dx + dy * dy
          t = len2 <= 1.0e-18 ? 0.0 : ((target[0] - row0[0]) * dx + (target[1] - row0[1]) * dy) / len2
          t = [[t, 0.0].max, 1.0].min
          point = [row0[0] + dx * t, row0[1] + dy * t]
          _5ae7f1e5 = (point[0] - target[0])**2 + (point[1] - target[1])**2
          layers = t <= num ? 0 : (t >= 1.0 - num ? 2 : 1)
          next unless best.nil? || _5ae7f1e5 < best[:distance_sq] - num ||
                      ((_5ae7f1e5 - best[:distance_sq]).abs <= num && layers < best[:vertex_order])
          best = { distance_sq: _5ae7f1e5, vertex_order: layers, index: idx, t: t, point: point }
        end
        best
      end
      def rotate_at_hit(rows, start_hit)
        idx = start_hit[:index]
        t = start_hit[:t]
        return rows.rotate(idx) if t <= 1.0e-9
        return rows.rotate(idx + 1) if t >= 1.0 - 1.0e-9
        rows.rotate(idx + 1).unshift(yield)
      end
    end
  end
end
