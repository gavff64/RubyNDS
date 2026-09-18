require "fileutils"

TOOLS = %w[make git curl tar sha256sum cc ffmpeg ffprobe]

def command?(command)
  ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |path|
    File.executable?(File.join(path, command))
  end
end

desc "Set up RubyNDS"
task :setup do
  devkitpro = ENV.fetch("DEVKITPRO", "/opt/devkitpro")
  devkitarm = ENV.fetch("DEVKITARM", "#{devkitpro}/devkitARM")
  missing = TOOLS.reject { |command| command?(command) }

  devkit_files = [
    "#{devkitarm}/bin/arm-none-eabi-gcc",
    "#{devkitpro}/libnds/include/nds.h",
    "#{devkitpro}/calico/include/calico.h",
    "#{devkitpro}/tools/bin/ndstool"
  ]
  missing << "devkitPro with nds-dev" unless devkit_files.all? { |path| File.exist?(path) }

  unless missing.empty?
    puts "Missing requirements:"
    missing.each { |requirement| puts "  #{requirement}" }
    abort "Install the missing requirements and run rake setup again."
  end

  if File.exist?("vendor/mruby")
    abort "vendor/mruby is not a valid mruby checkout." unless File.exist?("vendor/mruby/Rakefile")
  else
    FileUtils.mkdir_p("vendor")
    sh "git", "clone", "--depth", "1", "--branch", "4.0.0",
      "https://github.com/mruby/mruby.git", "vendor/mruby"
  end

  puts "RubyNDS is ready."
end
