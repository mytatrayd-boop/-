package sa.lamha.lamha.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import sa.lamha.lamha.R

/// إشعار شاشة القفل الثابت (الميزة ٣ج، DECISIONS ١٣): اختياري ومطفأ افتراضياً (lockNotification في
/// الجدول). ongoing، وأولوية منخفضة بلا صوت، وظاهر كاملاً في شاشة القفل (VISIBILITY_PUBLIC)،
/// وعدّاد تنازلي من النظام حتى الصلاة القادمة. يُحدَّث مع تحديثات الودجت، ويُلغى عند إطفاء المفتاح.
object LamhaNotification {
    private const val CHANNEL_ID = "lamha_lock_screen"
    private const val NOTIFICATION_ID = 1027

    fun refresh(context: Context, day: LamhaDay?) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val next = day?.nextPrayer
        if (day == null || !day.lockNotification || next == null) {
            nm.cancel(NOTIFICATION_ID)
            return
        }
        val ctx = LamhaWidgetReceiver.arabic(context)
        val deposit = day.deposits.firstOrNull()
        val (title, text) = LamhaLogic.notificationLines(
            next, day.qiblaDegrees, deposit?.label, deposit?.after,
            ctx.getString(R.string.notification_title), ctx.getString(R.string.notification_qibla),
            ctx.getString(R.string.notification_deposit), ctx.getString(R.string.notification_join),
        )
        val builder: Notification.Builder
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, ctx.getString(R.string.notification_channel), NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = ctx.getString(R.string.notification_channel_description)
            channel.setSound(null, null)
            channel.enableVibration(false)
            channel.setShowBadge(false)
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(channel)
            builder = Notification.Builder(context, CHANNEL_ID)
        } else {
            builder = legacyBuilder(context)
        }
        val (accent, _) = LamhaWidgetReceiver.colors(context, day)
        builder
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(accent)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(true)
            .setWhen(next.atMillis)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setContentIntent(LamhaWidgetReceiver.openAppIntent(context))
        try {
            // بلا إذن POST_NOTIFICATIONS (أندرويد ١٣+) لا يظهر شيء؛ Dart يطلبه قبل التشغيل.
            nm.notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // لا إذن.
        }
    }

    /// أندرويد ٧ (قبل القنوات): الأولوية والصوت على الإشعار نفسه.
    @Suppress("DEPRECATION")
    private fun legacyBuilder(context: Context): Notification.Builder =
        Notification.Builder(context).setPriority(Notification.PRIORITY_LOW).setSound(null)
}
