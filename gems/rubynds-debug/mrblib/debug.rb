module Debug
  COMBINATION = KEY_L | KEY_R

  def self.enabled=(enabled)
    @enabled = enabled
    @terminal = false
    Gfx.bottom_mode(:graphics)
  end

  def self.update
    return unless @enabled
    return unless (Input.held & COMBINATION) == COMBINATION
    return unless Input.down?(COMBINATION)

    @terminal = !@terminal
    Gfx.bottom_mode(@terminal ? :terminal : :graphics)
    @terminal
  end

  def self.terminal?
    @terminal
  end
end
