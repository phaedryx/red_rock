# frozen_string_literal: true

module SecondMod
  class Pebble
    include Gemcrafter::Item

    texture "pebble.png"
  end

  class Mod
    include Gemcrafter::Mod

    id "second_mod"
    contents Pebble
  end
end
