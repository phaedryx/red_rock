# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "open3"
require "tmpdir"

class TestRunnerTest < Minitest::Test
  GEM_ROOT = File.expand_path("../..", __dir__)
  EXE = File.join(GEM_ROOT, "exe/red_rock")

  def setup
    @tmp = Dir.mktmpdir
    RedRock::CLI::New.new(mod_id: "hello_gem", parent_dir: @tmp).call
    @project = File.join(@tmp, "hello_gem")
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_fresh_scaffold_passes
    out, err, status = run_tests
    assert_equal 0, status.exitstatus, out + err
    assert_match(/2 runs, \d+ assertions, 0 failures, 0 errors/, out)
  end

  def test_after_generate_item_passes
    project = RedRock::CLI::Project.new(root: @project)
    RedRock::CLI::Generate.new(project: project, kind: "item", name: "exploding_cookie").call
    out, err, status = run_tests
    assert_equal 0, status.exitstatus, out + err
    assert_match(/4 runs, \d+ assertions, 0 failures, 0 errors/, out)
  end

  def test_missing_texture_fails
    File.delete(File.join(@project, "textures/ruby_shard.png"))
    out, _err, status = run_tests
    assert_equal 1, status.exitstatus
    assert_includes out, "put a 16x16 PNG at textures/ruby_shard.png"
  end

  def test_no_tests_yet
    FileUtils.rm_rf(File.join(@project, "test"))
    out, err, status = run_tests
    assert_equal 0, status.exitstatus, err
    assert_equal "no tests yet (bin/red_rock generate item <name> makes one)\n", out
  end

  def test_runs_from_the_projects_binstub
    out, err, status = Open3.capture3({ "RUBYLIB" => File.join(GEM_ROOT, "lib") },
                                      RbConfig.ruby, "bin/red_rock", "test", chdir: @project)
    assert_equal 0, status.exitstatus, out + err
    assert_match(/2 runs, \d+ assertions, 0 failures, 0 errors/, out)
  end

  def test_minitest_is_a_runtime_dependency
    spec = Dir.chdir(GEM_ROOT) { Gem::Specification.load("red_rock.gemspec") }
    assert_equal %w[minitest rubyzip], spec.runtime_dependencies.map(&:name).sort
  end

  private

  # RUBYLIB points the scaffold's `require "red_rock"` at this checkout.
  def run_tests
    Open3.capture3({ "RUBYLIB" => File.join(GEM_ROOT, "lib") }, RbConfig.ruby, EXE, "test", @project)
  end
end
