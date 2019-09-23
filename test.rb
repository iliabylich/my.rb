class A
  # def m(n)
  #   [1, 2, 3, n].map { |x| x * 2 }.inject(&:+)
  # end
end

class B < A
  # start = 3
  # mlhs: flatten <-
  # kwrest
  # -skip (reserved for internal kwargs hash which is set manually and not via insn)
  # kwargs: <-
  # tail: <-
  # - skip
  # req: <- (skip mlhs)
  def m(a, a2, (b, b2, c, c2, d, d2), e, e2, (mlhs), opt1 = 170, opt2 = (2+3), *f, g:, g2:, h: 1002, h2: ('d' + 'efault'), h3: ('a' + 'b'), **i)
    puts [
      "a = #{a.inspect}",
      "a2 = #{a2.inspect}",
      "b = #{b.inspect}",
      "b2 = #{b2.inspect}",
      "c = #{c.inspect}",
      "c2 = #{c2.inspect}",
      "d = #{d.inspect}",
      "d2 = #{d2.inspect}",
      "e = #{e.inspect}",
      "e2 = #{e2.inspect}",
      "mlhs = #{mlhs.inspect}",
      "opt1 = #{opt1.inspect}",
      "opt2 = #{opt2.inspect}",
      "f = #{f.inspect}",
      "g = #{g.inspect}",
      "g2 = #{g2.inspect}",
      "h = #{h.inspect}",
      "h2 = #{h2.inspect}",
      "h3 = #{h3.inspect}",
      "i = #{i.inspect}",
    ]
    # super(4) * a * b * c
    142
  end
end

B.new.m(1, 2, [3, 4, 5, 6, 7, 8], 9, 10, [11], 12, 13, 13, g: 14, g2: 15, h: 16, i: 17, h3: 'hh3', j: 18)
# p A.ancestors
# p B.ancestors
# p 4200

