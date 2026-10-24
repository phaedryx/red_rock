package dev.gemcrafter.runtime;

import java.io.IOException;
import java.net.URL;
import java.util.Enumeration;

/**
 * The class loader JRuby is given. Under NeoForge, JRuby and gemcrafter live in different module
 * layers: the game layer can load JRuby's classes, but plain resources don't cross layers, so
 * neither loader alone sees both JRuby's own {@code .rb} files and gemcrafter's API sources.
 * Classes come from the parent (the game layer); resources the parent lacks come from JRuby's layer.
 */
final class LayeredResourceClassLoader extends ClassLoader {
    static {
        registerAsParallelCapable();
    }

    private final ClassLoader jrubyLayer;

    LayeredResourceClassLoader(ClassLoader parent, ClassLoader jrubyLayer) {
        super("gemcrafter-jruby", parent);
        this.jrubyLayer = jrubyLayer;
    }

    @Override
    protected URL findResource(String name) {
        return jrubyLayer.getResource(name);
    }

    @Override
    protected Enumeration<URL> findResources(String name) throws IOException {
        return jrubyLayer.getResources(name);
    }
}
