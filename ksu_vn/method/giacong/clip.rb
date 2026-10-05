module KSU
  module Cnc
    module Rail
      Result = Struct.new(:ok, :reason, :elems, keyword_init: true)
      module_function
      def narrow_scan(out, tool_r_mm:)
        boundary = Refit.clean_points(out)
        return failure("source_undersize") if boundary.length < 3
        return failure("source_oversize") if boundary.length > 1500
        num = Calc.signed_area(boundary)
        return failure("flat_area_prescreen") unless num.abs > 1.0e-9
        return failure("no_concave_prescreen") unless narrow_run(boundary, num.positive?, tool_r_mm)
        arr2 = Refit.refit(boundary)
        set_status = arr2[:status]
        return failure("rebuild_#{set_status}") unless set_status == "rebuilt_ok"
        elems = arr2[:elems]
        return failure("elem_count_bad") if elems.length < 3 || elems.length > 160
        return failure("need_line_and_arc") unless (%i[line arc] - elems.map { |arr| arr[:type] }).empty?
        arr3 = boundary.rotate(arr2[:reconstruction][:rotation_index])
        elems.each do |arr|
          next unless arr[:type] == :arc
          return failure("arc_radial_over") if arr[:radial_mm] > 0.002
          return failure("arc_bulge_over") if arr[:bulge_mm] > 0.30
          return failure("arc_sweep_over") if arr[:sweep_deg] > 180.0 + 1.0e-7
          start2 = arr3[arr[:src_start]..arr[:src_end]]
          arr4 = start2.each_cons(2).map { |a, b| Calc.angle_between(a, b, arr[:c]) * 180.0 / Math::PI }.max
          return failure("arc_step_over") if arr4 > 30.0 + 1.0e-7
        end
        Result.new(ok: true, elems: elems)
      rescue StandardError
        failure("vetting_error")
      end
      def narrow_run(boundary, ccw, r)
        arr = boundary + [boundary[0], boundary[1]]
        start2 = 0
        (1..boundary.length).any? do |idx|
          sample_tol_mm = Refit.circle_at(arr[idx - 1], arr[idx], arr[idx + 1])
          flag = sample_tol_mm && (ccw ? sample_tol_mm[:turn] < 0 : sample_tol_mm[:turn] > 0) && sample_tol_mm[:radius_mm] <= r + 0.02 &&
                    sample_tol_mm[:max_step_deg] <= 30.0 + 1.0e-7
          start2 = flag ? start2 + 1 : 0
          start2 >= 3
        end
      end
      def failure(reason)
        Result.new(ok: false, reason: reason)
      end
    end
    module Gate
      RADIUS_EPS_MM = 0.001
      Result = Struct.new(:eligible, :reason, :metadata, keyword_init: true)
      module_function
      def gate_check(elems, tool_r_mm:)
        rows = elems.map { |arr| Arc.read_element(arr) }
        return ok(false, "few_elems") if rows.length < 3
        return ok(false, "full_circle_banned") if rows.any? { |arr| arr[:type] == :arc && arr[:full_circle] }
        return ok(false, "need_line_and_arc") unless (%i[line arc] - rows.map { |arr| arr[:type] }).empty?
        base_area = Calc.path_area(rows)
        return ok(false, "flat_source_area") unless base_area.finite? && base_area.abs > Arc::HIT_EPS_MM
        flag = base_area.positive?
        collapse = rows.count do |arr|
          next false unless arr[:type] == :arc && arr[:ccw] != flag
          arr[:radius_mm] <= tool_r_mm + RADIUS_EPS_MM && arr[:radius_mm] - tool_r_mm <= RADIUS_EPS_MM &&
            Calc.arc_sweep(arr).abs <= Math::PI + 1.0e-9
        end
        return ok(false, "no_concave_fold") if collapse.zero?
        ok(true, "concave_fold", { source_ccw: flag, folded_arcs: collapse })
      end
      def ok(eligible, reason, metadata = {})
        Result.new(eligible: eligible, reason: reason, metadata: metadata.freeze)
      end
    end
    module Clip
      QUANT_MM = 0.001
      EDGE_MIN_MM = 0.0005
      JOINT_SNAP_MM = 0.008
      BOUNDARY_DISTANCE_MM = 0.012
      TANGENT_SHIFT_MM = 0.30
      TANGENT_MIN_LINE_MM = 0.50
      Result = Struct.new(:ok, :candidates, :error, :metadata, keyword_init: true)
      module_function
      def clipper_offset(paths, delta)
        ::KSU::Clipper.offset(paths, delta, 0.001, 0, 6, 2.0)
      rescue StandardError
        nil
      end
      def offset_polygon(base_pts, radius_mm:)
        boundary = dedupe_ring(base_pts)
        r = Calc.positive_float(radius_mm)
        return failure("bad_radius") unless r
        return failure("few_points") if boundary.length < 3
        return failure("self_intersect") if elements_cross?(boundary)
        num = Calc.signed_area(boundary)
        return failure("small_area") if num.abs <= 0.001
        flag = num < 0.0 ? boundary.reverse : boundary
        arr2 = [r, -r].filter_map do |delta|
          polygons = ::KSU::Clipper.offset([flag], delta, 0.00025, 0, 3, 2.0).filter_map do |arr|
            arr = arr.rotate if delta < 0.0 && arr.length >= 3 && arr[-1][1] == arr[0][1]
            arr = dedupe_ring(arr)
            arr if arr.length >= 3 && Calc.signed_area(arr).abs > 0.001
          end
          { delta_mm: delta, polygons: polygons } unless polygons.empty?
        rescue StandardError
          nil
        end
        return failure("offset_failed") if arr2.empty?
        Result.new(ok: true, candidates: arr2.freeze, error: nil, metadata: {}.freeze)
      end
      def mend_polygon(path_xy, base_pts, radius_mm:, mend: false)
        path = dedupe_ring(path_xy)
        boundary = dedupe_ring(base_pts)
        r = Calc.positive_float(radius_mm)
        return failure("bad_radius") unless r
        return failure("few_points") if path.length < 3 || boundary.length < 3
        labels = Calc::NATIVE ? Native.round_labels(path, boundary, r) : nil
        labels ||= path.map do |pt|
          arr4 = boundary.map { |center| (Calc.distance(pt, center) - r).abs }
          arr4.each_index.select { |idx| arr4[idx] <= 0.004 }.min_by { |idx| arr4[idx] }
        end
        rows = []
        path.each_index do |idx|
          row0, last_rect = path[idx], path[(idx + 1) % path.length]
          lbl = labels[idx]
          if lbl && lbl == labels[(idx + 1) % path.length]
            center = boundary[lbl]
            s, arr2 = Calc.project_to_radius(center, row0, r), Calc.project_to_radius(center, last_rect, r)
            return failure("no_round_join") unless s && arr2
            ax, ay = s[0] - center[0], s[1] - center[1]
            bx2, by2 = arr2[0] - center[0], arr2[1] - center[1]
            num = Math.atan2((ax * by2) - (ay * bx2), (ax * bx2) + (ay * by2))
            _88ca3e20 = Math.hypot((row0[0] + last_rect[0]) * 0.5 - center[0], (row0[1] + last_rect[1]) * 0.5 - center[1])
            num2 = ((r - _88ca3e20) - r * (1.0 - Math.cos(num.abs * 0.5))).abs
            if num.abs >= Math::PI / 360.0 && num.abs <= Math::PI * 0.75 &&
               _88ca3e20 <= r + (QUANT_MM * 2.0) && num2 <= (QUANT_MM * 4.0)
              ccw = num.positive?
              arr = rows.last
              next arr[:e] = arr2 if arr && same_arc?(arr, lbl, ccw, s)
              next rows << { type: :arc, s: s, e: arr2, c: center.dup, ccw: ccw, full_circle: false, src_vertex: lbl }
            end
          end
          rows << { type: :line, s: row0.dup, e: last_rect.dup }
        end
        rows = rotate_off_arc(rows)
        arr3 = arr5 = []
        if mend
          rows, arr3 = rejoin_rounds(rows, r)
          rows, arr5 = rejoin_arcs(rows, r)
        end
        rows = find_arc_seam(rows)
        rows &&= find_arc_seam(arc_segment(rows))
        return failure("open_loop") unless rows
        return failure("no_round_join") unless rows.any? { |arr| arr[:type] == :arc }
        tol = arr3.any? ? 0.45 : (arr5.any? ? 0.10 : 0.052)
        sampled = flatten_loop(rows)
        return failure("refit_drift") unless within?(sampled, ring(path), tol) <= tol
        success(rows, bridge_mend_count: arr3.length, sampled: sampled)
      end
      def offset_elements(elems, radius_mm:)
        r = Calc.positive_float(radius_mm)
        return failure("bad_radius") unless r
        rows = elems.map { |h| Util.dup_array_values(h) }
        return failure("few_segments") if rows.length < 3
        return failure("open_loop") unless elements_joined?(rows)
        rows.each do |h|
          next unless h[:type] == :arc
          h[:skip_mend] = true unless [h[:s], h[:e]].all? { |pt| (Calc.distance(pt, h[:c]) - r).abs <= 0.06 }
        end
        rows, arr = rejoin_rounds(rows, r)
        return failure("no_bridge_mend") if arr.empty?
        rows.each { |h| h.delete(:skip_mend) }
        rows, arr2 = rejoin_arcs(rows, r, arr.map { |h| h[:arc_origin_mm] })
        rows = find_arc_seam(rows)
        rows &&= find_arc_seam(arc_segment(rows))
        return failure("open_loop") unless rows && elements_joined?(rows)
        success(rows, bridge_mend_count: arr.length, bridge_mends: arr.freeze, tangent_mends: arr2.freeze)
      end
      def offset_shape(source_elems, radius_mm:, cut_side:)
        boundary, base_area, arr2 = offset_base(source_elems, radius_mm)
        return { ok: false, error: "offset_failed" } unless boundary
        rows = arr2.flat_map do |arr3|
          arr3[:polygons].map { |id_str| candidate_from(id_str, boundary, radius_mm, cut_side, base_area, true) }
        end
        arr = rows.grep(Hash)
        if arr.empty? && (rows.include?(:topology) || rows.grep(Array).any? { |polygon| !polygon_valid?(polygon) })
          arr = offset_both_ways(boundary, radius_mm, cut_side, base_area)
        end
        return { ok: false, error: "no_unique_region" } unless arr.length == 1
        polygon = arr.first[:polygon]
        _877fe383 = { promoted: false, tangency_promoted: false }
        _28d5c275 = mend_polygon(polygon, boundary, radius_mm: radius_mm)
        if _28d5c275.ok
          _3a5f8009 = rebuild_elements(_28d5c275.candidates, polygon, source_elems, radius_mm: radius_mm)
          best = _3a5f8009.ok ? _3a5f8009 : _28d5c275
          elems = best.candidates
          _11fc3a8c = refit_check(elems, best.metadata[:sampled], polygon, boundary, radius_mm)
          _877fe383 = { promoted: true, tangency_promoted: _3a5f8009.ok, refit_check: _11fc3a8c } if _11fc3a8c
        end
        elems = polygon.zip(polygon.rotate).map { |h, b| { type: :line, s: h.dup, e: b.dup } } unless _11fc3a8c
        { ok: true, elems: elems, distance_check: arr.first[:distance_check], arc_rebuilt: _877fe383 }
      rescue StandardError => err
        { ok: false, error: err.message }
      end
      def offset_candidates(rows, out, r, side)
        boundary, base_area, _b22f4148 = offset_base(rows, r)
        return unless boundary
        polygons = _b22f4148.filter_map do |arr|
          next unless arr[:polygons].length == 1
          polygon = arr[:polygons].first
          num = Calc.signed_area(polygon)
          polygon if side == "inside" ? num.abs < base_area.abs : num.abs > base_area.abs
        end
        return unless polygons.length == 1
        _5567b9be = ring(polygons.first)
        arr2 = out.select { |pt| Calc.polyline_distance(pt, _5567b9be) <= 0.060 + QUANT_MM }
        arr2.first if arr2.length == 1
      end
      def failure(error)
        Result.new(ok: false, candidates: [].freeze, error: error, metadata: {}.freeze)
      end
      def success(rows, **metadata)
        Result.new(ok: true, candidates: rows.map { |row| freeze_element(row) }.freeze, error: nil, metadata: metadata.freeze)
      end
      def dedupe_ring(out)
        Calc.dedupe_loop(out, EDGE_MIN_MM, true)
      end
      def ring(out)
        rows = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        rows << rows.first.dup if rows.length >= 3 && Calc.distance(rows.first, rows.last) > 1.0e-9
        rows
      end
      def flatten_loop(elems)
        rows = []
        elems.each do |arr|
          out = [arr[:s], arr[:e]]
          if arr[:type] == :arc
            center = arr[:c]
            r = Calc.distance(arr[:s], center)
            a0 = Calc.deg4(arr[:s], center)
            sweep = Calc.sweep_between(a0, Calc.deg4(arr[:e], center), arr[:ccw])
            num = 2.0 * Math.acos([[1.0 - 0.0005 / r, -1.0].max, 1.0].min)
            num = Math::PI / 180.0 unless num > 1.0e-8
            out = Calc.arc_points(center, r, a0, sweep, [[(sweep.abs / num).ceil, 1].max, 4096].min)
            out[-1] = arr[:e]
          end
          out.each { |pt| rows << pt if rows.empty? || Calc.distance(rows.last, pt) > 1.0e-9 }
        end
        ring(rows)
      end
      def freeze_element(row)
        result = row.transform_values { |h| h.is_a?(Array) ? h.dup.freeze : h }
        result.delete(:src_vertex)
        result.freeze
      end
      def elements_joined?(rows)
        return false if rows.length < 2
        rows.each_index.all? { |idx| Calc.distance(rows[idx][:e], rows[(idx + 1) % rows.length][:s]) <= JOINT_SNAP_MM }
      end
      def elements_cross?(rows)
        flag = Calc::NATIVE ? Native.sweep_intersects(rows) : nil
        return flag unless flag.nil?
        want = rows.length
        polygon_self_cross?(rows, 0.0) do |i, ix|
          Calc.segments_properly_cross?(rows[i], rows[(i + 1) % want], rows[ix], rows[(ix + 1) % want])
        end
      end
      def polygon_self_cross?(out, eps)
        want = out.length
        return false if want < 4
        _48a302ae = Array.new(want) do |idx|
          arr, b = out[idx], out[(idx + 1) % want]
          [idx, [arr[0], b[0]].min, [arr[0], b[0]].max, [arr[1], b[1]].min, [arr[1], b[1]].max]
        end
        active_ix = []
        _48a302ae.sort_by! { |screen_box| screen_box[1] }.each do |screen_box|
          _fe479353 = screen_box[1] - eps
          active_ix.delete_if { |panel| panel[2] < _fe479353 }
          active_ix.each do |panel|
            i, ix = panel[0], screen_box[0]
            i, ix = ix, i if ix < i
            next if ix - i == 1 || (i.zero? && ix == want - 1)
            next if panel[4] < screen_box[3] - eps || screen_box[4] < panel[3] - eps
            return true if yield(i, ix)
          end
          active_ix << screen_box
        end
        false
      end
      def pair_crosses?(out, i, ix)
        eps = 1.0e-9
        arr, b = out[i], out[(i + 1) % out.length]
        arr2, len2d = out[ix], out[(ix + 1) % out.length]
        _79b595ce, _0c502f23 = Calc.distance(arr, b), Calc.distance(arr2, len2d)
        num5, num4 = Calc.cross(arr, b, arr2) / _79b595ce, Calc.cross(arr, b, len2d) / _79b595ce
        num2, num3 = Calc.cross(arr2, len2d, arr) / _0c502f23, Calc.cross(arr2, len2d, b) / _0c502f23
        return true if ((num5 > eps && num4 < -eps) || (num5 < -eps && num4 > eps)) &&
                       ((num2 > eps && num3 < -eps) || (num2 < -eps && num3 > eps))
        if num5.abs <= eps && num4.abs <= eps && num2.abs <= eps && num3.abs <= eps
          num = (b[0] - arr[0]).abs >= (b[1] - arr[1]).abs ? 0 : 1
          _fe479353 = [[arr[num], b[num]].min, [arr2[num], len2d[num]].min].max
          return [[arr[num], b[num]].max, [arr2[num], len2d[num]].max].min - _fe479353 >= -eps
        end
        Calc.point_segment_distance(arr, arr2, len2d) <= eps || Calc.point_segment_distance(b, arr2, len2d) <= eps ||
          Calc.point_segment_distance(arr2, arr, b) <= eps || Calc.point_segment_distance(len2d, arr, b) <= eps
      end
      def build_index(arr)
        want = arr.length - 1
        segments = Array.new(want) do |idx|
          x1, y1 = arr[idx]
          x2, y2 = arr[idx + 1]
          [x1 < x2 ? x1 : x2, y1 < y2 ? y1 : y2, x1 > x2 ? x1 : x2, y1 > y2 ? y1 : y2, [x1, y1], [x2, y2]]
        end
        { root: index_bounds(segments, (0...want).to_a), segments: segments }
      end
      def index_bounds(segments, arr)
        _c62e3767 = _79d02a93 = Float::INFINITY
        _c9060cb1 = _eda2d8bc = -Float::INFINITY
        arr.each do |id|
          screen_box = segments[id]
          _c62e3767 = screen_box[0] if screen_box[0] < _c62e3767
          _79d02a93 = screen_box[1] if screen_box[1] < _79d02a93
          _c9060cb1 = screen_box[2] if screen_box[2] > _c9060cb1
          _eda2d8bc = screen_box[3] if screen_box[3] > _eda2d8bc
        end
        return [_c62e3767, _79d02a93, _c9060cb1, _eda2d8bc, arr.sort] if arr.length <= 8
        flag = (_c9060cb1 - _c62e3767) >= (_eda2d8bc - _79d02a93) ? 0 : 1
        ordered = arr.sort_by { |id| [(segments[id][flag] + segments[id][flag + 2]) * 0.5, id] }
        num = ordered.length / 2
        [_c62e3767, _79d02a93, _c9060cb1, _eda2d8bc, nil, index_bounds(segments, ordered[0...num]), index_bounds(segments, ordered[num..-1])]
      end
      def nearest_on_index(pt, idx, limit_mm)
        trai, duoi = pt
        segments = idx[:segments]
        best = _0725e9cf = Float::INFINITY
        num = -1
        if limit_mm
          best = Calc.point_segment_distance(pt, segments[limit_mm][4], segments[limit_mm][5])
          _0725e9cf = best * best
          num = limit_mm
        end
        arr = [idx[:root]]
        until arr.empty?
          node4 = arr.pop
          next if Calc.box_distance2(trai, duoi, node4) > _0725e9cf
          if node4[4]
            node4[4].each do |fld|
              next if limit_mm && fld == num
              seg = segments[fld]
              next if Calc.box_distance2(trai, duoi, seg) > _0725e9cf
              val = Calc.point_segment_distance(pt, seg[4], seg[5])
              next unless val < best || (val == best && fld < num)
              best = val
              _0725e9cf = val * val
              num = fld
            end
          elsif Calc.box_distance2(trai, duoi, node4[5]) <= Calc.box_distance2(trai, duoi, node4[6])
            arr.push(node4[6], node4[5])
          else
            arr.push(node4[5], node4[6])
          end
        end
        { distance_mm: best, segment_index: num }
      end
      def within?(arr, b, tol_mm)
        return Float::INFINITY if arr.length < 2 || b.length < 2
        hi = Calc::NATIVE ? Native.hausdorff(arr, b, tol_mm) : nil
        return hi if hi
        hi = 0.0
        [[arr, b], [b, arr]].each do |out, _b70d2c2f|
          idx = build_index(_b70d2c2f)
          cands2 = nil
          out.each do |pt|
            arr2 = nearest_on_index(pt, idx, cands2)
            cands2 = arr2[:segment_index]
            hi = arr2[:distance_mm] if arr2[:distance_mm] > hi
            return hi if hi > tol_mm
          end
        end
        hi
      end
      def path_drift(path_pts, base_pts, r)
        path = ring(path_pts)
        boundary = ring(base_pts)
        return { ok: false } if path.length < 4 || boundary.length < 4
        per_row = BOUNDARY_DISTANCE_MM + QUANT_MM * 2.0 + 0.0005
        ok = Calc::NATIVE ? Native.boundary_error(path, boundary, r) : nil
        return { ok: ok <= per_row } if ok
        return { ok: false } if (path.length - 1) * 4 > 120_000
        idx = build_index(boundary)
        cands2 = nil
        ok = 0.0
        path.each_cons(2) do |row0, last_rect|
          [0.0, 0.25, 0.5, 0.75].each do |_5f343815|
            arr = nearest_on_index(Calc.lerp(row0, last_rect, _5f343815), idx, cands2)
            cands2 = arr[:segment_index]
            num = (arr[:distance_mm] - r).abs
            ok = num if num > ok
          end
        end
        { ok: ok <= per_row }
      end
      def rotate_off_arc(rows)
        row0 = rows.first
        return rows unless rows.length > 1 && row0[:type] == :arc
        return rows unless same_arc?(rows.last, row0[:src_vertex], row0[:ccw], row0[:s])
        rows.shift
        rows.last[:e] = row0[:e].dup
        rows
      end
      def same_arc?(arr, mid, ccw, start)
        arr[:type] == :arc && arr[:src_vertex] == mid && arr[:ccw] == ccw &&
          Calc.distance(arr[:e], start) <= JOINT_SNAP_MM
      end
      def find_arc_seam(rows)
        return nil if rows.empty?
        rows.each_with_index do |arr, idx|
          b2 = rows[(idx + 1) % rows.length]
          gap2 = Calc.distance(arr[:e], b2[:s])
          return nil unless gap2 <= JOINT_SNAP_MM
          next if gap2 <= 1.0e-12
          if arr[:type] == :arc && b2[:type] == :line
            b2[:s] = arr[:e].dup
          elsif arr[:type] == :line && b2[:type] == :arc
            arr[:e] = b2[:s].dup
          elsif arr[:type] == :line && b2[:type] == :line
            arr[:e] = [(arr[:e][0] + b2[:s][0]) * 0.5, (arr[:e][1] + b2[:s][1]) * 0.5]
            b2[:s] = arr[:e].dup
          else
            return nil
          end
        end
        rows
      end
      def arc_segment(rows)
        flag = true
        while flag && rows.length > 1
          flag = false
          result = []
          rows.each do |arr|
            if result.any? && result.last[:type] == :line && arr[:type] == :line && arc_direction(result.last, arr)
              result.last[:e] = arr[:e].dup
              flag = true
            else
              result << arr
            end
          end
          rows = result
        end
        rows
      end
      def arc_direction(row0, last_rect)
        return false if Calc.distance(row0[:e], last_rect[:s]) > JOINT_SNAP_MM
        ax, ay = row0[:e][0] - row0[:s][0], row0[:e][1] - row0[:s][1]
        bx2, by2 = last_rect[:e][0] - last_rect[:s][0], last_rect[:e][1] - last_rect[:s][1]
        _45b54bd9, _f125bb43 = Math.hypot(ax, ay), Math.hypot(bx2, by2)
        return false if _45b54bd9 <= EDGE_MIN_MM || _f125bb43 <= EDGE_MIN_MM
        (ax * by2 - ay * bx2).abs / (_45b54bd9 * _f125bb43) <= 1.0e-6 && (ax * bx2 + ay * by2) / (_45b54bd9 * _f125bb43) > 0.999999
      end
      def rejoin_arcs(rows, r, on_change = nil)
        arr3 = []
        rows.each_with_index do |arr, idx|
          b2 = rows[(idx + 1) % rows.length]
          if arr[:type] == :arc && b2[:type] == :line
            arc, axis, _e7513c77, _b658f3bf = arr, b2, :e, :s
          elsif arr[:type] == :line && b2[:type] == :arc
            arc, axis, _e7513c77, _b658f3bf = b2, arr, :s, :e
          else
            next
          end
          e = arc[_e7513c77]
          next if Calc.distance(e, axis[_b658f3bf]) > JOINT_SNAP_MM
          center = arc[:c]
          next if on_change && on_change.none? { |path| Calc.distance(center, path) <= JOINT_SNAP_MM }
          next unless Calc.distance(axis[:s], axis[:e]) >= 1.0
          arr2 = Calc.project_on_line(center, axis[:s], axis[:e])
          _ae61224b = Calc.distance(center, arr2)
          next unless _ae61224b > 1.0e-12 && (_ae61224b - r).abs <= 0.006
          h = [center[0] + (arr2[0] - center[0]) * r / _ae61224b,
                     center[1] + (arr2[1] - center[1]) * r / _ae61224b]
          ctrl = Calc.distance(e, h)
          next if ctrl <= 1.0e-9 || ctrl > 0.15
          num = Calc.arc_sweep(arc.merge(_e7513c77 => h)).abs - Calc.arc_sweep(arc).abs
          next if num < -(Math::PI / 18_000.0) || num > Math::PI / 36.0
          arc[_e7513c77] = h.dup
          axis[_b658f3bf] = h.dup
          arr3 << { point: h.freeze, arc_origin_mm: center.first(2).freeze, wanted_r_mm: r,
                        joint_move_mm: ctrl, exact_join: "near_tangent_fixed" }
        end
        [rows, arr3]
      end
      def rejoin_rounds(rows, r)
        arr3 = []
        64.times do
          want = rows.length
          break if want < 3
          flag = want.times.any? do |idx|
            row0 = rows[idx]
            arr2 = rows[(idx + 1) % want]
            last_rect = rows[(idx + 2) % want]
            next false unless arr2[:type] == :line
            arr = if row0[:type] == :line && last_rect[:type] == :arc && !last_rect[:skip_mend]
                round_between(row0, arr2, last_rect, r, true)
              elsif row0[:type] == :arc && !row0[:skip_mend] && last_rect[:type] == :line
                round_between(last_rect, arr2, row0, r, false)
              end
            next false unless arr
            row0[:e] = arr[:point].dup
            last_rect[:s] = arr[:point].dup
            rows.delete_at((idx + 1) % want)
            arr3 << arr
            true
          end
          break unless flag
        end
        [rows, arr3]
      end
      def round_between(elem_state, arr, arc, r, at_start)
        _811071da, _7aca6700 = Calc.distance(elem_state[:s], elem_state[:e]), Calc.distance(arr[:s], arr[:e])
        return nil if _7aca6700 < 0.001 || _7aca6700 > [[r * 0.22, 0.45].max, 0.75].min
        return nil if _811071da < [1.0, r * 0.50, _7aca6700 * 2.5].max
        _4364da70, flag = at_start ? [elem_state[:e], arc[:s]] : [elem_state[:s], arc[:e]]
        head_off, tail_pt = at_start ? [_4364da70, flag] : [flag, _4364da70]
        return nil if Calc.distance(head_off, arr[:s]) > JOINT_SNAP_MM
        return nil if Calc.distance(arr[:e], tail_pt) > JOINT_SNAP_MM
        center = arc[:c]
        _40a8c77d = [[r * 0.45, 0.75].max, 1.50].min
        num2 = Calc.arc_sweep(arc).abs
        return nil unless num2.positive?
        best = Calc.ray_circle_hits(elem_state[:s], elem_state[:e], center, r).filter_map do |pt|
          _eaab8d3a = Calc.distance(pt, _4364da70)
          _a2a31c7d = Calc.distance(pt, flag)
          next if _eaab8d3a > _40a8c77d || _a2a31c7d > _40a8c77d
          num = Calc.arc_sweep(arc.merge((at_start ? :s : :e) => pt)).abs - num2
          next if num < -(Math::PI / 18_000.0) || num > Math::PI / 6.0
          [_eaab8d3a + _a2a31c7d, _eaab8d3a, _a2a31c7d, pt, num]
        end.min_by { |arr2| arr2.first(3) }
        return nil unless best
        _, _eaab8d3a, _a2a31c7d, pt, num = best
        { point: pt.dup.freeze, arc_origin_mm: center.first(2).freeze, wanted_r_mm: r,
          bridge_len_mm: _7aca6700, rail_shift_mm: _eaab8d3a, arc_move_mm: _a2a31c7d,
          sweep_extra_deg: num * 180.0 / Math::PI, exact_join: "line_circle_hit" }
      end
      def rebuild_elements(elems, sampled_pts, source_elems, radius_mm:)
        arr = elems.map { |arr3| Util.dup_array_values(arr3) }
        return failure("few_segments") if arr.length < 3
        num2 = shrink_to_fit(arr, source_elems, radius_mm)
        arr2 = {}
        arr.each_with_index do |axis, idx|
          next unless axis[:type] == :line
          arr7 = [arr[idx - 1], arr[(idx + 1) % arr.length]].select { |arr3| arr3[:type] == :arc }
          next if arr7.empty?
          arr6 = tangent_triple(axis, source_elems, arr7.map { |arr3| arr3[:c] }, radius_mm)
          arr2[idx] = arr6 if arr6
        end
        return failure("no_tangent_mend") if arr2.empty? && num2.zero?
        num = 0
        want = arr.length
        want.times do |idx|
          break if num >= 256
          _f273cbbc = (idx + 1) % want
          arr4, arr5 = arr[idx], arr[_f273cbbc]
          e = arr4[:e]
          next if Calc.distance(e, arr5[:s]) > JOINT_SNAP_MM
          _434c9c97 = [arr4[:type], arr5[:type]]
          if _434c9c97 == %i[line arc] && arr2[idx]
            num += 1 if tangent_line(arr4, arr5, arr2[idx], e, radius_mm, :line_arc)
          elsif _434c9c97 == %i[arc line] && arr2[_f273cbbc]
            num += 1 if tangent_line(arr5, arr4, arr2[_f273cbbc], e, radius_mm, :arc_line)
          elsif _434c9c97 == %i[line line] && (arr2[idx] || arr2[_f273cbbc])
            splice_elements(arr4, arr5, arr2[idx], arr2[_f273cbbc])
          end
        end
        return failure("no_tangent_mend") if num.zero? && num2.zero?
        flag = arr2.any? do |idx, arr6|
          [arr[idx][:s], arr[idx][:e]].any? { |pt| Calc.distance_to_line(pt, arr6[:first], arr6[:last]) > 1.0e-8 }
        end
        return failure("line_drift") if flag
        return failure("open_loop") unless elements_joined?(arr)
        sampled = flatten_loop(arr)
        return failure("self_intersect") if elements_cross?(dedupe_ring(sampled))
        return failure("refit_drift") unless within?(sampled, ring(dedupe_ring(sampled_pts)), 0.052) <= 0.052
        success(arr, sampled: sampled)
      end
      def tangent_line(axis, arc, arr, e, r, mode)
        _cb1cc64c = Calc.project_on_line(arc[:c], arr[:first], arr[:last])
        return nil if (Calc.distance(arc[:c], _cb1cc64c) - r).abs > 1.0e-8
        return nil unless Calc.distance(e, _cb1cc64c) <= TANGENT_SHIFT_MM
        sweep_delta(axis, arc, arr, _cb1cc64c, mode == :line_arc)
      end
      def sweep_delta(axis, arc, arr, h, at_start)
        flag = at_start ? :s : :e
        num = Calc.arc_sweep(arc.merge(flag => h)).abs - Calc.arc_sweep(arc).abs
        return nil if num.abs > 7.5 * Math::PI / 180.0
        return nil if Calc.along_axis(arr[:first], arr[:last], h, arc[:c]) > 1.0e-8
        axis[at_start ? :e : :s] = h.dup
        arc[flag] = h.dup
        true
      end
      def splice_elements(arr3, arr5, arr, arr2)
        e = arr3[:e]
        if arr && arr2
          pt = Calc.line_intersection(arr[:first], arr[:last], arr2[:first], arr2[:last], 1.0e-12)
          unless pt
            point = Calc.project_on_line(e, arr[:first], arr[:last])
            pt = point if Calc.distance_to_line(point, arr2[:first], arr2[:last]) <= 1.0e-8
          end
          per_row = 0.30
        else
          arr4 = arr || arr2
          pt = Calc.project_on_line(e, arr4[:first], arr4[:last])
          per_row = 0.052
        end
        return unless pt && Calc.distance(e, pt) <= per_row
        arr3[:e] = pt.dup
        arr5[:s] = pt.dup
      end
      def shrink_to_fit(arr, base_area, r)
        num = 0
        16.times do
          want = arr.length
          break if want < 3
          flag = want.times.any? do |idx|
            _42cd5245 = (idx + 1) % want
            last_rect = (idx + 2) % want
            _434c9c97 = [arr[idx][:type], arr[_42cd5245][:type], arr[last_rect][:type]]
            ok = if _434c9c97 == %i[line line arc]
                tangent_pair(arr[idx], arr[_42cd5245], arr[last_rect], base_area, r, true)
              elsif _434c9c97 == %i[arc line line]
                tangent_pair(arr[last_rect], arr[_42cd5245], arr[idx], base_area, r, false)
              end
            next false unless ok
            arr.delete_at(_42cd5245)
            num += 1
            true
          end
          break unless flag
        end
        num
      end
      def tangent_pair(arr5, arr6, arc, base_area, r, at_start)
        _e48bf237, _9a26378e = arr5[:s], arr5[:e]
        arr3, arr4 = arr6[:s], arr6[:e]
        center = arc[:c]
        _7aca6700 = Calc.distance(arr3, arr4)
        return nil unless _7aca6700 > EDGE_MIN_MM && _7aca6700 <= 0.15
        return nil unless Calc.distance(_9a26378e, _e48bf237) >= TANGENT_MIN_LINE_MM
        _0ac6848a, _1110e2ab = Calc.unit_vector(_e48bf237, _9a26378e)
        _f837c2bc = (((arr4[0] - arr3[0]) / _7aca6700) * _0ac6848a) +
                        (((arr4[1] - arr3[1]) / _7aca6700) * _1110e2ab)
        return nil unless _f837c2bc <= -Math.cos(8.0 * Math::PI / 180.0)
        _a173c4a4, _c7931bff = at_start ? [arc[:s], _9a26378e] : [arc[:e], _e48bf237]
        head_off, tail_pt = at_start ? [_9a26378e, _a173c4a4] : [_a173c4a4, _e48bf237]
        return nil if Calc.distance(head_off, arr3) > JOINT_SNAP_MM
        return nil if Calc.distance(arr4, tail_pt) > JOINT_SNAP_MM
        arr = tangent_triple(arr5, base_area, [center], r)
        return nil unless arr
        arr2 = Calc.project_on_line(center, arr[:first], arr[:last])
        return nil if (Calc.distance(center, arr2) - r).abs > 1.0e-8
        arr7 = [arr3, arr4].map { |pt| Calc.distance_to_line(pt, arr[:first], arr[:last]) }.max
        return nil unless arr7 <= 0.005
        start_hit = ((arr2[0] - _c7931bff[0]) * _0ac6848a) + ((arr2[1] - _c7931bff[1]) * _1110e2ab)
        flag = at_start ? start_hit : -start_hit
        return nil unless flag >= -1.0e-8 && flag <= TANGENT_SHIFT_MM
        _73335f17 = [Calc.distance(_c7931bff, arr2), Calc.distance(_a173c4a4, arr2)].max
        return nil unless _73335f17 <= TANGENT_SHIFT_MM
        sweep_delta(arr5, arc, arr, arr2, at_start)
      end
      def tangent_triple(arr5, base_area, on_change, r)
        _631641ca, _f8187aa6 = arr5[:s], arr5[:e]
        return nil unless Calc.distance(_f8187aa6, _631641ca) >= TANGENT_MIN_LINE_MM
        _1d740702, _b67c602d = Calc.unit_vector(_631641ca, _f8187aa6)
        arr8 = Math.cos(2.0 * Math::PI / 180.0)
        arr6 = []
        base_area.each_with_index do |boundary, _5a11d110|
          next unless boundary[:type] == :line
          arr, arr2 = boundary[:s], boundary[:e]
          next unless Calc.distance(arr2, arr) >= TANGENT_MIN_LINE_MM
          next unless on_change.all? { |center| [Calc.distance(center, arr), Calc.distance(center, arr2)].min <= 0.005 }
          _fa631170, _98aa547e = Calc.unit_vector(arr, arr2)
          num = (_fa631170 * _1d740702) + (_98aa547e * _b67c602d)
          next unless num.abs >= arr8
          [-1.0, 1.0].each do |side|
            nx, ny = -_98aa547e * side, _fa631170 * side
            row0 = [arr[0] + nx * r, arr[1] + ny * r]
            last_rect = [arr2[0] + nx * r, arr2[1] + ny * r]
            row0, last_rect = last_rect, row0 if num.negative?
            arr3 = [_631641ca, _f8187aa6].map { |pt| Calc.distance_to_line(pt, row0, last_rect) }.max
            next unless arr3 <= 0.052
            arr4 = on_change.map do |center|
              _cb1cc64c = Calc.project_on_line(center, row0, last_rect)
              [Calc.distance(_631641ca, _cb1cc64c), Calc.distance(_f8187aa6, _cb1cc64c)].min
            end
            next if arr4.any? { |val| val > TANGENT_SHIFT_MM }
            score = arr3 + Calc.kahan_sum(arr4) * 0.05 + (1.0 - num.abs) * r
            arr6 << [score, arr3, _5a11d110, side.to_i, row0, last_rect]
          end
        end
        best, arr7 = arr6.sort_by { |arr9| arr9.first(4) }
        return nil if best.nil? || (arr7 && (arr7[0] - best[0]).abs <= 1.0e-7)
        { first: best[4], last: best[5] }
      end
      def offset_base(rows, r)
        boundary = dedupe_ring(flatten_loop(rows))
        _553133a8 = offset_polygon(boundary, radius_mm: r)
        [boundary, Calc.signed_area(boundary), _553133a8.candidates] if _553133a8.ok
      end
      def candidate_from(id_str, boundary, r, side, base_area, want_side)
        polygon = dedupe_ring(id_str)
        return if polygon.length < 3
        return :topology if want_side && elements_cross?(polygon)
        num = Calc.signed_area(polygon)
        return polygon if num.abs <= 0.010
        return polygon unless side == "inside" ? num.abs < base_area.abs : num.abs > base_area.abs
        return :topology unless polygon_valid?(polygon)
        polygon.reverse! if num * base_area < 0.0
        arr = path_drift(polygon, boundary, r)
        { polygon: polygon, distance_check: arr } if arr[:ok]
      end
      def polygon_valid?(polygon)
        Validator.validate(polygon.zip(polygon.rotate).map { |a, b| { type: :line, s: a, e: b } }).valid?
      end
      def offset_both_ways(boundary, r, side, base_area)
        [r, -r].flat_map do |delta|
          paths = clipper_offset([boundary], delta) || []
          paths.map { |id_str| candidate_from(id_str, boundary, r, side, base_area, false) }.grep(Hash)
        end
      end
      def refit_check(elems, sampled, polygon, boundary, r)
        return unless Validator.validate(elems).valid?
        flag = elems.all? do |arr|
          arr[:type] != :arc || (Calc.distance(arr[:s], arr[:e]) > EDGE_MIN_MM && Calc.distance(arr[:e], arr[:c]) > EDGE_MIN_MM)
        end
        return unless flag
        sampled = dedupe_ring(sampled)
        return if sampled.length < 3 || elements_cross?(sampled)
        return if polygon_self_cross?(sampled, 1.0e-9) { |i, ix| pair_crosses?(sampled, i, ix) }
        num = Calc.signed_area(sampled)
        return unless num.abs > 0.010 && num * Calc.signed_area(polygon) > 0.0
        return unless within?(ring(sampled), ring(polygon), 0.052) <= 0.052
        arr2 = path_drift(sampled, boundary, r)
        { ok: true, source_check: arr2 } if arr2[:ok]
      end
    end
  end
end
