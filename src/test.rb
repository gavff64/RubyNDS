# (the overuse of comments is for my own sake. I don't work with bare metal or even C lol)

# shift the bits to the left. Shift integer "1" by X positions.
KEY_A      = 1 << 0 # 000000000001 = 1
KEY_B      = 1 << 1 # 000000000010 = 2
KEY_SELECT = 1 << 2 # 000000000100 = 4
KEY_START  = 1 << 3 # 000000001000 = 8
KEY_RIGHT  = 1 << 4 # etc.
KEY_LEFT   = 1 << 5
KEY_UP     = 1 << 6
KEY_DOWN   = 1 << 7
KEY_R      = 1 << 8
KEY_L      = 1 << 9
KEY_X      = 1 << 10
KEY_Y      = 1 << 11
KEY_TOUCH  = 1 << 14

# comparing the newly pressed buttons (.down) with the key constants bits. So if you press A then
# Input.down == KEY_A (both 00000001), however we bitwise compare because if you press A and B at
# the same time for example, then all buttons would be ignored because .down can represent multiple
# buttons at the same time, and KEY_A != 00000011 (Input.down A and B).
module Input
  def self.down?(key)
    (down & key) != 0 # bitwise not logical
  end
end

def puts(*args)
  args.each do |a|
    print(a.to_s + "\n")
  end
end

while System.main_loop?
  Input.update

  puts("A is pressed") if Input.down?(KEY_A)
  puts("B is pressed") if Input.down?(KEY_B)
  puts("X is pressed") if Input.down?(KEY_X)
  puts("Y is pressed") if Input.down?(KEY_Y)
  puts("START is pressed") if Input.down?(KEY_START)

  System.vblank
end
