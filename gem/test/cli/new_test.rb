# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "tmpdir"

class NewTest < Minitest::Test
  GEM_ROOT = File.expand_path("../..", __dir__)

  def setup
    @tmp = Dir.mktmpdir
  end

  def teardown
    Object.send(:remove_const, :HelloGem) if Object.const_defined?(:HelloGem, false)
    FileUtils.rm_rf(@tmp)
  end

  def test_writes_the_layout
    assert_equal %w[hello_gem/bin/red_rock hello_gem/lib/hello_gem.rb hello_gem/lib/hello_gem/items/ruby_shard.rb
                    hello_gem/textures/ruby_shard.png hello_gem/test/test_helper.rb
                    hello_gem/test/items/ruby_shard_test.rb hello_gem/README.md hello_gem/.gitignore],
                 scaffold
    assert File.executable?(project("bin/red_rock"))
  end

  def test_entry_file_wires_the_sample_item
    scaffold
    entry = File.read(project("lib/hello_gem.rb"))
    assert_includes entry, "module HelloGem"
    assert_includes entry, %(require_relative "hello_gem/items/ruby_shard")
    assert_includes entry, %(id "hello_gem")
    assert_includes entry, "contents RubyShard"
  end

  def test_item_file
    scaffold
    item = File.read(project("lib/hello_gem/items/ruby_shard.rb"))
    assert_includes item, "class RubyShard"
    assert_includes item, "include RedRock::Item"
    assert_includes item, %(texture "ruby_shard.png")
    assert_includes item, "stack_size 64"
  end

  def test_scaffold_builds
    scaffold
    jar = RedRock::CLI::Build.new(project_dir: project, out_dir: File.join(@tmp, "pkg")).call
    entries = Zip::File.open(jar) { |zip| zip.entries.map(&:name).reject { |n| n.end_with?("/") } }
    assert_equal %w[META-INF/MANIFEST.MF META-INF/neoforge.mods.toml red_rock/ruby/lib/hello_gem.rb
                    red_rock/ruby/lib/hello_gem/items/ruby_shard.rb red_rock/textures/ruby_shard.png].sort,
                 entries.sort
  end

  def test_refuses_existing_directory
    FileUtils.mkdir_p(project)
    File.write(project("mine.txt"), "keep me")
    err = assert_raises(RedRock::CLI::ProjectError) { scaffold }
    assert_equal "hello_gem/ already exists", err.message
    assert_equal ["mine.txt"], Dir.children(project)
    assert_equal "keep me", File.read(project("mine.txt"))
  end

  def test_rejects_mod_id_ruby_already_uses
    err = assert_raises(RedRock::CLI::ProjectError) { scaffold("data") }
    assert_equal %(mod id "data" is a name Ruby already uses; try "data_mod"), err.message
    err = assert_raises(RedRock::CLI::ProjectError) { scaffold("red_rock") }
    assert_equal %(mod id "red_rock" is a name Ruby already uses; try "red_rock_mod"), err.message
    assert_empty Dir.children(@tmp)
  end

  def test_rejects_invalid_mod_id
    err = assert_raises(RedRock::CLI::ProjectError) { scaffold("BoomCookies") }
    assert_equal %(mod id "BoomCookies" must start with a lowercase letter and use only lowercase letters, ) +
                 %(numbers and _ (2 to 64 of them; try "boom_cookies")), err.message
    err = assert_raises(RedRock::CLI::ProjectError) { scaffold("x") }
    assert_equal %(mod id "x" must start with a lowercase letter and use only lowercase letters, ) +
                 %(numbers and _ (2 to 64 of them)), err.message
    assert_empty Dir.children(@tmp)
  end

  def test_matches_the_committed_example
    scaffold
    example = File.expand_path("../examples/hello_gem", GEM_ROOT)
    assert_equal tree(example), tree(project)
    tree(project).each do |rel|
      assert_equal File.binread(File.join(example, rel)), File.binread(project(rel)), "#{rel} differs from the example"
    end
    assert File.executable?(File.join(example, "bin/red_rock"))
  end

  def test_gem_ships_templates
    files = Dir.chdir(GEM_ROOT) { Gem::Specification.load("red_rock.gemspec").files }
    assert_includes files, "lib/red_rock/cli/templates/item.rb.erb"
    assert_includes files, "lib/red_rock/cli/templates/placeholder.png"
  end

  private

  def scaffold(mod_id = "hello_gem") = RedRock::CLI::New.new(mod_id: mod_id, parent_dir: @tmp).call
  def project(*parts) = File.join(@tmp, "hello_gem", *parts)

  # Relative file paths under dir, minus what its .gitignore lists (pkg/ after a build).
  def tree(dir)
    ignore_file = File.join(dir, ".gitignore")
    ignored = File.file?(ignore_file) ? File.readlines(ignore_file, chomp: true).reject(&:empty?) : []
    Dir.glob("**/*", File::FNM_DOTMATCH, base: dir)
       .reject { |rel| File.directory?(File.join(dir, rel)) || ignored.any? { |i| rel.start_with?(i) } }
       .sort
  end
end
