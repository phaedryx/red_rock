package dev.redrock.adapter.v1_21_1;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import dev.redrock.runtime.ItemSpec;
import dev.redrock.runtime.ModManifest;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.function.Consumer;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Generates the 1.21.1 client assets for a Ruby mod's declarations. Release jars carry no JSON;
 * this is the one place that knows 1.21.1's asset formats.
 */
public final class AssetGenerator {
    /** {@code SharedConstants.RESOURCE_PACK_FORMAT} in 1.21.1. Data packs use 48. */
    static final int RESOURCE_PACK_FORMAT = 34;

    private static final Logger LOGGER = LoggerFactory.getLogger("red_rock");
    private static final Gson GSON = new Gson();

    private AssetGenerator() {}

    /**
     * @param textures looks up a texture by the filename the item declared
     * @return pack-relative path to file contents
     */
    public static Map<String, byte[]> generate(ModManifest m, Function<String, Optional<byte[]>> textures) {
        return generate(m, textures, LOGGER::warn);
    }

    static Map<String, byte[]> generate(
            ModManifest m, Function<String, Optional<byte[]>> textures, Consumer<String> warn) {
        String mod = m.modId();
        var files = new LinkedHashMap<String, byte[]>();
        var lang = new JsonObject();
        for (ItemSpec item : m.items()) {
            files.put("assets/%s/models/item/%s.json".formatted(mod, item.id()), json(itemModel(mod, item)));
            // The resource location comes from the item id, never the filename, so
            // `Ruby_Shard.PNG` still lands at a valid lower-case path.
            textures.apply(item.texture()).ifPresentOrElse(
                    png -> files.put("assets/%s/textures/item/%s.png".formatted(mod, item.id()), png),
                    () -> warn.accept("[red_rock] %s: texture %s not found for item %s; using missing texture"
                            .formatted(mod, item.texture(), item.id())));
            lang.addProperty("item.%s.%s".formatted(mod, item.id()), item.displayName());
        }
        files.put("assets/%s/lang/en_us.json".formatted(mod), json(lang));
        files.put("pack.mcmeta", json(packMeta(mod)));
        return files;
    }

    private static JsonObject itemModel(String mod, ItemSpec item) {
        var textures = new JsonObject();
        textures.addProperty("layer0", "%s:item/%s".formatted(mod, item.id()));
        var model = new JsonObject();
        model.addProperty("parent", "minecraft:item/generated");
        model.add("textures", textures);
        return model;
    }

    private static JsonObject packMeta(String mod) {
        var pack = new JsonObject();
        pack.addProperty("pack_format", RESOURCE_PACK_FORMAT);
        pack.addProperty("description", "RedRock generated assets for " + mod);
        var meta = new JsonObject();
        meta.add("pack", pack);
        return meta;
    }

    private static byte[] json(JsonObject object) {
        return GSON.toJson(object).getBytes(StandardCharsets.UTF_8);
    }
}
