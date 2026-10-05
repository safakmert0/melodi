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

// Tum modullerde Java/Kotlin hedefi 17: eski pluginler (dynamic_color 1.7.0,
// on_audio_query_android) Java 8'e kilitli; Kotlin 2.x toolchain ile karisik
// derleme JVM-target dogrulamasini patlatiyor.
// afterEvaluate: modullerin kendi android{} bloklari (1.8) once uygulanir,
// bizim 17 degerimiz finalize ONCESI araya girerek ezer. ':app' haric tutulur
// cunku evaluationDependsOn(":app") onu erken evaluate eder (already evaluated
// hatasi). AGP modeli uzerinden yazilir: JavaCompile task'ina dogrudan
// source/target yazmak eski AGP'lerde (8.1) bootclasspath'i siliyor.
subprojects {
    if (name != "app") {
        afterEvaluate {
            plugins.withId("com.android.library") {
                extensions.configure<com.android.build.gradle.LibraryExtension> {
                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }
                }
            }
            plugins.withId("org.jetbrains.kotlin.android") {
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    kotlinOptions.jvmTarget = JavaVersion.VERSION_17.toString()
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
