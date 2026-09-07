response = HTTP.get("wttr.in/NewYork?format=3")

if response.bytesize == 0
  puts "Connected, but nothing was returned."
else
  puts "Connected! Got #{response.bytesize} bytes."
  puts ""
  puts "Temperature in New York is #{response[/\d+/]} degrees Fahrenheit."
end
