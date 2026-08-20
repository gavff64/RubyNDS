# PCM streaming server for /examples/audio_stream_example.rb

require "webrick"

mp3 = File.join(__dir__, "music.mp3")
pcm = File.join(__dir__, "music.pcm")

abort "music.mp3 not found" unless File.exist?(mp3)

if !File.exist?(pcm) || File.mtime(pcm) < File.mtime(mp3)
  abort "ffmpeg failed" unless system(
    "ffmpeg",
    "-y",
    "-v", "error",
    "-i", mp3,
    "-f", "s16le",
    "-ar", "32000",
    "-ac", "2",
    pcm
  )
end

server = WEBrick::HTTPServer.new(Port: 8123, DocumentRoot: __dir__)

["INT", "TERM"].each do |signal|
  Signal.trap(signal) do
    server.shutdown
  end
end

puts "Serving music.pcm on port 8123"

server.start
