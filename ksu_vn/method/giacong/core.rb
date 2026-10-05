module KSU
  module Cnc
    ROOT_DIR = File.expand_path("../..", __dir__)
    module_function
    def database
      @run&.database
    end
    def set_run(reader)
      @run = reader
    end
    module Util
      module_function
      def fetch_required(h, key)
        return h[key] if h.key?(key)
        str = key.to_s
        return h[str] if h.key?(str)
        raise ArgumentError, "missing #{key}"
      end
      def lookup(h, key)
        h.key?(key) ? h[key] : h[key.to_s]
      end
      def truthy?(str)
        str == true || str.to_s.strip.downcase == "true" || str.to_s == "1"
      end
      def enabled?(str)
        str == true || %w[1 true yes on enabled].include?(str.to_s.strip.downcase)
      end
      def bool_or(str, default)
        case str
        when true, 1 then return true
        when false, 0 then return false
        when String
          id_str = str.strip.downcase
          return true if %w[1 true yes on enabled bat bật].include?(id_str)
          return false if %w[0 false no off disabled tat tắt].include?(id_str)
        end
        default
      end
      def clamp_float(val, lo, hi, default)
        number = Float(val, exception: false)
        (number&.finite? ? number : default.to_f).clamp(lo, hi)
      end
      def alnum_upper(text)
        str = text.to_s.upcase
        str.ascii_only? ? str.delete("^A-Z0-9") : str.gsub(/[^A-Z0-9]+/, '')
      end
      def dup_array_values(_0d6b8add)
        _0d6b8add.transform_values { |h| h.is_a?(Array) ? h.dup : h }
      end
      def freeze_rows(elems)
        Array(elems).map do |_0d6b8add|
          _0d6b8add.transform_values { |arr| arr.is_a?(Array) ? arr.map(&:to_f).freeze : arr }.freeze
        end.freeze
      end
      def fake_closed?(vec)
        !!vec.instance_variable_get(:@fake_closed)
      end
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
    module Export
      MM_PER_INCH = 25.4
      PASS_LIMIT = 200
      DISPLAY_TOOL_KEYS = %w[
        color draw_color name config_name cutter_name rpm feed plunge
        toc_do_giam_toc tu_dong_giam_toc khoang_cach_giam_toc cao_an_toan
      ].freeze
      FrozenExport = Struct.new(:database, :model, keyword_init: true)
      RUN_SCOPE_KEY = :ksu_cnc_preview
      ZERO_LEN_MM = 0.01
      CHAIN_GAP_MM = 0.1
      CHAIN_CLOSE_MM = 0.20
      CLOSED_GAP_MM = 0.005
      POCKET_CLEARANCE_MM = 0.025
      ARC_SAMPLE_MM = 0.005
      NATIVE_MATCH_MM = 0.03
      NARROW_SAMPLE_MM = 0.002
      NARROW_SCHEMA = "xnc_narrow_lock_v1".freeze
      REGION_SCHEMA = "xnc_region_lock_v1".freeze
      RESCUE_SAMPLE_MM = 0.0005
      RESCUE_SOURCE_MM = 0.01
      RESCUE_CHANGE_MM = 0.45
      EXACT_START_MM = 1.0e-5
      NODE_TOLERANCE_MM = 0.00001
      MARK_ARC_TOLERANCE_MM = 0.002
      MARK_TANGENT_TOLERANCE = 0.002
      WRITER_TOLERANCE_MM = 0.003
      MIN_ARC_R_MM = 0.01
      ARC_EQ_EPS = 1.0e-12
      FILENAME_MAX_LENGTH = 40
      NEIGHBORS = [-1, 0, 1].product([-1, 0, 1]).map(&:freeze).freeze
    end
    module Natural
      module_function
      def key(name)
        text = name.to_s.strip.upcase.tr("Đ", "D").gsub(/[\s_\-\.]+/, '')
        arr29 = text.scan(/\d+|\D+/).map { |grp| grp.match?(/\A\d+\z/) ? [1, grp.to_i] : [0, grp] }
        arr29 << [2, name.to_s.upcase]
      end
    end
    class Record
      attr_accessor :nesting_id, :sheet_id, :board_id, :part_id, :nesting_name, :sheet_name, :board_name, :part_name,
                    :layer_name, :vector_type, :operation_type, :closed, :points, :center, :radius, :diameter_mm,
                    :entity, :source_path, :src_path_ids, :board_entity, :board_chain, :sheet_entity, :part_entity,
                    :work_face, :root_sheet_name, :root_sheet_id, :latch_side, :latch_seq, :latch_row
      def initialize
        @nesting_id = @sheet_id = @board_id = @part_id = @nesting_name = @sheet_name = @board_name = @part_name = nil
        @layer_name = "Untagged"
        @vector_type = :edge
        @operation_type = :unknown
        @closed = false
        @points = []
        @center = @radius = @diameter_mm = @entity = @board_entity = @sheet_entity = @part_entity = nil
        @source_path = []
        @src_path_ids = []
        @board_chain = []
        @work_face = :front
        @root_sheet_name = @root_sheet_id = @latch_side = @latch_seq = @latch_row = nil
      end
    end
    class Database
      attr_reader :vectors
      def initialize
        @vectors = []
        @h10 = Hash.new { |arr, key| arr[key] = [] }
        reset_cache
      end
      def clear
        @vectors.clear
        @h10.clear
        reset_cache
      end
      def add(vec)
        @vectors << vec
        @h10[vec.layer_name.to_s] << vec
        reset_cache
        vec
      end
      def count
        @vectors.length
      end
      def layers
        @arr16 ||= @h10.keys.reject(&:empty?).sort_by { |name| Natural.key(name) }
      end
      def by_layer(name)
        @h10[name.to_s].dup
      end
      def each_layer(&blk)
        @h10.each(&blk)
      end
      def sheets
        @sheets ||= begin
          h = {}
          @vectors.each do |vec|
            nesting = (h[group_key(vec.nesting_id, vec.nesting_name, "NESTING")] ||= {})
            _3150250a = group_key(vec.sheet_id, vec.sheet_name, "SHEET")
            arr = (nesting[_3150250a] ||= { id: _3150250a, name: vec.sheet_name || "TAM_KHONG_TEN", boards: {}, vectors: [] })
            arr[:boards][group_key(vec.board_id, vec.board_name, "BOARD")] ||= { name: vec.board_name || "BOARD_KHONG_TEN" }
            arr[:vectors] << vec
          end
          h.values.flat_map(&:values)
        end
      end
      def layer_stats
        @layer_stats_cache ||= begin
          rows = {}
          @vectors.each do |vec|
            row = (rows[vec.layer_name.to_s.empty? ? "Untagged" : vec.layer_name] ||= { total: 0, boards: {} })
            row[:total] += 1
            board = vec.board_id || (vec.board_entity ? vec.board_entity.entityID : vec.board_name)
            row[:boards][board] = true if board
          end
          rows.sort_by { |name, _a725f564| Natural.key(name) }
                 .to_h { |name, row| [name, { total: row[:total], board_count: row[:boards].length }] }
        end
      end
      private
      def reset_cache
        @arr16 = @sheets = @layer_stats_cache = nil
      end
      def group_key(id, name, fallback)
        text = id.to_s.strip
        return text unless text.empty?
        lbl = name.to_s.strip
        lbl.empty? ? fallback : "NAME:#{lbl.upcase}"
      end
    end
    module Naming
      module_function
      def squish(str)
        str.to_s.gsub(/[\s_-]+/, " ").strip
      end
      def strip_face_suffix(str)
        str.to_s.strip.sub(/(?:[-_\s]*(?:mat[-_\s]?(?:truoc|sau)|front|back|top|bottom))\z/i.freeze, '').strip
      end
      def clean_sheet_label(val)
        text = squish(strip_face_suffix(val)
          .sub(/(?:[-_\s]*sheet[-_\s]*\d+)(?:[-_\s]*(?:mat[-_\s]?(?:truoc|sau)|front|back|top|bottom))?\z/i.freeze, '')
          .sub(/\A_+/, '').strip)
        placeholder_name?(text) ? '' : text
      end
      def placeholder_name?(val)
        text = squish(val)
        text.empty? || text.match?(/\A(?:ABF[\s_-]*NESTING|NESTING|SHEET[\s_-]*\d*|TAM[\s_-]*KHONG[\s_-]*TEN)\z/i.freeze)
      end
      def lbl(root_sheet_names:, sheet_name:, nesting_name:)
        h6 = Hash.new { |arr3, name| arr3[name] = clean_sheet_label(name) }
        arr2 = Array(root_sheet_names).map(&h6).reject(&:empty?)
        return arr2.group_by(&:itself).max_by { |name, rows| [rows.length, name.length] }.first unless arr2.empty?
        arr = clean_sheet_label(sheet_name)
        return arr unless arr.empty?
        nesting = squish(nesting_name)
        return nesting unless placeholder_name?(nesting)
        fallback = squish(strip_face_suffix(sheet_name))
        return fallback unless placeholder_name?(fallback)
        "NESTING"
      end
      def safe_filename(lbl)
        text = squish(lbl).tr(",", ".").sub(/\s+(\d+(?:\.\d+)?\s*mm)\z/i, "-\\1")
        text = text.gsub(/[\\\/:*?"<>|]+/, " ").gsub(/\s+/, " ").strip
        text = text.gsub(/\s*mm\z/i) { |th_txt| th_txt.gsub(/\s+/, '').downcase }
        text.empty? ? "NESTING" : text
      end
      def strip_thickness(lbl)
        text = squish(lbl).tr(",", ".")
        normal = text.sub(/\s+\d+(?:\.\d+)?\s*mm\z/i, '').strip
        normal.empty? ? text : normal
      end
      def sheet_number(*vars)
        vars.flatten.compact.each do |str|
          number = str.to_s.scan(/(?:sheet|tam|tấm)[\s_\-]*0*(\d+)/i).last&.first.to_i
          return number if number&.positive? && number < 10_000
        end
        nil
      end
      def label_fingerprint(lbl)
        Util.alnum_upper(squish(lbl))
      end
    end
    module Latch
      SECTION = "chong_bay".freeze
      ATTR_DICT = "ABF".freeze
      module_function
      def reset
        @side_names = nil
        @h20 = {}
      end
      def side_names
        @side_names ||= %w[tren duoi trai phai chung].to_h do |key|
          [key, setting("ten_#{key}", key == "chung" ? "LAYER" : key.upcase).to_s.strip]
        end
      end
      def setting(key, fallback)
        val = preset_settings[key]
        val.nil? ? ::KSU::Settings.get_raw(key, fallback, SECTION) : val
      rescue StandardError
        fallback
      end
      def preset_settings
        _2c5f4908 = ::KSU::Settings.get_raw("cai_dat_mau", nil, SECTION)
        presets2 = ::KSU::Settings.get_raw("presets", nil, SECTION)
        return {} if _2c5f4908.nil? || !presets2.is_a?(Array)
        settings = (presets2.find { |fld| fld.is_a?(Hash) && fld["name"] == _2c5f4908 } || {})["settings"]
        settings.is_a?(Hash) ? settings : {}
      end
      def side_of(prefix)
        text = prefix.to_s.strip
        return if text.empty?
        %w[tren duoi trai phai].find { |side| text == side_names[side] } || ('' if text == side_names["chung"] || text == "Lớp")
      end
      def decode_glyph(grp)
        name = grp.respond_to?(:name) ? grp.name.to_s : grp.to_s
        flag = grp.respond_to?(:get_attribute) ? grp.get_attribute(ATTR_DICT, "cutting-layer-postfix") : nil
        if flag.nil?
          return unless (arr = name.match(/\A(.*?)\s*(\d+)\z/))
          prefix, num = arr[1], arr[2].to_i
        else
          prefix, num = grp.get_attribute(ATTR_DICT, "cutting-layer-original-name").to_s, flag.to_i
        end
        side = side_of(prefix)
        return if side.nil?
        { tag: name, row: prefix.strip, side: side, seq: [num, 0].max }
      end
      def side_for_layer(layer, model)
        text = layer.to_s
        return @h20[text] if @h20.key?(text)
        rec = decode_glyph(model.layers[text] || text)
        @h20[text] = rec && rec[:side]
      end
      def cutting_lines?(entity)
        name = entity.name.to_s
        name = entity.definition.name.to_s if name.empty? && entity.is_a?(::Sketchup::ComponentInstance)
        %w[_ABF_cuttingLines ABF_cuttingLines].include?(name) || Util.truthy?(entity.get_attribute(ATTR_DICT, "is-cutting-lines")) ||
          Util.truthy?(entity.get_attribute(ATTR_DICT, "is_cutting_lines"))
      end
      def merge_latch(meta, entity)
        rec = cutting_lines?(entity) && decode_glyph(entity.layer)
        meta.merge!(latch_side: rec[:side], latch_seq: rec[:seq], latch_row: rec[:row], latch_tag: rec[:tag]) if rec
      end
      def apply_latch(rec, meta, _5eec405a)
        str = meta[:latch_row].to_s
        return unless _5eec405a && !str.empty?
        num = meta[:latch_seq].to_i
        rec.layer_name = rec.latch_row = str
        rec.latch_side = meta[:latch_side].to_s
        rec.latch_seq = num.positive? ? num : nil
      end
      def latched?(rec)
        !rec.latch_row.to_s.empty?
      end
    end
    class Abf
      class EditActive < StandardError; end
    end
    class Reader
      GROOVE_NAME_RE = /(?:GROOVE|SLOT|DADO|RABBET|CHANNEL|SAWCUT|RANH|RÃNH)/i
      attr_reader :database, :model
      def initialize(model)
        @model = model
        @database = Database.new
        @h22 = {}
        @h17 = {}
        @h6 = Hash.new { |arr, kind| arr[kind] = {} }
      end
      def scan
        [@database, @h22, @h17, @h6].each(&:clear)
        @last_matrix = nil
        Latch.reset
        arr = nesting_roots
        assert_not_editing(arr)
        arr.each do |nesting|
          walk(nesting, nesting.transformation, child_meta(nesting, {}, [], :nesting), [entity_name(nesting)], false, [nesting])
        end
        unify_sheets
        @database
      end
      private
      def cached(kind, key)
        cache = @h6[kind]
        cache.fetch(key) { cache[key] = yield }
      end
      def nesting_roots
        @model.entities.select do |entity|
          next false unless entity.is_a?(::Sketchup::Group) || entity.is_a?(::Sketchup::ComponentInstance)
          entity_name(entity) == "__ABF_Nesting" || entity.get_attribute("ABF", "is-nesting") == true ||
            entity.get_attribute("ABF", "is_nesting") == true
        end
      end
      def assert_not_editing(arr)
        arr.each do |nesting|
          entities_of(nesting).each do |entity|
            next unless entity.is_a?(::Sketchup::Group) || entity.is_a?(::Sketchup::ComponentInstance)
            offset_path = entity.get_attribute("KSU", "nest_edit_offset")
            raise Abf::EditActive, Text.t(:quet, :dang_sua) if offset_path.is_a?(Array) && offset_path.length == 2
          end
        end
      end
      def walk(ents3, tf, meta, path, in_cut, chain)
        entities_of(ents3).each do |entity|
          tag = entity.layer.name
          next if ignored_name?(entity_name(entity)) || ignored_name?(tag)
          case entity
          when ::Sketchup::Group, ::Sketchup::ComponentInstance
            walk(entity, tf * entity.transformation, child_meta(entity, meta, chain),
                           path + [entity_name(entity)], in_cut || Latch.cutting_lines?(entity), chain + [entity])
          when ::Sketchup::Edge
            next if cached(:note, tag) do
              tag.match?(/label|text|dimension|\bdim\b|annotation|note|ghi.?ch[uú]|k[ií]ch.?th[uươớ]{1,2}c|ch[uú].?th[ií]ch|guide/i)
            end
            read_edge(entity, tf, meta, path, in_cut, chain)
          end
        end
      end
      def read_edge(edge, tf, meta, path, in_cut, chain)
        lp = edge.curve
        key = [lp.entityID, matrix_id(tf.to_a)] if lp
        return if @h22[key]
        layer = edge.layer.name
        layer = meta[:container_layer] || "Untagged" if untagged?(layer)
        return if ignored_name?(layer) || ignored_name?(path.first)
        flag = layer.match?(/\AABF_/i.freeze)
        groove = groove_name?(layer) || (!flag && groove_entity?(edge, path))
        return unless groove || flag || in_cut ||
                      layer.match?(/\AABF[-_]?(?:D(?:3|5|8|10|15)|partBorder|sheetBorder|markSquare)\z/i) ||
                      attr_true?(edge, "is-outer-loop") || cut_layer?(edge, layer, meta, path)
        layer = groove_layer_name(edge, layer, path) if groove
        if lp
          @h22[key] = true
          read_curve(lp, tf, meta, path, layer, chain)
        else
          rec = new_record(edge, meta, path, layer, chain)
          rec.operation_type = operation_for(layer, :edge, false)
          rec.points = [edge.start.position, edge.end.position].map { |pt| pt.transform(tf) }
          @database.add(rec)
        end
      end
      def matrix_id(vars)
        return @matrix_id if vars.eql?(@last_matrix)
        arr = @h6[:matrix]
        @last_matrix = vars
        @matrix_id = arr[vars.map { |num| num.to_f.round(12) }] ||= arr.length
      end
      def read_curve(lp, tf, meta, path, layer, chain)
        rec = new_record(lp.edges.first, meta, path, layer, chain)
        arr, rec.closed = trace_loop(lp)
        rec.points = arr.map { |pt| pt.transform(tf) }
        if lp.is_a?(::Sketchup::ArcCurve)
          center = lp.center
          rec.center = center.transform(tf)
          rec.radius = rec.center.distance(center.offset(lp.xaxis, lp.radius).transform(tf))
          rec.diameter_mm = rec.radius.to_f * 2.0 * Export::MM_PER_INCH if rec.closed
          rec.vector_type = rec.closed ? :circle : :arc
        else
          rec.vector_type = :polyline
        end
        rec.operation_type = operation_for(layer, rec.vector_type, rec.closed)
        @database.add(rec)
      end
      def new_record(entity, meta, path, layer, chain)
        rec = Record.new
        rec.nesting_id, rec.sheet_id, rec.board_id, rec.part_id = meta.values_at(:nesting_id, :sheet_id, :board_id, :part_id)
        rec.nesting_name, rec.sheet_name, rec.board_name, rec.part_name = meta.values_at(:nesting, :sheet, :board, :part)
        rec.sheet_entity, rec.board_entity, rec.part_entity = meta.values_at(:sheet_entity, :board_entity, :part_entity)
        rec.root_sheet_name = meta[:root_sheet_name] || meta[:sheet]
        rec.root_sheet_id = meta[:root_sheet_id] || meta[:sheet_id]
        rec.work_face = meta[:work_face] || :front
        rec.layer_name = layer
        rec.entity = entity
        rec.source_path = path.dup
        rec.src_path_ids = chain.map { |fld| stable_id(fld, "G") }
        rec.board_chain = (meta[:board_chain] || []).dup
        Latch.apply_latch(rec, meta, Latch.side_for_layer(layer, @model) == meta[:latch_side].to_s)
        rec
      end
      def trace_loop(lp)
        snap_edges = lp.edges
        h = Hash.new { |arr2, key| arr2[key] = [] }
        snap_edges.each do |edge|
          h[edge.start] << [edge, edge.end]
          h[edge.end] << [edge, edge.start]
        end
        closed = h.values.all? { |arr| arr.length == 2 }
        cur = h.find { |_a1d9572f, arr| arr.length == 1 }&.first || snap_edges.first.start
        out = [cur.position]
        taken = {}
        while out.length <= snap_edges.length
          _d0d97483 = h[cur].find { |edge, _f8cb0809| !taken[edge.entityID] }
          break unless _d0d97483
          edge, cur = _d0d97483
          taken[edge.entityID] = true
          out << cur.position
        end
        [out, closed]
      end
      def operation_for(layer, _c48d8e0b, closed)
        th_txt = fingerprint(layer)
        return :reference if th_txt == "ABFPARTBORDER" || th_txt == "ABFSHEETBORDER"
        return :hole if closed && layer.strip.match?(/\AABF[-_\s]?D(\d+(?:[.,]\d+)?)(?=[^0-9.,]|$)/i)
        return :drill if closed && th_txt.match?(/DRILL|HOLE|KHOAN/)
        return :groove if th_txt.match?(/RANH|GROOVE|SLOT|DADO|RABBET|CHANNEL|SAWCUT|HEM/)
        return :pocket if closed && th_txt.match?(/POCKET|HOC|HANEN|BAONEN/)
        return :engrave if th_txt.match?(/ENGRAV|KHAC|VCARVE|DANHDAU/)
        return :profile if closed && th_txt.match?(/PROFILE|CUT|CONTOUR|OUTSIDE|INSIDE|CAT/)
        return :hole if _c48d8e0b == :circle
        closed ? :profile : :engrave
      end
      def cut_layer?(edge, layer, meta, path)
        name = layer.strip
        return false if untagged?(name) || name.match?(/\AABF_/i.freeze) ||
                        name.match?(/\A(?:LAYER0|UNTAGGED|DEFAULT|NESTING|SHEET|BOARD|PART|PANEL|STOCK|PHOI|PHÔI|TAM|TẤM|VAN|VÁN)\z/i.freeze)
        _e976ebfe = /(?:PROFILE|CUT(?:TING)?|CONTOUR|OUTSIDE|INSIDE|CAT|CẮT|POCKET|HOC|HỐC|HA[_\s-]?NEN|HẠ[_\s-]?NỀN|BAO[_\s-]?NEN|BÀO[_\s-]?NỀN|DRILL|HOLE|KHOAN|GROOVE|SLOT|DADO|RABBET|CHANNEL|RANH|RÃNH|HEM|HÈM|ENGRAV|KHAC|KHẮC|V[-_\s]?CARVE|MARK|DANH[_\s-]?DAU|ĐÁNH[_\s-]?DẤU)/i.freeze
        !untagged?(edge.layer.name.strip) || (!untagged?(meta[:container_layer]) && !meta[:sheet_id].nil?) ||
          name.match?(_e976ebfe) || path.any? { |fld| fld.match?(_e976ebfe) } ||
          ((!meta[:part_id].nil? || !meta[:board_id].nil?) && !edge.curve.nil?)
      end
      def groove_entity?(entity, path)
        return true if path.any? { |name| groove_name?(name) }
        return true if %w[is-groove is_groove groove slot dado rabbet channel sawcut is-slot is_slot]
                       .any? { |key| Util.truthy?(entity.get_attribute("ABF", key)) }
        abf_attributes(entity).any? do |key, str|
          key.to_s.match?(GROOVE_NAME_RE) || str.to_s.match?(GROOVE_NAME_RE)
        end
      end
      def groove_layer_name(entity, _27fe1276, path)
        return _27fe1276 unless untagged?(_27fe1276)
        _38d7e310 = path.reverse.find { |name| groove_name?(name) }
        return _38d7e310 if _38d7e310
        arr = abf_attributes(entity).find do |key, str|
          key.to_s.match?(/layer|operation|type|name/i) && str.to_s.match?(GROOVE_NAME_RE)
        end
        arr ? arr[1].to_s : "ABF-Groove"
      end
      def groove_name?(name)
        cached(:groove, name) { name.match?(GROOVE_NAME_RE) }
      end
      def fingerprint(str)
        return Util.alnum_upper(str) if str.ascii_only?
        str.upcase
             .tr("ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴĐÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸ",
                 "AAAAAAAAAAAAAAAAADEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYY")
             .gsub(/[^A-Z0-9]/, '')
      end
      def ignored_name?(val)
        return false if val.ascii_only? && val.match?(/[0-9]/)
        cached(:ignored, val) { %w[ABFEDGEBANDING ABFLABEL PTLARROW ABFSHEETID ABFSHEETMATERIAL].include?(fingerprint(val)) }
      end
      def attr_true?(entity, key)
        Util.truthy?(entity.get_attribute("ABF", key)) || Util.truthy?(entity.get_attribute("ABF", key.tr("-", "_")))
      end
      def untagged?(name)
        name.nil? || name.empty? || name == "Layer0" || name == "Untagged"
      end
      def entities_of(entity)
        entity.is_a?(::Sketchup::Group) ? entity.entities : entity.definition.entities
      end
      def entity_name(entity)
        key = entity_key(entity)
        @h17.fetch(key) do
          name = entity.respond_to?(:name) ? entity.name.to_s : ''
          name = entity.definition.name.to_s if name.empty? && entity.is_a?(::Sketchup::ComponentInstance)
          @h17[key] = name.empty? ? "#{entity.typename}-#{entity.entityID}" : name
        end
      end
      def abf_attributes(entity)
        cached(:attributes, entity_key(entity)) do
          h7 = []
          (entity.attribute_dictionaries || []).each do |h|
            h.each_pair { |name, val| h7 << [name, val] } if h.name.upcase.include?("ABF")
          end
          h7
        end
      end
      def entity_key(entity)
        id = entity.persistent_id
        id.positive? ? id : entity.object_id
      end
      def child_meta(entity, defn, h, _bcdae5c5 = nil)
        meta = defn.dup
        name = entity_name(entity)
        layer = entity.layer.name
        meta[:container_layer] = layer unless untagged?(layer)
        Latch.merge_latch(meta, entity)
        flag = _bcdae5c5
        flag ||= :board if attr_true?(entity, "is-board")
        flag ||= :sheet if name.match?(/(?:\A|[-_])sheet(?:[-_]|\z)/i) || !entity.get_attribute("ABF", "sheet-id").nil? ||
                           !entity.get_attribute("ABF", "sheet_id").nil? || attr_true?(entity, "is-sheet")
        flag ||= :board if name.match?(/\ABoard\b/i)
        flag ||= :part if name.match?(/\APart\b/i) || attr_true?(entity, "is-part")
        case flag
        when :nesting
          meta.merge!(nesting: name, nesting_id: stable_id(entity, "N"))
        when :sheet
          _eb120d6a, font = split_face(name)
          str = "SB:#{slug(_eb120d6a)}"
          meta.merge!(sheet: _eb120d6a, root_sheet_name: _eb120d6a, root_sheet_id: str,
                         sheet_id: "#{str}:#{font.to_s.upcase}", work_face: font, sheet_entity: entity,
                         board: nil, board_id: nil, board_entity: nil, part: nil, part_id: nil, part_entity: nil)
        when :board
          meta.merge!(board: name, board_id: attr_id(entity, %w[board-id board_id id], "B"), board_entity: entity,
                         board_chain: h.dup, part: nil, part_id: nil, part_entity: nil)
        when :part
          meta.merge!(part: name, part_id: attr_id(entity, %w[part-id part_id id], "P"), part_entity: entity)
        end
        meta
      end
      def split_face(name)
        return [name.sub(/[-_](?:bottom|back|mat[-_ ]?sau)\z/i, ''), :back, true] if name.match?(/[-_](?:bottom|back|mat[-_ ]?sau)\z/i)
        return [name.sub(/[-_](?:top|front|mat[-_ ]?truoc)\z/i, ''), :front, true] if name.match?(/[-_](?:top|front|mat[-_ ]?truoc)\z/i)
        [name, :front, false]
      end
      def slug(name)
        Util.alnum_upper(name)
      end
      def unify_sheets
        groups = @database.vectors.group_by do |rec|
          str2 = rec.sheet_entity && stable_id(rec.sheet_entity, "SHEETNODE")
          str2 ||= "SHEETNODE:#{rec.nesting_id}:#{rec.src_path_ids.join(' > ')}:#{rec.sheet_name}"
          [rec.nesting_id.to_s, str2]
        end
        groups.each_value do |arr|
          sample_tol_mm = arr.first
          str, font, str3 = split_face(sample_tol_mm.sheet_entity ? entity_name(sample_tol_mm.sheet_entity) : sample_tol_mm.sheet_name.to_s)
          font = arr.any? { |rec| rec.layer_name.match?(/\AABF[-_]?markSquare\z/i) } ? :back : :front unless str3
          str = str.strip
          str = sample_tol_mm.root_sheet_name.to_s.strip if str.empty?
          str = sample_tol_mm.sheet_name.to_s.strip if str.empty?
          str4 = "SB:#{slug(str)}"
          arr.each do |rec|
            rec.work_face = font
            rec.root_sheet_name = str
            rec.root_sheet_id = str4
          end
        end
        src = Hash.new { |arr2, key| arr2[key] = {} }
        @database.vectors.each { |rec| src[[rec.nesting_id.to_s, rec.root_sheet_id]][rec.work_face] = true }
        @database.vectors.each do |rec|
          _04c36b04 = src[[rec.nesting_id.to_s, rec.root_sheet_id]]
          font = rec.work_face
          str = rec.root_sheet_name.empty? ? rec.sheet_name.to_s : rec.root_sheet_name
          rec.sheet_name = _04c36b04[:front] && _04c36b04[:back] ? "#{str}_#{font == :back ? 'MAT_SAU' : "MAT_TRUOC"}" : str
          rec.sheet_id = "#{rec.root_sheet_id}:#{font.to_s.upcase}"
        end
      end
      def attr_id(entity, keys, prefix)
        keys.each do |key|
          str = entity.get_attribute("ABF", key)
          return "#{prefix}:#{str}" unless str.to_s.strip.empty?
        end
        stable_id(entity, prefix)
      end
      def stable_id(entity, prefix)
        id = entity.persistent_id
        "#{prefix}:#{id.positive? ? id : entity.entityID}"
      end
    end
    module Polygon
      TOLERANCE_MM = 0.001
      module_function
      def clean_ring(out)
        rows = out.map { |pt| [pt[0].to_f, pt[1].to_f] }
        rows.pop while rows.length > 1 && Calc.distance(rows.first, rows.last) <= TOLERANCE_MM
        outer_loop = []
        rows.each { |pt| outer_loop << pt unless outer_loop.any? && Calc.distance(outer_loop.last, pt) <= TOLERANCE_MM }
        outer_loop.pop if outer_loop.length > 2 && Calc.distance(outer_loop.first, outer_loop.last) <= TOLERANCE_MM
        outer_loop.shift while outer_loop.length > 3 && Calc.distance(outer_loop.last, outer_loop.first) < TOLERANCE_MM
        outer_loop
      end
      def polygon_ok?(out)
        rows = clean_ring(out)
        want = rows.length
        return { intersects: false } if want < 4
        return { intersects: nil } if want > 6000
        segments = Array.new(want) do |idx|
          arr = rows[idx]
          b = rows[(idx + 1) % want]
          [idx, arr, b, [arr[0], b[0]].min, [arr[0], b[0]].max, [arr[1], b[1]].min, [arr[1], b[1]].max]
        end
        active_ix = []
        segments.sort_by { |arr2| arr2[3] }.each do |seg|
          idx, arr, b, lx, _b0566a11, _2d7e228f, _897789b7 = seg
          _fe479353 = lx - TOLERANCE_MM
          active_ix.reject! { |arr2| arr2[4] < _fe479353 }
          active_ix.each do |panel|
            num = (idx - panel[0]).abs
            next if num <= 1 || num == want - 1
            next unless _b0566a11 >= panel[3] - TOLERANCE_MM && panel[4] >= _fe479353 &&
                        _897789b7 >= panel[5] - TOLERANCE_MM && panel[6] >= _2d7e228f - TOLERANCE_MM
            pt = Calc.proper_crossing(arr, b, panel[1], panel[2])
            return { intersects: true, pair: [panel[0], idx], point: pt } if pt
          end
          active_ix << seg
        end
        { intersects: false }
      end
    end
    module Open
      module_function
      def offset_ring(out, distance, _589df0d9)
        rows = out.each_with_object([]) { |pt, entries| entries << pt unless entries.last && Calc.distance(pt, entries.last) < 1.0e-9 }
        want = rows.length
        return nil if want < 2
        arr3 = rows.each_cons(2).map do |arr5, b|
          dx = b[0] - arr5[0]
          dy = b[1] - arr5[1]
          length = Math.hypot(dx, dy)
          [(-dy / length) * _589df0d9, (dx / length) * _589df0d9]
        end
        ctrl = ->(arr4, ref_p2) { [arr4[0] + (ref_p2[0] * distance), arr4[1] + (ref_p2[1] * distance)] }
        ok = [ctrl.call(rows.first, arr3.first)]
        (1...(want - 1)).each do |i|
          arr2 = arr3[i - 1]
          arr = arr3[i]
          start_x = arr2[0] + arr[0]
          ly0 = arr2[1] + arr[1]
          length = Math.hypot(start_x, ly0)
          next ok << ctrl.call(rows[i], arr) if length < 1.0e-9
          dot = (arr2[0] * arr[0]) + (arr2[1] * arr[1])
          _833097b6 = Math.sqrt([(1.0 + dot) / 2.0, 0.0].max)
          if _833097b6 >= 0.25
            upm = 1.0 / _833097b6
            ok << [rows[i][0] + ((start_x / length) * distance * upm), rows[i][1] + ((ly0 / length) * distance * upm)]
          else
            ok << ctrl.call(rows[i], arr2) << ctrl.call(rows[i], arr)
          end
        end
        ok << ctrl.call(rows.last, arr3.last)
      end
      def offset_with_border(out, r, side, border)
        left = offset_ring(out, r, 1.0)
        return nil unless left
        b2 = offset_ring(out, r, -1.0)
        bb2, bb = out.transpose unless border
        _ba5231eb = border || [(bb2.min + bb2.max) / 2.0, (bb.min + bb.max) / 2.0]
        _c059a7b8 = Calc.mean_distance(left, _ba5231eb)
        _d8db7287 = Calc.mean_distance(b2, _ba5231eb)
        return nil if (_c059a7b8 - _d8db7287).abs <= [0.05, r.abs * 0.02].max
        (_c059a7b8 < _d8db7287) == (side == "inside") ? left : b2
      end
    end
    module Mark
      POINT_TOL_MM = 0.001
      module_function
      def to_segments(out, tool_radius:, ramp_len_mm: nil)
        r = Calc.positive_float(tool_radius)
        rows = convex?(out)
        return failure(Text.t(:mat_sau, :khong_dung_dau)) unless r && rows.length == 3
        arr2, b, c = rows
        arr = Calc.unit_vector(arr2, b)
        arr3 = Calc.unit_vector(b, c)
        _a449e6cd = Math.acos([[(arr[0] * arr3[0]) + (arr[1] * arr3[1]), -1.0].max, 1.0].min)
        _3c2a5db6 = r * Math.tan(_a449e6cd * 0.5)
        _080af200 = _3c2a5db6 + POINT_TOL_MM
        tangent_in = [b[0] - (arr[0] * _3c2a5db6), b[1] - (arr[1] * _3c2a5db6)]
        _640480a7 = [b[0] + (arr3[0] * _3c2a5db6), b[1] + (arr3[1] * _3c2a5db6)]
        cw = ((arr[0] * arr3[1]) - (arr[1] * arr3[0])).negative?
        ref_p2 = cw ? [arr[1], -arr[0]] : [-arr[1], arr[0]]
        center = [tangent_in[0] + (ref_p2[0] * r), tangent_in[1] + (ref_p2[1] * r)]
        num = ((_a449e6cd * 180.0 / Math::PI) - 90.0).abs <= 1.0 && Calc.distance(arr2, b) > _080af200 && Calc.distance(b, c) > _080af200
        return failure(Text.t(:mat_sau, :khong_dung_dau)) unless num && (Calc.distance(center, _640480a7) - r).abs <= 0.002
        _34a8b7a8 = Calc.positive_float(ramp_len_mm)
        if _34a8b7a8
          return failure(Text.t(:mat_sau, :doc_ngan)) if _34a8b7a8 < 10.0
          return failure(Text.t(:mat_sau, :doc_dai)) if _34a8b7a8 > Calc.distance(arr2, tangent_in) - 1.0 + POINT_TOL_MM
        end
        ramp_point = _34a8b7a8 && [arr2[0] + (arr[0] * _34a8b7a8), arr2[1] + (arr[1] * _34a8b7a8)]
        a0 = Calc.deg4(tangent_in, center)
        sweep = Calc.normalize_sweep(Calc.deg4(_640480a7, center) - a0, !cw)
        arc = Calc.arc_points(center, r, a0, sweep, [(sweep.abs / (7.5 * Math::PI / 180.0)).ceil, 2].max)
        {
          ok: true, start: arr2, ramp_point: ramp_point, tangent_in: tangent_in, tangent_out: _640480a7,
          center: center, end_point: c, clockwise: cw, radius_mm: r, ramp_len_mm: _34a8b7a8 || 0.0,
          preview_points: finite_points([arr2, tangent_in] + arc.drop(1) + [c])
        }
      end
      def failure(reason)
        { ok: false, reason: reason }
      end
      def convex?(out)
        rows = finite_points(out)
        flag = true
        while flag && rows.length > 2
          flag = false
          result = [rows.first]
          rows[1...-1].each_with_index do |pt, idx|
            next flag = true if continues_straight?(result.last, pt, rows[idx + 2])
            result << pt
          end
          result << rows.last
          rows = finite_points(result)
        end
        rows
      end
      def finite_points(out)
        out.each_with_object([]) do |pt, rows|
          next unless pt[0].finite? && pt[1].finite?
          rows << [pt[0], pt[1]] unless rows.last && Calc.distance(rows.last, pt) <= POINT_TOL_MM
        end
      end
      def continues_straight?(arr, b, arr2)
        _ef672dce = b[0] - arr[0]
        _73792f97 = b[1] - arr[1]
        _6fff5dd9 = arr2[0] - b[0]
        _515aedb8 = arr2[1] - b[1]
        cross = (_ef672dce * _515aedb8) - (_73792f97 * _6fff5dd9)
        return false if cross.abs > 1.0e-6 * [Math.hypot(_ef672dce, _73792f97) * Math.hypot(_6fff5dd9, _515aedb8), 1.0].max
        (_ef672dce * _6fff5dd9) + (_73792f97 * _515aedb8) >= -1.0e-9
      end
    end
  end
end
