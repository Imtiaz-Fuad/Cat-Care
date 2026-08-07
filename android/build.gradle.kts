allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Plugins compiled at API 36 (e.g. file_picker >= 11.0.0,
// flutter_plugin_android_lifecycle >= 2.0.30) all read
// `flutter.compileSdkVersion` from their own android/build.gradle, so they
// automatically inherit the app's `compileSdk = 36` from android/app/build.gradle.kts.
// If a transitive plugin ever needs to be lifted, do it in this file with a
// targeted entry instead of a global `subprojects { afterEvaluate { ... } }`
// reflection block — that pattern hides the override from contributors and
// makes CI failures harder to diagnose.

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
