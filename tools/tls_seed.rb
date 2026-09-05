abort "Usage: ruby tools/tls_seed.rb /path/to/sd/tls.seed" unless ARGV.length == 1

File.open(ARGV[0], File::WRONLY | File::CREAT | File::EXCL, 0600) do |file|
  file.binmode
  file.write(Random.urandom(32))
end

puts "Created a private TLS seed. Keep it on writable storage, outside the ROM."
