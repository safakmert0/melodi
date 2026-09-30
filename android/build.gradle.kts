allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8 zorunlulugu: namespace bildirmeyen eski Android kutuphanesi
// (on_audio_query_android 1.1.0) manifest paketini namespace olarak alir.
// Diger kutuphanelere dokunulmaz.
subprojects {
    if (name == "on_audio_query_android") {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "com.lucasjosino.on_audio_query"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
