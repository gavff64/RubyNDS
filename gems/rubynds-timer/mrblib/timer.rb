module Timer
  @frames = 0

  def self.ms
    milliseconds = @frames * 1000 / 60
    @frames += 1
    milliseconds
  end

  def self.reset
    @frames = 0
  end
end
