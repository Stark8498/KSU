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

CASES = [
  ["KSU::Geom", "convex_hull", "_35c2c696", lambda { [SCATTER] }],
  ["KSU::Geom", "bounds", "_63a66557", lambda { [L] }],
  ["KSU::Geom", "boxes_overlap?", "_5666a38f", lambda { [BOX_A, BOX_B, 0.0] }],
  ["KSU::Geom", "boxes_overlap?", "_5666a38f", lambda { [BOX_A, BOX_C, 0.0] }],
  ["KSU::Geom", "boxes_overlap?", "_5666a38f", lambda { [BOX_A, BOX_C, 215.0] }],
  ["KSU::Geom", "edge_normals", "_a82acccd", lambda { [L] }],
  ["KSU::Geom", "project_range", "_1a71cf37", lambda { [L, 0.6, 0.8] }],
  ["KSU::Geom", "centroid", "_71d9e5d3", lambda { [L] }],
  ["KSU::Geom", "translate", "_fc888960", lambda { [L, 12.5, -3.25] }],
  ["KSU::Geom", "sat_mtv", "sat_mtv", lambda { [L, L2, 0.0] }],
  ["KSU::Geom", "sat_mtv", "sat_mtv", lambda { [L, L2, 5.0] }],
  ["KSU::Geom", "point_in?", "_8bddc18c", lambda { [20.0, 20.0, L] }],
  ["KSU::Geom", "point_in?", "_8bddc18c", lambda { [70.0, 70.0, L] }],
  ["KSU::Geom", "cross3", "_19da360c", lambda { [pt(0, 0), pt(10, 0), pt(10, 10)] }],
  ["KSU::Geom", "segments_cross?", "_54e62b06", lambda { [pt(0, 0), pt(10, 10), pt(0, 10), pt(10, 0)] }],
  ["KSU::Geom", "segments_cross?", "_54e62b06", lambda { [pt(0, 0), pt(1, 1), pt(5, 5), pt(6, 6)] }],
  ["KSU::Geom", "dist2_to_seg", "_0c8b8a0e", lambda { [pt(5, 9), pt(0, 0), pt(10, 0)] }],
  ["KSU::Geom", "seg_dist2", "_ac86f211", lambda { [pt(0, 0), pt(10, 0), pt(3, 4), pt(7, 4)] }],
  ["KSU::Nfp", "simplify_pts", "_7f9a6edc", lambda { [L] }],
  ["KSU::Nfp", "convex?", "_b4c1b27a", lambda { [L] }],
  ["KSU::Nfp", "convex?", "_b4c1b27a", lambda { [L2] }],
  ["KSU::Nfp", "lowest_ix", "_f5c19a2b", lambda { [L] }],
  ["KSU::Nfp", "minkowski_convex", "_db5a8bb4", lambda { [L2, L2] }],
  ["KSU::Nfp", "nfp_of", "_cc303760", lambda { [L2, L2] }],
  ["KSU::Nfp", "poly_key", "_d0de1f0f", lambda { [L] }],
  ["KSU::Sheet", "dist_to_box", "_71ed53b5", lambda { [pt(200, 200), BB] }],
  ["KSU::Sheet", "dist_to_box", "_71ed53b5", lambda { [pt(45, 40), BB] }],
  ["KSU::Sheet", "to_point", "_32121b6c", lambda { [pt(1, 2, 3)] }],
  ["KSU::Sheet", "to_point", "_32121b6c", lambda { [[pt(1, 2, 3)]] }],
  ["KSU::Sheet", "to_point", "_32121b6c", lambda { [nil] }],
]
