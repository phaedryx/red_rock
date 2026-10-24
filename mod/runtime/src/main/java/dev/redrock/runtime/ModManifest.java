package dev.redrock.runtime;

import java.util.List;

/** Everything a Ruby mod declared, converted out of Ruby so the adapter never touches JRuby. */
public record ModManifest(String modId, String version, String displayName, List<ItemSpec> items) {
    public ModManifest {
        items = List.copyOf(items);
    }
}
