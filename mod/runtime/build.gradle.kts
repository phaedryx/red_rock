import java.util.jar.JarFile
import java.util.zip.ZipFile

plugins {
    `java-library`
    id("net.neoforged.moddev") version "2.0.148"
}

val jrubyVersion = property("jruby_version") as String

// JRuby, unpacked into the runtime jar (see tasks.jar) rather than nested with jarJar.
val unpack: Configuration by configurations.creating {
    isCanBeConsumed = false
    isTransitive = false
}
configurations.implementation { extendsFrom(unpack) }

base.archivesName.set("red_rock")

neoForge {
    version = property("neo_version") as String

    mods {
        create("red_rock") {
            sourceSet(sourceSets.main.get())
        }
    }
}

dependencies {
    compileOnly(project(":loader"))

    // Nested in the runtime jar: FML only finds a language loader in its own LIBRARY jar.
    jarJar(project(":loader"))
    // jruby-complete's POM says <packaging>bundle</packaging>, so without an explicit jar
    // artifact Gradle resolves it as POM-only and pulls ~30 unshaded transitive jars instead.
    unpack("org.jruby:jruby-complete") {
        version {
            strictly("[$jrubyVersion,10.2)")
            prefer(jrubyVersion)
        }
        artifact {
            name = "jruby-complete"
            type = "jar"
        }
    }

    testImplementation(platform("org.junit:junit-bom:5.11.4"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    // Plain JUnit, not MDG's unitTest (which boots the whole game): add the few
    // Minecraft-provided libraries the runtime uses, at Minecraft 1.21.1's versions.
    testRuntimeOnly("org.slf4j:slf4j-simple:2.0.9")
    testImplementation("com.google.code.gson:gson:2.10.1")
}

tasks.test {
    useJUnitPlatform()
}

// JRuby goes into the runtime jar unpacked, so FML opens it from disk with the rest of red_rock. A
// nested jar can't be memory-mapped: FML read all 46 MB of it onto the heap each of the three times
// it opened it. org.jruby isn't relocated, because JRuby and its Ruby stdlib name it.
tasks.jar {
    duplicatesStrategy = DuplicatesStrategy.FAIL
    // Gradle doesn't see edits inside a filesMatching action, so its settings are declared as inputs.
    val jrubyLegalFiles = listOf("META-INF/LICENSE*", "META-INF/NOTICE*", "META-INF/COPYING", "META-INF/LEGAL",
        "META-INF/BSDL", "META-INF/thirdparty-LICENSE")
    val jrubyLegalDir = "META-INF/jruby"
    inputs.property("jrubyLegalFiles", jrubyLegalFiles)
    inputs.property("jrubyLegalDir", jrubyLegalDir)
    from(provider { unpack.map { zipTree(it) } }) {
        // red_rock's manifest, not JRuby's: its Automatic-Module-Name would rename the mod's module.
        exclude("META-INF/MANIFEST.MF", "META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA", "META-INF/*.EC")
        // JRuby's license and notice files, kept apart so they don't read as red_rock's own.
        filesMatching(jrubyLegalFiles) {
            path = "$jrubyLegalDir/$name"
        }
        // fastdoubleparser's Java 21 overlay and its module-info. Unused already, as neither jar is
        // Multi-Release.
        exclude("META-INF/versions/**")
    }
}

// The Ruby API in gem/lib is the single source of truth; the runtime ships it as
// classpath resources so JRuby's `require "red_rock"` loads the same code the CLI uses.
tasks.processResources {
    val props = mapOf("red_rock_version" to project.version)
    inputs.properties(props)
    filesMatching("META-INF/neoforge.mods.toml") { expand(props) }
    from("../../gem/lib") {
        into("red_rock/lib")
        exclude("red_rock/cli.rb", "red_rock/cli/**")
    }
}

// Seam check: only the version adapter may touch Minecraft/NeoForge APIs.
val checkSeams by tasks.registering {
    val sources = fileTree("src/main/java/dev/redrock") {
        include("**/*.java")
        exclude("adapter/**")
    }
    inputs.files(sources)
    doLast {
        val pattern = Regex("""^\s*import\s+(static\s+)?net\.(minecraft|neoforged)\.""", RegexOption.MULTILINE)
        val offenders = sources.files.filter { pattern.containsMatchIn(it.readText()) }.map { it.name }.sorted()
        if (offenders.isNotEmpty()) {
            throw GradleException("Minecraft/NeoForge imports outside dev.redrock.adapter: ${offenders.joinToString()}")
        }
    }
}
tasks.check { dependsOn(checkSeams) }

// Jar check: JRuby is unpacked in, not nested. A nested jar can't be memory-mapped, so FML would read
// all of it onto the heap, once per time it opens the jar.
val checkRuntimeJar by tasks.registering {
    val runtimeJar = tasks.jar.flatMap { it.archiveFile }
    val jrubyJars = files(unpack)
    inputs.file(runtimeJar)
    inputs.files(jrubyJars)
    doLast {
        val problems = mutableListOf<String>()
        JarFile(runtimeJar.get().asFile).use { jar ->
            val names = jar.entries().asSequence().map { it.name }.toList()
            names.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
                .forEach { problems += "duplicate entry $it" }
            names.filter { it.startsWith("META-INF/jarjar/") && it.endsWith(".jar") && !it.contains("red_rock-loader") }
                .forEach { problems += "nested jar $it" }
            names.filter { it.endsWith("module-info.class") }.forEach { problems += "stray $it" }
            names.filter { Regex("""META-INF/[^/]+\.(SF|DSA|RSA|EC)""").matches(it) }
                .forEach { problems += "signature file $it" }
            listOf("org/jruby/Ruby.class", "META-INF/jruby.home/lib/ruby/stdlib/json.rb",
                "jruby/java/core_ext.rb", "red_rock/lib/red_rock.rb", "META-INF/neoforge.mods.toml",
                "META-INF/services/dev.redrock.loader.RubyModBootstrap", "META-INF/jruby/LICENSE",
                "META-INF/jruby/NOTICE")
                .filter { it !in names }.forEach { problems += "missing $it" }
            val manifest = jar.manifest.mainAttributes
            listOf("Main-Class", "Automatic-Module-Name", "Multi-Release")
                .filter { manifest.getValue(it) != null }.forEach { problems += "manifest has JRuby's $it" }
            // Every service JRuby declares must reach the runtime jar unchanged.
            jrubyJars.forEach { file ->
                ZipFile(file).use { jruby ->
                    jruby.entries().asSequence().filter { it.name.startsWith("META-INF/services/") && !it.isDirectory }
                        .forEach { service ->
                            val unpacked = jar.getEntry(service.name)
                            val want = jruby.getInputStream(service).readBytes().decodeToString()
                            if (unpacked == null || jar.getInputStream(unpacked).readBytes().decodeToString() != want) {
                                problems += "service ${service.name} differs from JRuby's"
                            }
                        }
                }
            }
        }
        if (problems.isNotEmpty()) {
            throw GradleException("red_rock runtime jar:\n  " + problems.joinToString("\n  "))
        }
    }
}
tasks.check { dependsOn(checkRuntimeJar) }
