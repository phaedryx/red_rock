# frozen_string_literal: true

require "fileutils"

module RedRock
  module CLI
    # Scaffolds a mod with one working sample item. Writes nothing unless the
    # mod id is valid and its directory doesn't exist yet.
    class New
      SAMPLE = "ruby_shard"

      def initialize(mod_id:, parent_dir:)
        @mod_id = mod_id
        @parent_dir = parent_dir
      end

      # Returns the paths written, relative to parent_dir.
      def call
        check!
        written = files.map { |rel, (kind, source)| write(rel, kind, source) }
        File.chmod(0o755, File.join(root, "bin/red_rock"))
        written
      end

      private

      def write(rel, kind, source)
        dest = File.join(root, rel)
        FileUtils.mkdir_p(File.dirname(dest))
        if kind == :render
          File.write(dest, Templates.render(source, **vars))
        else
          FileUtils.cp(Templates.file(source), dest)
        end
        "#{@mod_id}/#{rel}"
      end

      def check!
        unless Naming.valid_mod_id?(@mod_id)
          message = "mod id \"#{@mod_id}\" must match [a-z][a-z0-9_]{1,63}"
          suggestion = Naming.snake(@mod_id)
          message += " (try \"#{suggestion}\")" if suggestion != @mod_id && Naming.valid_mod_id?(suggestion)
          raise ProjectError, message
        end
        raise ProjectError, "#{@mod_id}/ already exists" if File.exist?(root)
      end

      def files
        {
          "bin/red_rock" => [:render, "binstub"],
          "lib/#{@mod_id}.rb" => [:render, "entry.rb"],
          "lib/#{@mod_id}/items/#{SAMPLE}.rb" => [:render, "item.rb"],
          "textures/#{SAMPLE}.png" => [:copy, "#{SAMPLE}.png"],
          "test/test_helper.rb" => [:render, "test_helper.rb"],
          "test/items/#{SAMPLE}_test.rb" => [:render, "item_test.rb"],
          "README.md" => [:render, "README.md"],
          ".gitignore" => [:copy, "gitignore"]
        }
      end

      def vars
        {
          mod_id: @mod_id, module_name: Naming.camelize(@mod_id), mod_display_name: Naming.title(@mod_id),
          class_name: Naming.camelize(SAMPLE), stem: SAMPLE, display_name: Naming.title(SAMPLE),
          texture: "#{SAMPLE}.png", require_path: "#{@mod_id}/items/#{SAMPLE}"
        }
      end

      def root = File.join(@parent_dir, @mod_id)
    end
  end
end
