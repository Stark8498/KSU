module KSU::Assign
  private
  def load_ranks
    arr3 = saved_assign
    @parts.each do |arr|
      tag = tag_from_layer(arr[:cutting])
      if tag
        arr[:rank] = tag[:rank]
        arr[:side] = tag[:side]
        arr[:theo_vung] = tag[:theo_vung]
        arr[:prefix] = tag[:prefix]
        arr[:base_color] = tag[:base_color]
      elsif (slot = arr3[part_key(arr[:part])]).is_a?(Hash)
        arr[:rank] = slot["rank"]&.to_i
        str = slot["side"].to_s
        arr[:side] = str.empty? ? nil : str.to_sym
        arr[:theo_vung] = slot.key?("theo_vung") ? !!slot["theo_vung"] : true
        arr[:prefix] = slot["prefix"] || layer_prefix(arr[:side], arr[:theo_vung])
        arr[:base_color] = slot["color"] ? KSU::View.parse_color(slot["color"]) : nil
      else
        arr[:rank] = rank_from_attr(arr[:cutting])
        arr[:prefix] = arr[:rank] ? "Lớp" : nil
      end
      arr[:fill_color] = fill_color_of(arr)
    end
  end
  def rank_from_attr(cutting)
    return nil unless cutting && cutting.respond_to?(:layer) && cutting.layer
    meta = cutting.layer.name.to_s.match(/^Lớp\s+(\d+)$/)
    meta ? meta[1].to_i : nil
  end
  def tag_from_layer(cutting)
    return nil unless cutting && cutting.respond_to?(:layer)
    layer = cutting.layer
    return nil unless layer
    layers, prefix = split_layer_name(layer)
    return nil unless layers
    side, theo_vung, use_color = side_from_prefix(prefix)
    return nil if side.nil? && theo_vung.nil?
    color = use_color && layer.respond_to?(:color) ? layer.color : nil
    { rank: layers, side: side, theo_vung: theo_vung, prefix: prefix.to_s.strip, base_color: color }
  end
  def split_layer_name(grp)
    if grp.respond_to?(:get_attribute)
      num = grp.get_attribute("ABF", "cutting-layer-postfix")
      unless num.nil?
        return [[num.to_i, 1].max, grp.get_attribute("ABF", "cutting-layer-original-name").to_s]
      end
    end
    meta = grp.name.to_s.match(/\A(.*?)\s*(\d+)\z/)
    meta ? [meta[2].to_i, meta[1]] : [nil, nil]
  end
  def side_from_prefix(prefix)
    str = prefix.to_s.strip
    return [nil, nil, false] if str.empty?
    return [:tren, true, true] if str == @ten_tren
    return [:duoi, true, true] if str == @ten_duoi
    return [:trai, true, true] if str == @ten_trai
    return [:phai, true, true] if str == @ten_phai
    return [nil, false, true] if str == @ten_chung && !@ten_chung.to_s.strip.empty?
    return [nil, true, false] if str == "Lớp"
    [nil, nil, false]
  end
  def part_key(grp)
    (grp.respond_to?(:persistent_id) ? grp.persistent_id : grp.object_id).to_s
  end
  def saved_assign
    id_str = Sketchup.active_model.get_attribute("KSU", "chong_bay_da_gan", "{}").to_s
    h = JSON.parse(id_str)
    h.is_a?(Hash) ? h : {}
  rescue StandardError
    {}
  end
  def assign_payload
    h = {}
    @parts.each do |arr|
      next unless arr[:rank]
      h[part_key(arr[:part])] = {
        "rank" => arr[:rank],
        "side" => arr[:side]&.to_s,
        "theo_vung" => arr[:theo_vung],
        "prefix" => arr[:prefix],
        "color" => color_str(arr[:base_color])
      }
    end
    Sketchup.active_model.set_attribute("KSU", "chong_bay_da_gan", JSON.generate(h))
  rescue StandardError
    nil
  end
  def color_str(color)
    return nil unless color
    [color.red, color.green, color.blue]
  end
  def fill_color_of(arr)
    return nil unless arr[:rank]
    mix = @danh_so_thu_tu ? arr[:rank] - 1 : 0
    unless arr[:side]
      return KSU::View.shade(arr[:base_color], mix) if arr[:base_color]
      return KSU::View.rank_color(arr[:rank])
    end
    normal = arr[:base_color] || side_color(arr[:side], arr[:theo_vung])
    KSU::View.shade(normal, mix)
  end
  def apply_ranks(arr4)
    arr3 = []
    arr4.each do |arr2|
      arr = arr2[:part]
      arr[:rank] = arr2[:rank]
      arr[:side] = arr2[:side]
      arr[:theo_vung] = @layer_theo_vung
      arr[:prefix] = layer_prefix(arr2[:side])
      arr[:base_color] = arr2[:side] ? side_color(arr2[:side], @layer_theo_vung) : nil
      arr[:changed] = true
      arr[:fill_color] = fill_color_of(arr)
      arr3 << arr
    end
    commit_changes(arr3)
  end
  def set_rank(arr, layers)
    return unless arr[:rank]
    arr[:rank] = layers
    arr[:fill_color] = fill_color_of(arr)
    arr[:changed] = true
    commit_changes([arr])
  end
  def commit_changes(parts)
    return if parts.empty?
    KSU.start
    parts.each do |arr|
      next unless arr[:changed]
      cutting = arr[:cutting]
      next unless cutting && cutting.valid?
      if arr[:rank].nil?
        str2 = "ABF_cuttingLines"
        str = nil
        num = nil
      elsif arr[:side]
        str = arr[:prefix].to_s
        num = @danh_so_thu_tu ? arr[:rank].to_i : 0
        str2 = num == 0 ? str : "#{str}#{num}"
      else
        str = "Lớp"
        num = arr[:rank].to_i
        str2 = "Lớp #{num}"
      end
      tag = KSU::Cutting.layer(str2)
      if num && !str.to_s.empty? && tag.respond_to?(:set_attribute)
        tag.set_attribute("ABF", "cutting-layer-original-name", str)
        tag.set_attribute("ABF", "cutting-layer-postfix", num)
      end
      color = arr[:side] ? arr[:base_color] || side_color(arr[:side], arr[:theo_vung]) : nil
      tag.color = color if color && tag.respond_to?(:color=)
      KSU::Cutting.set_layer(cutting, tag)
      arr[:changed] = false
    end
    KSU.commit
    assign_payload
    tidy_layers if @tu_dong_don_layer
  rescue
    KSU.abort_op
  end
  def tidy_layers
    Sketchup.active_model.layers.purge_unused
  rescue StandardError
    nil
  end
end
KSU::Chongbay.include(KSU::Assign)
module KSU::Assign
  def self.activate_here(key)
    id = KSU::Xephang.normalize_id(KSU::Gannhan.license_field("i"))
    return false if id.to_s.empty?
    resp = KSU::Chontam.validate_key(key)
    return false if resp.nil?
    data = resp["data"]
    return false unless data.is_a?(Hash)
    return false unless data["code"] == "key_valid"
    arr = data["activations"]
    return false unless arr.is_a?(Array)
    arr.any? { |arr2| arr2.is_a?(Hash) && arr2["instance"].to_s == id.to_s }
  rescue
    false
  end
end
