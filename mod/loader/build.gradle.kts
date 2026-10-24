plugins {
    `java-library`
    id("net.neoforged.moddev") version "2.0.148"
}

base.archivesName.set("gemcrafter-loader")

neoForge {
    version = property("neo_version") as String
}

dependencies {
    testImplementation(platform("org.junit:junit-bom:5.11.4"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    // MDG only puts NeoForge on the main classpath; the tests need FML's SPI types too.
    testImplementation("net.neoforged.fancymodloader:loader:4.0.45")
}

tasks.test {
    useJUnitPlatform()
}

tasks.jar {
    manifest.attributes(
        // A language loader must live in a LIBRARY jar; FML reads its version from here.
        "FMLModType" to "LIBRARY",
        "Implementation-Version" to project.version,
    )
}
