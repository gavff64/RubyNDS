HOST = "httpbin.org"
PORT = 80
PATH = "/post"
BODY = "message=Hello+from+RubyNDS"

Net.wifi
sock = Net.connect(HOST, PORT)

request_lines = [
  "POST #{PATH} HTTP/1.1",
  "Host: #{HOST}",
  "User-Agent: curl/8.0",
  "Content-Type: application/x-www-form-urlencoded",
  "Content-Length: #{BODY.bytesize}",
  "Connection: close"
]
request = request_lines.join("\r\n") + "\r\n\r\n" + BODY

offset = 0
while offset < request.bytesize
  offset += Net.send(sock, request.byteslice(offset, request.bytesize - offset))
end

response = ""
loop do
  chunk = Net.recv(sock, 512)
  break if chunk == ""
  response << chunk
end
Net.close(sock)

header_end = response.index("\r\n\r\n")
raise "HTTP response ended before the headers were complete" unless header_end
response = response[(header_end + 4)..-1]
result = JSON.parse(response)

puts result["form"]["message"]
