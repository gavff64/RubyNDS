# Preface

As stated in the [README](./README.md), RubyNDS is an extremely ambitious project for me. I didn't, and still don't, have too much low-level hardware knowledge
or even C knowledge. The bindings were created via LLM, but not blindly, while the higher-level Ruby portions and mrbgems were created by me.

I will attempt to go over everything in the furthest amount of detail my knowledge allows me. However, this is not a technical deep dive because
a lot of that is already done by pre-existing DS development ecosystems that RubyNDS uses. But if you want to see my struggle understanding
bitmasks and how the DS hardware does anything at all, you can see some of that goofiness in [examples/tests/generic_testing.rb](./examples/tests/generic_testing.rb).

These docs are also available on my website https://docs.gavff.dev/RubyNDS

P.S. I am not an author, so sorry if this sucks balls lol 👎. There's a ton to write and I've definitely left some stuff out.

<img width="419" height="290" alt="comedy" src="https://github.com/user-attachments/assets/4ad324c9-ed5e-4c66-af20-06ec231145cf" />

## Contents

- [Getting started](#getting-started)
- [Application loop](#application-loop)
- [Low-level API](#low-level-api)
- [High-level API](#high-level-api)
- [Images, video and audio](#images-video-and-audio)
- [Limitations](#limitations)

## Getting started

| Requires: Ruby and Rake |
| --- |

</div>

1. Clone RubyNDS:

```sh
git clone https://github.com/gavff64/RubyNDS.git
cd RubyNDS
```

2. Run the setup:

```sh
rake setup
```

This checks for [devkitPro](https://devkitpro.org/wiki/Getting_Started) with the `nds-dev` package group, the required build tools and [FFmpeg](https://ffmpeg.org/). It also clones [mruby 4.0.0](https://github.com/mruby/mruby) into the `vendor` directory. If anything is missing, install it and run `rake setup` again.

3. Then build an application:

```sh
make GAME=examples/example.rb
```

4. The resulting ROM will be written to:

```text
example.nds
```

After modifying your application, run the same `make` command again. You only need to run a clean build if you want to rebuild everything:

```sh
make clean
make GAME=examples/example.rb
```

## Application loop

`System.main_loop?` is where you'd put application logic for what happens every frame loop. Whether it be drawing a rectangle all the time, no
matter what, or only drawing it if you're holding a button.

For example, this short script draws a red 20 by 20 pixel rectangle at the coordinates 100, 100 if you push the A button. That rectangle remains
there infinitely because there is no other logic to remove it or do anything else.

```ruby
# HIGH-LEVEL API
while System.main_loop?
  Input.update

  Draw.rectangle(100, 100, 20, 20, RED) if Input.down?(KEY_A)

  System.vblank
end
```

`Input.update` is what asks the DS hardware what buttons are currently being pressed, then it updates 3 bitmask values, `Input.down`, `Input.held`,
and `Input.up`.

`System.vblank` keeps the CPU in check by pausing additional logic until the display reaches its next vertical blank. This prevents `System.main_loop?`
from running thousands of times per second unnecessarily, screen tearing, excessive battery usage, etc. etc.

Notice that I said `Input.down` earlier instead of `Input.down?` like the code says? These are examples of the beginnings of the dozens of niceties added thanks to the
high-level helpers. Without the high-level helpers, you would need to write this:

```ruby
module Color
  def self.rgb(r, g, b)
    (r & 31) | ((g & 31) << 5) | ((b & 31) << 10) | (1 << 15)
  end
end

KEY_A = 1 << 0
RED = Color.rgb(31, 0, 0)

while System.main_loop?
  Input.update
  down = Input.down

  Gfx.fill_rect(:top, 100, 100, 20, 20, RED) if (down & KEY_A) != 0

  System.vblank
end
```

Wow! That's a lot of junk to worry about!! 🤔

We'll go over this more later, but the point is that input checking and drawing are 2 examples of things that need to run every single frame.
As opposed to something as simple as this:

```ruby
puts "Hello World!"
```

Which, yes! This is a valid RubyNDS program! This builds as an `.nds` file and will output "Hello World!" to the on-device text console. This doesn't require
constant frame by frame updating because this is a low-level C implementation from [libnds](https://github.com/devkitPro/libnds) which simply prints the text once
and the console retains the text, like any other terminal would.

## Low-level API

The low-level API maps closely to the native bindings and leaves application behavior in Ruby... mostly. You can see several examples of this in
[here.](./examples/low_level) This section of the docs is referring to [the actual C bindings](./src) AND the resulting low-level Ruby methods. Again,
please see the examples for the general method usage structure.

Some minor "exceptions" (if you want to call them that) would be video and HTTPS. They are present here, and you can see both low level and high level
examples of HTTPS and video in the [examples](./examples). However, TLS seed generation on-device would be insecure, and true video decoding is close to impossible
(or at least would require an LLM to build a huge system, defeating the purpose of this project). The [Makefile](./Makefile) + [tools](./tools) handle this at
build time.

### `System`

```c
void register_system_bindings(mrb_state *mrb)
{
  struct RClass *sys = mrb_define_module(mrb, "System");
  mrb_define_module_function(mrb, sys, "vblank",    sys_vblank,    MRB_ARGS_NONE());
  mrb_define_module_function(mrb, sys, "main_loop?", sys_main_loop_p, MRB_ARGS_NONE());
  mrb_define_module_function(mrb, sys, "milliseconds", sys_milliseconds, MRB_ARGS_NONE());
}
```

This is the `System.main_loop?` application loop discussed earlier, as well as a millisecond clock used by the [rubynds-timer mrbgem](./gems/rubynds-timer). Writing a timer
without this binding in Ruby would likely be wildly inaccurate from my experience.

### `Input`

```c
void register_input_bindings(mrb_state *mrb)
{
  struct RClass *inp = mrb_define_module(mrb, "Input");
  mrb_define_module_function(mrb, inp, "update",   input_update,   MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "held",     input_held,     MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "down",     input_down,     MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "up",       input_up,       MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch?",   input_touch_p,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch_x",  input_touch_x,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, inp, "touch_y",  input_touch_y,  MRB_ARGS_NONE());
}
```

Various button and touchscreen states which are returned as bitmasks. Here's a snippet from [generic_testing.rb](./examples/tests/generic_testing.rb) that was only intended as personal
notes, but works here.

```ruby
KEY_A = 1 << 0 # 000000000001 = 1
KEY_B = 1 << 1 # 000000000010 = 2
KEY_SELECT = 1 << 2 # 000000000100 = 4
KEY_START = 1 << 3 # 000000001000 = 8
KEY_RIGHT = 1 << 4 # etc.
KEY_LEFT = 1 << 5
KEY_UP = 1 << 6
KEY_DOWN = 1 << 7
KEY_R = 1 << 8
KEY_L = 1 << 9
KEY_X = 1 << 10
KEY_Y = 1 << 11
KEY_TOUCH = 1 << 14

module Input
  def self.down?(key)
    (down & key) != 0
  end
end
```

Here I am defining the keys as constants. Presumably if you're reading this part, you already know how bit shifting works, so hopefully I don't
need to re-explain it extremely poorly. Point is, you can see the `down` method defined from the C binding inside the `Input` helper.

### `Gfx`

```c
void register_gfx_bindings(mrb_state *mrb)
{
  struct RClass *gfx = mrb_define_module(mrb, "Gfx");
  mrb_define_module_function(mrb, gfx, "blit",      gfx_blit,      MRB_ARGS_REQ(6));
  mrb_define_module_function(mrb, gfx, "fill_rect", gfx_fill_rect, MRB_ARGS_REQ(6));
  mrb_define_module_function(mrb, gfx, "bottom_mode", gfx_bottom_mode, MRB_ARGS_REQ(1));
}
```

Basically just copying pixel data to either screen. Also some remnants of debug mode, used by the [rubynds-debug mrbgem](./gems/rubynds-debug). It's just a toggle
to display the libnds text console on the bottom screen or not. Graphics are supported on the top and bottom screen. Again you can see
`Gfx.fill_rect` was used earlier.

### `FS`

```c
void register_fs_bindings(mrb_state *mrb)
{
  struct RClass *fs = mrb_define_module(mrb, "FS");
  mrb_define_module_function(mrb, fs, "open",  fs_open,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, fs, "read",  fs_read,  MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, fs, "seek",  fs_seek,  MRB_ARGS_ARG(2, 1));
  mrb_define_module_function(mrb, fs, "close", fs_close, MRB_ARGS_REQ(1));
}
```

This is the NitroFS file system. For RubyNDS, whatever you put in the [assets](./assets) directory gets embedded inside the ROM and can be used by the DS
if supported. The [tools](./tools) run by the [Makefile](./Makefile) at build time and auto convert many file formats to RubyNDS/DS-friendly formats.

### `Audio`

```c
void register_audio_bindings(mrb_state *mrb)
{
  struct RClass *audio = mrb_define_module(mrb, "Audio");
  mrb_define_module_function(mrb, audio, "open",   audio_open,   MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "update", audio_update, MRB_ARGS_ARG(1, 2));
  mrb_define_module_function(mrb, audio, "volume=", audio_set_volume, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "close",  audio_close,  MRB_ARGS_NONE());
  mrb_define_module_function(mrb, audio, "sample_load", audio_sample_load, MRB_ARGS_REQ(1) | MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "effect_play", audio_effect_play, MRB_ARGS_REQ(1) | MRB_ARGS_KEY(3, 0));
  mrb_define_module_function(mrb, audio, "effect_stop", audio_effect_stop, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "effect_release", audio_effect_release, MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, audio, "effect_volume", audio_effect_volume, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, audio, "effect_pan", audio_effect_pan, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, audio, "effect_rate", audio_effect_rate, MRB_ARGS_REQ(2));
}
```

Raw PCM playback and streaming through [Maxmod](https://github.com/devkitPro/maxmod). Auto-converted files will be 8-bit PCM at 32,000 Hz. RubyNDS will assume straight PCM files
are 16-bit, defaulted to 32,000 Hz as well.

I'm a bit wary of the audio system. I read about ADPCM, which might be the proper way to do this...?
But it sounds like it's hard to work with or something? So for now we just have 8 and 16-bit PCM. I can run full
color video with audio on RubyNDS without absurdly high file sizes, I think this is fine for now.

### `Net`

```c
void register_net_bindings(mrb_state *mrb)
{
  struct RClass *net = mrb_define_module(mrb, "Net");
  mrb_define_module_function(mrb, net, "wifi",    net_wifi,    MRB_ARGS_NONE());
  mrb_define_module_function(mrb, net, "ip",      net_ip,      MRB_ARGS_NONE());
  mrb_define_module_function(mrb, net, "dns",     net_dns,     MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, net, "connect", net_connect, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "send",    net_send,    MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "recv",    net_recv,    MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "nonblock", net_nonblock, MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, net, "close",   net_close,   MRB_ARGS_REQ(1));
}
```

Basic networking, such as connecting to Wi-Fi, DNS lookups, TCP connections, sending and receiving bytes, etc. etc.

### `TLS`

```c
void register_tls_bindings(mrb_state *mrb)
{
  struct RClass *tls = mrb_define_module(mrb, "TLS");
  mrb_define_module_function(mrb, tls, "seed",  tls_seed,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "open",  tls_open,  MRB_ARGS_REQ(2));
  mrb_define_module_function(mrb, tls, "send",  tls_send,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "recv",  tls_recv,  MRB_ARGS_REQ(1));
  mrb_define_module_function(mrb, tls, "close", tls_close, MRB_ARGS_NONE());
}
```

I don't know a damn thing about network security, TLS, HTTPS. But if we want RubyNDS to be able to interact with the majority of the internet,
I had to vaguely throw something together. My understanding is that you need to make the TCP connection first, then make the HTTP request through
the TLS encryption.

Again, I don't want to regurgitate my poor and likely wrong understanding of HTTPS/TLS. So I'm only going to go over the setup for this.

We use [BearSSL](./third_party/bearssl) in the TLS binding to handle everything. However, a `tls.seed` file is required ONCE PER SD CARD (not once per `.nds` file). This could
technically be generated on-device, but I don't think there's enough randomness I can pull out of the hardware to make this safe, I could
be wrong though.

Run [tools/tls_seed.rb](./tools/tls_seed.rb):

```bash
ruby tools/tls_seed.rb /path/to/sd-card/tls.seed
```

This file goes inside the root directory of the SD card your compiled ROM is in. DO NOT PUT THIS IN `assets`.

Note: the clock on your DS needs to be set correctly. TLS checks certificate expiration dates.

There is a high-level HTTPS mrbgem that uses this binding, so HTTPS programmatically is written similarly to HTTP.

## High-level API

The high-level API is implemented by Ruby mrbgems using the low-level API. You can see several examples of this [here](./examples/high_level).

### `Draw`

The `Color` helper is included in the `Draw` mrbgem:

```ruby
custom_color = Color.rgb(4, 29, 1)
```

with a large pre-defined list for convenience:

```ruby
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
```

Each channel uses a value from 0 to 31. You can read more about this in [examples/tests/generic_testing.rb](./examples/tests/generic_testing.rb).

Drawing a green rectangle at (100, 100), sized 20x20 pixels, on the top screen:

```ruby
Draw.rectangle(100, 100, 20, 20, GAVFF_GREEN, :top)
```

Bottom screen:

```ruby
Draw.rectangle(100, 100, 20, 20, GAVFF_GREEN, :bottom)
```

Displaying an image on the top and bottom screen. Placed at (0, 0), which is the corner of the display, so the whole image is viewable.
Images retain their original size, unless they are larger than the DS resolution, in which they will downscale to fit in 256 x 192.
These files come from the [assets](./assets) directory. The `fat:/` SD card directory is not implemented in this:

```ruby
image = Draw.load("picture.png")
Debug.enabled = false # Disables the bottom on-screen text console from libnds

while System.main_loop?
  Draw.image(image, 0, 0, :top)
  Draw.image(image, 0, 0, :bottom)
  System.vblank
end
```

Audio from videos will sync close enough if you play them next to each other. Video is always streamed, even if not specified. Bottom screen video support is not
implemented. Supported source formats are GIF, MP4, MOV, MKV, WebM, and AVI.

Note how you load video and audio outside the loop, and then actually play those files inside the loop:

```ruby
video = Draw.load("video.mp4")
audio = Audio.load("video.mp4", stream: true)

while System.main_loop?
  Draw.video(video)
  Audio.play(audio)
  System.vblank
end
```

Stop video:

```ruby
Draw.stop
```

Draw single pixel:

```ruby
Draw.pixel(1, 1, BLUE, :top)
```

There's built in bitmap data for a basic font that supports 95 different characters ([thanks!](https://github.com/dhepper/font8x8)). Each character is 8 by 8 pixels, which cannot
be changed without changing the entire font. Only the color can be changed easily:

```ruby
Debug.enabled = false

Draw.text("Top screen", 88, 92, WHITE, :top)
Draw.text("Bottom screen", 76, 92, WHITE, :bottom)

while System.main_loop?
  System.vblank
end
```

Inside the mrbgem you can see:

```ruby
DEFAULT_FONT = Font.new(8, 8, 32, FONT_DATA)
```

Which describes the characters being 8 by 8 pixels, the first stored character has ASCII code 32, and FONT_DATA being a long string of
bytes, each byte representing 1 horizontal row of 8 pixels.

This is good enough for now but I should probably add to the tools section a converter to turn fonts into this format.

### `Audio`

Sound effects and short audio clips should be played without streaming. Long audio files should be streamed. Only streamed audio loops
automatically.

```ruby
# Load a sound effect
effect = Audio.load("effect.wav")

# Load streaming music
music = Audio.load("music.mp3", stream: true)

# An optional sample rate can be supplied for raw PCM:
sound = Audio.load("sound.pcm", sample_rate: 16000)
```

Various playback states:

```ruby
Audio.playing?
Audio.position # reports the streaming position in bytes
Audio.bytes_per_second # can convert that position into time
```

Stop audio:

```ruby
Audio.stop
```

### `Input`

We have pre-defined constants in this helper:

```ruby
KEY_A, KEY_B, KEY_X, KEY_Y,
KEY_START, KEY_SELECT,
KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
KEY_L, KEY_R,
KEY_TOUCH
```

You get the point here:

```ruby
while System.main_loop?
  Input.update # check what inputs, if any, are happening
  puts "A pressed" if Input.down?(KEY_A) # ".held?" ".up?"
  System.vblank # pause logic and only continue loop when the frame is done drawing
end
```

### `Timer`

Just a millisecond timer:

```ruby
while System.main_loop?
  print("\r\e[2K#{Timer.ms}")
  System.vblank
end
```

### `JSON`

Not to be confused with the [mruby-json mrbgem](./gems/mruby-json) I didn't write. The original `JSON.parse` only accepted JSON text. I needed it to take a file path,
which means you would have to `FS.open`, read loop, close, every time. This does all that for you. Again, no `fat:/` SD card support:

```ruby
data = JSON.fs_parse("settings.json") # this really reads "nitro:/settings.json"
```

### `HTTP`

Inspired by [HTTParty](https://github.com/jnunemaker/httparty). Makes HTTP GET requests:

```ruby
body = HTTP.get("wttr.in/NewYork?format=3")
```

with non-blocking streaming support:

```ruby
stream = HTTP.get("192.168.1.10/music.pcm", port: 8123, stream: true)
# which gives access to...
# stream.read
# stream.read(maximum_bytes)
# stream.eof?
# stream.close
```

As well as post requests:

```ruby
body = "message=Hello+from+RubyNDS"
response = HTTP.post("http://httpbin.org/post", body)
result = JSON.parse(response)

puts result["form"]["message"]
```

### `HTTPS`

Same functionality as HTTP:

```ruby
HTTPS.get("https://example.com", port: 443)
```

```ruby
body = "message=Hello+from+RubyNDS"
response = HTTPS.post("https://httpbin.org/post", body)
result = JSON.parse(response)

puts result["form"]["message"]
```

You can specify the seed location if for some reason it's not in the root of the SD card:

```ruby
HTTPS.get("https://example.com", seed: "fat:/tls.seed")
```

### `Debug`

Toggles if you want the bottom on screen text console. By default, pressing L and R together swaps between console and not:

```ruby
Debug.enabled = true

while System.main_loop?
  Input.update

  Debug.update
  puts "A pressed" if Debug.terminal? && Input.down?(KEY_A)

  System.vblank
end
```

## Images, video and audio

The goal with this was to have 3 good formats for local playback, and 3 good formats for internet playback. I needed a balance between format popularity, file size, and computational efficiency.
R15I, R15V and PCM are intended for local use. JPEG, MJPEG, and MP3 are intended for remote (internet) use. They can be used interchangeably though.

### `R15I and R15V`

R15I (RGB15 Image) and R15V (RGB15 Video) are both my attempt at designing formats to display images and high(-ish) frame rate color video, without a
massive `.nds` file or heavy on-device decoding, or massive bindings. These file formats (alongside PCM) are meant for local media.

RGB15 is the DS's 15-bit RGB color format, which is 5 bits each for red, green, and blue. You put regular PNG, JPG, MP4, whatever into the [assets](./assets)
folder, and the [Makefile](./Makefile) + [tools](./tools) convert them to RGB15 using [FFmpeg](https://ffmpeg.org/). So the DS doesn't do any decoding, it just displays the pre-formatted data
it's been given.

R15I contains the identifier, width, height, and the RGB15 color value of every pixel. This is a simple, uncompressed format.

Now R15V. This is the tricky compressed video format. R15V contains the identifier,
width, height, frame rate, total frame count, compression information, a 256 color palette, and the compressed video frames. R15V does not store
every pixel as a complete 2 byte color. Instead, each video pixel is just a 1 byte index that points to a color in the shared 256 color palette.

These frames are compressed with [FastLZ](./third_party/fastlz), which the DS can decompress on-device fast enough for real-time video. R15V files have zero audio
data on their own. But of course audio syncing works as shown previously. Video runs at 24 FPS max, which feels smooth. I guess this means the DS
is technically decoding video, but not in the practical sense? It's mostly just decompressing.

### `PCM`

PCM is simply pre-decoded audio that the DS hardware handles directly. PCM8 and PCM16 is used, however ADPCM is unforetunately not supported due to self-incompetence lol
(from what I read, it seems difficult to work with. But the payoff could be huge, so likely worth looking more into.)

### `JPEG/MJPEG`

Fortunately, [this godsend, JPEGDEC](https://github.com/bitbank2/JPEGDEC) exists which gives super tiny and lightweight JPEG support, and a sweet side effect of that is
MJPEG support. JPEGDEC simply decompresses small sections of the frame and writes the RGB15 pixels onto the DS screen. I'm not sure how fast MJPEG playback is on this, but I was able
to successfully play a 10 fps low quality livestream.

### `MP3`

Using the [OpenCORE MP3 decoder](https://android.googlesource.com/platform/frameworks/av/+/ee17317c6362f54bd311ec359b5c3518137fae9f/media/libstagefright/codecs/mp3dec/) we can convert
buffered MP3 data into PCM16 audio. Both HTTP and HTTPS in RubyNDS read the server's Content-Type to see if the stream contains MP3 data, then creates an MP3 stream automatically.

## Limitations

A lot, but also not that much. Can't be bothered to type that out right now. The big one would be on-device media decoders severely limiting what internet content can be accessed without
a relay server. Currently I think there's a solid trio of supported codecs that can be used and worked around, but I do not want a significant portion of the project just being codec support.
As with most things here, I barely know what I am doing!!
