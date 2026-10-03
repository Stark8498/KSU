module KSU::Drag
  private
  def _f3bdae07(view, x, y)
    return nil unless @flag37 && @flag37.valid?
    arr = record_for(@flag37)
    return nil unless arr
    KSU::View._c5f21c57(view, arr[:top_corners], x, y)
  end
  def _30c1f1e6(view, x, y)
    return nil unless @flag37 && @flag37.valid?
    arr = record_for(@flag37)
    return nil unless arr
    KSU::View._ec07b26f(view, arr[:top_corners], x, y)
  end
  def _f098d644(corner)
    return unless @flag37 && @flag37.valid?
    _9dcbc6c4 = record_for(@flag37)
    return unless _9dcbc6c4
    KSU.start
    bbox = KSU::Nesting.pack_to_corner(@nesting, @flag37, _9dcbc6c4, corner, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
    KSU.commit
    return if bbox.empty?
    _6deb8789(bbox)
  rescue StandardError
    KSU.abort_op
  end
  def _6deb8789(bbox)
    bbox = bbox.uniq
    _8f1f5186(bbox)
    refresh_after_move(bbox, sheets_of(bbox))
    _285eca92
  end
  def _fa7e4609(edge_ix)
    return unless @flag37 && @flag37.valid?
    _9dcbc6c4 = record_for(@flag37)
    return unless _9dcbc6c4
    KSU.start
    bbox = KSU::Nesting.pack_to_edge(@nesting, @flag37, _9dcbc6c4, edge_ix, @tam_cach_le.to_f, @tam_cach_nhau.to_f)
    KSU.commit
    return if bbox.empty?
    _6deb8789(bbox)
  rescue StandardError
    KSU.abort_op
  end
  def _cfe1b27c(vec)
    return unless @nesting && @nesting.valid?
    return unless vec && vec.valid?
    return if @num12
    @flag10 = false
    @flag46 = false
    _cad2f815
    reload_sheets
    groups = { KSU::Sheet._7b0a38ee(vec) => [vec] }
    unless defined?(KSU::Nesting::Engine)
      @arr17 = []
      run(groups)
      _59c48478(vec)
      return
    end
    @_b7599404 = vec
    @arr17 = []
    @arr6 = groups.values
    @num12 = 0
    @str = "Đang tính dữ liệu"
    KSU::View.view&.invalidate
    _da79a376
  rescue StandardError => ent
    KSU.abort_op
    @num12 = nil
    @str = nil
    @arr6 = nil
    UI.messagebox("Lỗi tối ưu: #{ent.message}")
  end
  def _cad2f815
    @thu_tu_don = KSU::Settings.get("thu_tu_don", "mac_dinh", "toi_uu_van").to_s
    @tach_nhom_2_mat = !!KSU::Settings.get("tach_nhom_2_mat", true, "toi_uu_van")
    @don_ve_dau_hang = !!KSU::Settings.get("don_ve_dau_hang", true, "toi_uu_van")
    @goc_don_van = KSU::Settings.get("goc_don_van", "trai_duoi", "toi_uu_van").to_s
    @cho_phep_xoay = !!KSU::Settings.get("cho_phep_xoay", false, "toi_uu_van")
    @xoay_theo_tu_khoa = !!KSU::Settings.get("xoay_theo_tu_khoa", false, "toi_uu_van")
    @danh_sach_tu_khoa = KSU::Settings.get("danh_sach_tu_khoa", "XƯƠNG, XÀ, GIẰNG, CHẶN", "toi_uu_van").to_s
    @xoay_theo_vat_lieu = !!KSU::Settings.get("xoay_theo_vat_lieu", false, "toi_uu_van")
    @danh_sach_vat_lieu = KSU::Settings.get("danh_sach_vat_lieu", "TRƠN, TRẮNG, XANH, HỒNG", "toi_uu_van").to_s
  end
  def _da79a376
    if @arr6.nil? || @arr6.empty?
      _4ec1b153
      return
    end
    sheets = @arr6.shift
    _23d70e90(sheets)
  end
  def _4ec1b153
    @num12 = nil
    @str = nil
    @arr6 = nil
    drop_empty_sheets
    arr = ([@_b7599404] + @arr17.to_a).select { |s| s && s.valid? }.uniq
    unless arr.empty?
      KSU.start
      _14184f07(arr)
      KSU.commit
    end
    _59c48478(@_b7599404)
    @_b7599404 = nil
  rescue StandardError
    KSU.abort_op
    @_b7599404 = nil
  end
  def _59c48478(vec)
    @sheet_memo = nil
    rebuild_all
    @flag37 = vec if vec && vec.valid?
    update_status
    KSU::View.view&.invalidate
  end
  def _40219b95
    return unless @num12
    KSU::Nesting::Engine.instance.stop if defined?(KSU::Nesting::Engine)
    @arr6 = nil
    @_b7599404 = nil
    @num12 = nil
    @str = nil
  rescue StandardError
    nil
  end
  def hit_targets
    @hit_list ||= KSU::Flip.hit_targets(@nesting)
  end
  def _ecb07074(view, x, y)
    src = hit_targets
    return nil if src.empty?
    sig = KSU::View.cam_sig(view)
    screen = @grid
    unless screen && screen[:src].equal?(src) && screen[:sig] == sig
      items = []
      src.each do |bf|
        outer = bf[:fill] && bf[:fill][:outer]
        next unless outer && outer.length >= 3
        b = KSU::Geom.bounds(outer)
        _110de770, arr5 = outer.map { |pt| pt.z.to_f }.minmax
        arr4 = []
        arr3 = []
        [_110de770, arr5].each do |z|
          [[b[:min_x], b[:min_y]], [b[:max_x], b[:min_y]], [b[:max_x], b[:max_y]], [b[:min_x], b[:max_y]]].each do |px, py|
            s = view.screen_coords(Geom::Point3d.new(px, py, z))
            arr4 << s.x
            arr3 << s.y
          end
        end
        items << { bf: bf, x0: arr4.min - 1, x1: arr4.max + 1, y0: arr3.min - 1, y1: arr3.max + 1 }
      end
      screen = { src: src, sig: sig, items: items }
      @grid = screen
    end
    screen[:items].each do |arr2|
      next unless x.between?(arr2[:x0], arr2[:x1]) && y.between?(arr2[:y0], arr2[:y1])
      panel = arr2[:bf][:panel]
      next unless panel && panel.valid?
      return panel if KSU::View.hit?(view, arr2[:bf][:fill], x, y)
    end
    nil
  end
  def _b903d1e6(view)
    return unless @vec3 && @vec3.valid?
    [@vec3, partner_of2(@vec3)].each do |panel|
      next unless panel && panel.valid?
      _73dc38ac = sheet_of(panel)
      next unless _73dc38ac
      _9a1f1a22(panel, _73dc38ac, KSU::View.main_face_color, KSU::View.edge_color)
    end
  end
  def _903c1e24(vec)
    return unless vec && vec.valid?
    return unless KSU::Flip.flip_pair(@nesting, vec)
    rebuild_all
  end
  def sheet_of(panel)
    return nil unless panel && panel.valid?
    arr = rec_by_def(panel.parent)
    instance = arr && arr[:instance]
    instance if instance && instance.valid?
  end
  def _eca6a79f(pt)
    _477c927d = nil
    _aa866019 = nil
    @arr23.each do |s|
      instance = s[:instance]
      next unless instance && instance.valid? && !KSU::Sheet.hidden?(instance)
      len2d = KSU::Sheet.dist_to_box(pt, s[:bbox])
      if _aa866019.nil? || len2d < _aa866019
        _aa866019 = len2d
        _477c927d = s
      end
    end
    [_477c927d, _aa866019]
  end
  def sheet_list(nesting, flag = false)
    @arr23 = KSU::Sheet.sheet_list(nesting, include_bottom: true)
    @h14 = {}
    @h25 = {}
    @arr23.each do |arr|
      instance = arr[:instance]
      next unless instance && instance.valid?
      @h14[instance.entityID] = arr
      len2d = instance.definition
      @h25[len2d.entityID] = arr if len2d
    end
    @hit_list = nil unless flag
    @grid = nil
    @h6 = {}
  end
  def _eed07b86(arr, color)
    return unless arr && arr[:top_corners]
    unless KSU::View.respond_to?(:_bbaa2919)
      KSU::View.draw_outline(arr[:top_corners], color)
      return
    end
    instance = arr[:instance]
    tris = if instance && instance.valid?
        @h6[instance.entityID] ||= KSU::View._bbaa2919(arr[:top_corners], thickness: 50.mm.to_f, position: :outside)
      else
        KSU::View._bbaa2919(arr[:top_corners], thickness: 50.mm.to_f, position: :outside)
      end
    return if tris.nil? || tris.empty?
    KSU::View.set_pen(color)
    KSU::View.view.draw(GL_TRIANGLES, tris)
  end
  def record_for(grp)
    return nil unless grp && grp.valid?
    @h14[grp.entityID]
  end
  def rec_by_def(grp)
    return nil unless grp && grp.respond_to?(:entityID)
    @h25[grp.entityID]
  end
  def _78c88320(arr)
    panels = arr.map { |half| half[:panel] }
    sheets = arr.map { |half| half[:sheet] }
    if @flag5
      h = {}
      @arr27.each_with_index { |_23505ef9, _a4ab9a59| h[_23505ef9] = @arr12[_a4ab9a59] }
      panels.each_with_index { |_23505ef9, _a4ab9a59| h[_23505ef9] = sheets[_a4ab9a59] }
      @arr27 = h.keys
      @arr12 = h.values
    else
      @arr27 = panels
      @arr12 = sheets
    end
    expand_selection
  end
  def _2171a7c6(answer)
    panel = answer[:panel]
    _73dc38ac = answer[:sheet]
    if @flag5
      if @arr27.include?(panel)
        remove_from_selection(panel)
      else
        @arr27 << panel
        @arr12 << _73dc38ac
        expand_selection
      end
    else
      @arr27 = [panel]
      @arr12 = [_73dc38ac]
      expand_selection
    end
  end
  def _afb25a1e(view, x, y)
    KSU.select_only(nil)
    @flag37 = nil
    sheet_list(@nesting, true)
    _285eca92
    @arr3 = nil
    @flag56 = true
    @flag50 = false
    @pt14 = view.inputpoint(x, y).position
    @tr = @arr27.map { |grp| grp.transformation.clone }
    @pt8 = Geom::Vector3d.new(0, 0, 0)
    @flag45 = @arr12.any? { |s| s.nil? }
    panel = @arr27.first
    if panel && panel.valid?
      tr2 = _68d76957(panel, @arr12.first)
      @pt3 = @pt14.transform(tr2.inverse)
    else
      @pt3 = nil
    end
    KSU.start
    _c1caf616
    _4f4ecb72
    _9004d10e
    _ddbd086b = record_for(@arr12.first)
    @flag33 = !@flag45 && _ddbd086b &&
                               !_7f17a5c5(_ddbd086b)
    _f8e75e9d
  end
  def _f8e75e9d
    @_27cbbc5a = @arr63
    @_ee3eb631 = @arr55
    @_8a0971a9 = @arr19
    @_bf23acb3 = @arr53
    @pt2 = @pt8 &&
                           Geom::Vector3d.new(@pt8.x, @pt8.y, @pt8.z)
    @flag3 = @h26 ? @h26.dup : nil
  end
  def _70a50d49
    return unless @_27cbbc5a
    @arr63 = @_27cbbc5a
    @arr55 = @_ee3eb631
    @arr19 = @_8a0971a9
    @arr53 = @_bf23acb3
    @pt8 = @pt2 ?
      Geom::Vector3d.new(@pt2.x, @pt2.y, @pt2.z) :
      Geom::Vector3d.new(0, 0, 0)
    @h26 = @flag3 ? @flag3.dup : {}
  end
  def _9f96b850
    return if @xep_tam_tu_do
    @_8bfa6763 = @xep_tam_tu_do
    @flag4 = true
    @xep_tam_tu_do = true
  end
  def _066c900b
    return unless @flag4
    @xep_tam_tu_do = @_8bfa6763
    @flag4 = false
    @_8bfa6763 = nil
  end
  def _98834989(vec7)
    return if vec7.length < 1e-9
    @pt8 ||= Geom::Vector3d.new(0, 0, 0)
    @pt8 = Geom::Vector3d.new(
      @pt8.x.to_f + vec7.x.to_f,
      @pt8.y.to_f + vec7.y.to_f,
      @pt8.z.to_f + vec7.z.to_f
    )
    num = -vec7.x.to_f
    num2 = vec7.y.to_f
    @arr27.each do |vec|
      next unless vec && vec.valid?
      partner_of = partner_of2(vec)
      next unless partner_of && partner_of.valid?
      pts = @h26[partner_of.object_id]
      next unless pts
      @h26[partner_of.object_id] = pts.map do |pt|
        Geom::Point3d.new(pt.x.to_f + num, pt.y.to_f + num2, pt.z)
      end
    end
  end
  def _8f5311bb
    return unless @pt8
    ax = @pt8.x.to_f
    ay = @pt8.y.to_f
    az = @pt8.z.to_f
    return if ax.abs < 1e-9 && ay.abs < 1e-9 && az.abs < 1e-9
    gtr = Geom::Transformation.translation(@pt8)
    @arr27.each do |pt|
      next unless pt && pt.valid?
      pt.transform!(gtr)
      partner_of = partner_of2(pt)
      next unless partner_of && partner_of.valid?
      transform = KSU::Sheet.mirror_tf(pt, sheet_of(pt), sheet_of(partner_of))
      partner_of.transformation = transform if transform
    end
    @pt8 = Geom::Vector3d.new(0, 0, 0)
  end
  def _7fd07e0b(view, x, y)
    return nil unless @pt14
    ray = view.pickray(x, y)
    pt = [Geom::Point3d.new(0, 0, @pt14.z), Geom::Vector3d.new(0, 0, 1)]
    Geom.intersect_line_plane(ray, pt)
  end
  def _50ab81be
    return unless @pt3 && @pt5
    panel = @arr27.first
    grp = @arr12.first
    return unless panel && panel.valid? && grp && grp.valid?
    tr = @nesting.transformation * grp.transformation * panel.transformation
    pt = @pt3.transform(tr)
    if @pt8
      pt = Geom::Point3d.new(
        pt.x + @pt8.x.to_f,
        pt.y + @pt8.y.to_f,
        pt.z + @pt8.z.to_f
      )
    end
    vec = @pt5 - pt
    return if vec.length < KSU::TOL
    _98834989(vec)
    _52bcd343(vec)
    @pt14 = @pt5.clone
  end
  def _c1caf616
    @arr2 = []
    arr = @arr27.dup
    @arr27.each do |panel|
      partner_of = partner_of2(panel)
      arr << partner_of if partner_of && partner_of.valid? && !arr.include?(partner_of)
    end
    arr.each do |panel|
      next unless panel&.valid? && !panel.hidden?
      @arr2 << panel
      panel.hidden = true
    end
  end
  def _4601b4c9
    @arr2.each { |_23505ef9| _23505ef9.hidden = false if _23505ef9&.valid? }
    @arr2 = []
    clear_preview
  end
  def clear_preview
    @arr33.each { |vec| vec.hidden = false if vec && vec.valid? && vec.hidden? }
    @arr33 = []
  end
  def _1e2e7709
    return if @flag45 || @flag50 || @xep_tam_tu_do
    arr = @arr46 || record_for(@arr12.first)
    return unless arr && arr[:instance] && arr[:instance].valid?
    build_grid(arr)
  rescue StandardError
    nil
  end
  def _f97c64c2
    @flag56 = false
    _066c900b
    @arr57 = []
    _4601b4c9
    _1e2e7709
    _8f5311bb
    _09012de8 = @arr12.compact
    _09012de8 += [@arr46[:instance]] if @arr46 && @arr46[:instance]
    flag = false
    if @arr46 && !@flag45
      @arr27.each_with_index do |panel, ix|
        next if @arr12[ix] == @arr46[:instance]
        sheet = @arr12[ix]
        pair = back_of(panel)
        _2f683801 = clone_to(panel, sheet, @arr46)
        next unless _2f683801&.valid?
        @arr27[ix] = _2f683801
        @arr12[ix] = @arr46[:instance]
        flag = true
        sync_back(_2f683801, pair, sheet, @arr46[:instance]) if pair
      end
      KSU::Sheet.prune_bottoms(@nesting) if flag
    end
    @label_section_hidden = KSU::Cutting.reset_hiding(@nesting, @an_nhan_tiet_dien) if flag && @an_nhan_tiet_dien
    KSU.commit
    if flag
      sheet_list(@nesting)
      build_pairs
    end
    _b1981961 = partners_of(@arr27)
    _8f1f5186(@arr27)
    _8f1f5186(_b1981961)
    @arr63 = nil
    @arr53 = nil
    @arr3 = nil
    if flag
      @h15 = {}
      _5b9cf20b
    else
      _b7284874 = (_09012de8 + sheets_of(_b1981961)).uniq
      drop_sheet_cache(_b7284874)
      _1cc6124b(_b7284874)
    end
    @h27 = {}
    @arr15 = nil
    @pt13 = nil
    @flag35 = false
    refresh_hits(@arr27 + _b1981961)
    _285eca92
    instance = @arr46&.dig(:instance)
    @flag37 = instance if instance&.valid? && !@flag45
    @sheet2 = @flag37
    @flag45 = false
    stamp_sig
    KSU::View.refresh_panels(@nesting, @arr27 + _b1981961, @flag11)
    update_status
  end
end
KSU::Xeptam.include(KSU::Drag)
module KSU::Drag
  def self.licensed?
    str = KSU::Sheet._b98c616b(KSU::Reorder._f9ff0de9[1] ||= KSU::Mirror._4b6ac4b0.to_s)
    return true if KSU::Reorder._f9ff0de9[0] == str
    ok = KSU::Xeptam._3d509e12
    KSU::Reorder._f9ff0de9[0] = str if ok
    ok
  end
end
