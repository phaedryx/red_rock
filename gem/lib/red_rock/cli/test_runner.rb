# frozen_string_literal: true

require "open3"
require "rbconfig"

module RedRock
  module CLI
    # Runs a mod's tests so authors never type a -I flag. In a subprocess, so
    # the mod's constants and Minitest's at-exit run never land inside the CLI.
    class TestRunner
      # Only test/ goes on the load path, for `require "test_helper"`. The
      # helper loads the mod with require_relative, so lib/ stays off it and a
      # mod called fileutils can't stand in for the library Minitest needs.
      COMMAND = [RbConfig.ruby, "-Itest", "-e", "ARGV.each { |f| require File.expand_path(f) }"].freeze

      def initialize(project:)
        @project = project
      end

      # Returns the exit status of the test run: 130 when Ctrl-C stopped it,
      # 128 + the signal number when something else killed it.
      def call(out:, err:)
        files = Dir.glob("test/**/*_test.rb", base: @project.root).sort
        if files.empty?
          out.puts "no tests yet (bin/red_rock generate item <name> makes one)"
          return 0
        end

        run(files, out, err)
      end

      private

      # Its own process group, so Ctrl-C reaches only the CLI, which stops the
      # run without either process printing a backtrace.
      def run(files, out, err)
        Open3.popen3(*COMMAND, *files, chdir: @project.root, pgroup: true) do |stdin, stdout, stderr, wait|
          stdin.close
          copies = [Thread.new { IO.copy_stream(stdout, out) }, Thread.new { IO.copy_stream(stderr, err) }]
          status = interruptible(wait)
          copies.each(&:join)
          status
        end
      end

      def interruptible(wait)
        status = wait.value
        status.exitstatus || (128 + status.termsig)
      rescue Interrupt
        Process.kill("KILL", wait.pid)
        wait.join
        130
      end
    end
  end
end
