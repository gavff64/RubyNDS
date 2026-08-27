module Audio # this is an extension layer. The C binding already has .open, .update, .close, .volume defined.
  ASSETS = {
    "sneaky_song.pcm" => { type: :stream },
    "vine_boom.pcm" => { type: :effect, sample_rate: 16000 },
    "bruh.pcm" => { type: :effect, sample_rate: 16000 }
  }

  @playing = false
  @pending = ""
  @eof = false
  @stream = nil

  def self.load(audio)
    if audio.is_a?(String)
      asset = ASSETS[audio]
      raise "Unknown audio asset: #{audio}" unless asset

      if asset[:type] == :stream
        return PCMFile.new("nitro:/#{audio}")
      else
        return Audio.sample_load(load_pcm("nitro:/#{audio}"), sample_rate: asset[:sample_rate])
      end
    end

    audio
  end

  def self.play(audio)
    return Audio.effect_play(audio) if audio.is_a?(Integer)

    unless @playing && @stream == audio
      stop if @playing

      Audio.open(sample_rate: 32000, bits: 16, channels: 2)
      @stream = audio
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

module Audio # I know this is kinda weird to specify twice, looks cleaner to me. Might refactor.
  class PCMFile
    def initialize(path)
      @file = FS.open(path)
      @closed = false
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
