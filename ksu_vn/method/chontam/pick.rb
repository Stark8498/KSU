class KSU::Chontam
  class << self
    def _5a9a8666(msg2)
      puts "[chontam] #{msg2}" if DBG
    end
    def _4e410601(thick)
      ((Time.now - thick) * 1000.0).round(1)
    end
    def _3f9bbe5e
      @cache = nil
      @_c7423e40 = nil
      @arr3 = nil
      @hit_targets = nil
    end
    def hit_targets(nesting)
      @hit_targets ||= KSU::Flip.hit_targets(nesting)
    end
    def _ecb07074(view, x, y)
      nesting = KSU::Nesting.find_nesting(notify: false)
      return nil unless nesting
      KSU::Flip.hit_panel(view, hit_targets(nesting), x, y)
    end
    def _4df86912
      @arr3 = nil
    end
    def _133b289c
      @_c7423e40 = nil
    end
    def _3fd8e206(text)
      keys = []
      text.to_s.split(",").each do |grp|
        grp = grp.strip
        next if grp.empty?
        if grp =~ /\A(\d+)\s*-\s*(\d+)\z/
          num2 = $1.to_i
          b = $2.to_i
          num2, b = b, num2 if num2 > b
          (num2..b).each { |n| keys << n }
        elsif grp =~ /\A\d+\z/
          keys << grp.to_i
        end
      end
      keys.uniq
    end
    def _e0b932ea(keys)
      return [] if keys.nil? || keys.empty?
      nesting = KSU::Nesting.find_nesting(notify: false)
      return [] unless nesting
      arr2 = []
      nesting.definition.entities.each do |grp|
        next unless KSU.container?(grp)
        next unless grp.name.to_s.downcase.include?("sheet")
        next if KSU::Sheet.bottom_sheet?(grp)
        ents = KSU.entities_in(grp)
        next unless ents
        ents.each do |entity|
          next unless KSU.container?(entity)
          next if KSU::Cutting.bottom_face?(entity)
          next unless _977c7789(entity, 2)
          ix = entity.get_attribute("ABF", "board-index")
          next if ix.nil?
          next unless keys.include?(ix.to_i)
          arr2.concat(_720fed6e(entity))
        end
      end
      arr2.compact.select(&:valid?).uniq
    end
    def _4d27616b(model)
      keys = _0a50b01c(KSU::Nesting.find_nesting(notify: false))
      keep_existing = model.selection.to_a.reject do |ent|
        !_d195e9f1(ent).nil? || keys.key?(ent.entityID)
      end
      KSU.select_only(keep_existing)
    end
    def _0a50b01c(nesting)
      keys = {}
      return keys unless nesting && nesting.valid?
      keys[nesting.entityID] = true
      arr = [[nesting, 0]]
      until arr.empty?
        ents3, depth = arr.shift
        arr2 = KSU.entities_in(ents3)
        next unless arr2
        arr2.each do |entity|
          next unless KSU.container?(entity)
          keys[entity.entityID] = true
          arr << [entity, depth + 1] if depth + 1 < 3
        end
      end
      keys
    end
    def _319513d3(model, arr, additive:, clear_on_empty:)
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
    def _34feb22a(model, container)
      arr = Array(container).select { |ent| ent.valid? && !model.selection.contains?(ent) }
      return [] if arr.empty?
      model.selection.add(arr)
      arr
    end
    def _4a670cfd(model, container)
      arr = Array(container).select { |ent| ent.valid? && model.selection.contains?(ent) }
      return if arr.empty?
      model.selection.remove(arr)
    end
    def _cb355156(rot)
      (rot & MK_SHIFT) != 0 || (rot & MK_CONTROL) != 0
    end
    def _6a98efb9(view, x, y)
      answer = _4deaf565(view, x, y)
      return [] unless answer && answer[:kind] == :panel
      _720fed6e(answer[:entity])
    end
    def _4deaf565(view, x, y)
      ph = view.pick_helper
      ph.do_pick(x, y)
      _477c927d = ph.best_picked
      if _477c927d && KSU.container?(_477c927d) &&
         !_07d87f58(_477c927d) && !KSU::Sheet._27ecfdd1(_477c927d)
        return { kind: :panel, entity: _477c927d }
      end
      (0...ph.count).each do |_a4ab9a59|
        next unless ph.leaf_at(_a4ab9a59).is_a?(Sketchup::Edge)
        path = ph.path_at(_a4ab9a59)
        lbl = _827d4a81(path)
        return lbl if lbl
        panel = _1db77630(path)
        return { kind: :panel, entity: panel } if panel
      end
      entity = _24c54f2a(view, x, y)
      entity ? { kind: :panel, entity: entity } : nil
    end
    def _827d4a81(path)
      return nil unless path
      path.each_with_index do |_310b620e, num|
        next if num.zero?
        next unless KSU.container?(_310b620e) && _6d620197(_310b620e)
        panel = path[num - 1]
        return nil unless panel && KSU.container?(panel)
        transform = Geom::Transformation.new
        (0...num).each do |j|
          n = path[j]
          transform = transform * n.transformation if n.respond_to?(:transformation)
        end
        flag = num >= 2 ? path[num - 2] : nil
        _c9fa72f2 = KSU::Cutting.label_pts(panel, transform)
        return { kind: :label, panel: panel, sheet: flag, loop: _c9fa72f2 }
      end
      nil
    end
    def _6d620197(grp)
      name = grp.respond_to?(:name) ? grp.name.to_s : ""
      def_name = (grp.respond_to?(:definition) && grp.definition) ? grp.definition.name.to_s : ""
      name.include?("_ABF_Label") || def_name.include?("_ABF_Label")
    end
    def _24c54f2a(view, x, y)
      pt = KSU::View.pick_on_plane(view, x, y, 0)
      return nil unless pt
      num2 = pt.x.to_f
      num = pt.y.to_f
      _477c927d = nil
      area = Float::INFINITY
      _34c552fc.each do |color|
        next unless color[:external]
        entity = color[:entity]
        next unless entity.valid?
        pts = (0..7).map { |_a4ab9a59| entity.definition.bounds.corner(_a4ab9a59).transform(color[:transform]) }
        x1, x2 = pts.map { |pt2| pt2.x.to_f }.minmax
        y1, y2 = pts.map { |pt2| pt2.y.to_f }.minmax
        next unless num2.between?(x1, x2) && num.between?(y1, y2)
        _5fb96e91 = (x2 - x1) * (y2 - y1)
        next unless _5fb96e91 < area
        area = _5fb96e91
        _477c927d = entity
      end
      _477c927d
    end
    def _1db77630(path)
      return nil unless path
      path.each_with_index do |_310b620e, num|
        next if num.zero?
        next unless KSU.container?(_310b620e) && _08a03619(_310b620e)
        return path[num - 1]
      end
      nil
    end
    def _08a03619(grp)
      return false unless grp.respond_to?(:get_attribute)
      return true if grp.get_attribute("ABF", "is-cutting-lines")
      name = grp.respond_to?(:name) ? grp.name.to_s : ""
      def_name = (grp.respond_to?(:definition) && grp.definition) ? grp.definition.name.to_s : ""
      name.include?("_ABF_cuttingLines") || def_name.include?("_ABF_cuttingLines")
    end
    def _94a6f47d(view, rect, strict)
      arr = []
      _5e1e3d1e(view, rect, strict).each do |color|
        arr.concat(_720fed6e(color[:entity]))
      end
      arr.compact.select(&:valid?).uniq
    end
    def _5e1e3d1e(view, rect, strict)
      screen_items(view).select do |arr|
        next false unless arr[:entity].valid?
        KSU::Quet.rect_hit?([arr[:sxmin], arr[:symin], arr[:sxmax], arr[:symax]], rect, strict)
      end
    end
    def _34c552fc
      @cache ? @cache[:candidates] : []
    end
    def screen_items(view)
      sig = KSU::View.cam_sig(view)
      return @arr3[:items] if @arr3 && @arr3[:sig] == sig
      items = []
      _34c552fc.each do |color|
        entity = color[:entity]
        next unless entity && entity.valid?
        begin
          bbox = entity.local_bounds
          pt = (0..7).map { |_a4ab9a59| view.screen_coords(bbox.corner(_a4ab9a59).transform(color[:transform])) }
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
    def _720fed6e(_9535dc0b)
      return [] unless _9535dc0b && _9535dc0b.valid? && KSU.container?(_9535dc0b)
      ix = _9535dc0b.respond_to?(:get_attribute) ? _9535dc0b.get_attribute("ABF", "board-index") : nil
      unless ix.nil?
        arr = _ab38749c(ix)
        arr << _9535dc0b
        return arr.compact.select(&:valid?).uniq
      end
      _d94409b2(_9535dc0b)
    end
    def _d94409b2(_9535dc0b)
      name = _6ae56a12(_9535dc0b)
      return [] if name.empty?
      nesting = _d195e9f1(_9535dc0b)
      arr = []
      if nesting
        return [] unless _d3318a1a(_9535dc0b, nesting)
        arr << _9535dc0b
        arr.concat(_7c845e31(name, _9535dc0b))
      else
        arr << _9535dc0b
        arr.concat(_670981eb(name))
      end
      arr.compact.select(&:valid?).uniq
    end
    def _ab38749c(ix)
      return [] if ix.nil? || @cache.nil?
      h = @cache[:index_map]
      return [] unless h
      h.fetch(ix.to_i, []).select { |ent| ent && ent.valid? }
    end
    def _7c845e31(name, arr27 = nil)
      return [] unless @cache
      (@cache[:external_map][name] || []).reject { |ent| ent == arr27 || !ent.valid? }
    end
    def _670981eb(name)
      return [] unless @cache
      (@cache[:nesting_map][name] || []).select(&:valid?)
    end
    def _d195e9f1(entity)
      return nil unless @cache && entity && entity.valid?
      nesting = @cache[:roots_map][entity.entityID]
      nesting if nesting&.valid?
    end
    def _d25f9b1c(entity)
      name = _6ae56a12(entity)
      return false if name.empty?
      return false if name.start_with?("_ABF_")
      return false if _9744ab6f(entity)
      return false if _cba1c244(entity)
      !KSU::Sheet._27ecfdd1(entity)
    end
    def _d3318a1a(entity, nesting)
      return false unless entity && nesting
      return false if entity == nesting
      return false if _20decd88(entity, nesting).length != 2
      return false unless _d25f9b1c(entity)
      defn = entity.parent
      defn.is_a?(Sketchup::ComponentDefinition) || defn.is_a?(Sketchup::Entities)
    end
    def _20decd88(entity, nesting)
      return [] unless entity && nesting
      return [entity] if entity == nesting
      arr = KSU.entities_in(nesting)
      return [] unless arr
      arr.each do |entity2|
        next unless KSU.container?(entity2)
        answer = _824298f7(entity, entity2, [entity2])
        return answer unless answer.empty?
      end
      []
    end
    def _824298f7(target, cur, path)
      return path if cur == target
      arr = KSU.entities_in(cur)
      return [] unless arr
      arr.each do |entity|
        next unless KSU.container?(entity)
        answer = _824298f7(target, entity, path + [entity])
        return answer unless answer.empty?
      end
      []
    end
    def _07d87f58(entity)
      _fc54e5ac(entity).any? { |n| n.strip == "__ABF_Nesting" }
    end
    def _6ae56a12(entity)
      name = entity.respond_to?(:name) ? entity.name.to_s.strip : ""
      return name unless name.empty?
      return entity.definition.name.to_s.strip if entity.respond_to?(:definition) && entity.definition
      ""
    end
    def _9744ab6f(entity)
      arr = _fc54e5ac(entity)
      arr << entity.layer.name.to_s if entity.respond_to?(:layer) && entity.layer
      arr.any? { |n| n.strip == "ABF_cuttingLines" }
    end
    def _cba1c244(entity)
      _fc54e5ac(entity).any? { |n| ["ABF_sheetMaterial", "ABF_sheetId"].include?(n.strip) }
    end
    def _fc54e5ac(entity)
      arr = []
      arr << entity.name.to_s if entity.respond_to?(:name)
      arr << entity.definition.name.to_s if entity.respond_to?(:definition) && entity.definition
      arr
    end
    def _cb453c89(model, nesting, tool)
      _133b289c
      ents = model.entities.to_a
      @_c7423e40 = {
        model: model,
        tool: tool,
        nesting: nesting,
        stage: :external,
        ext_queue: ents.map { |ent| [ent, nil, 0] },
        queue: [[nesting, nesting.transformation, 0]],
        candidates: [],
        external_map: Hash.new { |arr52, k| arr52[k] = [] },
        nesting_map: Hash.new { |arr52, k| arr52[k] = [] },
        roots_map: {},
        ticks: 0,
        t_start: Time.now,
      }
      _5a9a8666("cache_build start, top_entities=#{ents.length}, budget=200/tick @0.01s")
      _62aaad2f
    end
    def _62aaad2f
      return unless @_c7423e40
      UI.start_timer(0.01, false) { _5dc0e0f4 }
    end
    def _5dc0e0f4
      arr = @_c7423e40
      return unless arr
      model = arr[:model]
      tool = arr[:tool]
      unless model.valid? && Sketchup.active_model == model && model.tools.active_tool == tool
        _5a9a8666("cache_build huy o tick=#{arr[:ticks]} (doi tool/model)")
        _133b289c
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
            entity, transform, depth = arr[:ext_queue].shift
            num -= 1
            _416f815d(arr, entity, transform, depth)
          when :nesting
            if arr[:queue].empty?
              _d426c5bf(arr)
              return
            end
            ents3, _9a88c1a2, depth = arr[:queue].shift
            num -= 1
            _46f413d0(arr, ents3, _9a88c1a2, depth)
          end
        end
      rescue => ent
        _5a9a8666("cache_build loi tick=#{arr[:ticks]}: #{ent.class} #{ent.message}")
        _133b289c
        return
      ensure
        arr[:ticks] += 1
        model.active_view.invalidate if model.valid? && (arr[:ticks] % 3).zero?
      end
      _62aaad2f if @_c7423e40
    end
    def _416f815d(arr, entity, transform, depth)
      return unless KSU.container?(entity)
      return unless entity.valid?
      return if _07d87f58(entity)
      transform2 = transform ? transform * entity.transformation : entity.transformation
      name = _6ae56a12(entity)
      ix = entity.get_attribute("ABF", "board-index")
      if (depth.zero? || !ix.nil?) && !(name.empty? && ix.nil?)
        arr[:candidates] << { entity: entity, transform: transform2, external: true }
        arr[:external_map][name] << entity unless name.empty?
      end
      return unless ix.nil?
      arr2 = KSU.entities_in(entity)
      return unless arr2
      arr2.each do |entity3|
        next unless KSU.container?(entity3)
        arr[:ext_queue] << [entity3, transform2, depth + 1]
      end
    end
    def _46f413d0(arr, ents3, _9a88c1a2, depth)
      arr2 = KSU.entities_in(ents3)
      return unless arr2
      nesting = arr[:nesting]
      arr2.each do |entity|
        next unless KSU.container?(entity)
        next if KSU::Sheet.bottom_sheet?(entity) || KSU::Cutting.bottom_face?(entity)
        transform = _9a88c1a2 * entity.transformation
        arr[:roots_map][entity.entityID] = nesting
        if _977c7789(entity, depth + 1)
          name = _6ae56a12(entity)
          unless name.empty?
            arr[:candidates] << { entity: entity, transform: transform, external: false }
            arr[:nesting_map][name] << entity
          end
        end
        arr[:queue] << [entity, transform, depth + 1] if depth + 1 < 2
      end
    end
    def _977c7789(entity, depth)
      depth == 2 && _d25f9b1c(entity)
    end
    def _d426c5bf(arr)
      @cache = {
        candidates: arr[:candidates].uniq { |fld| fld[:entity].entityID },
        external_map: arr[:external_map],
        nesting_map: arr[:nesting_map],
        roots_map: arr[:roots_map],
        index_map: index_map(arr),
        external_index_map: external_index_map(arr),
      }
      @arr3 = nil
      @_c7423e40 = nil
      entity = arr[:external_map].values.inject(0) { |s, v| s + v.length }
      arr2 = arr[:nesting_map].values.inject(0) { |s, v| s + v.length }
      _5a9a8666("cache_build XONG, ticks=#{arr[:ticks]}, t=#{_4e410601(arr[:t_start])}ms, candidates=#{@cache[:candidates].length}, ext_3d=#{entity}, tam_nesting=#{arr2}, roots=#{arr[:roots_map].length}")
      tool = arr[:tool]
      tool._723ded7c if tool == arr[:model].tools.active_tool
    end
    def index_map(arr)
      h = Hash.new { |arr52, k| arr52[k] = [] }
      arr[:candidates].each do |fld|
        ent = fld[:entity]
        next unless ent && ent.valid?
        board_index = ent.get_attribute("ABF", "board-index")
        h[board_index.to_i] << ent unless board_index.nil?
      end
      nesting = arr[:nesting]
      if nesting && nesting.valid?
        nesting.definition.entities.each do |_73dc38ac|
          next unless KSU.container?(_73dc38ac)
          next unless KSU::Sheet.hidden?(_73dc38ac)
          ents = KSU.entities_in(_73dc38ac)
          next unless ents
          ents.each do |panel|
            next unless KSU.container?(panel)
            board_index = panel.get_attribute("ABF", "board-index")
            h[board_index.to_i] << panel unless board_index.nil?
          end
        end
      end
      h
    end
    def external_index_map(arr)
      h = Hash.new { |arr52, k| arr52[k] = [] }
      arr[:candidates].each do |fld|
        next unless fld[:external]
        ent = fld[:entity]
        next unless ent && ent.valid?
        board_index = ent.get_attribute("ABF", "board-index")
        h[board_index.to_i] << ent unless board_index.nil?
      end
      h
    end
    def _ce0f89bb(ix)
      return [] if ix.nil? || @cache.nil?
      h = @cache[:external_index_map]
      return [] unless h
      h.fetch(ix.to_i, []).select { |ent| ent && ent.valid? }
    end
  end
end
class KSU::Chontam
  def self._e36340ce
    _359b005a = KSU.wmi_connect
    parts = _359b005a.ExecQuery("ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='C:'} WHERE AssocClass=Win32_LogicalDiskToPartition")
    parts.each do |grp|
      id = KSU::Label._f58dcea4(_359b005a, grp)
      return id if id
    end
    nil
  rescue
    nil
  end
end
