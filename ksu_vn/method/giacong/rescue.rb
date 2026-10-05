module KSU
  module Cnc
    module Export
      module_function
      def stage_passes(arr)
        lock = arr[:lock]
        return nil unless lock && lock[:schema] == NARROW_SCHEMA
        tool, base_xy = arr.values_at(:tool, :base_xy)
        done = lock_check(lock, rotate_entry(arr[:toolpath_xy], tool))
        if done
          arr.update(lock: done, writer_done: true)
          return nil
        end
        outline = narrow_rescue(arr[:vector], base_xy, arr[:origin], arr[:radius], arr[:side], true)
        return err_tool_too_big unless outline && outline[:ok]
        elems = outline[:elems]
        flag = outline[:exact_touch] && elems.any? { |arr3| arr3[:type] == :arc }
        _9f9275a3 = ring(dedupe(outline[:path]))
        path = orient_path(_9f9275a3, tool, base_xy)
        path = rotate_to_corner(close_path(path), tool["entry_corner"], base_xy) unless flag
        arr2, lead_shift_mm = apply_lead(path, tool)
        return err_bad_path if arr2.length < 4
        lock = flag ? lock_with_schema(REGION_SCHEMA, elems, sample_tol_mm: NARROW_SAMPLE_MM) : nil
        arr.update(lock: lock, writer_done: flag, track: _9f9275a3, toolpath_xy: arr2,
                        lead_shift_mm: lead_shift_mm, rescued: true)
        nil
      end
      def stage_check(arr)
        lock = arr[:lock]
        flag = lock_empty?(lock).nil? && lock[:region_boundary] == true && region_locked?(lock)
        arr[:rescued] = true if flag
        return nil if arr[:circular] || arr[:writer_done] || flag
        r = arr[:radius]
        elem_state = lock_from_path(arr[:toolpath_xy], r)
        return nil unless elem_state[:risk]
        arr2 = offset_fallback(arr[:base_xy], r, arr[:side], rail_repair: elem_state)
        return err_tool_too_big unless arr2[:ok] && Array(arr2[:elems]).any?
        path = ring(dedupe(arr2[:path]))
        lock = elem_lock(arr2[:elems], local_rail: true, rail_check: arr2[:guard])
        arr.update(toolpath_xy: path, lock: lock, track: ring(path), rescued: true)
        nil
      end
      def stage_done(arr)
        r, base_xy, _ac4ed97e, lock = arr.values_at(:radius, :base_xy, :toolpath_xy, :lock)
        if lock_enabled?(lock)
          _ac4ed97e, lock = realign_lock(lock, _ac4ed97e, base_xy, r)
          return err_tool_too_big unless lock
        end
        return err_bad_path unless path_matches?(_ac4ed97e, arr[:track])
        unless arr[:dogbone]
          _1ad0cbfc = lock && lock[:final_aligned] == true && lock[:final_check][:ok] == true &&
                   (lock[:local_rail] == true || lock[:region_boundary] == true)
          _8e82fbd0 = _1ad0cbfc || !arr[:rescued] || drift_check(_ac4ed97e, base_xy, r)[:ok]
          return err_bad_path unless _8e82fbd0
          _d7127ff1 = gouge_at(_ac4ed97e, gouge_guide_for(arr))
          return err_gouge(_d7127ff1, r) if _d7127ff1
        end
        { ok: true, path: _ac4ed97e, base: ring(base_xy), cut_side: arr[:side], lead_shift_mm: arr[:lead_shift_mm],
          elem_lock: lock }
      end
      def narrow_rescue(vec, base_xy, anchor, r, side, flag3 = false)
        return nil unless side == "outside" && !dogbone_layer?(vec) && vec.closed
        arr5 = Array(vec.instance_variable_get(:@elements_of))
        flag = Rail.narrow_scan(base_xy, tool_r_mm: r) if arr5.empty?
        return nil if flag && !flag.ok
        boundary = flag ? flag.elems : elements_to_mm(arr5, anchor)
        return nil unless boundary.any? { |arr2| arr2[:type] == :arc && Calc.distance(arr2[:s], arr2[:c]) <= r + Gate::RADIUS_EPS_MM }
        _0b3bdf66 = Canonicalizer.canonicalize(boundary)
        return nil unless _0b3bdf66.ok
        rows = _0b3bdf66.elems
        return nil unless Calc.distance(rows.last[:e], rows.first[:s]) <= 0.001
        _fcb98096 = Gate.gate_check(rows, tool_r_mm: r)
        return nil unless _fcb98096.eligible
        fail = { ok: false }
        normal = dedupe(base_xy)
        arr3 = rows.map { |arr2| Calc.pack_element(arr2) }
        flag2 = clearance_grid(arr3, normal, 0.0) unless normal.empty?
        _1645a636 = if flag2
                     normal.all? { |pt| nearest_distance(pt, flag2, arr3) <= 0.01 }
                   else
                     normal.map { |pt| arr3.map { |packed| Calc.element_distance(pt, packed) }.min }.max <= 0.01
                   end
        return fail unless _1645a636
        _fe1bd296 = flag3
        unless flag3
          offset_path = Arc.offset_path(rows, tool_r_mm: r, cut_side: side, collapse: true)
          _fe1bd296 = offset_path.metadata[:reconcile_failed] == true
          return fail unless offset_path.ok || _fe1bd296
        end
        if _fe1bd296
          arr = Clip.offset_shape(rows, radius_mm: r, cut_side: side)
          return fail unless arr[:ok] == true && arr[:elems].any?
          elems = arr[:elems]
        else
          return fail unless offset_path.metadata[:fold_count] == _fcb98096.metadata[:folded_arcs]
          elems = offset_path.elems
        end
        vec7 = Validator.validate(elems, expect_ccw: _fcb98096.metadata[:source_ccw] == true,
                                                    source_segments: rows, expected_side: :outside)
        unless vec7.valid?
          flag5 = vec7.hard_issues.all? { |_f68f66d8| %i[self_intersection collinear_overlap].include?(_f68f66d8.code) }
          return fail if _fe1bd296 || !flag5
          return narrow_rescue(vec, base_xy, anchor, r, side, true)
        end
        path = dedupe(Calc.flatten_path(elems, chord_tol_mm: NARROW_SAMPLE_MM))
        return fail if path.length < 3 || self_intersects?(path) ||
                         !offset_side_ok?(path, base_xy, r, side)
        unless sim_view?
          unless clearance_check(path, rows, r)[:ok]
            return _fe1bd296 ? fail : narrow_rescue(vec, base_xy, anchor, r, side, true)
          end
          return fail if gouge_at(ring(path), gouge_guide(base_xy, r))
        end
        if _fe1bd296
          arr4 = arr[:arc_rebuilt] || {}
          refit_check = arr4[:refit_check] || {}
          polygon = arr4[:promoted] != true
          flag4 = polygon ? arr[:distance_check] : (refit_check[:source_check] if refit_check[:ok] == true)
          lock = elem_lock(elems, region_boundary: true, region_polygon: polygon, region_watch: flag4,
                                          region_check: refit_check, region_tolerance_mm: Clip::BOUNDARY_DISTANCE_MM)
        else
          lock = lock_with_schema(NARROW_SCHEMA, elems, sample_tol_mm: NARROW_SAMPLE_MM)
        end
        { ok: true, path: path, elems: elems, elem_lock: lock, final_boundary: _fe1bd296,
          exact_touch: _fe1bd296 && arr4[:tangency_promoted] == true }
      end
      def elem_lock_from_vector(vec, anchor, r, side, path_xy_in)
        id_str = elements_of(vec)
        return nil unless id_str.any? { |arr| arr[:type] == :arc } && elements_joined?(id_str)
        _0b3bdf66 = Canonicalizer.canonicalize(elements_to_mm(id_str, anchor))
        return nil unless _0b3bdf66.ok && _0b3bdf66.elems.any? { |arr| arr[:type] == :arc }
        rows = _0b3bdf66.elems
        row0 = rows.first
        if rows.length == 1 && row0[:type] == :arc && row0[:full_circle] == true
          center = row0[:c]
          start = row0[:s]
          base_r = Calc.distance(start, center)
          radius_mm = base_r + (side == "outside" ? r : -r)
          return nil unless radius_mm > 0.001
          upm = radius_mm / base_r
          pt = [center[0] + (start[0] - center[0]) * upm, center[1] + (start[1] - center[1]) * upm]
          elems = [{ type: :arc, s: pt, e: pt.dup, c: center.dup, ccw: row0[:ccw] == true, full_circle: true, radius_mm: radius_mm }]
        else
          offset_path = Arc.offset_path(rows, tool_r_mm: r, cut_side: side)
          return nil unless offset_path.ok && offset_path.elems.any? { |arr| arr[:type] == :arc }
          elems = offset_path.elems
        end
        ccw = Calc.signed_area(dedupe(Calc.flatten_path(rows, chord_tol_mm: ARC_SAMPLE_MM))).positive?
        vec8 = Validator.validate(elems, expect_ccw: ccw, source_segments: rows, expected_side: side.to_sym)
        return nil unless vec8.valid?
        path = ring(dedupe(Calc.flatten_path(elems, chord_tol_mm: ARC_SAMPLE_MM)))
        arr2 = ring(dedupe(path_xy_in))
        return nil if path.length < 4 || arr2.length < 4 || self_intersects?(path)
        err = Locked.within?(path, arr2, max_allowed: NATIVE_MATCH_MM)
        lock_with_schema("xnc_c_src_lock_v1", elems) if err <= NATIVE_MATCH_MM
      end
      def elements_to_mm(elems, anchor)
        num = ->(arr) { [arr[0] * MM_PER_INCH - anchor[0].to_f, arr[1] * MM_PER_INCH - anchor[1].to_f] }
        elems.map do |arr2|
          arr = { type: arr2[:type], s: num.call(arr2[:s]), e: num.call(arr2[:e]) }
          next arr unless arr[:type] == :arc
          arr.update(c: num.call(arr2[:c]), ccw: arr2[:ccw] == true, full_circle: arr2[:full_circle] == true)
        end
      end
      def lock_check(lock, arr)
        return nil unless lock
        unless lock_empty?(lock)
          path = ring(arr)
          _8d02513d = { shape_tol_mm: 0.01, sample_tol_mm: RESCUE_SAMPLE_MM }
          _b7d2a364 = Locked.align(lock[:elems], path, align_tol_mm: 0.0025, **_8d02513d)
          return nil unless _b7d2a364.ok
          _c3a7bc03 = pin_ends_to(path, _b7d2a364.start_point)
          return nil unless same_shape?(_c3a7bc03, path) && !self_intersects?(_c3a7bc03)
          _15768a95 = Locked.align(_b7d2a364.elems, _c3a7bc03, align_tol_mm: 1.0e-6, **_8d02513d)
          return nil unless _15768a95.ok
          arr.replace(_c3a7bc03)
          return lock.merge(elems: _15768a95.elems)
        end
        shape_tol_mm, _540fe238 = schema_tolerance(lock[:schema])
        return lock if !_540fe238 || (lock[:start_checked] && lock[:cache_schema] == _540fe238 &&
                                               same_points?(lock[:plan_points], arr))
        outline = lock[:schema] == REGION_SCHEMA
        elems = lock[:elems]
        sample_tol_mm = lock[:sample_tol_mm] || ARC_SAMPLE_MM
        if outline
          per_row = 0.0025
          point = Locked.align(elems, arr, align_tol_mm: per_row, shape_tol_mm: shape_tol_mm,
                                                             sample_tol_mm: sample_tol_mm)
          return nil unless point.ok && point.align_error_mm <= per_row
          if point.align_error_mm <= EXACT_START_MM
            _b7d2a364 = point
          else
            closed = arr.length > 1 && Calc.distance(arr.first, arr.last) <= per_row + 1.0e-9
            arr[0] = point.start_point.dup
            arr[-1] = point.start_point.dup if closed
          end
        end
        _b7d2a364 ||= Locked.align(elems, arr,
                                 align_tol_mm: outline ? EXACT_START_MM : shape_tol_mm,
                                 shape_tol_mm: shape_tol_mm, sample_tol_mm: sample_tol_mm)
        return nil unless _b7d2a364.ok && _b7d2a364.align_error_mm <= EXACT_START_MM
        plan = arr.map { |pt| [pt[0].to_f, pt[1].to_f].freeze }.freeze
        lock.merge(elems: _b7d2a364.elems, start_checked: true, start_err_mm: _b7d2a364.align_error_mm,
                      cache_schema: _540fe238, plan_points: plan)
      end
      def schema_tolerance(schema)
        case schema
        when REGION_SCHEMA then [0.003, "xnc_region_plan_fit_v1"]
        when NARROW_SCHEMA then [0.01, "xnc_narrow_plan_fit_v1"]
        when "xnc_c_src_lock_v1" then [NATIVE_MATCH_MM, "xnc_native_plan_fit_v1"]
        end
      end
      def same_points?(arr, arr2)
        arr.length == arr2.length &&
          arr.each_index.all? { |i| arr[i][0] == arr2[i][0] && arr[i][1] == arr2[i][1] }
      end
      def lock_with_schema(schema, elems, addon_data = {})
        { schema: schema, enabled: true, keep_elems: true, elems: elems }.merge(addon_data)
      end
      def elem_lock_schema(schema, elems, tol)
        lock_with_schema(schema, elems, sample_tol_mm: ARC_SAMPLE_MM, align_tol_mm: tol)
      end
      def lock_enabled?(lock)
        lock && lock[:schema] == "xnc_round_join_v3"
      end
      def lock_empty?(lock)
        return "no_clipper_lock" unless lock_enabled?(lock)
        elems = lock[:elems]
        return "no_elems" if elems.empty?
        number = ->(num2) { num2.is_a?(Numeric) && num2.to_f.finite? }
        num = ->(pt) { pt.is_a?(Array) && pt.length >= 2 && pt.first(2).all?(&number) }
        _90cb2398 = elems.index do |arr|
          sheet_type = arr[:type].to_s
          next true unless sheet_type == "line" || sheet_type == "arc"
          !num.call(arr[:s]) || !num.call(arr[:e]) || (sheet_type == "arc" && !num.call(arr[:c]))
        end
        "elem_#{_90cb2398 + 1}_missing_xy" if _90cb2398
      end
      def region_locked?(lock)
        arr = lock[:region_watch]
        arr && arr[:ok] == true && (lock[:region_polygon] == true || lock[:region_check][:ok] == true)
      end
      def offset_by_elements(base_xy, r, collapse)
        boundary = dedupe(base_xy)
        return nil if boundary.length < 3
        arr = Refit.refit(boundary)
        return nil unless arr[:status] == "rebuilt_ok"
        metrics = arr[:metrics]
        return nil unless collapse ? metrics[:sample_error_mm] <= 0.01 : metrics[:roundtrip_error_mm] <= 0.03
        _0b3bdf66 = Canonicalizer.canonicalize(arr[:elems])
        return nil unless _0b3bdf66.ok
        rows = _0b3bdf66.elems
        return nil unless rows.any? { |arr2| arr2[:type] == :line } && rows.any? { |arr2| arr2[:type] == :arc }
        offset_path = Arc.offset_path(rows, tool_r_mm: r, cut_side: "outside", collapse: collapse)
        return nil unless offset_path.ok
        return nil if collapse && !offset_path.metadata[:fold_count].positive?
        return nil unless Validator.validate(offset_path.elems, expect_ccw: Calc.signed_area(boundary).positive?,
                                                source_segments: rows, expected_side: :outside).valid?
        path = dedupe(Calc.flatten_path(offset_path.elems, chord_tol_mm: ARC_SAMPLE_MM))
        return nil if path.length < 3 || self_intersects?(path)
        return nil unless clearance_check(path, rows, r)[:ok]
        return nil unless offset_side_ok?(path, boundary, r, "outside")
        return nil if gouge_at(ring(path), gouge_guide(boundary, r))
        { path: path, elems: offset_path.elems }
      end
      def relock_dogbone(_ac4ed97e, base_xy, r)
        return unless needs_relock?(_ac4ed97e, base_xy, r)
        fail = { ok: false }
        packed = Clip.offset_polygon(dedupe(base_xy), radius_mm: r)
        _28d5c275 = Clip.mend_polygon(_ac4ed97e, base_xy, radius_mm: r, mend: true)
        return fail unless packed.ok && _28d5c275.ok && _28d5c275.metadata[:bridge_mend_count].positive?
        path = ring(dedupe(Calc.flatten_path(_28d5c275.candidates, chord_tol_mm: 0.005)))
        return fail if path.length < 4 || needs_relock?(path, base_xy, r)
        return fail unless drift_check(path, base_xy, r, tolerance_mm: RESCUE_SOURCE_MM)[:ok]
        { ok: true, path: path, elem_lock: elem_lock_schema("xnc_path_check_v3", _28d5c275.candidates, 0.006) }
      end
      def needs_relock?(path_xy, base_xy, r)
        path = ring(dedupe(path_xy))
        boundary = dedupe(base_xy)
        return false if path.length < 4 || boundary.length < 3
        arr = Compressor.compress(path, tolerance_mm: 0.025)
        arr.each_with_index.any? do |arr2, idx|
          next false unless arr2[:type] == :arc && (arr2[:radius] - r).abs <= 0.06
          next false unless boundary.map { |pt| Calc.distance(arr2[:center], pt) }.min <= 0.08
          arr3 = []
          arr3 << [arr[idx - 1], arr[idx - 1][:finish], arr2[:start]] if idx.positive?
          arr3 << [arr[idx + 1], arr2[:finish], arr[idx + 1][:start]] if idx + 1 < arr.length
          arr3.any? do |axis, a, b|
            axis[:type] == :line && axis[:length] > 1.0e-7 && axis[:length] <= 0.60 &&
              Calc.distance(a, b) <= 0.003
          end
        end
      end
      def lock_from_path(path_xy, r, tolerance_mm: 0.025)
        path = ring(dedupe(path_xy))
        elems = Compressor.compress(path, tolerance_mm: tolerance_mm).map do |arr|
          next { type: :line, s: arr[:start], e: arr[:finish] } unless arr[:type] == :arc
          { type: :arc, s: arr[:start], e: arr[:finish], c: arr[:center], ccw: !arr[:clockwise], full_circle: false }
        end
        _5f936613 = Clip.offset_elements(elems, radius_mm: r)
        return { risk: false } unless _5f936613.ok
        { risk: true, elems: _5f936613.candidates, original_path: path, rail_path: elements_to_path(elems),
          change_mm: Locked.within?(elements_to_path(_5f936613.candidates), path, max_allowed: RESCUE_CHANGE_MM),
          bridge_mends: _5f936613.metadata[:bridge_mends], tangent_mends: _5f936613.metadata[:tangent_mends] }
      end
      def offset_fallback(base_xy, r, cut_side, rail_repair: nil, gouge: nil)
        fail = { ok: false, error: "no_rescue_path" }
        saved = !gouge.nil?
        return fail if saved && !gouge[:clear_depth_mm].positive?
        boundary = dedupe(base_xy)
        return fail if boundary.length < 3 || self_intersects?(boundary)
        base_area = Calc.signed_area(boundary)
        return fail unless base_area.finite? && base_area.abs > 0.01
        _553133a8 = Clip.offset_polygon(boundary, radius_mm: r)
        return fail unless _553133a8.ok
        paths = _553133a8.candidates.filter_map { |_a2d0b3e2| single_polygon_path(_a2d0b3e2, boundary, base_area, r, cut_side) }
        return fail unless paths.length == 1
        _744d6cbf = { ok: false, error: "round_join_rebuild_failed" }
        return bridge_path(rail_repair, boundary, base_area, r, cut_side, true) || _744d6cbf if rail_repair
        elems, path = mend_path(paths.first, boundary, r, saved)
        return _744d6cbf if saved && !elems
        { ok: true, path: path || paths.first, elems: elems }
      rescue StandardError
        { ok: false, error: "no_rescue_path" }
      end
      def single_polygon_path(arr, boundary, base_area, r, side)
        polygons = arr[:polygons]
        return unless polygons.length == 1
        path = dedupe(polygons.first)
        return if path.length < 3
        num = Calc.signed_area(path)
        return if !num.finite? || num.abs <= 0.01 || self_intersects?(path)
        path.reverse! if num * base_area < 0.0
        return unless area_shrunk?(path, boundary, base_area, r, side)
        return unless offset_side_ok?(path, boundary, r, side)
        return unless drift_check(path, boundary, r)[:ok]
        path unless gouge_at(ring(path), gouge_guide(boundary, r))
      end
      def area_shrunk?(path, boundary, base_area, r, side)
        num = Calc.signed_area(path)
        if side == "inside"
          num.abs < base_area.abs &&
            fits_inside?(path, boundary, r) &&
            !inverted?(path, boundary, true)
        else
          side == "outside" && num.abs > base_area.abs
        end
      end
      def mend_path(sel, boundary, r, mend)
        _28d5c275 = Clip.mend_polygon(sel, boundary, radius_mm: r, mend: mend)
        return unless _28d5c275.ok
        elems = _28d5c275.candidates
        path = dedupe(Calc.flatten_loop(elems, RESCUE_SAMPLE_MM))
        arr = drift_check(path, boundary, r, tolerance_mm: RESCUE_SOURCE_MM)
        tol = _28d5c275.metadata[:bridge_mend_count].positive? ? 0.45 : 0.052
        _03552549 = Locked.within?(ring(path), ring(sel), max_allowed: tol)
        [elems, path] if arr[:ok] && _03552549 <= tol
      end
      def bridge_path(elem_state, boundary, base_area, r, side, arr7)
        elems = elem_state[:elems]
        path = elements_to_path(elems)
        arr3 = elem_state[:bridge_mends]
        arr6 = elem_state[:tangent_mends]
        pad_x = 0.10
        arr2 = arr3.map do |arr|
          num = [arr[:rail_shift_mm].abs, arr[:arc_move_mm].abs, arr[:bridge_len_mm].abs].max
          { point: arr[:point], radius_mm: [[num + pad_x, pad_x].max, 1.50].min }
        end
        arr6.each { |arr| arr2 << { point: arr[:point], radius_mm: [[arr[:joint_move_mm].abs + pad_x, pad_x].max, 0.30].min } }
        flag = (arr3 + arr6).all? do |arr|
          (Calc.distance(arr[:point], arr[:arc_origin_mm]) - r).abs <= 0.002
        end
        _e94ae109 = dedupe(path)
        _10a86f9d = flag && elem_state[:change_mm] <= RESCUE_CHANGE_MM &&
                arr3.all? { |arr| arr[:rail_shift_mm] <= RESCUE_CHANGE_MM } &&
                outline_unchanged?(path, elem_state[:rail_path], arr2) &&
                !self_intersects?(_e94ae109) &&
                area_shrunk?(_e94ae109, boundary, base_area, r, side) &&
                offset_side_ok?(_e94ae109, boundary, r, side) &&
                gouge_at(path, gouge_guide(boundary, r)).nil?
        return unless _10a86f9d
        arr4 = drift_check_ruby(path, boundary, r, arr2)
        return { ok: true, path: _e94ae109, elems: elems, guard: arr4 } if arr4[:ok]
        return unless arr7
        [0.010, 0.005, 0.0025].each do |tol|
          arr5 = lock_from_path(elem_state[:original_path], r, tolerance_mm: tol)
          done = arr5[:risk] && bridge_path(arr5, boundary, base_area, r, side, false)
          return done if done
        end
        nil
      end
      def realign_lock(lock, _ac4ed97e, base_xy, r)
        return if lock_empty?(lock)
        path = ring(dedupe(_ac4ed97e))
        _b7d2a364 = Locked.align(lock[:elems], path, align_tol_mm: 0.0025, shape_tol_mm: 0.01,
                                                        sample_tol_mm: RESCUE_SAMPLE_MM)
        return unless _b7d2a364.ok
        outline = lock[:region_boundary] == true
        if lock[:local_rail] == true
          arr = lock[:rail_check]
        elsif outline && region_locked?(lock)
          arr = lock[:region_watch]
        else
          tol = outline ? lock[:region_tolerance_mm] : RESCUE_SOURCE_MM
          sampled = Calc.flatten_loop(_b7d2a364.elems, RESCUE_SAMPLE_MM)
          arr = drift_check(sampled, base_xy, r, tolerance_mm: tol)
          return unless arr[:ok]
        end
        lock = lock.merge(elems: _b7d2a364.elems, align_tol_mm: 1.0e-6, sample_tol_mm: RESCUE_SAMPLE_MM,
                                final_check: arr, final_aligned: true)
        [pin_ends_to(path, _b7d2a364.start_point), lock]
      end
      def drift_check(path_xy, base_xy, r, tolerance_mm: 0.05)
        fail = { ok: false, error: "check_unmeasured" }
        tol = tolerance_mm + (Clip::QUANT_MM * 2.0)
        err_code = Calc::NATIVE_EXT ? Native.rescue_drift(path_xy, base_xy, r, tol) : nil
        return { ok: true } if err_code == 0
        return { ok: false, error: "check_drift" } if err_code == 1
        return fail if err_code == 2
        path = ring(dedupe(path_xy))
        boundary = ring(dedupe(base_xy))
        return fail if path.length < 4 || boundary.length < 4
        idx = pack_outline(boundary)
        want = path_steps_ok?(path) do |pt|
          num = (packed_distance_at(pt, idx) - r).abs
          return fail unless num.finite?
          return { ok: false, error: "check_drift" } if num > tol
        end
        want && want < 50_000 ? { ok: true } : fail
      end
      def drift_check_ruby(path_pts, base_pts, r, markers)
        fail = { ok: false, error: "check_unmeasured" }
        path = ring(dedupe(path_pts))
        boundary = ring(dedupe(base_pts))
        return fail if path.length < 4 || boundary.length < 4 || markers.empty?
        idx = pack_outline(boundary)
        tol = RESCUE_SOURCE_MM + (Clip::QUANT_MM * 2.0)
        num = 0
        want = path_steps_ok?(path) do |pt|
          num2 = (packed_distance_at(pt, idx) - r).abs
          return fail unless num2.finite?
          next if near_marker?(markers, pt)
          num += 1
          return { ok: false, error: "check_drift" } if num2 > tol
        end
        want && num.positive? ? { ok: true } : fail
      end
      def outline_unchanged?(outline_a, outline_b, markers)
        arr = ring(dedupe(outline_a))
        arr2 = ring(dedupe(outline_b))
        return false if arr.length < 4 || arr2.length < 4
        want = 0
        [[arr, arr2], [arr2, arr]].all? do |a, b|
          idx = pack_outline(b)
          want = path_steps_ok?(a, want) do |pt|
            tol = near_marker?(markers, pt) ? RESCUE_CHANGE_MM : 0.012
            return false unless packed_distance_at(pt, idx) <= tol
          end
        end
      end
      def path_steps_ok?(path, want = 0)
        path.each_cons(2) do |row0, last_rect|
          length = Calc.distance(row0, last_rect)
          return unless length.finite?
          steps = [[(length / 0.25).ceil, 1].max, 4096].min
          num = steps.to_f
          x = row0[0]
          y = row0[1]
          dx = last_rect[0] - x
          dy = last_rect[1] - y
          i = 0
          while i < steps
            return if want >= 50_000
            want += 1
            t = i / num
            yield [x + dx * t, y + dy * t]
            i += 1
          end
        end
        want
      end
      def near_marker?(arr2, pt)
        arr2.any? { |arr| Calc.distance(pt, arr[:point]) <= arr[:radius_mm] }
      end
      def pin_ends_to(path, start)
        arr = path.map { |pt| [pt[0].to_f, pt[1].to_f] }
        arr[0] = start.dup
        arr[-1] = start.dup
        arr
      end
      def elements_to_path(elems)
        ring(dedupe(Calc.flatten_loop(elems, RESCUE_SAMPLE_MM)))
      end
      def path_matches?(path, arr)
        flag = Calc::NATIVE ? Native.path_matches(path, arr) : nil
        return flag unless flag.nil?
        return false if path.length < 2 || arr.length < 2
        normal = arr.map { |arr2| [arr2[0].to_f, arr2[1].to_f] }
        h = {}
        normal.each_cons(2).with_index do |(a, b), i|
          steps = [[Math.hypot(b[0] - a[0], b[1] - a[1]).ceil, 1].max, 8192].min
          (0..steps).each do |num3|
            x, y = Calc.lerp(a, b, num3.to_f / steps)
            entries = ((h[(x / 2.0).floor] ||= {})[(y / 2.0).floor] ||= [])
            entries << i unless entries.last == i
          end
        end
        num = 40_000
        path.each_cons(2) do |row0, last_rect|
          a = [row0[0].to_f, row0[1].to_f]
          b = [last_rect[0].to_f, last_rect[1].to_f]
          steps = [[(Math.hypot(b[0] - a[0], b[1] - a[1]) / 0.50).ceil, 1].max, 4096].min
          (0..steps).each do |num2|
            return false if num <= 0
            pt = Calc.lerp(a, b, num2.to_f / steps)
            _4168a8e5 = (pt[0] / 2.0).floor
            _e2c52692 = (pt[1] / 2.0).floor
            flag2 = NEIGHBORS.any? do |dx, dy|
              h.dig(_4168a8e5 + dx, _e2c52692 + dy)&.any? { |i| Calc.segment_distance(pt, normal[i], normal[i + 1]) <= 0.15 }
            end
            return false unless flag2
            num -= 1
          end
        end
        true
      end
      def rescue_outline(out, tool, anchor, vec)
        @rescue_error = nil
        normal = simplify_open(ring(dedupe(out.map { |pt| to_mm(pt, anchor) })))
        normal.pop while normal.length > 1 && same_xy?(normal.first, normal.last)
        boundary = dedupe(normal)
        return pocket_error(Text.t(:duong, :van_de)) if boundary.length < 3 || Calc.signed_area(boundary).abs <= 0.01
        return pocket_error(Text.t(:duong, :bien_tu_cat)) if self_intersects?(boundary)
        diameter = tool["diameter"].to_f.abs
        r = diameter * 0.5
        return pocket_error(Text.t(:duong, :van_de)) unless r.positive?
        circle = outline_center(vec, boundary, anchor)
        rings = inner_contour(normal, tool, diameter) unless circle
        unless rings
          ok = circle ? bore_plan(circle, tool) : clear_pocket(boundary, tool, r, diameter)
          ok ||= raster_pocket(boundary, tool, r, diameter) unless circle
          return ok && assert_safe(ok, boundary, r, circle)
        end
        num = ->(row0, arr3) { (row0[0] - arr3[0]).abs <= 0.01 && (row0[1] - arr3[1]).abs <= 0.01 }
        loops = rings.filter_map do |loop_pts|
          arr = []
          loop_pts.each { |pt| arr << pt unless arr.last && num.call(arr.last, pt) }
          arr.pop while arr.length > 1 && num.call(arr.first, arr.last)
          arr << arr.first.dup if arr.length >= 3
        end
        outline = loops.first
        return pocket_error unless outline && valid_loop?(outline)
        arr2 = loops.reverse.filter_map do |loop_pts|
          outer_loop = ring(simplify_open(loop_pts))
          ring(orient(outer_loop, tool)) if outer_loop.length >= 4
        end
        return pocket_error if arr2.empty?
        fill = arr2.length < 2 && pocket_fits?(outline, diameter)
        paths = fill ? pocket_paths(outline, tool, diameter) : link_scan_lines(arr2, outline, tool)
        return pocket_error if paths.empty?
        assert_safe({ paths: paths }, boundary, r, nil, tool)
      end
      def pocket_error(reason = nil)
        @rescue_error = reason
        nil
      end
      def rescue_error
        @rescue_error || Text.t(:duong, :dao_qua_lon)
      end
      def step_over(tool, diameter, num2 = 0.65, per_row = 0.80)
        num = tool["pocket_step_mm"].to_f
        step = num.positive? ? num : diameter * num2
        [[step, diameter * 0.10].max, diameter * per_row].min
      end
      def outline_center(bb, boundary, anchor)
        if bb.vector_type == :circle && bb.center
          center = to_mm(bb.center, anchor)
          r = if bb.radius.to_f.positive?
                     bb.radius.to_f * MM_PER_INCH
                   else
                     Calc.kahan_sum(boundary.map { |pt| Calc.distance(pt, center) }) / boundary.length.to_f
                   end
          return { center: center, radius: r, explicit: true } if r.positive?
        end
        circle_fit_loose(boundary)
      end
      def bore_plan(arr, tool)
        center = arr[:center]
        diameter = tool["diameter"].to_f.abs
        r = diameter * 0.5
        tol = arr[:explicit] ? 0.005 : [[arr[:radial_error] + 0.005, 0.01].max, 0.03].min
        _dcb49d68 = arr[:radius] - r
        return pocket_error if _dcb49d68 < -tol
        return { paths: [], plunge_points: [center.dup] } if _dcb49d68 <= tol
        step = step_over(tool, diameter)
        inner = _dcb49d68 % step
        inner = [r * 0.50, _dcb49d68].min if inner <= 0.001
        inner = [inner, r, _dcb49d68].min
        want = [((_dcb49d68 - inner) / step).ceil, 0].max
        num2 = want.positive? ? (_dcb49d68 - inner) / want.to_f : 0.0
        arr2 = (0..want).map { |idx| inner + num2 * idx }
        arr2[-1] = _dcb49d68
        cut_direction = tool["cut_direction"].to_s
        flag = tool.merge("cut_direction" => %w[cw ccw].include?(cut_direction) ? cut_direction : "ccw")
        rings = arr2.filter_map do |num|
          segments = ([[(2.0 * Math::PI * num.abs / 0.50).ceil, 36].max, 240].min + 3) / 4 * 4
          circle = ring(Calc.arc_points(center, num, Math::PI * 0.5, 2.0 * Math::PI, segments)[0...-1])
          _e7c3b158 = ring(orient(circle, flag))
          _e7c3b158 if valid_loop?(_e7c3b158)
        end
        return pocket_error if rings.empty?
        paths = link_scan_lines(rings, rings.last, tool.merge("entry_corner" => "auto"))
        paths.empty? ? pocket_error : { paths: paths }
      end
      def assert_safe(ok, boundary, r, circle = nil, tool = nil)
        return ok if ok[:safety_checked] || paths_safe?(ok, boundary, r, circle)
        if tool
          diameter = r * 2.0
          arr = clear_pocket(boundary, tool, r, diameter) ||
                    raster_pocket(boundary, tool, r, diameter)
          return arr if arr && (arr[:safety_checked] || paths_safe?(arr, boundary, r))
        end
        pocket_error
      end
      def paths_safe?(ok, boundary, r, circle = nil, idx = nil)
        paths = ok[:paths]
        if circle
          _e5327771 = circle[:radius] - r
          return false if _e5327771 < -POCKET_CLEARANCE_MM
          out = Array(ok[:plunge_points]) + paths.flatten(1)
          return false if out.empty?
          _0a075013 = out.max_by { |pt| Calc.distance(pt, circle[:center]) }
          return Calc.distance(_0a075013, circle[:center]) <= [_e5327771, 0.0].max + POCKET_CLEARANCE_MM
        end
        limit = [r - POCKET_CLEARANCE_MM, 0.0].max
        idx ||= inside_index(boundary, r)
        paths.all? do |path|
          rows = to_pairs(path)
          rows.length >= 2 && rows.each_cons(2).all? { |row0, last_rect| link_clear?(row0, last_rect, boundary, limit, idx) }
        end
      end
      def inside_index(boundary, r)
        return nil if boundary.length < 24
        cell = [r, 1.0].max
        { grid: segment_grid(boundary, cell), cell: cell, inside: {} }
      end
      def link_clear?(row0, last_rect, boundary, limit, idx)
        mid_pt = [(row0[0] + last_rect[0]) * 0.5, (row0[1] + last_rect[1]) * 0.5]
        return false unless inside_cached?(row0, boundary, idx) && inside_cached?(mid_pt, boundary, idx) &&
                            inside_cached?(last_rect, boundary, idx)
        snap_edges = cells_between(idx, row0, last_rect, limit)
        free_at = Calc::NATIVE ? Native.gap_clear(row0, last_rect, boundary, snap_edges, limit, NODE_TOLERANCE_MM * 2.0) : nil
        return free_at unless free_at.nil?
        (snap_edges || (0...boundary.length)).none? { |edge| Calc.segment_gap(row0, last_rect, boundary[edge], boundary[(edge + 1) % boundary.length]) < limit }
      end
      def inside_cached?(pt, boundary, idx)
        h6 = idx && idx[:inside]
        return Calc.in_polygon?(pt[0], pt[1], boundary) unless h6
        h6.clear if h6.length > 200_000
        key = [(pt[0] * 10_000.0).round, (pt[1] * 10_000.0).round]
        h6.fetch(key) { h6[key] = Calc.in_polygon?(pt[0], pt[1], boundary) }
      end
      def cells_between(idx, row0, last_rect, limit)
        return nil unless idx
        cell = idx[:cell]
        pad_x = limit + 0.001
        _fe8c2291 = (([row0[0], last_rect[0]].min - pad_x) / cell).floor
        _b96b552c = (([row0[0], last_rect[0]].max + pad_x) / cell).floor
        _292168ca = (([row0[1], last_rect[1]].min - pad_x) / cell).floor
        _550469f9 = (([row0[1], last_rect[1]].max + pad_x) / cell).floor
        return nil if (_b96b552c - _fe8c2291 + 1) * (_550469f9 - _292168ca + 1) > 4096
        partner = {}
        _fe8c2291.upto(_b96b552c) { |_bade6541| _292168ca.upto(_550469f9) { |gap_y| idx[:grid].dig(_bade6541, gap_y)&.each { |edge| partner[edge] = true } } }
        partner.keys
      end
      def nested_outlines(vectors)
        rows = vectors.select { |vec| vec.closed && vec.points.length >= 3 }
        return [] if rows.length < 2
        rec = nesting_depth(rows)
        taken = {}
        materials = rows.sort_by { |vec| [rec[vec][:depth], -Calc.bounds_area(vec.points)] }
        materials.each_with_object([]) do |outer, h7|
          next if taken[outer]
          arr = rows.select { |row| !taken[row] && !row.equal?(outer) && rec[row][:parent].equal?(outer) }
          next unless arr.length == 1 && inside?(arr.first, outer)
          h7 << { outer: outer, inner: arr.first }
          taken[outer] = taken[arr.first] = true
        end
      end
      def tool_fits?(outer_rec, inner_rec, tool, anchor)
        diameter = tool["diameter"].to_f.abs
        r = diameter * 0.5
        return nil unless r.positive?
        outer, inner = [outer_rec, inner_rec].map { |vec| dedupe(vec.points.map { |pt| to_mm(pt, anchor) }) }
        return nil if outer.length < 3 || inner.length < 3
        outer, inner = inner, outer if Calc.signed_area(inner).abs > Calc.signed_area(outer).abs
        return nil unless polygon_contains?(outer, inner)
        _4e4d8475 = offset_native(outer, r, "inside")
        arr = offset_native(inner, r, "outside")
        return nil unless valid_loop?(_4e4d8475) && valid_loop?(arr)
        _4e4d8475, arr = [_4e4d8475, arr].map { |_e7c3b158| dedupe(_e7c3b158) }
        return nil if self_intersects?(_4e4d8475) || self_intersects?(arr)
        return nil unless polygon_contains?(_4e4d8475, arr)
        step = step_over(tool, diameter, 0.50, 0.75)
        num = Calc.signed_area(arr).abs
        rings = [ring(_4e4d8475)]
        cur = _4e4d8475
        500.times do
          _f273cbbc = spiral_contours(cur, step, diameter)
          break unless valid_loop?(_f273cbbc)
          _f273cbbc = dedupe(_f273cbbc)
          break unless polygon_contains?(_f273cbbc, arr)
          break if (Calc.signed_area(_f273cbbc).abs - num).abs <= 0.01
          rings << ring(_f273cbbc)
          cur = _f273cbbc
        end
        rings << ring(arr)
        arr2 = []
        rings.map { |_e7c3b158| [Calc.signed_area(_e7c3b158).abs, _e7c3b158] }.sort_by(&:first).each do |_354e0ff6, _e7c3b158|
          next if arr2.any? { |slot| (slot[0] - _354e0ff6).abs <= 0.01 }
          outer_loop = ring(simplify_open(_e7c3b158))
          outer_loop = rotate_to_corner(orient(outer_loop, tool), tool["entry_corner"])
          outer_loop = ring(close_path(outer_loop))
          arr2 << [_354e0ff6, outer_loop] if valid_loop?(outer_loop)
        end
        arr2.map(&:last) if arr2.length >= 2
      end
    end
  end
end
