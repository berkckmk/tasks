# R8/ProGuard keep rules for the release build.
#
# Most of what this app uses is already covered by consumer rules shipped
# inside the Firebase, Play Billing and Flutter artifacts. The rules below
# cover the cases those don't, plus the ones that only surface as a runtime
# crash in a shrunk build (never at compile time), which is why they're worth
# stating explicitly rather than discovering in Crashlytics.

# Keep line numbers and source file names so Crashlytics stack traces stay
# readable after deobfuscation with the uploaded mapping file.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Generic signatures and annotations are read reflectively by Firestore's
# POJO serialisation and by Gson-style converters inside the Google API
# clients; stripping them turns into an obscure runtime failure.
-keepattributes Signature,*Annotation*,EnclosingMethod,InnerClasses

# Firebase / Google Play Services.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Play Billing, used by in_app_purchase.
-keep class com.android.billingclient.api.** { *; }
-dontwarn com.android.billingclient.**

# Flutter embedding and deferred components. The deferred-component classes
# are referenced by the engine even when the feature is unused, which
# otherwise produces "missing class" warnings that fail the build.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Kotlin coroutines internals touched reflectively.
-dontwarn kotlinx.coroutines.**
