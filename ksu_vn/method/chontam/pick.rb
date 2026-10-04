class KSU::Chontam
  class << self
    def log(msg2)
      puts "[chontam] #{msg2}" if DBG
    end
    def ms_since(thick)
      ((Time.now - thick) * 1000.0).round(1)
    end
    def clear_caches
      @cache = nil
      @build = nil
      @arr3 = nil
      @hit_targets = nil
    end
    def hit_targets(nesting)
      @hit_targets ||= KSU::Flip.hit_targets(nesting)
    end
    def panel_at(view, x, y)
      nesting = KSU::Nesting.find_nesting(notify: false)
      return nil unless nesting
      KSU::Flip.hit_panel(view, hit_targets(nesting), x, y)
    end
    def clear_screen_cache
      @arr3 = nil
    end
    def cancel_cache_build
      @build = nil
    end
    def parse_indices(text)
      arr = []
      text.to_s.split(",").each do |grp|
        grp = grp.strip
        next if grp.empty?
        if grp =~ /\A(\d+)\s*-\s*(\d+)\z/
          num2 = $1.to_i
          b = $2.to_i
          num2, b = b, num2 if num2 > b
          (num2..b).each { |n| arr << n }
        elsif grp =~ /\A\d+\z/
          arr << grp.to_i
        end
      end
      arr.uniq
    end
    def panels_by_index(arr)
      return [] if arr.nil? || arr.empty?
      nesting = KSU::Nesting.find_nesting(notify: false)
      return [] unless nesting
      arr2 = []
      nesting.definition.entities.each do |sheet|
        next unless KSU.container?(sheet)
        next unless sheet.name.to_s.downcase.include?("sheet")
        next if KSU::Sheet.bottom_sheet?(sheet)
        ents = KSU.entities_in(sheet)
        next unless ents
        ents.each do |entity|
          next unless KSU.container?(entity)
          next if KSU::Cutting.bottom_face?(entity)
          next unless panel_at_depth?(entity, 2)
          ix = entity.get_attribute("ABF", "board-index")
          next if ix.nil?
          next unless arr.include?(ix.to_i)
          arr2.concat(twins_of(entity))
        end
      end
      arr2.compact.select(&:valid?).uniq
    end
    def keep_non_containers(model)
      h = container_ids(KSU::Nesting.find_nesting(notify: false))
      keep_existing = model.selection.to_a.reject do |ent|
        !root_of(ent).nil? || h.key?(ent.entityID)
      end
      KSU.select_only(keep_existing)
    end
    def container_ids(nesting)
      h = {}
      return h unless nesting && nesting.valid?
      h[nesting.entityID] = true
      arr = [[nesting, 0]]
      until arr.empty?
        ents3, lvl = arr.shift
        arr2 = KSU.entities_in(ents3)
        next unless arr2
        arr2.each do |entity|
          next unless KSU.container?(entity)
          h[entity.entityID] = true
          arr << [entity, lvl + 1] if lvl + 1 < 3
        end
      end
      h
    end
    def set_selection(model, arr, additive:, clear_on_empty:)
      arr = Array(arr).compact.select(&:valid?).uniq
      cur = model.selection.to_a
      target = if additive
          (cur + arr).uniq
        elsif arr.empty?
          clear_on_empty ? [] : cur
        else
          arr
        end
      arr3 = cur - target
      arr2 = target - cur
      model.selection.remove(arr3) if arr3.any?
      model.selection.add(arr2) if arr2.any?
    end
    def add_to_selection(model, container)
      arr = Array(container).select { |ent| ent.valid? && !model.selection.contains?(ent) }
      return [] if arr.empty?
      model.selection.add(arr)
      arr
    end
    def drop_from_selection(model, container)
      arr = Array(container).select { |ent| ent.valid? && model.selection.contains?(ent) }
      return if arr.empty?
      model.selection.remove(arr)
    end
    def modifier_down?(rot)
      (rot & MK_SHIFT) != 0 || (rot & MK_CONTROL) != 0
    end
    def twins_at(view, x, y)
      answer = pick_at(view, x, y)
      return [] unless answer && answer[:kind] == :panel
      twins_of(answer[:entity])
    end
    def pick_at(view, x, y)
      ph = view.pick_helper
      ph.do_pick(x, y)
      best = ph.best_picked
      if best && KSU.container?(best) &&
         !nesting_root?(best) && !KSU::Sheet.sheet_border?(best)
        return { kind: :panel, entity: best }
      end
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
        next unless KSU.container?(node4) && label_group?(node4)
        panel = path[i - 1]
        return nil unless panel && KSU.container?(panel)
        transform = Geom::Transformation.new
        (0...i).each do |j|
          n = path[j]
          transform = transform * n.transformation if n.respond_to?(:transformation)
        end
        sheet = i >= 2 ? path[i - 2] : nil
        lbl_pts = KSU::Cutting.label_pts(panel, transform)
        return { kind: :label, panel: panel, sheet: sheet, loop: lbl_pts }
      end
      nil
    end
    def label_group?(node4)
      str = node4.respond_to?(:name) ? node4.name.to_s : ""
      def_name = (node4.respond_to?(:definition) && node4.definition) ? node4.definition.name.to_s : ""
      str.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    end
    def smallest_at(view, x, y)
      pt = KSU::View.pick_on_plane(view, x, y, 0)
      return nil unless pt
      num2 = pt.x.to_f
      num = pt.y.to_f
      best = nil
      best_a = Float::INFINITY
      candidates.each do |color|
        next unless color[:external]
        entity = color[:entity]
        next unless entity.valid?
        pts = (0..7).map { |i| entity.definition.bounds.corner(i).transform(color[:transform]) }
        x1, arr2 = pts.map { |pt2| pt2.x.to_f }.minmax
        y1, arr3 = pts.map { |pt2| pt2.y.to_f }.minmax
        next unless num2.between?(x1, arr2) && num.between?(y1, arr3)
        area = (arr2 - x1) * (arr3 - y1)
        next unless area < best_a
        best_a = area
        best = entity
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
      return false unless node4.respond_to?(:get_attribute)
      return true if node4.get_attribute("ABF", "is-cutting-lines")
      str = node4.respond_to?(:name) ? node4.name.to_s : ""
      def_name = (node4.respond_to?(:definition) && node4.definition) ? node4.definition.name.to_s : ""
      str.include?("_ABF_cuttingLines") || def_name.include?("_ABF_cuttingLines")
    end
    def panels_in_rect(view, rect, strict)
      arr = []
      items_in_rect(view, rect, strict).each do |color|
        arr.concat(twins_of(color[:entity]))
      end
      arr.compact.select(&:valid?).uniq
    end
    def items_in_rect(view, rect, strict)
      screen_items(view).select do |arr|
        next false unless arr[:entity].valid?
        KSU::Quet.rect_hit?([arr[:sxmin], arr[:symin], arr[:sxmax], arr[:symax]], rect, strict)
      end
    end
    def candidates
      @cache ? @cache[:candidates] : []
    end
    def screen_items(view)
      sig = KSU::View.cam_sig(view)
      return @arr3[:items] if @arr3 && @arr3[:sig] == sig
      items = []
      candidates.each do |color|
        entity = color[:entity]
        next unless entity && entity.valid?
        begin
          bbox = entity.local_bounds
          pt = (0..7).map { |i| view.screen_coords(bbox.corner(i).transform(color[:transform])) }
          sxmin, sxmax = pt.map(&:x).minmax
          symin, symax = pt.map(&:y).minmax
          items << {
            entity: entity, transform: color[:transform],
            sxmin: sxmin, sxmax: sxmax, symin: symin, symax: symax,
          }
        rescue
          next
        end
      end
      @arr3 = { sig: sig, items: items }
      items
    end
    def twins_of(panel)
      return [] unless panel && panel.valid? && KSU.container?(panel)
      ix = panel.respond_to?(:get_attribute) ? panel.get_attribute("ABF", "board-index") : nil
      unless ix.nil?
        arr = by_index(ix)
        arr << panel
        return arr.compact.select(&:valid?).uniq
      end
      twins_by_name(panel)
    end
    def twins_by_name(panel)
      name = name_of(panel)
      return [] if name.empty?
      nesting = root_of(panel)
      arr = []
      if nesting
        return [] unless panel_under?(panel, nesting)
        arr << panel
        arr.concat(external_by_name(name, panel))
      else
        arr << panel
        arr.concat(nesting_by_name(name))
      end
      arr.compact.select(&:valid?).uniq
    end
    def by_index(ix)
      return [] if ix.nil? || @cache.nil?
      h = @cache[:index_map]
      return [] unless h
      h.fetch(ix.to_i, []).select { |ent| ent && ent.valid? }
    end
    def external_by_name(name, sel = nil)
      return [] unless @cache
      (@cache[:external_map][name] || []).reject { |ent| ent == sel || !ent.valid? }
    end
    def nesting_by_name(name)
      return [] unless @cache
      (@cache[:nesting_map][name] || []).select(&:valid?)
    end
    def root_of(entity)
      return nil unless @cache && entity && entity.valid?
      nesting = @cache[:roots_map][entity.entityID]
      nesting if nesting&.valid?
    end
    def pickable?(entity)
      name = name_of(entity)
      return false if name.empty?
      return false if name.start_with?("_ABF_")
      return false if cutting_layer?(entity)
      return false if sheet_meta?(entity)
      !KSU::Sheet.sheet_border?(entity)
    end
    def panel_under?(entity, nesting)
      return false unless entity && nesting
      return false if entity == nesting
      return false if path_to(entity, nesting).length != 2
      return false unless pickable?(entity)
      defn = entity.parent
      defn.is_a?(Sketchup::ComponentDefinition) || defn.is_a?(Sketchup::Entities)
    end
    def path_to(entity, nesting)
      return [] unless entity && nesting
      return [entity] if entity == nesting
      arr = KSU.entities_in(nesting)
      return [] unless arr
      arr.each do |entity2|
        next unless KSU.container?(entity2)
        answer = walk_to(entity, entity2, [entity2])
        return answer unless answer.empty?
      end
      []
    end
    def walk_to(target, cur, path)
      return path if cur == target
      arr = KSU.entities_in(cur)
      return [] unless arr
      arr.each do |entity|
        next unless KSU.container?(entity)
        answer = walk_to(target, entity, path + [entity])
        return answer unless answer.empty?
      end
      []
    end
    def nesting_root?(entity)
      names_of(entity).any? { |n| n.strip == "__ABF_Nesting" }
    end
    def name_of(entity)
      name = entity.respond_to?(:name) ? entity.name.to_s.strip : ""
      return name unless name.empty?
      return entity.definition.name.to_s.strip if entity.respond_to?(:definition) && entity.definition
      ""
    end
    def cutting_layer?(entity)
      arr = names_of(entity)
      arr << entity.layer.name.to_s if entity.respond_to?(:layer) && entity.layer
      arr.any? { |n| n.strip == "ABF_cuttingLines" }
    end
    def sheet_meta?(entity)
      names_of(entity).any? { |n| ["ABF_sheetMaterial", "ABF_sheetId"].include?(n.strip) }
    end
    def names_of(entity)
      arr = []
      arr << entity.name.to_s if entity.respond_to?(:name)
      arr << entity.definition.name.to_s if entity.respond_to?(:definition) && entity.definition
      arr
    end
    def cache_build(model, nesting, tool)
      cancel_cache_build
      ents = model.entities.to_a
      @build = {
        model: model,
        tool: tool,
        nesting: nesting,
        stage: :external,
        ext_queue: ents.map { |ent| [ent, nil, 0] },
        queue: [[nesting, nesting.transformation, 0]],
        candidates: [],
        external_map: Hash.new { |h, k| h[k] = [] },
        nesting_map: Hash.new { |h, k| h[k] = [] },
        roots_map: {},
        ticks: 0,
        t_start: Time.now,
      }
      log("cache_build start, top_entities=#{ents.length}, budget=200/tick @0.01s")
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
      unless model.valid? && Sketchup.active_model == model && model.tools.active_tool == tool
        log("cache_build huy o tick=#{arr[:ticks]} (doi tool/model)")
        cancel_cache_build
        return
      end
      num = 200
      begin
        while num > 0
          case arr[:stage]
          when :external
            if arr[:ext_queue].empty?
              arr[:stage] = :nesting
              next
            end
            entity, transform, lvl = arr[:ext_queue].shift
            num -= 1
            scan_external(arr, entity, transform, lvl)
          when :nesting
            if arr[:queue].empty?
              cache_finish(arr)
              return
            end
            ents3, tf, lvl = arr[:queue].shift
            num -= 1
            scan_nesting(arr, ents3, tf, lvl)
          end
        end
      rescue => ent
        log("cache_build loi tick=#{arr[:ticks]}: #{ent.class} #{ent.message}")
        cancel_cache_build
        return
      ensure
        arr[:ticks] += 1
        model.active_view.invalidate if model.valid? && (arr[:ticks] % 3).zero?
      end
      cache_next_tick if @build
    end
    def scan_external(arr, entity, transform, num)
      return unless KSU.container?(entity)
      return unless entity.valid?
      return if nesting_root?(entity)
      transform2 = transform ? transform * entity.transformation : entity.transformation
      name = name_of(entity)
      ix = entity.get_attribute("ABF", "board-index")
      if (num.zero? || !ix.nil?) && !(name.empty? && ix.nil?)
        arr[:candidates] << { entity: entity, transform: transform2, external: true }
        arr[:external_map][name] << entity unless name.empty?
      end
      return unless ix.nil?
      arr2 = KSU.entities_in(entity)
      return unless arr2
      arr2.each do |entity3|
        next unless KSU.container?(entity3)
        arr[:ext_queue] << [entity3, transform2, num + 1]
      end
    end
    def scan_nesting(arr, ents3, tf, lvl)
      arr2 = KSU.entities_in(ents3)
      return unless arr2
      nesting = arr[:nesting]
      arr2.each do |entity|
        next unless KSU.container?(entity)
        next if KSU::Sheet.bottom_sheet?(entity) || KSU::Cutting.bottom_face?(entity)
        transform = tf * entity.transformation
        arr[:roots_map][entity.entityID] = nesting
        if panel_at_depth?(entity, lvl + 1)
          name = name_of(entity)
          unless name.empty?
            arr[:candidates] << { entity: entity, transform: transform, external: false }
            arr[:nesting_map][name] << entity
          end
        end
        arr[:queue] << [entity, transform, lvl + 1] if lvl + 1 < 2
      end
    end
    def panel_at_depth?(entity, lvl)
      lvl == 2 && pickable?(entity)
    end
    def cache_finish(arr)
      @cache = {
        candidates: arr[:candidates].uniq { |fld| fld[:entity].entityID },
        external_map: arr[:external_map],
        nesting_map: arr[:nesting_map],
        roots_map: arr[:roots_map],
        index_map: index_map(arr),
        external_index_map: external_index_map(arr),
      }
      @arr3 = nil
      @build = nil
      entity = arr[:external_map].values.inject(0) { |s, v| s + v.length }
      arr2 = arr[:nesting_map].values.inject(0) { |s, v| s + v.length }
      log("cache_build XONG, ticks=#{arr[:ticks]}, t=#{ms_since(arr[:t_start])}ms, candidates=#{@cache[:candidates].length}, ext_3d=#{entity}, tam_nesting=#{arr2}, roots=#{arr[:roots_map].length}")
      tool = arr[:tool]
      tool.cache_done if tool == arr[:model].tools.active_tool
    end
    def index_map(arr)
      h9 = Hash.new { |h, k| h[k] = [] }
      arr[:candidates].each do |fld|
        ent = fld[:entity]
        next unless ent && ent.valid?
        board_index = ent.get_attribute("ABF", "board-index")
        h9[board_index.to_i] << ent unless board_index.nil?
      end
      nesting = arr[:nesting]
      if nesting && nesting.valid?
        nesting.definition.entities.each do |sheet|
          next unless KSU.container?(sheet)
          next unless KSU::Sheet.hidden?(sheet)
          ents = KSU.entities_in(sheet)
          next unless ents
          ents.each do |panel|
            next unless KSU.container?(panel)
            board_index = panel.get_attribute("ABF", "board-index")
            h9[board_index.to_i] << panel unless board_index.nil?
          end
        end
      end
      h9
    end
    def external_index_map(arr)
      h15 = Hash.new { |h, k| h[k] = [] }
      arr[:candidates].each do |fld|
        next unless fld[:external]
        ent = fld[:entity]
        next unless ent && ent.valid?
        board_index = ent.get_attribute("ABF", "board-index")
        h15[board_index.to_i] << ent unless board_index.nil?
      end
      h15
    end
    def external_by_index(ix)
      return [] if ix.nil? || @cache.nil?
      h = @cache[:external_index_map]
      return [] unless h
      h.fetch(ix.to_i, []).select { |ent| ent && ent.valid? }
    end
  end
end
class KSU::Chontam
  def self.volume_id
    wmi = KSU.wmi_connect
    parts = wmi.ExecQuery("ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='C:'} WHERE AssocClass=Win32_LogicalDiskToPartition")
    parts.each do |grp|
      id = KSU::Label.disk_serial(wmi, grp)
      return id if id
    end
    nil
  rescue
    nil
  end
end
