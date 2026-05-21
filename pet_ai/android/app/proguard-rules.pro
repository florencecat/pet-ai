-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson rules (official)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

-dontwarn sun.misc.**

-keep class com.google.gson.** { *; }

# Generic signatures of TypeToken and its subclasses (R8 fullMode)
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# flutter_local_notifications internal Gson models
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.** { *; }

# xmlpull (вторая частая ошибка R8 fullMode с этим плагином)
-keep class org.xmlpull.** { *; }
-dontwarn org.xmlpull.**