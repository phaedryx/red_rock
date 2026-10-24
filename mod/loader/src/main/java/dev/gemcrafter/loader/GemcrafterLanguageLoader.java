package dev.gemcrafter.loader;

import net.neoforged.fml.ModContainer;
import net.neoforged.fml.loading.JarVersionLookupHandler;
import net.neoforged.neoforgespi.language.IModInfo;
import net.neoforged.neoforgespi.language.IModLanguageLoader;
import net.neoforged.neoforgespi.language.ModFileScanData;

/**
 * Claims mod jars whose {@code neoforge.mods.toml} says {@code modLoader = "gemcrafter"}. Those jars
 * hold only Ruby and PNGs; the gemcrafter runtime mod does the real work. Modelled on Kotlin for
 * Forge's {@code KotlinLanguageLoader}.
 */
public final class GemcrafterLanguageLoader implements IModLanguageLoader {
    @Override
    public String name() {
        return "gemcrafter";
    }

    @Override
    public String version() {
        return JarVersionLookupHandler.getVersion(getClass()).orElse("0.1.0");
    }

    @Override
    public ModContainer loadMod(IModInfo info, ModFileScanData scan, ModuleLayer layer) {
        return new GemcrafterModContainer(info, layer);
    }
}
