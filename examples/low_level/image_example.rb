file = FS.open("nitro:/ruby_logo.png.r15i")
header = FS.read(file, 8)

raise "invalid image" unless header.bytesize == 8 && header.byteslice(0, 4) == "R15I"

width = header.getbyte(4) | header.getbyte(5) << 8
height = header.getbyte(6) | header.getbyte(7) << 8
pixels = FS.read(file, width * height * 2)

FS.close(file)

raise "invalid image" unless pixels.bytesize == width * height * 2

x = (256 - width) / 2
y = (192 - height) / 2

Gfx.fill_rect(:top, 0, 0, 256, 192, 1 << 15)
Gfx.blit(:top, x, y, width, height, pixels)

while System.main_loop?
  System.vblank
end
