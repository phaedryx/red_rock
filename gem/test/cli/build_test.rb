# frozen_string_literal: true

require "test_helper"
require "gemcrafter/cli"
require "fileutils"
require "open3"
require "tmpdir"

class BuildTest < Minitest::Test
  FIXTURE = File.expand_path("../fixtures/hello_gem", __dir__)
  EXE = File.expand_path("../../exe/gemcrafter", __dir__)

  def setup
    @tmp = Dir.mktmpdir
    @project = File.join(@tmp, "hello_gem")
    FileUtils.cp_r(FIXTURE, @project)
    @out = File.join(@tmp, "pkg")
  end

  def teardown
    Object.send(:remove_const, :HelloGem) if Object.const_defined?(:HelloGem, false)
    FileUtils.rm_rf(@tmp)
  end

  def test_build_writes_jar_layout
    jar = build
    assert_equal File.join(@out, "hello_gem-0.1.0.jar"), jar
    entries = Zip::File.open(jar) { |zip| zip.entries.map(&:name).reject { |n| n.end_with?("/") } }
    assert_equal %w[META-INF/MANIFEST.MF META-INF/neoforge.mods.toml gemcrafter/ruby/lib/hello_gem.rb
                    gemcrafter/textures/ruby_shard.png].sort, entries.sort
    assert(entries.none? { |n| n.end_with?(".json") })
  end

  def test_jar_contents
    jar = build
    Zip::File.open(jar) do |zip|
      assert_equal "Manifest-Version: 1.0\r\n\r\n", zip.read("META-INF/MANIFEST.MF")
      assert_includes zip.read("META-INF/neoforge.mods.toml"), %(entrypoint = "lib/hello_gem.rb")
      assert_equal File.binread(File.join(FIXTURE, "textures/ruby_shard.png")),
                   zip.read("gemcrafter/textures/ruby_shard.png")
    end
  end

  def test_nested_lib_files_are_included
    FileUtils.mkdir_p(File.join(@project, "lib/hello_gem"))
    File.write(File.join(@project, "lib/hello_gem/extra.rb"), "# frozen_string_literal: true\n")
    entries = Zip::File.open(build) { |zip| zip.entries.map(&:name) }
    assert_includes entries, "gemcrafter/ruby/lib/hello_gem/extra.rb"
  end

  def test_texture_copied_by_declared_name
    # Two renames, so this also works on case-insensitive filesystems.
    File.rename(File.join(@project, "textures/ruby_shard.png"), File.join(@project, "textures/tmp.png"))
    File.rename(File.join(@project, "textures/tmp.png"), File.join(@project, "textures/Ruby_Shard.PNG"))
    rewrite_entry { |src| src.sub('texture "ruby_shard.png"', 'texture "Ruby_Shard.PNG"') }
    entries = Zip::File.open(build) { |zip| zip.entries.map(&:name) }
    assert_includes entries, "gemcrafter/textures/Ruby_Shard.PNG"
    refute_includes entries, "gemcrafter/textures/ruby_shard.png"
  end

  def test_missing_texture_fails_build
    File.delete(File.join(@project, "textures/ruby_shard.png"))
    err = assert_raises(Gemcrafter::CLI::BuildError) { build }
    assert_equal "textures/ruby_shard.png not found (texture of HelloGem::RubyShard)", err.message
  end

  def test_two_entry_files_fail
    File.write(File.join(@project, "lib/other.rb"), "")
    err = assert_raises(Gemcrafter::CLI::BuildError) { build }
    assert_equal "lib/ must contain exactly one entry file (found: hello_gem.rb, other.rb)", err.message
  end

  def test_no_entry_file_fails
    File.delete(File.join(@project, "lib/hello_gem.rb"))
    err = assert_raises(Gemcrafter::CLI::BuildError) { build }
    assert_equal "lib/ must contain exactly one entry file (found: none)", err.message
  end

  def test_definition_error_propagates
    rewrite_entry { |src| src.sub('id "hello_gem"', 'id "Hello-Gem"') }
    assert_raises(Gemcrafter::DefinitionError) { build }
  end

  def test_cli_prints_jar_path
    out, err, status = Open3.capture3(RbConfig.ruby, EXE, "build", @project)
    assert status.success?, err
    assert_equal "#{File.join(@project, 'pkg', 'hello_gem-0.1.0.jar')}\n", out
  end

  def test_cli_error_has_no_backtrace
    rewrite_entry { |src| src.sub('id "hello_gem"', 'id "Hello-Gem"') }
    _out, err, status = Open3.capture3(RbConfig.ruby, EXE, "build", @project)
    assert_equal 1, status.exitstatus
    assert err.start_with?("error: "), err
    refute_match(/\.rb:\d/, err)
  end

  private

  def build = Gemcrafter::CLI::Build.new(project_dir: @project, out_dir: @out).call

  def rewrite_entry
    path = File.join(@project, "lib/hello_gem.rb")
    File.write(path, yield(File.read(path)))
  end
end
