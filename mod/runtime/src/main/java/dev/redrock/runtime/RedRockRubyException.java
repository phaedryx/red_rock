package dev.redrock.runtime;

/**
 * A Ruby error from a mod, described in Ruby terms: {@code "<RubyClass>: <message>"} followed by the
 * mod's own {@code .rb} frames. Mod authors see this message, never a Java stack trace.
 */
public final class RedRockRubyException extends RuntimeException {
    public RedRockRubyException(String rubyMessage, Throwable cause) {
        super(rubyMessage, cause);
    }
}
