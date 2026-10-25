subprojects {
    group = "dev.redrock"
    version = property("red_rock_version") as String

    repositories {
        mavenCentral()
    }

    tasks.withType<JavaCompile>().configureEach {
        options.encoding = "UTF-8"
        options.release.set(21)
    }
}
