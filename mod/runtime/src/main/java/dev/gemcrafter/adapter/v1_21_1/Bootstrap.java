package dev.gemcrafter.adapter.v1_21_1;

import dev.gemcrafter.loader.RubyModBootstrap;
import dev.gemcrafter.loader.RubyModLoadError;
import dev.gemcrafter.runtime.GemcrafterRubyException;
import dev.gemcrafter.runtime.ModManifest;
import dev.gemcrafter.runtime.RubyHost;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforgespi.language.IModInfo;
import net.neoforged.neoforgespi.locating.IModFile;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Loads one Ruby mod jar: evaluates its Ruby, registers its content and queues its assets. */
public final class Bootstrap implements RubyModBootstrap {
    private static final Logger LOGGER = LoggerFactory.getLogger("gemcrafter");

    @Override
    public void load(IModInfo info, IEventBus modBus) {
        IModFile file = info.getOwningFile().getFile();
        String entrypoint = String.valueOf(info.getModProperties().get("entrypoint"));
        String rubyRoot = "jar:" + file.getFilePath().toUri() + "!/gemcrafter/ruby";
        ModManifest manifest;
        try {
            manifest = RubyHost.shared().loadMod(info.getModId(), rubyRoot, entrypoint);
        } catch (GemcrafterRubyException e) {
            LOGGER.debug("[gemcrafter] {} failed to load", info.getModId(), e);
            throw new RubyModLoadError(e.getMessage());
        }
        ContentRegistrar.register(manifest, modBus);
        GemcrafterMod.addAssets(manifest, AssetGenerator.generate(manifest, texture -> read(file, texture)));
    }

    private static Optional<byte[]> read(IModFile file, String texture) {
        Path path = file.findResource("gemcrafter", "textures", texture);
        if (!Files.isRegularFile(path)) {
            return Optional.empty();
        }
        try {
            return Optional.of(Files.readAllBytes(path));
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
