HOST = "httpbin.org"
PORT = 443
PATH = "/post"
BODY = "message=Hello+from+RubyNDS"

TLS.seed("fat:/tls.seed")
Net.wifi
sock = Net.connect(HOST, PORT)

begin
  opened = TLS.open(sock, HOST)

  request_lines = [
    "POST #{PATH} HTTP/1.0",
    "Host: #{HOST}",
    "User-Agent: curl/8.0",
    "Accept-Encoding: identity",
    "Content-Type: application/x-www-form-urlencoded",
    "Content-Length: #{BODY.bytesize}",
    "Connection: close"
  ]
  request = request_lines.join("\r\n") + "\r\n\r\n" + BODY

  offset = 0
  while offset < request.bytesize
    offset += TLS.send(request.byteslice(offset, request.bytesize - offset))
  end

  response = ""
  loop do
    chunk = TLS.recv(512)
    break if chunk == ""
    response << chunk
  end
ensure
  TLS.close if opened
  Net.close(sock)
end

header_end = response.index("\r\n\r\n")
raise "HTTPS response ended before the headers were complete" unless header_end
response = response[(header_end + 4)..-1]
result = JSON.parse(response)

puts result["form"]["message"]
