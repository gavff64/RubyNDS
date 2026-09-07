module HTTPS
  class Stream
    def initialize(sock, pending, length)
      @sock = sock
      @pending = pending
      @length = length
      @read = 0
      @closed = false
    end

    def read(maxlen = 4096)
      return "" if @closed

      if @length
        remaining = @length - @read
        return close if remaining <= 0
        maxlen = remaining if remaining < maxlen
      end

      unless @pending.empty?
        chunk = @pending.byteslice(0, maxlen)
        @pending = @pending.byteslice(chunk.bytesize, @pending.bytesize - chunk.bytesize) || ""
        @read += chunk.bytesize
        close if @length && @read >= @length
        return chunk
      end

      chunk = TLS.recv(maxlen)
      return close if chunk == ""
      @read += chunk.bytesize
      close if @length && @read >= @length
      chunk
    end

    def eof?
      @closed
    end

    def close
      return "" if @closed
      TLS.close
      Net.close(@sock)
      @closed = true
      ""
    end
  end

  def self.open_stream(url, port, seed)
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
      TLS.open(sock, host)
      request_lines = [
        "GET #{path} HTTP/1.0",
        "Host: #{host_header}",
        "User-Agent: curl/8.0",
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

      until header_end
        chunk = TLS.recv(512)
        raise "HTTPS response ended before the headers were complete" if chunk == ""
        response << chunk
        header_end = response.index("\r\n\r\n")
      end

      headers = response.byteslice(0, header_end)
      raise "unsupported transfer encoding" if headers.match(/\r\nTransfer-Encoding:/i)
      size = headers.match(/\r\nContent-Length:\s*(\d+)\s*(?:\r\n|\z)/i)
      length = size ? size[1].to_i : nil
      pending = response.byteslice(header_end + 4, response.bytesize - header_end - 4) || ""
      Stream.new(sock, pending, length)
    rescue
      TLS.close
      Net.close(sock)
      raise
    end
  end

  def self.get(url, port: 443, seed: "fat:/tls.seed", stream: false)
    source = open_stream(url, port, seed)
    return source if stream

    body = ""
    begin
      loop do
        chunk = source.read
        break if chunk == ""
        body << chunk
      end
    ensure
      source.close
    end
    body
  end
end
