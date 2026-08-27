# (the overuse of comments is for my own sake. I don't work with bare metal or even C, bits blah blah lol)

# & = remove bits we DON'T want
# | = combine bits we DO want
# << = move bits into their assigned position

KEY_A = 1 << 0 # 000000000001 = 1
KEY_B = 1 << 1 # 000000000010 = 2
KEY_SELECT = 1 << 2 # 000000000100 = 4
KEY_START = 1 << 3 # 000000001000 = 8
KEY_RIGHT = 1 << 4 # etc.
KEY_LEFT = 1 << 5
KEY_UP = 1 << 6
KEY_DOWN = 1 << 7
KEY_R = 1 << 8
KEY_L = 1 << 9
KEY_X = 1 << 10
KEY_Y = 1 << 11
KEY_TOUCH = 1 << 14

# comparing the newly pressed buttons (.down) with the key constants bits. So if you press A then
# Input.down == KEY_A (both 00000001), however we bitwise compare because if you press A and B at
# the same time for example, then all buttons would be ignored because .down can represent multiple
# buttons at the same time, and KEY_A != 00000011 (Input.down A and B).
module Input
  def self.down?(key)
    (down & key) != 0 # bitwise not logical
  end
end

# 16-bit color per pixel aBBBBBGGGGGRRRRR
# 5 bits per color channel (RRRRR, GGGGG, BBBBB), one opaque (a).
# 1 bit is 2 possible states, 2 bits is 4 possible states, etc. So 5 bits is 32 possibilities (index 0 - 31).
# 32 red possibilities, 32 green, 32 blue = 32,768 total RGB combinations
# Example: 00000 = no red (0) | 10000 = medium red (rounded 16) | 11111 = full red (31)

# Example 2: Brown as 5 bits per channel is (18, 9, 0). So that's "1 00000 01001 10010". Opaque, no blue, 9 green, 18 red.
# "31" is the mask because each RGB channel is only 5 bits wide, 31 = 11111, the max. So "(r & 31)" means "keep the lowest 5 bits of r"
# Therefore, "(18 & 31)" = 10010 because 18 = 10010 and the mask keeps all bits the same. The point of this is because it can self-correct
# if the input color value contains too many bits. Everything past 5 bits is essentially ignored. This is the purpose of the mask on all colors.
# Green is 9, so do the same bitwise AND operation with the mask, then shift the bits 5 to the left so you're checking the green bits.
# Same for blue, shift 10 bits to the left.
# "(1 << 15)" is just checking 0 or 1 for transparency on the last available position.
# Lastly, "|" bitwise OR combines the RGB bits into a single 16-bit pixel (including the 1/0 transparency)

# So...
# red:
# 0 00000 00000 10010
# green:
# 0 00000 01001 00000
# blue:
# 0 00000 00000 00000
# opaque:
# 1 00000 00000 00000
# Combined = 1 00000 01001 10010 (brown)
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

while System.main_loop?
  Input.update

  # x, y, width, height, color
  (puts("A is pressed"); Gfx.fill_rect(:top, 10, 20, 50, 30, RED)) if Input.down?(KEY_A)
  (puts("B is pressed"); Gfx.fill_rect(:top, 20, 40, 50, 30, YELLOW)) if Input.down?(KEY_B)
  (puts("X is pressed"); Gfx.fill_rect(:top, 40, 80, 50, 30, BLUE)) if Input.down?(KEY_X)
  (puts("Y is pressed"); Gfx.fill_rect(:top, 80, 100, 50, 30, GREEN)) if Input.down?(KEY_Y)
  (puts("START is pressed"); Gfx.fill_rect(:top, 50, 50, 50, 30, GRAY)) if Input.down?(KEY_START)
  (puts("Touchscreen. Cleared screen."); Gfx.fill_rect(:top, 0, 0, 156, 192, BLACK)) if Input.down?(KEY_TOUCH)

  System.vblank
end
