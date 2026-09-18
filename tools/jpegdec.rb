directory = ARGV.fetch(0)

%w[JPEGDEC.h jpeg.inl].each do |name|
  path = "#{directory}/src/#{name}"
  source = File.binread(path)
  source.gsub!(/#if defined\s*\(\s*__MACH__\s*\)/, "#if defined(__NDS__) || defined(__MACH__)")
  source.gsub!(/\(int\)\(int64_t\)(pPage->\w+)/, '(uintptr_t)\1 & 15')

  source.gsub!(/static const uint16_t (usGrayTo565|usRangeTable[RGB])\[\] = \{(.*?)\};/m) do
    table = Regexp.last_match(1)
    values = Regexp.last_match(2).gsub(/\/\/[^\n]*|0x[0-9a-f]+|\b\d+\b/i) do |number|
      next number if number.start_with?("//")
      pixel = Integer(number)
      pixel = (pixel >> 11) | ((pixel >> 6 & 31) << 5) | ((pixel & 31) << 10)
      pixel |= 0x8000 if table == "usGrayTo565" || table == "usRangeTableR"
      "0x%04x" % pixel
    end
    section = table == "usGrayTo565" ? "" : ' __attribute__((section(".itcm.rodata")))'
    "static const uint16_t #{table}[]#{section} = {#{values}};"
  end

  File.binwrite(path, source)
end

File.write("#{directory}/jpegdec.c", "#include \"jpeg.inl\"\n")
