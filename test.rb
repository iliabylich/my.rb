# require 'ostruct'

# o = OpenStruct.new(a: 1)
# p o.a
# p o.b

def m(a, b:, c: 1, &blk)
  puts 'method called'
  result = a + b + c + blk.call(5, 6)
  p ['result', result]
  result
end

d = 4; z = 100
p m(1, b: 2, c: 3) { |x, y| p ['block called', x, x]; d + x + y + z }
