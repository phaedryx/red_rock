# frozen_string_literal: true

module RedRock
  module CLI
    # Every CLI error's message is shown as one line, `error: <message>`, so it
    # should say what to do, not what went wrong inside red_rock.
    class Error < StandardError; end
    class ProjectError < Error; end
    class BuildError < Error; end
    class GenerateError < Error; end
  end
end
