# frozen_string_literal: true

module RedRock
  module Mod
    CONTENT_MODULES = [Item].freeze
    TEXTURE_FILE = %r{\A[^/\\]+\.png\z}i

    class << self
      # Keyed by class name, so re-evaluating a mod's file replaces its entry.
      def registry = @registry ||= {}

      def all = registry.values

      def find(mod_id)
        all.reverse.find { |mod| mod.id == mod_id } or
          raise DefinitionError, "No RedRock::Mod with id #{mod_id} was defined"
      end

      def included(base)
        key = base.name || base
        registry.delete(key)
        registry[key] = base
        base.extend(ClassMethods)
      end
    end

    module ClassMethods
      def id(id = nil)
        return @id if id.nil?

        @id = id
      end

      def version(version = nil)
        return @version || "0.1.0" if version.nil?

        @version = version
      end

      def display_name(name = nil)
        return @display_name || Naming.title(Naming.last_segment(namespace)) if name.nil?

        @display_name = name
      end

      def license(license = nil)
        return @license || "All Rights Reserved" if license.nil?

        @license = license
      end

      def contents(*classes)
        return @contents || [] if classes.empty?

        @contents = classes
      end

      def manifest
        Validation.new(self).call
        {
          "mod_id" => id,
          "version" => version,
          "display_name" => display_name,
          "license" => license,
          "items" => contents.map { |item| item_manifest(item) }
        }
      end

      # The module the mod class is defined in (`HelloGem` for `HelloGem::Mod`).
      def namespace
        Object.const_get(name.split("::")[0..-2].join("::"))
      end

      private

      def item_manifest(item)
        { "id" => item.id.to_s, "texture" => item.texture, "stack_size" => item.stack_size,
          "display_name" => item.display_name }
      end
    end

    class Validation
      def initialize(mod)
        @mod = mod
      end

      def call
        check_namespace
        check_id
        @mod.contents.each { |content| check_content(content) }
        check_duplicates
      end

      private

      def check_namespace
        return if @mod.name.include?("::")

        example = @mod.id && Naming.valid_mod_id?(@mod.id) ? camelize(@mod.id) : "MyMod"
        fail! "`#{@mod.name}` must be inside a module named after the mod (e.g. `module #{example}`)"
      end

      def check_id
        fail! %(`#{@mod.name}` needs an id (id "#{Naming.snake(module_name)}")) if @mod.id.nil?
        return if Naming.valid_mod_id?(@mod.id)

        fail! %(mod id "#{@mod.id}" must match #{pattern(Naming::MOD_ID)})
      end

      def check_content(content)
        unless CONTENT_MODULES.any? { |m| content.is_a?(Class) && content.include?(m) }
          fail! "`#{content}` is not RedRock content (include RedRock::Item)"
        end
        unless content.name.to_s.start_with?("#{@mod.namespace.name}::")
          fail! "`#{content.name}` must be inside `module #{module_name}`"
        end
        check_item(content)
      end

      def check_item(item)
        check_texture(item)
        check_item_id(item)
        return if item.display_name.is_a?(String)

        fail! "`#{item.name}` display_name must be a String (got #{item.display_name.inspect})"
      end

      def check_texture(item)
        fail! %(`#{item.name}` needs a texture (texture "#{item.id}.png")) unless item.texture
        return if item.texture.is_a?(String) && TEXTURE_FILE.match?(item.texture)

        fail! "`#{item.name}` texture #{item.texture.inspect} must be a .png file name in textures/"
      end

      def check_item_id(item)
        id = item.id.is_a?(Symbol) ? item.id.to_s : item.id
        return if id.is_a?(String) && Naming.valid_path?(id)

        fail! "`#{item.name}` id #{id.inspect} must match #{pattern(Naming::PATH)}"
      end

      def check_duplicates
        @mod.contents.group_by { |content| content.id.to_s }.each do |id, classes|
          next if classes.size < 2

          fail! "duplicate id #{@mod.id}:#{id} (#{classes.map(&:name).join(', ')})"
        end
      end

      def pattern(regexp) = regexp.source.delete_prefix('\A').delete_suffix('\z')
      def module_name = Naming.last_segment(@mod.namespace)
      def camelize(id) = id.split("_").map(&:capitalize).join
      def fail!(message) = raise(DefinitionError, message)
    end
  end
end
