# frozen_string_literal: true

module SecondMod
  class Pebble
    include RedRock::Item

    texture "pebble.png"
  end

  class Mod
    include RedRock::Mod

    id "second_mod"
    contents Pebble
  end
end
