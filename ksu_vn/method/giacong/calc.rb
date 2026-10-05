module KSU
  module Cnc
    module Calc
      NATIVE = defined?(::KSU::Cnc::Native.boundary_error) ? true : false
      NATIVE_EXT = NATIVE && ::KSU::Cnc::Native.respond_to?(:rescue_drift)
      module_function
      def distance(arr, b)
        Math.hypot(arr[0].to_f - b[0].to_f, arr[1].to_f - b[1].to_f)
      end
      def deg4(pt, center)
        Math.atan2(pt[1].to_f - center[1].to_f, pt[0].to_f - center[0].to_f)
      end
      def cross(arr, arr2, b)
        ((arr2[0] - arr[0]) * (b[1] - arr[1])) - ((arr2[1] - arr[1]) * (b[0] - arr[0]))
      end
      def lerp(arr, b, t)
        [arr[0] + (b[0] - arr[0]) * t, arr[1] + (b[1] - arr[1]) * t]
      end
      def unit_vector(arr, b)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        length = Math.hypot(dx, dy)
        [dx / length, dy / length]
      end
      def sweep_between(a, b, ccw)
        delta = (b - a) % (Math::PI * 2.0)
        ccw ? delta : (delta.zero? ? 0.0 : delta - Math::PI * 2.0)
      end
      def wrap_pi(delta)
        delta -= 2.0 * Math::PI while delta > Math::PI
        delta += 2.0 * Math::PI while delta < -Math::PI
        delta
      end
      def normalize_sweep(delta, ccw)
        delta += Math::PI * 2.0 while ccw && delta <= 0.0
        delta -= Math::PI * 2.0 while !ccw && delta >= 0.0
        delta
      end
      def subtended_angle(a, b, center)
        delta = (deg4(b, center) - deg4(a, center)).abs
        delta > Math::PI ? 2.0 * Math::PI - delta : delta
      end
      def corner_angle_deg(arr, b, arr2, eps)
        x1 = b[0] - arr[0]
        y1 = b[1] - arr[1]
        x2 = arr2[0] - b[0]
        y2 = arr2[1] - b[1]
        _58f95f3b = Math.hypot(x1, y1)
        _3c77079d = Math.hypot(x2, y2)
        return 0.0 if _58f95f3b <= eps || _3c77079d <= eps
        Math.acos(((x1 * x2 + y1 * y2) / (_58f95f3b * _3c77079d)).clamp(-1.0, 1.0)) * 180.0 / Math::PI
      end
      def corner_dir(corner)
        num = 1.0 / Math.sqrt(2.0)
        { "bottom_right" => [num, -num], "top_right" => [num, num],
          "top_left" => [-num, num], "bottom_left" => [-num, -num] }[corner.to_s]
      end
      def pt(val)
        arr = Array(val)
        raise ArgumentError, "point_missing_xy" if arr.length < 2
        x = Float(arr[0])
        y = Float(arr[1])
        raise ArgumentError, "point_not_finite" unless x.finite? && y.finite?
        [x, y]
      end
      def positive_float(val)
        number = Float(val)
        number.finite? && number.positive? ? number : nil
      rescue StandardError
        nil
      end
      def round2(num)
        (num.to_f * 100.0).round / 100.0
      end
      def round_to(val, digits)
        format("%.#{digits}f", val).to_f
      end
      def kahan_sum(vars)
        rows = vars.to_a
        idx = rows.index { |num2| !num2.is_a?(Integer) }
        return rows.inject(0, :+) unless idx
        acc2 = rows.first(idx).inject(0, :+).to_f
        num3 = 0.0
        rows.drop(idx).each do |num2|
          num = num2.to_f
          next if acc2.nan?
          unless num.finite?
            flag = num.infinite? && acc2.infinite?
            acc2 = flag && (num.negative? != acc2.negative?) ? Float::NAN : num
            next
          end
          next if acc2.infinite?
          _5d951b22 = acc2 + num
          num3 += acc2.abs >= num.abs ? ((acc2 - _5d951b22) + num) : ((num - _5d951b22) + acc2)
          acc2 = _5d951b22
        end
        acc2 + num3
      end
      def dedupe_loop(out, tol, flag = false)
        rows = NATIVE ? Native.dedupe_loop(out, tol) : nil
        return rows if rows
        rows = []
        Array(out).each do |pt|
          next if flag && !(pt.respond_to?(:[]) && pt[0].is_a?(Numeric) && pt[1].is_a?(Numeric))
          _d3fb9c5b = [pt[0].to_f, pt[1].to_f]
          next unless _d3fb9c5b[0].finite? && _d3fb9c5b[1].finite?
          rows << _d3fb9c5b if rows.empty? || distance(rows.last, _d3fb9c5b) > tol
        end
        rows.pop while rows.length > 1 && distance(rows.first, rows.last) <= tol
        rows
      end
      def signed_area(out)
        flag = NATIVE ? Native.signed_area(out) : nil
        return flag if flag
        rows = Array(out)
        return 0.0 if rows.length < 3
        kahan_sum(rows.each_with_index.map { |arr, idx|
          b = rows[(idx + 1) % rows.length]
          (arr[0] * b[1]) - (b[0] * arr[1])
        }) * 0.5
      end
      def shoelace_area(out)
        return 0.0 if out.length < 3
        total = 0.0
        out.each_with_index do |arr, idx|
          b = out[(idx + 1) % out.length]
          total += (arr[0] * b[1]) - (b[0] * arr[1])
        end
        total * 0.5
      end
      def arc_sweep(arr)
        return arr[:ccw] ? Math::PI * 2.0 : -(Math::PI * 2.0) if arr[:full_circle]
        center = arr[:c]
        sweep_between(deg4(arr[:s], center), deg4(arr[:e], center), arr[:ccw])
      end
      def path_area(elems)
        kahan_sum(elems.map { |arr|
          s = arr[:s]
          arr2 = arr[:e]
          next 0.5 * (s[0] * arr2[1] - arr2[0] * s[1]) unless arr[:type] == :arc
          arr3 = arr[:c]
          r = distance(s, arr3)
          0.5 * (arr3[0] * (arr2[1] - s[1]) - arr3[1] * (arr2[0] - s[0]) + r * r * arc_sweep(arr))
        })
      end
      def tangent_at(arr4, at, eps = 1.0e-9)
        s, arr3, arr5 = arr4.values_at(:s, :e, :c)
        arr2 = if arr4[:type] == :line
                   [arr3[0] - s[0], arr3[1] - s[1]]
                 else
                   pt = at == :start ? s : arr3
                   arr = [pt[0] - arr5[0], pt[1] - arr5[1]]
                   arr4[:ccw] ? [-arr[1], arr[0]] : [arr[1], -arr[0]]
                 end
        length = Math.hypot(arr2[0], arr2[1])
        [arr2[0] / length, arr2[1] / length] unless length <= eps
      end
      def project_to_radius(center, boundary, r, eps = 1.0e-12)
        dx = boundary[0] - center[0]
        dy = boundary[1] - center[1]
        length = Math.hypot(dx, dy)
        [center[0] + dx * r / length, center[1] + dy * r / length] unless length <= eps
      end
      def arc_points(center, r, a0, sweep, steps)
        (0..steps).map do |idx|
          num = a0 + sweep * idx.to_f / steps
          [center[0] + Math.cos(num) * r, center[1] + Math.sin(num) * r]
        end
      end
      def arc_polyline(center, arr, b, r, num2)
        a0 = Math.atan2(arr[1] - center[1], arr[0] - center[0])
        delta = normalize_sweep(Math.atan2(b[1] - center[1], b[0] - center[0]) - a0, num2.positive?)
        tol = [0.01, r * 0.05].min
        num = 2.0 * Math.acos([[1.0 - (tol / [r, 0.000001].max), -1.0].max, 1.0].min)
        num = Math::PI / 18.0 unless num.finite? && num.positive?
        num = [num, Math::PI / 12.0].min
        arc_points(center, r, a0, delta, [(delta.abs / num).ceil, 1].max)
      end
      def circle_polyline(center, r, start, cw)
        num = 2.0 * Math.acos([[1.0 - (0.01 / r), -1.0].max, 1.0].min)
        num = Math::PI / 36.0 unless num.finite? && num.positive?
        segments = [[(((2.0 * Math::PI / num).ceil + 7) / 8) * 8, 24].max, 720].min
        a0 = deg4(start, center)
        (0...segments).map do |idx|
          flag = a0 + 2.0 * Math::PI * (cw ? -idx : idx) / segments
          [center[0] + Math.cos(flag) * r, center[1] + Math.sin(flag) * r]
        end
      end
      def flatten_path(elems, chord_tol_mm:)
        result = []
        last_rect = nil
        elems.each do |arr|
          out = arr[:type] == :arc ? arc_to_points(arr, chord_tol_mm) : [pt(arr[:s]), pt(arr[:e])]
          out.each do |row|
            result << (last_rect = row) unless last_rect && distance(last_rect, row) <= 1.0e-9
          end
        end
        result
      end
      def arc_to_points(arr, tol)
        s = pt(arr[:s])
        e = pt(arr[:e])
        c = pt(arr[:c])
        _ddfbd967 = arr[:full_circle]
        r = distance(s, c)
        raise ArgumentError, "bad_arc_radius" unless r.finite? && r.positive?
        a0 = deg4(s, c)
        sweep = arr[:ccw] ? Math::PI * 2.0 : -(Math::PI * 2.0)
        sweep = sweep_between(a0, deg4(e, c), arr[:ccw]) unless _ddfbd967
        raise ArgumentError, "zero_sweep" if sweep.abs <= 1.0e-12
        flag = tol < r ? 2.0 * Math.acos(1.0 - tol / r) : 0.0
        flag = Math::PI / 180.0 unless flag.finite? && flag > 1.0e-8
        steps = [(sweep.abs / [flag, Math::PI / 4.0].min).ceil, _ddfbd967 ? 24 : 1].max
        rows = arc_points(c, r, a0, sweep, [steps, 4096].min)
        rows[-1] = _ddfbd967 ? rows.first.dup : e
        rows
      end
      def flatten_loop(elems, tol)
        result = []
        last_rect = nil
        elems.each do |arr|
          axis = arr[:type] == :line
          out = axis ? [arr[:s], arr[:e]] : arc_segment_points(arr, tol)
          out.each do |h|
            result << (last_rect = axis ? h.dup : h) unless last_rect && distance(last_rect, h) <= 1.0e-9
          end
        end
        result << result.first.dup if last_rect && distance(result.first, last_rect) > 1.0e-9
        result
      end
      def arc_segment_points(arr, tol)
        s = arr[:s]
        c = arr[:c]
        r = distance(s, c)
        a0 = deg4(s, c)
        sweep = arc_sweep(arr)
        flag = Math::PI / 180.0
        if r.finite? && r.positive?
          chord = 2.0 * Math.acos([[1.0 - tol / r, -1.0].max, 1.0].min)
          flag = [chord.finite? && chord > 1.0e-8 ? chord : flag, Math::PI / 4.0].min
        end
        rows = arc_points(c, r, a0, sweep, [[(sweep.abs / flag).ceil, 1].max, 4096].min)
        rows[-1] = arr[:full_circle] ? rows.first.dup : arr[:e].dup
        rows
      end
      def param_on_segment(arr, b, pt, eps)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        _6592aad8 = dx * dx + dy * dy
        ((pt[0] - arr[0]) * dx + (pt[1] - arr[1]) * dy) / _6592aad8 unless _6592aad8 <= eps
      end
      def project_on_line(pt, arr, b, eps = 1.0e-18)
        t = param_on_segment(arr, b, pt, eps)
        [arr[0] + ((b[0] - arr[0]) * t), arr[1] + ((b[1] - arr[1]) * t)] if t
      end
      def distance_to_line(pt, a, b)
        distance(pt, project_on_line(pt, a, b))
      end
      def along_axis(arr, b, arr2, center)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        length = Math.hypot(dx, dy)
        (((arr2[0] - center[0]) * (dx / length)) + ((arr2[1] - center[1]) * (dy / length))).abs
      end
      def line_intersection(arr, b, arr2, len2d, eps)
        ax = b[0] - arr[0]
        ay = b[1] - arr[1]
        bx2 = len2d[0] - arr2[0]
        by2 = len2d[1] - arr2[1]
        num = (ax * by2) - (ay * bx2)
        return nil if num.abs <= eps
        t = (((arr2[0] - arr[0]) * by2) - ((arr2[1] - arr[1]) * bx2)) / num
        [arr[0] + ax * t, arr[1] + ay * t]
      end
      def line_cross(a, b, c, len2d)
        (x1, y1), (x2, y2), (bx1, by1), (bx2, by2) = a, b, c, len2d
        num = (x1 - x2) * (by1 - by2) - (y1 - y2) * (bx1 - bx2)
        return nil if num.abs < 0.000001
        _8c66a8e7 = x1 * y2 - y1 * x2
        _427f792d = bx1 * by2 - by1 * bx2
        [(_8c66a8e7 * (bx1 - bx2) - (x1 - x2) * _427f792d) / num, (_8c66a8e7 * (by1 - by2) - (y1 - y2) * _427f792d) / num]
      end
      def segment_circle_hits(arr, b, center, r)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        _54ef9f0f = dx * dx + dy * dy
        return [] if _54ef9f0f <= Arc::HIT_EPS_MM
        _17232881 = -((arr[0] - center[0]) * dx + (arr[1] - center[1]) * dy) / _54ef9f0f
        arr2 = [arr[0] + _17232881 * dx, arr[1] + _17232881 * dy]
        dist = Math.hypot(arr2[0] - center[0], arr2[1] - center[1])
        gap2 = dist - r
        return [arr2] if gap2.abs <= Arc::JOIN_TOL_MM
        return [] if gap2 > 0.0
        _563faae7 = Math.sqrt(r * r - dist * dist) / Math.sqrt(_54ef9f0f)
        [_17232881 - _563faae7, _17232881 + _563faae7].uniq.map { |t| [arr[0] + t * dx, arr[1] + t * dy] }
      end
      def ray_circle_hits(arr, b, center, r)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        sx = arr[0] - center[0]
        sy = arr[1] - center[1]
        _bf31ee79 = (dx * dx) + (dy * dy)
        return [] unless _bf31ee79 > 1.0e-18
        num = 2.0 * ((sx * dx) + (sy * dy))
        _29aa55a8 = (sx * sx) + (sy * sy) - (r * r)
        num2 = (num * num) - (4.0 * _bf31ee79 * _29aa55a8)
        return [] if num2 < -1.0e-10
        nesting = Math.sqrt(num2.negative? ? 0.0 : num2)
        [(-num - nesting) / (2.0 * _bf31ee79), (-num + nesting) / (2.0 * _bf31ee79)].uniq.map { |t| [arr[0] + (dx * t), arr[1] + (dy * t)] }
      end
      def circle_circle_hits(arr, _c51da9df, arr2, _bdfbe328)
        dx = arr2[0] - arr[0]
        dy = arr2[1] - arr[1]
        len2d = Math.hypot(dx, dy)
        eps = Arc::HIT_EPS_MM
        return [] if len2d <= eps || len2d > _c51da9df + _bdfbe328 + eps || len2d < (_c51da9df - _bdfbe328).abs - eps
        a = (_c51da9df * _c51da9df - _bdfbe328 * _bdfbe328 + len2d * len2d) / (2.0 * len2d)
        num = _c51da9df * _c51da9df - a * a
        return [] if num < -eps
        num = 0.0 if num.abs <= eps
        elem = Math.sqrt(num)
        trai = arr[0] + a * dx / len2d
        duoi = arr[1] + a * dy / len2d
        _78dcb2bf = -dy * elem / len2d
        _9ff9e93b = dx * elem / len2d
        hit = [trai + _78dcb2bf, duoi + _9ff9e93b]
        elem > eps ? [hit, [trai - _78dcb2bf, duoi - _9ff9e93b]] : [hit]
      end
      def segment_overlap(arr, b, arr2, len2d)
        _78dcb2bf = b[0] - arr[0]
        _9ff9e93b = b[1] - arr[1]
        start_x = len2d[0] - arr2[0]
        ly0 = len2d[1] - arr2[1]
        num = _78dcb2bf * ly0 - _9ff9e93b * start_x
        bx3 = arr2[0] - arr[0]
        by3 = arr2[1] - arr[1]
        eps = 1.0e-9
        if num.abs > eps
          t = (bx3 * ly0 - by3 * start_x) / num
          u = (bx3 * _9ff9e93b - by3 * _78dcb2bf) / num
          return [] unless t >= -eps && t <= 1.0 + eps && u >= -eps && u <= 1.0 + eps
          return [{ t: t, u: u }]
        end
        return [] if (bx3 * _9ff9e93b - by3 * _78dcb2bf).abs > eps
        _f515d7f8 = Export::NODE_TOLERANCE_MM * 2.0
        _3c525a3d = [[arr, 0.0, nil], [b, 1.0, nil], [arr2, nil, 0.0], [len2d, nil, 1.0]]
        rows = _3c525a3d.filter_map do |pt, t, u|
          next unless segment_distance(pt, arr, b) <= _f515d7f8 && segment_distance(pt, arr2, len2d) <= _f515d7f8
          { t: t || param_on_segment(arr, b, pt, 1.0e-12) || 0.0, u: u || param_on_segment(arr2, len2d, pt, 1.0e-12) || 0.0 }
        end
        rows.uniq { |arr3| [(arr3[:t] * 1_000_000_000).round, (arr3[:u] * 1_000_000_000).round] }
      end
      def segment_hit_params(a, b, c, len2d)
        (ax, ay), (bx2, by2), (px, py), (dx, dy) = a, b, c, len2d
        _78dcb2bf = bx2 - ax
        _9ff9e93b = by2 - ay
        start_x = dx - px
        ly0 = dy - py
        num = (_78dcb2bf * ly0) - (_9ff9e93b * start_x)
        _568a55ba = px - ax
        _57277a24 = py - ay
        eps = 1.0e-10
        if num.abs > eps
          t = ((_568a55ba * ly0) - (_57277a24 * start_x)) / num
          u = ((_568a55ba * _9ff9e93b) - (_57277a24 * _78dcb2bf)) / num
          return [] unless t >= -eps && t <= 1.0 + eps && u >= -eps && u <= 1.0 + eps
          return [[[t, 0.0].max, 1.0].min]
        end
        return [] if ((_568a55ba * _9ff9e93b) - (_57277a24 * _78dcb2bf)).abs > eps
        _0944c678 = (_78dcb2bf * _78dcb2bf) + (_9ff9e93b * _9ff9e93b)
        return Math.hypot(ax - px, ay - py) <= eps ? [0.0] : [] if _0944c678 <= eps
        _fe479353, _aae2b052 = [((px - ax) * _78dcb2bf + (py - ay) * _9ff9e93b) / _0944c678, ((dx - ax) * _78dcb2bf + (dy - ay) * _9ff9e93b) / _0944c678].minmax
        _fe479353 = [_fe479353, 0.0].max
        _aae2b052 = [_aae2b052, 1.0].min
        return [] if _aae2b052 < _fe479353 - eps
        (_aae2b052 - _fe479353).abs <= eps ? [_fe479353] : [_fe479353, _aae2b052]
      end
      def proper_crossing(a, b, c, len2d)
        tol = Polygon::TOLERANCE_MM
        return nil if distance(a, c) <= tol || distance(a, len2d) <= tol || distance(b, c) <= tol || distance(b, len2d) <= tol
        (x1, y1), (x2, y2), (bx1, by1), (bx2, by2) = a, b, c, len2d
        num = ((x1 - x2) * (by1 - by2)) - ((y1 - y2) * (bx1 - bx2))
        return nil if num.abs <= 1.0e-12
        t = (((x1 - bx1) * (by1 - by2)) - ((y1 - by1) * (bx1 - bx2))) / num
        u = -(((x1 - x2) * (y1 - by1)) - ((y1 - y2) * (x1 - bx1))) / num
        _84c2185b = [tol / [distance(a, b), tol].max, 1.0e-9].max
        arr = [tol / [distance(c, len2d), tol].max, 1.0e-9].max
        return nil unless t > _84c2185b && t < 1.0 - _84c2185b && u > arr && u < 1.0 - arr
        [x1 + ((x2 - x1) * t), y1 + ((y2 - y1) * t)]
      end
      def segments_cross?(arr, b, arr2, len2d)
        px = arr2[0]
        py = arr2[1]
        _ee4f533e = len2d[0] - px
        _4c8d9d44 = len2d[1] - py
        side = ((_ee4f533e * (arr[1] - py)) - (_4c8d9d44 * (arr[0] - px))) > 0
        return false if side == (((_ee4f533e * (b[1] - py)) - (_4c8d9d44 * (b[0] - px))) > 0)
        ax = arr[0]
        ay = arr[1]
        _fbf0cf8d = b[0] - ax
        _7e1c7e1d = b[1] - ay
        side = ((_fbf0cf8d * (py - ay)) - (_7e1c7e1d * (px - ax))) > 0
        side != (((_fbf0cf8d * (len2d[1] - ay)) - (_7e1c7e1d * (len2d[0] - ax))) > 0)
      end
      def segments_properly_cross?(a, b, c, len2d)
        _f8be1476 = cross(a, b, c)
        _4a43487d = cross(a, b, len2d)
        _4a6708a1 = cross(c, len2d, a)
        _8e2655fb = cross(c, len2d, b)
        eps = 1.0e-10
        (_f8be1476 > eps && _4a43487d < -eps || _f8be1476 < -eps && _4a43487d > eps) && (_4a6708a1 > eps && _8e2655fb < -eps || _4a6708a1 < -eps && _8e2655fb > eps)
      end
      def collinear_within?(a, b, c)
        (ax, ay), (bx2, by2), (px, py) = a, b, c
        dx = px - ax
        dy = py - ay
        _0944c678 = (dx * dx) + (dy * dy)
        return false if _0944c678 < 1.0e-9
        return false if (((bx2 - ax) * dy) - ((by2 - ay) * dx)).abs / Math.sqrt(_0944c678) > 0.01
        dot = ((bx2 - ax) * dx) + ((by2 - ay) * dy)
        dot >= -1.0e-6 && dot <= _0944c678 + 1.0e-6
      end
      def circumcircle_terms(a, b, c)
        (ax, ay), (bx2, by2), (px, py) = a, b, c
        num = 2.0 * (ax * (by2 - py) + bx2 * (py - ay) + px * (ay - by2))
        a2 = ax * ax + ay * ay
        b2 = bx2 * bx2 + by2 * by2
        _feb3e0b1 = px * px + py * py
        [num, (a2 * (by2 - py) + b2 * (py - ay) + _feb3e0b1 * (ay - by2)) / num, (a2 * (px - bx2) + b2 * (ax - px) + _feb3e0b1 * (bx2 - ax)) / num]
      end
      def circumcircle(a, b, c)
        num, _ee4f533e, _4c8d9d44 = circumcircle_terms(a, b, c)
        upm = [distance(a, b), distance(b, c), distance(a, c), 1.0].max
        return nil if num.abs <= 1.0e-10 * upm * upm
        r = distance([_ee4f533e, _4c8d9d44], a)
        { center: [_ee4f533e, _4c8d9d44], radius: r } if r.positive? && r <= 1_000_000.0
      end
      def circle_through(arr, b, c, eps = 1.0e-9)
        num, _ee4f533e, _4c8d9d44 = circumcircle_terms(arr, b, c)
        return nil if num.abs < eps
        half = Math.hypot(arr[0] - _ee4f533e, arr[1] - _4c8d9d44)
        { center: [_ee4f533e, _4c8d9d44], radius: half } if half.finite? && half.positive?
      end
      def fit_circle(rows)
        arr = Array.new(8, 0.0)
        rows.each do |x, y|
          z = -(x * x + y * y)
          [x, y, x * x, y * y, x * y, x * z, y * z, z].each_with_index { |val, idx| arr[idx] += val }
        end
        start_x, ly0, _fe08b049, _4505ccb0, _14e64bd7, _4b5b1dd9, _c8a69433, _be3d46c9 = arr
        a = [[_fe08b049, _14e64bd7, start_x, _4b5b1dd9], [_14e64bd7, _4505ccb0, ly0, _c8a69433], [start_x, ly0, rows.length.to_f, _be3d46c9]]
        3.times do |_10931e94|
          num = (_10931e94...3).max_by { |row| a[row][_10931e94].abs }
          return nil if a[num][_10931e94].abs <= 1.0e-12
          a[_10931e94], a[num] = a[num], a[_10931e94] if num != _10931e94
          _dc0ffeca = a[_10931e94][_10931e94]
          (_10931e94...4).each { |idx| a[_10931e94][idx] /= _dc0ffeca }
          3.times do |row|
            next if row == _10931e94
            factor = a[row][_10931e94]
            (_10931e94...4).each { |idx| a[row][idx] -= factor * a[_10931e94][idx] }
          end
        end
        px = -a[0][3] * 0.5
        py = -a[1][3] * 0.5
        _62922f60 = px * px + py * py - a[2][3]
        { center: [px, py], radius: Math.sqrt(_62922f60) } if _62922f60.finite? && _62922f60 > 0.0
      end
      def chord_normal_point(arr, b, arr2)
        _fa4482a3 = b[0] - arr[0]
        _db5cf9ab = b[1] - arr[1]
        chord = Math.hypot(_fa4482a3, _db5cf9ab)
        return nil if chord <= 1.0e-9
        _12a9205b = (arr[0] + b[0]) * 0.5
        _619826f2 = (arr[1] + b[1]) * 0.5
        _5869632a = -_db5cf9ab / chord
        _785c570a = _fa4482a3 / chord
        offset_path = ((arr2[0] - _12a9205b) * _5869632a) + ((arr2[1] - _619826f2) * _785c570a)
        [_12a9205b + (offset_path * _5869632a), _619826f2 + (offset_path * _785c570a)] if offset_path.finite?
      end
      def arc_length_to(start, pt, center, r, cw)
        delta = wrap_pi(deg4(pt, center) - deg4(start, center))
        delta -= 2.0 * Math::PI if cw && delta.positive?
        delta += 2.0 * Math::PI if !cw && delta.negative?
        r * delta.abs
      end
      def point_segment_distance(pt, arr, b, eps = 1.0e-18)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        _0944c678 = (dx * dx) + (dy * dy)
        return distance(pt, arr) if _0944c678 <= eps
        t = (((pt[0] - arr[0]) * dx) + ((pt[1] - arr[1]) * dy)) / _0944c678
        t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t)
        Math.hypot(pt[0] - (arr[0] + (dx * t)), pt[1] - (arr[1] + (dy * t)))
      end
      def segment_distance(pt, arr, b)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        _0944c678 = (dx * dx) + (dy * dy)
        return Math.hypot(pt[0] - arr[0], pt[1] - arr[1]) if _0944c678 < 1.0e-12
        t = (((pt[0] - arr[0]) * dx) + ((pt[1] - arr[1]) * dy)) / _0944c678
        t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t)
        Math.hypot(pt[0] - (arr[0] + (t * dx)), pt[1] - (arr[1] + (t * dy)))
      end
      def pack_segment(arr, b)
        dx = b[0] - arr[0]
        dy = b[1] - arr[1]
        [arr[0], arr[1], dx, dy, (dx * dx) + (dy * dy)]
      end
      def packed_distance(trai, duoi, packed)
        ax, ay, dx, dy, _0944c678 = packed
        return Math.hypot(trai - ax, duoi - ay) if _0944c678 < 1.0e-12
        t = (((trai - ax) * dx) + ((duoi - ay) * dy)) / _0944c678
        t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t)
        Math.hypot(trai - (ax + (t * dx)), duoi - (ay + (t * dy)))
      end
      def contour_distance(pt, arr)
        flag = NATIVE ? Native.contour_distance(pt, arr) : nil
        return flag if flag
        (0...arr.length - 1).map { |i| segment_distance(pt, arr[i], arr[i + 1]) }.min || Float::INFINITY
      end
      def polygon_distance(pt, polygon)
        flag = NATIVE ? Native.polygon_distance(pt, polygon) : nil
        return flag if flag
        return 0.0 if polygon.length < 2
        polygon.each_with_index.map { |a, i| segment_distance(pt, a, polygon[(i + 1) % polygon.length]) }.min
      end
      def polyline_distance(pt, arr)
        lo = Float::INFINITY
        arr.each_cons(2) do |a, b|
          val = point_segment_distance(pt, a, b)
          lo = val if val < lo
        end
        lo
      end
      def segment_gap(a, b, c, len2d)
        return 0.0 unless segment_overlap(a, b, c, len2d).empty?
        [segment_distance(a, c, len2d), segment_distance(b, c, len2d),
         segment_distance(c, a, b), segment_distance(len2d, a, b)].min
      end
      def mean_distance(rows, pt)
        total = 0.0
        rows.each { |arr| total += Math.hypot(arr[0] - pt[0], arr[1] - pt[1]) }
        total / rows.length
      end
      def pack_element(arr)
        s = arr[:s]
        e = arr[:e]
        return [false, s, e] if arr[:type] == :line
        c = arr[:c]
        ccw = arr[:ccw]
        a0 = deg4(s, c)
        _ba9e6b99 = deg4(e, c)
        sweep = (ccw ? _ba9e6b99 - a0 : a0 - _ba9e6b99) % (Math::PI * 2.0)
        [true, s, e, c, distance(s, c), arr[:full_circle], ccw, a0, sweep + 1.0e-9]
      end
      def element_distance(pt, packed)
        arc, s, e, arr, r, world_tr, ccw, a0, per_row = packed
        return point_segment_distance(pt, s, e) unless arc
        _78dcb2bf = pt[0] - arr[0]
        _9ff9e93b = pt[1] - arr[1]
        length = Math.hypot(_78dcb2bf, _9ff9e93b)
        if length > 1.0e-12
          return (length - r).abs if world_tr
          trai = arr[0] + _78dcb2bf * r / length
          duoi = arr[1] + _9ff9e93b * r / length
          num = Math.atan2(duoi - arr[1].to_f, trai - arr[0].to_f)
          delta = (ccw ? num - a0 : a0 - num) % (Math::PI * 2.0)
          return (length - r).abs if delta <= per_row
        end
        [distance(pt, s), distance(pt, e)].min
      end
      def arc_distance(pt, arr)
        center = arr[:c]
        total = arc_sweep(arr)
        packed = sweep_between(deg4(arr[:s], center), deg4(pt, center), arr[:ccw])
        inside = arr[:ccw] ? packed >= -1.0e-9 && packed <= total + 1.0e-9 : packed <= 1.0e-9 && packed >= total - 1.0e-9
        return [distance(pt, arr[:s]), distance(pt, arr[:e])].min unless inside
        (distance(pt, center) - distance(arr[:s], center)).abs
      end
      def closest_on_line(arr2, target)
        s = arr2[:s]
        arr = arr2[:e]
        t = param_on_segment(s, arr, target, 1.0e-18)
        return nil unless t
        t = [[t, 0.0].max, 1.0].min
        point = [s[0] + (arr[0] - s[0]) * t, s[1] + (arr[1] - s[1]) * t]
        { point: point, distance: distance(point, target) }
      end
      def closest_on_arc(arr, target)
        center = arr[:c]
        r = distance(arr[:s], center)
        return nil unless r.finite? && r.positive?
        _fbf0cf8d = target[0] - center[0]
        _7e1c7e1d = target[1] - center[1]
        length = Math.hypot(_fbf0cf8d, _7e1c7e1d)
        return nil if length <= 1.0e-18
        point = [center[0] + _fbf0cf8d * r / length, center[1] + _7e1c7e1d * r / length]
        unless arr[:full_circle]
          a0 = deg4(arr[:s], center)
          total = sweep_between(a0, deg4(arr[:e], center), arr[:ccw])
          num = total.abs <= 1.0e-12 ? 0.0 : sweep_between(a0, deg4(point, center), arr[:ccw]) / total
          return nil unless num >= -1.0e-8 && num <= 1.0 + 1.0e-8
        end
        { point: point, distance: distance(point, target) }
      end
      def ray_crossing?(x, y, polygon)
        inside = false
        num = polygon.length - 1
        polygon.each_with_index do |(xi, yi), idx|
          xj, yj = polygon[num]
          inside = !inside if (yi > y) != (yj > y) && x < ((xj - xi) * (y - yi) / (yj - yi)) + xi
          num = idx
        end
        inside
      end
      def in_polygon?(x, y, polygon)
        inside = NATIVE ? Native.in_polygon(x, y, polygon) : nil
        return inside unless inside.nil?
        pt = [x, y]
        want = polygon.length
        polygon.each_index.any? { |i| segment_distance(pt, polygon[i], polygon[(i + 1) % want]) <= 0.001 } ||
          ray_crossing?(x, y, polygon)
      end
      def box_distance2(trai, duoi, screen_box)
        dx = trai < screen_box[0] ? screen_box[0] - trai : (trai > screen_box[2] ? trai - screen_box[2] : 0.0)
        dy = duoi < screen_box[1] ? screen_box[1] - duoi : (duoi > screen_box[3] ? duoi - screen_box[3] : 0.0)
        dx * dx + dy * dy
      end
      def bounds_of(out)
        lx = _2d7e228f = Float::INFINITY
        _b0566a11 = _897789b7 = -Float::INFINITY
        out.each do |pt|
          x = pt.x.to_f
          y = pt.y.to_f
          lx = x if x < lx
          _b0566a11 = x if x > _b0566a11
          _2d7e228f = y if y < _2d7e228f
          _897789b7 = y if y > _897789b7
        end
        lx.finite? ? [lx, _b0566a11, _2d7e228f, _897789b7] : [0.0, 0.0, 0.0, 0.0]
      end
      def bounds_area(out)
        screen_box = bounds_of(out)
        (screen_box[1] - screen_box[0]).abs * (screen_box[3] - screen_box[2]).abs
      end
      def bounds_equal?(arr, b, tol)
        (0..3).all? { |idx| (arr[idx] - b[idx]).abs <= tol }
      end
      def bounds_inside?(inner, outer)
        inner[0] >= outer[0] - 1.0e-6 && inner[1] <= outer[1] + 1.0e-6 &&
          inner[2] >= outer[2] - 1.0e-6 && inner[3] <= outer[3] + 1.0e-6
      end
      def bounds_same_size?(arr, b)
        (arr[1] - arr[0] - (b[1] - b[0])).abs < 1.0e-6 && (arr[3] - arr[2] - (b[3] - b[2])).abs < 1.0e-6
      end
    end
  end
end
