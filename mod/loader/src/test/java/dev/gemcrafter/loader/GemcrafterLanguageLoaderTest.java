package dev.gemcrafter.loader;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;

class GemcrafterLanguageLoaderTest {
    @Test
    void nameMatchesModsToml() {
        assertEquals("gemcrafter", new GemcrafterLanguageLoader().name());
    }

    @Test
    void serviceFileNamesLoader() throws IOException {
        try (var in = getClass().getResourceAsStream(
                "/META-INF/services/net.neoforged.neoforgespi.language.IModLanguageLoader")) {
            assertNotNull(in);
            assertEquals("dev.gemcrafter.loader.GemcrafterLanguageLoader",
                    new String(in.readAllBytes(), StandardCharsets.UTF_8).strip());
        }
    }

    @Test
    void rubyModLoadErrorCarriesOnlyTheRubyMessage() {
        var error = new RubyModLoadError("SyntaxError: boom\n  from lib/x.rb:3");
        assertEquals("SyntaxError: boom\n  from lib/x.rb:3", error.getMessage());
        assertEquals(0, error.getStackTrace().length);
        assertNull(error.getCause());
    }
}
