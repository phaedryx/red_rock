# frozen_string_literal: true

require "test_helper"

# Run all the tests with:  bin/red_rock test
class RubyShardTest < Minitest::Test
  def test_is_listed_in_the_mod
    assert_includes HelloGem::Mod.contents, HelloGem::RubyShard
  end

  def test_has_a_texture_file
    assert File.file?(File.expand_path("../../textures/#{HelloGem::RubyShard.texture}", __dir__)),
           "put a 16x16 PNG at textures/#{HelloGem::RubyShard.texture}"
  end
end
