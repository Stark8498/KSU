module KSU::Group
  private
  def toggle_group
    return if @arr27.empty?
    arr = @arr27.map { |_23505ef9| group_id(_23505ef9) }
    arr2 = arr.compact.uniq
    if arr2.size == 1 && !arr.include?(nil)
      ungroup_selected
    elsif @arr27.size >= 2
      group_selected
    else
      return
    end
    KSU::View.refresh_groups(@arr27)
  end
  def group_id(panel)
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def new_group_id
    (Time.now.to_f * 1000).to_i.to_s(36)
  end
  def group_mates(panel)
    gid = group_id(panel)
    return [] unless gid
    out = []
    all_panels.each do |_23505ef9, s, g|
      out << [_23505ef9, s] if g == gid && _23505ef9 != panel
    end
    out
  end
  def all_panels
    out = []
    return out unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |grp|
      next unless KSU.container?(grp)
      if grp.name.to_s.downcase.include?("sheet")
        next if KSU::Sheet.bottom_sheet?(grp)
        grp.definition.entities.each do |panel|
          next unless KSU::Sheet.panel?(panel)
          gid = panel.get_attribute("KSU", "group-id")
          out << [panel, grp, gid] if gid
        end
      else
        gid = grp.get_attribute("KSU", "group-id")
        out << [grp, nil, gid] if gid
      end
    end
    out
  end
  def expand_selection
    ids = {}
    @arr27.each do |grp|
      gid = group_id(grp)
      ids[gid] = true if gid
    end
    return if ids.empty?
    h2 = {}
    @arr27.each { |grp| h2[grp.entityID] = true if grp && grp.valid? }
    all_panels.each do |panel, _73dc38ac, gid|
      next unless ids[gid]
      next if h2[panel.entityID]
      @arr27 << panel
      @arr12 << _73dc38ac
    end
  end
  def remove_from_selection(panel)
    gid = group_id(panel)
    arr = gid ? @arr27.select { |_23505ef9| group_id(_23505ef9) == gid } : [panel]
    arr.each do |_23505ef9|
      ix = @arr27.index(_23505ef9)
      next unless ix
      @arr27.delete_at(ix)
      @arr12.delete_at(ix)
    end
  end
  def group_selected
    return if @arr27.size < 2
    gid = new_group_id
    KSU.start
    @arr27.each do |grp|
      grp.set_attribute("KSU", "group-id", gid) if grp && grp.valid?
    end
    @flag36 = true
    KSU.commit
  rescue StandardError
    @flag36 = false
    KSU.abort_op
  end
  def ungroup_selected
    KSU.start
    @arr27.each do |vec|
      vec.delete_attribute("KSU", "group-id") if vec && vec.valid?
    end
    @flag36 = true
    KSU.commit
  rescue StandardError
    @flag36 = false
    KSU.abort_op
  end
end
KSU::Xeptam.include(KSU::Group)
