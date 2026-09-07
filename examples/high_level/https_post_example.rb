body = "message=Hello+from+RubyNDS"
response = HTTPS.post("https://httpbin.org/post", body)
result = JSON.parse(response)

puts result["form"]["message"]
