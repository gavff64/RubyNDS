# Run a TCP echo server on your computer and use its LAN address here.
socket = TCP.connect("192.168.1.10", 8123)
socket.write("hello\n")
puts socket.read_exact(6)
socket.close
