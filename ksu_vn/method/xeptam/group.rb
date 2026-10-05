module KSU::Group
  private
  def toggle_group
    return if @sel.empty?
    arr = @sel.map { |pt3| group_id(pt3) }
    arr2 = arr.compact.uniq
    if arr2.size == 1 && !arr.include?(nil)
      group_selection(nil)
    elsif @sel.size >= 2
      group_selection((Time.now.to_f * 1000).to_i.to_s(36))
    else
      return
    end
    KSU::View.refresh_groups(@sel)
  end
  def group_id(panel)
    return nil unless panel && panel.valid?
    panel.get_attribute("KSU", "group-id")
  end
  def group_mates(panel)
    gid = group_id(panel)
    return [] unless gid
    all_panels.select { |pt3, _item, grp2| grp2 == gid && pt3 != panel }.map { |arr| arr[0, 2] }
  end
  def all_panels
    out = []
    return out unless @nesting && @nesting.valid?
    @nesting.definition.entities.each do |node4|
      next unless KSU.container?(node4)
      if node4.name.to_s.downcase.include?("sheet")
        next if KSU::Sheet.bottom_sheet?(node4)
        node4.definition.entities.each do |panel|
          next unless KSU::Sheet.part_group?(panel)
          gid = panel.get_attribute("KSU", "group-id")
          out << [panel, node4, gid] if gid
        end
      else
        gid = node4.get_attribute("KSU", "group-id")
        out << [node4, nil, gid] if gid
      end
    end
    out
  end
  def ungroup_selection
    ids = @sel.map { |grp| group_id(grp) }.select { |grp2| grp2 }.to_h { |grp2| [grp2, true] }
    return if ids.empty?
    arr = @sel.select { |grp| grp && grp.valid? }.to_h { |grp| [grp.entityID, true] }
    all_panels.each do |panel, sheet, gid|
      next unless ids[gid]
      next if arr[panel.entityID]
      @sel << panel
      @sel_sheets << sheet
    end
  end
  def remove_from_selection(panel)
    gid = group_id(panel)
    arr = gid ? @sel.select { |pt3| group_id(pt3) == gid } : [panel]
    arr.each do |pt3|
      ix = @sel.index(pt3)
      next unless ix
      @sel.delete_at(ix)
      @sel_sheets.delete_at(ix)
    end
  end
  def group_selection(gid)
    KSU.start
    @sel.each do |grp|
      next unless grp && grp.valid?
      gid ? grp.set_attribute("KSU", "group-id", gid) : grp.delete_attribute("KSU", "group-id")
    end
    @flag13 = true
    KSU.commit
  rescue StandardError
    @flag13 = false
    KSU.abort_op
  end
end
KSU::Xeptam.include(KSU::Group)
