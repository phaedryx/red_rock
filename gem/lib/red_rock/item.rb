# frozen_string_literal: true

module RedRock
  module Item
    STACK_SIZES = (1..99)

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def red_rock_kind = :item

      def texture(file = nil)
        return @texture if file.nil?

        @texture = file
      end

      def stack_size(size = nil)
        return @stack_size || 64 if size.nil?
        unless size.is_a?(Integer) && STACK_SIZES.cover?(size)
          raise DefinitionError, "stack_size must be 1..99 (got #{size.inspect})"
        end

        @stack_size = size
      end

      def display_name(name = nil)
        return @display_name || Naming.title(Naming.last_segment(self)) if name.nil?

        @display_name = name
      end

      def id(id = nil)
        return @id || Naming.snake(Naming.last_segment(self)) if id.nil?

        @id = id
      end
    end
  end
end
