module HTTPS
  class Stream
    attr_reader :content_type

    def initialize(sock, pending, length, content_type)
      @sock = sock
      @pending = pending
      @length = length
      @content_type = content_type
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

    def write(data)
      HTTPS.write_all_bytes(data)
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

  def self.seed_tls(path)
    TLS.seed(path)
  rescue
    raise unless path == "sd:/tls.seed"
    TLS.seed("fat:/tls.seed")
  end

  def self.write_all_bytes(data)
    offset = 0
    while offset < data.bytesize
      offset += TLS.send(data.byteslice(offset, data.bytesize - offset))
    end
    offset
  end

  def self.open_stream(url, port, seed, method = "GET", body = nil, content_type = nil)
    raise "invalid HTTPS URL" if url.match(/[\x00-\x20\x7f]/)
    match = url.match(/\A(?:https:\/\/)?([^\/?#:@]+)(?::(\d+))?([\/?#].*)?\z/)
    raise "invalid HTTPS URL" unless match

    host = match[1]
    port = match[2].to_i if match[2]
    path = (match[3] || "/").split("#", 2)[0] || "/"
    path = "/#{path}" unless path.start_with?("/")
    host_header = port == 443 ? host : "#{host}:#{port}"

    seed_tls(seed)
    HTTP.ensure_wifi!
    sock = Net.connect(host, port)

    begin
      TLS.open(sock, host)
      request_lines = [
        "#{method} #{path} HTTP/1.0",
        "Host: #{host_header}",
        "User-Agent: curl/8.0",
        "Accept-Encoding: identity"
      ]
      if body
        request_lines << "Content-Type: #{content_type}"
        request_lines << "Content-Length: #{body.bytesize}"
      end
      request_lines << "Connection: close"
      request = request_lines.join("\r\n") + "\r\n\r\n" + (body || "")

      write_all_bytes(request)

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
      type = headers.match(/\r\nContent-Type:\s*([^\s;]+)/i)
      content_type = type ? type[1].downcase : nil
      pending = response.byteslice(header_end + 4, response.bytesize - header_end - 4) || ""
      Stream.new(sock, pending, length, content_type)
    rescue
      TLS.close
      Net.close(sock)
      raise
    end
  end

  def self.read_all(source)
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

  def self.get(url, port: 443, seed: "sd:/tls.seed", stream: false)
    source = open_stream(url, port, seed)
    return source if stream
    read_all(source)
  end

  def self.post(url, body, port: 443, seed: "sd:/tls.seed", content_type: "application/x-www-form-urlencoded")
    read_all(open_stream(url, port, seed, "POST", body, content_type))
  end
end
