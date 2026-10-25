package dev.redrock.runtime;

/** One item a Ruby mod declared, as plain data the adapter can register. */
public record ItemSpec(String id, String texture, int stackSize, String displayName) {}
