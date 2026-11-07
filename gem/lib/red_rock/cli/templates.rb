# frozen_string_literal: true

require "erb"

module RedRock
  module CLI
    # The files `new` and `generate` write. ERB templates take their variables
    # as locals; the other files (PNGs, .gitignore) are copied as they are.
    module Templates
      DIR = File.expand_path("templates", __dir__)

      module_function

      def render(name, **vars)
        ERB.new(File.read(file("#{name}.erb")), trim_mode: "-").result_with_hash(vars)
      end

      def file(name) = File.join(DIR, name)
    end
  end
end
