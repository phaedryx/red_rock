# frozen_string_literal: true

require "pathname"

module RedRock
  module CLI
    # A mod project on disk: the directory holding bin/red_rock and lib/, and
    # the one top-level .rb in lib/ that is the mod's entry file.
    class Project
      MODULE_LINE = /^module\s+([A-Z]\w*)/

      def self.find(dir)
        raise ProjectError, "there's no folder #{dir}" unless File.directory?(dir)

        Pathname(dir).expand_path.ascend do |candidate|
          return new(root: candidate.to_s) if candidate.join("bin/red_rock").file? && candidate.join("lib").directory?
        end
        raise ProjectError, "not inside a RedRock mod (no bin/red_rock found in or above #{dir})"
      end

      attr_reader :root

      def initialize(root:)
        @root = File.expand_path(root)
      end

      def path(*parts) = File.join(@root, *parts)

      def entry_file
        entries = Dir.children(path("lib")).select { |f| f.end_with?(".rb") && File.file?(path("lib", f)) }.sort
        return "lib/#{entries.first}" if entries.size == 1

        found = entries.empty? ? "none" : entries.join(", ")
        raise ProjectError, "lib/ must contain exactly one entry file (found: #{found})"
      end

      def mod_id = File.basename(entry_file, ".rb")

      def module_name
        File.read(path(entry_file), encoding: "UTF-8")[MODULE_LINE, 1]
      end
    end
  end
end
