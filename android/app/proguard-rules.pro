# Please add these rules to your existing keep rules in order to suppress warnings.
# This is generated automatically by the Android Gradle plugin.
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
-dontwarn org.bouncycastle.jce.provider.BouncyCastleProvider
-dontwarn org.bouncycastle.pqc.jcajce.provider.BouncyCastlePQCProvider
-dontwarn com.fasterxml.jackson.core.**
-dontwarn com.fasterxml.jackson.databind.**
-dontwarn com.google.auto.value.**
-keep class org.xmlpull.v1.** { *; }

# flutter_open_app_settings
#
# R8 cannot resolve this class during analysis even though it is present in the
# built APK (verified: FlutterOpenAppSettingsPlugin is in classes11.dex of a
# debug build). It is referenced from GeneratedPluginRegistrant and reached at
# runtime from profile_page_widget.dart -> openNotificationSettings().
#
# AGP generates only the -dontwarn, which suppresses the build error without
# guaranteeing the class survives shrinking -- that would trade a build failure
# for a ClassNotFoundException when a user opens notification settings. The
# -keep makes survival explicit.
#
# Check before removing: confirm the plugin is still a dependency and the action
# is still reachable.
#   grep -rn "openNotificationSettings" lib
-dontwarn com.josephcrowell.flutter_open_app_settings.FlutterOpenAppSettingsPlugin
-keep class com.josephcrowell.flutter_open_app_settings.** { *; }





