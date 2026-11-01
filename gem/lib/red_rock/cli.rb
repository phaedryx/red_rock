# frozen_string_literal: true

require_relative "../red_rock"
require_relative "cli/errors"
require_relative "cli/project"
require_relative "cli/mods_toml"
require_relative "cli/build"
require_relative "cli/templates"
require_relative "cli/new"
require_relative "cli/entry_file"

module RedRock
  module CLI
    USAGE = <<~USAGE
      usage: red_rock new MOD_ID
             red_rock generate item NAME [DIR]
             red_rock build [DIR]
             red_rock test [DIR]
    USAGE

    module_function

    # Returns the process exit status. Errors are reported in one line with no
    # backtrace: mod authors should see what to fix, not where red_rock broke.
    def start(argv, out: $stdout, err: $stderr)
      command, *args = argv
      case command
      when "new" then new_mod(args.first.to_s, out)
      when "build" then build(args.first, out)
      else
        err.puts USAGE
        1
      end
    rescue ScriptError, StandardError => e
      err.puts "error: #{e.message}"
      1
    end

    def new_mod(mod_id, out)
      New.new(mod_id: mod_id, parent_dir: Dir.pwd).call.each { |path| out.puts "Made #{path}" }
      out.puts
      out.puts "Next: cd #{mod_id} && bin/red_rock build"
      0
    end

    def build(dir, out)
      project_dir = File.expand_path(dir || ".")
      out.puts Build.new(project_dir: project_dir, out_dir: File.join(project_dir, "pkg")).call
      0
    end
  end
end
