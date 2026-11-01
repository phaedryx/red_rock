# frozen_string_literal: true

require_relative "../red_rock"
require_relative "cli/errors"
require_relative "cli/project"
require_relative "cli/mods_toml"
require_relative "cli/build"
require_relative "cli/templates"
require_relative "cli/new"
require_relative "cli/entry_file"
require_relative "cli/generate"

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
      when "generate", "g" then generate(*args, out: out)
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

    def generate(kind = nil, name = nil, dir = ".", out:)
      raise GenerateError, "usage: #{USAGE.lines[1].strip}" unless kind && name

      project = Project.find(File.expand_path(dir))
      result = Generate.new(project: project, kind: kind, name: name).call
      out.puts made_lines(result)
      out.puts registered_lines(result, project)
      out.puts
      out.puts "Next: bin/red_rock build"
      0
    end

    # In the order the files were considered: the item, its texture, its test.
    def made_lines(result)
      (result.created + result.kept).sort_by { |rel| %w[lib textures test].index(rel[%r{\A[^/]+}]) }.map do |rel|
        if result.kept.include?(rel) then "Kept #{rel} (you already drew one)"
        elsif rel.start_with?("textures/") then "Made #{rel} (a placeholder; draw your own 16x16 PNG over it)"
        else "Made #{rel}"
        end
      end
    end

    def registered_lines(result, project)
      return "Added #{result.const} to #{project.entry_file}" if result.registered

      require_line = %(require_relative "#{result.require_path}")
      width = require_line.length + 3
      module_name = project.module_name || Naming.camelize(project.mod_id)
      <<~TEXT.chomp
        Couldn't find where to add #{result.const} in #{project.entry_file}. Add these two lines yourself:
          #{require_line.ljust(width)}(inside module #{module_name}, near the top)
          #{result.const.ljust(width)}(on the contents line)
      TEXT
    end

    def build(dir, out)
      project_dir = File.expand_path(dir || ".")
      out.puts Build.new(project_dir: project_dir, out_dir: File.join(project_dir, "pkg")).call
      0
    end
  end
end
