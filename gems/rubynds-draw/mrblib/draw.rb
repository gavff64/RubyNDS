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

  class Font
    attr_reader :width, :height

    def initialize(width, height, first, data)
      @width = width
      @height = height
      @first = first
      @last = first + data.bytesize / height
      @fallback = 63 >= @first && 63 < @last ? 63 : @first
      @data = data
    end

    def row(character, y)
      character = @fallback unless character >= @first && character < @last
      @data.getbyte((character - @first) * @height + y)
    end
  end

  FONT_DATA =
    "\x00\x00\x00\x00\x00\x00\x00\x00\x18\x3C\x3C\x18\x18\x00\x18\x00\x36\x36\x00\x00\x00\x00\x00\x00\x36\x36\x7F\x36\x7F\x36\x36\x00" \
    "\x0C\x3E\x03\x1E\x30\x1F\x0C\x00\x00\x63\x33\x18\x0C\x66\x63\x00\x1C\x36\x1C\x6E\x3B\x33\x6E\x00\x06\x06\x03\x00\x00\x00\x00\x00" \
    "\x18\x0C\x06\x06\x06\x0C\x18\x00\x06\x0C\x18\x18\x18\x0C\x06\x00\x00\x66\x3C\xFF\x3C\x66\x00\x00\x00\x0C\x0C\x3F\x0C\x0C\x00\x00" \
    "\x00\x00\x00\x00\x00\x0C\x0C\x06\x00\x00\x00\x3F\x00\x00\x00\x00\x00\x00\x00\x00\x00\x0C\x0C\x00\x60\x30\x18\x0C\x06\x03\x01\x00" \
    "\x3E\x63\x73\x7B\x6F\x67\x3E\x00\x0C\x0E\x0C\x0C\x0C\x0C\x3F\x00\x1E\x33\x30\x1C\x06\x33\x3F\x00\x1E\x33\x30\x1C\x30\x33\x1E\x00" \
    "\x38\x3C\x36\x33\x7F\x30\x78\x00\x3F\x03\x1F\x30\x30\x33\x1E\x00\x1C\x06\x03\x1F\x33\x33\x1E\x00\x3F\x33\x30\x18\x0C\x0C\x0C\x00" \
    "\x1E\x33\x33\x1E\x33\x33\x1E\x00\x1E\x33\x33\x3E\x30\x18\x0E\x00\x00\x0C\x0C\x00\x00\x0C\x0C\x00\x00\x0C\x0C\x00\x00\x0C\x0C\x06" \
    "\x18\x0C\x06\x03\x06\x0C\x18\x00\x00\x00\x3F\x00\x00\x3F\x00\x00\x06\x0C\x18\x30\x18\x0C\x06\x00\x1E\x33\x30\x18\x0C\x00\x0C\x00" \
    "\x3E\x63\x7B\x7B\x7B\x03\x1E\x00\x0C\x1E\x33\x33\x3F\x33\x33\x00\x3F\x66\x66\x3E\x66\x66\x3F\x00\x3C\x66\x03\x03\x03\x66\x3C\x00" \
    "\x1F\x36\x66\x66\x66\x36\x1F\x00\x7F\x46\x16\x1E\x16\x46\x7F\x00\x7F\x46\x16\x1E\x16\x06\x0F\x00\x3C\x66\x03\x03\x73\x66\x7C\x00" \
    "\x33\x33\x33\x3F\x33\x33\x33\x00\x1E\x0C\x0C\x0C\x0C\x0C\x1E\x00\x78\x30\x30\x30\x33\x33\x1E\x00\x67\x66\x36\x1E\x36\x66\x67\x00" \
    "\x0F\x06\x06\x06\x46\x66\x7F\x00\x63\x77\x7F\x7F\x6B\x63\x63\x00\x63\x67\x6F\x7B\x73\x63\x63\x00\x1C\x36\x63\x63\x63\x36\x1C\x00" \
    "\x3F\x66\x66\x3E\x06\x06\x0F\x00\x1E\x33\x33\x33\x3B\x1E\x38\x00\x3F\x66\x66\x3E\x36\x66\x67\x00\x1E\x33\x07\x0E\x38\x33\x1E\x00" \
    "\x3F\x2D\x0C\x0C\x0C\x0C\x1E\x00\x33\x33\x33\x33\x33\x33\x3F\x00\x33\x33\x33\x33\x33\x1E\x0C\x00\x63\x63\x63\x6B\x7F\x77\x63\x00" \
    "\x63\x63\x36\x1C\x1C\x36\x63\x00\x33\x33\x33\x1E\x0C\x0C\x1E\x00\x7F\x63\x31\x18\x4C\x66\x7F\x00\x1E\x06\x06\x06\x06\x06\x1E\x00" \
    "\x03\x06\x0C\x18\x30\x60\x40\x00\x1E\x18\x18\x18\x18\x18\x1E\x00\x08\x1C\x36\x63\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF" \
    "\x0C\x0C\x18\x00\x00\x00\x00\x00\x00\x00\x1E\x30\x3E\x33\x6E\x00\x07\x06\x06\x3E\x66\x66\x3B\x00\x00\x00\x1E\x33\x03\x33\x1E\x00" \
    "\x38\x30\x30\x3E\x33\x33\x6E\x00\x00\x00\x1E\x33\x3F\x03\x1E\x00\x1C\x36\x06\x0F\x06\x06\x0F\x00\x00\x00\x6E\x33\x33\x3E\x30\x1F" \
    "\x07\x06\x36\x6E\x66\x66\x67\x00\x0C\x00\x0E\x0C\x0C\x0C\x1E\x00\x30\x00\x30\x30\x30\x33\x33\x1E\x07\x06\x66\x36\x1E\x36\x67\x00" \
    "\x0E\x0C\x0C\x0C\x0C\x0C\x1E\x00\x00\x00\x33\x7F\x7F\x6B\x63\x00\x00\x00\x1F\x33\x33\x33\x33\x00\x00\x00\x1E\x33\x33\x33\x1E\x00" \
    "\x00\x00\x3B\x66\x66\x3E\x06\x0F\x00\x00\x6E\x33\x33\x3E\x30\x78\x00\x00\x3B\x6E\x66\x06\x0F\x00\x00\x00\x3E\x03\x1E\x30\x1F\x00" \
    "\x08\x0C\x3E\x0C\x0C\x2C\x18\x00\x00\x00\x33\x33\x33\x33\x6E\x00\x00\x00\x33\x33\x33\x1E\x0C\x00\x00\x00\x63\x6B\x7F\x7F\x36\x00" \
    "\x00\x00\x63\x36\x1C\x36\x63\x00\x00\x00\x33\x33\x33\x3E\x30\x1F\x00\x00\x3F\x19\x0C\x26\x3F\x00\x38\x0C\x0C\x07\x0C\x0C\x38\x00" \
    "\x18\x18\x18\x00\x18\x18\x18\x00\x07\x0C\x0C\x38\x0C\x0C\x07\x00\x6E\x3B\x00\x00\x00\x00\x00\x00"

  DEFAULT_FONT = Font.new(8, 8, 32, FONT_DATA)

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
    attr_reader :width, :height, :frame_rate

    def initialize(path)
      path = "#{path}.r15v" unless path.downcase.end_with?(".r15v")
      path = path.start_with?("nitro:/") ? path : "nitro:/#{path}"
      @width, @height, @frame_rate = Gfx.video_open(path)
      @closed = false
    end

    def draw(frame, x, y)
      Gfx.video_frame(:top, x, y, frame)
    end

    def close
      return if @closed
      Gfx.video_close
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

  def self.image(image, x, y, screen = :top)
    Gfx.blit(screen, x, y, image.width, image.height, image.pixels)
  end

  def self.video(video, x = nil, y = nil)
    return false if video.closed?

    unless @video == video
      stop
      @video = video
      @x = x || (256 - video.width) / 2
      @y = y || (192 - video.height) / 2
      @start = System.milliseconds
      @frame = -1
    end

    frame = (System.milliseconds - @start) * video.frame_rate / 1000

    if frame != @frame
      video.draw(frame, @x, @y)
      @frame = frame
    end

    true
  end

  def self.stop
    return unless @video
    @video.close
    @video = nil
  end

  def self.pixel(x, y, color, screen = :top)
    Gfx.fill_rect(screen, x, y, 1, 1, color)
  end

  def self.rectangle(x, y, width, height, color, screen = :top)
    Gfx.fill_rect(screen, x, y, width, height, color)
  end

  def self.text(text, x, y, color = WHITE, screen = :top, font = DEFAULT_FONT)
    start_x = x

    text.each_byte do |character|
      next if character == 13

      if character == 10
        x = start_x
        y += font.height
        next
      end

      font.height.times do |row|
        bits = font.row(character, row)
        column = 0

        while column < font.width
          column += 1 while column < font.width && (bits & (1 << column)) == 0
          first = column
          column += 1 while column < font.width && (bits & (1 << column)) != 0
          Gfx.fill_rect(screen, x + first, y + row, column - first, 1, color) if column > first
        end
      end

      x += font.width
    end
  end

  def self.circle(x, y, size, color, screen = :top) # unfilled, sorta just testing (aka this is a bad way to do this)
    360.times do |degrees|
      angle = degrees * Math::PI / 180

      point_x = x + size * Math.cos(angle)
      point_y = y + size * Math.sin(angle)

      Draw.pixel(point_x, point_y, color, screen)
    end
  end
end
