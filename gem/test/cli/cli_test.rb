# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
  end

  def teardown
    Object.send(:remove_const, :BoomCookies) if Object.const_defined?(:BoomCookies, false)
    FileUtils.rm_rf(@tmp)
  end

  def test_new_prints_made_lines_and_next
    out, _err, status = run_cli("new", "hello_gem")
    assert_equal 0, status
    assert_equal <<~OUT, out
      Made hello_gem/bin/red_rock
      Made hello_gem/lib/hello_gem.rb
      Made hello_gem/lib/hello_gem/items/ruby_shard.rb
      Made hello_gem/textures/ruby_shard.png
      Made hello_gem/test/test_helper.rb
      Made hello_gem/test/items/ruby_shard_test.rb
      Made hello_gem/README.md
      Made hello_gem/.gitignore

      Next: cd hello_gem && bin/red_rock build
    OUT
  end

  def test_new_error_is_one_line
    FileUtils.mkdir_p(File.join(@tmp, "hello_gem"))
    _out, err, status = run_cli("new", "hello_gem")
    assert_equal 1, status
    assert_equal "error: hello_gem/ already exists\n", err
  end

  def test_new_without_a_mod_id_prints_usage
    _out, err, status = run_cli("new")
    assert_equal 1, status
    assert_equal "error: usage: red_rock new MOD_ID\n", err
    assert_empty Dir.children(@tmp)
  end

  def test_unknown_command_prints_usage
    _out, err, status = run_cli("frobnicate")
    assert_equal 1, status
    assert_equal <<~USAGE, err
      usage: red_rock new MOD_ID
             red_rock generate item NAME [DIR]
             red_rock build [DIR]
             red_rock test [DIR]
    USAGE
  end

  def test_generate_prints_made_and_next
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    out, err, status = run_cli("generate", "item", "exploding_cookie", dir: File.join(@tmp, "boom_cookies/lib"))
    assert_equal 0, status, err
    assert_equal <<~OUT, out
      Made lib/boom_cookies/items/exploding_cookie.rb
      Made textures/exploding_cookie.png (a placeholder; draw your own 16x16 PNG over it)
      Made test/items/exploding_cookie_test.rb
      Added ExplodingCookie to lib/boom_cookies.rb

      Next: bin/red_rock build
    OUT
  end

  def test_generate_says_when_a_texture_is_kept
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    project = File.join(@tmp, "boom_cookies")
    FileUtils.cp(File.join(project, "textures/ruby_shard.png"), File.join(project, "textures/exploding_cookie.png"))
    out, = run_cli("generate", "item", "exploding_cookie", project)
    assert_includes out, "Made lib/boom_cookies/items/exploding_cookie.rb\n" \
                         "Kept textures/exploding_cookie.png (you already drew one)\n" \
                         "Made test/items/exploding_cookie_test.rb\n"
  end

  def test_g_is_an_alias
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    out, err, status = run_cli("g", "item", "ExplodingCookie", "boom_cookies")
    assert_equal 0, status, err
    assert_includes out, "Added ExplodingCookie to lib/boom_cookies.rb\n"
  end

  def test_generate_name_with_a_space
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    project = File.join(@tmp, "boom_cookies")
    [%w[exploding cookie], %w[big exploding cookie]].each do |words|
      out, err, status = run_cli("generate", "item", *words, dir: project)
      assert_equal 1, status
      assert_empty out
      assert_equal %(error: name "#{words.join(' ')}" can't have spaces; try "#{words.join('_')}"\n), err
    end
    assert_equal ["ruby_shard.rb"], Dir.children(File.join(project, "lib/boom_cookies/items"))
  end

  def test_generate_says_when_a_test_is_kept
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    project = File.join(@tmp, "boom_cookies")
    File.write(File.join(project, "test/items/exploding_cookie_test.rb"), "# mine\n")
    out, = run_cli("generate", "item", "exploding_cookie", dir: project)
    assert_includes out, "Kept test/items/exploding_cookie_test.rb (you already wrote one)\n"
  end

  # A path that isn't there is a mistyped folder, not the second word of a name.
  def test_generate_into_a_missing_folder
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    %w[../mymmod ./nope lib/nope].each do |dir|
      out, err, status = run_cli("generate", "item", "cake", dir, dir: File.join(@tmp, "boom_cookies"))
      assert_equal 1, status
      assert_empty out
      assert_equal "error: there's no folder #{dir}\n", err
    end
  end

  def test_build_from_a_subfolder
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    out, err, status = run_cli("build", dir: File.join(@tmp, "boom_cookies/lib"))
    assert_equal 0, status, err
    assert_match %r{/boom_cookies/pkg/boom_cookies-0\.1\.0\.jar$}, out
    refute File.exist?(File.join(@tmp, "boom_cookies/lib/pkg"))
  end

  def test_test_runs_in_process
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    rubylib = ENV.fetch("RUBYLIB", nil)
    ENV["RUBYLIB"] = File.expand_path("../../lib", __dir__)
    out, err, status = run_cli("test", dir: File.join(@tmp, "boom_cookies"))
    assert_equal 0, status, out + err
    assert_match(/2 runs, \d+ assertions, 0 failures, 0 errors/, out)
  ensure
    ENV["RUBYLIB"] = rubylib
  end

  def test_generate_outside_a_project
    _out, err, status = run_cli("generate", "item", "exploding_cookie")
    assert_equal 1, status
    assert err.start_with?("error: not inside a RedRock mod (no bin/red_rock found in or above "), err
    assert_equal 1, err.lines.size
  end

  def test_generate_with_unedited_entry_exits_zero
    RedRock::CLI::New.new(mod_id: "boom_cookies", parent_dir: @tmp).call
    entry = File.join(@tmp, "boom_cookies/lib/boom_cookies.rb")
    File.write(entry, File.read(entry).sub("contents RubyShard", "contents RubyShard,\n             Other"))
    out, err, status = run_cli("generate", "item", "exploding_cookie", dir: File.join(@tmp, "boom_cookies"))
    assert_equal 0, status, err
    assert_equal <<~OUT, out
      Made lib/boom_cookies/items/exploding_cookie.rb
      Made textures/exploding_cookie.png (a placeholder; draw your own 16x16 PNG over it)
      Made test/items/exploding_cookie_test.rb
      Couldn't find where to add ExplodingCookie in lib/boom_cookies.rb. Add these two lines yourself:
        require_relative "boom_cookies/items/exploding_cookie"   (inside module BoomCookies, near the top)
        ExplodingCookie                                          (at the end of the contents list, after a comma)

      Next: add those two lines, then bin/red_rock build
    OUT
  end

  private

  def run_cli(*argv, dir: @tmp)
    out = StringIO.new
    err = StringIO.new
    status = Dir.chdir(dir) { RedRock::CLI.start(argv, out: out, err: err) }
    [out.string, err.string, status]
  end
end
