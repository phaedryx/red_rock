plugins {
    `java-library`
    id("net.neoforged.moddev") version "2.0.148"
}

val jrubyVersion = property("jruby_version") as String

base.archivesName.set("gemcrafter")

neoForge {
    version = property("neo_version") as String

    mods {
        create("gemcrafter") {
            sourceSet(sourceSets.main.get())
        }
    }
}

dependencies {
    compileOnly(project(":loader"))

    // Shipped inside the runtime jar: the language loader (a LIBRARY jar) and JRuby.
    jarJar(project(":loader"))
    // jruby-complete's POM says <packaging>bundle</packaging>, so without an explicit jar
    // artifact Gradle resolves it as POM-only and pulls ~30 unshaded transitive jars instead.
    jarJar(implementation("org.jruby:jruby-complete") {
        version {
            strictly("[$jrubyVersion,10.2)")
            prefer(jrubyVersion)
        }
        artifact {
            name = "jruby-complete"
            type = "jar"
        }
        isTransitive = false
    })

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

// The Ruby API in gem/lib is the single source of truth; the runtime ships it as
// classpath resources so JRuby's `require "gemcrafter"` loads the same code the CLI uses.
tasks.processResources {
    val props = mapOf("gemcrafter_version" to project.version)
    inputs.properties(props)
    filesMatching("META-INF/neoforge.mods.toml") { expand(props) }
    from("../../gem/lib") {
        into("gemcrafter/lib")
        exclude("gemcrafter/cli.rb", "gemcrafter/cli/**")
    }
}

// Seam check: only the version adapter may touch Minecraft/NeoForge APIs.
val checkSeams by tasks.registering {
    val sources = fileTree("src/main/java/dev/gemcrafter") {
        include("**/*.java")
        exclude("adapter/**")
    }
    inputs.files(sources)
    doLast {
        val pattern = Regex("""^\s*import\s+(static\s+)?net\.(minecraft|neoforged)\.""", RegexOption.MULTILINE)
        val offenders = sources.files.filter { pattern.containsMatchIn(it.readText()) }.map { it.name }.sorted()
        if (offenders.isNotEmpty()) {
            throw GradleException("Minecraft/NeoForge imports outside dev.gemcrafter.adapter: ${offenders.joinToString()}")
        }
    }
}
tasks.check { dependsOn(checkSeams) }
