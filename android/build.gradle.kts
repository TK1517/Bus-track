buildscript {
    repositories {
        google()           // <--- THIS IS MISSING
        mavenCentral()     // <--- THIS IS MISSING
    }

    dependencies {
        // Also, use version 4.4.2 as 4.4.4 might not exist yet
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}