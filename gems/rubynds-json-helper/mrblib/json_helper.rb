module JSON
  def self.fs_parse(file)
    file = FS.open("nitro:/#{file}")
    json = ""

    loop do
      chunk = FS.read(file, 4096)
      break if chunk == ""
      json << chunk
    end

    FS.close(file)
    return JSON.parse(json)
  end
end
