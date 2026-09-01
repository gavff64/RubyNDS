file = Draw.load("ruby_logo.png")
x = (256 - file.width) / 2
y = (192 - file.height) / 2

Draw.rectangle(0, 0, 256, 192, BLACK)

while System.main_loop?
  Draw.image(file, x, y)
  System.vblank
end
