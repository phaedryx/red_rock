# frozen_string_literal: true

module RedRock
  module CLI
    # The one edit `generate` makes to an author's own file: a require_relative
    # and an entry on the `contents` line. If either place can't be found for
    # certain, the file is left exactly as it was and the caller tells the
    # author what to add by hand.
    class EntryFile
      REQUIRE = /^\s*require_relative\b/
      MODULE = /^module\s+[A-Z]\w*/
      CONTENTS = /^(\s*)contents\b(.*)$/

      def initialize(path)
        @path = path
      end

      # True when the file now requires require_path and lists const; false
      # when it couldn't be edited (and wasn't).
      def add_item(require_path:, const:) # rubocop:disable Naming/PredicateMethod
        original = File.readlines(@path)
        lines = with_require(original, require_path)
        lines &&= with_contents(lines, const)
        return false unless lines

        File.write(@path, lines.join) unless lines == original
        true
      end

      private

      # Each returns the edited lines, or nil when its anchor isn't certain.
      def with_require(lines, require_path)
        line = %(require_relative "#{require_path}")
        return lines if lines.any? { |l| l.strip == line }

        anchor = lines.rindex { |l| l.match?(REQUIRE) } || lines.index { |l| l.match?(MODULE) }
        anchor && lines.dup.insert(anchor + 1, "  #{line}\n")
      end

      def with_contents(lines, const)
        index = contents_index(lines) or return
        indent, rest = lines[index].match(CONTENTS).captures
        return if rest.rstrip.end_with?(",", "\\")
        return lines if rest.match?(/\b#{const}\b/)

        lines.dup.tap { |edited| edited[index] = "#{indent}contents#{listed(rest, const)}\n" }
      end

      # The contents line, when there is exactly one.
      def contents_index(lines)
        found = lines.each_index.select { |i| lines[i].match?(CONTENTS) }
        found.first if found.size == 1
      end

      def listed(rest, const) = rest.strip.empty? ? " #{const}" : "#{rest.rstrip}, #{const}"
    end
  end
end
