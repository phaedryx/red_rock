# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "tmpdir"

class ProjectTest < Minitest::Test
  def setup
    @tmp = File.realpath(Dir.mktmpdir)
    @root = File.join(@tmp, "hello_gem")
    FileUtils.mkdir_p(File.join(@root, "bin"))
    FileUtils.mkdir_p(File.join(@root, "lib/hello_gem/items"))
    File.write(File.join(@root, "bin/red_rock"), "")
    File.write(File.join(@root, "lib/hello_gem.rb"), "module HelloGem\nend\n")
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_find_from_root
    assert_equal @root, RedRock::CLI::Project.find(@root).root
  end

  def test_find_from_nested_dir
    assert_equal @root, RedRock::CLI::Project.find(File.join(@root, "lib/hello_gem/items")).root
  end

  def test_find_fails_for_a_missing_folder
    missing = File.join(@root, "lib/nope")
    err = assert_raises(RedRock::CLI::ProjectError) { RedRock::CLI::Project.find(missing) }
    assert_equal "there's no folder #{missing}", err.message
  end

  def test_find_fails_outside_a_project
    err = assert_raises(RedRock::CLI::ProjectError) { RedRock::CLI::Project.find(@tmp) }
    assert_equal "not inside a RedRock mod (no bin/red_rock found in or above #{@tmp})", err.message
  end

  def test_path = assert_equal(File.join(@root, "lib", "x.rb"), project.path("lib", "x.rb"))
  def test_entry_file = assert_equal("lib/hello_gem.rb", project.entry_file)
  def test_mod_id = assert_equal("hello_gem", project.mod_id)
  def test_module_name = assert_equal("HelloGem", project.module_name)

  def test_module_name_reads_utf8_under_any_locale
    File.write(File.join(@root, "lib/hello_gem.rb"), "# épée\nmodule HelloGem\nend\n")
    with_external_encoding(Encoding::US_ASCII) { assert_equal "HelloGem", project.module_name }
  end

  def test_module_name_missing_is_nil
    File.write(File.join(@root, "lib/hello_gem.rb"), "# nothing here\n")
    assert_nil project.module_name
  end

  def test_entry_file_errors_are_project_errors
    File.write(File.join(@root, "lib/other.rb"), "")
    err = assert_raises(RedRock::CLI::ProjectError) { project.entry_file }
    assert_equal "lib/ must contain exactly one entry file (found: hello_gem.rb, other.rb)", err.message
    assert_kind_of RedRock::CLI::Error, err
  end

  private

  def project = RedRock::CLI::Project.new(root: @root)
end
