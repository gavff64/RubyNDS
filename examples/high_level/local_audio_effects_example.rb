vine_boom = Audio.load("vine_boom.pcm")
bruh = Audio.load("bruh.pcm")
bgm = Audio.load("sneaky_song.pcm")

puts "Press A for vine boom"
puts "Press B for bruh"

while System.main_loop?
  Input.update

  Audio.play(bgm)
  Audio.play(vine_boom) if Input.down?(KEY_A)
  Audio.play(bruh) if Input.down?(KEY_B)
  
  System.vblank
end

Audio.stop
