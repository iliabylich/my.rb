require 'benchmark/ips'

def in_n_frames(depth = 0, n, blk)
  if depth == n
    blk.call
  else
    in_n_frames(depth + 1, n, blk)
  end
end

# begin
#   in_n_frames(1000, proc { raise 'dead' })
# rescue => e
#   p e.backtrace.length
# end

Benchmark.ips do |x|
  x.config(time: 3)

  x.report('raise') do
    begin
      in_n_frames(1000, proc { raise 'x' })
    rescue => e
    end
  end

  x.report('throw') do
    catch(:x) do
      in_n_frames(1000, proc { throw :x })
    end
  end

  x.compare!
end
