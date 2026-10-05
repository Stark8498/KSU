require "digest"
module KSU
  module Cnc
    module Canvas
      module_function
      def to_segments(arr, model, only_index:, with_toolpaths:, moves: true)
        return { ok: false, message: Text.t(:quet, :khong_du_lieu) } unless arr.count.positive?
        settings = Export.cnc_settings
        thickness = Calc.round2(settings["do_day_van"])
        meta = build_meta(model, settings).merge!(moves: moves)
        Export.path_cache_limit(arr.count)
        sheets = sheet_rows(arr).each_with_index.filter_map do |sheet, idx|
          next unless only_index.nil? || only_index == idx
          h = with_toolpaths ? slot_for(sheet, meta) : build_slot(sheet, meta, false)
          next unless h
          h[:source].each { |fld| fld[:color] = layer_color(fld[:layer], meta) }
          arr2 = Export.materials_of(sheet)
          str = arr2.length > 1 && Text.error_text(Text.t(:van, :nhieu_vat_lieu, vat_lieu: arr2.join(", ")))
          h = h.merge(warnings: [str] + Array(h[:warnings]), blocked: true) if str
          _108712d0 = with_toolpaths && back_mismatch_note(sheet)
          h = h.merge(warnings: Array(h[:warnings]) + [_108712d0]) if _108712d0
          h.merge!(index: idx, pending: !with_toolpaths, material_key: material_key(sheet))
        end
        { ok: true, thickness: thickness, top: settings["goc_cao_do"] == "bottom" ? thickness : 0.0, sheets: sheets }
      rescue Export::UnsafeCutError => str
        { ok: false, message: Text.error_text(str.message) }
      end
      def sheet_rows(db)
        sheets = db.sheets
        return @sheet_rows[1] if @sheet_rows && @sheet_rows[0].equal?(sheets)
        arr2 = Export.sheet_map(db).values.sort_by { |arr| [Natural.key(arr[:name]), arr[:path_key].to_s] }
        idx = @sheet_index = {}
        arr2.each_with_index { |arr, index| idx[arr[:path_key].to_s] ||= index }
        @sheet_rows = [sheets, arr2]
        @h16 = @arr37 = @h13 = nil
        slots.delete_if { |id, _| !idx.key?(id) }
        arr2
      end
      def sheet_index(db)
        sheet_rows(db)
        @sheet_index
      end
      def build_meta(model, settings)
        arr = Library.config_copy
        tools = arr["tools"].map { |tool| Export.merge_tool_settings(tool, settings) }
        {
          model: model, settings: settings, colors: {}, tools: {}.compare_by_identity, layer_map: arr["layer_map"],
          cutter_by_id: arr["cutters"].to_h { |tool| [tool["id"].to_s, tool] },
          cutter_by_no: arr["cutters"].to_h { |tool| [tool["number"].to_i, tool] },
          tool_index: tools.to_h { |tool| [tool["id"].to_s, tool] },
          tool_order: tools.each_with_index.to_h { |tool, idx| [tool["id"].to_s, idx] },
          layer_order: arr["layer_order"].each_with_index.to_h { |name, idx| [name.to_s, idx] }
        }
      end
      def slots
        @slots ||= {}
      end
      def reset_stamp
        @sheet_rows = @sheet_index = @h16 = @arr37 = @h13 = nil
        Export.clear_sheet_map
        Export.reset_path_cache
      end
      def reset2
        slots.clear
        reset_stamp
      end
      def slot_report(db, model)
        meta = build_meta(model, Export.cnc_settings)
        sheet_rows(db).each_with_object({ valid: [], stale: [], labels: {} }) do |arr, arr2|
          id = arr[:path_key].to_s
          _291100d1 = slot_fresh?(slots[id], slot_key(arr, meta), tool_names(arr, meta))
          arr2[_291100d1 ? :valid : :stale] << id
          arr2[:labels][id] = sheet_fields(arr, meta).slice(:material, :label).merge(material_key: material_key(arr))
        end
      end
      def slot_for(arr, meta)
        id = arr[:path_key].to_s
        key = slot_key(arr, meta)
        side_names = tool_names(arr, meta)
        prev_key = slot = slots[id]
        slots[id] = slot if !slot_fresh?(slot, key, side_names) && (slot = Store.get(key))
        if slot_fresh?(slot, key, side_names)
          h = slot[:row].merge(sheet_fields(arr, meta))
          return h.merge!(toolpaths: Array(slot[:paths]).map { |path| path_fields(path, meta) })
        end
        h = build_slot(arr, meta, true, slot || prev_key)
        return h unless h&.key?(:paths)
        paths = h.delete(:paths)
        ops = h.delete(:ops)
        slot = slots[id] = { key: key, names: side_names, row: h.merge(toolpaths: []), paths: paths,
                                             ops: ops, base: slot_key_now(arr, meta) }
        Store.set(key, slot) unless no_toolpath?(slot)
        h
      end
      def slot_fresh?(slot, key, side_names)
        return false unless slot && slot[:key] == key
        slot[:names] == side_names || slot[:row][:warnings].empty?
      end
      def slot_key_now(sheet, meta)
        saved_sel = sheet_scope(sheet, meta)
        tools = meta[:tools_base] ||= begin
          _ec0da59d = Digest::SHA256.new
          hash_value(_ec0da59d, meta[:tool_index].transform_values { |tool| Export.tool_cut_keys(tool) })
          _ec0da59d.hexdigest
        end
        vars = [geometry_key(sheet), tools, saved_sel[:do_day_van], saved_sel[:reason], saved_sel[:back], meta[:settings]["goc_cao_do"]]
        Digest::SHA256.hexdigest(vars.join("|"))
      end
      def slot_ready?(arr, meta)
        slot = slots[arr[:path_key].to_s]
        return false unless slot && slot[:paths] && slot[:ops].is_a?(Hash) && !slot[:ops].empty?
        slot[:base] == slot_key_now(arr, meta)
      end
      def index_paths(arr2, meta, prev_key, ops)
        idx = {}.compare_by_identity
        arr2[:vectors].each_with_index { |vec, _6441cd49| idx[vec] = _6441cd49 }
        head_off = "ksu_cnc_op_v1|#{geometry_key(arr2)}|#{meta[:settings]['goc_cao_do']}|"
        flag = prev_key && prev_key[:paths] && prev_key[:ops].is_a?(Hash) ? prev_key[:ops] : {}
        lambda do |arr, vectors, tool_index, anchor, border, _93877d6f|
          tool = arr[:tool]
          arr3 = Digest::SHA256.new << head_off << arr[:vectors].map { |vec| idx[vec] }.join(",") << "|"
          hash_value(arr3, [Export.tool_cut_keys(tool), tool.values_at("name", "config_name", "cutter_name"),
                                      vectors.map { |vec| tool_index[vec] }, anchor, border])
          key = arr3.hexdigest
          ok = reuse_paths(prev_key, flag[key], arr) || _93877d6f.call
          ops << [key, *ok]
          ok
        end
      end
      def reuse_paths(prev_key, rec, arr2)
        return nil unless rec.is_a?(Array) && rec.length == 4
        row0, want, id_str, partner = rec
        rows = prev_key[:paths][row0, want]
        return nil unless rows && rows.length == want && id_str >= want && partner.is_a?(Array)
        layer_name = arr2[:layer_name]
        paths = rows.map do |arr|
          Planner::Path.new(arr[:kind], layer_name, arr[:tool], arr[:points], arr[:closed], arr[:entry_style], [], 0.0, {})
        end
        paths.concat(Array.new(id_str - want) { Planner::Path.new("center", layer_name, nil, [], false, nil, [], 0.0, {}) })
        [paths, partner.map { |_f68f66d8| Planner::PlanIssue.new(*_f68f66d8) }]
      end
      def ops_summary(ops, arr)
        _6441cd49 = row0 = 0
        ops.to_h do |key, paths, partner|
          want = arr[_6441cd49, paths.length].count { |fld| fld }
          rec = [row0, want, paths.length, partner.map(&:to_a)]
          _6441cd49 += paths.length
          row0 += want
          [key, rec]
        end
      end
      def no_toolpath?(slot)
        slot[:paths].nil? && slot[:row][:warnings].include?(Text.t(:mo_phong, :khong_dung_duong_dao))
      end
      def slot_key(sheet, meta)
        geometry_key(sheet) + sheet_cache_key(sheet, meta)
      end
      def geometry_key(arr)
        (@h16 ||= {}.compare_by_identity)[arr] ||= begin
          _ec0da59d = Digest::SHA256.new << "ksu_cnc_geometry_v7|#{arr[:path_key]}|#{arr[:name]}|#{arr[:nesting_name]}|"
          arr[:vectors].each do |bb|
            _ec0da59d << %i[
              nesting_id sheet_id board_id part_id board_name part_name layer_name vector_type operation_type closed
              work_face root_sheet_id root_sheet_name latch_side latch_seq latch_row diameter_mm
            ].map { |name| "#{name}=#{bb.public_send(name)}|" }.join
            _ec0da59d << "path=#{bb.source_path.map(&:to_s).join('/')}|radius=#{format("%.9f", bb.radius.to_f)}|"
            out = bb.center ? [bb.center, *bb.points] : bb.points
            out.each_slice(256) do |grp|
              vars = grp.flat_map { |pt| [pt.x.to_f, pt.y.to_f, pt.z.to_f] }
              _ec0da59d << format("%.7f,%.7f,%.7f,;" * grp.length, *vars)
            end
            _ec0da59d << "#"
          end
          _ec0da59d.hexdigest
        end
      end
      def sheet_cache_key(sheet, meta)
        saved_sel = sheet_scope(sheet, meta)
        tools = Export.tool_index_for(meta, saved_sel[:do_day_van], saved_sel[:back])
        _ec0da59d = Digest::SHA256.new << "ksu_cnc_simulation_sheet_cache_v7|"
        hash_value(_ec0da59d, saved_sel[:map])
        hash_value(_ec0da59d, saved_sel[:skip])
        hash_value(_ec0da59d, rank_keys(saved_sel[:ids], meta[:tool_order]))
        hash_value(_ec0da59d, rank_keys(saved_sel[:names], meta[:layer_order]))
        hash_value(_ec0da59d, saved_sel[:ids].to_h { |id| [id, Export.tool_cut_keys(tools[id])] })
        hash_value(_ec0da59d, [saved_sel[:do_day_van], saved_sel[:reason], meta[:settings]["goc_cao_do"]])
        _ec0da59d.hexdigest
      end
      def tool_names(sheet, meta)
        sheet_scope(sheet, meta)[:ids].map do |id|
          [id, *meta[:tool_index][id].values_at("name", "config_name", "cutter_name").map(&:to_s)]
        end.sort
      end
      def sheet_scope(arr, meta)
        (meta[:scopes] ||= {}.compare_by_identity)[arr] ||= begin
          layer_map = meta[:layer_map]
          side_names = arr[:vectors].map { |vec| vec.layer_name.to_s }.uniq
          h = side_names.each_with_object({}) do |name, rows|
            id = layer_map[name.strip].to_s
            rows[name.strip] = id if meta[:tool_index].key?(id)
          end
          _9f00578a = Export.thickness_of(arr, meta[:settings])
          reason = Export.thickness_problem(arr) unless _9f00578a
          ref_p1 = side_names.select { |name| Export.skip_layer?(layer_map, name) }.map(&:strip)
          { names: side_names, map: h, ids: h.values.uniq, skip: ref_p1, do_day_van: _9f00578a, reason: reason,
            back: Export.work_face(arr[:vectors]) == :back }
        end
      end
      def rank_keys(keys, materials)
        vars = keys.map { |key| materials.fetch(key, 1_000_000) }
        arr = vars.uniq.sort
        keys.each_with_index.to_h { |key, idx| [key, arr.index(vars[idx])] }
      end
      def hash_value(_ec0da59d, val)
        case val
        when Hash
          _ec0da59d << "{"
          val.keys.sort_by(&:to_s).each { |key| hash_value(_ec0da59d << key.to_s << ":", val[key]) << ";" }
          _ec0da59d << "}"
        when Array
          _ec0da59d << "["
          val.each { |fld| hash_value(_ec0da59d, fld) << "," }
          _ec0da59d << "]"
        when Numeric
          number = val.to_f
          _ec0da59d << (number.finite? ? format("%.9f", number) : val.to_s)
        when TrueClass, FalseClass, NilClass, Symbol
          _ec0da59d << val.inspect
        else
          _ec0da59d << val.to_s
        end
      end
      def build_slot(arr, meta, with_toolpaths, prev_key = nil)
        vectors = arr[:vectors]
        anchor = Export.origin_of(vectors)
        return nil unless anchor
        warnings = []
        boundary = vectors.each_with_index.filter_map do |vec, idx|
          out = round_path(vec.points.map { |pt| Export.to_mm(pt, anchor) })
          next if out.length < 2
          if vec.closed && !Export.really_closed?(vec)
            gap2 = Text.num(Export.end_gap(vec), 3)
            x, y = out.first
            text = Text.t(:ban_ve, :kin_bi_ho, layer: vec.layer_name, khoang: gap2, x: Text.num(x, 1), y: Text.num(y, 1))
            warnings << Text.warning_text(text)
          end
          { layer: vec.layer_name, points: out, v: idx }
        end
        return nil if boundary.empty?
        text2, x1 = boundary.flat_map { |arr2| arr2[:points].map(&:first) }.minmax
        y0, y1 = boundary.flat_map { |arr2| arr2[:points].map(&:last) }.minmax
        _9f00578a = sheet_scope(arr, meta)[:do_day_van]
        thickness = _9f00578a && Calc.round2(_9f00578a)
        arr2 = {
          id: arr[:path_key].to_s, name: arr[:name].to_s, **sheet_fields(arr, meta),
          x: Calc.round2(anchor[0]), y: Calc.round2(anchor[1]), bx: Calc.round2(text2), by: Calc.round2(y0),
          w: Calc.round2(x1 - text2), h: Calc.round2(y1 - y0),
          thickness: thickness, top: meta[:settings]["goc_cao_do"] == "bottom" ? thickness : 0.0,
          source: boundary, toolpaths: [], warnings: warnings, blocked: false
        }
        build_paths(arr2, arr, meta, prev_key) if with_toolpaths
        arr2
      rescue StandardError
        { id: arr[:path_key].to_s, name: arr[:name].to_s, source: [], toolpaths: [], blocked: true,
          warnings: [Text.t(:mo_phong, :khong_dung_van)] }
      end
      def build_paths(arr, arr3, meta, prev_key = nil)
        saved_sel = sheet_scope(arr3, meta)
        _9f00578a = saved_sel[:do_day_van]
        raise Export::UnsafeCutError, saved_sel[:reason] unless _9f00578a
        layer_map = meta[:layer_map]
        warnings = arr[:warnings]
        arr2 = Export.tool_index_for(meta, _9f00578a, saved_sel[:back])
        vectors = arr3[:vectors].reject { |vec| Export.reference?(vec) }
        arr4 = vectors.reject { |vec| Export.border_layer?(vec.layer_name) }
        Export.tools_too_deep(arr3, arr2, layer_map, _9f00578a, arr4).each do |tool|
          depth = Text.num(tool["cut_depth"].to_f.abs)
          warnings << Text.t(:mo_phong, :qua_day, ten: Export.ten(tool), sau: depth, day: Text.num(_9f00578a))
        end
        saved_sel[:map].each_value do |id|
          Export.pass_limit_note(arr2[id]).each { |axis| warnings << axis unless warnings.include?(axis) }
        end
        arr6, arr7 = Export.split_unmapped(arr4, arr2, layer_map)
        unless arr6.empty?
          warnings << Text.error_text(Text.t(:chong_bay, :chua_gan, layer: arr6.join(", ")))
          arr[:blocked] = true
        end
        warnings << Text.t(:xuat, :layer_bo_qua, layer: arr7.join(", ")) unless arr7.empty?
        back = Export.work_face(vectors) == :back
        box2 = Frame.to_segments(vectors, back_face: back)
        warnings << Text.t(:mat_sau, :thieu_khung, van: "#{arr[:label]}#{Text.t(:van, :mat)}") if back && box2 && !box2[:full_sheet]
        raise Export::UnsafeCutError, Text.t(:van, :khong_goc) unless box2
        plan = Planner::Builder.to_segments(
          vectors: vectors, origin: box2[:origin], run_scope: :sim_view, repair_stats: (h = {}),
          references: vectors.select { |vec| Export.part_border?(vec.layer_name) },
          operations: Export.operations_for(arr4, layer_map, arr2, meta[:tool_order], meta[:layer_order]),
          reuse: index_paths(arr3, meta, prev_key, (ops = []))
        )
        arr8 = plan.warnings.map { |axis| axis.sub(/\A[^:]+: /, '') }
        warnings.reject! { |axis| arr8.include?(axis.sub(/\A[^:]+: /, '')) }
        warnings.concat(plan.warnings).concat(Export.repair_notes(h))
        want = plan.hard_issues.length
        if want.positive? || !plan.shape_report[:ok]
          warnings.unshift(want.positive? ? Text.t(:mo_phong, :bi_chan_duong_dao) : Text.t(:mo_phong, :bi_chan_hinh))
          arr[:blocked] = true
        elsif plan.paths.empty?
          warnings.unshift(Text.t(:mo_phong, :bi_chan_trong)) unless Export.all_skipped?(arr4, layer_map)
        end
        arr5 = plan.paths.map do |path|
          out = round_path(path.points)
          flag = %w[drill pocket_bore].include?(path.kind)
          next if out.empty? || (!flag && out.length < 2)
          { kind: path.kind, tool: path.tool, points: flag ? [out.first] : out,
            entry_style: path.entry_style, closed: path.closed }
        end
        arr[:paths] = arr5.compact
        arr[:ops] = ops_summary(ops, arr5)
        arr[:toolpaths].concat(arr[:paths].map { |slot| path_fields(slot, meta) })
      rescue StandardError => err
        arr[:paths] = arr[:ops] = nil
        arr[:warnings] << (err.is_a?(Export::UnsafeCutError) ? Text.error_text(err.message) : Text.t(:mo_phong, :khong_dung_duong_dao))
        arr[:blocked] = true
      end
      def path_fields(slot, meta)
        tool, fields = h6 = meta[:tools][slot[:tool]] ||= tool_fields(slot[:tool], meta)
        kind = slot[:kind]
        out = slot[:points]
        row = { kind: kind, **fields, points: out }
        return row unless meta[:moves]
        depths = h6[2] ||= [Export.z(tool), Export.approach_z(tool), Export.pass_depths(tool)]
        return row.merge!(moves: round_xy(out.first, depths)) if %w[drill pocket_bore].include?(kind)
        slow_dist = kind == "profile" || slot[:closed] ? Export.slow_length(tool) : 0.0
        slow_dist = 0.0 if %w[open_cut pocket rim_pocket].include?(kind)
        row.merge!(moves: entry_moves(out, tool, slot[:entry_style], slow_dist, depths))
      end
      def tool_fields(tool, meta)
        str = meta[:tool_index][tool["id"].to_s]
        tool = tool.merge(str.slice(*Export::DISPLAY_TOOL_KEYS)) if str
        [tool, {
          tool: tool["number"].to_i, name: (tool["cutter_name"] || tool["name"] || tool["config_name"]).to_s,
          color: cutter_color(tool, meta), shape: tool_shape(tool),
          diameter: Calc.round2(tool["diameter"]), angle: tool["angle"].to_f, feed: tool["feed"].to_f,
          slow_feed: Export.slow_feed(tool).to_f, plunge: tool["plunge"].to_f
        }]
      end
      def entry_moves(out, tool, entry_style, slow_len, depths)
        z2, approach, tool_index = depths
        str = (entry_style || tool["entry_mode"]).to_s == "ramp_line"
        arr2 = out.map { |pt| Calc.round2(pt[0]) }
        arr = out.map { |pt| Calc.round2(pt[1]) }
        last_rect = out.length - 1
        _aae2b052 = Calc.round2(approach)
        result = [[arr2[0], arr[0], Calc.round2(z2), "rapid"], [arr2[0], arr[0], _aae2b052, "rapid"]]
        tool_index.each_with_index do |depth, _2b9ddb2e|
          num = result.length
          z = Calc.round2(depth)
          if str
            _69c0a968 = [[last_rect, 12].min, 1].max
            (0.._69c0a968).each do |ix|
              result << arr22(out[ix], approach + (depth - approach) * (ix.to_f / _69c0a968), "cut")
            end
            a = _69c0a968 + 1
          else
            result << [arr2[0], arr[0], z, "plunge"]
            a = 1
          end
          (a..last_rect).each { |ix| result << [arr2[ix], arr[ix], z, "cut".freeze] }
          if _2b9ddb2e < tool_index.length - 1
            result << [arr2[last_rect], arr[last_rect], _aae2b052, "rapid"] << [arr2[0], arr[0], _aae2b052, "rapid"]
          elsif slow_len.positive?
            trim_tail(result, num, slow_len)
          end
        end
        result << [arr2[last_rect], arr[last_rect], Calc.round2(z2), "rapid"]
      end
      def trim_tail(result, a, length)
        rest = length
        idx = result.length - 1
        while idx > a && rest > 1.0e-6
          arr, b = result[idx - 1, 2]
          break unless b[3] == "cut"
          pts = Math.hypot(b[0] - arr[0], b[1] - arr[1])
          if pts <= rest + 1.0e-6
            b[3] = "slow"
            rest -= pts
          else
            t = (pts - rest) / pts
            result.insert(idx, arr22(Calc.lerp(arr, b, t), arr[2] + (b[2] - arr[2]) * t, "cut"))
            result[idx + 1][3] = "slow"
            rest = 0.0
          end
          idx -= 1
        end
      end
      def round_xy(pt, depths)
        x = Calc.round2(pt[0])
        y = Calc.round2(pt[1])
        z = Calc.round2(depths[0])
        [[x, y, z, "rapid"], [x, y, Calc.round2(depths[1]), "rapid"],
         [x, y, Calc.round2(depths[2].last), "plunge"], [x, y, z, "rapid"]]
      end
      def arr22(pt, z, tag)
        [Calc.round2(pt[0]), Calc.round2(pt[1]), Calc.round2(z), tag]
      end
      def round_path(rows)
        rows.each_with_object([]) do |arr, ok|
          pt = [Calc.round2(arr[0]), Calc.round2(arr[1])]
          last_rect = ok.last
          ok << pt unless last_rect && (last_rect[0] - pt[0]).abs <= 0.002 && (last_rect[1] - pt[1]).abs <= 0.002
        end
      end
      def sheet_fields(arr, meta)
        vectors = arr[:vectors]
        material, lbl = material_and_label(arr[:name], vectors, sheet_scope(arr, meta)[:do_day_van])
        { material: material, label: lbl, bottom: Export.work_face(vectors) == :back }
      end
      def material_key(sheet)
        arr = front_of(sheet)
        material_and_label(arr[:name], arr[:vectors], Export.sheet_thickness(arr))[0]
      end
      def front_of(sheet)
        @arr37 ||= begin
          sheets = @sheet_rows ? @sheet_rows[1] : []
          sheets = [] if sheets.none? { |fld| Export.work_face(fld[:vectors]) == :back }
          h7 = sheets.group_by { |fld| fld[:physical_override] || Export.layout_key(fld) }
          h7.each_value.with_object({}.compare_by_identity) do |src, arr37|
            _05b497c8 = src.find { |fld| Export.work_face(fld[:vectors]) == :front }
            src.each { |fld| arr37[fld] = _05b497c8 if _05b497c8 && Export.work_face(fld[:vectors]) == :back }
          end
        end
        @arr37[sheet] || sheet
      end
      def back_mismatch_note(arr)
        _05b497c8 = front_of(arr)
        return if _05b497c8.equal?(arr)
        h13 = (@h13 ||= {}.compare_by_identity)
        return h13[arr] if h13.key?(arr)
        lbl = material_and_label(arr[:name], arr[:vectors], nil)[1]
        h13[arr] = Export.back_mismatch_note(arr, _05b497c8, "#{lbl}#{Text.t(:van, :mat)}")
      end
      def material_and_label(name, vectors, thickness)
        text = name.to_s.sub(/_MAT_(?:SAU|TRUOC)\z/, '')
        arr = text.match(/\A_*(.+?)[-_ ]+sheet[-_ ]*(\d+)\z/i)
        vec = vectors.find(&:sheet_entity)
        _b08724af = vec ? Export.all_attributes(vec.sheet_entity).to_h : {}
        id = _b08724af["ABF.sheet-id"].to_s.strip
        id = arr ? arr[2] : text if id.empty?
        material = _b08724af["KSU.sheet-material"].to_s.strip
        material = _b08724af["ABF.sheet-type"].to_s.strip if material.empty?
        material = arr ? arr[1] : '' if material.empty?
        return [material, id] if material.empty? || thickness.nil?
        normal = material.sub(/\s*[-–]?\s*\d+(?:[.,]\d+)?\s*mm\s*\z/i, '').strip
        normal = material if normal.empty?
        num = thickness.round(1)
        ["#{normal} - #{num % 1 == 0 ? num.round : num}mm", id]
      end
      def layer_color(layer, meta)
        name = layer.to_s
        meta[:colors][name] ||= begin
          color = layer_color_hex(meta[:model], name)
          key = Util.alnum_upper(name) if color.empty?
          colors = { "CUTTINGLINES" => "#999900", "SHEETBORDER" => "#ff7f00", "MARKSQUARE" => "#0000ff", "PARTBORDER" => "#ff69b4" } if key
          key ? colors.find { |suffix, _| key.end_with?(suffix) }.to_a.last.to_s : color
        end
      end
      def layer_of(model, name)
        model.layers[name == "Untagged" ? "Layer0" : name]
      end
      def layer_color_hex(model, name)
        layer_name = layer_of(model, name)
        return '' unless layer_name
        color = layer_name.color
        format("#%02x%02x%02x", color.red, color.green, color.blue)
      end
      def cutter_color(tool, meta)
        str2 = meta[:cutter_by_id][tool["cutter_id"].to_s] || meta[:cutter_by_no][tool["number"].to_i]
        str = (str2 && str2["color"]).to_s.strip
        str = tool["draw_color"].to_s.strip if str.empty?
        str.match?(/\A#[0-9a-fA-F]{6}\z/) ? str : "#e53935"
      end
      def tool_shape(tool)
        return "drill" if tool["cutter_type"].to_s == "drill_bit" || tool["type"].to_s == "drill"
        tool["cutter_type"].to_s == "v_bit" ? "vbit" : "endmill"
      end
      reset2
    end
  end
end
