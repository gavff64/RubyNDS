stream = HTTP.get("192.168.x.x/music.pcm", port: 8123, stream: true) # obviously replace with your local ip
music = Audio.load(stream)
puts "Audio streaming through HTTP..."

while System.main_loop?
  Audio.play(music)
  System.vblank
end

Audio.stop
