package dev.redrock.runtime;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class RubyHostTest {
    @TempDir
    Path tmp;

    /** Packs a fixture the way `red_rock build` does and returns the root Bootstrap would pass. */
    private String jarRoot(String name) throws IOException {
        return jarRoot(name, tmp);
    }

    private String jarRoot(String name, Path dir) throws IOException {
        Path jar = Files.createDirectories(dir).resolve(name + "-0.1.0.jar");
        Path lib = Path.of(fixture(name), "lib");
        try (var zip = new ZipOutputStream(Files.newOutputStream(jar)); var files = Files.list(lib)) {
            for (Path file : files.toList()) {
                zip.putNextEntry(new ZipEntry("red_rock/ruby/lib/" + file.getFileName()));
                zip.write(Files.readAllBytes(file));
                zip.closeEntry();
            }
        }
        return "jar:" + jar.toUri() + "!/red_rock/ruby";
    }

    private static String fixture(String name) {
        try {
            return Path.of(RubyHostTest.class.getResource("/fixtures/" + name).toURI()).toString();
        } catch (URISyntaxException e) {
            throw new IllegalStateException(e);
        }
    }

    @Test
    void loadsManifest() {
        var m = RubyHost.shared().loadMod("hello_gem", fixture("hello_gem"), "lib/hello_gem.rb");
        assertEquals(new ModManifest("hello_gem", "0.1.0", "Hello Gem",
                List.of(new ItemSpec("ruby_shard", "ruby_shard.png", 16, "Ruby Shard"))), m);
    }

    @Test
    void sharedIsOneRuntime() {
        assertSame(RubyHost.shared(), RubyHost.shared());
    }

    @Test
    void twoModsShareOneRuntimeWithoutLeaking() {
        var a = RubyHost.shared().loadMod("hello_gem", fixture("hello_gem"), "lib/hello_gem.rb");
        var b = RubyHost.shared().loadMod("second_mod", fixture("second_mod"), "lib/second_mod.rb");
        assertEquals(List.of("ruby_shard"), a.items().stream().map(ItemSpec::id).toList());
        assertEquals(List.of("pebble"), b.items().stream().map(ItemSpec::id).toList());
    }

    @Test
    void syntaxErrorIsReportedInRubyTerms() {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("broken", fixture("broken"), "lib/broken.rb"));
        assertTrue(e.getMessage().startsWith("SyntaxError"), e.getMessage());
        assertTrue(e.getMessage().contains("lib/broken.rb:3"), e.getMessage());
        assertFalse(e.getMessage().contains(".java"), e.getMessage());
        assertFalse(e.getMessage().contains("org.jruby"), e.getMessage());
        assertFalse(e.getMessage().contains(fixture("broken")), "absolute paths leak: " + e.getMessage());
    }

    @Test
    void loadsManifestFromJar() throws IOException {
        var m = RubyHost.shared().loadMod("hello_gem", jarRoot("hello_gem"), "lib/hello_gem.rb");
        assertEquals(List.of("ruby_shard"), m.items().stream().map(ItemSpec::id).toList());
    }

    @Test
    void syntaxErrorInJarIsReportedInRubyTerms() throws IOException {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("broken", jarRoot("broken"), "lib/broken.rb"));
        assertTrue(e.getMessage().startsWith("SyntaxError: lib/broken.rb:3"), e.getMessage());
        assertFalse(e.getMessage().contains(".jar"), "jar path leaks: " + e.getMessage());
        assertFalse(e.getMessage().contains(tmp.toString()), "absolute path leaks: " + e.getMessage());
    }

    @Test
    void nameErrorInJarShowsOnlyModFrames() throws IOException {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("raises", jarRoot("raises"), "lib/raises.rb"));
        assertTrue(e.getMessage().startsWith("NameError: uninitialized constant Raises::NotDefinedAnywhere"),
                e.getMessage());
        assertTrue(e.getMessage().contains("\n  from lib/raises.rb:4"), e.getMessage());
        assertFalse(e.getMessage().contains(".jar"), "jar path leaks: " + e.getMessage());
        assertFalse(e.getMessage().contains(".java"), e.getMessage());
    }

    @Test
    void errorsFromAJarUnderAPathWithSpacesStayRelative() throws IOException {
        // macOS launchers keep mods under "~/Library/Application Support/…".
        Path dir = tmp.resolve("Application Support/mods");

        var nameError = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("raises", jarRoot("raises", dir), "lib/raises.rb"));
        assertTrue(nameError.getMessage().contains("\n  from lib/raises.rb:4"), nameError.getMessage());

        var syntaxError = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("broken", jarRoot("broken", dir), "lib/broken.rb"));
        assertTrue(syntaxError.getMessage().startsWith("SyntaxError: lib/broken.rb:3"), syntaxError.getMessage());
        assertFalse(syntaxError.getMessage().contains("Application Support"), syntaxError.getMessage());
    }

    @Test
    void malformedManifestIsReportedWithoutJavaExceptionNames() {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("bad_manifest", fixture("bad_manifest"), "lib/bad_manifest.rb"));
        assertTrue(e.getMessage().startsWith("RedRock::DefinitionError: bad_manifest's manifest is malformed"),
                e.getMessage());
        assertFalse(e.getMessage().contains("ClassCastException"), e.getMessage());
    }

    @Test
    void definitionErrorIsReportedVerbatim() {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("top_level", fixture("top_level"), "lib/top_level.rb"));
        assertTrue(e.getMessage().startsWith(
                "RedRock::DefinitionError: `RubyShard` must be inside `module TopLevel`"), e.getMessage());
    }

    @Test
    void unknownModIdIsADefinitionError() {
        var e = assertThrows(RedRockRubyException.class,
                () -> RubyHost.shared().loadMod("not_hello", fixture("hello_gem"), "lib/hello_gem.rb"));
        assertEquals("RedRock::DefinitionError: No RedRock::Mod with id not_hello was defined", e.getMessage());
    }
}
