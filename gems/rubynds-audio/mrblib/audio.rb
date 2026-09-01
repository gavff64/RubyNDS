module Audio # this is an extension layer. The C binding already has .open, .update, .close, .volume defined.
  @playing = false
  @pending = ""
  @eof = false
  @stream = nil
  @position = 0
  @bytes_per_second = 0

  def self.load(audio, stream: false, sample_rate: 32000)
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

  def self.play(audio)
    return Audio.effect_play(audio) if audio.is_a?(Integer)

    unless @playing && @stream == audio
      stop if @playing

      sample_rate = audio.is_a?(PCMFile) ? audio.sample_rate : 32000
      bits = audio.is_a?(PCMFile) ? audio.bits : 16
      channels = audio.is_a?(PCMFile) ? audio.channels : 2
      Audio.open(sample_rate: sample_rate, bits: bits, channels: channels)
      @stream = audio
      @frame_bytes = bits / 8 * channels
      @bytes_per_second = sample_rate * @frame_bytes
      @position = nil
      @pending = ""
      @eof = false
      @playing = true
    end

    unless @eof || @pending.bytesize >= 8192
      chunk = @stream.read
      if chunk == ""
        @eof = true
      elsif chunk
        @pending << chunk
      end
    end

    playable = @pending.bytesize - (@pending.bytesize % @frame_bytes)

    if playable > 0
      pcm = @pending.byteslice(0, playable)
      used = Audio.update(pcm)
      if used > 0
        @position = -used if @position.nil?
        @position += used
        @pending = @pending.byteslice(used, @pending.bytesize - used) || ""
      end
    else
      Audio.update("")
    end

    stop if @eof && @pending.empty?
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
    @eof = false
    @position = 0
    @bytes_per_second = 0
    @playing = false
  end
end

module Audio # I know this is kinda dumb to specify twice
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
