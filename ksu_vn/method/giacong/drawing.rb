require "fileutils"
module KSU::Giacong
  def self.collect_sheets(db, excluded, table_off)
    nesting = KSU::Nesting.find_nesting(notify: false)
    return nil unless nesting && nesting.valid?
    collect_in_rect = collect_in_rect(nesting)
    h2 = {}.compare_by_identity
    ::KSU::Cnc::Canvas.sheet_rows(db).each do |arr|
      id = arr[:path_key].to_s
      arr[:vectors].each { |vec| (h2[vec.sheet_entity] ||= {})[id] = true if vec.sheet_entity }
    end
    ref_p1 = excluded.to_h { |id| [id.to_s, true] }
    arr2 = collect_in_rect[:sheets].reject do |s|
      h = h2[s[:gr]]
      h ? h.keys.all? { |id| ref_p1[id] } : table_off.include?(sheet_material(s[:front]))
    end
    [collect_in_rect, arr2]
  end
  def self.sheet_material(grp)
    rec = ::KSU::Cnc::Record.new
    rec.sheet_entity = grp
    vectors = [rec]
    ::KSU::Cnc::Canvas.material_and_label(grp.name, vectors, ::KSU::Cnc::Export.sheet_thickness(vectors: vectors))[0]
  end
  def self.export_dxf(folder, db, excluded, table_off, progress: nil, found: nil)
    partner = found || collect_sheets(db, excluded, table_off)
    return { ok: false, count: 0, failed: [], dir: nil } unless partner && !partner[1].empty?
    model = Sketchup.active_model
    title = entity_name(model.title)
    title = "KSU" if title.empty?
    dir = File.join(folder, title + "__" + Time.now.strftime("%H-%M-%S"))
    slot = ::KSU::Cnc::Dialog.normalized_settings["toi_uu_xuong_dao"] ? build_context(db, model) : nil
    fail = write_dxf_files(dir, partner[0], partner[1], slot, progress)
    { ok: fail.empty?, count: partner[1].length - fail.length, failed: fail, dir: dir }
  end
  def self.sheet_slug(s)
    entity_name(s[:key]).gsub(/_+/, "_")
  end
  def self.dxf_filename(s, arr)
    normal = sheet_slug(s) + "_" + s[:id].to_s.rjust(3, "0")
    normal += s[:bottom] ? "_01" : "_02" if arr[s[:key]]
    normal + ".dxf"
  end
  def self.write_dxf_files(dir, collect_in_rect, sheets, slot, progress)
    FileUtils.mkdir_p(dir)
    arr2 = sheets.map { |s| s[:key] }.uniq
    h = {}
    sheets.each { |s| h[s[:key]] = true if s[:bottom] }
    fail = []
    done = 0
    arr2.each_with_index do |key, i|
      arr = sheets.select { |s| s[:key] == key }
      str = File.join(dir, (i + 1).to_s.rjust(3, "0") + "_" + sheet_slug(arr.first))
      FileUtils.mkdir_p(str)
      str3 = str
      str2 = str
      if h[key]
        str3 = File.join(str, "TOP")
        str2 = File.join(str, "BOTTOM")
        FileUtils.mkdir_p(str3)
        FileUtils.mkdir_p(str2)
      end
      arr.each do |s|
        progress&.call(5 + 90 * done / sheets.length)
        done += 1
        _5133d650 = KSU::Giacong::Dxf.new(collect_in_rect[:true_color])
        write_entities(_5133d650, s[:ents], slot && !s[:bottom] ? [s, slot] : nil)
        path = File.join(s[:bottom] ? str2 : str3, dxf_filename(s, h))
        fail << path unless _5133d650.store_post(path)
      end
    end
    fail
  end
  def self.write_entities(_5133d650, ents, slot)
    ents.each do |entity|
      arr = entity[:pts].map { |arr3| KSU::Giacong::PtEx.new(arr3[0], arr3[1], 0) }
      if entity[:via_module]
        if entity[:closed]
          arr2 = detect_arc(arr)
          if arr2
            _5133d650.write_circle(arr2[:center], arr2[:radius], entity[:layer])
            next
          end
        end
        arr = simplify_loop(arr)
      end
      target = slot && vector_for(entity, *slot)
      arr = rotate_to_point(arr, target) if target
      _5133d650.write_polyline(arr, entity[:layer], entity[:closed])
    end
  end
end
