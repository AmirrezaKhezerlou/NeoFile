# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SharedPreferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class * extends io.flutter.plugins.sharedpreferences.** { *; }

# AndroidPdfViewer & PDF View
-dontwarn com.github.barteksc.pdfviewer.**
-keep class com.github.barteksc.pdfviewer.** { *; }
-keep class com.shockwave.** { *; }

# Play Core deferred components warnings suppression
-dontwarn com.google.android.play.core.**

# Native methods
-keepclasseswithmembers class * {
    native <methods>;
}

-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
