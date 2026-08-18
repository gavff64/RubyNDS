def puts(*args)
  args.each do |arg|
    print(arg.to_s + "\n")
  end
end

Net.wifi
HOST = "wttr.in"
PORT = 80
PATH = "/NewYork?format=3"

sock = Net.connect(HOST, PORT)

request_lines = [
  "GET #{PATH} HTTP/1.1",
  "Host: #{HOST}",
  "User-Agent: curl/8.0",
  "Connection: close"
]
request = request_lines.join("\r\n") + "\r\n\r\n"

offset = 0
while offset < request.bytesize
  written = Net.send(sock, request.byteslice(offset, request.bytesize - offset))
  offset += written
end

response = ""
loop do
  chunk = Net.recv(sock, 512)
  break if chunk == ""
  response << chunk
end
Net.close(sock)

header_end = response.index("\r\n\r\n")
response = response[header_end..-1]

if response.bytesize == 0
  puts("Connected, but nothing was returned.")
else
  puts("Connected! Got #{response.bytesize} bytes.")
  puts("")
  puts("Temperature in New York is #{response[/\d+/]} degrees Fahrenheit.")
end
