package dev.redrock.runtime;

import java.net.URI;
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
    private static final Logger LOGGER = LoggerFactory.getLogger("red_rock");
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
        // JRuby is shaded into red_rock's own jar, so its default class loader sees both JRuby's
        // stdlib and red_rock's Ruby API.
        var container = new ScriptingContainer(LocalContextScope.CONCURRENT, LocalVariableBehavior.TRANSIENT);
        container.setLoadPaths(List.of("uri:classloader:/red_rock/lib"));
        container.runScriptlet("require 'red_rock'");
        LOGGER.info("[red_rock] JRuby booted in {} ms", (System.nanoTime() - start) / 1_000_000);
        return new RubyHost(container);
    }

    /**
     * Evaluates a mod's entry file and returns its validated manifest.
     *
     * @param rubyRoot a directory, or a JRuby-readable {@code jar:file:/…!/red_rock/ruby} URL
     * @param entrypoint the entry file relative to {@code rubyRoot}, e.g. {@code lib/hello_gem.rb}
     * @throws RedRockRubyException for any Ruby error, including syntax and definition errors
     */
    public synchronized ModManifest loadMod(String modId, String rubyRoot, String entrypoint) {
        try {
            Object kernel = container.runScriptlet("Kernel");
            container.callMethod(kernel, "load", rubyRoot + "/" + entrypoint);
            Object modRegistry = container.runScriptlet("RedRock::Mod");
            Object mod = container.callMethod(modRegistry, "find", modId);
            return toManifest(modId, container.callMethod(mod, "manifest", Map.class));
        } catch (RuntimeException e) {
            RaiseException raise = findRaise(e);
            if (raise == null) {
                throw e;
            }
            throw new RedRockRubyException(describe(raise, rubyRoot), e);
        }
    }

    private static ModManifest toManifest(String modId, Map<?, ?> manifest) {
        var items = new ArrayList<ItemSpec>();
        if (!(manifest.get("items") instanceof List<?> list)) {
            throw malformed(modId, "items is not an Array");
        }
        for (Object item : list) {
            if (!(item instanceof Map<?, ?> spec)) {
                throw malformed(modId, "an item is not a Hash");
            }
            if (!(spec.get("stack_size") instanceof Long stackSize)) {
                throw malformed(modId, "stack_size is not an Integer");
            }
            items.add(new ItemSpec(string(modId, spec, "id"), string(modId, spec, "texture"),
                    stackSize.intValue(), string(modId, spec, "display_name")));
        }
        return new ModManifest(string(modId, manifest, "mod_id"), string(modId, manifest, "version"),
                string(modId, manifest, "display_name"), items);
    }

    private static String string(String modId, Map<?, ?> map, String key) {
        if (map.get(key) instanceof String value) {
            return value;
        }
        throw malformed(modId, key + " is not a String");
    }

    /** RedRock's own validation should make this unreachable; it keeps Java exceptions from authors. */
    private static RedRockRubyException malformed(String modId, String problem) {
        return new RedRockRubyException(
                "RedRock::DefinitionError: " + modId + "'s manifest is malformed (" + problem + ")", null);
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
     * {@code jar:file:/x.jar!/red_rock/ruby} comes back as {@code ///x.jar!/red_rock/ruby}, and
     * percent-encoded characters ({@code Application%20Support}) come back decoded.
     */
    private static Pattern rootPrefix(String rubyRoot) {
        String root = rubyRoot;
        if (root.startsWith("jar:")) {
            int bang = root.indexOf('!');
            root = URI.create(root.substring("jar:".length(), bang)).getPath() + root.substring(bang);
        }
        root = root.replaceFirst("^/*", "");
        return Pattern.compile("(?:(?:jar|file):)*/*" + Pattern.quote(root + "/"));
    }
}
