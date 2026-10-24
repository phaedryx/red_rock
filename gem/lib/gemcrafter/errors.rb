# frozen_string_literal: true

module Gemcrafter
  # Raised when a mod's declarations are invalid. Its message is shown to the
  # mod author verbatim, so it should say what to write instead.
  class DefinitionError < StandardError; end
end
