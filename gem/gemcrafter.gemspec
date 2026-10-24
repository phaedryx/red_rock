# frozen_string_literal: true

require_relative "lib/gemcrafter/version"

Gem::Specification.new do |spec|
  spec.name = "gemcrafter"
  spec.version = Gemcrafter::VERSION
  spec.authors = ["Tad Thorley"]

  spec.summary = "Write Minecraft content mods in Ruby"
  spec.description = <<~DESC
    Gemcrafter lets Ruby developers declare Minecraft content (items, blocks,
    mobs, tools, projectiles) in idiomatic Ruby and ship it as an ordinary
    NeoForge mod jar that runs on the gemcrafter runtime.
  DESC
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["gemcrafter"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubyzip", "~> 3.2"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
