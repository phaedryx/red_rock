subprojects {
    group = "dev.gemcrafter"
    version = property("gemcrafter_version") as String

    repositories {
        mavenCentral()
    }

    tasks.withType<JavaCompile>().configureEach {
        options.encoding = "UTF-8"
        options.release.set(21)
    }
}
