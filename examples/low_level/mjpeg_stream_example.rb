# Ohio State University's Byrd Polar and Climate Research Center public weather cam, may or may not be offline.
HOST = "ipcam-1.byrd.osu.edu"
PORT = 443
PATH = "/mjpg/video.mjpg?resolution=256x192&compression=60&fps=5"

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

  data = ""
  header_end = nil

  until header_end
    chunk = TLS.recv(512)
    raise "HTTPS response ended before the headers were complete" if chunk == ""
    data << chunk
    header_end = data.index("\r\n\r\n")
  end

  data = data.byteslice(header_end + 4, data.bytesize - header_end - 4) || ""

  while System.main_loop?
    first = nil
    last = nil

    until last
      first = data.index("\xFF\xD8")
      last = data.index("\xFF\xD9", first + 2) if first
      break if last

      data = data.byteslice(first, data.bytesize - first) if first && first > 0
      data = data.byteslice(-1, 1) if !first && data.bytesize > 4096

      chunk = TLS.recv(1024)
      break if chunk == ""
      data << chunk
    end

    break unless last

    frame = data.byteslice(first, last - first + 2)
    data = data.byteslice(last + 2, data.bytesize - last - 2) || ""
    Gfx.jpeg(:top, 0, 0, frame)
    System.vblank
  end
ensure
  TLS.close if opened
  Net.close(sock)
end
