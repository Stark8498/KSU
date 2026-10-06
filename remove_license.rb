# frozen_string_literal: true
# Xoa toan bo luong license khoi ma nguon KSU ( chay 1 lan, sau do co the xoa file nay)
require "fileutils"

ROOT = File.join(__dir__, "ksu_vn")

def read(p)
  File.read(p, encoding: "UTF-8")
end

def write(p, s)
  File.write(p, s)
end

def each_rb
  Dir[File.join(ROOT, "**", "*.rb")].sort.each { |f| yield f }
end

report = Hash.new(0)

# ---------------------------------------------------------------------------
# BUOC 1: cat het khoi `class/module ... check_license / assert_license`
#   - neu block chi chua 2 ham check/assert -> xoa ca block
#   - neu block con ham khac (normalize_id, validate_key...) -> giu lai phan con
# Block bat dau bang dong dinh nghia va ket thuc bang dong `end` o cot 0.
# ---------------------------------------------------------------------------
block_re = /^((?:class|module)\s+\S+\n(?:(?!^(?:class|module)\s).)*?\nend\n)/m

each_rb do |f|
  src = read(f)
  out = +""
  pos = 0
  src.scan(block_re) do
    m = Regexp.last_match
    blk = m[0]
    if blk =~ /^\s*def self\.(?:check_license|assert_license)\b/
      body = blk.lines.reject { |l| l =~ /^\s*def self\.(?:check_license|assert_license)\b/ }
      # loai toan bo than cua 2 ham (tat ca dong nam giua def va end cuoi)
      kept = []
      skipping = false
      blk.lines.each do |l|
        if l =~ /^\s*def self\.(?:check_license|assert_license)\b/
          skipping = true
          next
        end
        if skipping
          if l =~ /^  end\s*\n?\z/
            skipping = false
          end
          next
        end
        kept << l
      end
      meaningful = kept.reject { |l| l.strip.empty? || l.strip == "end" }
      if meaningful.size <= 1 # chi con dong dinh nghia + end -> xoa ca block
        report[:blocks_removed] += 1
      else
        out << src[pos...m.begin(0)] << kept.join
        report[:blocks_trimmed] += 1
      end
      pos = m.end(0)
    end
  end
  out << src[pos..] unless out.empty?
  write(f, out) unless out == src && pos.zero?
end

# ---------------------------------------------------------------------------
# BUOC 2: xoa cac dong GOI check_license / assert_license con sot lai
# ---------------------------------------------------------------------------
each_rb do |f|
  src = read(f)
  lines = src.lines.reject { |l| l =~ /^\s*(?:::)?KSU::\w+(?:::\w+)?\.(?:check_license|assert_license)\s*$/ }
  n = src.lines.size - lines.size
  report[:call_lines] += n
  write(f, lines.join) if n.positive?
end

# ---------------------------------------------------------------------------
# BUOC 3: sua cac diem neu/co van ban license
# ---------------------------------------------------------------------------

# main.rb: with_license goi thang block
p1 = File.join(ROOT, "main.rb")
s1 = read(p1)
raise "main.rb not found" unless s1.include?("def self.with_license")
s1.sub!(/def self\.with_license\(&run_blk)\n.*?\n\s*end\n/m,
        "def self.with_license(&run_blk)\n    run_blk&.call\n  end\n")
write(p1, s1)

# utils/other.rb: bo chan trong select_tool
p2 = File.join(ROOT, "utils", "other.rb")
s2 = read(p2)
s2.sub!(/^\s*return unless KSU::Drag\.licensed\? == true\n/m, "")
write(p2, s2)

# method/xeptam/drag.rb: xoa module KSU::Drag licensed? o cuoi file
p3 = File.join(ROOT, "method", "xeptam", "drag.rb")
s3 = read(p3)
s3.sub!(/\nmodule KSU::Drag\n(?:.*?)\ndef self\.licensed\?.*?\nend\n\z/m, "\n")
s3.sub!(/\nmodule KSU::Drag\n(?:.|\n)*?\nend\n\z/, "\n") if s3.include?("licensed?")
write(p3, s3)

# method/xeptam.rb: xoa class KSU::Xeptam license_gate o cuoi file
p4 = File.join(ROOT, "method", "xeptam.rb")
s4 = read(p4)
s4.sub!(/class KSU::Xeptam\n  def self\.license_gate\n(?:.|\n)*?\nend\n/, "")
write(p4, s4)

# utils/flip.rb: xoa read_license_file + prompt_activate, xoa luon require "json"
p5 = File.join(ROOT, "utils", "flip.rb")
s5 = read(p5)
s5.sub!(/^require "json"\n/, "")
s5.sub!(/module KSU::Flip\n(?:.|\n)*?\nprompt_activate\n(?:.|\n)*?\nend\n\z/) { "module KSU::Flip\nend\n" }
write(p5, s5)

# utils/view.rb: xoa seed_license_file + show_activation_result
p6 = File.join(ROOT, "utils", "view.rb")
s6 = read(p6)
if s6.include?("def self.seed_license_file")
  i = s6.index("module KSU::View\n  def self.seed_license_file")
  j = s6.index("\nend\n", s6.index("def self.show_activation_result"))
  s6 = s6[0...i] + "module KSU::View\nend\n" + s6[(j + 2)..]
end
write(p6, s6)

# method/xeptam/nfp.rb: xoa save_binding
p7 = File.join(ROOT, "method", "xeptam", "nfp.rb")
s7 = read(p7)
s7.sub!(/module KSU::Nfp\n  def self\.save_binding\(key\)\n(?:.|\n)*?\nend\n/, "module KSU::Nfp\n")
write(p7, s7)

# method/xeptam/push.rb: xoa clear_license
p8 = File.join(ROOT, "method", "xeptam", "push.rb")
s8 = read(p8)
s8.sub!(/module KSU::Push\n  def self\.clear_license\n(?:.|\n)*?\nend\n/, "module KSU::Push\n")
write(p8, s8)

# method/toiuu/postproc.rb & toiuuvan/postproc.rb: xoa confirm_deactivate(_v1), unpack_value van giu
%w[method/toiuu/postproc.rb method/toiuuvan/postproc.rb].each do |rel|
  pp = File.join(ROOT, rel)
  ss = read(pp)
  ss.sub!(/  def self\.confirm_deactivate(_v1)?\n(?:.|\n)*?\n  end\n/, "")
  write(pp, ss)
end

# utils/sheet/reorder.rb: xoa deactivate_error
pr = File.join(ROOT, "utils", "sheet", "reorder.rb")
sr = read(pr)
sr.sub!(/  def self\.deactivate_error\(err_code\)\n(?:.|\n)*?\n  end\n/, "")
write(pr, sr)

# utils/nesting/corner.rb: xoa deactivate_now
pc = File.join(ROOT, "utils", "nesting", "corner.rb")
sc = read(pc)
sc.sub!(/module KSU::Corner\n  def self\.deactivate_now\(key\)\n(?:.|\n)*?\nend\n/, "module KSU::Corner\n")
write(pc, sc)

# utils/preset/field.rb: xoa activation_ok?
pf = File.join(ROOT, "utils", "preset", "field.rb")
sf = read(pf)
sf.sub!(/module KSU::Field\n  def self\.activation_ok\?\(resp\)\n(?:.|\n)*?\nend\n/, "module KSU::Field\n")
write(pf, sf)

# utils/cutting.rb: xoa license_path + deactivate_key (giu require "uri" an toan)
pcut = File.join(ROOT, "utils", "cutting.rb")
scut = read(pcut)
scut.sub!(/module KSU::Cutting\n  def self\.license_path\n(?:.|\n)*?\nend\n/, "module KSU::Cutting\n")
scut.sub!(/module KSU::Cutting\n  def self\.deactivate_key\n(?:.|\n)*?\nend\n/, "module KSU::Cutting\n") if scut.include?("def self.deactivate_key")
# xoa kiieu tren: tim chinh xac hon
scut.sub!(/  def self\.deactivate_key\(serial_key\)\n(?:.|\n)*?\n  end\n/, "")
write(pcut, scut)

# utils/cutting/loop.rb: xoa license_url
pl = File.join(ROOT, "utils", "cutting", "loop.rb")
sl = read(pl)
sl.sub!(/module KSU::Loop\n  def self\.license_url\(serial_key, request\)\n(?:.|\n)*?\nend\n/, "module KSU::Loop\n")
write(pl, sl)

# method/chontam.rb: xoa validate_key (neu block chi con no thi buoc 1 da xu ly; o day thay bang no-op an toan)
# => da bi xoa o Buoc 1 vi nam trong class chi chua no + check/assert. Bo qua.

# method/chongbay/shape.rb: xoa activations_left
ps = File.join(ROOT, "method", "chongbay", "shape.rb")
ss = read(ps)
ss.sub!(/  def self\.activations_left\(resp, key\)\n(?:.|\n)*?\n  end\n/, "")
write(ps, ss)

# system/setting.rb: xoa activate_key, callbacks gan-xoa kich hoat, doi dieu kien export/import online
pst = File.join(ROOT, "system", "setting.rb")
sst = read(pst)
sst.sub!(/  def self\.activate_key\(serial_key\)\n(?:.|\n)*?\n  end\n/, "")
sst.sub!(/    dlg2\.add_action_callback\("remove_activation"\) do \|_item\|\n(?:.|\n)*?    end\n/) { "" }
sst.sub!(/      key = KSU::Gannhan\.license_field\("k"\)\n      KSU::Cutting\.deactivate_key\(key\) unless key\.to_s\.empty\?\n      KSU::Store\.set_binding\("k", ""\)\n      KSU::Store\.set_binding\("i", ""\)\n      KSU::Store\.set_binding\("t", ""\)\n/, "")
sst.gsub!(/    key = KSU::Gannhan\.license_field\("k"\)\n    if key\.to_s\.empty\?\n      UI\.messagebox\("Chưa kích hoạt phần mềm!"\)\n      return false\n    end\n/, "")
write(pst, sst)

# method/catcuoi.rb & netcatcuoi.rb: xoa rebind_license
%w[method/catcuoi.rb method/netcatcuoi.rb].each do |rel|
  prn = File.join(ROOT, rel)
  srn = read(prn)
  srn.sub!(/class KSU::\w+\n  def self\.rebind_license\n(?:.|\n)*?\nend\n/, "")
  write(prn, srn)
end

# method/toiuu/engine.rb & toiuuvan/engine.rb: xoa license blocks
pe = File.join(ROOT, "method", "toiuu", "engine.rb")
se = read(pe)
se.sub!(/module KSU::Engine\n  def self\.license_ok\?\n(?:.|\n)*?\nend\n/, "module KSU::Engine\n")
write(pe, se)
pe2 = File.join(ROOT, "method", "toiuuvan", "engine.rb")
se2 = read(pe2)
se2.sub!(/module KSU::Engine\n  def self\.license_ok_v1\?\n(?:.|\n)*?\nend\n/, "module KSU::Engine\n")
write(pe2, se2)

# method/chongbay/assign.rb: xoa activate_here
pa = File.join(ROOT, "method", "chongbay", "assign.rb")
sa = read(pa)
sa.sub!(/module KSU::Assign\n  def self\.activate_here\(key\)\n(?:.|\n)*?\nend\n/, "module KSU::Assign\n")
write(pa, sa)

# method/gannhan.rb: xoa license_field
pg = File.join(ROOT, "method", "gannhan.rb")
sg = read(pg)
sg.sub!(/class KSU::Gannhan\n  def self\.license_field\(key\)\n(?:.|\n)*?\nend\n/, "")
write(pg, sg)

# method/toiuu.rb & toiuuvan.rb: xoa drop_id_cache
%w[method/toiuu.rb method/toiuuvan.rb].each do |rel|
  pd = File.join(ROOT, rel)
  sd = read(pd)
  sd.sub!(/class KSU::\w+\n  def self\.drop_id_cache\n(?:.|\n)*?\nend\n/, "")
  write(pd, sd)
end

# utils/view/query.rb: xoa drop_id_cache2
pq = File.join(ROOT, "utils", "view", "query.rb")
sq = read(pq)
sq.sub!(/module KSU::Query\n  def self\.drop_id_cache2\n(?:.|\n)*?\nend\n/, "module KSU::Query\n")
write(pq, sq)

# method/xeptam/mirror.rb: xoa machine_id
pm = File.join(ROOT, "method", "xeptam", "mirror.rb")
sm = read(pm)
sm.sub!(/module KSU::Mirror\n  def self\.machine_id\n(?:.|\n)*?\nend\n/, "module KSU::Mirror\n")
write(pm, sm)

# utils/sheet/bottom.rb: xoa bound_here?
pb = File.join(ROOT, "utils", "sheet", "bottom.rb")
sb = read(pb)
sb.sub!(/module KSU::Bottom\n  def self\.bound_here\?\n(?:.|\n)*?\nend\n/, "module KSU::Bottom\n")
write(pb, sb)

# method/chongbay.rb: xoa read_bindings block
pcb = File.join(ROOT, "method", "chongbay.rb")
scb = read(pcb)
scb.sub!(/class KSU::Chongbay\n  def self\.read_bindings\n(?:.|\n)*?\nend\n/, "")
write(pcb, scb)

# utils/font/data.rb: chi giu module KSU::Font rong (xoa FONT_B64 + read_license)
pfd = File.join(ROOT, "utils", "font", "data.rb")
File.write(pfd, "module KSU::Font\nend\n")

# utils/nesting/optimize.rb: xoa write_license
po = File.join(ROOT, "utils", "nesting", "optimize.rb")
so = read(po)
so.sub!(/^require "json"\nmodule KSU::Optimize\n  def self\.write_license\(data\)\n(?:.|\n)*?\nend\n/, "module KSU::Optimize\n")
write(po, so)

# utils/preset/mode.rb: xoa write_binding_key
pmd = File.join(ROOT, "utils", "preset", "mode.rb")
smd = read(pmd)
smd.sub!(/module KSU::Mode\n  def self\.write_binding_key\(key, val\)\n(?:.|\n)*?\nend\n/, "module KSU::Mode\n")
write(pmd, smd)

# utils/preset/store.rb: xoa set_binding
pstore = File.join(ROOT, "utils", "preset", "store.rb")
sstore = read(pstore)
sstore.sub!(/module KSU::Store\n  def self\.set_binding\(key, val\)\n(?:.|\n)*?\nend\n/, "module KSU::Store\n")
write(pstore, sstore)

# method/catcuoi/lastcut.rb & netcatcuoi/lastcut.rb: xoa license_value(_v1)
%w[method/catcuoi/lastcut.rb method/netcatcuoi/lastcut.rb].each do |rel|
  pl2 = File.join(ROOT, rel)
  sl2 = read(pl2)
  sl2.sub!(/module KSU::Lastcut\n  def self\.license_value(_v1)?\(key, default\)\n(?:.|\n)*?\nend\n/, "module KSU::Lastcut\n")
  write(pl2, sl2)
end

# utils/nesting/edit.rb: xoa clear_bindings
ped = File.join(ROOT, "utils", "nesting", "edit.rb")
sed = read(ped)
sed.sub!(/module KSU::Edit\n  def self\.clear_bindings\n(?:.|\n)*?\nend\n/, "module KSU::Edit\n")
write(ped, sed)

# method/xeptam/collide.rb: xoa license_json + activation_errors
pcl = File.join(ROOT, "method", "xeptam", "collide.rb")
scl = read(pcl)
scl.sub!(/module KSU::Collide\n  def self\.license_json\n(?:.|\n)*?\nend\n/, "module KSU::Collide\n")
scl.sub!(/  def self\.activation_errors\n(?:.|\n)*?\n  end\n/, "")
write(pcl, scl)

# utils/view/widget.rb: xoa ask_key
pw = File.join(ROOT, "utils", "view", "widget.rb")
sw = read(pw)
sw.sub!(/  def self\.ask_key\n(?:.|\n)*?\n  end\n/, "")
write(pw, sw)

puts "DONE: #{report.inspect}"
