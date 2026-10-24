# frozen_string_literal: true

require "test_helper"

module ItemFixtures
  class RubyShard
    include Gemcrafter::Item
  end

  class Overridden
    include Gemcrafter::Item

    texture "shard.png"
    stack_size 16
    id "shard"
    display_name "Shiny"
  end
end

class ItemTest < Minitest::Test
  def test_defaults
    assert_equal "ruby_shard", ItemFixtures::RubyShard.id
    assert_equal "Ruby Shard", ItemFixtures::RubyShard.display_name
    assert_equal 64, ItemFixtures::RubyShard.stack_size
    assert_nil ItemFixtures::RubyShard.texture
    assert_equal :item, ItemFixtures::RubyShard.gemcrafter_kind
  end

  def test_overrides
    assert_equal "shard.png", ItemFixtures::Overridden.texture
    assert_equal 16, ItemFixtures::Overridden.stack_size
    assert_equal "shard", ItemFixtures::Overridden.id
    assert_equal "Shiny", ItemFixtures::Overridden.display_name
  end

  def test_stack_size_out_of_range
    err = assert_raises(Gemcrafter::DefinitionError) do
      Class.new do
        include Gemcrafter::Item

        stack_size 100
      end
    end
    assert_match "stack_size must be 1..99", err.message
  end

  def test_stack_size_zero
    assert_raises(Gemcrafter::DefinitionError) do
      Class.new do
        include Gemcrafter::Item

        stack_size 0
      end
    end
  end
end
