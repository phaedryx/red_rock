# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "red_rock"

require "minitest/autorun"

# Runs the block as if the locale were `encoding` (LANG=C is US-ASCII).
def with_external_encoding(encoding)
  verbose = $VERBOSE
  $VERBOSE = nil # setting default_external warns
  previous = Encoding.default_external
  Encoding.default_external = encoding
  yield
ensure
  Encoding.default_external = previous
  $VERBOSE = verbose
end
