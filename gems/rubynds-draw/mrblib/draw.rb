module Color
  def self.rgb(r, g, b)
    (r & 31) | ((g & 31) << 5) | ((b & 31) << 10) | (1 << 15)
  end
end

RED = Color.rgb(31, 0, 0)
YELLOW = Color.rgb(31, 31, 0)
BLUE = Color.rgb(0, 0, 31)
GREEN = Color.rgb(0, 31, 0)
GRAY = Color.rgb(24, 24, 24)
BLACK = Color.rgb(0, 0, 0)
WHITE = Color.rgb(31, 31, 31)
LIGHT_GRAY = Color.rgb(28, 28, 28)
DARK_GRAY = Color.rgb(10, 10, 10)
ORANGE = Color.rgb(31, 16, 0)
BROWN = Color.rgb(18, 9, 0)
PURPLE = Color.rgb(16, 0, 24)
PINK = Color.rgb(31, 16, 24)
CYAN = Color.rgb(0, 31, 31)
MAGENTA = Color.rgb(31, 0, 31)
LIME = Color.rgb(16, 31, 0)
MAROON = Color.rgb(16, 0, 0)
OLIVE = Color.rgb(16, 16, 0)
NAVY = Color.rgb(0, 0, 16)
TEAL = Color.rgb(0, 16, 16)
GOLD = Color.rgb(31, 26, 0)
BEIGE = Color.rgb(30, 28, 22)
TAN = Color.rgb(26, 21, 14)
CORAL = Color.rgb(31, 16, 10)
VIOLET = Color.rgb(20, 10, 31)
INDIGO = Color.rgb(9, 0, 16)
SKY_BLUE = Color.rgb(10, 22, 31)
DARK_RED = Color.rgb(16, 0, 0)
DARK_GREEN = Color.rgb(0, 16, 0)
DARK_BLUE = Color.rgb(0, 0, 16)

module Draw
  def self.rectangle(x, y, width, height, color)
    Gfx.fill_rect(:top, x, y, width, height, color)
  end
end
