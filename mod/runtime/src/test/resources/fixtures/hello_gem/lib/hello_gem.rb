# frozen_string_literal: true

module HelloGem
  class RubyShard
    include RedRock::Item

    texture "ruby_shard.png"
    stack_size 16
  end

  class Mod
    include RedRock::Mod

    id "hello_gem"
    contents RubyShard
  end
end
