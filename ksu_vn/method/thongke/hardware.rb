module KSU::Thongke::Phukien
  MINIFIX_ATTRS = %w[
    is-minifix-part-b is-minifix-part-a is-side-drill is-side-drill-depth is-screw
    is-lockdowel-line-1-red is-lockdowel-line-2-blue is-lockdowel-preview-a is-lockdowel-preview-b
    is-spring-dowel-pin-profile-on-red is-spring-dowel-pin-profile-on-blue
    is-spring-dowel-pin-keyhole-hanging-plate-out is-spring-dowel-pin-keyhole-hanging-plate-in
    is-if-openline is-if-preview
  ].freeze
  def self.abf_kids(_124c7bd3)
    (KSU.entities_in(_124c7bd3) || []).select { |e| KSU.container?(e) && e.attribute_dictionary("ABF") }
  end
  def self.kids_with(groups, attr)
    groups.map { |grp| grp.get_attribute("ABF", attr) }.tally
  end
  def self.make_shared_unique(arr)
    grp2 = (arr + arr.flat_map { |gr| abf_kids(gr) }).select { |grp| grp.definition.instances.size > 1 }
    return if grp2.empty?
    KSU.set_status("Đang tách nhóm dùng chung ...")
    KSU.start(false)
    grp2.each { |grp| grp.make_unique if grp.valid? }
    KSU.commit
    KSU.set_status("")
  end
  def self.intersect_length(grp)
    entity = %w[intersect-x intersect-r intersect-offset].map { |k| grp.get_attribute("ABF", k, 0) / 25.4 }.inject(:+)
    tf = KSU::Label.world_tf(grp)
    bnds = grp.definition.bounds
    p_ref = bnds.corner(0).transform(tf)
    [1, 2, 4].map { |i| p_ref.distance(bnds.corner(i).transform(tf)).to_f }.max - 2 * entity
  end
  def self.group_by_name(groups, **addon_data)
    groups.each_with_object({}) { |grp, arr2|
      name = grp.get_attribute("ABF", "setting-name") || grp.get_attribute("ABF", "statistical-name")
      (arr2[name] ||= []) << intersect_length(grp) if name
    }.map { |name, arr|
      { name: name, quantity: KSU::Thongke.round_len(arr.inject(0, :+)), count_by_length: arr.map { |_6f2569f7| KSU::Cutting.d(_6f2569f7) }.tally, **addon_data }
    }
  end
  def self.list_intersect(arr2)
    arr2.flat_map { |gr| abf_kids(gr) }.each_with_object({}) { |grp, arr|
      next if (MINIFIX_ATTRS & grp.attribute_dictionary("ABF").keys).empty?
      arr[KSU::Label.world_tf(grp).origin.to_a.map { |c| (c * 1000).round }] ||= grp.get_attribute("ABF", "setting-name") || nil
    }.values.tally.map { |k, v| { name: k, quantity: v, type: "fitting" } }
  end
  def self.list_minifix(arr2)
    h, h2 = arr2.flat_map { |gr|
      groups = abf_kids(gr).select { |grp| grp.get_attribute("ABF", "is-hinge-part-b") || grp.get_attribute("ABF", "is-hinge-part-a") }
      groups.empty? || KSU::Label.board?(gr) ? groups : []
    }.partition { |grp| grp.get_attribute("ABF", "is-hinge-part-b") == true }.map { |groups| kids_with(groups, "setting-name") }
    (h2.keys | h.keys).map { |name| { name: name, quantity: [h.fetch(name, 0), h2.fetch(name, 0)].max, type: "hinge" } }
  end
  def self.stat_objects(arr)
    arr.flat_map { |gr|
      next [gr] if gr.get_attribute("ABF", "is-statistical-object")
      KSU::Cutting.kids_with_attr(gr, "is-statistical-object") || []
    }
  end
  def self.list_statistical(arr)
    _61798be7, panel = stat_objects(arr).partition { |grp| grp.get_attribute("ABF", "statistical-type") == "counter" }
    arr3 = _61798be7.each_with_object({}) { |grp, u| u[grp.get_attribute("ABF", "statistical-name")] ||= grp.get_attribute("ABF", "statistical-unit") }
    arr4 = kids_with(_61798be7, "statistical-name").map { |name, v| { name: name, quantity: v, subtype: "counter", unit: arr3[name] } }
    arr2 = group_by_name(panel.select { |grp| grp.get_attribute("ABF", "statistical-type") == "length_measuring" }, subtype: "length_measuring")
    _2633501c, arr6 = arr.select { |grp| grp.get_attribute("ABF", "setting-name") }.partition { |grp| grp.get_attribute("ABF", "is-intersect") }
    arr5 = kids_with(arr6, "setting-name").map { |name, v| { name: name, quantity: v, subtype: "counter" } }
    arr4 + arr2 + arr5 + group_by_name(_2633501c, subtype: "length_measuring")
  end
  def self.set_unit(name, val)
    KSU.start(false)
    stat_objects(KSU::Thongke::Quet.all_roots).each do |grp|
      grp.set_attribute("ABF", "statistical-unit", val) if grp.get_attribute("ABF", "statistical-type") == "counter" && grp.get_attribute("ABF", "statistical-name") == name
    end
    KSU.commit
  end
end
