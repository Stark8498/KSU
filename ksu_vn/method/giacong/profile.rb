module KSU
  module Cnc
    module Export
      module_function
      def build_path(vec, out, tool, anchor, nested)
        arr = { vector: vec, points: out, tool: tool, origin: anchor, nested: nested, preview: sim_view? }
        done = stage_offset(arr) || stage_validate(arr)
        return done if done
        return stage_salvage(arr) if arr[:invalid]
        stage_dogbone(arr) ||
          stage_gouge(arr) ||
          stage_lead(arr) ||
          stage_passes(arr) ||
          stage_check(arr) ||
          stage_done(arr)
      end
      def err_tool_too_big
        { ok: false, error: Text.t(:duong, :dao_qua_lon) }
      end
      def err_bad_path
        { ok: false, error: Text.t(:duong, :van_de) }
      end
      def elem_lock(elems, addon_data = {})
        { schema: "xnc_round_join_v3", enabled: true, keep_elems: true, arc_repack_ok: false, clipper_salvage: true,
          elems: elems }.merge(addon_data)
      end
      def orient_path(path, tool, base_xy)
        rotate_to_corner(orient(path, tool), tool["entry_corner"], base_xy)
      end
      def apply_lead(path, tool)
        lead_shift_mm = tool["khoang_cach_xuong_dao"].to_f
        [ring(shift_lead(path, -lead_shift_mm)), lead_shift_mm]
      end
      def stage_offset(arr)
        bb, tool, anchor = arr.values_at(:vector, :tool, :origin)
        r = tool["diameter"].to_f.abs * 0.5
        return err_bad_path unless r.positive?
        side = cut_side_of(tool, arr[:nested])
        side = arr[:nested] ? "inside" : "outside" if side == "auto"
        side = "outside" if side == "flip_side"
        base_xy = dedupe(arr[:points].map { |pt| to_mm(pt, anchor) })
        return err_bad_path if base_xy.length < 3
        arr.update(radius: r, side: side)
        arr[:circular] = bb.center && [:circle, :arc].include?(bb.vector_type)
        arr3 = narrow_rescue(bb, base_xy, anchor, r, side) unless arr[:circular]
        if arr3
          return err_tool_too_big unless arr3[:ok]
          offset_xy = arr3[:path]
          arr[:lock] = arr3[:elem_lock]
          arr[:rescued] = arr[:final_boundary] = arr3[:final_boundary]
          arr[:narrow] = true
        else
          outline = arr[:points]
          arr2 = simplify_points(ring(base_xy))
          arr2.pop while arr2.length > 1 && same_xy?(arr2.first, arr2.last)
          if arr2.length >= 3 && arr2.length < base_xy.length
            outline = arr2.map { |pt| to_model_point(pt, anchor) }
            base_xy = arr2
          end
          if arr[:circular]
            offset_xy = circle_path(bb, outline, anchor, r, side)
          else
            saved = outline.map { |pt| to_mm(pt, anchor) }
            saved.pop while saved.length > 1 && same_xy?(saved.first, saved.last)
            arr4 = offset_loop(base_xy, r, side, saved)
            offset_xy = arr4[:path]
            unless arr4[:ok]
              arr5 = offset_fallback(base_xy, r, side)
              return { ok: false, error: arr4[:error] } unless arr5[:ok]
              offset_xy = arr5[:path]
              arr.update(rescued: true, elems: arr5[:elems])
            end
          end
        end
        return err_bad_path if offset_xy.nil? || offset_xy.length < 3
        arr.update(base_xy: base_xy, offset_xy: dedupe(offset_xy))
        nil
      end
      def stage_validate(arr)
        r, side, base_xy, offset_xy = arr.values_at(:radius, :side, :base_xy, :offset_xy)
        inside = side == "inside"
        return err_tool_too_big if inside && !fits_inside?(offset_xy, base_xy, r)
        lock = arr[:lock]
        lock ||= elem_lock(arr[:elems]) if Array(arr[:elems]).any?
        flag21 = !arr[:narrow] && (self_intersects?(offset_xy) || inverted?(offset_xy, base_xy, inside) ||
                                            !offset_side_ok?(offset_xy, base_xy, r, side))
        if flag21 && side == "outside" && !dogbone_layer?(arr[:vector])
          arr3 = offset_by_elements(base_xy, r, true)
          if arr3
            offset_xy = dedupe(arr3[:path])
            lock = elem_lock_schema("xnc_arc_fold_v1", arr3[:elems], 0.02)
            arr[:rescued] = nil
            flag21 = false
          end
        end
        if flag21 && !arr[:circular]
          arr2 = offset_fallback(base_xy, r, side)
          if arr2[:ok]
            offset_xy = dedupe(arr2[:path])
            arr[:rescued] = true
            lock = Array(arr2[:elems]).any? ? elem_lock(arr2[:elems]) : nil
            flag21 = offset_xy.length < 3 || self_intersects?(offset_xy) || inverted?(offset_xy, base_xy, inside) ||
                      !offset_side_ok?(offset_xy, base_xy, r, side)
          end
        end
        arr.update(offset_xy: offset_xy, lock: lock, invalid: flag21)
        nil
      end
      def stage_salvage(arr)
        tool, r, side, base_xy = arr.values_at(:tool, :radius, :side, :base_xy)
        id_str = dedupe(arr[:offset_xy])
        return err_tool_too_big unless offset_side_ok?(id_str, base_xy, r, side)
        lead_shift_mm = tool["khoang_cach_xuong_dao"].to_f
        path = dedupe(shift_lead(orient_path(ring(id_str), tool, base_xy), -lead_shift_mm))
        closed = ring(close_path(path)) unless self_intersects?(path)
        if closed && closed.length >= 4 && offset_side_ok?(closed, base_xy, r, side) &&
           (side != "inside" || fits_inside?(closed, base_xy, r)) &&
           gouge_at(closed, gouge_guide_for(arr)).nil?
          return { ok: true, path: closed, base: ring(base_xy), cut_side: side, lead_shift_mm: lead_shift_mm }
        end
        err_tool_too_big
      end
      def offset_loop(base_xy, r, side, saved)
        rows = dedupe(base_xy)
        return err_bad_path if rows.length < 3
        arr2 = circle_fit(rows)
        arr = arr2 && offset_circle(arr2[:center], arr2[:radius], rows, r, side)
        return { ok: true, path: arr } if arr && arr.length >= 3
        return offset_inside(base_xy, r) if side == "inside"
        path = offset_native(saved, r, side) if saved.length >= 3
        path && path.length >= 3 ? { ok: true, path: path } : err_bad_path
      end
      def stage_dogbone(arr)
        r, side, base_xy, offset_xy = arr.values_at(:radius, :side, :base_xy, :offset_xy)
        arr[:dogbone] = dogbone_layer?(arr[:vector])
        _ac4ed97e = ring(offset_xy)
        if arr[:dogbone]
          arr[:lock] = nil if lock_enabled?(arr[:lock])
          return err_bad_path if gouge_at(_ac4ed97e, gouge_guide_for(arr))
          ok = Dogbone.relief_path(base_xy, offset_xy, r, side)
          return err_bad_path unless ok[:ok]
          _ac4ed97e = ok[:path]
          arr2 = relock_dogbone(_ac4ed97e, base_xy, r) unless arr[:preview]
          if arr2
            return err_bad_path unless arr2[:ok]
            _ac4ed97e = arr2[:path]
            arr[:lock] = arr2[:elem_lock]
          end
        end
        return err_bad_path unless offset_side_ok?(_ac4ed97e, base_xy, r, side)
        arr[:toolpath_xy] = _ac4ed97e
        nil
      end
      def stage_gouge(arr)
        return nil if arr[:dogbone] || arr[:preview]
        r, side, base_xy = arr.values_at(:radius, :side, :base_xy)
        arr2 = gouge_at(arr[:toolpath_xy], gouge_guide_for(arr))
        return nil unless arr2
        if !arr[:narrow] && side == "outside" && arr2[:segment_mm] <= r * 2.0
          arr4 = offset_by_elements(base_xy, r, false)
          if arr4
            path = arr4[:path]
            arr[:lock] = elem_lock_schema("xnc_elem_recover_v1", arr4[:elems], 0.03)
            arr[:rescued] = nil
          else
            arr3 = offset_fallback(base_xy, r, side, gouge: arr2)
            if arr3[:ok] && Array(arr3[:elems]).any?
              path = arr3[:path]
              arr.update(lock: elem_lock(arr3[:elems]), rescued: true)
            end
          end
          if path
            arr[:toolpath_xy] = ring(dedupe(path))
            arr2 = gouge_at(arr[:toolpath_xy], gouge_guide_for(arr))
          end
        end
        err_gouge(arr2, r) if arr2
      end
      def stage_lead(arr2)
        tool, side, base_xy = arr2.values_at(:tool, :side, :base_xy)
        lock, arr = arr2.values_at(:lock, :toolpath_xy)
        if lock.nil? && !arr2[:dogbone] && !arr2[:final_boundary] && !arr2[:preview]
          lock = elem_lock_from_vector(arr2[:vector], arr2[:origin], arr2[:radius], side, arr)
        end
        _65ffa089 = lock_enabled?(lock)
        return err_tool_too_big if _65ffa089 && lock_empty?(lock)
        arr2[:track] = ring(arr)
        arr = orient_path(arr, tool, base_xy)
        arr = close_path(arr) unless _65ffa089
        arr, lead_shift_mm = apply_lead(rotate_to_corner(arr, tool["entry_corner"], base_xy), tool)
        return err_bad_path if arr.length < 4
        if arr2[:preview]
          return { ok: true, path: arr, base: ring(base_xy), cut_side: side, lead_shift_mm: lead_shift_mm }
        end
        arr2.update(toolpath_xy: arr, lead_shift_mm: lead_shift_mm, lock: lock)
        nil
      end
      def offset_radius(base_r, r, cut_side)
        target = cut_side == "inside" ? base_r - r : base_r + r
        target if target > 0.001
      end
      def offset_circle(center, base_r, out, r, cut_side)
        target = offset_radius(base_r, r, cut_side)
        Calc.circle_polyline(center, target, out.first, Calc.signed_area(out).negative?) if target
      end
      def circle_path(bb, out, anchor, r, cut_side)
        center = to_mm(bb.center, anchor)
        start = to_mm(out.first, anchor)
        target = offset_radius(Math.sqrt((start[0] - center[0])**2 + (start[1] - center[1])**2), r, cut_side)
        Calc.circle_polyline(center, target, start, out.length > 1 && arc_is_cw?(out, bb.center)) if target
      end
      def circle_fit(out)
        rows = dedupe(out)
        return nil if rows.length < 8
        num = Calc.circumcircle(rows[0], rows[rows.length / 3], rows[(rows.length * 2) / 3])
        return nil unless num && num[:radius] > 0.001
        center, r = num.values_at(:center, :radius)
        return nil if rows.map { |pt| (Calc.distance(pt, center) - r).abs }.max > 0.01
        sweep = nil
        num2 = 0.0
        ring(rows).each_cons(2) do |row0, last_rect|
          _5d5d62fb = Calc.deg4(last_rect, center) - Calc.deg4(row0, center)
          delta = Math.atan2(Math.sin(_5d5d62fb), Math.cos(_5d5d62fb))
          return nil if delta.abs <= 1.0e-10
          flag = delta.negative? ? -1.0 : 1.0
          sweep ||= flag
          return nil if flag != sweep || delta.abs > 12.0 * Math::PI / 180.0 + 1.0e-10
          num2 += delta.abs
          chord = Calc.distance(last_rect, row0)
          return nil if chord > r * 2.0 + 1.0e-9
          _e8f9dc5f = chord * 0.5
          inside = r * r - _e8f9dc5f * _e8f9dc5f
          return nil if inside < -1.0e-9 || r - Math.sqrt([inside, 0.0].max) > 0.006 * r
        end
        return nil if num2 < 330.0 * Math::PI / 180.0 || num2 > 390.0 * Math::PI / 180.0
        num
      end
      def circle_fit_loose(out)
        rows = dedupe(out)
        return nil if rows.length < 8
        arr2 = Calc.fit_circle(rows)
        return nil unless arr2 && arr2[:radius] > 0.01
        center, r = arr2.values_at(:center, :radius)
        arr3 = rows.map { |pt| (Calc.distance(pt, center) - r).abs }.max
        return nil if arr3 > [0.08, r * 0.006].max
        arr = rows.map { |pt| Calc.deg4(pt, center) % (2.0 * Math::PI) }.sort
        arr4 = arr.each_cons(2).map { |a, b| b - a } << arr.first + 2.0 * Math::PI - arr.last
        return nil if arr4.max > (70.0 * Math::PI / 180.0)
        return nil unless (Calc.signed_area(rows).abs / (Math::PI * r * r)).between?(0.86, 1.04)
        { center: center, radius: r, radial_error: arr3 }
      end
      def offset_marching(boundary, r)
        lx, arr4 = boundary.map(&:first).minmax
        _2d7e228f, arr3 = boundary.map(&:last).minmax
        return err_bad_path if arr4 - lx <= 0.000001 || arr3 - _2d7e228f <= 0.000001
        cell = [[r / 32.0, 0.08].min, 0.035].max
        _95733ccb = (lx / cell).floor * cell - cell * 0.371
        _1c631d5d = (_2d7e228f / cell).floor * cell - cell * 0.619
        limit = [arr4 - _95733ccb, arr3 - _1c631d5d].max + cell
        depth = 0
        rsz = cell
        while rsz < limit
          rsz *= 2.0
          depth += 1
        end
        return err_bad_path if depth > 18
        segments = Native.marching(boundary, r, _95733ccb, _1c631d5d, rsz, depth, cell, [r, 1.0].max, r + [cell * 8.0, 1.0].max)
        return err_tool_too_big if segments.empty?
        loops = trace_loops(segments, [cell * 0.001, 0.00001].max).select do |arr|
          arr.length >= 3 && Calc.signed_area(arr).abs > 0.01 && !self_intersects?(arr)
        end
        return err_bad_path if loops.empty?
        arr2 = loops.select { |arr| Calc.signed_area(arr).abs > 0.05 }
        if arr2.length > 1
          return err_tool_too_big.merge(disconnected_loops: arr2.map { |arr| ring(dedupe(arr)) })
        end
        num = (arr2.empty? ? loops : arr2).max_by { |arr| Calc.signed_area(arr).abs }
        sel = smooth_loop(num, [cell * 0.16, 0.01].max)
        return err_bad_path if sel.length < 3 || self_intersects?(sel)
        sel.reverse! if Calc.signed_area(sel) * Calc.signed_area(boundary) < 0.0
        return err_tool_too_big unless loop_clear?(sel, boundary, r - [cell * 0.65, 0.04].max)
        { ok: true, path: ring(sel) }
      rescue SystemStackError
        err_bad_path
      end
      def loop_clear?(rows, boundary, per_row)
        free_at = Calc::NATIVE_EXT ? Native.clear_loop(rows, boundary, per_row) : nil
        return free_at unless free_at.nil?
        ring(rows).each_cons(2).all? do |row0, last_rect|
          [row0, *[0.25, 0.5, 0.75].map { |_5f343815| Calc.lerp(row0, last_rect, _5f343815) }].all? do |pt|
            Calc.in_polygon?(pt[0], pt[1], boundary) &&
              Calc.polygon_distance(pt, boundary) >= per_row
          end
        end
      end
      def trace_loops(segments, tol)
        arr = []
        keys = {}
        h = Hash.new { |arr3, key| arr3[key] = [] }
        segments.each do |row0, last_rect|
          a = node_index(row0, arr, keys, tol)
          b = node_index(last_rect, arr, keys, tol)
          next if a == b
          h[a] << b unless h[a].include?(b)
          h[b] << a unless h[b].include?(a)
        end
        taken = {}
        want = arr.length
        loops = []
        h.each_key do |start|
          h[start].each do |_f273cbbc|
            next if taken[start < _f273cbbc ? start * want + _f273cbbc : _f273cbbc * want + start]
            cycle = [start]
            _1b553836 = nil
            cur = start
            path = _f273cbbc
            (segments.length + 8).times do
              edge = cur < path ? cur * want + path : path * want + cur
              break if taken[edge]
              taken[edge] = true
              _1b553836, cur = cur, path
              cycle << cur
              break if cur == start
              opts2 = h[cur].reject { |node4| node4 == _1b553836 }
              break if opts2.empty?
              path = opts2.first
              next if opts2.length == 1
              arr2 = arr[cur]
              _67147d3b = Math.atan2(arr2[1] - arr[_1b553836][1], arr2[0] - arr[_1b553836][0])
              path = opts2.min_by do |node4|
                delta = (Math.atan2(arr[node4][1] - arr2[1], arr[node4][0] - arr2[0]) - _67147d3b).abs
                delta > Math::PI ? Math::PI * 2.0 - delta : delta
              end
            end
            next unless cur == start
            cycle.pop
            polygon = cycle.map { |node4| arr[node4] }
            loops << polygon if polygon.length >= 3
          end
        end
        loops
      end
      def node_index(pt, _18e680f5, keys, tol = NODE_TOLERANCE_MM)
        num = (keys[(pt[0] / tol).round] ||= {})
        num[(pt[1] / tol).round] ||= (_18e680f5 << [pt[0], pt[1]]).length - 1
      end
      def offset_graph(out, r)
        num = Calc.signed_area(out)
        return nil if num.abs < 0.000001
        area_sign = num.positive? ? 1.0 : -1.0
        want = out.length
        lines = out.zip(out.rotate).map do |row0, arr|
          dx = arr[0] - row0[0]
          dy = arr[1] - row0[1]
          length = Math.hypot(dx, dy)
          return nil if length < 0.000001
          nx = (-dy / length) * area_sign
          ny = (dx / length) * area_sign
          [[row0[0] + nx * r, row0[1] + ny * r], [arr[0] + nx * r, arr[1] + ny * r]]
        end
        ok = []
        out.each_with_index do |mid, idx|
          arr2 = lines[idx - 1]
          axis = lines[idx]
          arr3 = out[idx - 1]
          arr = out[(idx + 1) % want]
          cross = (mid[0] - arr3[0]) * (arr[1] - mid[1]) - (mid[1] - arr3[1]) * (arr[0] - mid[0])
          if cross.abs < 0.000000001
            ok << axis[0]
          elsif cross * area_sign > 0.0
            ok << (Calc.line_cross(arr2[0], arr2[1], axis[0], axis[1]) || axis[0])
          else
            arc = Calc.arc_polyline(mid, arr2[1], axis[0], r, -area_sign)
            arc.shift if !ok.empty? && !arc.empty? && same_xy?(ok.last, arc.first)
            ok.concat(arc)
          end
        end
        dedupe(ok)
      end
      def planar_graph(out)
        flag = Calc::NATIVE_EXT ? Native.planar_graph(out) : nil
        return flag || nil unless flag.nil?
        segments = out.zip(out.rotate)
        _8401179f = Array.new(segments.length) { [0.0, 1.0] }
        segments.each_with_index do |row0, i|
          ((i + 1)...segments.length).each do |ix|
            arr3 = segments[ix]
            Calc.segment_overlap(row0[0], row0[1], arr3[0], arr3[1]).each do |hit|
              _8401179f[i] << hit[:t]
              _8401179f[ix] << hit[:u]
            end
          end
        end
        arr = []
        keys = {}
        snap_edges = {}
        segments.each_with_index do |seg, idx|
          payload2 = _8401179f[idx].map { |val| [[val, 0.0].max, 1.0].min }.sort
          payload2 = payload2.each_with_object([]) do |val, entries|
            entries << val if entries.empty? || (val - entries.last).abs > 0.000000001
          end
          payload2.each_cons(2) do |_1c696a32, _10c5d6ce|
            next if _10c5d6ce - _1c696a32 <= 0.000000001
            arr2 = Calc.lerp(seg[0], seg[1], _1c696a32)
            b = Calc.lerp(seg[0], seg[1], _10c5d6ce)
            next if Math.hypot(b[0] - arr2[0], b[1] - arr2[1]) <= NODE_TOLERANCE_MM
            _802fd751 = node_index(arr2, arr, keys)
            _16ecc822 = node_index(b, arr, keys)
            snap_edges[[_802fd751, _16ecc822].minmax] = true unless _802fd751 == _16ecc822
          end
        end
        return nil if snap_edges.empty?
        snap_edges = snap_edges.keys
        h = Hash.new { |arr4, key| arr4[key] = [] }
        snap_edges.each do |arr2, b|
          h[arr2] << b
          h[b] << arr2
        end
        h.each do |node4, _3e337e34|
          anchor = arr[node4]
          _3e337e34.sort_by! { |neighbor| Math.atan2(arr[neighbor][1] - anchor[1], arr[neighbor][0] - anchor[0]) }
        end
        { nodes: arr, edges: snap_edges, adjacency: h }
      end
      def graph_faces(arr3)
        arr4, arr5 = arr3.values_at(:nodes, :adjacency)
        h = {}
        src = []
        arr2 = arr3[:edges].flat_map { |row0, last_rect| [[row0, last_rect], [last_rect, row0]] }
        arr2.each do |start|
          next if h[start]
          cur = start
          cycle = []
          (arr2.length + 4).times do
            break if h[cur] && cur != start
            h[cur] = true
            a, b = cur
            cycle << a
            arr = arr5[b]
            back = arr.index(a)
            break if back.nil?
            cur = [b, arr[(back - 1) % arr.length]]
            break if cur == start
          end
          next unless cur == start
          cycle = cycle.each_with_object([]) { |node4, entries| entries << node4 if entries.empty? || entries.last != node4 }
          next if cycle.length < 3
          polygon = cycle.map { |node4| arr4[node4] }
          num = Calc.signed_area(polygon)
          next if num.abs <= 0.0000001
          src << { cycle: cycle, polygon: polygon, area: num }
        end
        src
      end
      def face_loops(arr3, arr)
        h = {}
        arr3.each do |font|
          cycle = font[:cycle]
          cycle.zip(cycle.rotate).each do |edge|
            h[edge] = true unless h.delete(edge.reverse)
          end
        end
        return [] if h.empty?
        h2 = Hash.new { |arr4, key| arr4[key] = [] }
        h.each_key { |row0, last_rect| h2[row0] << last_rect }
        rest = h.dup
        loops = []
        until rest.empty?
          cur = rest.first[0]
          cycle = [cur[0]]
          (h.length + 4).times do
            break unless rest.delete(cur)
            a, b = cur
            cycle << b
            break if b == cycle.first
            arr2 = h2[b].select { |path| rest[[b, path]] }
            break if arr2.empty?
            anchor = arr[b]
            back = Math.atan2(arr[a][1] - anchor[1], arr[a][0] - anchor[0])
            _f273cbbc = arr2.min_by do |path|
              _5d5d62fb = back - Math.atan2(arr[path][1] - anchor[1], arr[path][0] - anchor[0])
              _5d5d62fb += Math::PI * 2.0 while _5d5d62fb < 0.0
              _5d5d62fb
            end
            cur = [b, _f273cbbc]
          end
          next unless cycle.last == cycle.first
          cycle.pop
          polygon = cycle.map { |node4| arr[node4] }
          loops << polygon if polygon.length >= 3
        end
        loops
      end
      def smooth_loop(out, tol)
        rows = dedupe(out)
        return rows if rows.length < 5
        _3936af4d = rows.each_index.min_by { |idx| rows[idx] }
        row0 = rows[_3936af4d]
        _20eab7f5 = rows.each_index.max_by do |idx|
          (rows[idx][0] - row0[0])**2 + (rows[idx][1] - row0[1])**2
        end
        want = rows.length
        head_off = rdp_keep(rows.rotate(_3936af4d)[0..((_20eab7f5 - _3936af4d) % want)], tol)
        tail_pt = rdp_keep(rows.rotate(_20eab7f5)[0..((_3936af4d - _20eab7f5) % want)], tol)
        arr = dedupe(head_off + tail_pt[1...-1])
        arr.length < 3 || self_intersects?(arr) ? rows : arr
      end
      def rdp_keep(rows, tol)
        flag = Calc::NATIVE ? Native.rdp_keep(rows, tol) : nil
        flag ? flag.map { |idx| rows[idx].dup } : rdp_keep_ruby(rows, tol)
      end
      def rdp_keep_ruby(rows, tol)
        return rows.map(&:dup) if rows.length <= 2
        row0 = rows.first
        last_rect = rows.last
        arr = (1...(rows.length - 1)).map { |idx| Calc.segment_distance(rows[idx], row0, last_rect) }
        hi = arr.max
        return [row0.dup, last_rect.dup] if hi <= tol
        _c9cee24f = arr.index(hi) + 1
        rdp_keep_ruby(rows[0.._c9cee24f], tol)[0...-1] + rdp_keep_ruby(rows[_c9cee24f..-1], tol)
      end
      def offset_side_ok?(path_xy, base_xy, r, cut_side)
        rows = dedupe(path_xy)
        boundary = dedupe(base_xy)
        return false if rows.length < 3 || boundary.length < 3
        row0 = rows.first
        last_rect = rows.last
        want = [[(Calc.distance(last_rect, row0) / 2.0).ceil, 12].max, 180].min
        half = r.abs
        tol = [[half * 0.12, 0.30].max, 0.80].min
        _5567b9be = ring(boundary)
        (1...want).all? do |idx|
          pt = Calc.lerp(last_rect, row0, idx / want.to_f)
          distance = Calc.contour_distance(pt, _5567b9be)
          next false if (distance - half).abs > tol
          inside = Calc.in_polygon?(pt[0], pt[1], boundary)
          cut_side == "inside" ? inside : !(cut_side == "outside" && inside && distance > tol)
        end
      end
      def fits_inside?(offset_xy, base_xy, r)
        return false if offset_xy.length < 3 || base_xy.length < 3
        tol = [[r.abs * 0.01, 0.03].max, 0.20].min
        _5567b9be = ring(base_xy)
        (0...offset_xy.length).step([1, (offset_xy.length / 240.0).ceil].max).all? do |idx|
          pt = offset_xy[idx]
          _f273cbbc = offset_xy[(idx + 1) % offset_xy.length]
          [pt, [(pt[0] + _f273cbbc[0]) * 0.5, (pt[1] + _f273cbbc[1]) * 0.5]].all? do |sample_tol_mm|
            Calc.contour_distance(sample_tol_mm, _5567b9be) <= tol || Calc.in_polygon?(sample_tol_mm[0], sample_tol_mm[1], base_xy)
          end
        end
      end
      def inverted?(offset_xy, base_xy, inside)
        return false if !inside || offset_xy.length < 3 || base_xy.length < 3
        eps = 0.001
        _41548c7b, arr = base_xy.map(&:first).minmax
        _d816ba86, y1 = base_xy.map(&:last).minmax
        offset_xy.any? { |x, y| x < _41548c7b - eps || x > arr + eps || y < _d816ba86 - eps || y > y1 + eps }
      end
      def gouge_guide(base_xy, r)
        boundary = ring(dedupe(base_xy))
        return nil if boundary.length < 3
        half = r.abs
        arr = boundary.each_cons(3).map { |a, b, c| Calc.point_segment_distance(b, a, c) }.max
        gap_for = [[[half * 0.05, 0.05].max, 0.30].min, [arr * 0.5, half * 0.25].min].max
        per_row = half - gap_for
        [boundary, half, gap_for, per_row] if per_row.positive?
      end
      def gouge_guide_for(h)
        h.fetch(:gouge_guide) { h[:gouge_guide] = gouge_guide(h[:base_xy], h[:radius]) }
      end
      def gouge_at(path_xy, guide)
        rows = dedupe(path_xy)
        return nil if rows.length < 2 || guide.nil?
        boundary, half, gap_for, per_row = guide
        hit = Calc::NATIVE ? Native.gouge_scan(rows, boundary, per_row) : false
        hit = gouge_scan(rows, boundary, per_row) if hit == false
        return nil unless hit
        x, y, distance, length = hit
        { xy: [x, y], clear_depth_mm: [half - distance - gap_for, 0.0].max, segment_mm: length }
      end
      def gouge_scan(rows, boundary, per_row)
        grid = segment_grid(boundary[0...-1], per_row)
        rows.each_cons(2) do |a, b|
          length = Calc.distance(a, b)
          next unless length > 1.0
          steps = [[length.ceil, 2].max, 240].min
          (1...steps).each do |_5d951b22|
            pt = Calc.lerp(a, b, _5d951b22 / steps.to_f)
            px = (pt[0] / per_row).floor
            py = (pt[1] / per_row).floor
            arr = NEIGHBORS.flat_map { |dx, dy| grid.dig(px + dx, py + dy) || [] }.uniq
            distance = arr.map { |idx| Calc.point_segment_distance(pt, boundary[idx], boundary[idx + 1]) }.min
            next unless distance && distance < per_row
            return [pt[0], pt[1], distance, length]
          end
        end
        nil
      end
      def err_gouge(arr, r)
        key = arr[:segment_mm] > r.abs * 2.0 ? :an_lem_ban_ve : :an_lem_dao
        { ok: false, error: Text.t(:duong, key), xy: arr[:xy] }
      end
      def segment_grid(polygon, cell)
        grid = {}
        polygon.zip(polygon.rotate).each_with_index do |(row0, last_rect), idx|
          lx, _b0566a11 = [row0[0], last_rect[0]].minmax
          _2d7e228f, _897789b7 = [row0[1], last_rect[1]].minmax
          arr = (lx / cell).floor..(_b0566a11 / cell).floor
          arr2 = (_2d7e228f / cell).floor..(_897789b7 / cell).floor
          arr.each { |_bade6541| arr2.each { |gap_y| ((grid[_bade6541] ||= {})[gap_y] ||= []) << idx } }
        end
        grid
      end
      def clearance_check(path_xy, source_elems, r)
        rows = ring(dedupe(path_xy))
        return { ok: false } if rows.length < 2 || source_elems.empty?
        arr = source_elems.map { |_0d6b8add| Calc.pack_element(_0d6b8add) }
        _48a302ae = clearance_grid(arr, rows, r)
        rows.each_cons(2) do |a, b|
          [0.0, 0.25, 0.5, 0.75].each do |_5f343815|
            distance = nearest_distance(Calc.lerp(a, b, _5f343815), _48a302ae, arr)
            return { ok: false } unless distance.finite?
            delta = distance - r
            return { ok: false } if delta < -0.01 || delta > 0.01
          end
        end
        { ok: true }
      end
      def clearance_grid(arr4, rows, r)
        num = ->(arr3) { arr3[0].abs <= 1.0e6 && arr3[1].abs <= 1.0e6 }
        return nil unless r.abs <= 1.0e6 && rows.all?(&num)
        _68b53d20 = r + 1.0
        arr4.map do |packed|
          arc, s, e, arr2, half = packed
          arr = [s, e]
          arr.push([arr2[0] - half, arr2[1] - half], [arr2[0] + half, arr2[1] + half]) if arc
          return nil unless arr.all?(&num)
          text, x1 = arr.map(&:first).minmax
          y0, y1 = arr.map(&:last).minmax
          [text - _68b53d20, x1 + _68b53d20, y0 - _68b53d20, y1 + _68b53d20, packed]
        end
      end
      def nearest_distance(pt, arr, arr2)
        return arr2.map { |packed| Calc.element_distance(pt, packed) }.min unless arr
        trai, duoi = pt
        best = Float::INFINITY
        arr.each do |text, x1, y0, y1, packed|
          next if trai < text || trai > x1 || duoi < y0 || duoi > y1
          val = Calc.element_distance(pt, packed)
          best = val if val < best
        end
        best
      end
      def pack_outline(_105d9ed2)
        rows = ring(dedupe(_105d9ed2))
        return nil if rows.length < 2
        cell = 16.0
        grid = {}
        arr = []
        rows.each_cons(2) do |row0, last_rect|
          next if same_xy?(row0, last_rect)
          pts = Calc.pack_segment(row0, last_rect)
          _c62e3767, _c9060cb1 = [(row0[0] / cell).floor, (last_rect[0] / cell).floor].minmax
          _79d02a93, _eda2d8bc = [(row0[1] / cell).floor, (last_rect[1] / cell).floor].minmax
          next arr << pts if (_c9060cb1 - _c62e3767 + 1) * (_eda2d8bc - _79d02a93 + 1) > 512
          (_c62e3767.._c9060cb1).each { |px| (_79d02a93.._eda2d8bc).each { |py| ((grid[px] ||= {})[py] ||= []) << pts } }
        end
        _916bf73f, arr3 = grid.keys.minmax
        _99b2664c, arr2 = grid.each_value.flat_map(&:keys).minmax
        [rows, cell, grid, arr, _916bf73f, arr3, _99b2664c, arr2]
      end
      def packed_distance_at(pt, packed_outline)
        rows, cell, grid, arr2, _916bf73f, _6a5c2b81, _99b2664c, _a1c5301a = packed_outline
        trai, duoi = pt
        px = (trai / cell).floor
        py = (duoi / cell).floor
        best = Float::INFINITY
        arr2.each do |pts|
          val = Calc.packed_distance(trai, duoi, pts)
          best = val if val < best
        end
        unless grid.empty?
          _e7c3b158 = [_916bf73f - px, px - _6a5c2b81, _99b2664c - py, py - _a1c5301a, 0].max
          num = [(px - _916bf73f).abs, (px - _6a5c2b81).abs, (py - _99b2664c).abs, (py - _a1c5301a).abs].max
          while _e7c3b158 <= num
            left = px - _e7c3b158
            b2 = px + _e7c3b158
            bot = py - _e7c3b158
            _e4f12bf3 = py + _e7c3b158
            x = left
            while x <= b2
              arr = grid[x]
              flag = x == left || x == b2 ? 1 : _e4f12bf3 - bot
              y = bot
              while arr && y <= _e4f12bf3
                arr[y]&.each do |pts|
                  val = Calc.packed_distance(trai, duoi, pts)
                  best = val if val < best
                end
                y += flag
              end
              x += 1
            end
            gap_for = [trai - left * cell, (b2 + 1) * cell - trai, duoi - bot * cell, (_e4f12bf3 + 1) * cell - duoi].min
            return best if best.finite? && best <= gap_for + 1.0e-12
            _e7c3b158 += 1
          end
        end
        best.finite? ? best : Calc.contour_distance(pt, rows)
      end
      def polygon_contains?(outer, inner)
        inside = Calc::NATIVE_EXT ? Native.polygon_contains(outer, inner) : nil
        return inside unless inside.nil?
        arr2 = dedupe(outer)
        b = dedupe(inner)
        return false if arr2.length < 3 || b.length < 3
        flag = arr2.zip(arr2.rotate).any? do |arr, arr3|
          _ee4f533e = arr3[0] - arr[0]
          _4c8d9d44 = arr3[1] - arr[1]
          side = b.map { |arr4| (_ee4f533e * (arr4[1] - arr[1])) - (_4c8d9d44 * (arr4[0] - arr[0])) > 0 }
          b.each_index.any? do |ix|
            num = (ix + 1) % b.length
            side[ix] != side[num] &&
              (Calc.cross(b[ix], b[num], arr) > 0) != (Calc.cross(b[ix], b[num], arr3) > 0)
          end
        end
        !flag && b.all? { |pt| Calc.in_polygon?(pt[0], pt[1], arr2) }
      end
      def to_pairs(out)
        Array(out).each_with_object([]) do |pt, ok|
          path = [pt[0].to_f, pt[1].to_f]
          ok << path if ok.empty? || !same_xy?(ok.last, path)
        end
      end
      def dedupe(out)
        Calc.dedupe_loop(out, ZERO_LEN_MM)
      end
      def same_xy?(arr, b)
        Math.hypot(arr[0] - b[0], arr[1] - b[1]) <= ZERO_LEN_MM
      end
      def ring(out)
        ok = Array(out).dup
        ok << ok.first unless ok.empty? || same_xy?(ok.first, ok.last)
        ok
      end
      def self_intersects?(out)
        flag = Calc::NATIVE ? Native.self_intersects(out) : nil
        return flag unless flag.nil?
        entries = Array(out)
        entries = entries[0...-1] if entries.length > 2 && Calc.distance(entries.first, entries.last) < 1.0e-9
        want = entries.length
        return false if want < 4
        arr6 = entries.map { |arr2| arr2[0].to_f }
        arr3 = entries.map { |arr2| arr2[1].to_f }
        cell = [[arr6.max - arr6.min, arr3.max - arr3.min].max / Math.sqrt(want).clamp(8.0, 128.0), 0.001].max
        grid = {}
        entries.each_with_index do |arr, i|
          b = entries[(i + 1) % want]
          lx, _b0566a11 = [arr[0], b[0]].minmax
          _2d7e228f, _897789b7 = [arr[1], b[1]].minmax
          arr4 = (lx / cell).floor..(_b0566a11 / cell).floor
          arr5 = (_2d7e228f / cell).floor..(_897789b7 / cell).floor
          h = {}
          arr4.each { |_bade6541| arr5.each { |gap_y| grid.dig(_bade6541, gap_y)&.each { |num| h[num] = true } } }
          h.each_key do |num|
            next if num == i - 1 || (num.zero? && i == want - 1)
            return true if Calc.segments_cross?(arr, b, entries[num], entries[(num + 1) % want])
          end
          arr4.each { |_bade6541| arr5.each { |gap_y| ((grid[_bade6541] ||= {})[gap_y] ||= []) << i } }
        end
        false
      end
      def keep_indices(rows, _4d3367e1)
        keep_existing = [0]
        num2 = 0
        num = 2
        while num <= _4d3367e1
          _5f301685 = num - num2 <= 256 &&
                     ((num2 + 1)...num).all? { |k| Calc.collinear_within?(rows[num2], rows[k], rows[num]) }
          if _5f301685
            num += 1
          else
            num2 = num - 1
            keep_existing << num2
            num = num2 + 2
          end
        end
        keep_existing << _4d3367e1 unless keep_existing.last == _4d3367e1
        keep_existing
      end
      def close_path(out)
        arr = out.map { |arr3| [arr3[0].to_f, arr3[1].to_f] }
        closed = arr.length > 2 && same_xy?(arr.first, arr.last)
        arr.pop while arr.length > 1 && same_xy?(arr.first, arr.last)
        return out unless closed && arr.length >= 3
        arr2 = arr + [arr.first]
        keep_existing = keep_indices(arr2, arr.length)[0...-1].map { |idx| arr2[idx] }
        keep_existing.shift if keep_existing.length >= 4 && Calc.collinear_within?(keep_existing.last, keep_existing.first, keep_existing[1])
        keep_existing.length < 3 ? out : ring(keep_existing)
      end
      def simplify_open(out)
        return out if out.length < 3
        keep_indices(out, out.length - 1).map { |idx| out[idx] }
      end
    end
  end
end
