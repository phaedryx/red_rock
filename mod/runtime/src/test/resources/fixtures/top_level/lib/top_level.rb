# frozen_string_literal: true

class RubyShard
  include RedRock::Item

  texture "ruby_shard.png"
end

module TopLevel
  class Mod
    include RedRock::Mod

    id "top_level"
    contents RubyShard
  end
end
