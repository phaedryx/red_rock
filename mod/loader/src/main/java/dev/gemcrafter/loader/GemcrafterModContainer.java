package dev.gemcrafter.loader;

import java.util.ServiceLoader;
import net.neoforged.bus.EventBusErrorMessage;
import net.neoforged.bus.api.BusBuilder;
import net.neoforged.bus.api.Event;
import net.neoforged.bus.api.EventListener;
import net.neoforged.bus.api.IEventBus;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.ModLoadingException;
import net.neoforged.fml.ModLoadingIssue;
import net.neoforged.fml.event.IModBusEvent;
import net.neoforged.neoforgespi.language.IModInfo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/** The container for one Ruby mod. Construction hands the mod to the gemcrafter runtime. */
public final class GemcrafterModContainer extends ModContainer {
    private static final Logger LOGGER = LoggerFactory.getLogger("gemcrafter");

    private final IEventBus eventBus;
    private final ModuleLayer layer;

    GemcrafterModContainer(IModInfo info, ModuleLayer layer) {
        super(info);
        this.layer = layer;
        this.eventBus = BusBuilder.builder()
                .setExceptionHandler(GemcrafterModContainer::onEventFailed)
                .markerType(IModBusEvent.class)
                .allowPerPhasePost()
                .build();
    }

    @Override
    public IEventBus getEventBus() {
        return eventBus;
    }

    @Override
    protected void constructMod() {
        RubyModBootstrap bootstrap = ServiceLoader.load(layer, RubyModBootstrap.class).findFirst()
                .orElseThrow(() -> new ModLoadingException(ModLoadingIssue.error(
                        "fml.modloadingissue.failedtoloadmod",
                        "the gemcrafter runtime mod is not installed").withAffectedMod(getModInfo())));
        try {
            bootstrap.load(getModInfo(), eventBus);
        } catch (RubyModLoadError e) {
            // The displayed issue's text is the cause's message: Ruby terms, no Java frames.
            throw new ModLoadingException(ModLoadingIssue.error("fml.modloadingissue.failedtoloadmod")
                    .withCause(e)
                    .withAffectedMod(getModInfo()));
        }
    }

    private static void onEventFailed(
            IEventBus bus, Event event, EventListener[] listeners, int busId, Throwable throwable) {
        LOGGER.error("{}", new EventBusErrorMessage(event, busId, listeners, throwable));
    }
}
