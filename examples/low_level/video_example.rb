video = Gfx.video_open("nitro:/bad_apple.mp4.r15v")
audio = FS.open("nitro:/bad_apple.mp4.stream.pcm")
width = video[0]
height = video[1]
frame_rate = video[2]
x = (256 - width) / 2
y = (192 - height) / 2
pending = ""
position = nil
frame = -1

Audio.open(sample_rate: 32000, bits: 8, channels: 2)

while System.main_loop?
  if pending.bytesize < 8192
    chunk = FS.read(audio, 4096)
    if chunk == ""
      FS.seek(audio, 0)
      chunk = FS.read(audio, 4096)
    end
    pending << chunk
  end

  playable = pending.bytesize - (pending.bytesize % 2)

  if playable > 0
    pcm = pending.byteslice(0, playable)
    used = Audio.update(pcm)
    if used > 0
      position = -used if position.nil?
      position += used
      pending = pending.byteslice(used, pending.bytesize - used) || ""
    end
  else
    Audio.update("")
  end

  target = position.to_i * frame_rate / 64000
  if frame != target
    Gfx.video_frame(:top, x, y, target)
    frame = target
  end

  System.vblank
end

FS.close(audio)
Audio.close
Gfx.video_close
