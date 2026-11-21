# flutter_local_notifications (الأذان، DECISIONS ٢٨): المكتبة تخزّن الإشعارات المجدولة بـGson وتقرأها بـTypeToken،
# وR8 (تصغير الإصدار) يحذف معلومات الأنواع العامة فتفشل الجدولة بـ«Missing type parameter» دون ظهور شيء للمستخدم.
# القواعد الموصى بها في وثائق المكتبة.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
