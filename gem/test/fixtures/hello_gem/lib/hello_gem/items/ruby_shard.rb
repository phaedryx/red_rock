# frozen_string_literal: true

module HelloGem
  # An item is something you can hold in your hand.
  # In the game it's called hello_gem:ruby_shard.
  class RubyShard
    include RedRock::Item # this line makes it an item; leave it in

    # The picture for this item: a 16 by 16 pixel PNG in the textures/ folder.
    texture "ruby_shard.png"

    # The name players see. Delete this line and RedRock makes one
    # from the class name ("Ruby Shard").
    display_name "Ruby Shard"

    # How many fit in one stack. 1 to 99; 64 is normal.
    stack_size 64
  end
end
