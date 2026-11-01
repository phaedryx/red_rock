# frozen_string_literal: true

# Everything in your mod lives inside this module.
# In the game, HelloGem::RubyShard is called hello_gem:ruby_shard.
module HelloGem
  # Each thing you add gets its own file under lib/hello_gem/.
  # Run `bin/red_rock generate item <name>` to add one; it also adds the line here.
  require_relative "hello_gem/items/ruby_shard"

  class Mod
    include RedRock::Mod

    id "hello_gem"
    # version "0.1.0"
    # display_name "Hello Gem"
    # license "All Rights Reserved"

    # Only things listed here exist in the game.
    # The generator adds each new one; you can also type them in yourself.
    contents RubyShard
  end
end
