# frozen_string_literal: true

class RubyShard
  include Gemcrafter::Item

  texture "ruby_shard.png"
end

module TopLevel
  class Mod
    include Gemcrafter::Mod

    id "top_level"
    contents RubyShard
  end
end
