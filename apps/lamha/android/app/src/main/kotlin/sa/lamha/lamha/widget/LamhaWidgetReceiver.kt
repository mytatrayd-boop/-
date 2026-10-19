package sa.lamha.lamha.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetScheduler

/// مستقبل الودجت. Dart يطلب تحديثه بالاسم الكامل (qualifiedAndroidName في services.dart).
/// بعد كل تحديث تُعاد جدولة التحديثات القادمة من الجدول: كل صلاة، ومنتصف الليل، والظهر.
/// المنبهات من HomeWidgetScheduler (غير دقيقة بلا إذن SCHEDULE_EXACT_ALARM)، وتُستعاد بعد
/// إعادة التشغيل عبر HomeWidgetScheduledUpdateReceiver في AndroidManifest (DECISIONS ١٠).
class LamhaWidgetReceiver : HomeWidgetGlanceWidgetReceiver<LamhaWidget>() {

    override val glanceAppWidget = LamhaWidget()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val json = HomeWidgetPlugin.getData(context).getString(LamhaWidget.SCHEDULE_KEY, null)
        HomeWidgetScheduler.schedule(
            context,
            LamhaWidgetReceiver::class.java.name,
            LamhaSchedule.updateTimes(json, System.currentTimeMillis()),
        )
    }
}
