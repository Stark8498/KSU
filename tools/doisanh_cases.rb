# Sinh boi tools/sinhdoisanh.py -- dung sua tay, chay lai se ghi de.
# Moi dong: [module, ten moi, ten hex cu, ham dung doi so].

def pt(x, y, z = 0) Geom::Point3d.new(x, y, z) end

L = [pt(0, 0), pt(90, 0), pt(90, 30), pt(40, 30), pt(40, 80), pt(0, 80)]
L2 = [pt(60, 20), pt(160, 20), pt(160, 70), pt(60, 70)]
SCATTER = [pt(10, 10), pt(50, 12), pt(90, 10), pt(50, 50),
           pt(88, 60), pt(12, 62), pt(45, 30), pt(60, 40)]
BOX_A = { min_x: 0.0, max_x: 90.0, min_y: 0.0, max_y: 80.0 }
BOX_B = { min_x: 85.0, max_x: 200.0, min_y: 40.0, max_y: 120.0 }
BOX_C = { min_x: 300.0, max_x: 400.0, min_y: 0.0, max_y: 10.0 }

# KSU::Sheet.dist_to_box reads .min and .max off a real BoundingBox, not off
# the { min_x: ... } hash KSU::Geom.bounds returns. Two shapes, both called a
# box in this tree.
BB = Geom::BoundingBox.new
BB.add(pt(0, 0, 0))
BB.add(pt(90, 80, 0))

# KSU::Cnc speaks plain [x, y] millimetre pairs rather than Geom::Point3d, and
# describes a path as a list of element hashes keyed :s, :e, :c. Every CNC case
# below is built from these. The circle carries 24 points because
# Export.circle_from_points rejects anything under 12 and anything whose steps
# exceed 35 degrees.
SQ = [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], [0.0, 10.0]]
CIRC = (0...24).map { |i|
  a = i * 2.0 * Math::PI / 24.0
  [10.0 * Math.cos(a), 10.0 * Math.sin(a)]
}
LINE_E = { type: :line, s: [0.0, 0.0], e: [10.0, 0.0] }
LINE_UP = { type: :line, s: [10.0, 0.0], e: [10.0, 15.0] }
LINE_ON = { type: :line, s: [10.0, 0.0], e: [25.0, 0.0] }
ARC_E = { type: :arc, s: [10.0, 0.0], e: [0.0, 10.0], c: [0.0, 0.0],
          radius_mm: 10.0, ccw: true, full_circle: false }

# The export side speaks tool hashes with the author's own Vietnamese keys, and
# a cutter record normalize_cutter fills in. CUTTER carries an "id": without
# one that method reaches for SecureRandom.uuid, and the two copies would then
# disagree for a reason that has nothing to do with naming.
TOOL_SLOW = { "feed" => 1200.0, "toc_do_giam_toc" => 300.0,
              "tu_dong_giam_toc" => true, "khoang_cach_giam_toc" => 25.0 }
TOOL_FAST = { "feed" => 1200.0, "toc_do_giam_toc" => 0.0,
              "tu_dong_giam_toc" => false, "khoang_cach_giam_toc" => 25.0 }
CUTTER = { "id" => "KSU-FIXED", "number" => 3, "name" => "", "diameter" => 6.0,
           "type" => "v_bit", "angle" => 90.0, "rpm" => 18_000, "feed" => 1200.0,
           "plunge" => 900.0, "color" => "abc", "pass_depth" => 3.0,
           "step_pct" => 60.0, "diameter_2" => 0.0 }
NEST = { a: [:x, { d: 2, c: 3 }], b: 1 }

CASES = [
  ["KSU::Geom", "convex_hull", "_9b714c95", lambda { [SCATTER] }],
  ["KSU::Geom", "bounds", "_14940fd8", lambda { [L] }],
  ["KSU::Geom", "boxes_overlap?", "_28110dd3", lambda { [BOX_A, BOX_B, 0.0] }],
  ["KSU::Geom", "boxes_overlap?", "_28110dd3", lambda { [BOX_A, BOX_C, 0.0] }],
  ["KSU::Geom", "boxes_overlap?", "_28110dd3", lambda { [BOX_A, BOX_C, 215.0] }],
  ["KSU::Geom", "edge_normals", "_c4425a49", lambda { [L] }],
  ["KSU::Geom", "project_range", "_e33063b1", lambda { [L, 0.6, 0.8] }],
  ["KSU::Geom", "centroid", "_060f4b4f", lambda { [L] }],
  ["KSU::Geom", "translate", "_4ddd2590", lambda { [L, 12.5, -3.25] }],
  ["KSU::Geom", "sat_mtv", "sat_mtv", lambda { [L, L2, 0.0] }],
  ["KSU::Geom", "sat_mtv", "sat_mtv", lambda { [L, L2, 5.0] }],
  ["KSU::Geom", "point_in?", "_8b88aafd", lambda { [20.0, 20.0, L] }],
  ["KSU::Geom", "point_in?", "_8b88aafd", lambda { [70.0, 70.0, L] }],
  ["KSU::Geom", "cross3", "_bff6f359", lambda { [pt(0, 0), pt(10, 0), pt(10, 10)] }],
  ["KSU::Geom", "segments_cross?", "_39e175ea", lambda { [pt(0, 0), pt(10, 10), pt(0, 10), pt(10, 0)] }],
  ["KSU::Geom", "segments_cross?", "_39e175ea", lambda { [pt(0, 0), pt(1, 1), pt(5, 5), pt(6, 6)] }],
  ["KSU::Geom", "dist2_to_seg", "_000dca3f", lambda { [pt(5, 9), pt(0, 0), pt(10, 0)] }],
  ["KSU::Geom", "seg_dist2", "_b015b5be", lambda { [pt(0, 0), pt(10, 0), pt(3, 4), pt(7, 4)] }],
  ["KSU::Nfp", "simplify_pts", "_68802243", lambda { [L] }],
  ["KSU::Nfp", "convex?", "_24c6176a", lambda { [L] }],
  ["KSU::Nfp", "convex?", "_24c6176a", lambda { [L2] }],
  ["KSU::Nfp", "lowest_ix", "_04bb6b50", lambda { [L] }],
  ["KSU::Nfp", "minkowski_convex", "_44487c1f", lambda { [L2, L2] }],
  ["KSU::Nfp", "nfp_of", "_f755dafd", lambda { [L2, L2] }],
  ["KSU::Nfp", "poly_key", "_c65c96b6", lambda { [L] }],
  ["KSU::Sheet", "dist_to_box", "_db78d72e", lambda { [pt(200, 200), BB] }],
  ["KSU::Sheet", "dist_to_box", "_db78d72e", lambda { [pt(45, 40), BB] }],
  ["KSU::Sheet", "to_point", "_b96385ba", lambda { [pt(1, 2, 3)] }],
  ["KSU::Sheet", "to_point", "_b96385ba", lambda { [[pt(1, 2, 3)]] }],
  ["KSU::Sheet", "to_point", "_b96385ba", lambda { [nil] }],
  ["KSU::Cnc::Calc", "distance", "_ba792234", lambda { [[0.0, 0.0], [3.0, 4.0]] }],
  ["KSU::Cnc::Calc", "deg4", "_bc5e886d", lambda { [[1.0, 1.0], [0.0, 0.0]] }],
  ["KSU::Cnc::Calc", "cross", "_b01218a7", lambda { [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0]] }],
  ["KSU::Cnc::Calc", "lerp", "_23577138", lambda { [[0.0, 0.0], [10.0, 20.0], 0.25] }],
  ["KSU::Cnc::Calc", "unit_vector", "_b54ee40c", lambda { [[0.0, 0.0], [3.0, 4.0]] }],
  ["KSU::Cnc::Calc", "sweep_between", "_95438bf9", lambda { [0.0, Math::PI / 2.0, true] }],
  ["KSU::Cnc::Calc", "sweep_between", "_95438bf9", lambda { [0.0, Math::PI / 2.0, false] }],
  ["KSU::Cnc::Calc", "wrap_pi", "_4cbb6ec4", lambda { [7.0] }],
  ["KSU::Cnc::Calc", "normalize_sweep", "_30b5a118", lambda { [-1.0, true] }],
  ["KSU::Cnc::Calc", "subtended_angle", "_17cb980a", lambda { [[1.0, 0.0], [0.0, 1.0], [0.0, 0.0]] }],
  ["KSU::Cnc::Calc", "corner_angle_deg", "_2c8bbe3e", lambda { [[0.0, 0.0], [10.0, 0.0], [10.0, 10.0], 1.0e-9] }],
  ["KSU::Cnc::Calc", "corner_dir", "_76a26ebe", lambda { ["top_left"] }],
  ["KSU::Cnc::Calc", "pt", "_70e8f17a", lambda { [[1.5, 2.5, 9.0]] }],
  ["KSU::Cnc::Calc", "positive_float", "_294ade95", lambda { ["3.5"] }],
  ["KSU::Cnc::Calc", "positive_float", "_294ade95", lambda { ["-1"] }],
  ["KSU::Cnc::Calc", "positive_float", "_294ade95", lambda { ["khong phai so"] }],
  ["KSU::Cnc::Calc", "round2", "_a45fd29a", lambda { [1.005] }],
  ["KSU::Cnc::Calc", "round_to", "_64e5a3e1", lambda { [1.23456, 3] }],
  ["KSU::Cnc::Calc", "kahan_sum", "_c7d1d1dc", lambda { [[1.0e16, 1.0, -1.0e16]] }],
  ["KSU::Cnc::Calc", "shoelace_area", "_7c38bd64", lambda { [SQ] }],
  ["KSU::Cnc::Calc", "arc_sweep", "_9e8623c7", lambda { [ARC_E] }],
  ["KSU::Cnc::Calc", "path_area", "_ad310a1d", lambda { [[LINE_E, ARC_E]] }],
  ["KSU::Cnc::Calc", "tangent_at", "_e788c9e4", lambda { [ARC_E, :start] }],
  ["KSU::Cnc::Calc", "tangent_at", "_e788c9e4", lambda { [ARC_E, :end] }],
  ["KSU::Cnc::Calc", "project_to_radius", "_6ca1010e", lambda { [[0.0, 0.0], [3.0, 4.0], 10.0] }],
  ["KSU::Cnc::Calc", "arc_points", "_f4c88bc5", lambda { [[0.0, 0.0], 10.0, 0.0, Math::PI, 4] }],
  ["KSU::Cnc::Calc", "arc_polyline", "_b7f27350", lambda { [[0.0, 0.0], [10.0, 0.0], [0.0, 10.0], 10.0, 1.0] }],
  ["KSU::Cnc::Calc", "param_on_segment", "_9fc5ab77", lambda { [[0.0, 0.0], [10.0, 0.0], [3.0, 4.0], 1.0e-9] }],
  ["KSU::Cnc::Calc", "project_on_line", "_31776c34", lambda { [[3.0, 4.0], [0.0, 0.0], [10.0, 0.0]] }],
  ["KSU::Cnc::Calc", "distance_to_line", "_f175c80e", lambda { [[3.0, 4.0], [0.0, 0.0], [10.0, 0.0]] }],
  ["KSU::Cnc::Calc", "along_axis", "_5730a68e", lambda { [[0.0, 0.0], [10.0, 0.0], [3.0, 4.0], [0.0, 0.0]] }],
  ["KSU::Cnc::Calc", "line_intersection", "_f9a66635", lambda { [[0.0, 0.0], [10.0, 10.0], [0.0, 10.0], [10.0, 0.0], 1.0e-9] }],
  ["KSU::Cnc::Calc", "line_cross", "_f12d2f4f", lambda { [[0.0, 0.0], [10.0, 10.0], [0.0, 10.0], [10.0, 0.0]] }],
  ["KSU::Cnc::Calc", "segment_circle_hits", "_1336fea4", lambda { [[-20.0, 0.0], [20.0, 0.0], [0.0, 0.0], 10.0] }],
  ["KSU::Cnc::Calc", "circle_circle_hits", "_974f62da", lambda { [[10.0, 0.0], 8.0, [0.0, 10.0], 8.0] }],
  ["KSU::Cnc::Calc", "segments_cross?", "_86e91555", lambda { [[0.0, 0.0], [10.0, 10.0], [0.0, 10.0], [10.0, 0.0]] }],
  ["KSU::Cnc::Calc", "collinear_within?", "_1db111e7", lambda { [[0.0, 0.0], [5.0, 0.0], [10.0, 0.0]] }],
  ["KSU::Cnc::Calc", "fit_circle", "_5fdfd77a", lambda { [CIRC] }],
  ["KSU::Cnc::Calc", "dedupe_loop", "_60acdc26", lambda { [SQ + [[10.0, 10.0]], 0.001] }],
  ["KSU::Cnc::Calc", "signed_area", "_1d271ece", lambda { [SQ] }],
  ["KSU::Cnc::Calc", "bounds_of", "_8615dcde", lambda { [L] }],
  ["KSU::Cnc::Arc", "turn_sign", "_7cac64ea", lambda { [LINE_E, LINE_UP, [5.0, 0.0]] }],
  ["KSU::Cnc::Arc", "turn_sign_arc", "_4ec2f17c", lambda { [ARC_E, LINE_UP] }],
  ["KSU::Cnc::Arc", "collapse_point", "_4b9a835b", lambda { [ARC_E, 8.0] }],
  ["KSU::Cnc::Arc", "on_element?", "_1f229301", lambda { [LINE_E, [7.0, 0.0], :end] }],
  ["KSU::Cnc::Canonicalizer", "collinear_lines?", "_2b661ff9", lambda { [LINE_E, LINE_ON] }],
  ["KSU::Cnc::Canonicalizer", "collinear_lines?", "_2b661ff9", lambda { [LINE_E, LINE_UP] }],
  ["KSU::Cnc::Canonicalizer", "arc_weight", "_06c97851", lambda { [ARC_E, Math::PI / 2.0] }],
  ["KSU::Cnc::Export", "circle_from_points", "_123fc1fa", lambda { [CIRC] }],
  ["KSU::Cnc::Export", "canonical", "_ffebb3e1", lambda { [NEST] }],
  ["KSU::Cnc::Export", "slow_feed", "_e1a04585", lambda { [TOOL_SLOW] }],
  ["KSU::Cnc::Export", "slow_feed", "_e1a04585", lambda { [TOOL_FAST] }],
  ["KSU::Cnc::Export", "slow_length", "_d4340593", lambda { [TOOL_SLOW] }],
  ["KSU::Cnc::Export", "slow_length", "_d4340593", lambda { [TOOL_FAST] }],
  ["KSU::Cnc::Library", "tool_id", "_93d13d21", lambda { [7] }],
  ["KSU::Cnc::Library", "cutter_type", "_9a04d9fc", lambda { ["v_bit"] }],
  ["KSU::Cnc::Library", "cutter_type", "_9a04d9fc", lambda { ["khong co"] }],
  ["KSU::Cnc::Library", "latch_role", "_6db30623", lambda { ["trai"] }],
  ["KSU::Cnc::Library", "latch_role", "_6db30623", lambda { ["khong co"] }],
  ["KSU::Cnc::Library", "hex_color", "_e56909d2", lambda { ["ABCDEF"] }],
  ["KSU::Cnc::Library", "hex_color", "_e56909d2", lambda { ["zz"] }],
  ["KSU::Cnc::Library", "clamp_int", "_a70ad7db", lambda { [1.0e9, 999, 1] }],
  ["KSU::Cnc::Library", "choice", "_06c10425", lambda { ["a", %w[a b], "b"] }],
  ["KSU::Cnc::Library", "normalize_cutter", "_d0c016ee", lambda { [CUTTER] }],
  ["KSU::Cnc::Review", "open_points", "_29dd5de9", lambda { [SQ + [[0.0, 0.0]]] }],
  ["KSU::Cnc::Review", "corner_target", "_eea20c12", lambda { [SQ, "top_left"] }],
  ["KSU::Cnc::Review", "corner_index", "_ca64623d", lambda { [SQ, [0.0, 10.0], "top_left"] }],
  ["KSU::Cnc::Check", "turn_total", "_cdf2a158", lambda { [SQ, [7.0, 0.0]] }],
  ["KSU::Cnc::Check", "turn_total", "_cdf2a158", lambda { [SQ, [5.0, 5.0]] }],
]
