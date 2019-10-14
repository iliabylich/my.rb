# require 'ostruct'

# o = OpenStruct.new(a: 1)
# p o
# p o.a
# p o.b

$LOADED_FEATURES.reject! { |file| file.end_with?('set.rb') }
Object.send(:remove_const, :Set)
Object.send(:remove_const, :SortedSet)
require 'set'

s = Set.new
s << 1 << 2 << 3
p s

# def m(a, b:, c: 1, &blk)
#   puts 'method called'
#   result = a + b + c + blk.call(5, 6)
#   p ['result', result]
#   result
# end

# d = 4; z = 100
# p m(1, b: 2, c: 3) { |x, y| p ['block called', x, x]; d + x + y + z }
