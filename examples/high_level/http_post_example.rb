body = "message=Hello+from+RubyNDS"
response = HTTP.post("http://httpbin.org/post", body)
result = JSON.parse(response)

puts result["form"]["message"]
