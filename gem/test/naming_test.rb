# frozen_string_literal: true

require "test_helper"

class NamingTest < Minitest::Test
  def test_snake = assert_equal "ruby_shard", Gemcrafter::Naming.snake("RubyShard")
  def test_snake_acronym = assert_equal "http_thing", Gemcrafter::Naming.snake("HTTPThing")
  def test_title = assert_equal "Ruby Shard", Gemcrafter::Naming.title("RubyShard")

  def test_mod_ids
    assert Gemcrafter::Naming.valid_mod_id?("hello_gem")
    refute Gemcrafter::Naming.valid_mod_id?("Hello-Gem")
    refute Gemcrafter::Naming.valid_mod_id?("x")
  end

  def test_valid_path
    assert Gemcrafter::Naming.valid_path?("ruby_shard")
    refute Gemcrafter::Naming.valid_path?("Ruby_Shard")
  end

  def test_last_segment
    assert_equal "Item", Gemcrafter::Naming.last_segment(Gemcrafter::Item)
  end
end
