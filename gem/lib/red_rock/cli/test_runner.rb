# frozen_string_literal: true

require "rbconfig"

module RedRock
  module CLI
    # Runs a mod's tests so authors never type a -I flag. In a subprocess, so
    # the mod's constants and Minitest's at-exit run never land inside the CLI.
    class TestRunner
      def initialize(project:)
        @project = project
      end

      # Returns the exit status of the test run.
      def call(out:, err:)
        files = Dir.glob("test/**/*_test.rb", base: @project.root).sort
        if files.empty?
          out.puts "no tests yet (bin/red_rock generate item <name> makes one)"
          return 0
        end

        out.flush
        system(RbConfig.ruby, "-Ilib", "-Itest", "-e", "ARGV.each { |f| require File.expand_path(f) }", *files,
               chdir: @project.root, out: out, err: err)
        Process.last_status.exitstatus
      end
    end
  end
end
