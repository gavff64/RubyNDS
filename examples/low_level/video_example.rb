CLOCK_RATE = 32768
CLOCK_BYTES = CLOCK_RATE * 4

def read_u16(file)
  data = FS.read(file, 2)
  data.getbyte(0) | data.getbyte(1) << 8
end

def read_u32(file)
  data = FS.read(file, 4)
  data.getbyte(0) |
    data.getbyte(1) << 8 |
    data.getbyte(2) << 16 |
    data.getbyte(3) << 24
end

video = FS.open("nitro:/bad_apple.mp4.r15v")

raise "invalid video" unless FS.read(video, 4) == "R15V"

width = read_u16(video)
height = read_u16(video)
frame_rate = read_u16(video)
frame_count = read_u32(video)
frame_size = width * height * 2
x = (256 - width) / 2
y = (192 - height) / 2
silence = "\0" * 16384
clock = nil
frame_index = -1

Audio.open(sample_rate: CLOCK_RATE, bits: 16, channels: 2)
Audio.volume = 0
Gfx.fill_rect(:top, 0, 0, 256, 192, 1 << 15)

while System.main_loop?
  used = Audio.update(silence)
  clock = -used if clock.nil?
  clock += used
  target = clock * frame_rate / CLOCK_BYTES
  break if target >= frame_count

  if target > frame_index
    FS.seek(video, 14 + target * frame_size)
    frame = FS.read(video, frame_size)
    raise "invalid video" unless frame.bytesize == frame_size
    Gfx.blit(:top, x, y, width, height, frame)
    frame_index = target
  end

  System.vblank
end

Audio.close
FS.close(video)
