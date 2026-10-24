package dev.gemcrafter.runtime;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Collections;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class LayeredResourceClassLoaderTest {
    @TempDir
    Path game;

    @TempDir
    Path jruby;

    private static URLClassLoader loaderFor(Path root) throws IOException {
        return new URLClassLoader(new URL[] {root.toUri().toURL()}, null);
    }

    @Test
    void findsResourcesOnlyTheOtherLayerHas() throws IOException {
        Files.createDirectories(jruby.resolve("jruby/java"));
        Files.writeString(jruby.resolve("jruby/java/core_ext.rb"), "# core");
        Files.createDirectories(game.resolve("gemcrafter/lib"));
        Files.writeString(game.resolve("gemcrafter/lib/gemcrafter.rb"), "# api");

        try (var gameLoader = loaderFor(game); var jrubyLoader = loaderFor(jruby)) {
            var loader = new LayeredResourceClassLoader(gameLoader, jrubyLoader);
            assertNotNull(loader.getResource("jruby/java/core_ext.rb"));
            assertNotNull(loader.getResource("gemcrafter/lib/gemcrafter.rb"));
            assertNull(loader.getResource("nope.rb"));
            assertEquals(1, Collections.list(loader.getResources("jruby/java/core_ext.rb")).size());
        }
    }

    @Test
    void classesComeFromTheParent() throws Exception {
        try (var jrubyLoader = loaderFor(jruby)) {
            var loader = new LayeredResourceClassLoader(getClass().getClassLoader(), jrubyLoader);
            assertSame(RubyHost.class, loader.loadClass(RubyHost.class.getName()));
        }
    }
}
