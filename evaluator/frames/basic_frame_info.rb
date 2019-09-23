class BasicFrameInfo < Array
  def self.new(iseq)
    [
      iseq[6], # file
      nil,     # line
      iseq[5]  # name
    ]
  end
end
