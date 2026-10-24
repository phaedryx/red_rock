# frozen_string_literal: true

# Bypasses Gemcrafter's validation to hand Java a manifest of the wrong shape.
module BadManifest
  class Mod
    include Gemcrafter::Mod

    id "bad_manifest"

    def self.manifest
      { "mod_id" => "bad_manifest", "version" => "0.1.0", "display_name" => "Bad", "license" => "MIT",
        "items" => [{ "id" => :shard, "texture" => "shard.png", "stack_size" => 1, "display_name" => "Shard" }] }
    end
  end
end
