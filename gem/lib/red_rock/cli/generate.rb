# frozen_string_literal: true

require "fileutils"

module RedRock
  module CLI
    # Adds one piece of content to a mod: its file, a placeholder texture, a
    # test, and the two lines in the entry file that register it. Every check
    # runs before anything is written.
    class Generate
      KINDS = %w[item].freeze

      Result = Data.define(:created, :kept, :registered, :const, :require_path)

      def initialize(project:, kind:, name:)
        @project = project
        @kind = kind
        @name = name
      end

      def call
        check!
        created = []
        kept = []
        render(item_file, "item.rb", created)
        copy_placeholder(texture_file, created, kept)
        render(test_file, "item_test.rb", created)
        entry = EntryFile.new(@project.path(@project.entry_file))
        registered = entry.add_item(require_path: require_path, const: const)
        Result.new(created:, kept:, registered:, const:, require_path:)
      end

      private

      def check!
        raise GenerateError, "can't generate \"#{@kind}\" yet (only: #{KINDS.join(', ')})" unless KINDS.include?(@kind)
        unless Naming.valid_name?(stem)
          raise GenerateError, "name \"#{@name}\" must start with a letter and use only letters, numbers and _"
        end
        raise GenerateError, "#{item_file} already exists" if File.exist?(@project.path(item_file))
      end

      def render(rel, template, created)
        write(rel) { |dest| File.write(dest, Templates.render(template, **vars)) }
        created << rel
      end

      # A texture the author already drew is theirs; never paint over it.
      def copy_placeholder(rel, created, kept)
        return kept << rel if File.exist?(@project.path(rel))

        write(rel) { |dest| FileUtils.cp(Templates.file("placeholder.png"), dest) }
        created << rel
      end

      def write(rel)
        dest = @project.path(rel)
        FileUtils.mkdir_p(File.dirname(dest))
        yield dest
      end

      def vars
        {
          mod_id: mod_id, module_name: module_name, class_name: const, stem: stem,
          display_name: Naming.title(stem), texture: "#{stem}.png", require_path: require_path
        }
      end

      def stem = @stem ||= Naming.snake(@name)
      def const = Naming.camelize(stem)
      def mod_id = @project.mod_id
      def module_name = @project.module_name || Naming.camelize(mod_id)
      def require_path = "#{mod_id}/items/#{stem}"
      def item_file = "lib/#{require_path}.rb"
      def texture_file = "textures/#{stem}.png"
      def test_file = "test/items/#{stem}_test.rb"
    end
  end
end
