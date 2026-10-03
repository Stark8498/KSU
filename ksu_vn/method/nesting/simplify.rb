module KSU::Simplify
  module_function
  def _c71fe5d3(box, _24bf279f)
    n = box.length
    return box if n < 4
    min_x = box.map { |arr3| arr3[0] }.min
    arr8 = box.map { |arr3| arr3[0] }.max
    min_y = box.map { |arr3| arr3[1] }.min
    arr9 = box.map { |arr3| arr3[1] }.max
    num2 = 0.0
    n.times do |num|
      arr6 = box[num]
      b = box[(num + 1) % n]
      num2 += arr6[0] * b[1] - b[0] * arr6[1]
    end
    flag2 = (num2 < 0 ? 1 : -1) * (_24bf279f ? 1 : -1)
    vec = []
    (0...n - 1).each { |num| vec << [box[num + 1][0] - box[num][0], box[num + 1][1] - box[num][1]] }
    vec << [box[n - 1][0] - box[0][0], box[n - 1][1] - box[0][1]]
    num5 = 20.0 * Math::PI / 180.0
    num3 = 10.0 * Math::PI / 180.0
    num4 = 40.0 * Math::PI / 180.0
    bounds = []
    idx = 0
    while idx <= n - 1
      if idx < n - 2
        ang = _877aa5f8(vec[idx], vec[idx + 1])
        if ang < num5
          flag = _92674c1b(vec[idx], vec[idx + 1]) > 0 ? -1 : 1
          _474c31eb = idx
          j = idx + 1
          while j < n - 1
            _4bfaa449 = _877aa5f8(vec[j], vec[j + 1])
            flag3 = _92674c1b(vec[j], vec[j + 1]) > 0 ? -1 : 1
            _a836bc0b = _877aa5f8(vec[idx], vec[j + 1])
            break unless (_4bfaa449 - ang).abs < num3 && flag3 == flag && _a836bc0b < num4
            _474c31eb = j
            j += 1
          end
          if _474c31eb > idx
            bounds << box[idx]
            if flag * flag2 > 0
              _76ee3d2c = _03ea1bb7(box[idx], vec[idx], box[_474c31eb], vec[_474c31eb])
              bounds << _76ee3d2c if _76ee3d2c
            end
            bounds << box[_474c31eb]
            idx = _474c31eb + 1
            next
          end
        end
        bounds << box[idx]
        idx += 1
      else
        bounds << box[idx]
        idx += 1
      end
    end
    arr = []
    bounds.each do |b|
      rect = arr.last
      next if rect && (b[0] - rect[0]).abs < 1e-9 && (b[1] - rect[1]).abs < 1e-9
      arr << b
    end
    arr.pop if arr.length > 2 && (arr.first[0] - arr.last[0]).abs < 1e-9 && (arr.first[1] - arr.last[1]).abs < 1e-9
    if arr.length >= 3
      loop do
        ok = true
        num = 1
        while num <= arr.length - 2
          _7e2557de = [arr[num][0] - arr[num - 1][0], arr[num][1] - arr[num - 1][1]]
          _298717ec = [arr[num + 1][0] - arr[num][0], arr[num + 1][1] - arr[num][1]]
          if _877aa5f8(_7e2557de, _298717ec) < 0.01
            arr.delete_at(num)
            ok = false
          else
            num += 1
          end
        end
        break if ok || arr.length < 3
      end
    end
    return box if arr.length < 3
    _72faa8fa = [[min_x - 0.0001, min_y - 0.0001], [arr8 + 0.0001, min_y - 0.0001],
               [arr8 + 0.0001, arr9 + 0.0001], [min_x - 0.0001, arr9 + 0.0001]]
    arr7 = _578e7a65(arr, _72faa8fa)
    arr7.length >= 3 ? arr7 : arr
  end
  def _877aa5f8(arr2, b)
    _8efa9bce = Math.sqrt(arr2[0] * arr2[0] + arr2[1] * arr2[1])
    _71d780bd = Math.sqrt(b[0] * b[0] + b[1] * b[1])
    return 0.0 if _8efa9bce < 1e-12 || _71d780bd < 1e-12
    color = (arr2[0] * b[0] + arr2[1] * b[1]) / (_8efa9bce * _71d780bd)
    color = 1.0 if color > 1.0
    color = -1.0 if color < -1.0
    Math.acos(color)
  end
  def _92674c1b(arr2, b)
    arr2[0] * b[1] - arr2[1] * b[0]
  end
  def _03ea1bb7(arr, v, arr2, num3)
    num = v[0] * num3[1] - v[1] * num3[0]
    return nil if num.abs < 1e-12
    thick = ((arr2[0] - arr[0]) * num3[1] - (arr2[1] - arr[1]) * num3[0]) / num
    [arr[0] + thick * v[0], arr[1] + thick * v[1]]
  end
  def _578e7a65(_6125f482, arr5)
    result = _6125f482
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
