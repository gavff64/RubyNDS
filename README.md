# RubyNDS
Write DS Homebrew apps in pure Ruby!

<img width="235" height="360" alt="video" src="https://github.com/user-attachments/assets/0fa1c674-4b7e-43a6-96b7-38bbc3ca556a" />

## What is this?
RubyNDS is an SDK which includes an embedded mruby runtime, thin bindings to native DS libraries, build tools and examples. There is both a **low-level Ruby API** for verbosity, and an idiomatic **high-level Ruby API** for developer happiness. The focus is DSi development, but inheriently RubyNDS applications will run on 3DS/2DS/DS as well.

<div align="center">
  
| DS hardware -> Thin C bindings -> Low-level Ruby API -> High-level Ruby API |
| --- |

</div>

### Example:

These 3 scripts all do the same thing. 
- Connect to wifi
- Fetch some data
- libnds displays it to the on-screen DS console (unparsed)

Here's the ***scary*** C example:

```c
// This specific example is generated. Please read "What's the purpose?" in this README to understand why.
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
puts HTTP.get("wttr.in/NewYork?format=3")
```

> See more in [examples](./examples/)

## What's the purpose?
I wanted to write homebrew apps for DSi using a favorable language. And since I don't really know C, I wanted to avoid having an LLM create an entire framework for me. Not only is that pretty lame, but I learn nothing in the process as the majority of the hard work is done.

So the goal is to have the C side of this project be as thin as possible. Not only does this make the inner workings more legible for me, but it also ensures all of the API logic is pure self-written Ruby. 

This is only possible thanks to all of the DS native libraries and SDK components available like [libnds](https://github.com/devkitPro/libnds), [DSWiFi](https://github.com/devkitPro/dswifi), [Maxmod](https://github.com/devkitPro/maxmod). And obviously [devkitPro](https://github.com/devkitPro) for even providing the cross-compilation tools and whatnot in the first place.

