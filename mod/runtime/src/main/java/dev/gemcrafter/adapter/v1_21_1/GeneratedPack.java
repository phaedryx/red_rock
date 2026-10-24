package dev.gemcrafter.adapter.v1_21_1;

import dev.gemcrafter.runtime.ModManifest;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.packs.AbstractPackResources;
import net.minecraft.server.packs.PackLocationInfo;
import net.minecraft.server.packs.PackSelectionConfig;
import net.minecraft.server.packs.PackType;
import net.minecraft.server.packs.repository.Pack;
import net.minecraft.server.packs.repository.PackSource;
import net.minecraft.server.packs.resources.IoSupplier;
import net.neoforged.neoforge.event.AddPackFindersEvent;
import org.jetbrains.annotations.Nullable;

/** An in-memory client resource pack serving one Ruby mod's generated assets. */
final class GeneratedPack extends AbstractPackResources {
    private final String modId;
    private final Map<String, byte[]> files;

    private GeneratedPack(PackLocationInfo location, String modId, Map<String, byte[]> files) {
        super(location);
        this.modId = modId;
        this.files = files;
    }

    static void register(AddPackFindersEvent e, ModManifest m, Map<String, byte[]> files) {
        if (e.getPackType() != PackType.CLIENT_RESOURCES) {
            return;
        }
        var info = new PackLocationInfo(
                "gemcrafter/" + m.modId(), Component.literal(m.displayName()), PackSource.BUILT_IN, Optional.empty());
        var supplier = new Pack.ResourcesSupplier() {
            @Override
            public GeneratedPack openPrimary(PackLocationInfo location) {
                return new GeneratedPack(location, m.modId(), files);
            }

            @Override
            public GeneratedPack openFull(PackLocationInfo location, Pack.Metadata metadata) {
                return new GeneratedPack(location, m.modId(), files);
            }
        };
        Pack pack = Pack.readMetaAndCreate(
                info, supplier, PackType.CLIENT_RESOURCES, new PackSelectionConfig(true, Pack.Position.TOP, false));
        if (pack != null) {
            e.addRepositorySource(packs -> packs.accept(pack));
        }
    }

    @Override
    public @Nullable IoSupplier<InputStream> getRootResource(String... path) {
        return supply(String.join("/", path));
    }

    @Override
    public @Nullable IoSupplier<InputStream> getResource(PackType type, ResourceLocation location) {
        return supply(type.getDirectory() + "/" + location.getNamespace() + "/" + location.getPath());
    }

    @Override
    public void listResources(PackType type, String namespace, String path, ResourceOutput output) {
        String root = type.getDirectory() + "/" + namespace + "/";
        String prefix = root + path + "/";
        files.forEach((key, bytes) -> {
            if (key.startsWith(prefix)) {
                output.accept(ResourceLocation.fromNamespaceAndPath(namespace, key.substring(root.length())),
                        () -> new ByteArrayInputStream(bytes));
            }
        });
    }

    @Override
    public Set<String> getNamespaces(PackType type) {
        return type == PackType.CLIENT_RESOURCES ? Set.of(modId) : Set.of();
    }

    @Override
    public void close() {}

    private @Nullable IoSupplier<InputStream> supply(String key) {
        byte[] bytes = files.get(key);
        return bytes == null ? null : () -> new ByteArrayInputStream(bytes);
    }
}
