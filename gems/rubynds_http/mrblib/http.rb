module HTTP
  @wifi_initialized = false

  def self.ensure_wifi!
    return if @wifi_initialized
    Net.wifi
    @wifi_initialized = true
  end

  def self.write_all_bytes(sock, request)
    offset = 0
    while offset < request.bytesize
      written = Net.send(sock, request.byteslice(offset, request.bytesize - offset))
      offset += written
    end
  end

  def self.get(url, port = 80)
    ensure_wifi!
    host = url.match(/\A(?:https?:\/\/)?([^\/?#]+)/)[1]
    path = url.match(/\A(?:https?:\/\/)?[^\/?#]+(\/[^#]*)/)[1]
    sock = Net.connect(host, port)

    request_lines = [
      "GET #{path} HTTP/1.1",
      "Host: #{host}",
      "User-Agent: curl/8.0",
      "Connection: close"
    ]
    request = request_lines.join("\r\n") + "\r\n\r\n"

    write_all_bytes(sock, request)

    response = ""
    loop do
      chunk = Net.recv(sock, 512)
      break if chunk == ""
      response << chunk
    end
    Net.close(sock)
    header_end = response.index("\r\n\r\n")
    response = response[header_end..-1]
    return response
  end
end
