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

  (current_color = RED; print("\r\e[2KCurrent color: #{"red".red}")) if Input.down?(KEY_A)
  (current_color = BLUE; print("\r\e[2KCurrent color: #{"blue".blue}")) if Input.down?(KEY_B)
  (current_color = GREEN; print("\r\e[2KCurrent color: #{"green".green}")) if Input.down?(KEY_X)
  (current_color = BLACK; print("\r\e[2KCurrent color: None (eraser)")) if Input.down?(KEY_Y)
  Draw.rectangle(0, 0, 256, 192, BLACK) if Input.down?(KEY_START)

  if Input.touch?
    x = Input.touch_x
    y = Input.touch_y
    Draw.rectangle(x, y, 5, 5, current_color)
  end

  System.vblank
end
