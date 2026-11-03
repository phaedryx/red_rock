# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "tmpdir"

class EntryFileTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    @path = File.join(@tmp, "boom_cookies.rb")
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_adds_after_last_require
    write <<~RUBY
      module BoomCookies
        require_relative "boom_cookies/items/ruby_shard"
        require_relative "boom_cookies/items/tnt"

        class Mod
          contents RubyShard, Tnt
        end
      end
    RUBY
    assert add_item
    assert_equal <<~RUBY, File.read(@path)
      module BoomCookies
        require_relative "boom_cookies/items/ruby_shard"
        require_relative "boom_cookies/items/tnt"
        require_relative "boom_cookies/items/exploding_cookie"

        class Mod
          contents RubyShard, Tnt, ExplodingCookie
        end
      end
    RUBY
  end

  # A require that runs after `contents` can't be the anchor: the new class
  # wouldn't exist yet when contents names it.
  def test_ignores_requires_below_contents
    write <<~RUBY
      module BoomCookies
        require_relative "boom_cookies/items/ruby_shard"

        class Mod
          contents RubyShard
          require_relative "boom_cookies/thing"
        end
      end
      require_relative "boom_cookies/after"
    RUBY
    assert add_item
    assert_equal <<~RUBY, File.read(@path)
      module BoomCookies
        require_relative "boom_cookies/items/ruby_shard"
        require_relative "boom_cookies/items/exploding_cookie"

        class Mod
          contents RubyShard, ExplodingCookie
          require_relative "boom_cookies/thing"
        end
      end
      require_relative "boom_cookies/after"
    RUBY
  end

  def test_contents_above_module_is_left_alone
    write <<~RUBY
      contents RubyShard
      module BoomCookies
      end
    RUBY
    refute_changed
  end

  def test_reads_utf8_under_any_locale
    write standard_entry.sub("module BoomCookies", "# épée\nmodule BoomCookies")
    with_external_encoding(Encoding::US_ASCII) { assert add_item }
    assert_includes File.read(@path, encoding: "UTF-8"), "# épée\n"
    assert_includes File.read(@path), "contents RubyShard, ExplodingCookie"
  end

  def test_adds_after_module_when_no_requires
    write <<~RUBY
      module BoomCookies
        class Mod
          contents
        end
      end
    RUBY
    assert add_item
    assert_equal <<~RUBY, File.read(@path)
      module BoomCookies
        require_relative "boom_cookies/items/exploding_cookie"
        class Mod
          contents ExplodingCookie
        end
      end
    RUBY
  end

  def test_appends_to_contents
    write standard_entry
    assert add_item
    assert_includes File.read(@path), "    contents RubyShard, ExplodingCookie\n"
  end

  def test_fills_empty_contents
    write standard_entry.sub("contents RubyShard", "contents")
    assert add_item
    assert_includes File.read(@path), "    contents ExplodingCookie\n"
  end

  def test_is_idempotent
    write standard_entry
    assert add_item
    once = File.read(@path)
    assert add_item
    assert_equal once, File.read(@path)
  end

  def test_multiline_contents_is_left_alone
    write standard_entry.sub("contents RubyShard", "contents RubyShard,\n             Other")
    refute_changed
  end

  def test_continued_contents_is_left_alone
    write standard_entry.sub("contents RubyShard", "contents RubyShard \\\n             Other")
    refute_changed
  end

  def test_two_contents_lines_are_left_alone
    write standard_entry.sub("contents RubyShard", "contents RubyShard\n    contents Other")
    refute_changed
  end

  def test_missing_contents_is_left_alone
    write standard_entry.sub("contents RubyShard", "")
    refute_changed
  end

  def test_contents_with_a_comment_is_left_alone
    write standard_entry.sub("contents RubyShard", "contents RubyShard # my items")
    refute_changed
  end

  def test_contents_with_parentheses_is_left_alone
    write standard_entry.sub("contents RubyShard", "contents(RubyShard)")
    refute_changed
  end

  def test_missing_module_and_requires_is_left_alone
    write "class Mod\n  contents RubyShard\nend\n"
    refute_changed
  end

  private

  def write(src) = File.write(@path, src)

  def add_item
    RedRock::CLI::EntryFile.new(@path).add_item(require_path: "boom_cookies/items/exploding_cookie",
                                                const: "ExplodingCookie")
  end

  def refute_changed
    before = File.binread(@path)
    refute add_item
    assert_equal before, File.binread(@path)
  end

  def standard_entry
    <<~RUBY
      module BoomCookies
        require_relative "boom_cookies/items/ruby_shard"

        class Mod
          include RedRock::Mod

          id "boom_cookies"
          contents RubyShard
        end
      end
    RUBY
  end
end
