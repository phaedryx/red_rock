package dev.redrock.loader;

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

/** The container for one Ruby mod. Construction hands the mod to the red_rock runtime. */
public final class RedRockModContainer extends ModContainer {
    private static final Logger LOGGER = LoggerFactory.getLogger("red_rock");

    /**
     * FML's own "failedtoloadmod" wording, used as the issue's translation key. FML falls back to the
     * key as the pattern when it has no translation for it, and formats the Ruby message as plain
     * text. The stock key would render the cause as {@code <java class>: <message>} instead.
     */
    private static final String RUBY_LOAD_ISSUE =
            "{100,modinfo,name} ({100,modinfo,id}) has failed to load correctly\n\u00a77{0}";

    private final IEventBus eventBus;
    private final ModuleLayer layer;

    RedRockModContainer(IModInfo info, ModuleLayer layer) {
        super(info);
        this.layer = layer;
        this.eventBus = BusBuilder.builder()
                .setExceptionHandler(RedRockModContainer::onEventFailed)
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
                        "the red_rock runtime mod is not installed").withAffectedMod(getModInfo())));
        try {
            bootstrap.load(getModInfo(), eventBus);
        } catch (RubyModLoadError e) {
            throw new ModLoadingException(rubyLoadIssue(getModInfo(), e));
        }
    }

    /** The issue players and authors see: Ruby terms only, with no Java cause attached. */
    static ModLoadingIssue rubyLoadIssue(IModInfo info, RubyModLoadError error) {
        return ModLoadingIssue.error(RUBY_LOAD_ISSUE, error.getMessage()).withAffectedMod(info);
    }

    private static void onEventFailed(
            IEventBus bus, Event event, EventListener[] listeners, int busId, Throwable throwable) {
        LOGGER.error("{}", new EventBusErrorMessage(event, busId, listeners, throwable));
    }
}
