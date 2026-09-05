# Overuse of comments is for my own sake. Sorry lol above my paygrade - gavff

module HTTP
  @wifi_initialized = false

  # Nested class so every streaming request has it's own object and separate states.
  class Stream
    def initialize(sock, pending)
      @sock = sock
      @pending = pending # If we get some data after the headers in the same frame, store it. Should be a once per request thing.
      @eof = false # Has the server ended the response?
      @closed = false # Has the object closed its own socket?
    end

    # read a max of 4096 bytes from @pending, remove those bytes after reading. Do so until @pending is empty.
    # this likely gets called continually depending on total data length
    def read(maxlen = 4096)
      return "" if @eof || @closed

      unless @pending.empty?
        chunk = @pending.byteslice(0, maxlen)
        @pending = @pending.byteslice(chunk.bytesize, @pending.bytesize - chunk.bytesize) || ""
        return chunk
      end

      chunk = Net.recv(@sock, maxlen) # assign 4096 bytes to chunk, non-blocking.

      if chunk == "" # server closed the connection
        @eof = true
        close
      end
      return chunk
    end

    def eof?
      @eof
    end

    def close
      return if @closed
      Net.close(@sock)
      @closed = true
    end
  end

  def self.ensure_wifi!
    return if @wifi_initialized
    Net.wifi
    @wifi_initialized = true
  end

  def self.write_all_bytes(sock, request)
    offset = 0 # start at beginning of request
    while offset < request.bytesize # keep going until every byte has been sent
      written = Net.send(sock, request.byteslice(offset, request.bytesize - offset)) # number of bytes that went out
      offset += written # add up/keep track of total number of bytes that went out
    end
  end

  def self.stream_bytes(sock, request)
    write_all_bytes(sock, request) # sends the http request

    buffer = ""
    header_end = nil

    until header_end # keep reading until end of header is found
      chunk = Net.recv(sock, 512) # read up to 512 bytes at a time

      if chunk == ""
        Net.close(sock)
        raise "HTTP response ended before the headers were complete"
      end

      buffer << chunk
      header_end = buffer.index("\r\n\r\n")
    end

    pending = buffer.byteslice(header_end + 4, buffer.bytesize - header_end - 4) || "" # runs when header_end is found obviously
    Net.nonblock(sock, true) # switch to non-blocking mode since we have the complete response header (recieved from blocking reads)
    Stream.new(sock, pending) # object keeps access to the open socket and gives it some bytes we may have recieved in that time already.
  end

  def self.get(url, port: 80, stream: false)
    raise "use HTTPS.get for HTTPS URLs" if url.downcase.start_with?("https://")
    ensure_wifi!
    match = url.match(/\A(?:https?:\/\/)?([^\/?#:]+)(?::(\d+))?/)
    host = match[1]
    port = match[2].to_i if match[2]

    path_match = url.match(/\A(?:https?:\/\/)?[^\/?#]+(\/[^#]*)/)
    path = path_match ? path_match[1] : "/"

    sock = Net.connect(host, port)

    host_header = port == 80 ? host : "#{host}:#{port}"

    request_lines = [
      "GET #{path} HTTP/1.1",
      "Host: #{host_header}",
      "User-Agent: curl/8.0",
      "Connection: close"
    ]
    request = request_lines.join("\r\n") + "\r\n\r\n"

    if stream
      return stream_bytes(sock, request)
    else
      write_all_bytes(sock, request)

      response = ""
      loop do
        chunk = Net.recv(sock, 512)
        break if chunk == ""
        response << chunk
      end

      Net.close(sock)
      header_end = response.index("\r\n\r\n")
      response = response[(header_end + 4)..-1]
      return response
    end
  end
end
