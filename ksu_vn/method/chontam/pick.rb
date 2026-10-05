class KSU::Chontam
  class << self
    def clear_caches
      @cache = nil
      @build = nil
      @arr30 = nil
      @flip_rows = nil
    end
    def panel_at(view, x, y)
      nesting = KSU::Nesting.find_nesting(notify: false)
      return nil unless nesting
      KSU::Flip.hit_panel(view, @flip_rows ||= KSU::Flip.flip_rows(nesting), x, y)
    end
    def clear_screen_cache
      @arr30 = nil
      @flip_rows = nil
    end
    def cancel_cache_build
      @build = nil
    end
    def parse_indices(text)
      arr = []
      text.to_s.split(",").each do |grp|
        grp = grp.strip
        if grp =~ /\A(\d+)\s*-\s*(\d+)\z/
          a, b = [$1.to_i, $2.to_i].minmax
          (a..b).each { |n| arr << n }
        elsif grp =~ /\A\d+\z/
          arr << grp.to_i
        end
      end
      arr.uniq
    end
    def panels_by_index(arr)
      return [] if arr.empty?
      nesting = KSU::Nesting.find_nesting(notify: false)
      return [] unless nesting
      arr2 = []
      nesting.definition.entities.each do |sheet|
        next if !KSU::Sheet.sheet?(sheet) || KSU::Sheet.bottom_sheet?(sheet)
        KSU.entities_in(sheet).each do |grp|
          next if !KSU.container?(grp) || KSU::Cutting.bottom_face?(grp) || !pickable?(grp)
          ix = grp.get_attribute("ABF", "board-index")
          next if ix.nil? || !arr.include?(ix.to_i)
          arr2.concat(twins_of(grp))
        end
      end
      arr2.compact.select(&:valid?).uniq
    end
    def drop_nested_from_selection
      h = container_ids(KSU::Nesting.find_nesting(notify: false))
      KSU.select_only(KSU.selection.reject { |grp| !root_of(grp).nil? || h.key?(grp.entityID) })
    end
    def container_ids(nesting)
      h = {}
      return h unless nesting && nesting.valid?
      h[nesting.entityID] = true
      queue = [[nesting, 0]]
      until queue.empty?
        ents3, depth = queue.shift
        (KSU.entities_in(ents3) || []).each do |grp|
          next unless KSU.container?(grp)
          h[grp.entityID] = true
          queue << [grp, depth + 1] if depth + 1 < 3
        end
      end
      h
    end
    def set_selection(model, arr, additive:, clear_on_empty:)
      arr = Array(arr).compact.select(&:valid?).uniq
      return if !additive && !clear_on_empty && arr.empty?
      cur = model.selection.to_a
      target = additive ? (cur + arr).uniq : arr
      arr2 = cur - target
      arr3 = target - cur
      model.selection.remove(arr2) if arr2.any?
      model.selection.add(arr3) if arr3.any?
    end
    def add_to_selection(model, container)
      arr = Array(container).select { |vec| vec.valid? && !model.selection.contains?(vec) }
      return [] if arr.empty?
      model.selection.add(arr)
      arr
    end
    def drop_from_selection(model, container)
      arr = Array(container).select { |vec| vec.valid? && model.selection.contains?(vec) }
      return if arr.empty?
      model.selection.remove(arr)
    end
    def modifier_down?(rot)
      (rot & MK_SHIFT) != 0 || (rot & MK_CONTROL) != 0
    end
    def twins_at(view, x, y)
      ok = pick_at(view, x, y)
      return [] unless ok && ok[:kind] == :panel
      twins_of(ok[:entity])
    end
    def pick_at(view, x, y)
      ph = view.pick_helper
      ph.do_pick(x, y)
      best = ph.best_picked
      return { kind: :panel, entity: best } if KSU.container?(best) && !nesting_root?(best) && !KSU::Sheet.sheet_border?(best)
      (0...ph.count).each do |i|
        next unless ph.leaf_at(i).is_a?(Sketchup::Edge)
        path = ph.path_at(i)
        lbl = label_hit(path)
        return lbl if lbl
        panel = panel_from_path(path)
        return { kind: :panel, entity: panel } if panel
      end
      entity = smallest_at(view, x, y)
      entity ? { kind: :panel, entity: entity } : nil
    end
    def label_hit(path)
      return nil unless path
      path.each_with_index do |node4, i|
        next if i.zero?
        next unless KSU.container?(node4) && entity_labels(node4).any? { |n| n.include?("_ABF_Label") }
        panel = path[i - 1]
        return nil unless panel && KSU.container?(panel)
        tr = Geom::Transformation.new
        path.take(i).each { |n| tr *= n.transformation if n.respond_to?(:transformation) }
        return { kind: :label, panel: panel, loop: KSU::Cutting.label_pts(panel, tr) }
      end
      nil
    end
    def smallest_at(view, x, y)
      pt = KSU::View.pick_on_plane(view, x, y, 0)
      return nil unless pt
      _a8ec13cf, num = pt.x.to_f, pt.y.to_f
      best, best_a = nil, Float::INFINITY
      candidates.each do |arr|
        next unless arr[:external]
        entity = arr[:entity]
        next unless entity.valid?
        bb = KSU::Geom.box_corners(entity.definition.bounds, arr[:transform])
        x1, arr2 = bb.map { |pt2| pt2.x.to_f }.minmax
        y1, arr3 = bb.map { |pt2| pt2.y.to_f }.minmax
        next unless _a8ec13cf.between?(x1, arr2) && num.between?(y1, arr3)
        _354e0ff6 = (arr2 - x1) * (arr3 - y1)
        next unless _354e0ff6 < best_a
        best_a, best = _354e0ff6, entity
      end
      best
    end
    def panel_from_path(path)
      return nil unless path
      path.each_with_index do |node4, i|
        next if i.zero?
        next unless KSU.container?(node4) && cutting_lines?(node4)
        return path[i - 1]
      end
      nil
    end
    def cutting_lines?(node4)
      return true if node4.get_attribute("ABF", "is-cutting-lines")
      entity_labels(node4).any? { |n| n.include?("_ABF_cuttingLines") }
    end
    def panels_in_rect(view, rect, strict)
      arr2 = screen_items(view).select { |arr| arr[:entity].valid? && KSU::Quet.rect_hit?(arr[:box], rect, strict) }
      arr2.flat_map { |arr| twins_of(arr[:entity]) }.compact.select(&:valid?).uniq
    end
    def candidates
      @cache ? @cache[:candidates] : []
    end
    def screen_items(view)
      sig = KSU::View.cam_sig(view)
      return @arr30[:items] if @arr30 && @arr30[:sig] == sig
      items = []
      candidates.each do |arr|
        entity = arr[:entity]
        next unless entity && entity.valid?
        begin
          pt = KSU::Geom.box_corners(entity.local_bounds, arr[:transform]).map { |pt3| view.screen_coords(pt3) }
          sxmin, sxmax = pt.map(&:x).minmax
          symin, symax = pt.map(&:y).minmax
          items << { entity: entity, box: [sxmin, symin, sxmax, symax] }
        rescue
          next
        end
      end
      @arr30 = { sig: sig, items: items }
      items
    end
    def twins_of(vec)
      return [] unless vec && vec.valid? && KSU.container?(vec)
      ix = KSU::Cutting.index_of(vec)
      return (cached_at(ix) << vec).compact.select(&:valid?).uniq unless ix.nil?
      name = name_of(vec)
      return [] if name.empty?
      nesting = root_of(vec)
      return [] if nesting && !panel_under?(vec, nesting)
      ([vec] + cached_named(name, nesting ? :external_map : :nesting_map, vec)).compact.select(&:valid?).uniq
    end
    def cached_at(ix, key = :index_map)
      return [] if ix.nil? || @cache.nil?
      @cache[key].fetch(ix.to_i, []).select { |vec| vec && vec.valid? }
    end
    def cached_named(name, key, ref_p1)
      return [] unless @cache
      (@cache[key][name] || []).reject { |vec| vec == ref_p1 || !vec.valid? }
    end
    def root_of(entity)
      return nil unless @cache && entity && entity.valid?
      nesting = @cache[:roots_map][entity.entityID]
      nesting if nesting&.valid?
    end
    def pickable?(entity)
      name = name_of(entity)
      return false if name.empty? || name.start_with?("_ABF_")
      return false if (entity_labels(entity).map(&:strip) & %w[ABF_cuttingLines ABF_sheetMaterial ABF_sheetId]).any?
      return false if entity.respond_to?(:layer) && entity.layer && entity.layer.name.to_s.strip == "ABF_cuttingLines"
      !KSU::Sheet.sheet_border?(entity)
    end
    def panel_under?(entity, nesting)
      return false unless entity && nesting
      return false if entity == nesting
      return false if walk_to(entity, nesting, []).length != 2
      return false unless pickable?(entity)
      entity.parent.is_a?(Sketchup::ComponentDefinition) || entity.parent.is_a?(Sketchup::Entities)
    end
    def walk_to(target, cur, path)
      return path if cur == target
      (KSU.entities_in(cur) || []).each do |_25d57fd1|
        next unless KSU.container?(_25d57fd1)
        ok = walk_to(target, _25d57fd1, path + [_25d57fd1])
        return ok unless ok.empty?
      end
      []
    end
    def nesting_root?(entity)
      entity_labels(entity).any? { |n| n.strip == "__ABF_Nesting" }
    end
    def name_of(entity)
      name = entity.respond_to?(:name) ? entity.name.to_s.strip : ""
      return name unless name.empty?
      return entity.definition.name.to_s.strip if entity.respond_to?(:definition) && entity.definition
      ""
    end
    def entity_labels(entity)
      side_names = []
      side_names << entity.name.to_s if entity.respond_to?(:name)
      side_names << entity.definition.name.to_s if entity.respond_to?(:definition) && entity.definition
      side_names
    end
    def cache_build(model, nesting, tool)
      cancel_cache_build
      @build = {
        model: model,
        tool: tool,
        nesting: nesting,
        stage: :external,
        ext_queue: model.entities.to_a.map { |e| [e, nil, 0] },
        queue: [[nesting, nesting.transformation, 0]],
        candidates: [],
        external_map: Hash.new { |elem, k| elem[k] = [] },
        nesting_map: Hash.new { |elem, k| elem[k] = [] },
        roots_map: {},
        ticks: 0,
      }
      cache_next_tick
    end
    def cache_next_tick
      return unless @build
      UI.start_timer(0.01, false) { cache_tick }
    end
    def cache_tick
      arr = @build
      return unless arr
      model = arr[:model]
      tool = arr[:tool]
      return cancel_cache_build unless model.valid? && Sketchup.active_model == model && model.tools.active_tool == tool
      num = 200
      begin
        while num > 0
          case arr[:stage]
          when :external
            if arr[:ext_queue].empty?
              arr[:stage] = :nesting
              next
            end
            num -= 1
            scan_external(arr, *arr[:ext_queue].shift)
          when :nesting
            return cache_finish(arr) if arr[:queue].empty?
            num -= 1
            scan_nesting(arr, *arr[:queue].shift)
          end
        end
      rescue StandardError
        return cancel_cache_build
      ensure
        arr[:ticks] += 1
        model.active_view.invalidate if model.valid? && (arr[:ticks] % 3).zero?
      end
      cache_next_tick if @build
    end
    def scan_external(arr, entity, _ac3b3b9d, depth)
      return unless KSU.container?(entity) && entity.valid?
      return if nesting_root?(entity)
      tr = _ac3b3b9d ? _ac3b3b9d * entity.transformation : entity.transformation
      name = name_of(entity)
      ix = entity.get_attribute("ABF", "board-index")
      if (depth.zero? || !ix.nil?) && !(name.empty? && ix.nil?)
        arr[:candidates] << { entity: entity, transform: tr, external: true }
        arr[:external_map][name] << entity unless name.empty?
      end
      return unless ix.nil?
      KSU.entities_in(entity).each do |_25d57fd1|
        next unless KSU.container?(_25d57fd1)
        arr[:ext_queue] << [_25d57fd1, tr, depth + 1]
      end
    end
    def scan_nesting(arr, ents3, tf, depth)
      KSU.entities_in(ents3).each do |grp|
        next if !KSU.container?(grp) || KSU::Sheet.bottom_sheet?(grp) || KSU::Cutting.bottom_face?(grp)
        transform = tf * grp.transformation
        arr[:roots_map][grp.entityID] = arr[:nesting]
        if depth == 1 && pickable?(grp)
          arr[:candidates] << { entity: grp, transform: transform, external: false }
          arr[:nesting_map][name_of(grp)] << grp
        end
        arr[:queue] << [grp, transform, depth + 1] if depth + 1 < 2
      end
    end
    def cache_finish(arr)
      @cache = {
        candidates: arr[:candidates].uniq { |fld| fld[:entity].entityID },
        external_map: arr[:external_map],
        nesting_map: arr[:nesting_map],
        roots_map: arr[:roots_map],
        index_map: index_map(arr),
        external_index_map: index_map(arr, true),
      }
      @arr30 = nil
      @build = nil
      tool = arr[:tool]
      tool.cache_done if tool == arr[:model].tools.active_tool
    end
    def index_map(arr, flag = false)
      h = Hash.new { |elem, k| elem[k] = [] }
      arr[:candidates].each do |fld|
        next if flag && !fld[:external]
        grp = fld[:entity]
        next unless grp && grp.valid?
        board_index = grp.get_attribute("ABF", "board-index")
        h[board_index.to_i] << grp unless board_index.nil?
      end
      nesting = arr[:nesting]
      return h if flag || !(nesting && nesting.valid?)
      nesting.definition.entities.each do |sheet|
        next unless KSU.container?(sheet) && KSU::Sheet.hidden?(sheet)
        KSU.entities_in(sheet).each do |panel|
          next unless KSU.container?(panel)
          board_index = panel.get_attribute("ABF", "board-index")
          h[board_index.to_i] << panel unless board_index.nil?
        end
      end
      h
    end
  end
end
class KSU::Chontam
  def self.volume_id
    wmi = KSU.wmi_connect
    arr29 = wmi.ExecQuery("ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='C:'} WHERE AssocClass=Win32_LogicalDiskToPartition")
    arr29.each do |grp|
      id = KSU::Label.disk_serial(wmi, grp)
      return id if id
    end
    nil
  rescue
    nil
  end
end
