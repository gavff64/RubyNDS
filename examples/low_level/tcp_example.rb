# Run a TCP echo server on your computer and use its LAN address here.
Net.wifi
sock = Net.connect("192.168.1.10", 8123)
Net.nonblock(sock, true)

message = "hello\n"
offset = 0
while offset < message.bytesize
  written = Net.send(sock, message.byteslice(offset, message.bytesize - offset))
  if written
    offset += written
  else
    System.vblank
  end
end

response = ""
while response.bytesize < 6
  chunk = Net.recv(sock, 6 - response.bytesize)
  if chunk == ""
    response = nil
    break
  elsif chunk
    response << chunk
  else
    System.vblank
  end
end

puts response
Net.close(sock)
