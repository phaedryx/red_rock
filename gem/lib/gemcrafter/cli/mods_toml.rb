# frozen_string_literal: true

module Gemcrafter
  module CLI
    module ModsToml
      module_function

      def render(manifest:, entrypoint:)
        mod_id = manifest.fetch("mod_id")
        <<~TOML
          modLoader = "gemcrafter"
          loaderVersion = #{str(API_RANGE)}
          license = #{str(manifest.fetch('license'))}

          [[mods]]
          modId = #{str(mod_id)}
          version = #{str(manifest.fetch('version'))}
          displayName = #{str(manifest.fetch('display_name'))}

          [modproperties.#{mod_id}]
          entrypoint = #{str(entrypoint)}

          [[dependencies.#{mod_id}]]
          modId = "gemcrafter"
          type = "required"
          versionRange = #{str(API_RANGE)}
          ordering = "AFTER"
          side = "BOTH"
        TOML
      end

      def str(value) = %("#{value.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}")
    end
  end
end
