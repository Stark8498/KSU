module KSU::Thongke::Phukien
  MINIFIX_ATTRS = %w[
    is-minifix-part-b is-minifix-part-a is-side-drill is-side-drill-depth is-screw
    is-lockdowel-line-1-red is-lockdowel-line-2-blue is-lockdowel-preview-a is-lockdowel-preview-b
    is-spring-dowel-pin-profile-on-red is-spring-dowel-pin-profile-on-blue
    is-spring-dowel-pin-keyhole-hanging-plate-out is-spring-dowel-pin-keyhole-hanging-plate-in
    is-if-openline is-if-preview
  ].freeze
  def self.abf_kids(node)
    (KSU.entities_in(node) || []).select { |ent|
      KSU.container?(ent) && ent.attribute_dictionaries && ent.attribute_dictionaries["ABF"]
    }
  end
  def self.kids_with(node, attr)
    (KSU.entities_in(node) || []).select { |g|
      KSU.container?(g) && g.get_attribute("ABF", attr)
    }
  end
  def self.count_by(arr, attr)
    want = {}
    arr.each do |g|
      name = g.get_attribute("ABF", attr)
      want[name] = (want[name] || 0) + 1
    end
    want
  end
  def self.pt_key(box)
    [(box.x * 1000).round, (box.y * 1000).round, (box.z * 1000).round]
  end
  def self.make_unique_all(scope)
    arr = scope.select { |gr| gr.definition.instances.size > 1 }
    scope.each do |gr|
      arr.concat(abf_kids(gr).select { |g| g.definition.instances.size > 1 })
    end
    return if arr.empty?
    KSU.set_status("Đang tách nhóm dùng chung ...")
    KSU.start(false)
    arr.each { |g| g.make_unique if g.valid? }
    KSU.commit
    KSU.set_status("")
  end
  def self.intersect_length(g)
    x = g.get_attribute("ABF", "intersect-x", 0) / 25.4
    half = g.get_attribute("ABF", "intersect-r", 0) / 25.4
    _8a2a0205 = g.get_attribute("ABF", "intersect-offset", 0) / 25.4
    tf = KSU::Label.world_tf(g)
    bounds = g.definition.bounds
    p_ref = bounds.corner(0).transform(tf)
    arr = [1, 2, 4].map { |_a4ab9a59| p_ref.distance(bounds.corner(_a4ab9a59).transform(tf)).to_f }
    arr.max - 2 * (x + half + _8a2a0205)
  end
  def self.sum_lengths(arr)
    want = {}
    arr.each do |g|
      name = g.get_attribute("ABF", "setting-name") || g.get_attribute("ABF", "statistical-name")
      next unless name
      value = intersect_length(g)
      key = KSU::Cutting.d(value)
      want[name] ||= { count_by_length: {}, total_length: 0 }
      want[name][:total_length] += value
      want[name][:count_by_length][key] = (want[name][:count_by_length][key] || 0) + 1
    end
    want.map { |k, v|
      { name: k, quantity: KSU::Thongke.round_len(v[:total_length]), count_by_length: v[:count_by_length] }
    }
  end
  def self.list_intersect(scope)
    sum_lengths(scope.flat_map { |gr| kids_with(gr, "is-intersect") })
  end
  def self.list_minifix(scope)
    h3 = {}
    h = {}
    scope.each do |gr|
      abf_kids(gr).each do |g|
        next if (MINIFIX_ATTRS & g.attribute_dictionaries["ABF"].keys).empty?
        key = pt_key(KSU::Label.world_tf(g).origin)
        (h3[key] ||= []) << g
        name = g.get_attribute("ABF", "setting-name")
        h[key] = name if h[key].nil? && name
      end
    end
    want = {}
    h3.each_key do |key|
      name = h[key]
      want[name] = (want[name] || 0) + 1
    end
    want.map { |k, v| { name: k, quantity: v, type: "fitting" } }
  end
  def self.hinge_parts(scope)
    parts = []
    scope.each do |gr|
      arr = abf_kids(gr).select { |g|
        g.get_attribute("ABF", "is-hinge-part-b") || g.get_attribute("ABF", "is-hinge-part-a")
      }
      next if arr.empty?
      tf = KSU::Label.world_tf(gr)
      src = KSU::Cutting.board_faces(gr, tf)
      next unless src
      arr.each do |g|
        parts << {
          is_part_b: g.get_attribute("ABF", "is-hinge-part-b") == true,
          name: g.get_attribute("ABF", "setting-name"),
        }
      end
    end
    parts
  end
  def self.list_hinge(scope)
    h = {}
    h2 = {}
    hinge_parts(scope).each do |grp|
      name = grp[:name]
      if grp[:is_part_b]
        h2[name] = (h2[name] || 0) + 1
      else
        h[name] = (h[name] || 0) + 1
      end
    end
    (h.keys + h2.keys).uniq.map { |name|
      { name: name, quantity: [(h2[name] || 0), (h[name] || 0)].max, type: "hinge" }
    }
  end
  def self.stat_objects(scope)
    scope.flat_map { |gr|
      gr.get_attribute("ABF", "is-statistical-object") ? [gr] : kids_with(gr, "is-statistical-object")
    }
  end
  def self.list_statistical(scope)
    arr5 = stat_objects(scope)
    arr = arr5.select { |g| g.get_attribute("ABF", "statistical-type") == "counter" }
    h = {}
    arr.each { |g| h[g.get_attribute("ABF", "statistical-name")] ||= g.get_attribute("ABF", "statistical-unit") }
    arr6 = count_by(arr, "statistical-name").map { |name, v|
      { name: name, quantity: v, subtype: "counter", unit: h[name] }
    }
    arr2 = sum_lengths(arr5.select { |g| g.get_attribute("ABF", "statistical-type") == "length_measuring" })
    arr2.each { |fld| fld[:subtype] = "length_measuring" }
    with_len, arr8 = scope.select { |g| g.get_attribute("ABF", "setting-name") }
                                            .partition { |g| g.get_attribute("ABF", "is-intersect") }
    arr7 = count_by(arr8, "setting-name").map { |name, v|
      { name: name, quantity: v, subtype: "counter" }
    }
    arr4 = sum_lengths(with_len)
    arr4.each { |fld| fld[:subtype] = "length_measuring" }
    arr6 + arr2 + arr7 + arr4
  end
  def self.set_unit(name, value)
    KSU.start(false)
    stat_objects(KSU::Thongke::Quet.all_roots).each do |g|
      next unless g.get_attribute("ABF", "statistical-type") == "counter"
      next unless g.get_attribute("ABF", "statistical-name") == name
      g.set_attribute("ABF", "statistical-unit", value)
    end
    KSU.commit
  end
end
