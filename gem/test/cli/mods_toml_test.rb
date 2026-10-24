# frozen_string_literal: true

require "test_helper"
require "gemcrafter/cli"

class ModsTomlTest < Minitest::Test
  EXPECTED = <<~TOML
    modLoader = "gemcrafter"
    loaderVersion = "[0.1,0.2)"
    license = "All Rights Reserved"

    [[mods]]
    modId = "hello_gem"
    version = "0.1.0"
    displayName = "Hello Gem"

    [modproperties.hello_gem]
    entrypoint = "lib/hello_gem.rb"

    [[dependencies.hello_gem]]
    modId = "gemcrafter"
    type = "required"
    versionRange = "[0.1,0.2)"
    ordering = "AFTER"
    side = "BOTH"
  TOML

  MANIFEST = {
    "mod_id" => "hello_gem", "version" => "0.1.0", "display_name" => "Hello Gem",
    "license" => "All Rights Reserved", "items" => []
  }.freeze

  def test_renders_exact_toml
    assert_equal EXPECTED, Gemcrafter::CLI::ModsToml.render(manifest: MANIFEST, entrypoint: "lib/hello_gem.rb")
  end

  def test_escapes_quotes_and_backslashes
    toml = Gemcrafter::CLI::ModsToml.render(manifest: MANIFEST.merge("display_name" => %(Say "hi" \\o/)),
                                            entrypoint: "lib/hello_gem.rb")
    assert_includes toml, %(displayName = "Say \\"hi\\" \\\\o/"\n)
  end
end
