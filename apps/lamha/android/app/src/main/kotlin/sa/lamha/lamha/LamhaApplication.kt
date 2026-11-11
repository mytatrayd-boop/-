package sa.lamha.lamha

import android.app.Application

/// يركّب سجل الأعطال قبل أي شيء آخر (LamhaCrashLog).
class LamhaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        LamhaCrashLog.install(this)
    }
}
