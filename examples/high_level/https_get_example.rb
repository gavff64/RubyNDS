puts "Fetching mruby from GitHub..."
response = HTTPS.get("https://api.github.com/repos/mruby/mruby")
repository = JSON.parse(response)

if repository["message"]
  puts repository["message"]
else
  puts "Repository: #{repository["full_name"]}"
  puts "Stars: #{repository["stargazers_count"]}"
  puts "Forks: #{repository["forks_count"]}"
end
