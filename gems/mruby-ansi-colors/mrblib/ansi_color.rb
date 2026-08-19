class String

  def color_codes
      {
        black: 30,
        light_black: 90,
        bg_black: 40,
        bg_light_black: 100,
        red: 31,
        light_red: 91,
        bg_red: 41,
        bg_light_red: 101,
        green: 32,
        light_green: 92,
        bg_green: 42,
        bg_light_green: 102,
        yellow: 33,
        light_yellow: 93,
        bg_yellow: 43,
        bg_light_yellow: 103,
        blue: 34,
        light_blue: 94,
        bg_blue: 44,
        bg_light_blue: 104,
        magenta: 35,
        light_magenta: 95,
        bg_magenta: 45,
        bg_light_magenta: 105,
        cyan: 36,
        light_cyan: 96,
        bg_cyan: 46,
        bg_light_cyan: 106,
        white: 37,
        light_white: 97,
        bg_white: 47,
        bg_light_white: 107,
        default: 39,
        bg_default: 49
      }
    end

    def colors
      color_codes.keys
    end

    def mode_codes
      {
        default: 0, # Turn off all attributes
        bold: 1, # Set bold mode
        italic: 3, # Set italic mode
        underline: 4, # Set underline mode
        blink: 5, # Set blink mode
        swap: 7, # Exchange foreground and background colors
        hide: 8 # Hide text (foreground color would be the same as background)
      }
    end

    def modes
      mode_codes.keys
    end

    def set_color(fg_color, bg_color = :bg_default, mode = :default)
      fg_code = color_codes[fg_color] || "38;5;#{fg_color}"
      "\033[#{fg_code};1m#{self}\033[39m"
    end

    alias_method(:color, :set_color)

    "".colors.each do |c|
      define_method(c) { self.color(c) }
    end
end
