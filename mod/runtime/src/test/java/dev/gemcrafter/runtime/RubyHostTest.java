package dev.gemcrafter.runtime;

import static org.junit.jupiter.api.Assertions.*;

import java.net.URISyntaxException;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;

class RubyHostTest {
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
        var e = assertThrows(GemcrafterRubyException.class,
                () -> RubyHost.shared().loadMod("broken", fixture("broken"), "lib/broken.rb"));
        assertTrue(e.getMessage().startsWith("SyntaxError"), e.getMessage());
        assertTrue(e.getMessage().contains("lib/broken.rb:3"), e.getMessage());
        assertFalse(e.getMessage().contains(".java"), e.getMessage());
        assertFalse(e.getMessage().contains("org.jruby"), e.getMessage());
        assertFalse(e.getMessage().contains(fixture("broken")), "absolute paths leak: " + e.getMessage());
    }

    @Test
    void definitionErrorIsReportedVerbatim() {
        var e = assertThrows(GemcrafterRubyException.class,
                () -> RubyHost.shared().loadMod("top_level", fixture("top_level"), "lib/top_level.rb"));
        assertTrue(e.getMessage().startsWith(
                "Gemcrafter::DefinitionError: `RubyShard` must be inside `module TopLevel`"), e.getMessage());
    }

    @Test
    void unknownModIdIsADefinitionError() {
        var e = assertThrows(GemcrafterRubyException.class,
                () -> RubyHost.shared().loadMod("not_hello", fixture("hello_gem"), "lib/hello_gem.rb"));
        assertEquals("Gemcrafter::DefinitionError: No Gemcrafter::Mod with id not_hello was defined", e.getMessage());
    }
}
