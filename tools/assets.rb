require "fileutils"
require "json"
require "open3"

IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .bmp .webp]
VIDEO_EXTENSIONS = %w[.gif .mp4 .mov .mkv .webm .avi]
AUDIO_EXTENSIONS = %w[.wav .mp3 .flac .ogg .m4a .aac]

source = File.expand_path(ARGV.fetch(0))
output = File.expand_path(ARGV.fetch(1))

def run(*command)
  stdout, stderr, status = Open3.capture3(*command)
  raise stderr unless status.success?
  stdout
end

def video_stream(path)
  data = run(
    "ffprobe", "-v", "error", "-select_streams", "v:0",
    "-show_entries", "stream=width,height,r_frame_rate",
    "-of", "json", path
  )
  JSON.parse(data).fetch("streams").fetch(0)
end

def audio?(path)
  data = run(
    "ffprobe", "-v", "error", "-select_streams", "a:0",
    "-show_entries", "stream=index", "-of", "json", path
  )
  !JSON.parse(data).fetch("streams").empty?
end

def dimensions(stream)
  width = stream.fetch("width")
  height = stream.fetch("height")
  scale = [256.0 / width, 192.0 / height, 1.0].min
  [[(width * scale).floor, 1].max, [(height * scale).floor, 1].max]
end

def frame_rate(stream)
  numerator, denominator = stream.fetch("r_frame_rate").split("/").map(&:to_f)
  rate = denominator == 0 ? 30 : (numerator / denominator).round
  [[rate, 1].max, 30].min
end

def rgb15(rgba)
  count = rgba.bytesize / 4
  pixels = Array.new(count)
  input = 0
  output = 0

  while output < count
    red = rgba.getbyte(input) >> 3
    green = rgba.getbyte(input + 1) >> 3
    blue = rgba.getbyte(input + 2) >> 3
    alpha = rgba.getbyte(input + 3) >= 128 ? 0x8000 : 0
    pixels[output] = red | green << 5 | blue << 10 | alpha
    input += 4
    output += 1
  end

  pixels.pack("v*")
end

def read_exact(io, length)
  data = "".b

  while data.bytesize < length
    chunk = io.read(length - data.bytesize)
    break if chunk.nil?
    data << chunk
  end

  data
end

def convert_image(source, output)
  stream = video_stream(source)
  width, height = dimensions(stream)
  rgba = run(
    "ffmpeg", "-v", "error", "-nostdin", "-i", source,
    "-frames:v", "1", "-vf", "scale=#{width}:#{height}:flags=lanczos",
    "-f", "rawvideo", "-pix_fmt", "rgba", "pipe:1"
  )
  raise "invalid image data: #{source}" unless rgba.bytesize == width * height * 4
  File.binwrite(output, ["R15I", width, height].pack("a4v2") + rgb15(rgba))
end

def convert_video(source, output)
  stream = video_stream(source)
  width, height = dimensions(stream)
  rate = frame_rate(stream)
  frame_bytes = width * height * 4
  command = [
    "ffmpeg", "-v", "error", "-nostdin", "-i", source,
    "-map", "0:v:0", "-vf", "fps=#{rate},scale=#{width}:#{height}:flags=lanczos",
    "-f", "rawvideo", "-pix_fmt", "rgba", "pipe:1"
  ]

  Open3.popen3(*command) do |stdin, stdout, stderr, wait|
    stdin.close
    error = Thread.new { stderr.read }
    frames = 0

    File.open(output, "wb") do |file|
      file.write(["R15V", width, height, rate, 0].pack("a4v3V"))

      loop do
        rgba = read_exact(stdout, frame_bytes)
        break if rgba.empty?
        raise "invalid video data: #{source}" unless rgba.bytesize == frame_bytes
        file.write(rgb15(rgba))
        frames += 1
      end

      raise "invalid video data: #{source}" if frames == 0
      file.seek(10)
      file.write([frames].pack("V"))
    end

    message = error.value
    raise message unless wait.value.success?
  end
end

def convert_audio(source, output, channels, duration = nil)
  command = [
    "ffmpeg", "-v", "error", "-nostdin", "-i", source,
    "-map", "0:a:0", "-vn", "-ac", channels.to_s, "-ar", "32000",
    "-f", "s8", "-acodec", "pcm_s8"
  ]
  command += ["-af", "apad", "-t", duration.to_s] if duration
  run(*command, output)
end

def video_duration(path)
  header = File.binread(path, 14)
  rate = header.getbyte(8) | header.getbyte(9) << 8
  frames = header.getbyte(10) |
    header.getbyte(11) << 8 |
    header.getbyte(12) << 16 |
    header.getbyte(13) << 24
  frames.to_f / rate
end

def compile(output)
  temporary = "#{output}.tmp"
  FileUtils.rm_f(temporary)
  yield temporary
  FileUtils.mv(temporary, output)
ensure
  FileUtils.rm_f(temporary)
end

FileUtils.mkdir_p(output)
outputs = []
compiler_time = File.mtime(__FILE__)

Dir.glob(File.join(source, "**", "*"), File::FNM_DOTMATCH).sort.each do |path|
  next unless File.file?(path)

  relative = path.delete_prefix("#{source}/")
  extension = File.extname(path).downcase
  destination = File.join(output, relative)

  if AUDIO_EXTENSIONS.include?(extension)
    effect = "#{destination}.effect.pcm"
    stream = "#{destination}.stream.pcm"
    outputs << effect
    outputs << stream

    [[effect, 1], [stream, 2]].each do |audio, channels|
      FileUtils.mkdir_p(File.dirname(audio))
      next if File.exist?(audio) && File.mtime(audio) >= [File.mtime(path), compiler_time].max
      puts "audio #{relative}"
      compile(audio) { |temporary| convert_audio(path, temporary, channels) }
    end

    next
  end

  if VIDEO_EXTENSIONS.include?(extension)
    video = "#{destination}.r15v"
    outputs << video
    FileUtils.mkdir_p(File.dirname(video))

    unless File.exist?(video) && File.mtime(video) >= [File.mtime(path), compiler_time].max
      puts "video #{relative}"
      compile(video) { |temporary| convert_video(path, temporary) }
    end

    if audio?(path)
      audio = "#{destination}.stream.pcm"
      outputs << audio
      unless File.exist?(audio) && File.mtime(audio) >= [File.mtime(path), compiler_time].max
        puts "audio #{relative}"
        duration = video_duration(video)
        compile(audio) { |temporary| convert_audio(path, temporary, 2, duration) }
      end
    end

    next
  end

  if IMAGE_EXTENSIONS.include?(extension)
    destination = "#{destination}.r15i"
  end

  outputs << destination
  FileUtils.mkdir_p(File.dirname(destination))
  next if File.exist?(destination) && File.mtime(destination) >= [File.mtime(path), compiler_time].max

  if IMAGE_EXTENSIONS.include?(extension)
    puts "image #{relative}"
    compile(destination) { |temporary| convert_image(path, temporary) }
  else
    compile(destination) { |temporary| FileUtils.cp(path, temporary) }
  end
end

Dir.glob(File.join(output, "**", "*"), File::FNM_DOTMATCH).reverse_each do |path|
  if File.file?(path)
    FileUtils.rm_f(path) unless outputs.include?(path)
  elsif File.directory?(path) && Dir.empty?(path)
    Dir.rmdir(path)
  end
end
