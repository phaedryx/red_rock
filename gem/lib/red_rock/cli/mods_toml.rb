# frozen_string_literal: true

module RedRock
  module CLI
    module ModsToml
      module_function

      def render(manifest:, entrypoint:)
        mod_id = manifest.fetch("mod_id")
        <<~TOML
          modLoader = "red_rock"
          loaderVersion = #{str(API_RANGE)}
          license = #{str(manifest.fetch('license'))}

          [[mods]]
          modId = #{str(mod_id)}
          version = #{str(manifest.fetch('version'))}
          displayName = #{str(manifest.fetch('display_name'))}

          [modproperties.#{mod_id}]
          entrypoint = #{str(entrypoint)}

          [[dependencies.#{mod_id}]]
          modId = "red_rock"
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
