module Input
  def self.down?(key)
    (down & key) != 0
  end
end

KEY_A = 1 << 0
KEY_B = 1 << 1

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

def load_pcm(path)
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

vine_boom = Audio.sample_load(load_pcm("nitro:/vine_boom.pcm"), sample_rate: 16000)
bruh = Audio.sample_load(load_pcm("nitro:/bruh.pcm"), sample_rate: 16000)
music = FS.open("nitro:/sneaky_song.pcm")
pending = ""

Audio.open(sample_rate: 32000, bits: 16, channels: 2)

puts "Press A for vine boom"
puts "Press B for bruh"

while System.main_loop?
  Input.update

  Audio.effect_play(vine_boom) if Input.down?(KEY_A)
  Audio.effect_play(bruh) if Input.down?(KEY_B)

  if pending.bytesize < 8192
    chunk = FS.read(music, 4096)
    if chunk == ""
      FS.seek(music, 0)
      chunk = FS.read(music, 4096)
    end
    pending << chunk
  end

  playable = pending.bytesize - (pending.bytesize % 4)

  if playable > 0
    pcm = pending.byteslice(0, playable)
    used = Audio.update(pcm)
    if used > 0
      pending = pending.byteslice(used, pending.bytesize - used) || ""
    end
  else
    Audio.update("")
  end

  System.vblank
end

FS.close(music)
Audio.close
