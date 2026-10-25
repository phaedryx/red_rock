package dev.redrock.adapter.v1_21_1;

import static org.junit.jupiter.api.Assertions.*;

import com.google.gson.JsonElement;
import com.google.gson.JsonParser;
import dev.redrock.runtime.ItemSpec;
import dev.redrock.runtime.ModManifest;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AssetGeneratorTest {
    private static final byte[] PNG = {(byte) 0x89, 'P', 'N', 'G'};

    private static ModManifest helloGem(ItemSpec... items) {
        return new ModManifest("hello_gem", "0.1.0", "Hello Gem", List.of(items));
    }

    private static JsonElement json(byte[] bytes) {
        return JsonParser.parseString(new String(bytes, StandardCharsets.UTF_8));
    }

    @Test
    void generatesModelLangAndTexture() {
        var files = AssetGenerator.generate(
                helloGem(new ItemSpec("ruby_shard", "ruby_shard.png", 16, "Ruby Shard")),
                file -> file.equals("ruby_shard.png") ? Optional.of(PNG) : Optional.empty());

        assertEquals(Set.of(
                "pack.mcmeta",
                "assets/hello_gem/models/item/ruby_shard.json",
                "assets/hello_gem/textures/item/ruby_shard.png",
                "assets/hello_gem/lang/en_us.json"), files.keySet());
        assertEquals(json("""
                {"parent":"minecraft:item/generated","textures":{"layer0":"hello_gem:item/ruby_shard"}}
                """.getBytes(StandardCharsets.UTF_8)), json(files.get("assets/hello_gem/models/item/ruby_shard.json")));
        assertArrayEquals(PNG, files.get("assets/hello_gem/textures/item/ruby_shard.png"));
        assertEquals(json("""
                {"item.hello_gem.ruby_shard":"Ruby Shard"}
                """.getBytes(StandardCharsets.UTF_8)), json(files.get("assets/hello_gem/lang/en_us.json")));
        assertEquals(json("""
                {"pack":{"pack_format":34,"description":"RedRock generated assets for hello_gem"}}
                """.getBytes(StandardCharsets.UTF_8)), json(files.get("pack.mcmeta")));
    }

    @Test
    void langCoversAllItems() {
        var files = AssetGenerator.generate(
                helloGem(new ItemSpec("ruby_shard", "ruby_shard.png", 16, "Ruby Shard"),
                        new ItemSpec("pebble", "pebble.png", 64, "Pebble")),
                file -> Optional.of(PNG));

        assertEquals(json("""
                {"item.hello_gem.ruby_shard":"Ruby Shard","item.hello_gem.pebble":"Pebble"}
                """.getBytes(StandardCharsets.UTF_8)), json(files.get("assets/hello_gem/lang/en_us.json")));
    }

    @Test
    void missingTextureIsSkippedWithWarning() {
        var warnings = new ArrayList<String>();
        Map<String, byte[]> files = AssetGenerator.generate(
                helloGem(new ItemSpec("ruby_shard", "ruby_shard.png", 16, "Ruby Shard")),
                file -> Optional.empty(),
                warnings::add);

        assertFalse(files.containsKey("assets/hello_gem/textures/item/ruby_shard.png"));
        assertTrue(files.containsKey("assets/hello_gem/models/item/ruby_shard.json"));
        assertTrue(files.containsKey("assets/hello_gem/lang/en_us.json"));
        assertEquals(List.of(
                "[red_rock] hello_gem: texture ruby_shard.png not found for item ruby_shard; using missing texture"),
                warnings);
    }

    @Test
    void textureFilenameCasingDoesNotLeakIntoResourceLocation() {
        var files = AssetGenerator.generate(
                helloGem(new ItemSpec("ruby_shard", "Ruby_Shard.PNG", 16, "Ruby Shard")),
                file -> file.equals("Ruby_Shard.PNG") ? Optional.of(PNG) : Optional.empty());

        assertArrayEquals(PNG, files.get("assets/hello_gem/textures/item/ruby_shard.png"));
    }
}
