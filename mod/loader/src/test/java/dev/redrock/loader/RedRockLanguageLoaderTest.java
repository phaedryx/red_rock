package dev.redrock.loader;

import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import net.neoforged.fml.i18n.FMLTranslations;
import net.neoforged.neoforgespi.language.IModFileInfo;
import net.neoforged.neoforgespi.language.IModInfo;
import net.neoforged.neoforgespi.locating.IModFile;
import org.junit.jupiter.api.Test;

class RedRockLanguageLoaderTest {
    /** A stand-in for an FML interface: the named getters return the given values, the rest null. */
    private static <T> T stub(Class<T> type, Object... getters) {
        var values = new java.util.HashMap<String, Object>();
        for (int i = 0; i < getters.length; i += 2) {
            values.put((String) getters[i], getters[i + 1]);
        }
        return type.cast(Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] {type},
                (proxy, method, args) -> values.get(method.getName())));
    }

    @Test
    void nameMatchesModsToml() {
        assertEquals("red_rock", new RedRockLanguageLoader().name());
    }

    @Test
    void serviceFileNamesLoader() throws IOException {
        try (var in = getClass().getResourceAsStream(
                "/META-INF/services/net.neoforged.neoforgespi.language.IModLanguageLoader")) {
            assertNotNull(in);
            assertEquals("dev.redrock.loader.RedRockLanguageLoader",
                    new String(in.readAllBytes(), StandardCharsets.UTF_8).strip());
        }
    }

    @Test
    void rubyModLoadErrorCarriesOnlyTheRubyMessage() {
        var error = new RubyModLoadError("SyntaxError: boom\n  from lib/x.rb:3");
        assertEquals("SyntaxError: boom\n  from lib/x.rb:3", error.getMessage());
        assertEquals(0, error.getStackTrace().length);
        assertNull(error.getCause());
        // FML prints the cause with toString(); a Java class name there would leak to authors.
        assertEquals("SyntaxError: boom\n  from lib/x.rb:3", error.toString());
    }

    @Test
    void loadIssueShowsTheRubyMessageWithoutJavaNames() {
        var file = stub(IModFile.class, "getFilePath", Path.of("mods/hello_gem-0.1.0.jar"));
        var fileInfo = stub(IModFileInfo.class, "getFile", file);
        var info = stub(IModInfo.class, "getModId", "hello_gem", "getDisplayName", "Hello Gem",
                "getOwningFile", fileInfo);
        var issue = RedRockModContainer.rubyLoadIssue(info,
                new RubyModLoadError("SyntaxError: lib/hello_gem.rb:6: syntax error, unexpected ']'\n  texture {x} ]"));

        assertEquals("Hello Gem (hello_gem) has failed to load correctly\n"
                + "SyntaxError: lib/hello_gem.rb:6: syntax error, unexpected ']'\n  texture {x} ]",
                FMLTranslations.stripControlCodes(FMLTranslations.translateIssueEnglish(issue)));
        assertNull(issue.cause(), "a cause would print as a Java class name");
        assertSame(info, issue.affectedMod());
    }
}
