DEBUG = true

Debug.enabled = DEBUG

while System.main_loop?
  Input.update

  puts("Debug terminal") if Debug.update
  puts("A pressed") if Debug.terminal? && Input.down?(KEY_A)

  Draw.rectangle(0, 0, 256, 192, BLUE, :top)
  Draw.rectangle(0, 0, 256, 192, RED, :bottom)

  System.vblank
end
