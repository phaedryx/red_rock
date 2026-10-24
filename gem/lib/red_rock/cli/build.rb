# frozen_string_literal: true

require "fileutils"
require "zip"

module RedRock
  module CLI
    class BuildError < StandardError; end

    # Writes a release jar: Ruby sources, the textures items declare, and
    # neoforge.mods.toml. Never generated JSON — the runtime adapter makes that.
    class Build
      def initialize(project_dir:, out_dir:)
        @project_dir = project_dir
        @out_dir = out_dir
      end

      def call
        entry = entry_file
        mod = load_mod(entry)
        manifest = mod.manifest
        textures = texture_files(mod)
        write_jar(manifest, entry, textures)
      end

      private

      def entry_file
        entries = Dir.children(path("lib")).select { |f| f.end_with?(".rb") && File.file?(path("lib", f)) }.sort
        return "lib/#{entries.first}" if entries.size == 1

        found = entries.empty? ? "none" : entries.join(", ")
        raise BuildError, "lib/ must contain exactly one entry file (found: #{found})"
      end

      def load_mod(entry)
        before = Mod.all
        load path(entry)
        defined = Mod.all - before
        return defined.first if defined.size == 1

        raise BuildError, "#{entry} must define exactly one RedRock::Mod (found #{defined.size})"
      end

      def texture_files(mod)
        mod.contents.each do |item|
          next if File.file?(path("textures", item.texture))

          raise BuildError, "textures/#{item.texture} not found (texture of #{item.name})"
        end
        mod.contents.map(&:texture).uniq
      end

      def write_jar(manifest, entry, textures)
        FileUtils.mkdir_p(@out_dir)
        jar = File.join(@out_dir, "#{manifest.fetch('mod_id')}-#{manifest.fetch('version')}.jar")
        FileUtils.rm_f(jar)
        Zip::File.open(jar, create: true) { |zip| write_entries(zip, manifest, entry, textures) }
        jar
      end

      def write_entries(zip, manifest, entry, textures)
        zip.get_output_stream("META-INF/MANIFEST.MF") { |io| io.write("Manifest-Version: 1.0\r\n\r\n") }
        zip.get_output_stream("META-INF/neoforge.mods.toml") do |io|
          io.write(ModsToml.render(manifest: manifest, entrypoint: entry))
        end
        ruby_sources.each { |rel| zip.add("red_rock/ruby/#{rel}", path(rel)) }
        textures.each { |file| zip.add("red_rock/textures/#{file}", path("textures", file)) }
      end

      def ruby_sources
        Dir.glob("lib/**/*.rb", base: @project_dir).sort
      end

      def path(*parts) = File.join(@project_dir, *parts)
    end
  end
end
