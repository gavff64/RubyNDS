video = Draw.load("bad_apple.mp4")
audio = Audio.load("bad_apple.mp4", stream: true)

while System.main_loop?
  Audio.play(audio)
  Draw.video(video)
  System.vblank
end
