module X; puts self; class << self; puts self; end; end
class Y; puts self; class << self; puts self end; end

p [__FILE__, __LINE__]

puts File.expand_path('.', __dir__)
$: << File.expand_path('.', __dir__)
require 'test2'
