module KSU::Thongke::Tonghop
  HEADERS = [
    "ID", "Tấm", "Tên", "Dài", "Rộng", "Dày", "Vật liệu",
    "Mã 1", "Mã 2", "Mã 3",
  ].freeze
  def self.list_edgeband(arr3)
    h = {}
    arr3.each do |arr|
      arr[:edgeband_lengths].each do |k, v|
        key = [k, arr[:material].to_s, arr[:thickness]]
        h[key] ||= {
          thickness: arr[:edgeband_thickness].fetch(k, 0),
          name: arr[:edgeband_base][k].to_s,
          material: arr[:material].to_s,
          board_thickness: arr[:thickness],
          quantity: 0,
        }
        h[key][:quantity] += v
      end
    end
    arr2 = h.values.each { |fld| fld[:quantity] = KSU::Thongke.round_len(fld[:quantity]) }
    arr2.sort_by { |fld| [fld[:name].to_s, fld[:material].to_s, fld[:board_thickness].to_f] }
  end
  def self.list_sheet(scope)
    h = {}
    thickness = {}
    min_sheet_id = {}
    KSU::Thongke::Quet.each_sheet(scope) do |ent, sheet|
      next if KSU::Sheet.hidden?(ent)
      sheet_type = ent.get_attribute("ABF", "sheet-type", "")
      thick = ent.get_attribute("ABF", "sheet-thickness")
      thickness[sheet_type] = thick if thick
      h[sheet_type] = (h[sheet_type] || 0) + 1
      min_sheet_id[sheet_type] = [(min_sheet_id[sheet_type] || 9999), sheet].min
    end
    arr = h.map { |k, v|
      { thickness: thickness.fetch(k, k), name: k, quantity: v, min_sheet_id: min_sheet_id[k] }
    }
    arr.sort_by { |fld| fld[:min_sheet_id].to_i }
  end
  def self.part_data(arr2)
    arr2 = arr2.sort_by { |arr| [arr[:sheet].to_i, arr[:material].to_s, arr[:name].to_s] }
    rows = arr2.map { |arr|
      [
        arr[:index],
        arr[:sheet] != -1 ? arr[:sheet] : "",
        arr[:name],
        arr[:length], arr[:width], arr[:thickness], arr[:material],
        arr[:code_ns][0], arr[:code_ns][1], arr[:code_ns][2],
      ]
    }
    { headers: HEADERS, rows: rows }
  end
  def self.round_lengths(fld)
    return fld unless fld[:count_by_length]
    count_by_length = {}
    fld[:count_by_length].each do |k, v|
      key = k.to_f.round
      count_by_length[key] = (count_by_length[key] || 0) + v
    end
    fld.merge(quantity: fld[:quantity].to_f.round(1), count_by_length: count_by_length)
  end
  def self.round_sums(data)
    acc2 = data[:sum_data]
    data.merge(sum_data: acc2.merge(
      list_intersect: acc2[:list_intersect].map { |fld| round_lengths(fld) },
      list_statistical_object: acc2[:list_statistical_object].map { |fld| round_lengths(fld) },
      list_edgeband: acc2[:list_edgeband].map { |fld| fld.merge(quantity: fld[:quantity].to_f.round(1)) },
    ))
  end
  def self.round_parts(data)
    grp = data[:part_data]
    arr2 = [HEADERS.index("Dài"), HEADERS.index("Rộng")]
    rows = grp[:rows].map { |h2|
      arr = h2.dup
      arr2.each { |color| arr[color] = arr[color].to_f.round }
      arr
    }
    data.merge(part_data: grp.merge(rows: rows))
  end
  def self._984ac2f3
    _9535dc0b = KSU::Thongke::Quet.selected_roots
    scope = _9535dc0b.empty? ? KSU::Thongke::Quet.all_roots : _9535dc0b
    KSU::Thongke::Phukien.make_unique_all(scope)
    _d0ed3d7d = KSU::Thongke::Quet.list_boards(scope)
    list_connector = KSU::Thongke::Phukien.list_minifix(scope) + KSU::Thongke::Phukien.list_hinge(scope)
    {
      sum_data: {
        list_connector: list_connector,
        list_intersect: KSU::Thongke::Phukien.list_intersect(scope),
        list_statistical_object: KSU::Thongke::Phukien.list_statistical(scope),
        list_edgeband: list_edgeband(_d0ed3d7d),
        list_sheet: list_sheet(scope),
      },
      part_data: part_data(_d0ed3d7d),
    }
  end
end
