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

  def teardown = FileUtils.rm_rf(@tmp)

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

  private

  def run_cli(*argv, dir: @tmp)
    out = StringIO.new
    err = StringIO.new
    status = Dir.chdir(dir) { RedRock::CLI.start(argv, out: out, err: err) }
    [out.string, err.string, status]
  end
end
