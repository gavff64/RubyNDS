# PCM streaming server for examples/(low_level || high_level)/audio_stream_example.rb

require "webrick"

pcm = File.join(__dir__, "music.pcm")

abort "music.pcm not found" unless File.exist?(pcm)

server = WEBrick::HTTPServer.new(Port: 8123, DocumentRoot: __dir__)

["INT", "TERM"].each do |signal|
  Signal.trap(signal) { exit! 0 }
end

puts "Serving music.pcm on port 8123"

server.start
