module Timer
  @start = nil

  def self.ms
    now = System.milliseconds
    @start = now unless @start
    now - @start
  end

  def self.reset
    @start = System.milliseconds
  end
end
