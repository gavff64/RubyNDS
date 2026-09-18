<div align="center">

# RubyNDS
Write DSi Homebrew apps in pure Ruby!

Documentation and setup at [DOCS.md](./DOCS.md)

<img width="235" height="360" alt="video" src="https://github.com/user-attachments/assets/0fa1c674-4b7e-43a6-96b7-38bbc3ca556a" />

</div>

## What is this?
RubyNDS is an SDK which includes an embedded mruby runtime, thin bindings to native DS libraries, build tooling and examples. There is both a **low-level Ruby API** for finer-grained control without C, and an idiomatic **high-level Ruby API** for developer happiness. The focus is DSi development, but inherently *most* RubyNDS applications will run on DS/2DS/3DS as well.

<div align="center">

| DS hardware -> Native DS Libraries -> Thin C bindings -> Low-level Ruby API -> High-level Ruby API |
| --- |

</div>

### Example:

These 3 scripts all do the same thing.
- Connect to wifi
- Fetch some data
- Display the result through the libnds on-screen console (unparsed)

Here's the ***scary*** C example:

```c
// This specific example is generated.
// Please read "What's the purpose?" in this README to understand why.
Wifi_InitDefault(WFC_CONNECT);

struct hostent *host = gethostbyname("wttr.in");
int sock = socket(AF_INET, SOCK_STREAM, 0);

struct sockaddr_in server = { 0 };
server.sin_family = AF_INET;
server.sin_port = htons(80);
memcpy(&server.sin_addr, host->h_addr_list[0], 4);

connect(sock, (struct sockaddr *)&server, sizeof server);

char request[] =
  "GET /NewYork?format=3 HTTP/1.1\r\n"
  "Host: wttr.in\r\n"
  "Connection: close\r\n\r\n";

send(sock, request, strlen(request), 0);

char response[512];
int bytes;
while ((bytes = recv(sock, response, sizeof response, 0)) > 0)
  printf("%.*s", bytes, response);

closesocket(sock);
```

Then that same example using the **low-level Ruby API**:

```ruby
Net.wifi

sock = Net.connect("wttr.in", 80)

request_lines = [
  "GET #{PATH} HTTP/1.1",
  "Host: #{HOST}",
  "User-Agent: curl/8.0",
  "Connection: close"
]
request = request_lines.join("\r\n") + "\r\n\r\n"

Net.send(sock, request)

loop do
  chunk = Net.recv(sock, 512)
  break if chunk == ""
  print chunk
end

Net.close(sock)
```

Then again using the beautiful **high-level Ruby API**:

```ruby
puts HTTP.get("wttr.in/NewYork?format=3") # Response has header auto-trimmed
```

> See more low-level and high-level Ruby-only examples in [examples](./examples/)

## What's the purpose?
I wanted to write homebrew apps for the DSi using a favorable language. And since I don't really know any C, I wanted to avoid having an LLM create an entire framework for me. Not only is that pretty lame, but I learn nothing in the process as the majority of the hard work is done.

So the goal is that the C layer only exists as primitive bindings to a small-ish low-level Ruby API, which I've attempted to design myself, but haven't written myself since it's obviously in a language I don't know. The high-level Ruby API is a conglomeration of mrbgems that wrap one or more low-level Ruby API calls into much more idiomatic Ruby methods. Fortunately for me, that is pure Ruby that I get to write! (trust me, you can tell.)

For full transparency sake. I am crudely punching above my weight with this project. What I thought was going to be some tiny bindings to allow me to write small homebrew projects turned into a full SDK. I'm researching and learning on the fly, so be aware that many concepts and implementations will not be strong. I am merely a hobbiest Ruby programmer 🥀

That being said. This is only possible thanks to all of the DS native libraries and SDK components available like [libnds](https://github.com/devkitPro/libnds), [DSWiFi](https://github.com/devkitPro/dswifi), [Maxmod](https://github.com/devkitPro/maxmod). And obviously [devkitPro](https://github.com/devkitPro) for even providing the cross-compilation tools and whatnot in the first place.

Thank you for reading.
<div align="right">
<img width="200" height="150" alt="love" src="https://github.com/user-attachments/assets/ae9978c5-d18c-4472-98cc-5401e69c7e5e" />
</div>


## Formal Acknowledgements

RubyNDS is built on the work of many open-source projects:

- [mruby](https://github.com/mruby/mruby) and its contributors for the embedded Ruby runtime.
- [devkitPro](https://github.com/devkitPro) and its contributors for the toolchain and DS development ecosystem, including [libnds](https://github.com/devkitPro/libnds), [DSWifi](https://github.com/devkitPro/dswifi), [Maxmod](https://github.com/devkitPro/maxmod), [Calico](https://github.com/devkitPro/calico), and [libfat](https://github.com/devkitPro/libfat).
- Ariya Hidayat for [FastLZ](https://github.com/ariya/FastLZ), used by R15V video.
- Thomas Pornin for [BearSSL](https://bearssl.org/), used for on-device TLS and HTTPS.
- Larry Bank / BitBank Software for [JPEGDEC](https://github.com/bitbank2/JPEGDEC), used for JPEG and MJPEG decoding.
- PacketVideo for the [OpenCORE MP3 decoder](https://android.googlesource.com/platform/frameworks/av/+/ee17317c6362f54bd311ec359b5c3518137fae9f/media/libstagefright/codecs/mp3dec/), used for MP3 decoding.

All third-party components remain the property of their respective authors and are distributed under their respective licenses.

## License

RubyNDS is available under the [MIT License](./LICENSE).

You don't have to, but if you use RubyNDS for anything, please let me know! I'd love to see. 🙂
