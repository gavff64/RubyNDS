module TCP
  @wifi_initialized = false

  def self.ensure_wifi!
    return if @wifi_initialized
    Net.wifi
    @wifi_initialized = true
  end

  def self.connect(host, port, on_wait: nil)
    ensure_wifi!
    # Net.connect returns a socket number. Wrap it in an object with read/write methods.
    Socket.new(Net.connect(host, port), on_wait)
  end

  # each connection gets its own object and separate state, like HTTP::Stream.
  class Socket
    def initialize(sock, on_wait = nil)
      @sock = sock # the socket number from Net.connect.
      @on_wait = on_wait # optional proc to run while waiting for bytes to arrive or go out.
      @closed = false # has this connection ended or been closed by the application?
      Net.nonblock(@sock, true) # send/receive return nil if they would have to wait.
    end

    # nil means wait, "" means the connection ended.
    def read(maxlen = 4096)
      raise ArgumentError, "length must not be negative" if maxlen < 0
      return "" if maxlen == 0 || @closed # nothing to receive, or no connection left.
      chunk = Net.recv(@sock, maxlen) # can return fewer bytes than we asked for.
      return close if chunk == "" # the other end closed its connection, close our end too.
      chunk
    end

    def read_exact(length)
      raise ArgumentError, "length must not be negative" if length < 0
      data = String.new
      while data.bytesize < length
        chunk = read(length - data.bytesize) # ask only for the bytes we're still missing.
        return nil if chunk == ""
        if chunk
          data << chunk
        else
          wait # nil means no bytes are ready yet. Wait a frame, then try again.
        end
      end
      data
    end

    # keep sending until every byte has gone out.
    def write(data)
      offset = 0 # number of bytes already sent, also where the next send starts.
      while offset < data.bytesize
        return nil if @closed
        # byteslice takes a starting byte and a byte count, send only the unsent part.
        sent = Net.send(@sock, data.byteslice(offset, data.bytesize - offset))
        if sent == 0 # stop if no bytes went out, so we don't retry forever without progress.
          close
          return nil
        elsif sent
          offset += sent
        else
          wait
        end
      end
      offset
    end

    # discard large messages without keeping them all in memory.
    def skip(length)
      raise ArgumentError, "length must not be negative" if length < 0
      remaining = length # number of bytes we still need to discard.
      while remaining > 0
        chunk = read_exact([remaining, 1024].min) # at most 1024 bytes, or fewer near the end.
        return nil unless chunk # connection ended before we could skip everything.
        remaining -= chunk.bytesize # count these bytes, the next loop replaces this chunk.
      end
      length
    end

    def eof?
      @closed
    end

    def closed?
      @closed
    end

    def close
      return "" if @closed
      Net.close(@sock)
      @closed = true
      ""
    end

    private # wait is an internal helper for the socket methods above.

    def wait
      # only false cancels, a callback may otherwise return nil.
      if @on_wait && @on_wait.call == false
        close
      else
        System.vblank
      end
    end
  end
end
