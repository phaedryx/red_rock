# frozen_string_literal: true

require "test_helper"
require "red_rock/cli"
require "fileutils"
require "tmpdir"

class GenerateTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir
    RedRock::CLI::New.new(mod_id: "hello_gem", parent_dir: @tmp).call
  end

  def teardown
    Object.send(:remove_const, :HelloGem) if Object.const_defined?(:HelloGem, false)
    FileUtils.rm_rf(@tmp)
  end

  def test_creates_item_files_and_registers
    result = generate
    assert_equal %w[lib/hello_gem/items/exploding_cookie.rb textures/exploding_cookie.png
                    test/items/exploding_cookie_test.rb], result.created
    assert_empty result.kept
    assert result.registered
    assert_equal "ExplodingCookie", result.const
    assert_equal "hello_gem/items/exploding_cookie", result.require_path

    entry = read("lib/hello_gem.rb")
    assert_includes entry, %(  require_relative "hello_gem/items/exploding_cookie"\n)
    assert_includes entry, "    contents RubyShard, ExplodingCookie\n"
    item = read("lib/hello_gem/items/exploding_cookie.rb")
    assert_includes item, "module HelloGem"
    assert_includes item, "class ExplodingCookie"
    assert_includes item, %(texture "exploding_cookie.png")
    assert_includes item, %(display_name "Exploding Cookie")
    assert_includes read("test/items/exploding_cookie_test.rb"), "class ExplodingCookieTest < Minitest::Test"
    assert_equal File.binread(RedRock::CLI::Templates.file("placeholder.png")),
                 File.binread(path("textures/exploding_cookie.png"))
  end

  def test_generated_project_builds
    generate
    jar = RedRock::CLI::Build.new(project_dir: path, out_dir: File.join(@tmp, "pkg")).call
    entries = Zip::File.open(jar) { |zip| zip.entries.map(&:name) }
    assert_includes entries, "red_rock/ruby/lib/hello_gem/items/exploding_cookie.rb"
    assert_includes entries, "red_rock/textures/exploding_cookie.png"
  end

  def test_accepts_either_spelling
    other = File.join(@tmp, "other")
    RedRock::CLI::New.new(mod_id: "hello_gem", parent_dir: other).call
    generate("ExplodingCookie")
    generate("exploding_cookie", root: File.join(other, "hello_gem"))
    assert_equal snapshot(path), snapshot(File.join(other, "hello_gem"))
  end

  def test_rejects_name_starting_with_digit
    err = assert_raises(RedRock::CLI::GenerateError) { generate("3d_glasses") }
    assert_equal %(name "3d_glasses" must start with a letter and use only letters, numbers and _), err.message
  end

  def test_rejects_name_whose_game_id_would_differ
    err = assert_raises(RedRock::CLI::GenerateError) { generate("sword_2") }
    assert_equal %(name "sword_2" would be called "sword2" in the game; use "sword2" instead), err.message
    err = assert_raises(RedRock::CLI::GenerateError) { generate("fizzy__pop") }
    assert_equal %(name "fizzy__pop" would be called "fizzy_pop" in the game; use "fizzy_pop" instead), err.message
    refute File.exist?(path("lib/hello_gem/items/sword_2.rb"))
  end

  def test_rejects_unknown_kind
    err = assert_raises(RedRock::CLI::GenerateError) { generate(kind: "block") }
    assert_equal %(can't generate "block" yet (only: item)), err.message
  end

  def test_refuses_existing_item
    File.write(path("lib/hello_gem/items/exploding_cookie.rb"), "# mine\n")
    entry = read("lib/hello_gem.rb")
    err = assert_raises(RedRock::CLI::GenerateError) { generate }
    assert_equal "lib/hello_gem/items/exploding_cookie.rb already exists", err.message
    assert_equal "# mine\n", read("lib/hello_gem/items/exploding_cookie.rb")
    refute File.exist?(path("textures/exploding_cookie.png"))
    refute File.exist?(path("test/items/exploding_cookie_test.rb"))
    assert_equal entry, read("lib/hello_gem.rb")
  end

  def test_existing_texture_is_kept
    drawn = File.binread(path("textures/ruby_shard.png"))
    File.binwrite(path("textures/exploding_cookie.png"), drawn)
    result = generate
    assert_equal ["textures/exploding_cookie.png"], result.kept
    assert_equal %w[lib/hello_gem/items/exploding_cookie.rb test/items/exploding_cookie_test.rb], result.created
    assert_equal drawn, File.binread(path("textures/exploding_cookie.png"))
  end

  def test_unedited_entry_prints_instructions
    rewrite("lib/hello_gem.rb") { |src| src.sub("contents RubyShard", "contents RubyShard,\n             Other") }
    entry = File.binread(path("lib/hello_gem.rb"))
    result = generate
    refute result.registered
    assert_equal entry, File.binread(path("lib/hello_gem.rb"))
    assert_equal 3, result.created.size
    result.created.each { |rel| assert File.file?(path(rel)), rel }
  end

  def test_uses_the_entry_files_module_name
    rewrite("lib/hello_gem.rb") { |src| src.sub("module HelloGem", "module Hello") }
    generate
    assert_includes read("lib/hello_gem/items/exploding_cookie.rb"), "module Hello\n"
    assert_includes read("test/items/exploding_cookie_test.rb"), "Hello::ExplodingCookie"
  end

  def test_rejects_the_name_mod
    before = snapshot(path)
    err = assert_raises(RedRock::CLI::GenerateError) { generate("mod") }
    assert_equal %(name "mod" is taken by your mod's own Mod class; pick another), err.message
    assert_equal before, snapshot(path)
  end

  # A class named RedRock inside the mod's module would hide RedRock itself.
  def test_rejects_the_name_red_rock
    before = snapshot(path)
    %w[red_rock RedRock].each do |name|
      err = assert_raises(RedRock::CLI::GenerateError) { generate(name) }
      assert_equal %(name "#{name}" is taken by RedRock itself; pick another), err.message
    end
    assert_equal before, snapshot(path)
  end

  def test_keeps_an_existing_test
    FileUtils.mkdir_p(path("test/items"))
    File.write(path("test/items/exploding_cookie_test.rb"), "# mine\n")
    result = generate
    assert_equal "# mine\n", read("test/items/exploding_cookie_test.rb")
    assert_equal :kept, result.files["test/items/exploding_cookie_test.rb"]
  end

  def test_keeps_the_capitals_typed
    result = generate("TNT")
    assert_equal "TNT", result.const
    assert_equal "hello_gem/items/tnt", result.require_path
    item = read("lib/hello_gem/items/tnt.rb")
    assert_includes item, "  class TNT\n"
    assert_includes item, %(display_name "TNT"\n)
    assert_includes item, %[from the class name ("TNT")]
    assert_includes read("lib/hello_gem.rb"), "contents RubyShard, TNT\n"
  end

  def test_refuses_without_a_module_line
    rewrite("lib/hello_gem.rb") { |src| src.sub("module HelloGem", "# module HelloGem") }
    before = snapshot(path)
    err = assert_raises(RedRock::CLI::GenerateError) { generate }
    assert_equal %(couldn't find a "module" line in lib/hello_gem.rb; new items go inside that module), err.message
    assert_equal before, snapshot(path)
  end

  def test_files_are_in_the_order_considered
    FileUtils.cp(path("textures/ruby_shard.png"), path("textures/exploding_cookie.png"))
    assert_equal({ "lib/hello_gem/items/exploding_cookie.rb" => :made, "textures/exploding_cookie.png" => :kept,
                   "test/items/exploding_cookie_test.rb" => :made }, generate.files)
  end

  private

  def generate(name = "exploding_cookie", kind: "item", root: path)
    project = RedRock::CLI::Project.new(root: root)
    RedRock::CLI::Generate.new(project: project, kind: kind, name: name).call
  end

  # Every file under root, by relative path, with its bytes.
  def snapshot(root)
    Dir.glob("**/*", File::FNM_DOTMATCH, base: root).reject { |f| File.directory?(File.join(root, f)) }
       .sort.to_h { |f| [f, File.binread(File.join(root, f))] }
  end

  def path(*parts) = File.join(@tmp, "hello_gem", *parts)
  def read(rel) = File.read(path(rel))
  def rewrite(rel) = File.write(path(rel), yield(read(rel)))
end
