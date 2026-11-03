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
require_relative "cli/test_runner"

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
      when "new" then new_mod(args.first, out)
      when "generate", "g" then generate(*args, out: out)
      when "build" then build(args.first, out)
      when "test" then TestRunner.new(project: Project.find(File.expand_path(args.first || "."))).call(out:, err:)
      else
        err.puts USAGE
        1
      end
    rescue Interrupt
      err.puts
      130
    rescue ScriptError, StandardError => e
      err.puts "error: #{e.message}"
      1
    end

    def new_mod(mod_id, out)
      raise ProjectError, "usage: red_rock new MOD_ID" unless mod_id

      New.new(mod_id: mod_id, parent_dir: Dir.pwd).call.each { |path| out.puts "Made #{path}" }
      out.puts
      out.puts "Next: cd #{mod_id} && bin/red_rock build"
      0
    end

    def generate(kind = nil, name = nil, *rest, out:)
      raise GenerateError, "usage: #{USAGE.lines[1].strip}" unless kind && name

      project = Project.find(generate_dir(name, rest))
      result = Generate.new(project: project, kind: kind, name: name).call
      out.puts made_lines(result)
      out.puts registered_lines(result, project)
      out.puts
      out.puts result.registered ? "Next: bin/red_rock build" : "Next: add those two lines, then bin/red_rock build"
      0
    end

    # `generate item exploding cookie`: a second word that isn't a folder is
    # part of the name, typed with a space instead of _. One that looks like a
    # path (../mymod, ./x, lib/x) is a folder, even a mistyped one.
    def generate_dir(name, rest)
      return "." if rest.empty?

      dir = rest.first
      return dir if rest.size == 1 && (File.directory?(dir) || dir.match?(%r{/|\A\.}))

      words = [name, *rest]
      raise GenerateError, "name \"#{words.join(' ')}\" can't have spaces; try \"#{words.join('_')}\""
    end

    def made_lines(result)
      result.files.map do |rel, how|
        if how == :kept then "Kept #{rel} (you already #{rel.start_with?('textures/') ? 'drew' : 'wrote'} one)"
        elsif rel.start_with?("textures/") then "Made #{rel} (a placeholder; draw your own 16x16 PNG over it)"
        else "Made #{rel}"
        end
      end
    end

    def registered_lines(result, project)
      return "Added #{result.const} to #{project.entry_file}" if result.registered

      require_line = %(require_relative "#{result.require_path}")
      width = require_line.length + 3
      <<~TEXT.chomp
        Couldn't find where to add #{result.const} in #{project.entry_file}. Add these two lines yourself:
          #{require_line.ljust(width)}(inside module #{project.module_name}, near the top)
          #{result.const.ljust(width)}(at the end of the contents list, after a comma)
      TEXT
    end

    def build(dir, out)
      project_dir = project_root(File.expand_path(dir || "."))
      out.puts Build.new(project_dir: project_dir, out_dir: File.join(project_dir, "pkg")).call
      0
    end

    # Build works from anywhere inside a mod, like generate and test. A folder
    # with no bin/red_rock above it is built as before, so Build reports what's missing.
    def project_root(dir)
      Project.find(dir).root
    rescue ProjectError
      dir
    end
  end
end
