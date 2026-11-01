# frozen_string_literal: true

require "fileutils"

module RedRock
  module CLI
    # Adds one piece of content to a mod: its file, a placeholder texture, a
    # test, and the two lines in the entry file that register it. Every check
    # runs before anything is written.
    class Generate
      KINDS = %w[item].freeze

      # files maps each path, in the order considered, to :made or :kept.
      Result = Data.define(:files, :registered, :const, :require_path) do
        def created = files.filter_map { |rel, how| rel if how == :made }
        def kept = files.filter_map { |rel, how| rel if how == :kept }
      end

      def initialize(project:, kind:, name:)
        @project = project
        @kind = kind
        @name = name
      end

      def call
        check!
        files = {
          item_file => render(item_file, "item.rb"),
          texture_file => copy_placeholder(texture_file),
          test_file => render(test_file, "item_test.rb")
        }
        Result.new(files:, registered: register, const:, require_path:)
      end

      private

      def check!
        raise GenerateError, "can't generate \"#{@kind}\" yet (only: #{KINDS.join(', ')})" unless KINDS.include?(@kind)
        unless Naming.valid_name?(stem)
          raise GenerateError, "name \"#{@name}\" must start with a letter and use only letters, numbers and _"
        end

        check_game_name!
        raise GenerateError, "#{item_file} already exists" if File.exist?(@project.path(item_file))

        check_module_line!
      end

      # Items go inside the entry file's module; without one there's no name to put them in.
      def check_module_line!
        return if module_name

        raise GenerateError, %(couldn't find a "module" line in #{@project.entry_file}; new items go inside that module)
      end

      # The game names an item after its class, so a stem that doesn't survive
      # the trip to a class name and back (sword_2 -> Sword2 -> sword2) would
      # give the item a different id from its files.
      def check_game_name!
        raise GenerateError, %(name "#{@name}" is taken by your mod's own Mod class; pick another) if const == "Mod"

        game_name = Naming.snake(const)
        return if game_name == stem

        raise GenerateError, %(name "#{@name}" would be called "#{game_name}" in the game; use "#{game_name}" instead)
      end

      def register
        EntryFile.new(@project.path(@project.entry_file)).add_item(require_path: require_path, const: const)
      end

      def render(rel, template)
        write(rel) { |dest| File.write(dest, Templates.render(template, **vars)) }
        :made
      end

      # A texture the author already drew is theirs; never paint over it.
      def copy_placeholder(rel)
        return :kept if File.exist?(@project.path(rel))

        write(rel) { |dest| FileUtils.cp(Templates.file("placeholder.png"), dest) }
        :made
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
      def module_name = @module_name ||= @project.module_name
      def require_path = "#{mod_id}/items/#{stem}"
      def item_file = "lib/#{require_path}.rb"
      def texture_file = "textures/#{stem}.png"
      def test_file = "test/items/#{stem}_test.rb"
    end
  end
end
