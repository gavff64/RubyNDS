# Check generic_testing.rb for info on bits/what this means

module Color
  def self.rgb(r, g, b)
    (r & 31) | ((g & 31) << 5) | ((b & 31) << 10) | (1 << 15)
  end
end

KEY_A = 1 << 0
KEY_B = 1 << 1
KEY_START = 1 << 3
KEY_X = 1 << 10
KEY_Y = 1 << 11
KEY_TOUCH = 1 << 14

RED = Color.rgb(31, 0, 0)
BLUE = Color.rgb(0, 0, 31)
GREEN = Color.rgb(0, 31, 0)
BLACK = Color.rgb(0, 0, 0)

puts("Paint Example")
puts("")
puts("Press A for #{"red".red}.")
puts("Press B for #{"blue".blue}")
puts("Press X for #{"green".green}.")
puts("Press Y for eraser.")
puts("Press START to clear screen.")
puts("")
puts("Touch anywhere to draw.")
puts("")
puts("")
puts("")
puts("")
puts("")
puts("")
puts("")
puts("")
print("Current color: #{"red".red}")

current_color = RED
while System.main_loop?
  Input.update
  down = Input.down
  (current_color = RED; print("\r\e[2KCurrent color: #{"red".red}")) if (down & KEY_A) != 0
  (current_color = BLUE; print("\r\e[2KCurrent color: #{"blue".blue}")) if (down & KEY_B) != 0
  (current_color = GREEN; print("\r\e[2KCurrent color: #{"green".green}")) if (down & KEY_X) != 0
  (current_color = BLACK; print("\r\e[2KCurrent color: None (eraser)")) if (down & KEY_Y) != 0
  Gfx.fill_rect(:top, 0, 0, 256, 192, BLACK) if (down & KEY_START) != 0

  if Input.touch?
    x = Input.touch_x
    y = Input.touch_y
    Gfx.fill_rect(:top, x, y, 5, 5, current_color)
  end

  System.vblank
end
