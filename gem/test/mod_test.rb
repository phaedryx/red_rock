# frozen_string_literal: true

require "test_helper"

class ModTest < Minitest::Test
  def teardown = remove_fixture_constants

  def remove_fixture_constants
    %i[HelloGem Mod RubyShard].each { |c| Object.send(:remove_const, c) if Object.const_defined?(c, false) }
  end

  def test_manifest
    hello_gem
    expected = {
      "mod_id" => "hello_gem",
      "version" => "0.1.0",
      "display_name" => "Hello Gem",
      "license" => "All Rights Reserved",
      "items" => [
        { "id" => "ruby_shard", "texture" => "ruby_shard.png", "stack_size" => 16, "display_name" => "Ruby Shard" }
      ]
    }
    assert_equal expected, HelloGem::Mod.manifest
  end

  def test_overridden_mod_metadata
    hello_gem do
      version "1.2.3"
      display_name "Hello!"
      license "MIT"
    end
    manifest = HelloGem::Mod.manifest
    assert_equal ["1.2.3", "Hello!", "MIT"], manifest.values_at("version", "display_name", "license")
  end

  def test_find
    hello_gem
    assert_same HelloGem::Mod, Gemcrafter::Mod.find("hello_gem")
  end

  def test_find_unknown
    err = assert_raises(Gemcrafter::DefinitionError) { Gemcrafter::Mod.find("nope") }
    assert_equal "No Gemcrafter::Mod with id nope was defined", err.message
  end

  def test_reload_replaces_registry_entry
    source = <<~RUBY
      module HelloGem
        class Mod
          include Gemcrafter::Mod

          id "hello_gem"
        end
      end
    RUBY
    TOPLEVEL_BINDING.eval(source)
    size = Gemcrafter::Mod.all.size
    TOPLEVEL_BINDING.eval(source)
    assert_equal size, Gemcrafter::Mod.all.size
  end

  def test_invalid_mod_id
    %w[Hello-Gem x HELLO].each do |bad|
      hello_gem { id bad }
      err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
      assert_equal %(mod id "#{bad}" must match [a-z][a-z0-9_]{1,63}), err.message
    end
  end

  def test_top_level_mod
    Object.const_set(:Mod, Class.new).include(Gemcrafter::Mod)
    ::Mod.id "hello_gem"
    err = assert_raises(Gemcrafter::DefinitionError) { ::Mod.manifest }
    assert_equal "`Mod` must be inside a module named after the mod (e.g. `module HelloGem`)", err.message
  end

  def test_missing_id
    hello_gem { @id = nil }
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal '`HelloGem::Mod` needs an id (id "hello_gem")', err.message
  end

  def test_non_content_class
    hello_gem
    HelloGem.const_set(:Thing, Class.new)
    HelloGem::Mod.contents HelloGem::Thing
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal "`HelloGem::Thing` is not Gemcrafter content (include Gemcrafter::Item)", err.message
  end

  def test_top_level_content_class
    hello_gem
    Object.const_set(:RubyShard, item_class { texture "ruby_shard.png" })
    HelloGem::Mod.contents ::RubyShard
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal "`RubyShard` must be inside `module HelloGem`", err.message
  end

  def test_item_without_texture
    hello_gem
    HelloGem::RubyShard.instance_variable_set(:@texture, nil)
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal '`HelloGem::RubyShard` needs a texture (texture "ruby_shard.png")', err.message
  end

  def test_symbol_item_id_is_accepted
    hello_gem
    HelloGem::RubyShard.id :shard
    assert_equal "shard", HelloGem::Mod.manifest["items"].first["id"]
  end

  def test_invalid_item_id
    [["Ruby Shard", '"Ruby Shard"'], ["RubyShard", '"RubyShard"'], [42, "42"]].each do |bad, shown|
      hello_gem
      HelloGem::RubyShard.id bad
      err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
      assert_equal "`HelloGem::RubyShard` id #{shown} must match [a-z0-9_]+", err.message
    end
  end

  def test_display_name_must_be_a_string
    hello_gem
    HelloGem::RubyShard.display_name 42
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal "`HelloGem::RubyShard` display_name must be a String (got 42)", err.message
  end

  def test_texture_must_be_a_png_file_name
    ["../lib/m.rb", "sub/ruby_shard.png", "ruby_shard.gif", :ruby_shard].each do |bad|
      hello_gem
      HelloGem::RubyShard.texture bad
      err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
      assert_equal "`HelloGem::RubyShard` texture #{bad.inspect} must be a .png file name in textures/", err.message
    end
  end

  def test_texture_casing_is_allowed
    hello_gem
    HelloGem::RubyShard.texture "Ruby_Shard.PNG"
    assert_equal "Ruby_Shard.PNG", HelloGem::Mod.manifest["items"].first["texture"]
  end

  def test_duplicate_ids
    hello_gem
    HelloGem.const_set(:Other, item_class { texture "other.png" })
    HelloGem::Other.id "ruby_shard"
    HelloGem::Mod.contents HelloGem::RubyShard, HelloGem::Other
    err = assert_raises(Gemcrafter::DefinitionError) { HelloGem::Mod.manifest }
    assert_equal "duplicate id hello_gem:ruby_shard (HelloGem::RubyShard, HelloGem::Other)", err.message
  end

  private

  def item_class(&) = Class.new { include Gemcrafter::Item }.tap { |c| c.class_eval(&) }

  # Defines HelloGem::RubyShard and HelloGem::Mod as real constants so that
  # validation sees the same names an author's file would produce.
  def hello_gem(&extra)
    remove_fixture_constants
    top = Object.const_set(:HelloGem, Module.new)
    shard = top.const_set(:RubyShard, item_class do
      texture "ruby_shard.png"
      stack_size 16
    end)
    mod = top.const_set(:Mod, Class.new)
    mod.include(Gemcrafter::Mod)
    mod.id "hello_gem"
    mod.contents shard
    mod.class_eval(&extra) if extra
    mod
  end
end
