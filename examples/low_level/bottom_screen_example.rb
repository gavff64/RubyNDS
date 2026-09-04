DEBUG = true

KEY_A = 1 << 0
KEY_L = 1 << 9
KEY_R = 1 << 8

RED = 31 | 1 << 15
BLUE = 31 << 10 | 1 << 15

combination = KEY_L | KEY_R
terminal = false

Gfx.bottom_mode(:graphics)

while System.main_loop?
  Input.update

  held = Input.held
  down = Input.down

  if DEBUG && (held & combination) == combination && (down & combination) != 0
    terminal = !terminal
    Gfx.bottom_mode(terminal ? :terminal : :graphics)
    print("Debug terminal\n") if terminal
  end

  print("A pressed\n") if terminal && (down & KEY_A) != 0

  Gfx.fill_rect(:top, 0, 0, 256, 192, BLUE)
  Gfx.fill_rect(:bottom, 0, 0, 256, 192, RED)

  System.vblank
end
