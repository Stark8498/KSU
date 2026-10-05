module KSU::Thongke::Phukien
  MINIFIX_ATTRS = %w[
    is-minifix-part-b is-minifix-part-a is-side-drill is-side-drill-depth is-screw
    is-lockdowel-line-1-red is-lockdowel-line-2-blue is-lockdowel-preview-a is-lockdowel-preview-b
    is-spring-dowel-pin-profile-on-red is-spring-dowel-pin-profile-on-blue
    is-spring-dowel-pin-keyhole-hanging-plate-out is-spring-dowel-pin-keyhole-hanging-plate-in
    is-if-openline is-if-preview
  ].freeze
  def self.abf_kids_v1(node)
    (KSU.entities_in(node) || []).select { |ent|
      KSU.container?(ent) && ent.attribute_dictionaries && ent.attribute_dictionaries["ABF"]
    }
  end
  def self.kids_with_v1(node, attr)
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
      arr.concat(abf_kids_v1(gr).select { |g| g.definition.instances.size > 1 })
    end
    return if arr.empty?
    KSU.set_status("Đang tách nhóm dùng chung ...")
    KSU.start(false)
    arr.each { |g| g.make_unique if g.valid? }
    KSU.commit
    KSU.set_status("")
  end
  def self.intersect_length_v1(g)
    x = g.get_attribute("ABF", "intersect-x", 0) / 25.4
    half = g.get_attribute("ABF", "intersect-r", 0) / 25.4
    isect_off = g.get_attribute("ABF", "intersect-offset", 0) / 25.4
    tf = KSU::Label.world_tf(g)
    bnds = g.definition.bounds
    p_ref = bnds.corner(0).transform(tf)
    arr = [1, 2, 4].map { |i| p_ref.distance(bnds.corner(i).transform(tf)).to_f }
    arr.max - 2 * (x + half + isect_off)
  end
  def self.sum_lengths(arr)
    want = {}
    arr.each do |g|
      name = g.get_attribute("ABF", "setting-name") || g.get_attribute("ABF", "statistical-name")
      next unless name
      value = intersect_length_v1(g)
      key = KSU::Cutting.d(value)
      want[name] ||= { count_by_length: {}, total_length: 0 }
      want[name][:total_length] += value
      want[name][:count_by_length][key] = (want[name][:count_by_length][key] || 0) + 1
    end
    want.map { |k, v|
      { name: k, quantity: KSU::Thongke.round_len(v[:total_length]), count_by_length: v[:count_by_length] }
    }
  end
  def self.list_intersect_v1(scope)
    sum_lengths(scope.flat_map { |gr| kids_with_v1(gr, "is-intersect") })
  end
  def self.list_minifix_v1(scope)
    h2 = {}
    h = {}
    scope.each do |gr|
      abf_kids_v1(gr).each do |g|
        next if (MINIFIX_ATTRS & g.attribute_dictionaries["ABF"].keys).empty?
        key = pt_key(KSU::Label.world_tf(g).origin)
        (h2[key] ||= []) << g
        name = g.get_attribute("ABF", "setting-name")
        h[key] = name if h[key].nil? && name
      end
    end
    want = {}
    h2.each_key do |key|
      name = h[key]
      want[name] = (want[name] || 0) + 1
    end
    want.map { |k, v| { name: k, quantity: v, type: "fitting" } }
  end
  def self.hinge_parts(scope)
    parts = []
    scope.each do |gr|
      arr = abf_kids_v1(gr).select { |g|
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
    h2 = {}
    h = {}
    hinge_parts(scope).each do |grp|
      name = grp[:name]
      if grp[:is_part_b]
        h[name] = (h[name] || 0) + 1
      else
        h2[name] = (h2[name] || 0) + 1
      end
    end
    (h2.keys + h.keys).uniq.map { |name|
      { name: name, quantity: [(h[name] || 0), (h2[name] || 0)].max, type: "hinge" }
    }
  end
  def self.stat_objects_v1(scope)
    scope.flat_map { |gr|
      gr.get_attribute("ABF", "is-statistical-object") ? [gr] : kids_with_v1(gr, "is-statistical-object")
    }
  end
  def self.list_statistical_v1(scope)
    arr = stat_objects_v1(scope)
    arr4 = arr.select { |g| g.get_attribute("ABF", "statistical-type") == "counter" }
    h = {}
    arr4.each { |g| h[g.get_attribute("ABF", "statistical-name")] ||= g.get_attribute("ABF", "statistical-unit") }
    arr7 = count_by(arr4, "statistical-name").map { |name, v|
      { name: name, quantity: v, subtype: "counter", unit: h[name] }
    }
    arr3 = sum_lengths(arr.select { |g| g.get_attribute("ABF", "statistical-type") == "length_measuring" })
    arr3.each { |fld| fld[:subtype] = "length_measuring" }
    with_len, arr5 = scope.select { |g| g.get_attribute("ABF", "setting-name") }
                                            .partition { |g| g.get_attribute("ABF", "is-intersect") }
    arr6 = count_by(arr5, "setting-name").map { |name, v|
      { name: name, quantity: v, subtype: "counter" }
    }
    arr2 = sum_lengths(with_len)
    arr2.each { |fld| fld[:subtype] = "length_measuring" }
    arr7 + arr3 + arr6 + arr2
  end
  def self.set_unit_v1(name, value)
    KSU.start(false)
    stat_objects_v1(KSU::Thongke::Quet.all_roots_v1).each do |g|
      next unless g.get_attribute("ABF", "statistical-type") == "counter"
      next unless g.get_attribute("ABF", "statistical-name") == name
      g.set_attribute("ABF", "statistical-unit", value)
    end
    KSU.commit
  end
end
