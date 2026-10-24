# frozen_string_literal: true

require_relative "../gemcrafter"
require_relative "cli/mods_toml"
require_relative "cli/build"

module Gemcrafter
  module CLI
    USAGE = "usage: gemcrafter build [DIR]"

    module_function

    # Returns the process exit status. Errors are reported in one line with no
    # backtrace: mod authors should see what to fix, not where gemcrafter broke.
    def start(argv, out: $stdout, err: $stderr)
      command, dir = argv
      unless command == "build"
        err.puts USAGE
        return 1
      end

      project_dir = File.expand_path(dir || ".")
      out.puts Build.new(project_dir: project_dir, out_dir: File.join(project_dir, "pkg")).call
      0
    rescue ScriptError, StandardError => e
      err.puts "error: #{e.message}"
      1
    end
  end
end
