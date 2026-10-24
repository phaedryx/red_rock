package dev.gemcrafter.runtime;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;
import org.jruby.embed.LocalContextScope;
import org.jruby.embed.LocalVariableBehavior;
import org.jruby.embed.ScriptingContainer;
import org.jruby.exceptions.RaiseException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** The one JRuby runtime every Ruby mod in this JVM shares. */
public final class RubyHost {
    private static final Logger LOGGER = LoggerFactory.getLogger("gemcrafter");
    private static volatile RubyHost shared;

    private final ScriptingContainer container;

    private RubyHost(ScriptingContainer container) {
        this.container = container;
    }

    public static RubyHost shared() {
        RubyHost host = shared;
        if (host == null) {
            synchronized (RubyHost.class) {
                host = shared;
                if (host == null) {
                    host = boot();
                    shared = host;
                }
            }
        }
        return host;
    }

    private static RubyHost boot() {
        long start = System.nanoTime();
        var container = new ScriptingContainer(LocalContextScope.CONCURRENT, LocalVariableBehavior.TRANSIENT);
        container.setClassLoader(new LayeredResourceClassLoader(
                RubyHost.class.getClassLoader(), ScriptingContainer.class.getClassLoader()));
        container.setLoadPaths(List.of("uri:classloader:/gemcrafter/lib"));
        container.runScriptlet("require 'gemcrafter'");
        LOGGER.info("[gemcrafter] JRuby booted in {} ms", (System.nanoTime() - start) / 1_000_000);
        return new RubyHost(container);
    }

    /**
     * Evaluates a mod's entry file and returns its validated manifest.
     *
     * @param rubyRoot a directory, or a JRuby-readable {@code jar:file:/…!/gemcrafter/ruby} URL
     * @param entrypoint the entry file relative to {@code rubyRoot}, e.g. {@code lib/hello_gem.rb}
     * @throws GemcrafterRubyException for any Ruby error, including syntax and definition errors
     */
    public synchronized ModManifest loadMod(String modId, String rubyRoot, String entrypoint) {
        try {
            Object kernel = container.runScriptlet("Kernel");
            container.callMethod(kernel, "load", rubyRoot + "/" + entrypoint);
            Object modRegistry = container.runScriptlet("Gemcrafter::Mod");
            Object mod = container.callMethod(modRegistry, "find", modId);
            return toManifest((Map<?, ?>) container.callMethod(mod, "manifest", Map.class));
        } catch (RuntimeException e) {
            RaiseException raise = findRaise(e);
            if (raise == null) {
                throw e;
            }
            throw new GemcrafterRubyException(describe(raise, rubyRoot), e);
        }
    }

    private static ModManifest toManifest(Map<?, ?> manifest) {
        var items = new ArrayList<ItemSpec>();
        for (Object item : (List<?>) manifest.get("items")) {
            var spec = (Map<?, ?>) item;
            items.add(new ItemSpec(
                    (String) spec.get("id"),
                    (String) spec.get("texture"),
                    ((Number) spec.get("stack_size")).intValue(),
                    (String) spec.get("display_name")));
        }
        return new ModManifest(
                (String) manifest.get("mod_id"),
                (String) manifest.get("version"),
                (String) manifest.get("display_name"),
                items);
    }

    private static RaiseException findRaise(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof RaiseException raise) {
                return raise;
            }
        }
        return null;
    }

    private String describe(RaiseException raise, String rubyRoot) {
        Object exception = raise.getException();
        Pattern rootPrefix = rootPrefix(rubyRoot);
        String className = container.callMethod(container.callMethod(exception, "class"), "name", String.class);
        String message = container.callMethod(exception, "message", String.class);
        var text = new StringBuilder(className).append(": ").append(rootPrefix.matcher(message).replaceAll(""));
        List<?> backtrace = container.callMethod(exception, "backtrace", List.class);
        if (backtrace != null) {
            for (Object frame : backtrace) {
                var matcher = rootPrefix.matcher(String.valueOf(frame));
                if (matcher.lookingAt()) {
                    text.append("\n  from ").append(matcher.replaceFirst(""));
                }
            }
        }
        return text.toString();
    }

    /**
     * Matches a path up to and including the mod's Ruby root, in whatever spelling JRuby reports it:
     * {@code jar:file:/x.jar!/gemcrafter/ruby} comes back as {@code ///x.jar!/gemcrafter/ruby}, for one.
     */
    private static Pattern rootPrefix(String rubyRoot) {
        String root = rubyRoot.replaceFirst("^(jar:)?(file:)?/*", "");
        return Pattern.compile("[^\\s'\"(]*" + Pattern.quote(root + "/"));
    }
}
