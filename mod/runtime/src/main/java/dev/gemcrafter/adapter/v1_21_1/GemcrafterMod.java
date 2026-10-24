package dev.gemcrafter.adapter.v1_21_1;

import dev.gemcrafter.runtime.ModManifest;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.event.AddPackFindersEvent;

/**
 * The gemcrafter runtime mod. Ruby mods construct after it (they depend on it), and each one's
 * {@link Bootstrap} adds its generated assets here; the client asks for packs later still.
 */
@Mod("gemcrafter")
public final class GemcrafterMod {
    record GeneratedAssets(ModManifest manifest, Map<String, byte[]> files) {}

    private static final List<GeneratedAssets> ASSETS = new CopyOnWriteArrayList<>();

    public GemcrafterMod(IEventBus modBus) {
        modBus.addListener(AddPackFindersEvent.class,
                e -> ASSETS.forEach(a -> GeneratedPack.register(e, a.manifest(), a.files())));
    }

    static void addAssets(ModManifest manifest, Map<String, byte[]> files) {
        ASSETS.add(new GeneratedAssets(manifest, Map.copyOf(files)));
    }
}
