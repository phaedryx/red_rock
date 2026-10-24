# frozen_string_literal: true

require_relative "lib/red_rock/version"

Gem::Specification.new do |spec|
  spec.name = "red_rock"
  spec.version = RedRock::VERSION
  spec.authors = ["Tad Thorley"]

  spec.summary = "Write Minecraft content mods in Ruby"
  spec.description = <<~DESC
    RedRock lets Ruby developers declare Minecraft content (items, blocks,
    mobs, tools, projectiles) in idiomatic Ruby and ship it as an ordinary
    NeoForge mod jar that runs on the red_rock runtime.
  DESC
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["red_rock"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rubyzip", "~> 3.2"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
