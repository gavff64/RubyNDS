# Random University of Mississippi's Icecast stream, may or may not be online.
URL = "https://wusm-stream2.usm.edu/wusm"

stream = HTTPS.get(URL, stream: true)
music = Audio.load(stream)
puts "Streaming MP3 through HTTPS..."

while System.main_loop?
  Audio.play(music)
  System.vblank
end

Audio.stop
