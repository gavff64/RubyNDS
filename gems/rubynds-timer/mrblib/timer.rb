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

class FPS
  attr_reader :value

  def initialize
    @ticks = 0
    @started = System.milliseconds
    @value = 0
  end

  def tick
    @ticks += 1
    elapsed = System.milliseconds - @started
    return if elapsed < 1000

    @value = @ticks * 1000 / elapsed
    @ticks = 0
    @started = System.milliseconds
    print "\r\e[2K#{@value} FPS"
  end

  def reset
    @ticks = 0
    @started = System.milliseconds
    @value = 0
  end
end
