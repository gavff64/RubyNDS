module HTTPS
  def self.get(url, port: 443, seed: "fat:/tls.seed")
    raise "invalid HTTPS URL" if url.match(/[\x00-\x20\x7f]/)
    match = url.match(/\A(?:https:\/\/)?([^\/?#:@]+)(?::(\d+))?([\/?#].*)?\z/)
    raise "invalid HTTPS URL" unless match

    host = match[1]
    port = match[2].to_i if match[2]
    path = (match[3] || "/").split("#", 2)[0] || "/"
    path = "/#{path}" unless path.start_with?("/")
    host_header = port == 443 ? host : "#{host}:#{port}"

    TLS.seed(seed)
    HTTP.ensure_wifi!
    sock = Net.connect(host, port)

    begin
      opened = TLS.open(sock, host)
      request_lines = [
        "GET #{path} HTTP/1.0",
        "Host: #{host_header}",
        "User-Agent: RubyNDS",
        "Accept-Encoding: identity",
        "Connection: close"
      ]
      request = request_lines.join("\r\n") + "\r\n\r\n"

      offset = 0
      while offset < request.bytesize
        offset += TLS.send(request.byteslice(offset, request.bytesize - offset))
      end

      response = ""
      header_end = nil
      length = nil

      loop do
        chunk = TLS.recv(4096)
        break if chunk == ""
        response << chunk

        unless header_end
          header_end = response.index("\r\n\r\n")
          if header_end
            headers = response.byteslice(0, header_end)
            raise "unsupported transfer encoding" if headers.match(/\r\nTransfer-Encoding:/i)
            size = headers.match(/\r\nContent-Length:\s*(\d+)\s*(?:\r\n|\z)/i)
            length = size[1].to_i if size
          end
        end

        break if header_end && length && response.bytesize >= header_end + 4 + length
      end

      raise "HTTPS response ended before the headers were complete" unless header_end
      body = response.byteslice(header_end + 4, response.bytesize - header_end - 4)
      raise "incomplete HTTPS response" if length && body.bytesize < length
      length ? body.byteslice(0, length) : body
    ensure
      TLS.close if opened
      Net.close(sock)
    end
  end
end
