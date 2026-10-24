package dev.gemcrafter.adapter.v1_21_1;

import dev.gemcrafter.runtime.ItemSpec;
import dev.gemcrafter.runtime.ModManifest;
import java.util.ArrayList;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.event.BuildCreativeModeTabContentsEvent;
import net.neoforged.neoforge.registries.DeferredItem;
import net.neoforged.neoforge.registries.DeferredRegister;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** Registers a Ruby mod's declared content with Minecraft's registries, on that mod's own bus. */
public final class ContentRegistrar {
    private static final Logger LOGGER = LoggerFactory.getLogger("gemcrafter");

    private ContentRegistrar() {}

    public static void register(ModManifest m, IEventBus modBus) {
        var items = DeferredRegister.createItems(m.modId());
        var registered = new ArrayList<DeferredItem<Item>>();
        for (ItemSpec spec : m.items()) {
            registered.add(items.registerSimpleItem(spec.id(), new Item.Properties().stacksTo(spec.stackSize())));
            LOGGER.info("[gemcrafter] {}: registered item {}:{}", m.modId(), m.modId(), spec.id());
        }
        items.register(modBus);
        modBus.addListener(BuildCreativeModeTabContentsEvent.class, e -> {
            if (e.getTabKey() == CreativeModeTabs.INGREDIENTS) {
                registered.forEach(e::accept);
            }
        });
    }
}
