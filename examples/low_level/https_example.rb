HOST = "api.github.com"
PORT = 443
PATH = "/repos/mruby/mruby"

puts "Fetching mruby from GitHub..."
TLS.seed("fat:/tls.seed")
Net.wifi
sock = Net.connect(HOST, PORT)

begin
  opened = TLS.open(sock, HOST)

  request_lines = [
    "GET #{PATH} HTTP/1.0",
    "Host: #{HOST}",
    "User-Agent: RubyNDS",
    "Accept-Encoding: identity",
    "Connection: close"
  ]
  request = request_lines.join("\r\n") + "\r\n\r\n"

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
repository = JSON.parse(response)

if repository["message"]
  puts repository["message"]
else
  puts "Repository: #{repository["full_name"]}"
  puts "Stars: #{repository["stargazers_count"]}"
  puts "Forks: #{repository["forks_count"]}"
end
