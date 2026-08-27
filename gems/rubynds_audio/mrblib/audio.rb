module Audio
  @playing = false
  @pending = ""
  @eof = false
  @stream = nil

  def self.play(stream)
    stop if @playing

    Audio.open(sample_rate: 32000, bits: 16, channels: 2)
    @stream = stream
    @pending = ""
    @eof = false
    @playing = true
  end

  def self.tick
    return unless @playing

    unless @eof
      chunk = @stream.read
      if chunk == ""
        @eof = true
      elsif chunk
        @pending << chunk
      end
    end

    playable = @pending.bytesize - (@pending.bytesize % 4)

    if playable > 0
      pcm = @pending.byteslice(0, playable)
      used = Audio.update(pcm)
      if used > 0
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

  def self.stop
    return unless @playing

    @stream.close
    Audio.close
    @stream = nil
    @pending = ""
    @eof = false
    @playing = false
  end
end
