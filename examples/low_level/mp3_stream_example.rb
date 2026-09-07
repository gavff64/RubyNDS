# Random University of Mississippi's Icecast stream, may or may not be online.
HOST = "wusm-stream2.usm.edu"
PORT = 443
PATH = "/wusm"

TLS.seed("fat:/tls.seed")
Net.wifi
sock = Net.connect(HOST, PORT)

begin
  opened = TLS.open(sock, HOST)

  request_lines = [
    "GET #{PATH} HTTP/1.0",
    "Host: #{HOST}",
    "User-Agent: curl/8.0",
    "Accept-Encoding: identity",
    "Connection: close"
  ]
  request = request_lines.join("\r\n") + "\r\n\r\n"

  offset = 0
  while offset < request.bytesize
    offset += TLS.send(request.byteslice(offset, request.bytesize - offset))
  end

  compressed = ""
  header_end = nil

  until header_end
    compressed << TLS.recv(512)
    header_end = compressed.index("\r\n\r\n")
  end

  compressed = compressed.byteslice(header_end + 4, compressed.bytesize - header_end - 4) || ""
  decoded = ""
  compressed_offset = 0
  decoded_offset = 0
  playing = false

  puts "Streaming MP3 through HTTPS..."
  MP3.open

  while System.main_loop?
    if compressed.bytesize - compressed_offset < 65536
      chunk = TLS.recv(4096)
      break if chunk == ""
      compressed << chunk
    end

    available = compressed.bytesize - compressed_offset

    if compressed_offset >= 16384
      compressed = compressed.byteslice(compressed_offset, available) || ""
      compressed_offset = 0
    end

    2.times do
      break if compressed.bytesize - compressed_offset < 16384
      break if decoded.bytesize - decoded_offset >= 65536

      pcm, used, sample_rate, channels = MP3.decode(compressed, compressed_offset)
      break if used == 0
      compressed_offset += used

      unless pcm.empty?
        decoded << pcm
        unless playing
          Audio.open(sample_rate: sample_rate, bits: 16, channels: channels)
          playing = true
        end
      end
    end

    if playing
      available = decoded.bytesize - decoded_offset
      decoded_offset += Audio.update(decoded, decoded_offset, available)

      if decoded_offset >= 32768
        decoded = decoded.byteslice(decoded_offset, decoded.bytesize - decoded_offset) || ""
        decoded_offset = 0
      end
    end

    System.vblank
  end
ensure
  Audio.close if playing
  MP3.close
  TLS.close if opened
  Net.close(sock)
end
