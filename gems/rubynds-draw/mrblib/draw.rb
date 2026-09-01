module Color
  def self.rgb(r, g, b)
    (r & 31) | ((g & 31) << 5) | ((b & 31) << 10) | (1 << 15)
  end
end

RED = Color.rgb(31, 0, 0)
YELLOW = Color.rgb(31, 31, 0)
BLUE = Color.rgb(0, 0, 31)
GREEN = Color.rgb(0, 31, 0)
GRAY = Color.rgb(24, 24, 24)
BLACK = Color.rgb(0, 0, 0)
WHITE = Color.rgb(31, 31, 31)
LIGHT_GRAY = Color.rgb(28, 28, 28)
DARK_GRAY = Color.rgb(10, 10, 10)
ORANGE = Color.rgb(31, 16, 0)
BROWN = Color.rgb(18, 9, 0)
PURPLE = Color.rgb(16, 0, 24)
PINK = Color.rgb(31, 16, 24)
CYAN = Color.rgb(0, 31, 31)
MAGENTA = Color.rgb(31, 0, 31)
LIME = Color.rgb(16, 31, 0)
MAROON = Color.rgb(16, 0, 0)
OLIVE = Color.rgb(16, 16, 0)
GAVFF_GREEN = Color.rgb(9, 14, 1)
NAVY = Color.rgb(0, 0, 16)
TEAL = Color.rgb(0, 16, 16)
GOLD = Color.rgb(31, 26, 0)
BEIGE = Color.rgb(30, 28, 22)
TAN = Color.rgb(26, 21, 14)
CORAL = Color.rgb(31, 16, 10)
VIOLET = Color.rgb(20, 10, 31)
INDIGO = Color.rgb(9, 0, 16)
SKY_BLUE = Color.rgb(10, 22, 31)
DARK_RED = Color.rgb(16, 0, 0)
DARK_GREEN = Color.rgb(0, 16, 0)
DARK_BLUE = Color.rgb(0, 0, 16)

module Draw
  VIDEO_FORMATS = %w[.gif .mp4 .mov .mkv .webm .avi .r15v]
  CLOCK_RATE = 32768
  CLOCK_BYTES = CLOCK_RATE * 4
  SILENCE = "\0" * 16384

  class Image
    attr_reader :width, :height, :pixels

    def initialize(path)
      path = "#{path}.r15i" unless path.end_with?(".r15i")
      path = path.start_with?("nitro:/") ? path : "nitro:/#{path}"
      file = FS.open(path)
      header = FS.read(file, 8)

      unless header.bytesize == 8 && header.byteslice(0, 4) == "R15I"
        FS.close(file)
        raise "invalid RGB15 image"
      end

      @width = header.getbyte(4) | header.getbyte(5) << 8
      @height = header.getbyte(6) | header.getbyte(7) << 8

      unless @width > 0 && @width <= 256 && @height > 0 && @height <= 192
        FS.close(file)
        raise "invalid RGB15 image"
      end

      @pixels = FS.read(file, @width * @height * 2)
      FS.close(file)

      raise "invalid RGB15 image" unless @pixels.bytesize == @width * @height * 2
    end
  end

  class Video
    attr_reader :width, :height, :frame_rate, :frame_count

    def initialize(path)
      path = "#{path}.r15v" unless path.end_with?(".r15v")
      path = path.start_with?("nitro:/") ? path : "nitro:/#{path}"
      @file = FS.open(path)
      header = FS.read(@file, 14)

      unless header.bytesize == 14 && header.byteslice(0, 4) == "R15V"
        FS.close(@file)
        raise "invalid RGB15 video"
      end

      @width = header.getbyte(4) | header.getbyte(5) << 8
      @height = header.getbyte(6) | header.getbyte(7) << 8
      @frame_rate = header.getbyte(8) | header.getbyte(9) << 8
      @frame_count = header.getbyte(10) |
        header.getbyte(11) << 8 |
        header.getbyte(12) << 16 |
        header.getbyte(13) << 24

      unless @width > 0 && @width <= 256 && @height > 0 && @height <= 192 &&
             @frame_rate > 0 && @frame_rate <= 60 && @frame_count > 0
        FS.close(@file)
        raise "invalid RGB15 video"
      end

      @frame_size = @width * @height * 2
      @closed = false
    end

    def frame(index)
      FS.seek(@file, 14 + index * @frame_size)
      pixels = FS.read(@file, @frame_size)
      raise "invalid RGB15 video" unless pixels.bytesize == @frame_size
      pixels
    end

    def close
      return if @closed
      FS.close(@file)
      @closed = true
    end

    def closed?
      @closed
    end
  end

  def self.load(path)
    return Video.new(path) if VIDEO_FORMATS.any? { |format| path.downcase.end_with?(format) }
    Image.new(path)
  end

  def self.image(image, x, y)
    Gfx.blit(:top, x, y, image.width, image.height, image.pixels)
  end

  def self.video(video, x = nil, y = nil)
    return false if video.closed?

    unless @video == video
      stop
      @audio = Audio.playing?
      unless @audio
        Audio.open(sample_rate: CLOCK_RATE, bits: 16, channels: 2)
        Audio.volume = 0
      end
      @video = video
      @x = x || (256 - video.width) / 2
      @y = y || (192 - video.height) / 2
      @clock = nil
      @frame = -1
    end

    if @audio
      frame = Audio.position * video.frame_rate / Audio.bytes_per_second
    else
      used = Audio.update(SILENCE)
      @clock = -used if @clock.nil?
      @clock += used
      frame = @clock * video.frame_rate / CLOCK_BYTES
    end

    frame %= video.frame_count

    if frame != @frame
      Gfx.blit(:top, @x, @y, video.width, video.height, video.frame(frame))
      @frame = frame
    end

    true
  end

  def self.stop
    return unless @video
    @audio ? Audio.stop : Audio.close
    @video.close
    @video = nil
  end

  def self.pixel(x, y, color)
    Gfx.fill_rect(:top, x, y, 1, 1, color)
  end

  def self.rectangle(x, y, width, height, color)
    Gfx.fill_rect(:top, x, y, width, height, color)
  end

  def self.circle(x, y, size, color) # unfilled, sorta just testing
    360.times do |degrees|
      angle = degrees * Math::PI / 180

      point_x = x + size * Math.cos(angle)
      point_y = y + size * Math.sin(angle)

      Draw.pixel(point_x, point_y, color)
    end
  end
end
