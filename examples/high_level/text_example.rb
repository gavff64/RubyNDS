# This is on-screen text, NOT the on-screen console. So the main loop is required.

Debug.enabled = false

Draw.rectangle(0, 0, 256, 192, BLACK, :top)
Draw.rectangle(0, 0, 256, 192, BLACK, :bottom)
Draw.text("Top screen", 88, 92, WHITE, :top)
Draw.text("Bottom screen", 76, 92, WHITE, :bottom)

while System.main_loop?
  System.vblank
end
