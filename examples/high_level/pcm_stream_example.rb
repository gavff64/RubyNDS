stream = HTTP.get("192.168.12.189/music.pcm", port: 8123, stream: true)
music = Audio.load(stream)
puts "Audio streaming through HTTP..."

while System.main_loop?
  Audio.play(music)
  System.vblank
end

Audio.stop
