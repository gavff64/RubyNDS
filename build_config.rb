# Requires mruby 4.0.0 at /vendor/mruby

devkitpro = ENV.fetch("DEVKITPRO", "/opt/devkitpro")
devkitarm = ENV.fetch("DEVKITARM", "#{devkitpro}/devkitARM")

MRuby::Build.new("host") do |conf|
  toolchain :gcc
  conf.build_mrbc_exec
  conf.disable_libmruby
end

MRuby::CrossBuild.new("nds") do |conf|
  toolchain :gcc

  conf.cc do |cc|
    cc.command = "#{devkitarm}/bin/arm-none-eabi-gcc"
    cc.flags << %w[
      -mthumb -mthumb-interwork -march=armv5te -mtune=arm946e-s
      -O2 -ffunction-sections -fdata-sections
    ]
    cc.defines << %w[MRB_INT32 MRB_USE_FLOAT32]
    cc.compile_options = %(%{flags} -o "%{outfile}" -c "%{infile}")
  end

  conf.archiver.command = "#{devkitarm}/bin/arm-none-eabi-ar"
  conf.host_target = "arm-none-eabi"
  conf.bins = []
  conf.build_mrbtest_lib_only
  conf.disable_cxx_exception

  conf.gembox "stdlib"
  conf.gem "gems/mruby-json"
  conf.gem "gems/mruby-onig-regexp"
  conf.gem "gems/mruby-ansi-colors"
  conf.gem "gems/mruby-puts"
  conf.gem "gems/rubynds-http"
  conf.gem "gems/rubynds-audio"
  conf.gem "gems/rubynds-input"
end
