module KSU::Simplify
  module_function
  def simplify_poly(box, want_ccw)
    n = box.length
    return box if n < 4
    min_x, min_y, hi_x, hi_y = KSU::Nesting.poly_bounds(box)
    _cbcce633 = box.zip(box.rotate).inject(0.0) { |s, (arr3, b)| s + cross2(arr3, b) }
    flag2 = (_cbcce633 < 0 ? 1 : -1) * (want_ccw ? 1 : -1)
    arr2 = (box.each_cons(2).to_a << [box[0], box[-1]]).map { |arr3, b| [b[0] - arr3[0], b[1] - arr3[1]] }
    _1125c4d1, _74a17b3b, arr7 = [20.0, 10.0, 40.0].map { |len2d| len2d * Math::PI / 180.0 }
    bnds, idx = [], 0
    while idx < n
      bnds << box[idx]
      _20fa2560 = idx
      if idx < n - 2 && (ang = angle_between(arr2[idx], arr2[idx + 1])) < _1125c4d1
        flag = cross2(arr2[idx], arr2[idx + 1]) > 0 ? -1 : 1
        ix = idx + 1
        while ix < n - 1
          _4df72b82 = angle_between(arr2[ix], arr2[ix + 1])
          flag3 = cross2(arr2[ix], arr2[ix + 1]) > 0 ? -1 : 1
          _86974898 = angle_between(arr2[idx], arr2[ix + 1])
          break unless (_4df72b82 - ang).abs < _74a17b3b && flag3 == flag && _86974898 < arr7
          ix += 1
        end
        _20fa2560 = ix - 1
        if _20fa2560 > idx
          _042404e7 = flag * flag2 > 0 && line_meet(box[idx], arr2[idx], box[_20fa2560], arr2[_20fa2560])
          bnds << _042404e7 if _042404e7
          bnds << box[_20fa2560]
        end
      end
      idx = _20fa2560 + 1
    end
    num = ->(arr3, b) { (arr3[0] - b[0]).abs < 1e-9 && (arr3[1] - b[1]).abs < 1e-9 }
    arr = bnds.each_with_object([]) { |b, t| t << b unless t.last && num.call(b, t.last) }
    arr.pop if arr.length > 2 && num.call(arr.first, arr.last)
    ok = false
    until ok || arr.length < 3
      ok, i = true, 1
      while i <= arr.length - 2
        arr5 = [arr[i][0] - arr[i - 1][0], arr[i][1] - arr[i - 1][1]]
        arr4 = [arr[i + 1][0] - arr[i][0], arr[i + 1][1] - arr[i][1]]
        if angle_between(arr5, arr4) < 0.01 && cross2(arr5, arr4) * flag2 > -0.001 * Math.hypot(arr5[0] + arr4[0], arr5[1] + arr4[1])
          arr.delete_at(i)
          ok = false
        else
          i += 1
        end
      end
    end
    return box if arr.length < 3
    arr6 = clip_to_box(arr, [[min_x - 0.0001, min_y - 0.0001], [hi_x + 0.0001, min_y - 0.0001],
                                             [hi_x + 0.0001, hi_y + 0.0001], [min_x - 0.0001, hi_y + 0.0001]])
    arr6.length >= 3 ? arr6 : arr
  end
  def angle_between(arr, b)
    len_a = Math.sqrt(arr[0] * arr[0] + arr[1] * arr[1])
    len_b = Math.sqrt(b[0] * b[0] + b[1] * b[1])
    return 0.0 if len_a < 1e-12 || len_b < 1e-12
    c = (arr[0] * b[0] + arr[1] * b[1]) / (len_a * len_b)
    Math.acos(c > 1.0 ? 1.0 : (c < -1.0 ? -1.0 : c))
  end
  def cross2(arr, b)
    arr[0] * b[1] - arr[1] * b[0]
  end
  def line_meet(arr, v, arr2, w)
    num = cross2(v, w)
    return nil if num.abs < 1e-12
    t = ((arr2[0] - arr[0]) * w[1] - (arr2[1] - arr[1]) * w[0]) / num
    [arr[0] + t * v[0], arr[1] + t * v[1]]
  end
  def clip_to_box(poly, arr4)
    result = poly
    arr4.rotate(-1).zip(arr4).each do |arr2, arr3|
      arr32, result = result, []
      next if arr32.empty?
      inside = ->(segs_for_ray) { (arr3[0] - arr2[0]) * (segs_for_ray[1] - arr2[1]) > (arr3[1] - arr2[1]) * (segs_for_ray[0] - arr2[0]) }
      eax, eay = arr2[1] - arr3[1], arr2[0] - arr3[0]
      _52c3f5b2 = cross2(arr2, arr3)
      seg_meet = lambda do |s, arr|
        ebx, eby = s[1] - arr[1], s[0] - arr[0]
        _f6cf12bd = cross2(s, arr)
        len2d = eay * ebx - eax * eby
        next s if len2d.abs < 1e-12
        num = 1.0 / len2d
        [(_52c3f5b2 * eby - _f6cf12bd * eay) * num, (_52c3f5b2 * ebx - _f6cf12bd * eax) * num]
      end
      s = arr32.last
      _bfe51601 = inside.call(s)
      arr32.each do |arr|
        _f5481ca8 = inside.call(arr)
        result << seg_meet.call(s, arr) if _f5481ca8 != _bfe51601
        result << arr if _f5481ca8
        s, _bfe51601 = arr, _f5481ca8
      end
    end
    result
  end
end
