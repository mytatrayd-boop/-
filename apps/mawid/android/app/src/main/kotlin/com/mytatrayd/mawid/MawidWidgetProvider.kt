package com.mytatrayd.mawid

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/// ودجت «المتبقي إلى موعد الصرف». التطبيق يكتب JSON في HomeWidgetPreferences
/// (انظر lib/core/widget_sync.dart)، والودجت يحسب الأيام المتبقية بنفسه عند كل تحديث.
class MawidWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val payload = prefs.getString("payload", null)
        for (id in ids) manager.updateAppWidget(id, build(context, payload))
    }

    private fun leftText(d: Long): String = when {
        d == 0L -> "اليوم"
        d == 1L -> "غداً"
        d == 2L -> "بعد يومين"
        d <= 10L -> "بعد $d أيام"
        else -> "بعد $d يوماً"
    }

    private fun build(context: Context, payload: String?): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.mawid_widget)
        val rows = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3)
        val names = intArrayOf(R.id.name0, R.id.name1, R.id.name2, R.id.name3)
        val days = intArrayOf(R.id.days0, R.id.days1, R.id.days2, R.id.days3)
        for (r in rows) v.setViewVisibility(r, View.GONE)
        v.setViewVisibility(R.id.empty, View.GONE)

        var shown = 0
        try {
            if (payload != null) {
                val json = JSONObject(payload)
                val color = json.optLong("color", 0xFF1C2B4BL).toInt()
                v.setTextColor(R.id.title, color)
                val items = json.getJSONArray("items")
                val today = LocalDate.now()
                for (i in 0 until minOf(items.length(), 4)) {
                    val item = items.getJSONObject(i)
                    val dates = item.getJSONArray("dates")
                    var next: LocalDate? = null
                    for (k in 0 until dates.length()) {
                        val d = LocalDate.parse(dates.getString(k))
                        if (!d.isBefore(today)) { next = d; break }
                    }
                    v.setViewVisibility(rows[i], View.VISIBLE)
                    v.setTextViewText(names[i], item.getString("name"))
                    v.setTextColor(days[i], color)
                    v.setTextViewText(
                        days[i],
                        if (next == null) "افتح التطبيق" else leftText(ChronoUnit.DAYS.between(today, next))
                    )
                    shown++
                }
            }
        } catch (e: Exception) {
            shown = 0
        }
        if (shown == 0) v.setViewVisibility(R.id.empty, View.VISIBLE)

        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            val pi = PendingIntent.getActivity(
                context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            v.setOnClickPendingIntent(R.id.root, pi)
        }
        return v
    }
}
