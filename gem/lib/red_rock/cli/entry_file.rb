# frozen_string_literal: true

module RedRock
  module CLI
    # The one edit `generate` makes to an author's own file: a require_relative
    # and an entry on the `contents` line. If either place can't be found for
    # certain, the file is left exactly as it was and the caller tells the
    # author what to add by hand.
    class EntryFile
      REQUIRE = /^\s*require_relative\b/
      CONTENTS = /^(\s*)contents\b(.*)$/
      # Only a plain list of class names is safe to append to: no comment,
      # parentheses or line continuation.
      PLAIN_LIST = /\A(?:\s+[A-Z]\w*(?:\s*,\s*[A-Z]\w*)*)?\s*\z/

      def initialize(path)
        @path = path
      end

      # True when the file now requires require_path and lists const; false
      # when it couldn't be edited (and wasn't).
      def add_item(require_path:, const:)
        original = File.readlines(@path, encoding: "UTF-8")
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

        anchor = require_anchor(lines)
        anchor && lines.dup.insert(anchor + 1, "  #{line}\n")
      end

      # The last require_relative between the module line and contents, else
      # the module line. A require that runs after contents would be too late:
      # contents names the new class before it exists.
      def require_anchor(lines)
        mod = lines.index { |l| l.match?(Project::MODULE_LINE) }
        contents = contents_index(lines)
        return unless mod && contents && mod < contents

        ((mod + 1)...contents).reverse_each.find { |i| lines[i].match?(REQUIRE) } || mod
      end

      def with_contents(lines, const)
        index = contents_index(lines) or return
        indent, rest = lines[index].match(CONTENTS).captures
        return unless rest.match?(PLAIN_LIST)
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
