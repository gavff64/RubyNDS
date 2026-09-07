module Audio # this is an extension layer. The C binding already has .open, .update, .close, .volume defined.
  @playing = false
  @pending = ""
  @eof = false
  @stream = nil
  @position = 0
  @bytes_per_second = 0
  @offset = 0

  def self.load(audio, stream: false, sample_rate: 32000)
    return MP3Stream.new(audio) if audio.respond_to?(:content_type) && audio.content_type == "audio/mpeg"

    if audio.is_a?(String)
      bits = audio.end_with?(".pcm") ? 16 : 8
      channels = 2

      if bits == 8
        channels = stream ? 2 : 1
        type = stream ? "stream" : "effect"
        audio = "#{audio}.#{type}.pcm"
      end

      path = audio.start_with?("nitro:/") ? audio : "nitro:/#{audio}"

      return PCMFile.new(path, sample_rate, bits, channels) if stream
      return Audio.sample_load(load_pcm(path), sample_rate: sample_rate, bits: bits)
    end

    audio
  end

  def self.play(audio, buffer_length: 4096)
    return Audio.effect_play(audio) if audio.is_a?(Integer)

    unless @playing && @stream == audio
      stop if @playing

      sample_rate = audio.respond_to?(:sample_rate) ? audio.sample_rate : 32000
      bits = audio.respond_to?(:bits) ? audio.bits : 16
      channels = audio.respond_to?(:channels) ? audio.channels : 2
      Audio.open(sample_rate: sample_rate, bits: bits, channels: channels,
                 buffer_length: buffer_length)
      @stream = audio
      @frame_bytes = bits / 8 * channels
      @bytes_per_second = sample_rate * @frame_bytes
      @position = nil
      @pending = ""
      @offset = 0
      @eof = false
      @playing = true
    end

    available = @pending.bytesize - @offset

    if @offset >= 16384
      @pending = @pending.byteslice(@offset, available) || ""
      @offset = 0
    end

    unless @eof || available >= 8192
      chunk = @stream.read
      if chunk == ""
        @eof = true
      elsif chunk
        @pending << chunk
      end
    end

    available = @pending.bytesize - @offset
    playable = available - (available % @frame_bytes)

    if playable > 0
      used = Audio.update(@pending, @offset, playable)
      if used > 0
        @position = -used if @position.nil?
        @position += used
        @offset += used
      end
    else
      Audio.update("") if @position.nil?
    end

    stop if @eof && @offset == @pending.bytesize
  end

  def self.playing?
    @playing
  end

  def self.position
    @position || 0
  end

  def self.bytes_per_second
    @bytes_per_second
  end

  def self.stop
    return unless @playing

    @stream.close
    Audio.close
    @stream = nil
    @pending = ""
    @offset = 0
    @eof = false
    @position = 0
    @bytes_per_second = 0
    @playing = false
  end
end

module Audio # I know this is kinda dumb to specify twice
  class MP3Stream
    attr_reader :sample_rate, :channels

    def initialize(stream)
      @stream = stream
      @compressed = ""
      @offset = 0
      @first = nil
      @sample_rate = nil
      @channels = nil
      @eof = false
      @closed = false
      MP3.open

      until @first
        @first = decode
        raise "MP3 stream ended before audio was found" if @first == ""
        System.vblank unless @first
      end
    rescue
      close
      raise
    end

    def bits
      16
    end

    def read
      if @first
        pcm = @first
        @first = nil
        return pcm
      end

      decode
    end

    def close
      return if @closed

      @stream.close
      MP3.close
      @closed = true
    end

    def decode
      available = @compressed.bytesize - @offset

      if @offset >= 16384
        @compressed = @compressed.byteslice(@offset, available) || ""
        @offset = 0
        available = @compressed.bytesize
      end

      if available < 4096 && !@eof
        chunk = @stream.read
        if chunk == ""
          @eof = true
        elsif chunk
          @compressed << chunk
        end
        available = @compressed.bytesize - @offset
      end

      return "" if @eof && available == 0
      return nil if available < 4096 && !@eof

      pcm, used, rate, channels = MP3.decode(@compressed, @offset, available)
      @offset += used

      unless pcm.empty?
        @sample_rate = rate
        @channels = channels
        return pcm
      end

      nil
    end
  end

  class PCMFile
    def initialize(path, sample_rate, bits, channels)
      @file = FS.open(path)
      @sample_rate = sample_rate
      @bits = bits
      @channels = channels
      @closed = false
    end

    def sample_rate
      @sample_rate
    end

    def bits
      @bits
    end

    def channels
      @channels
    end

    def read(maxlen = 4096)
      return "" if @closed

      chunk = FS.read(@file, maxlen)
      if chunk == ""
        FS.seek(@file, 0)
        chunk = FS.read(@file, maxlen)
      end
      chunk
    end

    def close
      return if @closed

      FS.close(@file)
      @closed = true
    end
  end

  def self.load_pcm(path)
    file = FS.open(path)
    data = ""

    loop do
      chunk = FS.read(file, 4096)
      break if chunk == ""
      data << chunk
    end

    FS.close(file)
    data
  end
end
