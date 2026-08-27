HOST = "192.168.12.189"
PORT = 8123
PATH = "/music.pcm"

Net.wifi
sock = Net.connect(HOST, PORT)

request_lines = [
  "GET #{PATH} HTTP/1.1",
  "Host: #{HOST}",
  "User-Agent: curl/8.0",
  "Connection: close"
]

request = request_lines.join("\r\n") + "\r\n\r\n"

sent = 0

while sent < request.bytesize
  written = Net.send(sock, request.byteslice(sent, request.bytesize - sent))
  sent += written
end

buffer = ""
header_end = nil

until header_end
  buffer << Net.recv(sock, 512)
  header_end = buffer.index("\r\n\r\n")
end

pending = buffer.byteslice(header_end + 4, buffer.bytesize - header_end - 4) || ""

puts "Audio streaming through HTTP..."
Audio.open(sample_rate: 32000, bits: 16, channels: 2)
Net.nonblock(sock, true)
eof = false

while System.main_loop?
  unless eof
    chunk = Net.recv(sock, 4096)
    if chunk == ""
      eof = true
    elsif chunk
      pending << chunk
    end
  end

  playable = pending.bytesize - (pending.bytesize % 4)

  if playable > 0
    pcm = pending.byteslice(0, playable)
    used = Audio.update(pcm)
    if used > 0
      pending = pending.byteslice(used, pending.bytesize - used) || ""
    end
  else
    Audio.update("")
  end
  break if eof && pending.empty?
  System.vblank
end

Net.close(sock)
Audio.close
