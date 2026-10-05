module KSU
  module Cnc
    module Canonicalizer
      BASE_TOL_MM = 0.001
      ZERO_LEN_MM = 0.000001
      GEOM_EPS_MM = 1.0e-12
      Result = Struct.new(:ok, :elems, :error, keyword_init: true)
      module_function
      def canonicalize(elems)
        rows = elems.map { |_0d6b8add| read_element(_0d6b8add) }
        return failure("empty") if rows.empty?
        rows = rows.reject { |arr| arr[:type] == :line && Calc.distance(arr[:s], arr[:e]) <= ZERO_LEN_MM }
        return failure("all_zero_length") if rows.empty?
        return failure("chain_gap") unless merge_runs(rows)
        loop do
          want = rows.length
          rows = rows.each_with_object([]) do |_0d6b8add, result|
            _1264b6fa = result.last && merge_pair(result.last, _0d6b8add)
            _1264b6fa ? (result[-1] = _1264b6fa) : (result << _0d6b8add)
          end
          if rows.length > 1 && (_1264b6fa = merge_pair(rows.last, rows.first))
            rows.pop
            rows[0] = _1264b6fa
          end
          break if rows.length == want
        end
        return failure("chain_gap") unless merge_runs(rows)
        Result.new(ok: true, elems: rows.each(&:freeze).freeze, error: nil)
      rescue StandardError => err
        failure(err.message)
      end
      def read_element(arr32)
        case Util.fetch_required(arr32, :type).to_sym
        when :line
          { type: :line, s: Calc.pt(Util.fetch_required(arr32, :s)), e: Calc.pt(Util.fetch_required(arr32, :e)) }
        when :arc
          c, s, arr = %i[c s e].map { |key| Calc.pt(Util.fetch_required(arr32, key)) }
          r = Calc.distance(s, c)
          raise ArgumentError, "bad_arc_radius" unless r.finite? && r > ZERO_LEN_MM
          _ddfbd967 = Util.enabled?(Util.lookup(arr32, :full_circle))
          ccw = Util.enabled?(Util.fetch_required(arr32, :ccw))
          unless _ddfbd967
            raise ArgumentError, "arc_radius_mismatch" if (r - Calc.distance(arr, c)).abs > BASE_TOL_MM
            sweep = Calc.sweep_between(Calc.deg4(s, c), Calc.deg4(arr, c), ccw)
            raise ArgumentError, "zero_sweep" if sweep.abs <= GEOM_EPS_MM
          end
          { type: :arc, s: s, e: _ddfbd967 ? s.dup : arr, c: c, ccw: ccw, full_circle: _ddfbd967,
            radius_mm: r, src_point_count: Util.lookup(arr32, :src_point_count) }
        else
          raise ArgumentError, "unknown_segment"
        end
      end
      def merge_runs(rows)
        rows.each_index do |idx|
          arr = rows[idx]
          b2 = rows[(idx + 1) % rows.length]
          gap2 = Calc.distance(arr[:e], b2[:s])
          return false if gap2 > BASE_TOL_MM
          next if gap2 <= GEOM_EPS_MM
          h = if arr[:type] == :arc then arr[:e]
                        elsif b2[:type] == :arc then b2[:s]
                        else [(arr[:e][0] + b2[:s][0]) * 0.5, (arr[:e][1] + b2[:s][1]) * 0.5]
                        end
          arr[:e] = h.dup
          b2[:s] = h.dup
        end
        true
      end
      def merge_pair(arr, arr2)
        return { type: :line, s: arr[:s].dup, e: arr2[:e].dup } if collinear_lines?(arr, arr2)
        merge_arcs(arr, arr2)
      end
      def collinear_lines?(arr, arr2)
        return false unless arr[:type] == :line && arr2[:type] == :line
        return false if Calc.distance(arr[:e], arr2[:s]) > BASE_TOL_MM
        ax = arr[:e][0] - arr[:s][0]
        ay = arr[:e][1] - arr[:s][1]
        bx2 = arr2[:e][0] - arr2[:s][0]
        by2 = arr2[:e][1] - arr2[:s][1]
        _45b54bd9 = Math.hypot(ax, ay)
        return false if _45b54bd9 <= ZERO_LEN_MM || Math.hypot(bx2, by2) <= ZERO_LEN_MM
        (ax * by2 - ay * bx2).abs / _45b54bd9 <= BASE_TOL_MM && (ax * bx2 + ay * by2).positive?
      end
      def merge_arcs(arr, arr2)
        return nil unless arr[:type] == :arc && arr2[:type] == :arc && arr[:ccw] == arr2[:ccw]
        return nil if arr[:full_circle] || arr2[:full_circle] || Calc.distance(arr[:e], arr2[:s]) > BASE_TOL_MM
        _67b16b38 = Calc.distance(arr[:s], arr[:c])
        _66bbff43 = Calc.distance(arr2[:s], arr2[:c])
        return nil if Calc.distance(arr[:c], arr2[:c]) > 0.0005 || (_67b16b38 - _66bbff43).abs > 0.0005
        arr3 = Calc.tangent_at(arr, :end, GEOM_EPS_MM)
        b = Calc.tangent_at(arr2, :start, GEOM_EPS_MM)
        return nil unless arr3 && b
        return nil unless Math.acos([[arr3[0] * b[0] + arr3[1] * b[1], -1.0].max, 1.0].min) * 180.0 / Math::PI <= 0.05
        num3 = Calc.arc_sweep(arr)
        num2 = Calc.arc_sweep(arr2)
        num = num3.abs + num2.abs
        return nil if num <= GEOM_EPS_MM || num >= Math::PI * 2.0 - GEOM_EPS_MM
        _07ed2838 = arc_weight(arr, num3)
        _533457a0 = arc_weight(arr2, num2)
        _43cbf38b = _07ed2838 + _533457a0
        center = [(arr[:c][0] * _07ed2838 + arr2[:c][0] * _533457a0) / _43cbf38b,
                     (arr[:c][1] * _07ed2838 + arr2[:c][1] * _533457a0) / _43cbf38b]
        r = (_67b16b38 * _07ed2838 + _66bbff43 * _533457a0) / _43cbf38b
        _a5ec378f = Calc.project_to_radius(center, arr[:s], r)
        _465fc811 = Calc.project_to_radius(center, arr2[:e], r)
        return nil unless _a5ec378f && _465fc811
        num4 = Calc.sweep_between(Calc.deg4(_a5ec378f, center), Calc.deg4(_465fc811, center), arr[:ccw])
        return nil if num4.abs <= GEOM_EPS_MM
        return nil if (num4.abs - num).abs > 0.001 * Math::PI / 180.0
        { type: :arc, s: _a5ec378f, e: _465fc811, c: center, ccw: arr[:ccw], full_circle: false,
          radius_mm: r, src_point_count: [arr[:src_point_count].to_i + arr2[:src_point_count].to_i - 1, 2].max,
          elem_role: "concyclic_merge" }
      end
      def arc_weight(arr, sweep)
        want = arr[:src_point_count].to_i
        want > 1 ? (want - 1).to_f : [sweep.abs, GEOM_EPS_MM].max
      end
      def failure(error)
        Result.new(ok: false, elems: [].freeze, error: error)
      end
    end
    module Topology
      Contour = Struct.new(:vector, :points, :closed, :gap_mm, :fake_closed)
      module Engine
        module_function
        def to_segments(vectors, anchor)
          vectors.filter_map do |vec|
            next if vec.points.length < 2
            arr = []
            vec.points.each do |pt|
              arr2 = Export.to_mm(pt, anchor)
              arr << arr2 if arr.empty? || Math.hypot(arr[-1][0] - arr2[0], arr[-1][1] - arr2[1]) > 0.0001
            end
            next if arr.length < 2
            gap2 = Calc.distance(arr.first, arr.last)
            Contour.new(vec, arr, vec.closed && gap2 <= Export::CHAIN_CLOSE_MM, gap2, Util.fake_closed?(vec))
          end
        end
      end
      module Validator
        module_function
        def validate(arr2)
          arr = []
          warnings = []
          arr2.each do |_105d9ed2|
            key = if _105d9ed2.closed
                       :dien_tich_0 if Calc.signed_area(_105d9ed2.points).abs < 0.001
                     elsif _105d9ed2.fake_closed || _105d9ed2.vector.closed
                       :kin_bi_ho
                     end
            next unless key
            x, y = _105d9ed2.points.first.first(2).map { |val| Text.num(val, 1) }
            _747530d5 = { layer: _105d9ed2.vector.layer_name, khoang: Text.num(_105d9ed2.gap_mm, 3), x: x, y: y }
            (key == :dien_tich_0 ? arr : warnings) << Text.t(:ban_ve, key, **_747530d5)
          end
          { ok: arr.empty?, errors: arr, warnings: warnings }
        end
      end
    end
    module Validator
      Issue = Struct.new(:code)
      Result = Struct.new(:hard_issues) do
        def valid?
          hard_issues.empty?
        end
      end
      Line = Struct.new(:s, :e) do
        def sheet_type
          :line
        end
        def length
          Math.hypot(e[0] - s[0], e[1] - s[1])
        end
        def box
          [[s[0], e[0]].min, [s[1], e[1]].min, [s[0], e[0]].max, [s[1], e[1]].max]
        end
      end
      Arc = Struct.new(:s, :e, :c, :r, :a0, :sweep) do
        def sheet_type
          :arc
        end
        def length
          r * sweep.abs
        end
        def angle_within?(a, num)
          eps = num.abs
          len2d = (sweep > 0 ? a - a0 : a0 - a) % (Math::PI * 2.0)
          len2d = 0.0 if (Math::PI * 2.0 - len2d).abs <= eps
          len2d >= -eps && len2d <= sweep.abs + eps
        end
        def point_at(a)
          [c[0] + r * Math.cos(a), c[1] + r * Math.sin(a)]
        end
        def box
          pts2 = [s, e]
          [0.0, Math::PI / 2, Math::PI, 3 * Math::PI / 2].each do |_17818395|
            pts2 << point_at(_17818395) if angle_within?(_17818395, 1e-9)
          end
          bb2, bb = pts2.transpose
          [bb2.min, bb.min, bb2.max, bb.max]
        end
      end
      module_function
      def validate(segments, expect_ccw: nil, source_segments: nil, expected_side: nil)
        return Result.new([Issue.new(:invalid_input)]) if segments.empty?
        tol = 0.001
        arr = []
        segs = build_segments(segments, tol, arr)
        return Result.new(arr) if segs.empty?
        check_closed(segs, tol, arr)
        _48a302ae = find_crossings(segs, tol, arr)
        validate_loops(source_segments, segs, expected_side, tol, arr, _48a302ae) if source_segments
        return Result.new(arr) if expect_ccw.nil? || arr.any? { |i| i.code == :open_contour }
        _354e0ff6 = signed_area(segs)
        num = [tol * segs.inject(0.0) { |acc2, seg| acc2 + seg.length }, tol * tol].max
        arr << Issue.new(:flipped_orientation) if expect_ccw ? _354e0ff6 < -num : _354e0ff6 > num
        Result.new(arr)
      end
      def build_segments(rows, tol, _53e651f8)
        rows.each_with_object([]) do |elem, segs|
          pts = to_segments(elem, tol)
          (pts.is_a?(Issue) ? _53e651f8 : segs) << pts
        end
      end
      def to_segments(elem, tol)
        case elem[:type]
        when :line
          s = finite_xy(elem[:s])
          arr = finite_xy(elem[:e])
          return Issue.new(:invalid_segment) unless s && arr
          Math.hypot(arr[0] - s[0], arr[1] - s[1]) < tol ? Issue.new(:zero_length) : Line.new(s, arr)
        when :arc
          s = finite_xy(elem[:s])
          arr = finite_xy(elem[:e])
          arr2 = finite_xy(elem[:c])
          return Issue.new(:invalid_segment) unless s && arr && arr2 && (elem[:ccw] == true || elem[:ccw] == false)
          _c8f37482 = Math.hypot(s[0] - arr2[0], s[1] - arr2[1])
          part_re2 = Math.hypot(arr[0] - arr2[0], arr[1] - arr2[1])
          return Issue.new(:bad_arc) if (_c8f37482 - part_re2).abs > tol * 10 || _c8f37482 < tol
          a0 = Math.atan2(s[1] - arr2[1], s[0] - arr2[0])
          world_tr = elem[:full_circle] == true
          closed = Math.hypot(arr[0] - s[0], arr[1] - s[1]) <= tol
          return Issue.new(:bad_arc) if closed != world_tr
          sweep = if world_tr
                    elem[:ccw] ? Math::PI * 2.0 : -(Math::PI * 2.0)
                  else
                    a1 = Math.atan2(arr[1] - arr2[1], arr[0] - arr2[0])
                    elem[:ccw] ? (a1 - a0) % (Math::PI * 2.0) : -((a0 - a1) % (Math::PI * 2.0))
                  end
          arc = Arc.new(s, arr, arr2, (_c8f37482 + part_re2) / 2.0, a0, sweep)
          arc.length < tol ? Issue.new(:zero_length) : arc
        else
          Issue.new(:invalid_segment)
        end
      end
      def finite_xy(arr)
        x = arr[0].to_f
        y = arr[1].to_f
        [x, y] if x.finite? && y.finite?
      end
      def check_closed(segs, tol, _53e651f8)
        segs.each_with_index do |seg, i|
          num = segs[(i + 1) % segs.size]
          _53e651f8 << Issue.new(:open_contour) unless Math.hypot(seg.e[0] - num.s[0], seg.e[1] - num.s[1]) <= tol
        end
      end
      def to_native_row(seg)
        return [0, seg.s[0], seg.s[1], seg.e[0], seg.e[1], 0.0, 0.0, 0.0, 0.0, 0.0] if seg.sheet_type == :line
        [1, seg.s[0], seg.s[1], seg.e[0], seg.e[1], seg.c[0], seg.c[1], seg.r, seg.a0, seg.sweep]
      end
      def find_crossings(segs, tol, _53e651f8)
        arr3 = Calc::NATIVE_EXT ? Native.crossings(segs.map { |seg| to_native_row(seg) }, tol) : nil
        if arr3
          arr3[1].each { |err_code| _53e651f8 << Issue.new(err_code == 1 ? :collinear_overlap : :self_intersection) }
          return arr3[0]
        end
        n = segs.size
        arr = segs.map(&:box)
        h = {}
        gap_for = tol * 4.0
        _f515d7f8 = tol * 2
        arr4 = Array.new(n) { [] }
        materials = (0...n).sort_by { |k| arr[k][0] }
        materials.each_with_index do |meta, arr2|
          screen_box = arr[meta]
          _68b53d20 = screen_box[2] + gap_for
          while (arr2 += 1) < n && arr[k = materials[arr2]][0] <= _68b53d20
            if meta < k
              arr4[meta] << k if boxes_overlap?(screen_box, arr[k], tol)
            elsif boxes_overlap?(arr[k], screen_box, tol)
              arr4[k] << meta
            end
          end
        end
        small_size = arr.all? { |b| b[0] > -1.0e9 && b[1] > -1.0e9 && b[2] < 1.0e9 && b[3] < 1.0e9 }
        arr4.each_with_index do |row, i|
          a = segs[i]
          row.sort!.each do |ix|
            b = segs[ix]
            next if small_size && ix == i + 1 && same_direction?(a, b)
            arr5, overlap = segment_crossings(a, b, tol)
            _53e651f8 << Issue.new(:collinear_overlap) if overlap
            next if overlap || arr5.empty?
            e = ix == i + 1 && Calc.distance(a.e, b.s) <= _f515d7f8
            _0d017c2d = i == 0 && ix == n - 1 && Calc.distance(b.e, a.s) <= _f515d7f8
            arr5.each do |arr2|
              next if e && Calc.distance(arr2, a.e) <= _f515d7f8
              next if _0d017c2d && Calc.distance(arr2, b.e) <= _f515d7f8
              key = [i, ix, (arr2[0] / tol).round, (arr2[1] / tol).round]
              next if h[key]
              h[key] = true
              _53e651f8 << Issue.new(:self_intersection)
            end
          end
        end
        arr
      end
      def same_direction?(a, b)
        return false unless a.sheet_type == :line && b.sheet_type == :line && a.e == b.s
        _3e718c2b = a.e[0] - a.s[0]
        _25e31dc7 = a.e[1] - a.s[1]
        _1e4ff9ac = b.e[0] - b.s[0]
        _e758b2b3 = b.e[1] - b.s[1]
        (_3e718c2b * _e758b2b3 - _25e31dc7 * _1e4ff9ac).abs > 1.0e-12 * [Math.hypot(_3e718c2b, _25e31dc7) * Math.hypot(_1e4ff9ac, _e758b2b3), 1.0].max
      end
      def validate_loops(loops, arr3, expect_ccw, tol, _53e651f8, expected_side)
        arr2 = []
        boundary = build_segments(loops, tol, arr2)
        check_closed(boundary, tol, arr2)
        arr = find_crossings(boundary, tol, arr2)
        return _53e651f8 << Issue.new(:invalid_input) if boundary.empty? || arr2.any?
        return _53e651f8 << Issue.new(:bad_offset_side) if pairwise_crossings(boundary, arr3, tol, arr, expected_side)
        arr5 = arr3.flat_map { |seg| sample_midpoints(seg) }
        screen_box = [arr.map { |b| b[0] }.min, arr.map { |b| b[1] }.min,
                  arr.map { |b| b[2] }.max, arr.map { |b| b[3] }.max]
        arr4 = arr5.map { |segs_for_ray| point_inside?(boundary, segs_for_ray, tol, screen_box) }.compact
        return _53e651f8 << Issue.new(:contain_unknown) if arr4.empty?
        _53e651f8 << Issue.new(:bad_offset_side) if arr4.any? { |_e964015e| expect_ccw == :inside ? !_e964015e : _e964015e }
      end
      def sample_midpoints(seg)
        return [[(seg.s[0] + seg.e[0]) * 0.5, (seg.s[1] + seg.e[1]) * 0.5]] if seg.sheet_type == :line
        want = [[(seg.sweep.abs / (Math::PI / 4.0)).ceil, 1].max, 16].min
        (0...want).map { |i| seg.point_at(seg.a0 + seg.sweep * ((i + 0.5) / want.to_f)) }
      end
      def pairwise_crossings(a1b, arr, tol, arr2, bbox)
        cell = grid_cell_size(bbox)
        grid = cell && build_grid(bbox, cell)
        a1b.each_with_index do |a, ia|
          num = grid ? grid_candidates(grid, cell, arr2[ia], tol) : (0...arr.length)
          num.each do |ib|
            next unless boxes_overlap?(arr2[ia], bbox[ib], tol)
            arr3, overlap = segment_crossings(a, arr[ib], tol)
            return true if overlap || arr3.any?
          end
        end
        false
      end
      def grid_cell_size(arr)
        return nil if arr.length < 32
        arr2 = arr.map { |screen_box| [screen_box[2] - screen_box[0], screen_box[3] - screen_box[1]].max }
        num = Calc.kahan_sum(arr2) / arr2.length.to_f
        num * 2.0 if num.finite? && num > 1.0e-9
      end
      def build_grid(arr, cell)
        grid = {}
        num = 0
        num2 = [arr.length * 128, 4096].max
        arr.each_with_index do |screen_box, idx|
          _fe8c2291, _b96b552c, _292168ca, arr2 = screen_box.values_at(0, 2, 1, 3).map { |val| (val / cell).floor }
          return nil if num + (_b96b552c - _fe8c2291 + 1) * (arr2 - _292168ca + 1) > num2
          _fe8c2291.upto(_b96b552c) do |_bade6541|
            _292168ca.upto(arr2) do |gap_y|
              ((grid[_bade6541] ||= {})[gap_y] ||= []) << idx
              num += 1
            end
          end
        end
        grid
      end
      def grid_candidates(grid, cell, screen_box, tol)
        partner = {}
        ((screen_box[0] - tol) / cell).floor.upto(((screen_box[2] + tol) / cell).floor) do |_bade6541|
          ((screen_box[1] - tol) / cell).floor.upto(((screen_box[3] + tol) / cell).floor) do |gap_y|
            grid.dig(_bade6541, gap_y)&.each { |idx| partner[idx] = true }
          end
        end
        partner.keys
      end
      def boxes_overlap?(arr, b, tol)
        arr[0] <= b[2] + tol && arr[2] >= b[0] - tol &&
          arr[1] <= b[3] + tol && arr[3] >= b[1] - tol
      end
      def point_inside?(segs, segs_for_ray, tol, screen_box)
        return false if segs_for_ray[0] < screen_box[0] - tol || segs_for_ray[0] > screen_box[2] + tol || segs_for_ray[1] < screen_box[1] - tol || segs_for_ray[1] > screen_box[3] + tol
        _c0f065c0 = Math.hypot(screen_box[2] - screen_box[0], screen_box[3] - screen_box[1]) * 2 + 1.0
        [0.0, 0.7853981, 2.1293, 3.9, 4.71238898, 5.5, 1.0472].each do |ang|
          c = ray_hits(segs, segs_for_ray, ang, _c0f065c0, tol)
          return c.odd? unless c.nil?
        end
        nil
      end
      def ray_hits(segs, segs_for_ray, ang, len, tol)
        _ee4f533e = Math.cos(ang)
        _4c8d9d44 = Math.sin(ang)
        total = 0
        segs.each do |seg|
          half = seg.sheet_type == :line ? ray_hits_line(segs_for_ray, _ee4f533e, _4c8d9d44, len, seg, tol) : ray_hits_arc(segs_for_ray, _ee4f533e, _4c8d9d44, len, seg, tol)
          return nil if half.nil?
          total += half
        end
        total
      end
      def ray_hits_line(segs_for_ray, _ee4f533e, _4c8d9d44, len, seg, tol)
        bx1, by1 = seg.s
        bx2, by2 = seg.e
        rx = bx2 - bx1
        ry = by2 - by1
        num2 = _ee4f533e * ry - _4c8d9d44 * rx
        return ((bx1 - segs_for_ray[0]) * _4c8d9d44 - (by1 - segs_for_ray[1]) * _ee4f533e).abs <= tol ? nil : 0 if num2.abs < 1e-12
        t = ((bx1 - segs_for_ray[0]) * ry - (by1 - segs_for_ray[1]) * rx) / num2
        u = ((bx1 - segs_for_ray[0]) * _4c8d9d44 - (by1 - segs_for_ray[1]) * _ee4f533e) / num2
        num = (tol * 2) / [seg.length, tol].max
        return nil if t.abs <= tol && u >= -num && u <= 1 + num
        return 0 if t <= tol || t > len || u < -num || u > 1 + num
        return nil if u <= num || u >= 1 - num
        1
      end
      def ray_hits_arc(segs_for_ray, _ee4f533e, _4c8d9d44, len, arc, tol)
        sx = segs_for_ray[0] - arc.c[0]
        sy = segs_for_ray[1] - arc.c[1]
        b  = 2 * (sx * _ee4f533e + sy * _4c8d9d44)
        _6ddbc368 = sx * sx + sy * sy - arc.r * arc.r
        num = b * b - 4 * _6ddbc368
        return nil if num.abs < 8 * arc.r * tol
        return 0 if num < 0
        _3643b905 = Math.sqrt(num)
        z = 4 * (tol / arc.r)
        num2 = 0
        [(-b - _3643b905) / 2.0, (-b + _3643b905) / 2.0].each do |t|
          ang = Math.atan2(segs_for_ray[1] + t * _4c8d9d44 - arc.c[1], segs_for_ray[0] + t * _ee4f533e - arc.c[0])
          return nil if t.abs <= tol && arc.angle_within?(ang, z)
          next if t <= tol || t > len
          len2d = (arc.sweep > 0 ? ang - arc.a0 : arc.a0 - ang) % (Math::PI * 2.0)
          len2d = 0.0 if (Math::PI * 2.0 - len2d).abs <= z
          stroke_w = arc.sweep.abs
          return nil if len2d < z || len2d > Math::PI * 2.0 - z || (len2d - stroke_w).abs < z
          num2 += 1 if len2d < stroke_w
        end
        num2
      end
      def segment_crossings(a, b, tol)
        if a.sheet_type == :line
          b.sheet_type == :line ? line_line_crossings(a, b, tol) : [line_arc_crossings(a, b, tol), false]
        elsif b.sheet_type == :line
          [line_arc_crossings(b, a, tol), false]
        else
          arc_arc_crossings(a, b, tol)
        end
      end
      def line_line_crossings(_58f95f3b, _3c77079d, tol)
        (x1, y1), (x2, y2) = _58f95f3b.s, _58f95f3b.e
        (bx1, by1), (bx2, by2) = _3c77079d.s, _3c77079d.e
        _3e718c2b = x2 - x1
        _25e31dc7 = y2 - y1
        _1e4ff9ac = bx2 - bx1
        _e758b2b3 = by2 - by1
        len_a = Math.hypot(_3e718c2b, _25e31dc7)
        len_b = Math.hypot(_1e4ff9ac, _e758b2b3)
        num = _3e718c2b * _e758b2b3 - _25e31dc7 * _1e4ff9ac
        _e3bcf5c4 = tol / [len_a, tol].max
        if num.abs <= 1.0e-12 * [len_a * len_b, 1.0].max
          cross = (bx1 - x1) * _25e31dc7 - (by1 - y1) * _3e718c2b
          return [[], false] if cross.abs > tol * [len_a, 1.0].max
          _3643b905 = _3e718c2b * _3e718c2b + _25e31dc7 * _25e31dc7
          _48e96c96 = ((bx1 - x1) * _3e718c2b + (by1 - y1) * _25e31dc7) / _3643b905
          _232f918e = ((bx2 - x1) * _3e718c2b + (by2 - y1) * _25e31dc7) / _3643b905
          _09dce564, _a5ffa708 = [_48e96c96, _232f918e].minmax
          _a9e4c2d5 = [_09dce564, 0.0].max
          _0c73f84a = [_a5ffa708, 1.0].min
          return [[], true] if (_0c73f84a - _a9e4c2d5) * len_a > tol * 2
          return [[], false] unless _0c73f84a >= _a9e4c2d5 - _e3bcf5c4
          t = [[(_a9e4c2d5 + _0c73f84a) * 0.5, 0.0].max, 1.0].min
        else
          t = ((bx1 - x1) * _e758b2b3 - (by1 - y1) * _1e4ff9ac) / num
          u = ((bx1 - x1) * _25e31dc7 - (by1 - y1) * _3e718c2b) / num
          _c066b852 = tol / [len_b, tol].max
          return [[], false] unless t >= -_e3bcf5c4 && t <= 1 + _e3bcf5c4 && u >= -_c066b852 && u <= 1 + _c066b852
        end
        [[[x1 + t * _3e718c2b, y1 + t * _25e31dc7]], false]
      end
      def line_arc_crossings(arr, a, tol)
        dx = arr.e[0] - arr.s[0]
        dy = arr.e[1] - arr.s[1]
        sx = arr.s[0] - a.c[0]
        sy = arr.s[1] - a.c[1]
        _bf31ee79 = dx * dx + dy * dy
        t_slice = -(sx * dx + sy * dy) / _bf31ee79
        px = arr.s[0] + t_slice * dx
        py = arr.s[1] + t_slice * dy
        num = a.r * a.r - ((px - a.c[0])**2 + (py - a.c[1])**2)
        return [] if num < -(2.0 * a.r * tol + tol * tol)
        num = 0.0 if num < 0.0
        _a9d16c6d = Math.sqrt(num / _bf31ee79)
        num2 = tol / [arr.length, tol].max
        payload2 = _a9d16c6d <= num2 ? [t_slice] : [t_slice - _a9d16c6d, t_slice + _a9d16c6d]
        _4f16de43 = tol / a.r
        pts2 = payload2.filter_map do |t|
          next unless t >= -num2 && t <= 1 + num2
          arr2 = [arr.s[0] + t * dx, arr.s[1] + t * dy]
          arr2 if a.angle_within?(Math.atan2(arr2[1] - a.c[1], arr2[0] - a.c[0]), _4f16de43)
        end
        dedupe_points(pts2, tol)
      end
      def arc_arc_crossings(a1, a2, tol)
        len2d = Math.hypot(a2.c[0] - a1.c[0], a2.c[1] - a1.c[1])
        if len2d <= tol && (a1.r - a2.r).abs <= tol
          overlap = arc_spans_overlap?(a1, a2, tol)
          arr2 = overlap ? [] : [a1.s, a1.e, a2.s, a2.e].select { |arr|
            grp2 = Math.atan2(arr[1] - a1.c[1], arr[0] - a1.c[0])
            a1.angle_within?(grp2, tol / a1.r) && a2.angle_within?(grp2, tol / a2.r)
          }
          return [dedupe_points(arr2, tol), overlap]
        end
        return [[], false] if len2d > a1.r + a2.r + tol || len2d < (a1.r - a2.r).abs - tol || len2d <= 1.0e-12
        _54ef9f0f = (a1.r**2 - a2.r**2 + len2d**2) / (2.0 * len2d)
        num = a1.r**2 - _54ef9f0f**2
        return [[], false] if num < -(2.0 * [a1.r, a2.r].max * tol + tol * tol)
        num = 0.0 if num < 0.0
        elem = Math.sqrt(num)
        _c5211475 = a1.c[0] + _54ef9f0f * (a2.c[0] - a1.c[0]) / len2d
        _5f765dbc = a1.c[1] + _54ef9f0f * (a2.c[1] - a1.c[1]) / len2d
        _821639ac = -(a2.c[1] - a1.c[1]) / len2d * elem
        _98c3a7e0 = (a2.c[0] - a1.c[0]) / len2d * elem
        flag = elem <= tol ? [[_c5211475, _5f765dbc]] : [[_c5211475 + _821639ac, _5f765dbc + _98c3a7e0], [_c5211475 - _821639ac, _5f765dbc - _98c3a7e0]]
        _08709280 = tol / a1.r
        _6378214c = tol / a2.r
        arr2 = flag.select do |arr|
          a1.angle_within?(Math.atan2(arr[1] - a1.c[1], arr[0] - a1.c[0]), _08709280) &&
            a2.angle_within?(Math.atan2(arr[1] - a2.c[1], arr[0] - a2.c[0]), _6378214c)
        end
        [dedupe_points(arr2, tol), false]
      end
      def arc_spans_overlap?(a1, a2, tol)
        eps = tol / [a1.r, a2.r, tol].max
        arr = arc_span(a1, eps)
        arr2 = arc_span(a2, eps)
        arr.any? { |x| arr2.any? { |y| [x[1], y[1]].min - [x[0], y[0]].max > eps } }
      end
      def arc_span(arc, eps)
        length = arc.sweep.abs
        return [[0.0, Math::PI * 2.0]] if length >= Math::PI * 2.0 - eps
        start = (arc.sweep > 0 ? arc.a0 : arc.a0 + arc.sweep) % (Math::PI * 2.0)
        run_batch = start + length
        run_batch <= Math::PI * 2.0 ? [[start, run_batch]] : [[start, Math::PI * 2.0], [0.0, run_batch - Math::PI * 2.0]]
      end
      def dedupe_points(pts2, tol)
        pts2.each_with_object([]) do |arr, out|
          out << arr unless out.any? { |arr2| Math.hypot(arr[0] - arr2[0], arr[1] - arr2[1]) <= tol }
        end
      end
      def signed_area(segs)
        num = 0.0
        segs.each do |seg|
          num += 0.5 * (seg.s[0] * seg.e[1] - seg.e[0] * seg.s[1])
          next unless seg.sheet_type == :arc
          num3 = seg.sweep.abs
          num2 = 0.5 * seg.r * seg.r * (num3 - Math.sin(num3))
          num += seg.sweep > 0 ? num2 : -num2
        end
        num
      end
      private_class_method :build_segments, :to_segments, :finite_xy, :check_closed, :find_crossings, :to_native_row,
                           :validate_loops, :sample_midpoints, :pairwise_crossings, :grid_cell_size,
                           :build_grid, :grid_candidates, :boxes_overlap?, :point_inside?, :ray_hits,
                           :ray_hits_line, :ray_hits_arc, :segment_crossings, :line_line_crossings, :line_arc_crossings, :arc_arc_crossings,
                           :arc_spans_overlap?, :arc_span, :dedupe_points, :same_direction?
    end
    module Refit
      METRIC_SAMPLES = 512
      GAPLESS_MM = 0.001
      GEOM_EPS_MM = 1.0e-9
      module_function
      def clean_points(out)
        rows = []
        out.each { |pt| rows << pt if rows.empty? || Calc.distance(rows.last, pt) > GEOM_EPS_MM }
        rows.pop while rows.length > 2 && Calc.distance(rows.first, rows.last) <= GEOM_EPS_MM
        rows
      end
      def refit(out)
        boundary = clean_points(out)
        return failure("too_few_pts") if boundary.length < 3
        return failure("source_oversize") if boundary.length > 1500
        base_area = Calc.signed_area(boundary)
        return failure("source_bad_shape") if base_area.abs <= GEOM_EPS_MM
        _bdeab2bf = boundary.each_index.max_by do |idx|
          Calc.corner_angle_deg(boundary[idx - 1], boundary[idx], boundary[(idx + 1) % boundary.length], GEOM_EPS_MM)
        end
        arr2 = boundary.rotate(_bdeab2bf)
        _6dd27878 = arr2 + [arr2.first.dup]
        runs = arc_candidates(_6dd27878)
        return failure("no_arc_found") if runs.empty?
        elems = arc_segment(rebuild_elements(_6dd27878, runs))
        flag = elems.each_with_index.all? do |arr, idx|
          Calc.distance(arr[:e], elems[(idx + 1) % elems.length][:s]) <= GAPLESS_MM
        end
        return failure("gap_fail") unless flag
        return failure("check_fail") unless Validator.validate(elems, expect_ccw: base_area.positive?).valid?
        return failure("wrong_turn") unless base_area.negative? == Calc.path_area(elems).negative?
        _17091c88 = sample_metric(boundary)
        arr3 = _17091c88 + elems.flat_map { |arr| arr.values_at(:s, :e, :c).compact }
        num = max_min_distance(_17091c88, elems.length, arr3) do |pt, idx|
          arr = elems[idx]
          arr[:type] == :arc ? Calc.arc_distance(pt, arr) : Calc.point_segment_distance(pt, arr[:s], arr[:e], GEOM_EPS_MM)
        end
        mid = [num, runs.map { |start2| start2[:max_radial_mm] }.max].max
        return failure("reparse_fail") unless mid <= 0.005
        _020bbe85 = Calc.flatten_path(elems, chord_tol_mm: 0.01)
        _7af979e5 = max_deviation(sample_metric(_020bbe85), boundary)
        _c1535085 = max_deviation(_17091c88, _020bbe85)
        metrics = { sample_error_mm: _c1535085, roundtrip_error_mm: [_7af979e5, _c1535085].max }
        { status: "rebuilt_ok", reconstruction: { rotation_index: _bdeab2bf }, metrics: metrics, elems: elems }
      end
      def max_deviation(out, arr)
        want = arr.length
        max_min_distance(out, want, out + arr) do |pt, idx|
          Calc.point_segment_distance(pt, arr[idx], arr[(idx + 1) % want], GEOM_EPS_MM)
        end
      end
      def max_min_distance(out, want, arr2)
        num2 = want.positive? && arr2.all? { |arr| arr[0].abs < 1.0e150 && arr[1].abs < 1.0e150 }
        return out.map { |pt| Array.new(want) { |idx| yield(pt, idx) }.min }.max unless num2
        flag = nil
        num = 0
        out.each do |pt|
          _f515d7f8 = nil
          start = num
          want.times do |_5d951b22|
            idx = (start + _5d951b22) % want
            val = yield(pt, idx)
            next unless _f515d7f8.nil? || val < _f515d7f8
            _f515d7f8 = val
            num = idx
            break if flag && _f515d7f8 <= flag
          end
          flag = _f515d7f8 if flag.nil? || _f515d7f8 > flag
        end
        flag
      end
      def arc_candidates(arr2)
        num = (1...(arr2.length - 1)).filter_map do |idx|
          sample_tol_mm = circle_at(arr2[idx - 1], arr2[idx], arr2[idx + 1])
          next unless sample_tol_mm && sample_tol_mm[:radius_mm] >= 0.01 && sample_tol_mm[:radius_mm] <= 1.0e7
          next unless sample_tol_mm[:max_step_deg] <= 45.0
          sample_tol_mm.merge!(index: idx)
        end
        runs = num.slice_when do |arr3, arr4|
          arr4[:index] != arr3[:index] + 1 || arr3[:turn] != arr4[:turn] ||
            Calc.distance(arr3[:center_mm], arr4[:center_mm]) > 0.01 ||
            (arr3[:radius_mm] - arr4[:radius_mm]).abs > 0.01
        end.filter_map { |_124c7bd3| fit_arc_run(_124c7bd3, arr2) }
        runs.sort_by { |arr| [-arr[:point_count], arr[:start_index]] }.each_with_object([]) do |start2, arr5|
          next if arr5.any? { |arr| [start2[:start_index], arr[:start_index]].max < [start2[:end_index], arr[:end_index]].min }
          arr5 << start2
        end.sort_by { |arr| arr[:start_index] }
      end
      def circle_at(arr, b, arr2)
        num, _ee4f533e, _4c8d9d44 = Calc.circumcircle_terms(arr, b, arr2)
        return nil if num.abs <= 1.0e-10
        r = Math.hypot(arr[0] - _ee4f533e, arr[1] - _4c8d9d44)
        return nil unless r.finite? && r.positive?
        cross = (b[0] - arr[0]) * (arr2[1] - b[1]) - (b[1] - arr[1]) * (arr2[0] - b[0])
        return nil if cross.abs <= 1.0e-12
        center = [_ee4f533e, _4c8d9d44]
        _5d951b22 = [Calc.angle_between(arr, b, center), Calc.angle_between(b, arr2, center)].max
        { center_mm: center, radius_mm: r, turn: cross.positive? ? 1 : -1, max_step_deg: _5d951b22 * 180.0 / Math::PI }
      end
      def fit_arc_run(arr, out)
        return nil if arr.length < 3
        _79596bdd = arr.first[:index] - 1
        end_index = arr.last[:index] + 1
        arr2 = out[_79596bdd..end_index]
        arr3 = fit_circle_lsq(arr2)
        return nil unless arr3 && arr3[:max_radial_mm] <= 0.005
        center, r = arr3.values_at(:center_mm, :radius_mm)
        num2 = arr.first[:turn]
        num = total_sweep(arr2, center, num2).abs * 180.0 / Math::PI
        return nil unless num >= 5.0 && num <= 355.0
        bulge = arr2.each_cons(2).map { |a, b| r * (1.0 - Math.cos(Calc.angle_between(a, b, center) * 0.5)) }.max
        return nil if bulge < 0.001
        return nil if arr.any? { |arr4| Calc.distance(arr4[:center_mm], center) > 0.01 }
        return nil if arr.any? { |arr4| (arr4[:radius_mm] - r).abs > 0.01 }
        { start_index: _79596bdd, end_index: end_index, point_count: arr2.length, center_mm: center,
          radius_mm: r, clockwise: num2.negative?, sweep_deg: num, max_radial_mm: arr3[:max_radial_mm],
          max_bulge_mm: bulge }
      end
      def rebuild_elements(arr, runs)
        arr2 = runs.to_h { |start2| [start2[:start_index], start2] }
        elems = []
        edge = 0
        while edge < arr.length - 1
          start2 = arr2[edge]
          if start2
            elems << {
              type: :arc, s: arr[start2[:start_index]].dup, e: arr[start2[:end_index]].dup, c: start2[:center_mm].dup,
              ccw: !start2[:clockwise], full_circle: false, radius_mm: start2[:radius_mm], src_start: start2[:start_index],
              src_end: start2[:end_index], src_point_count: start2[:point_count], radial_mm: start2[:max_radial_mm],
              bulge_mm: start2[:max_bulge_mm], sweep_deg: start2[:sweep_deg]
            }
            edge = start2[:end_index]
          else
            elems << { type: :line, s: arr[edge].dup, e: arr[edge + 1].dup }
            edge += 1
          end
        end
        elems
      end
      def arc_segment(elems)
        result = []
        elems.each do |arr|
          last_rect = result.last
          if last_rect && last_rect[:type] == :line && arr[:type] == :line &&
             arc_direction(last_rect[:s], last_rect[:e], arr[:e]) && Calc.distance(last_rect[:e], arr[:s]) <= GAPLESS_MM
            last_rect[:e] = arr[:e]
          else
            result << arr
          end
        end
        row0 = result.first
        last_rect = result.last
        if result.length > 2 && row0[:type] == :line && last_rect[:type] == :line &&
           Calc.distance(last_rect[:e], row0[:s]) <= GAPLESS_MM && arc_direction(last_rect[:s], last_rect[:e], row0[:e])
          row0[:s] = last_rect[:s]
          result.pop
        end
        result
      end
      def arc_direction(arr, b, arr2)
        _ef672dce = b[0] - arr[0]
        _73792f97 = b[1] - arr[1]
        _6fff5dd9 = arr2[0] - b[0]
        _515aedb8 = arr2[1] - b[1]
        _dd077b4f = Math.hypot(_ef672dce, _73792f97)
        _faea421b = Math.hypot(_6fff5dd9, _515aedb8)
        return false if _dd077b4f <= GEOM_EPS_MM || _faea421b <= GEOM_EPS_MM
        (_ef672dce * _515aedb8 - _73792f97 * _6fff5dd9).abs / _dd077b4f <= 0.001 && (_ef672dce * _6fff5dd9 + _73792f97 * _515aedb8).positive?
      end
      def sample_metric(out)
        return out if out.length <= METRIC_SAMPLES
        (0...METRIC_SAMPLES).map { |idx| out[(idx.to_f * (out.length - 1) / (METRIC_SAMPLES - 1)).round] }
      end
      def fit_circle_lsq(out)
        arr2 = Calc.kahan_sum(out.map { |pt| pt[0] }) / out.length.to_f
        arr3 = Calc.kahan_sum(out.map { |pt| pt[1] }) / out.length.to_f
        _fe08b049 = _4505ccb0 = _14e64bd7 = _4b5b1dd9 = _c8a69433 = 0.0
        out.each do |pt|
          x = pt[0] - arr2
          y = pt[1] - arr3
          z = x * x + y * y
          _fe08b049 += x * x
          _4505ccb0 += y * y
          _14e64bd7 += x * y
          _4b5b1dd9 += x * z
          _c8a69433 += y * z
        end
        num2 = _fe08b049 * _4505ccb0 - _14e64bd7 * _14e64bd7
        return nil if num2.abs <= 1.0e-12
        num3 = 0.5 * (_4b5b1dd9 * _4505ccb0 - _c8a69433 * _14e64bd7) / num2
        num4 = 0.5 * (_c8a69433 * _fe08b049 - _4b5b1dd9 * _14e64bd7) / num2
        center = [arr2 + num3, arr3 + num4]
        arr = out.map { |pt| Calc.distance(pt, center) }.sort
        num = arr.length / 2
        r = arr.length.odd? ? arr[num] : (arr[num - 1] + arr[num]) * 0.5
        return nil unless r >= 0.01 && r <= 1.0e7
        { center_mm: center, radius_mm: r, max_radial_mm: arr.map { |val| (val - r).abs }.max }
      end
      def total_sweep(out, center, num)
        total = 0.0
        out.map { |pt| Calc.deg4(pt, center) }.each_cons(2) do |row0, last_rect|
          delta = last_rect - row0
          if num.positive?
            delta += 2.0 * Math::PI while delta < 0.0
            delta -= 2.0 * Math::PI while delta > 2.0 * Math::PI
          else
            delta -= 2.0 * Math::PI while delta > 0.0
            delta += 2.0 * Math::PI while delta < -2.0 * Math::PI
          end
          return 0.0 if delta.abs > 45.0 * Math::PI / 180.0 + 1.0e-8
          total += delta
        end
        total
      end
      def failure(set_status)
        { status: set_status }
      end
    end
  end
end
