module KSU::Thongke::Tonghop
  HEADERS = [
    "ID", "Tấm", "Tên", "Dài", "Rộng", "Dày", "Vật liệu",
    "Mã 1", "Mã 2", "Mã 3",
  ].freeze
  def self.list_edgeband_v1(arr)
    acc = {}
    arr.each do |rec|
      rec[:edgeband_lengths].each do |k, v|
        key = [k, rec[:material].to_s, rec[:thickness]]
        acc[key] ||= {
          thickness: rec[:edgeband_thickness].fetch(k, 0),
          name: rec[:edgeband_base][k].to_s,
          material: rec[:material].to_s,
          board_thickness: rec[:thickness],
          quantity: 0,
        }
        acc[key][:quantity] += v
      end
    end
    seen3 = acc.values.each { |fld| fld[:quantity] = KSU::Thongke.round_len(fld[:quantity]) }
    seen3.sort_by { |fld| [fld[:name].to_s, fld[:material].to_s, fld[:board_thickness].to_f] }
  end
  def self.list_sheet_v1(scope)
    h = {}
    thickness = {}
    min_sheet_id = {}
    KSU::Thongke::Quet.each_sheet_v1(scope) do |ent, sheet_id|
      next if KSU::Sheet.hidden?(ent)
      sheet_type = ent.get_attribute("ABF", "sheet-type", "")
      thick = ent.get_attribute("ABF", "sheet-thickness")
      thickness[sheet_type] = thick if thick
      h[sheet_type] = (h[sheet_type] || 0) + 1
      min_sheet_id[sheet_type] = [(min_sheet_id[sheet_type] || 9999), sheet_id].min
    end
    seen3 = h.map { |k, v|
      { thickness: thickness.fetch(k, k), name: k, quantity: v, min_sheet_id: min_sheet_id[k] }
    }
    seen3.sort_by { |fld| fld[:min_sheet_id].to_i }
  end
  def self.part_data_v1(arr)
    arr = arr.sort_by { |rec| [rec[:sheet].to_i, rec[:material].to_s, rec[:name].to_s] }
    rows = arr.map { |rec|
      [
        rec[:index],
        rec[:sheet] != -1 ? rec[:sheet] : "",
        rec[:name],
        rec[:length], rec[:width], rec[:thickness], rec[:material],
        rec[:code_ns][0], rec[:code_ns][1], rec[:code_ns][2],
      ]
    }
    { headers: HEADERS, rows: rows }
  end
  def self.round_lengths_v1(fld)
    return fld unless fld[:count_by_length]
    count_by_length = {}
    fld[:count_by_length].each do |k, v|
      key = k.to_f.round
      count_by_length[key] = (count_by_length[key] || 0) + v
    end
    fld.merge(quantity: fld[:quantity].to_f.round(1), count_by_length: count_by_length)
  end
  def self.round_sums_v1(data)
    acc2 = data[:sum_data]
    data.merge(sum_data: acc2.merge(
      list_intersect: acc2[:list_intersect].map { |fld| round_lengths_v1(fld) },
      list_statistical_object: acc2[:list_statistical_object].map { |fld| round_lengths_v1(fld) },
      list_edgeband: acc2[:list_edgeband].map { |fld| fld.merge(quantity: fld[:quantity].to_f.round(1)) },
    ))
  end
  def self.round_parts_v1(data)
    grp = data[:part_data]
    arr2 = [HEADERS.index("Dài"), HEADERS.index("Rộng")]
    rows = grp[:rows].map { |h|
      arr = h.dup
      arr2.each { |color| arr[color] = arr[color].to_f.round }
      arr
    }
    data.merge(part_data: grp.merge(rows: rows))
  end
  def self.summary_rows_v1
    arr = KSU::Thongke::Quet.selected_roots
    scope = arr.empty? ? KSU::Thongke::Quet.all_roots_v1 : arr
    KSU::Thongke::Phukien.make_unique_all(scope)
    _d0ed3d7d = KSU::Thongke::Quet.list_boards_v1(scope)
    list_connector = KSU::Thongke::Phukien.list_minifix_v1(scope) + KSU::Thongke::Phukien.list_hinge(scope)
    {
      sum_data: {
        list_connector: list_connector,
        list_intersect: KSU::Thongke::Phukien.list_intersect_v1(scope),
        list_statistical_object: KSU::Thongke::Phukien.list_statistical_v1(scope),
        list_edgeband: list_edgeband_v1(_d0ed3d7d),
        list_sheet: list_sheet_v1(scope),
      },
      part_data: part_data_v1(_d0ed3d7d),
    }
  end
end
