# frozen_string_literal: true

require "test_helper"

class NamingTest < Minitest::Test
  def test_snake = assert_equal "ruby_shard", RedRock::Naming.snake("RubyShard")
  def test_snake_acronym = assert_equal "http_thing", RedRock::Naming.snake("HTTPThing")
  def test_title = assert_equal "Ruby Shard", RedRock::Naming.title("RubyShard")

  def test_mod_ids
    assert RedRock::Naming.valid_mod_id?("hello_gem")
    refute RedRock::Naming.valid_mod_id?("Hello-Gem")
    refute RedRock::Naming.valid_mod_id?("x")
  end

  def test_valid_path
    assert RedRock::Naming.valid_path?("ruby_shard")
    refute RedRock::Naming.valid_path?("Ruby_Shard")
  end

  def test_last_segment
    assert_equal "Item", RedRock::Naming.last_segment(RedRock::Item)
  end
end
