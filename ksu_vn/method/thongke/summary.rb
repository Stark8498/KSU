module KSU::Thongke::Tonghop
  def self.list_edgeband(_b72afbe5)
    _b72afbe5.each_with_object({}) { |rec, elem|
      mat = rec[:material].to_s
      rec[:edgeband_lengths].each do |k, v|
        (elem[[k, mat, rec[:thickness]]] ||= {
          thickness: rec[:edgeband_thickness].fetch(k, 0), name: rec[:edgeband_base][k].to_s,
          material: mat, board_thickness: rec[:thickness], quantity: 0,
        })[:quantity] += v
      end
    }.values.each { |fld| fld[:quantity] = KSU::Thongke.round_len(fld[:quantity]) }
      .sort_by { |fld| [fld[:name], fld[:material], fld[:board_thickness].to_f] }
  end
  def self.list_sheet(_4230ad5c)
    h = {}
    KSU::Thongke::Quet.each_sheet(_4230ad5c) do |grp, sheet_id|
      next if KSU::Sheet.hidden?(grp)
      sheet_type = grp.get_attribute("ABF", "sheet-type", "")
      fld = (h[sheet_type] ||= { thickness: sheet_type, name: sheet_type, quantity: 0, min_sheet_id: 9999 })
      fld[:thickness] = grp.get_attribute("ABF", "sheet-thickness") || fld[:thickness]
      fld[:quantity] += 1
      fld[:min_sheet_id] = [fld[:min_sheet_id], sheet_id].min
    end
    h.values.sort_by { |fld| fld[:min_sheet_id].to_i }
  end
  def self.part_data(arr)
    rows = arr.sort_by { |rec| [rec[:sheet].to_i, rec[:material].to_s, rec[:name].to_s] }.map { |rec|
      [rec[:index], rec[:sheet] != -1 ? rec[:sheet] : "", *rec.values_at(:name, :length, :width, :thickness, :material),
       *rec[:code_ns].values_at(0, 1, 2)]
    }
    { headers: ["ID", "Tấm", "Tên", "Dài", "Rộng", "Dày", "Vật liệu", "Mã 1", "Mã 2", "Mã 3"], rows: rows }
  end
  def self.round_lengths(fld)
    return fld unless fld[:count_by_length]
    lines = fld[:count_by_length].each_with_object(Hash.new(0)) { |(num, v), elem| elem[num.to_f.round] += v }
    fld.merge(quantity: fld[:quantity].to_f.round(1), count_by_length: lines)
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
    data.merge(part_data: grp.merge(rows: grp[:rows].map { |h|
      h.dup.tap { |half| [3, 4].each { |c| half[c] = half[c].to_f.round } }
    }))
  end
  def self.summary_rows
    arr = KSU.selection.select { |e| KSU.container?(e) }
    roots = arr.empty? ? KSU::Thongke::Quet.all_roots : arr
    KSU::Thongke::Phukien.make_shared_unique(roots)
    _b72afbe5 = KSU::Thongke::Quet.list_boards(roots)
    {
      sum_data: {
        list_connector: KSU::Thongke::Phukien.list_intersect(roots) + KSU::Thongke::Phukien.list_minifix(roots),
        list_intersect: KSU::Thongke::Phukien.group_by_name(roots.flat_map { |gr| KSU::Cutting.kids_with_attr(gr, "is-intersect") || [] }),
        list_statistical_object: KSU::Thongke::Phukien.list_statistical(roots),
        list_edgeband: list_edgeband(_b72afbe5),
        list_sheet: list_sheet(roots),
      },
      part_data: part_data(_b72afbe5),
    }
  end
end
