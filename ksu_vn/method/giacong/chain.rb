module KSU
  module Cnc
    module Export
      module_function
      def operations_for(vectors, layer_map, arr3, h, h2)
        groups = {}
        vectors.each do |vec|
          layer = vec.layer_name.to_s
          tool = arr3[layer_map[layer.strip].to_s]
          next unless tool
          arr2 = latch_tag(vec)
          str = vec.board_id.to_s
          part_id = vec.part_id.to_s
          row = (groups[[tool["id"].to_s, layer, str, part_id, arr2]] ||= {
            tool: tool.dup, layer_name: layer, board_id: str, part_id: part_id,
            board_name: vec.board_name.to_s, part_name: vec.part_name.to_s, latch_seq: nil, vectors: []
          })
          row[:vectors] << vec
          row[:latch_seq] = [row[:latch_seq], arr2[1]].compact.min if arr2 && arr2[1].positive?
        end
        groups.values.sort_by do |arr|
          layer = arr[:layer_name]
          arr4 = arr[:vectors].flat_map(&:points).map { |pt| pt.y.to_f * MM_PER_INCH }.max || 0.0
          [
            h.fetch(arr[:tool]["id"].to_s, 1_000_000), arr[:latch_seq] || 1_000_000,
            h2.fetch(layer, 1_000_000), Natural.key(layer), -arr4,
            Natural.key(arr[:board_name]), Natural.key(arr[:part_name])
          ]
        end
      end
      def nesting_depth(vectors)
        arr = vectors.select { |vec| vec.closed && vec.points.length >= 3 }
        rec = arr.to_h do |vec|
          box = Calc.bounds_of(vec.points)
          [vec, { bbox: box, area: (box[1] - box[0]).abs * (box[3] - box[2]).abs }]
        end
        str = arr.none? { |vec| vec.part_id.to_s.strip.empty? }
        groups = str ? arr.group_by { |vec| vec.part_id.to_s.strip }.values : [arr]
        h = Hash.new { |arr3, key| arr3[key] = [] }
        groups.each do |arr2|
          ordered = arr2.sort_by { |vec| rec[vec][:area] }
          ordered.each_with_index do |inner, _87f8fb65|
            a = rec[inner][:bbox]
            ordered.drop(_87f8fb65 + 1).each do |outer|
              b = rec[outer][:bbox]
              next unless str || same_part?(inner, outer)
              next if !Calc.bounds_inside?(a, b) || Calc.bounds_same_size?(a, b)
              h[inner] << outer if contains_points?(inner.points, outer.points)
            end
          end
        end
        arr.each_with_object({}) do |vec, ok|
          rows = h[vec]
          ok[vec] = { depth: rows.length, parent: rows.min_by { |path| rec[path][:area] } }
        end
      end
      def nesting_depth_all(arr5, arr4, arr7)
        vectors = arr5.each_with_index.flat_map do |rows, idx|
          rows.select { |vec| offsets?(arr4[idx][:tool], vec) }
        end
        rec = nesting_depth(vectors)
        return rec if rec.empty?
        arr2 = arr7.select { |vec| vec.closed && vec.points.length >= 3 }
        h2 = arr2.group_by { |border| border.part_id.to_s.strip }
        h2.delete('')
        arr8 = arr2.to_h { |border| [border, Calc.bounds_area(border.points)] }
        h = {}
        vectors.each do |vec|
          arr3 = h2.fetch(vec.part_id.to_s.strip, arr2).select do |border|
            inside?(vec, border) || same_outline?(vec, border)
          end
          h[vec] = arr3.min_by { |row| arr8[row] } unless arr3.empty?
        end
        h.keys.group_by { |vec| h[vec] }.each do |border, arr|
          arr6 = arr.to_h { |vec| [vec, true] }
          h3 = {}
          arr.each do |nesting|
            next if arr6[rec[nesting][:parent]] || !same_outline?(nesting, border)
            arr.each { |vec| h3[vec] = true if vec.equal?(nesting) || ancestor?(vec, nesting, rec) }
          end
          arr.each { |vec| rec[vec][:depth] += 1 unless h3[vec] }
        end
        rec
      end
      def offsets?(tool, vec)
        return false unless really_closed?(vec)
        return false if %w[drill rim_pocket area_clear].include?(tool["type"].to_s) || pocket?(tool, vec)
        str = vec.operation_type.to_s
        str == "pocket" ? can_offset?(tool, vec) : str != "groove"
      end
      def ancestor?(vec, _b3d6b6ff, rec)
        cur = rec[vec][:parent]
        while cur
          return true if cur.equal?(_b3d6b6ff)
          cur = rec[cur][:parent]
        end
        false
      end
      def same_outline?(a_vec, border)
        _a65b1a05 = Calc.bounds_of(a_vec.points)
        arr = Calc.bounds_of(border.points)
        num2 = Calc.signed_area(a_vec.points).abs
        num = Calc.signed_area(border.points).abs
        return true if Calc.bounds_equal?(_a65b1a05, arr, 1.5 / MM_PER_INCH) &&
                       (num2 - num).abs / [num2, num, 1.0e-12].max <= 0.01
        long_axis = [(arr[1] - arr[0]).abs, (arr[3] - arr[2]).abs, 1.0e-9].max
        _5368b77a = [[long_axis * MM_PER_INCH * 0.002, 1.5].max, 5.0].min
        return false unless Calc.bounds_equal?(_a65b1a05, arr, _5368b77a / MM_PER_INCH)
        return false unless num.positive?
        _5f343815 = num2 / num
        _5f343815 >= 0.90 && _5f343815 <= 1.10
      end
      def inside?(inner, outer)
        return false if inner.points.length < 3 || outer.points.length < 3 || !same_part?(inner, outer)
        _393c2ecd = Calc.bounds_of(inner.points)
        _cc7682d2 = Calc.bounds_of(outer.points)
        return false if !Calc.bounds_inside?(_393c2ecd, _cc7682d2) || Calc.bounds_same_size?(_393c2ecd, _cc7682d2)
        contains_points?(inner.points, outer.points)
      end
      def same_part?(inner, outer)
        arr, str = inner.part_id.to_s, outer.part_id.to_s
        arr.empty? || str.empty? || arr == str
      end
      def contains_points?(inner, outer)
        want = inner.length
        _203b017d = [1, (want / 12.0).ceil].max
        seen2 = _832ce6af = num = _adf0fff9 = _c49977ef = 0.0
        snap_edges = []
        inner.each_with_index do |pt, idx|
          pt2 = inner[(idx + 1) % want]
          x1, y1 = pt.x.to_f, pt.y.to_f
          x2, num2 = pt2.x.to_f, pt2.y.to_f
          seen2 += x1
          _832ce6af += y1
          cross = (x1 * num2) - (x2 * y1)
          num += cross
          _adf0fff9 += (x1 + x2) * cross
          _c49977ef += (y1 + num2) * cross
          snap_edges.push([x1, y1], [(x1 + x2) * 0.5, (y1 + num2) * 0.5]) if (idx % _203b017d).zero?
        end
        arr = num.abs <= 1.0e-12 ? [] : [[_adf0fff9 / (3.0 * num), _c49977ef / (3.0 * num)]]
        arr = (arr << [seen2 / want, _832ce6af / want]).concat(snap_edges).uniq
        arr2 = outer.map { |pt| [pt.x.to_f, pt.y.to_f] }
        arr.any? { |x, y| Calc.ray_crossing?(x, y, arr2) } &&
          arr.all? { |x, y| Calc.in_polygon?(x, y, arr2) }
      end
      def hole_diameter(vec)
        return nil unless really_closed?(vec)
        sheet_type = vec.vector_type.to_s
        diameter = Calc.positive_float(vec.diameter_mm.to_f) if %w[circle arc].include?(sheet_type)
        diameter ||= Calc.positive_float(vec.radius.to_f * MM_PER_INCH * 2.0) if sheet_type == "circle"
        return diameter if diameter
        arr = circle_from_points(vec.points.map { |pt| [pt.x.to_f * MM_PER_INCH, pt.y.to_f * MM_PER_INCH] })
        arr && Calc.positive_float(arr[:radius] * 2.0)
      end
      def circle_from_points(out)
        rows = dedupe(out)
        return nil if rows.length < 12
        arr = Calc.fit_circle(rows)
        return nil unless arr && arr[:radius] > 0.01
        (px, py), r = arr.values_at(:center, :radius)
        return nil if rows.map { |x, y| (Math.hypot(x - px, y - py) - r).abs }.max > 0.01
        sweep = nil
        num = 0.0
        rows.each_with_index do |(x1, y1), idx|
          x2, num3 = rows[(idx + 1) % rows.length]
          _d23c4f19 = Math.atan2(y1 - py, x1 - px)
          _0e2756b3 = Math.atan2(num3 - py, x2 - px)
          delta = Math.atan2(Math.sin(_0e2756b3 - _d23c4f19), Math.cos(_0e2756b3 - _d23c4f19))
          return nil if delta.abs <= 1.0e-10
          flag = delta.negative? ? -1.0 : 1.0
          sweep ||= flag
          return nil unless flag == sweep
          return nil if delta.abs > 35.0 * Math::PI / 180.0
          num += delta.abs
        end
        return nil if num < 330.0 * Math::PI / 180.0 || num > 390.0 * Math::PI / 180.0
        num2 = Calc.signed_area(rows).abs / (Math::PI * r * r)
        return nil unless num2.between?(0.94, 1.02)
        { center: [px, py], radius: r }
      end
      def hole_wider_than_tool?(tool, vec)
        num = tool["diameter"].to_f.abs
        return false unless num.finite? && num.positive?
        hole_dia = hole_diameter(vec)
        hole_dia ? hole_dia - num > 0.05 : false
      end
      def drill_in_place?(tool, vec)
        tool["type"].to_s == "drill" && !hole_wider_than_tool?(tool, vec)
      end
      def pocket?(tool, vec)
        return false unless vec.closed
        sheet_type = tool["type"].to_s
        side = tool["cut_side"].to_s
        return true if sheet_type == "area_clear" || side == "pocket"
        return false if !%w[drill rim_pocket].include?(sheet_type) && %w[inside outside center auto flip_side follow_dir].include?(side)
        return true if hole_wider_than_tool?(tool, vec)
        return false if sheet_type == "drill"
        name = vec.layer_name
        th_txt = layer_slug(name)
        %w[dogbone xuong_cho mong_cho].any? { |key| th_txt.include?(key) } ||
          name.to_s.strip[/\AABF[-_]?D(\d+(?:[.,]\d+)?)(?=[^0-9.,]|$)/i, 1].to_s.tr(",", ".").to_f > 15.001 ||
          vec.operation_type.to_s == "pocket" || %w[pocket hoc ha_nen bao_nen].any? { |key| th_txt.include?(key) }
      end
      def can_offset?(tool, vec)
        !%w[drill area_clear].include?(tool["type"].to_s) && really_closed?(vec) &&
          %w[inside outside auto flip_side follow_dir].include?(tool["cut_side"].to_s)
      end
      def cut_side_of(tool, nested)
        side = tool["cut_side"].to_s
        return side unless side == "follow_dir"
        case tool["cut_direction"].to_s
        when "cw" then "inside"
        when "ccw" then "outside"
        else nested ? "inside" : "outside"
        end
      end
      def layer_slug(str)
        name = str.to_s
        keys = (@layer_slug_cache ||= {})
        keys.fetch(name) do
          keys.clear if keys.length >= 4096
          text = name.downcase
          text = (text.unicode_normalize(:nfd).gsub(/\p{Mn}/, '') rescue text) unless text.ascii_only?
          keys[name] = text.gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, '').freeze
        end
      end
      def dogbone_layer?(vec)
        arr = layer_slug(vec.layer_name)
        arr.include?("dogbone") || arr.include?("xuong_cho")
      end
      def build_chains(vectors, _3a26d1be = nil)
        _b3bd1b7f = unmark_fake_closed(drop_duplicates(vectors))
        segments, _7b244287 = _b3bd1b7f.partition do |vec|
          !vec.closed && %i[edge polyline arc curve].include?(vec.vector_type) && vec.points.length >= 2
        end
        segments, _a8f95a40 = drop_zero_length(segments)
        segments, _9d983184 = drop_same_ends(segments)
        _d1b40753, _3b52ed1e = close_gaps(join_segments(segments))
        _7b244287, _335c1a28 = close_loops(_7b244287)
        _7b244287, _47bdbdff = drop_repeat_points(_7b244287)
        _d1b40753, _57e030d6 = drop_repeat_points(_d1b40753)
        _3a26d1be&.merge!(zero_segs_cut: _a8f95a40 + _47bdbdff + _57e030d6, dupes_cut: _9d983184,
                         gaps_shut: _3b52ed1e + _335c1a28) { |_07afedbd, a, b| a + b }
        _7b244287 + _d1b40753
      end
      def drop_duplicates(vectors)
        h = {}
        h2 = vectors.each_with_index.group_by do |vec, _80d90b95|
          out = vec.points
          flag = out.empty? ? 0 : point_key(out.first).hash + point_key(out.last).hash
          [vec.vector_type, vec.closed, out.length, flag]
        end
        h2.each_value do |rows|
          rows = rows.uniq { |vec, _80d90b95| shape_key(vec) } if rows.length > 1
          rows.each { |_5e94297f, idx| h[idx] = true }
        end
        vectors.select.with_index { |_5e94297f, idx| h[idx] }
      end
      def unmark_fake_closed(vectors)
        vectors.map do |h|
          next h unless h.closed && !really_closed?(h)
          _5f37e12d = h.dup
          _5f37e12d.closed = false
          _5f37e12d.instance_variable_set(:@fake_closed, true)
          _5f37e12d
        end
      end
      def drop_zero_length(segments)
        arr = segments.reject do |seg|
          out = seg.points
          out.length == 2 && gap_mm(out[0], out[1]) <= ZERO_LEN_MM
        end
        [arr, segments.length - arr.length]
      end
      def drop_same_ends(segments)
        arr2 = []
        arr = segments.select do |seg|
          out = seg.points
          a, b = out.first, out.last
          flag = arr2.any? do |row0, last_rect, want|
            want == out.length &&
              ((gap_mm(row0, a) <= CHAIN_GAP_MM && gap_mm(last_rect, b) <= CHAIN_GAP_MM) ||
               (gap_mm(row0, b) <= CHAIN_GAP_MM && gap_mm(last_rect, a) <= CHAIN_GAP_MM))
          end
          arr2 << [a, b, out.length] unless flag
          !flag
        end
        [arr, segments.length - arr.length]
      end
      def join_segments(segments)
        h = {}
        segments.each_with_index do |seg, idx|
          (h[point_key(seg.points.first)] ||= []) << idx
          (h[point_key(seg.points.last)] ||= []) << idx
        end
        taken = Array.new(segments.length, false)
        segments.each_index.filter_map do |_79596bdd|
          next if taken[_79596bdd]
          taken[_79596bdd] = true
          normal = segments[_79596bdd]
          arr = normal.points.dup
          fake_closed = Util.fake_closed?(normal)
          elems = elements_of(normal)
          elem_state = { valid: !elems.empty?, elems: elems }
          while (idx = take_next_segment(arr, segments, h, taken, elem_state, false) ||
                         take_next_segment(arr, segments, h, taken, elem_state, true))
            fake_closed ||= Util.fake_closed?(segments[idx])
          end
          out_rec = normal.dup
          out_rec.points = arr
          out_rec.closed = arr.length > 2 && same_point?(arr.first, arr.last)
          out_rec.instance_variable_set(:@fake_closed, true) if fake_closed
          if elem_state[:valid] && elem_state[:elems].any? { |arr2| arr2[:type] == :arc }
            out_rec.instance_variable_set(:@elements_of, Util.freeze_rows(elem_state[:elems]))
          elsif out_rec.instance_variable_defined?(:@elements_of)
            out_rec.remove_instance_variable(:@elements_of)
          end
          out_rec
        end
      end
      def take_next_segment(arr, segments, h, taken, elem_state, _8b2b6fd2)
        flag = _8b2b6fd2 ? arr.first : arr.last
        h.fetch(point_key(flag), []).each do |idx|
          next if taken[idx]
          out = segments[idx].points
          _f515d7f8, flag2 = _8b2b6fd2 ? [out.last, out.first] : [out.first, out.last]
          reversed = !same_point?(_f515d7f8, flag)
          next if reversed && !same_point?(flag2, flag)
          _a5e52b43 = reversed ? out.reverse : out
          taken[idx] = true
          _8b2b6fd2 ? arr.unshift(*_a5e52b43[0...-1]) : arr.concat(_a5e52b43[1..])
          append_elements(elem_state, segments[idx], reversed: reversed, prepend: _8b2b6fd2)
          return idx
        end
        nil
      end
      def append_elements(elem_state, vec, reversed:, prepend:)
        return unless elem_state[:valid]
        rows = elements_of(vec)
        if reversed
          rows.reverse!.each do |arr|
            arr[:s], arr[:e] = arr[:e], arr[:s]
            arr[:ccw] = !arr[:ccw] if arr[:type] == :arc
          end
        end
        elems = elem_state[:elems]
        long_axis = elem_state[:checked] ? rows.length + 1 : elems.length + rows.length
        prepend ? elems.unshift(*rows) : elems.concat(rows)
        elem_state[:checked] = !rows.empty? && elements_joined?(prepend ? elems.first(long_axis) : elems.last(long_axis))
        return if elem_state[:checked]
        elem_state[:valid] = false
        elem_state[:elems] = []
      end
      def close_gaps(arr)
        taken = Array.new(arr.length, false)
        num = 0
        ok = arr.each_index.filter_map do |i|
          next if taken[i]
          taken[i] = true
          out_rec = arr[i].dup
          next out_rec if really_closed?(out_rec)
          out = out_rec.points
          fake_closed = Util.fake_closed?(out_rec)
          loop do
            _2ec73b4d = nil
            ix = arr.each_index.find { |k| !taken[k] && (_2ec73b4d = splice(out, arr[k].points)) }
            break unless ix
            out = _2ec73b4d
            fake_closed ||= Util.fake_closed?(arr[ix])
            taken[ix] = true
          end
          out_rec.remove_instance_variable(:@elements_of) if out_rec.instance_variable_defined?(:@elements_of)
          closed, _5f936613 = closed_points(out)
          num += 1 if _5f936613
          out_rec.closed = true if closed
          out_rec.instance_variable_set(:@fake_closed, true) if fake_closed
          out_rec.points = closed || out
          out_rec
        end
        [ok, num]
      end
      def splice(arr, _c10b9ce7)
        return nil if arr.empty? || _c10b9ce7.empty?
        _b6e3b20b, _e1d020b5 = arr.first, arr.last
        _fbfe8a95, _f8d3568a = _c10b9ce7.first, _c10b9ce7.last
        if gap_mm(_e1d020b5, _fbfe8a95) <= CHAIN_GAP_MM
          arr + _c10b9ce7[1..]
        elsif gap_mm(_e1d020b5, _f8d3568a) <= CHAIN_GAP_MM
          arr + _c10b9ce7.reverse[1..]
        elsif gap_mm(_b6e3b20b, _f8d3568a) <= CHAIN_GAP_MM
          _c10b9ce7[0..-2] + arr
        elsif gap_mm(_b6e3b20b, _fbfe8a95) <= CHAIN_GAP_MM
          _c10b9ce7.reverse[0..-2] + arr
        end
      end
      def close_loops(vectors)
        num = 0
        ok = vectors.map do |h|
          next h if h.closed
          closed, _5f936613 = closed_points(h.points)
          next h unless closed
          num += 1 if _5f936613
          out_rec = h.dup
          out_rec.points = closed
          out_rec.closed = true
          out_rec
        end
        [ok, num]
      end
      def closed_points(out)
        return nil if out.length <= 2
        _fee74244 = gap_mm(out.first, out.last)
        return nil if _fee74244 > CHAIN_CLOSE_MM
        _fee74244 > ZERO_LEN_MM ? [out[0...-1] + [out.first], true] : [out, false]
      end
      def drop_repeat_points(vectors)
        num = 0
        ok = vectors.map do |h|
          out = h.points
          next h if out.length < 3
          arr = [out.first]
          out[1..].each { |pt| arr << pt unless gap_mm(arr.last, pt) <= ZERO_LEN_MM }
          next h if arr.length == out.length
          num += out.length - arr.length
          out_rec = h.dup
          out_rec.points = arr
          out_rec
        end
        [ok, num]
      end
      def really_closed?(vec)
        return false unless vec.closed
        out = vec.points
        out.length >= 3 && gap_mm(out.first, out.last) <= CHAIN_CLOSE_MM
      end
      def end_gap(vec)
        out = vec.points
        out.length < 2 ? Float::INFINITY : gap_mm(out.first, out.last)
      end
      def gap_mm(pt, b)
        Math.hypot((b.x.to_f - pt.x.to_f) * MM_PER_INCH, (b.y.to_f - pt.y.to_f) * MM_PER_INCH)
      end
      def same_point?(pt, b)
        pt.distance(b) < (ZERO_LEN_MM / MM_PER_INCH)
      end
      def ring3d(out)
        ok = out.dup
        ok << ok.first if ok.length > 1 && !same_point?(ok.first, ok.last)
        ok
      end
      def point_key(pt)
        [pt.x.to_f.round(6), pt.y.to_f.round(6), pt.z.to_f.round(6)]
      end
      def shape_key(vec)
        arr = vec.points.map { |pt| point_key(pt) }
        _b79faaa2 = arr.reverse
        [vec.vector_type, vec.closed, (_b79faaa2 <=> arr) == -1 ? _b79faaa2 : arr]
      end
      def elements_of(bb)
        found = bb.instance_variable_get(:@elements_of)
        return found.map { |row| Util.dup_array_values(row) } if found
        out = bb.points
        return [] if out.length < 2
        case bb.vector_type
        when :arc, :circle
          center = bb.center
          return [] unless center
          _ddfbd967 = bb.vector_type == :circle
          [{ type: :arc, s: xyz(out.first), e: xyz(_ddfbd967 ? out.first : out.last),
             c: xyz(center), ccw: !arc_is_cw?(out, center), full_circle: _ddfbd967 }]
        when :edge, :line
          [{ type: :line, s: xyz(out.first), e: xyz(out.last) }]
        when :polyline, :curve
          out.each_cons(2).filter_map do |row0, last_rect|
            next if same_point?(row0, last_rect)
            { type: :line, s: xyz(row0), e: xyz(last_rect) }
          end
        else
          []
        end
      end
      def xyz(pt)
        [pt.x.to_f, pt.y.to_f, pt.z.to_f]
      end
      def elements_joined?(elems)
        return false if elems.empty?
        elems.each_cons(2).all? do |arr, arr2|
          Math.hypot((arr[:e][0] - arr2[:s][0]) * MM_PER_INCH, (arr[:e][1] - arr2[:s][1]) * MM_PER_INCH) <= 0.001
        end
      end
      def arc_is_cw?(out, center)
        Calc.cross(center, out.first, out[1]) < 0.0
      end
      class FrozenName
        attr_reader :name
        def initialize(name)
          @name = name.to_s.dup.freeze
        end
      end
      class FrozenDictionary
        attr_reader :name
        def initialize(name, h7)
          @name = name.to_s.dup.freeze
          @h7 = h7.freeze
        end
        def each_pair(&blk)
          @h7.each_pair(&blk)
        end
      end
      class FrozenEntity
        attr_reader :name, :layer, :definition, :persistent_id, :attribute_dictionaries
        def initialize(entity)
          @persistent_id = (entity.respond_to?(:persistent_id) ? entity.persistent_id : entity.object_id) rescue entity.object_id
          @name = (entity.respond_to?(:name) ? entity.name.to_s.dup.freeze : ''.freeze) rescue ''.freeze
          layer = (entity.respond_to?(:layer) && entity.layer ? entity.layer.name.to_s : '') rescue ''
          @layer = FrozenName.new(layer)
          grp = (entity.respond_to?(:definition) && entity.definition ? entity.definition.name.to_s : '') rescue ''
          @definition = FrozenName.new(grp)
          @attribute_dictionaries = frozen_attributes(entity)
          freeze
        end
        def curve
          nil
        end
        private
        def frozen_attributes(entity)
          flag = entity.respond_to?(:attribute_dictionaries) ? entity.attribute_dictionaries : nil
          return [].freeze unless flag
          flag.map do |h|
            h7 = {}
            h.each_pair { |key, val| h7[key.to_s] = Export.deep_dup(val) }
            FrozenDictionary.new(h.name.to_s, h7)
          end.freeze
        rescue StandardError
          [].freeze
        end
      end
      class FrozenModel
        attr_reader :path, :title
        def initialize(model)
          @path = model.path.to_s.dup.freeze
          @title = model.title.to_s.dup.freeze
        end
      end
      def deep_dup(h)
        case h
        when String then h.dup
        when Array then h.map { |fld| deep_dup(fld) }
        when Hash then h.each_with_object({}) { |(key, fld), out| out[deep_dup(key)] = deep_dup(fld) }
        when NilClass, TrueClass, FalseClass, Numeric, Symbol then h
        else h.dup
        end
      rescue StandardError
        h.to_s
      end
      def dup_point(pt)
        ::Geom::Point3d.new(pt.x.to_f, pt.y.to_f, pt.z.to_f) if pt
      end
      def frozen_entity(entity, cache)
        return nil unless entity
        key = (entity.respond_to?(:persistent_id) ? [:pid, entity.persistent_id] : [:oid, entity.object_id]) rescue [:oid, entity.object_id]
        cache[key] ||= FrozenEntity.new(entity)
      end
      def freeze_model(arr, model)
        raise Text.t(:quet, :khong_du_lieu) unless arr && arr.count.positive?
        cache = {}
        h = {}.compare_by_identity
        bb2 = Database.new
        arr.vectors.each do |rec|
          bb = rec.dup
          bb.points = rec.points.map { |segs_for_ray| ::Geom::Point3d.new(segs_for_ray.x.to_f, segs_for_ray.y.to_f, segs_for_ray.z.to_f) if segs_for_ray }
          bb.center = dup_point(rec.center)
          bb.source_path = deep_dup(rec.source_path)
          bb.src_path_ids = deep_dup(rec.src_path_ids)
          bb.board_chain = deep_dup(rec.board_chain)
          bb.entity = h[rec.entity] ||= frozen_entity(rec.entity, cache)
          bb.board_entity = h[rec.board_entity] ||= frozen_entity(rec.board_entity, cache)
          bb.sheet_entity = h[rec.sheet_entity] ||= frozen_entity(rec.sheet_entity, cache)
          bb.part_entity = h[rec.part_entity] ||= frozen_entity(rec.part_entity, cache)
          bb2.add(bb)
        end
        FrozenExport.new(database: bb2, model: FrozenModel.new(model))
      end
      def write_drill(lines, post, paths, tool, vars)
        z3 = z(tool)
        approach = approach_z(tool)
        depth = depth_value(tool, tool["cut_depth"])
        paths.each do |path|
          x, y = path.points.first
          move_to_start(lines, post, vars, x: x, y: y, tool: tool)
          write_peck(lines, post, vars, tool, approach, depth)
          rapid(lines, post, vars, z: z3)
        end
      end
      def write_peck(lines, post, vars, tool, approach, depth)
        return write_bore_entry(lines, post, vars, tool, depth) unless tool["drill_mode"].to_s == "peck"
        num2 = [tool["peck_mm"].to_f.abs, 0.1].max
        cur = approach
        num3 = 0
        while cur - depth > 1.0e-6
          if (num3 += 1) > PASS_LIMIT
            raise UnsafeCutError, Text.t(:dao, :khoan_nhap_nho, buoc: Text.num(num2, 3), ten: ten(tool))
          end
          _6f764a70 = [cur - num2, depth].max
          write_bore_entry(lines, post, vars, tool, _6f764a70)
          break if (_6f764a70 - depth).abs <= 1.0e-6
          cur = [_6f764a70 + [1.0, num2 * 0.35].max, approach].min
          rapid(lines, post, vars, z: cur)
        end
      end
      def drill_center(bb, tool)
        hole_dia = hole_diameter(bb)
        raise UnsafeCutError, Text.t(:duong, :lo_khoan) unless hole_dia
        center = bb.center if %w[circle arc].include?(bb.vector_type.to_s)
        unless center
          base_pts = bb.points.map { |pt| [pt.x.to_f * MM_PER_INCH, pt.y.to_f * MM_PER_INCH] }
          arr = circle_fit(base_pts) || circle_from_points(base_pts)
          raise UnsafeCutError, Text.t(:duong, :lo_khoan) unless arr
          x, y = arr[:center]
          center = ::Geom::Point3d.new(x.to_f / MM_PER_INCH, y.to_f / MM_PER_INCH, 0.0)
        end
        num2 = tool["diameter"].to_f.abs
        raise UnsafeCutError, Text.t(:duong, :van_de) unless num2.finite? && num2.positive?
        if hole_dia - num2 < -0.05
          raise UnsafeCutError, Text.t(:duong, :khoan_lon_hon_lo, lo: Text.num(hole_dia, 3))
        end
        center
      end
      def write_mark(lines, post, row, tool, vars)
        plan = row.metadata["back_square_mark"]
        assert_mark_plan(plan, tool)
        z4 = z(tool)
        pass_depths(tool).each do |depth|
          move_to_start(lines, post, vars, x: plan[:start][0], y: plan[:start][1], tool: tool)
          rest = write_mark_entry(lines, post, vars, plan, tool, depth)
          feed = tool["feed"].to_f
          rest.each_cons(2) { |_a5c3241a, pt| feed_move(lines, post, vars, x: pt[0], y: pt[1], feed: feed) }
          tangent_in = plan[:tangent_in]
          arr = plan[:tangent_out]
          arc_move(lines, post, vars, x: arr[0], y: arr[1],
                      i: plan[:center][0] - tangent_in[0], j: plan[:center][1] - tangent_in[1],
                      feed: feed, clockwise: plan[:clockwise], first: false)
          feed_move(lines, post, vars, x: plan[:end_point][0], y: plan[:end_point][1], feed: feed)
          rapid(lines, post, vars, z: z4)
        end
      end
      def write_mark_entry(lines, post, vars, plan, tool, depth)
        mode = tool["entry_mode"].to_s
        spiral = mode == "ramp_line" && tool["ramp_kind"].to_s == "spiral"
        if spiral || %w[helix helix_ramp].include?(mode)
          raise UnsafeCutError, Text.t(:mat_sau, :khong_xoan, ten: ten(tool), kieu: Text.term(spiral ? :xoan_bien : :xoan_tam))
        end
        path = [plan[:start], plan[:tangent_in]]
        case mode
        when "vertical", ''
          write_bore_entry(lines, post, vars, tool, depth)
          path
        when "ramp_line"
          assert_ramp_fits(path, tool, [depth])
          write_entry(lines, post, path, tool, vars, depth)
        end
      end
      def assert_mark_plan(plan, tool)
        err = Text.t(:mat_sau, :khong_dung_dau)
        r = plan[:radius_mm]
        raise UnsafeCutError, err if (r - tool["diameter"].to_f * 0.5).abs > MARK_ARC_TOLERANCE_MM
        start, tangent_in, arr, center = plan.values_at(:start, :tangent_in, :tangent_out, :center)
        _6c24d0bb = Math.hypot(tangent_in[0] - center[0], tangent_in[1] - center[1])
        _a1faf843 = Math.hypot(arr[0] - center[0], arr[1] - center[1])
        raise UnsafeCutError, err if (_6c24d0bb - r).abs > MARK_ARC_TOLERANCE_MM || (_a1faf843 - r).abs > MARK_ARC_TOLERANCE_MM
        arr2 = unit_to(start, tangent_in)
        arr4 = unit_to(arr, plan[:end_point])
        arr3 = unit_to(center, tangent_in)
        arr5 = unit_to(center, arr)
        num2 = ((arr2[0] * arr3[0]) + (arr2[1] * arr3[1])).abs
        num = ((arr4[0] * arr5[0]) + (arr4[1] * arr5[1])).abs
        raise UnsafeCutError, err if num2 > MARK_TANGENT_TOLERANCE || num > MARK_TANGENT_TOLERANCE
        return unless tool["entry_mode"].to_s == "ramp_line" && tool["ramp_kind"].to_s != "spiral"
        ramp_point = plan[:ramp_point]
        raise UnsafeCutError, err if !ramp_point || (plan[:ramp_len_mm] - tool["ramp_len_mm"].to_f).abs > 0.002
        arr6 = unit_to(start, ramp_point)
        _c01f1c2f = (arr6[0] * arr2[0]) + (arr6[1] * arr2[1])
        raise UnsafeCutError, err if _c01f1c2f < 1.0 - MARK_TANGENT_TOLERANCE
      end
      def unit_to(arr, b)
        dx = b[0].to_f - arr[0].to_f
        dy = b[1].to_f - arr[1].to_f
        length = Math.hypot(dx, dy)
        raise UnsafeCutError, Text.t(:mat_sau, :khong_dung_dau) unless length.finite? && length > 0.001
        [dx / length, dy / length]
      end
      def simplify_points(out)
        closed = out.length > 2 && Calc.distance(out.first, out.last) < 1.0e-9
        entries = closed ? out[0...-1] : out.dup
        want = entries.length
        return out if want < 5
        keep_existing = Array.new(want, true)
        runs = []
        idx = 0
        while idx < want
          last_rect = idx
          last_rect += 1 while Calc.distance(entries[last_rect % want], entries[(last_rect + 1) % want]) < 1.6 && last_rect - idx < 12
          runs << [idx, last_rect] if (1..10).cover?(last_rect - idx)
          idx = last_rect + 1
        end
        runs.each do |start, run_batch|
          circle = Calc.circle_through(entries[start], entries[((start + run_batch) / 2) % want],
                                           entries[run_batch % want], 1.0e-12)
          next if circle.nil? || circle[:radius] >= 1.0
          corner = Calc.line_cross(entries[start - 1], entries[start],
                                             entries[run_batch % want], entries[(run_batch + 1) % want])
          next if corner.nil? || Calc.distance(corner, entries[start]) > 6.0
          (start..run_batch).each { |k| keep_existing[k % want] = false }
          entries[start] = corner
          keep_existing[start] = true
        end
        ok = entries.select.with_index { |_, k| keep_existing[k] }
        return out if ok.length < 3
        ok << ok.first if closed
        ok
      end
      def offset_native(out, r, cut_side)
        return nil if out.length < 3
        num = Calc.signed_area(out)
        return nil if num.abs < 0.000001
        flag = num.positive? ? -1.0 : 1.0
        ctrl = r * (cut_side == "inside" ? -flag : flag)
        want = out.length
        lines = Array.new(want) do |idx|
          arr = out[idx]
          b = out[(idx + 1) % want]
          dx = b[0] - arr[0]
          dy = b[1] - arr[1]
          length = Math.sqrt(dx * dx + dy * dy)
          return nil if length < 0.000001
          _821639ac = -dy / length * ctrl
          _98c3a7e0 = dx / length * ctrl
          [[arr[0] + _821639ac, arr[1] + _98c3a7e0], [b[0] + _821639ac, b[1] + _98c3a7e0]]
        end
        num2 = r.abs * 1.02
        num3 = r.abs * 2.5
        ok = []
        want.times do |idx|
          arr2 = lines[idx - 1]
          cur = lines[idx]
          e = Calc.line_cross(arr2[0], arr2[1], cur[0], cur[1])
          next ok << cur[0] if e.nil?
          mid = out[idx]
          arr3 = out[idx - 1]
          arr4 = out[(idx + 1) % want]
          cross = ((mid[0] - arr3[0]) * (arr4[1] - mid[1])) - ((mid[1] - arr3[1]) * (arr4[0] - mid[0]))
          per_row = (cross * ctrl).negative? ? num2 : num3
          next ok << e if Math.hypot(e[0] - mid[0], e[1] - mid[1]) <= per_row
          _b0ec3adc = Calc.deg4(arr2[1], mid)
          delta = Calc.wrap_pi(Calc.deg4(cur[0], mid) - _b0ec3adc)
          steps = [(delta.abs / (12.0 * Math::PI / 180.0)).ceil, 1].max
          ok.concat(Calc.arc_points(mid, r.abs, _b0ec3adc, delta, steps))
        end
        ok
      end
      def offset_inside(out, r)
        boundary = dedupe(out)
        return err_bad_path if boundary.length < 3
        return { ok: false, error: Text.t(:duong, :bien_tu_cat) } if self_intersects?(boundary)
        id_str = offset_graph(boundary, r)
        return err_bad_path if id_str.nil? || id_str.length < 3
        arr2 = planar_graph(id_str)
        return err_bad_path unless arr2
        per_row = r - 0.04
        src = graph_faces(arr2).select do |font|
          rows = font[:area] > 0.000001 ? dedupe(font[:polygon]) : []
          rows.length >= 3 && loop_clear?(rows, boundary, per_row)
        end
        loops = face_loops(src, arr2[:nodes]).select do |arr|
          arr.length >= 3 && Calc.signed_area(arr).abs > 0.001 && !self_intersects?(arr)
        end
        arr3 = loops.select { |arr| Calc.signed_area(arr).abs > 0.05 }
        return offset_marching(boundary, r) if loops.empty? || arr3.length > 1
        sel = dedupe((arr3.empty? ? loops : arr3).max_by { |arr| Calc.signed_area(arr).abs })
        return err_bad_path if sel.length < 3
        safe_send = sel.all? do |pt|
          Calc.in_polygon?(pt[0], pt[1], boundary) && Calc.polygon_distance(pt, boundary) >= per_row
        end
        return offset_marching(boundary, r) unless safe_send
        { ok: true, path: ring(sel) }
      end
    end
  end
end
