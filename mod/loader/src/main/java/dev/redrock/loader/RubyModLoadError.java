package dev.redrock.loader;

/**
 * A Ruby mod failed to load. Its message is in Ruby terms and is shown to players and mod authors
 * as-is, so it carries no Java stack trace and no cause.
 */
public final class RubyModLoadError extends RuntimeException {
    public RubyModLoadError(String rubyMessage) {
        super(rubyMessage, null, false, false);
    }

    /** FML prints causes with {@code toString()}; a Java class name there would leak to authors. */
    @Override
    public String toString() {
        return getMessage();
    }
}
