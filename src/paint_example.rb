# Check generic_testing.rb for info on bits/what this means

def puts(*args)
  args.each do |a|
    print(a.to_s + "\n")
  end
end

KEY_A      = 1 << 0
KEY_B      = 1 << 1
KEY_START  = 1 << 3
KEY_X      = 1 << 10
KEY_Y      = 1 << 11
KEY_TOUCH  = 1 << 14

module Input
  def self.down?(key)
    (down & key) != 0
  end
end

module Color
  def self.rgb(r, g, b)
    (r & 31) | ((g & 31) << 5) | ((b & 31) << 10) | (1 << 15)
  end
end

RED = Color.rgb(31, 0, 0)
BLUE = Color.rgb(0, 0, 31)
GREEN = Color.rgb(0, 31, 0)
BLACK = Color.rgb(0, 0, 0)

puts("Paint Example")
puts("")
puts("Press A for red.")
puts("Press B for blue.")
puts("Press X for green.")
puts("Press Y for eraser.")
puts("Press START to clear screen.")
puts("")
puts("Touch anywhere to draw.")

current_color = RED
while System.main_loop?
  Input.update

  current_color = RED if Input.down?(KEY_A)
  current_color = BLUE if Input.down?(KEY_B)
  current_color = GREEN if Input.down?(KEY_X)
  current_color = BLACK if Input.down?(KEY_Y)

  if Input.touch?
    x = Input.touch_x
    y = Input.touch_y
    Gfx.fill_rect(:top, x, y, 5, 5, current_color)
  end

  Gfx.fill_rect(:top, 0, 0, 256, 192, BLACK) if Input.down?(KEY_START)

  System.vblank
end
