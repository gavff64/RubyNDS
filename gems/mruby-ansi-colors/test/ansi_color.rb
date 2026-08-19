assert('String.color_codes') do
  assert_equal Hash, "".color_codes.class
end

assert('String.colors') do
  assert_equal Array, "".colors.class
end

assert('String.mode_codes') do
  assert_equal Hash, "".mode_codes.class
end

assert('String.modes') do
  assert_equal Array, "".modes.class
end

assert('String#set_color') do
  assert_equal "\e[0;31;49mBasquiat\e[0m", "Basquiat".set_color(:red)
  assert_equal "\e[0;31;49mBasquiat\e[0m", "Basquiat".color(:red)
end

assert('String#color_codes') do
  cc = "".color_codes.keys
  assert_true cc.include? :blue
end

assert('String#mode_codes') do
  mc = "".mode_codes.keys
  assert_true mc.include? :bold
end

assert('String#colors') do
  colorz = "".colors
  assert_true colorz.include? :blue
end

assert('String#mode_codes') do
  mc = "".mode_codes
  assert_true mc.include? :bold
end

assert('Print string in every color') do
  "".colors.each { |c| print ".".send(c)}
end
