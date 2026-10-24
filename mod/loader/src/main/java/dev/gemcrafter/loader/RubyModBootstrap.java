package dev.gemcrafter.loader;

import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforgespi.language.IModInfo;

/**
 * Implemented by the gemcrafter runtime (game layer), found through {@link java.util.ServiceLoader}.
 * The loader lives in a lower layer and cannot see game classes, so it calls across this interface.
 */
public interface RubyModBootstrap {
    /**
     * Evaluates the Ruby mod and registers its content on {@code modBus}.
     *
     * @throws RubyModLoadError when the mod's Ruby code fails, with a message in Ruby terms
     */
    void load(IModInfo info, IEventBus modBus);
}
