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

module Input
  def self.down?(key)
    (down & key) != 0
  end

  def self.held?(key)
    (held & key) != 0
  end

  def self.up?(key)
    (up & key) != 0
  end
end
