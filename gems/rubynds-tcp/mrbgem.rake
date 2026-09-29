MRuby::Gem::Specification.new("rubynds-tcp") do |spec|
  spec.license = "MIT"
  spec.author  = "gavff"
  spec.summary = "Simple Ruby TCP sockets for RubyNDS"
  spec.add_dependency "mruby-string-ext", core: "mruby-string-ext"
end
