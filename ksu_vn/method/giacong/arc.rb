module KSU
  module Cnc
    module Arc
      RADIUS_MIN_MM = 0.001
      LINE_MIN_MM = 0.000001
      JOIN_TOL_MM = 0.001
      HIT_EPS_MM = 1.0e-9
      COLLAPSE_JOIN_MM = 0.05
      Result = Struct.new(:ok, :elems, :error, :metadata, keyword_init: true)
      module_function
      def offset_path(elems, tool_r_mm:, cut_side:, collapse: false)
        rows = elems.map { |arr2| read_element(arr2) }
        return failure("few_segments") if rows.length < 2
        tool_r = Calc.positive_float(tool_r_mm)
        return failure("bad_radius") unless tool_r
        side = cut_side.to_s
        return failure("bad_side") unless %w[inside outside].include?(side)
        base_area = Calc.path_area(rows)
        return failure("zero_area") if base_area.abs <= HIT_EPS_MM
        offset_sign = base_area.positive? == (side == "inside") ? tool_r : -tool_r
        want = rows.length
        arr6 = rows.map.with_index do |arr2, idx|
          offset_element(arr2, offset_sign, collapse).merge!(src_row: idx)
        end
        result = []
        arr3 = []
        arr6.each_with_index do |arr4, idx|
          result << arr4
          f_adj = (idx + 1) % want
          arr7 = arr6[f_adj]
          arr = join_pair(arr4, arr7, rows[idx], rows[f_adj], tool_r, offset_sign, idx)
          if arr[:ok]
            arr4[:e] = (arr[:point_from] || arr[:point]).dup
            arr7[:s] = (arr[:point_to] || arr[:point]).dup
            result << arr[:round_elem] if arr[:round_elem]
          elsif collapse && arr[:collapsed]
            arr3 << idx
          else
            return failure(arr[:error])
          end
        end
        num = result.count { |arr2| arr2[:folded_arc] }
        if collapse
          arr5 = folded_arcs(result)
          result = result.reject { |arr2| arr2[:folded_arc] }
          if (arr5.any? && !reconcile_folds(result, arr5, arr3, rows, tool_r, side)) ||
             (arr3.any? && !reconcile_collapsed(result, arr3, tool_r, want))
            return failure("reconcile_failed", reconcile_failed: true)
          end
        end
        return failure("zero_offset_area") if Calc.path_area(result).abs <= HIT_EPS_MM
        Result.new(ok: true, elems: result.each(&:freeze).freeze, metadata: { fold_count: num }.freeze)
      rescue StandardError => err
        failure(err.message)
      end
      def read_element(id_str)
        sheet_type = Util.fetch_required(id_str, :type).to_sym
        arr = { type: sheet_type, s: Calc.pt(Util.fetch_required(id_str, :s)), e: Calc.pt(Util.fetch_required(id_str, :e)) }
        return arr if sheet_type == :line
        raise ArgumentError, "unknown_segment" unless sheet_type == :arc
        center = Calc.pt(Util.fetch_required(id_str, :c))
        arr.merge!(c: center, ccw: Util.enabled?(Util.fetch_required(id_str, :ccw)),
                      full_circle: Util.enabled?(Util.lookup(id_str, :full_circle)), radius_mm: Calc.distance(arr[:s], center))
      end
      def failure(error, metadata = {})
        Result.new(ok: false, elems: [].freeze, error: error, metadata: metadata.freeze)
      end
      def offset_element(h, offset_sign, collapse)
        s, arr, c = h.values_at(:s, :e, :c)
        if h[:type] == :line
          dx = arr[0] - s[0]
          dy = arr[1] - s[1]
          length = Math.hypot(dx, dy)
          raise ArgumentError, "zero_length_line" if length <= LINE_MIN_MM
          nx = -dy / length
          ny = dx / length
          return h.merge(s: [s[0] + nx * offset_sign, s[1] + ny * offset_sign],
                               e: [arr[0] + nx * offset_sign, arr[1] + ny * offset_sign], source_s: s, source_e: arr)
        end
        radius_mm = h[:radius_mm] + (h[:ccw] ? -offset_sign : offset_sign)
        if radius_mm.abs <= RADIUS_MIN_MM || (collapse && radius_mm < -RADIUS_MIN_MM)
          pt = radius_mm.abs <= RADIUS_MIN_MM ? c : collapse_point(h, offset_sign.abs)
          return h.merge(type: :line, s: pt.dup, e: pt.dup, radius_mm: 0.0, folded_arc: true)
        end
        raise ArgumentError, "tool_larger_than_arc" unless radius_mm > RADIUS_MIN_MM
        start = Calc.project_to_radius(c, s, radius_mm, HIT_EPS_MM)
        run_batch = h[:full_circle] ? start&.dup : Calc.project_to_radius(c, arr, radius_mm, HIT_EPS_MM)
        raise ArgumentError, "zero_arc_radius" unless start && run_batch
        h.merge(s: start, e: run_batch, radius_mm: radius_mm)
      end
      def collapse_point(arr2, r)
        raise ArgumentError, "full_circle_collapse" if arr2[:full_circle]
        sweep = Calc.arc_sweep(arr2)
        raise ArgumentError, "half_circle_collapse" if sweep.abs > Math::PI + HIT_EPS_MM
        s, e, arr3 = arr2.values_at(:s, :e, :c)
        arr = Calc.circle_circle_hits(s, r, e, r)
        raise ArgumentError, "wide_arc_collapse" if arr.empty?
        return arr.first if arr.length == 1
        _40e89dd8 = Calc.deg4(s, arr3) + sweep * 0.5
        r2 = arr2[:radius_mm]
        _42cd5245 = [arr3[0] + Math.cos(_40e89dd8) * r2, arr3[1] + Math.sin(_40e89dd8) * r2]
        arr.max_by { |pt| [Calc.distance(pt, _42cd5245), -pt[0], -pt[1]] }
      end
      def join_pair(arr4, arr5, arr3, arr2, r, offset_sign, at_index)
        arr = intersect_pair(arr4, arr5, arr3, arr2, r)
        arr6 = arr3[:e]
        b = arr2[:s]
        mid = [(arr6[0] + b[0]) * 0.5, (arr6[1] + b[1]) * 0.5] unless Calc.distance(arr6, b) > JOIN_TOL_MM
        unless arr[:ok]
          return arr unless arr[:gap] && mid
          _3e891ad1 = arr3[:type] == :arc || arr2[:type] == :arc
          _5d5d62fb = (_3e891ad1 && turn_sign_arc(arr3, arr2)) || turn_sign(arr3, arr2, mid)
          return arr unless (_5d5d62fb * offset_sign).negative?
          arr7 = round_corner(mid, arr4[:e], arr5[:s], r, at_index)
          return arr7[:ok] ? arr7 : arr
        end
        return arr unless mid && (arr4[:type] == :line || arr5[:type] == :line)
        if arr4[:type] == :line && arr5[:type] == :line
          flag = (turn_sign(arr3, arr2, mid) * offset_sign).negative?
          per_row = r * (flag ? 1.02 : 2.5)
        else
          _5d5d62fb = turn_sign_arc(arr3, arr2)
          return arr unless _5d5d62fb && (_5d5d62fb * offset_sign).negative?
          per_row = r * 1.02
        end
        return arr unless Calc.distance(mid, arr[:point]) > per_row
        round_corner(mid, arr4[:e], arr5[:s], r, at_index)
      end
      def intersect_pair(arr2, arr, _2bf2cbeb, _0927b414, r)
        collapsed2 = arr2[:folded_arc] || arr[:folded_arc]
        arr3 = collapsed2 ? trim_pair(arr2, arr) : tangent_gap(arr2, arr)
        if arr3.empty? && !collapsed2 && arr2[:type] == :line && arr[:type] == :line &&
           Calc.distance(arr2[:e], arr[:s]) <= JOIN_TOL_MM
          arr3 = [[(arr2[:e][0] + arr[:s][0]) * 0.5, (arr2[:e][1] + arr[:s][1]) * 0.5]]
        end
        if arr3.empty?
          return { ok: false, gap: true, collapsed: true, error: "collapsed_gap" } if collapsed2
          gap2 = arr2[:type] != :arc || arr[:type] != :arc ||
                Calc.distance(arr2[:c], arr[:c]) - (arr2[:radius_mm] + arr[:radius_mm]) > JOIN_TOL_MM
          return { ok: false, gap: gap2, error: "no_join_hit" }
        end
        _95d29ad0 = [r * 12.0, 5.0].max
        arr4 = arr3.filter_map do |pt|
          _18ec63a8 = Calc.distance(pt, arr2[:e])
          _d6999e65 = Calc.distance(pt, arr[:s])
          _0cb58f80 = [_18ec63a8, _d6999e65].max
          next if _0cb58f80 > _95d29ad0
          next unless on_arc?(arr2, _2bf2cbeb, pt, :end) && on_arc?(arr, _0927b414, pt, :start)
          [[_18ec63a8 + _d6999e65, _0cb58f80, pt[0], pt[1]], pt]
        end
        pt = arr4.min_by(&:first)&.last || pick_intersection(arr2, arr, _2bf2cbeb, _0927b414, arr3, _95d29ad0)
        pt ? { ok: true, point: pt } : { ok: false, error: "no_join_point" }
      end
      def pick_intersection(arr, arr2, _2bf2cbeb, _0927b414, arr3, _95d29ad0)
        return unless arr3.length == 2 && arr[:type] != arr2[:type]
        arr4 = arr3.select do |pt|
          [Calc.distance(pt, arr[:e]), Calc.distance(pt, arr2[:s])].max <= _95d29ad0 &&
            on_element?(arr, pt, :end) && on_element?(arr2, pt, :start) &&
            on_line?(arr, _2bf2cbeb, pt, :end) &&
            on_line?(arr2, _0927b414, pt, :start)
        end
        arr4.first if arr4.length == 1
      end
      def round_corner(center, _02c89ac2, _fe07d030, r, at_index)
        fail = { ok: false, error: "round_join_failed" }
        return fail if [_02c89ac2, _fe07d030].any? { |pt| Calc.distance(pt, center) <= HIT_EPS_MM }
        a = Calc.project_to_radius(center, _02c89ac2, r, HIT_EPS_MM)
        b = Calc.project_to_radius(center, _fe07d030, r, HIT_EPS_MM)
        return fail if [Calc.distance(a, _02c89ac2), Calc.distance(b, _fe07d030)].max > JOIN_TOL_MM
        delta = Calc.wrap_pi(Calc.deg4(b, center) - Calc.deg4(a, center))
        return fail if delta.abs <= HIT_EPS_MM
        { ok: true, point_from: a, point_to: b,
          round_elem: { type: :arc, s: a, e: b, c: center, ccw: delta.positive?, full_circle: false,
                        radius_mm: r, join_index: at_index } }
      end
      def turn_sign_arc(left, b2)
        arr = Calc.tangent_at(left, :end)
        arr2 = Calc.tangent_at(b2, :start)
        arr[0] * arr2[1] - arr[1] * arr2[0] if arr && arr2
      end
      def turn_sign(arr, arr2, mid)
        (mid[0] - arr[:s][0]) * (arr2[:e][1] - mid[1]) - (mid[1] - arr[:s][1]) * (arr2[:e][0] - mid[0])
      end
      def on_element?(arr, pt, at)
        _f515d7f8, flag = at == :end ? [arr[:e], arr[:s]] : [arr[:s], arr[:e]]
        return false unless Calc.distance(pt, flag) - Calc.distance(pt, _f515d7f8) > JOIN_TOL_MM
        if arr[:type] == :line
          t = Calc.param_on_segment(arr[:s], arr[:e], pt, HIT_EPS_MM)
          _37953fc6, flag2 = at == :end ? [1.0, 0.0] : [0.0, 1.0]
          return !t.nil? && (t - _37953fc6).abs + HIT_EPS_MM < (t - flag2).abs
        end
        Calc.angle_between(_f515d7f8, pt, arr[:c]) * arr[:radius_mm] + JOIN_TOL_MM <
          Calc.angle_between(flag, pt, arr[:c]) * arr[:radius_mm]
      end
      def on_line?(h, _a8edb910, pt, at)
        return true unless h[:type] == :arc
        return false if h[:full_circle]
        num = Calc.arc_sweep(_a8edb910)
        num2 = Calc.arc_sweep(h.merge((at == :start ? :s : :e) => pt))
        return false if num.abs <= HIT_EPS_MM || num2.abs <= HIT_EPS_MM
        num.positive? == num2.positive?
      end
      def on_arc?(h, _a8edb910, pt, at)
        return true unless h[:type] == :arc
        return false if h[:full_circle]
        num2 = Calc.arc_sweep(_a8edb910)
        num = Calc.arc_sweep(h.merge((at == :start ? :s : :e) => pt))
        return false if num.abs <= HIT_EPS_MM || num2.positive? != num.positive?
        ((num2.abs - num.abs).abs * 180.0 / Math::PI) <= 45.0
      end
      def tangent_gap(arr, arr2)
        case [arr[:type], arr2[:type]]
        when [:line, :line] then [Calc.line_intersection(arr[:s], arr[:e], arr2[:s], arr2[:e], HIT_EPS_MM)].compact
        when [:line, :arc] then Calc.segment_circle_hits(arr[:s], arr[:e], arr2[:c], arr2[:radius_mm])
        when [:arc, :line] then Calc.segment_circle_hits(arr2[:s], arr2[:e], arr[:c], arr[:radius_mm])
        when [:arc, :arc] then Calc.circle_circle_hits(arr[:c], arr[:radius_mm], arr2[:c], arr2[:radius_mm])
        end
      end
      def trim_pair(arr, arr2)
        center, panel = arr[:folded_arc] ? [arr[:s], arr2] : [arr2[:s], arr]
        if panel[:folded_arc]
          return [] if Calc.distance(arr[:s], arr2[:s]) > COLLAPSE_JOIN_MM
          return [[(arr[:s][0] + arr2[:s][0]) * 0.5, (arr[:s][1] + arr2[:s][1]) * 0.5]]
        end
        if panel[:type] == :line
          _014a8b46 = Calc.project_on_line(center, panel[:s], panel[:e], HIT_EPS_MM)
          return _014a8b46.nil? || Calc.distance(_014a8b46, center) > COLLAPSE_JOIN_MM ? [] : [_014a8b46]
        end
        return [] if (Calc.distance(panel[:c], center) - panel[:radius_mm]).abs > COLLAPSE_JOIN_MM
        [Calc.project_to_radius(panel[:c], center, panel[:radius_mm], HIT_EPS_MM) || raise(ArgumentError, "zero_arc_radius")]
      end
      def folded_arcs(rows)
        _88a61dbc = ->(arr) { !arr[:folded_arc] }
        rows.each_with_index.filter_map do |arr, idx|
          next unless arr[:folded_arc]
          { index: arr[:src_row], left: rows.rotate(idx).reverse_each.find(&_88a61dbc),
            right: rows.rotate(idx + 1).find(&_88a61dbc),
            consecutive: rows[idx - 1][:folded_arc] || rows[(idx + 1) % rows.length][:folded_arc] }
        end
      end
      def reconcile_folds(rows, arr4, _5adc787e, base_area, r, side)
        return false if rows.length < 2
        arr4.all? do |arr3|
          idx = arr3[:index]
          next false if arr3[:consecutive]
          next true unless ([(idx - 1) % base_area.length, idx] & _5adc787e).empty?
          arr, arr2 = arr3.values_at(:left, :right)
          flag = rows.index { |row| row.equal?(arr) }
          next false unless arr && arr2 && flag && rows[(flag + 1) % rows.length].equal?(arr2)
          gap2 = Calc.distance(arr[:e], arr2[:s])
          next true if gap2 <= JOIN_TOL_MM
          next false if gap2 > COLLAPSE_JOIN_MM + HIT_EPS_MM
          pt = reconcile_pair(arr, arr2, base_area, r, side)
          next false unless pt
          arr[:e], arr2[:s] = pt.dup, pt.dup
          true
        end
      end
      def reconcile_pair(arr2, arr3, base_area, r, side)
        tol = COLLAPSE_JOIN_MM + HIT_EPS_MM
        per_row = [[1.0, r * 0.30].min, COLLAPSE_JOIN_MM].max + HIT_EPS_MM
        rows = tangent_gap(arr2, arr3).map do |pt|
          _03f33f5e = Calc.distance(arr2[:e], pt)
          _5985096d = Calc.distance(arr3[:s], pt)
          failed = _03f33f5e <= tol && _5985096d <= tol
          _bca11338 = on_arc?(arr2, arr2, pt, :end) && on_arc?(arr3, arr3, pt, :start)
          _e7093b34 = _bca11338 && clamp_to_element(arr2, pt, :end) && clamp_to_element(arr3, pt, :start)
          { point: pt,
            strict: failed && _bca11338 && on_element?(arr2, pt, :end) && on_element?(arr3, pt, :start),
            fallback: failed && _e7093b34, boundary: _e7093b34 && _03f33f5e <= per_row && _5985096d <= per_row }
        end
        arr4 = rows.select { |arr| arr[:strict] }
        return arr4.first[:point] if arr4.length == 1
        return unless arr4.empty?
        fallback = rows.select { |arr| arr[:fallback] }
        return fallback.first[:point] if fallback.length == 1
        out = rows.filter_map { |arr| arr[:point] if arr[:boundary] }
        Clip.offset_candidates(base_area, out, r, side) if out.any?
      end
      def clamp_to_element(arr, pt, at)
        return Calc.arc_sweep(arr).abs > HIT_EPS_MM if arr[:type] == :arc
        start, run_batch = at == :start ? [pt, arr[:e]] : [arr[:s], pt]
        _332974fe = arr[:source_e][0] - arr[:source_s][0]
        _a0cbde20 = arr[:source_e][1] - arr[:source_s][1]
        _cef254e2 = run_batch[0] - start[0]
        _b609a7ee = run_batch[1] - start[1]
        length = Math.hypot(_cef254e2, _b609a7ee)
        return false if length <= LINE_MIN_MM
        (_332974fe * _b609a7ee - _a0cbde20 * _cef254e2).abs / (Math.hypot(_332974fe, _a0cbde20) * length) <= 1.0e-7 && (_332974fe * _cef254e2 + _a0cbde20 * _b609a7ee).positive?
      end
      def reconcile_collapsed(rows, arr4, r, want)
        return false if rows.length < 2
        _7ae7e3bf = [r * 0.30, 1.0].min + HIT_EPS_MM
        _6a8c6975 = lambda do |arr3|
          idx = arr3[:join_index]
          !idx.nil? && arr4.any? { |panel| [1, want - 1].include?((idx - panel) % want) }
        end
        rows.each_with_index.all? do |arr, idx|
          b2 = rows[(idx + 1) % rows.length]
          gap2 = Calc.distance(arr[:e], b2[:s])
          next true if gap2 <= JOIN_TOL_MM
          _c73416b0 = _6a8c6975.call(arr)
          next false if _c73416b0 == _6a8c6975.call(b2)
          _e3d717dd, _6a0dcdba, axis, rank_b = _c73416b0 ? [arr, :end, b2, :start] : [b2, :start, arr, :end]
          next false unless axis[:type] == :line
          _f515d7f8, flag = rank_b == :end ? [axis[:e], axis[:s]] : [axis[:s], axis[:e]]
          arr2 = tangent_gap(arr, b2).filter_map do |pt|
            num = move_endpoint(_e3d717dd, pt, _6a0dcdba)
            t = Calc.param_on_segment(axis[:s], axis[:e], pt, HIT_EPS_MM)
            next unless num && t
            arr22 = Calc.distance(_f515d7f8, pt)
            arr5 = t >= -HIT_EPS_MM && t <= 1.0 + HIT_EPS_MM && gap2 <= _7ae7e3bf && Calc.distance(pt, flag) > LINE_MIN_MM
            next unless arr22 <= _7ae7e3bf || arr5
            [[arr22 + num.abs * 0.001, arr22, pt[0], pt[1]], pt]
          end
          next false if arr2.empty?
          pt = arr2.min_by(&:first).last
          arr[:e], b2[:s] = pt.dup, pt.dup
          true
        end
      end
      def move_endpoint(h, pt, at)
        num2 = Calc.arc_sweep(h)
        return if num2.abs <= HIT_EPS_MM
        num = Calc.arc_sweep(h.merge((at == :start ? :s : :e) => pt))
        return if num.abs <= HIT_EPS_MM || num.positive? != num2.positive?
        return if num.abs > Math::PI + HIT_EPS_MM
        num3 = (num.abs - num2.abs) * 180.0 / Math::PI
        num3 unless num3.abs > 30.0 + 1.0e-7
      end
    end
    module Dogbone
      module_function
      def relief_path(outline, offset_pts, r, cut_side)
        tol = 0.01
        boundary = clean_points(outline, tol)
        offset_path = clean_points(offset_pts, tol)
        tool_r = r.to_f.abs
        side = cut_side.to_s.downcase
        return failure("bad_radius") unless tool_r.positive?
        return failure("bad_side") unless %w[inside outside].include?(side)
        return failure("corner_mismatch") if boundary.length < 3 || boundary.length != offset_path.length
        area_sign = Calc.shoelace_area(boundary)
        return failure("zero_area") if area_sign.abs <= tol * tol
        ok = []
        num = 0
        boundary.rotate(-1).zip(boundary, boundary.rotate, offset_path).each do |_1b553836, corner, _f273cbbc, arr|
          push_point(ok, arr, tol)
          next unless relief_corner?(_1b553836, corner, _f273cbbc, area_sign, side, tol)
          dx = arr[0] - corner[0]
          dy = arr[1] - corner[1]
          _68b53d20 = Math.hypot(dx, dy)
          next if _68b53d20 <= tool_r + tol
          upm = tool_r / _68b53d20
          push_point(ok, [corner[0] + (dx * upm), corner[1] + (dy * upm)], tol)
          push_point(ok, arr, tol)
          num += 1
        end
        return failure("no_relief_corner") if num.zero?
        path = clean_points(ok, tol)
        path << path.first.dup if path.length >= 2
        { ok: true, path: path }
      end
      def clean_points(out, tol)
        rows = out.filter_map do |pt|
          x = pt[0].to_f
          y = pt[1].to_f
          [x, y] if x.finite? && y.finite?
        end
        rows.pop while rows.length > 1 && Calc.distance(rows.first, rows.last) <= tol
        arr = rows.each_with_object([]) { |pt, entries| push_point(entries, pt, tol) }
        arr.pop while arr.length > 1 && Calc.distance(arr.first, arr.last) <= tol
        arr
      end
      def relief_corner?(_1b553836, corner, _f273cbbc, area_sign, cut_side, tol)
        return false if Calc.distance(_1b553836, corner) <= tol || Calc.distance(corner, _f273cbbc) <= tol
        num = Calc.cross(_1b553836, corner, _f273cbbc)
        return false if num.abs <= tol * tol
        deg4 = Calc.corner_angle_deg(_1b553836, corner, _f273cbbc, 1.0e-12)
        return false if deg4 < 60.0 || deg4 > 150.0
        (num * area_sign).positive? == (cut_side == "inside")
      end
      def push_point(rows, pt, tol)
        path = [pt[0].to_f, pt[1].to_f]
        rows << path if rows.empty? || Calc.distance(rows.last, path) > tol
      end
      def failure(error)
        { ok: false, error: error }
      end
    end
    module Compressor
      DUP_TOL_MM = 1.0e-7
      @arr3 = nil
      module_function
      def compress(out, tolerance_mm:)
        arr = []
        last_rect = nil
        out.each do |pt|
          next unless pt[0].finite? && pt[1].finite?
          next if last_rect && Math.hypot(last_rect[0].to_f - pt[0].to_f, last_rect[1].to_f - pt[1].to_f) <= DUP_TOL_MM
          arr << (last_rect = pt)
        end
        return [] if arr.length < 2
        num = tolerance_mm.instance_of?(Float) && arr.all? { |pt| pt.instance_of?(Array) && pt.length == 2 }
        flat = arr.flatten(1) if num
        key = flat.push(tolerance_mm).pack("G*") if flat&.all?(Float)
        return rebind_points(@arr3[1], arr) if key && @arr3 && @arr3[0] == key
        arr4 = []
        h = {}.compare_by_identity
        idx = 0
        last_ix = arr.length - 1
        while idx < last_ix
          arr2 = arc_run_at(arr, idx, tolerance_mm)
          unless arr2
            start = arr[idx]
            run_batch = arr[idx + 1]
            arr2 = { type: :line, start: start, finish: run_batch,
                          length: Math.hypot(start[0].to_f - run_batch[0].to_f, start[1].to_f - run_batch[1].to_f) }
          end
          arr4 << arr2
          h[arr2] = idx
          idx = arr2[:end_index] || idx + 1
        end
        out_rec = arc_segment(arr4)
        @arr3 = [key, push_segment(out_rec, h, last_ix)] if key
        out_rec
      end
      def push_segment(arr2, h2, last_ix)
        arr2.each_with_index.map do |h, _6441cd49|
          arr = h.merge(start: nil, finish: nil)
          arr.merge!(center: h[:center].dup, source_points: nil) if arr[:type] == :arc
          [h2[h], h2.fetch(arr2[_6441cd49 + 1], last_ix), arr]
        end
      end
      def rebind_points(plan, arr)
        plan.map do |row0, last_rect, h|
          arr2 = h.merge(start: arr[row0], finish: arr[last_rect])
          next arr2 unless arr2[:type] == :arc
          arr2.merge!(center: h[:center].dup, source_points: arr[row0..last_rect])
        end
      end
      def arc_run_at(out, _79596bdd, tol)
        partner = Calc::NATIVE ? Native.detect_arc(out, _79596bdd, tol) : false
        partner = fit_arc_run(out, _79596bdd, tol) if partner == false
        return nil unless partner
        end_index, cx, _678e79b2, r, sweep, length = partner
        { type: :arc, start: out[_79596bdd], finish: out[end_index], center: [cx, _678e79b2], radius: r,
          clockwise: sweep.negative?, sweep: sweep, length: length, end_index: end_index,
          source_points: out[_79596bdd..end_index] }
      end
      def fit_arc_run(out, _79596bdd, tol)
        cands2 = nil
        ((_79596bdd + 2)..[_79596bdd + 32, out.length - 1].min).each do |_a6b6962f|
          circle = Calc.circumcircle(out[_79596bdd], out[(_79596bdd + _a6b6962f) / 2], out[_a6b6962f])
          next unless circle
          sweep = extend_arc_run(out, _79596bdd, _a6b6962f, circle[:center], circle[:radius], tol)
          next unless sweep && sweep.abs >= 0.5 * Math::PI / 180.0
          cands2 = circle.merge(sweep: sweep, end_index: _a6b6962f)
          break
        end
        return nil unless cands2
        end_index, sweep = cands2.values_at(:end_index, :sweep)
        sweep2 = sweep.negative? ? -1.0 : 1.0
        _507187ed = Calc.deg4(out[end_index], cands2[:center])
        while end_index + 1 < out.length
          path = out[end_index + 1]
          break if (Calc.distance(path, cands2[:center]) - cands2[:radius]).abs > tol
          _70c40249 = Calc.deg4(path, cands2[:center])
          delta = Calc.wrap_pi(_70c40249 - _507187ed)
          break if delta.abs <= 1.0e-10 || delta * sweep2 <= 0.0 || delta.abs > (30.0 * Math::PI / 180.0)
          break if (sweep + delta).abs > (Math::PI + 1.0e-7)
          sweep += delta
          _507187ed = _70c40249
          end_index += 1
        end
        return nil if Calc.distance(out[_79596bdd], out[end_index]) <= DUP_TOL_MM
        center = Calc.chord_normal_point(out[_79596bdd], out[end_index], cands2[:center])
        return nil unless center
        r = Calc.distance(out[_79596bdd], center)
        return nil unless r.positive? && r <= 1_000_000.0
        sweep = extend_arc_run(out, _79596bdd, end_index, center, r, tol)
        return nil unless sweep
        length = r * sweep.abs
        return nil if sweep.abs < (5.0 * Math::PI / 180.0) || length < 0.1
        [end_index, center[0], center[1], r, sweep, length]
      end
      def extend_arc_run(out, _3936af4d, _4d3367e1, center, r, tol)
        num = r - tol
        _42833ffe = r + tol
        flag2 = num.positive? ? num * num : 0.0
        _db3f42ca = _42833ffe * _42833ffe
        _d197ab89 = [flag2, _db3f42ca, 1.0].max
        _507187ed = Calc.deg4(out[_3936af4d], center)
        _5d97a3be = out[_3936af4d]
        sweep = 0.0
        sweep3 = nil
        (_3936af4d.._4d3367e1).each do |idx|
          pt = out[idx]
          dx = pt[0] - center[0]
          dy = pt[1] - center[1]
          _5ae7f1e5 = dx * dx + dy * dy
          flag = (_5ae7f1e5 > _d197ab89 ? _5ae7f1e5 : _d197ab89) * 1.4210854715202004e-14
          if num.positive?
            _304b45a2 = _5ae7f1e5 > _db3f42ca + flag || _5ae7f1e5 < flag2 - flag
            inside = _5ae7f1e5 < _db3f42ca - flag && _5ae7f1e5 > flag2 + flag
          else
            _304b45a2 = _5ae7f1e5 > _db3f42ca + flag
            inside = _5ae7f1e5 < _db3f42ca - flag
          end
          return nil if _304b45a2 || (!inside && (Math.hypot(dx, dy) - r).abs > tol)
          next if idx == _3936af4d
          chord = Calc.distance(_5d97a3be, pt)
          return nil if chord > r * 2.0 + 1.0e-9
          _e8f9dc5f = chord * 0.5
          _92dffb5a = r * r - _e8f9dc5f * _e8f9dc5f
          return nil if _92dffb5a < -1.0e-9 || r - Math.sqrt([_92dffb5a, 0.0].max) > tol
          deg4 = Calc.deg4(pt, center)
          delta = Calc.wrap_pi(deg4 - _507187ed)
          return nil if delta.abs <= 1.0e-10 || delta.abs > (30.0 * Math::PI / 180.0)
          flag3 = delta.negative? ? -1.0 : 1.0
          sweep3 ||= flag3
          return nil unless flag3 == sweep3
          sweep += delta
          return nil if sweep.abs > (Math::PI + 1.0e-7)
          _507187ed = deg4
          _5d97a3be = pt
        end
        sweep
      end
      def arc_segment(arr3)
        out_rec = []
        arr = nil
        arr3.each do |arr2|
          next unless arr2[:length] > DUP_TOL_MM
          if arr && arr[:type] == :line && arr2[:type] == :line &&
             arc_direction(arr[:start], arr[:finish], arr2[:finish])
            arr[:finish] = arr2[:finish]
            arr[:length] = Calc.distance(arr[:start], arr[:finish])
          else
            out_rec << (arr = arr2)
          end
        end
        out_rec
      end
      def arc_direction(arr, b, arr2)
        _ef672dce = b[0] - arr[0]
        _73792f97 = b[1] - arr[1]
        _6fff5dd9 = arr2[0] - b[0]
        _515aedb8 = arr2[1] - b[1]
        cross = _ef672dce * _515aedb8 - _73792f97 * _6fff5dd9
        dot = _ef672dce * _6fff5dd9 + _73792f97 * _515aedb8
        upm = [Math.hypot(_ef672dce, _73792f97) * Math.hypot(_6fff5dd9, _515aedb8), 1.0].max
        cross.abs <= 1.0e-8 * upm && dot >= 0.0
      end
      def split_at_length(arr2, _6affa40e)
        num = 0.0
        arr2.flat_map do |arr|
          _c3558fdf = num
          num += arr[:length]
          next arr unless _6affa40e > _c3558fdf + 1.0e-9 && _6affa40e < num - 1.0e-9
          split_segment(arr, _6affa40e - _c3558fdf).compact
        end
      end
      def split_segment(h, length)
        length2 = h[:length]
        return [nil, h] if length <= 1.0e-9
        return [h, nil] if length >= length2 - 1.0e-9
        _5f343815 = length / length2
        if h[:type] == :arc
          _e4ae727b = h[:sweep] * _5f343815
          deg4 = Calc.deg4(h[:start], h[:center]) + _e4ae727b
          _3718aa1d = [h[:center][0] + h[:radius] * Math.cos(deg4),
                            h[:center][1] + h[:radius] * Math.sin(deg4)]
          _1e7e548f, _2a1ac834 = split_arc(h, _3718aa1d, length)
          return [h.merge(finish: _3718aa1d, sweep: _e4ae727b, length: length, source_points: _1e7e548f),
                  h.merge(start: _3718aa1d, sweep: h[:sweep] - _e4ae727b, length: length2 - length,
                                  source_points: _2a1ac834)]
        end
        _3718aa1d = Calc.lerp(h[:start], h[:finish], _5f343815)
        [h.merge(finish: _3718aa1d, length: length), h.merge(start: _3718aa1d, length: length2 - length)]
      end
      def split_arc(arr, _3718aa1d, length)
        arr2 = [arr[:start]]
        arr3 = [_3718aa1d]
        arr[:source_points][1...-1].each do |pt|
          progress = Calc.arc_length_to(arr[:start], pt, arr[:center], arr[:radius], arr[:clockwise])
          if progress < length - DUP_TOL_MM
            arr2 << pt
          elsif progress > length + DUP_TOL_MM
            arr3 << pt
          end
        end
        arr2 << _3718aa1d unless Calc.distance(arr2.last, _3718aa1d) <= DUP_TOL_MM
        arr3 << arr[:finish] unless Calc.distance(arr3.last, arr[:finish]) <= DUP_TOL_MM
        [arr2, arr3]
      end
    end
    module Locked
      Result = Struct.new(:ok, :elems, :start_point, :align_error_mm, :shape_error_mm, :reversed, :error, keyword_init: true)
      module_function
      def align(elems, lasso_pts, align_tol_mm:, shape_tol_mm:, sample_tol_mm:)
        rows = read_elements(elems)
        path = clean_loop(lasso_pts)
        return failure("no_elems") if rows.empty?
        return failure("open_path") if path.length < 4
        reversed = signed_area(Calc.flatten_loop(rows, sample_tol_mm)) * signed_area(path[0...-1]) < 0.0
        rows = reverse_elements(rows) if reversed
        start_hit = project_start(rows, path.first)
        return failure("no_projection") unless start_hit
        return failure("start_off_path") if start_hit[:distance] > align_tol_mm
        arr = rotate_to_start(rows, start_hit)
        gap2 = arr.zip(arr.rotate).map { |arr2, b| Calc.distance(arr2[:e], b[:s]) }.max
        return failure("aligned_gap") if gap2 > 0.001
        sampled = Calc.flatten_loop(arr, sample_tol_mm)
        raise ArgumentError unless sampled.all? { |pt| pt[0].finite? && pt[1].finite? }
        _dcc2d230 = shape_drift(sampled, path, shape_tol_mm)
        return failure("geometry_drift") if _dcc2d230 > shape_tol_mm
        Result.new(ok: true, elems: Util.freeze_rows(arr), start_point: start_hit[:point].freeze,
                   align_error_mm: start_hit[:distance], shape_error_mm: _dcc2d230, reversed: reversed)
      rescue StandardError
        failure("bad_elems")
      end
      def read_elements(elems)
        Array(elems).map do |row|
          sheet_type = Util.fetch_required(row, :type).to_sym
          raise ArgumentError unless sheet_type == :line || sheet_type == :arc
          _0d6b8add = { type: sheet_type, s: Calc.pt(Util.fetch_required(row, :s)), e: Calc.pt(Util.fetch_required(row, :e)) }
          next _0d6b8add if sheet_type == :line
          _0d6b8add.merge!(c: Calc.pt(Util.fetch_required(row, :c)), ccw: !!Util.lookup(row, :ccw),
                         full_circle: !!Util.lookup(row, :full_circle))
        end
      end
      def reverse_elements(elems)
        elems.reverse.map do |h|
          arr = h.merge(s: h[:e], e: h[:s])
          arr[:ccw] = !h[:ccw] if h[:type] == :arc
          arr
        end
      end
      def rotate_to_start(elems, start_hit)
        idx, _54c4f9e6 = start_hit.values_at(:index, :point)
        arr = elems[idx]
        return elems.rotate(idx) if Calc.distance(_54c4f9e6, arr[:s]) <= 1.0e-7
        return elems.rotate(idx + 1) if Calc.distance(_54c4f9e6, arr[:e]) <= 1.0e-7
        _7d4993b9, _ec4270a0 = element_start(arr, _54c4f9e6)
        [_7d4993b9] + elems[(idx + 1)..] + elems[0...idx] + [_ec4270a0]
      end
      def element_start(arr, h)
        h2 = arr[:type] == :line ? { type: :line } : { type: :arc, c: arr[:c].dup, ccw: arr[:ccw], full_circle: false }
        [h2.merge(s: h.dup, e: arr[:e].dup), h2.merge(s: arr[:s].dup, e: h.dup)]
      end
      def project_start(elems, target)
        arr3 = elems.each_with_index.filter_map do |arr, idx|
          hit = arr[:type] == :line ? Calc.closest_on_line(arr, target) : Calc.closest_on_arc(arr, target)
          hit&.merge!(index: idx)
        end
        arr3.min_by { |arr2| arr2[:distance] }
      end
      def within?(row0, _55d3a52b, max_allowed:)
        shape_drift(clean_loop(row0), clean_loop(_55d3a52b), max_allowed)
      end
      def shape_drift(arr, b, per_row)
        return Float::INFINITY if arr.length < 2 || b.length < 2
        _fa6c44a5 = Native.max_distance(arr, b, per_row)
        return _fa6c44a5 if _fa6c44a5 > per_row
        _2b3bc252 = Native.max_distance(b, arr, per_row)
        _fa6c44a5 > _2b3bc252 ? _fa6c44a5 : _2b3bc252
      end
      def clean_loop(out)
        rows = []
        last_rect = nil
        out.each do |val|
          pt = Calc.pt(val)
          rows << (last_rect = pt) if last_rect.nil? || Math.hypot(last_rect[0] - pt[0], last_rect[1] - pt[1]) > 1.0e-9
        end
        rows << rows.first.dup if rows.length >= 3 && Calc.distance(rows.first, last_rect) > 1.0e-9
        rows
      end
      def signed_area(out)
        out = out[0...-1] if out.length > 1 && Calc.distance(out.first, out.last) <= 1.0e-9
        Calc.signed_area(out)
      end
      def failure(error)
        Result.new(ok: false, elems: [].freeze, error: error)
      end
    end
  end
end
