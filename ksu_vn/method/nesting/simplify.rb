module KSU::Simplify
  module_function
  def simplify_poly(box, want_ccw)
    n = box.length
    return box if n < 4
    min_x = box.map { |arr3| arr3[0] }.min
    hi_x = box.map { |arr3| arr3[0] }.max
    min_y = box.map { |arr3| arr3[1] }.min
    hi_y = box.map { |arr3| arr3[1] }.max
    num2 = 0.0
    n.times do |i|
      arr6 = box[i]
      b = box[(i + 1) % n]
      num2 += arr6[0] * b[1] - b[0] * arr6[1]
    end
    flag2 = (num2 < 0 ? 1 : -1) * (want_ccw ? 1 : -1)
    vec = []
    (0...n - 1).each { |i| vec << [box[i + 1][0] - box[i][0], box[i + 1][1] - box[i][1]] }
    vec << [box[n - 1][0] - box[0][0], box[n - 1][1] - box[0][1]]
    num5 = 20.0 * Math::PI / 180.0
    num3 = 10.0 * Math::PI / 180.0
    num4 = 40.0 * Math::PI / 180.0
    bnds = []
    idx = 0
    while idx <= n - 1
      if idx < n - 2
        ang = angle_between(vec[idx], vec[idx + 1])
        if ang < num5
          flag = cross2(vec[idx], vec[idx + 1]) > 0 ? -1 : 1
          last_ix = idx
          j = idx + 1
          while j < n - 1
            ang2 = angle_between(vec[j], vec[j + 1])
            flag3 = cross2(vec[j], vec[j + 1]) > 0 ? -1 : 1
            ang_span = angle_between(vec[idx], vec[j + 1])
            break unless (ang2 - ang).abs < num3 && flag3 == flag && ang_span < num4
            last_ix = j
            j += 1
          end
          if last_ix > idx
            bnds << box[idx]
            if flag * flag2 > 0
              meet = line_meet(box[idx], vec[idx], box[last_ix], vec[last_ix])
              bnds << meet if meet
            end
            bnds << box[last_ix]
            idx = last_ix + 1
            next
          end
        end
        bnds << box[idx]
        idx += 1
      else
        bnds << box[idx]
        idx += 1
      end
    end
    arr = []
    bnds.each do |b|
      last = arr.last
      next if last && (b[0] - last[0]).abs < 1e-9 && (b[1] - last[1]).abs < 1e-9
      arr << b
    end
    arr.pop if arr.length > 2 && (arr.first[0] - arr.last[0]).abs < 1e-9 && (arr.first[1] - arr.last[1]).abs < 1e-9
    if arr.length >= 3
      loop do
        ok = true
        i = 1
        while i <= arr.length - 2
          v_in = [arr[i][0] - arr[i - 1][0], arr[i][1] - arr[i - 1][1]]
          _298717ec = [arr[i + 1][0] - arr[i][0], arr[i + 1][1] - arr[i][1]]
          if angle_between(v_in, _298717ec) < 0.01
            arr.delete_at(i)
            ok = false
          else
            i += 1
          end
        end
        break if ok || arr.length < 3
      end
    end
    return box if arr.length < 3
    box4 = [[min_x - 0.0001, min_y - 0.0001], [hi_x + 0.0001, min_y - 0.0001],
               [hi_x + 0.0001, hi_y + 0.0001], [min_x - 0.0001, hi_y + 0.0001]]
    arr7 = clip_to_box(arr, box4)
    arr7.length >= 3 ? arr7 : arr
  end
  def angle_between(arr2, b)
    len_a = Math.sqrt(arr2[0] * arr2[0] + arr2[1] * arr2[1])
    len_b = Math.sqrt(b[0] * b[0] + b[1] * b[1])
    return 0.0 if len_a < 1e-12 || len_b < 1e-12
    color = (arr2[0] * b[0] + arr2[1] * b[1]) / (len_a * len_b)
    color = 1.0 if color > 1.0
    color = -1.0 if color < -1.0
    Math.acos(color)
  end
  def cross2(arr2, b)
    arr2[0] * b[1] - arr2[1] * b[0]
  end
  def line_meet(arr, v, arr2, w)
    num = v[0] * w[1] - v[1] * w[0]
    return nil if num.abs < 1e-12
    thick = ((arr2[0] - arr[0]) * w[1] - (arr2[1] - arr[1]) * w[0]) / num
    [arr[0] + thick * v[0], arr[1] + thick * v[1]]
  end
  def clip_to_box(poly, arr5)
    result = poly
    arr2 = arr5.last
    arr5.each do |arr3|
      arr61 = result
      result = []
      next if arr61.empty?
      _2ecd529b = ->(pt) { (arr3[0] - arr2[0]) * (pt[1] - arr2[1]) > (arr3[1] - arr2[1]) * (pt[0] - arr2[0]) }
      _d2e36cfd = lambda do |s, ent|
        _c421ab5c = arr2[1] - arr3[1]
        _6b658665 = arr2[0] - arr3[0]
        _0939779c = s[1] - ent[1]
        _ff6ec2cb = s[0] - ent[0]
        _3125dfd3 = arr2[0] * arr3[1] - arr2[1] * arr3[0]
        _58259b16 = s[0] * ent[1] - s[1] * ent[0]
        len2d = _6b658665 * _0939779c - _c421ab5c * _ff6ec2cb
        next s if len2d.abs < 1e-12
        num = 1.0 / len2d
        [(_3125dfd3 * _ff6ec2cb - _58259b16 * _6b658665) * num, (_3125dfd3 * _0939779c - _58259b16 * _c421ab5c) * num]
      end
      s = arr61.last
      arr61.each do |ent|
        if _2ecd529b.call(ent)
          result << _d2e36cfd.call(s, ent) unless _2ecd529b.call(s)
          result << ent
        elsif _2ecd529b.call(s)
          result << _d2e36cfd.call(s, ent)
        end
        s = ent
      end
      arr2 = arr3
    end
    result
  end
end
