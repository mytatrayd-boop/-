package sa.lamha.lamha

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/// «تشخيص لمحة»: أيقونة مستقلة لا تشغّل Flutter، تعرض أسباب انهيار لمحة على هذا الجهاز (LamhaCrashLog)
/// ليصوّرها المالك ويرسلها. مؤقتة حتى يُحسم بلاغ الانهيار على أندرويد.
class DiagActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = LamhaCrashLog.report(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            fitsSystemWindows = true
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        fun button(label: String, action: () -> Unit) = Button(this).apply {
            this.text = label
            setOnClickListener { action() }
            bar.addView(this, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        }
        button("نسخ") {
            (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                .setPrimaryClip(ClipData.newPlainText("lamha-diag", text))
            Toast.makeText(this, "تم النسخ", Toast.LENGTH_SHORT).show()
        }
        button("مشاركة") {
            startActivity(
                Intent.createChooser(
                    Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text),
                    "مشاركة التقرير",
                ),
            )
        }
        button("مسح السجل") {
            LamhaCrashLog.clear(this)
            recreate()
        }
        root.addView(bar)
        val body = TextView(this).apply {
            this.text = text
            textSize = 12f
            setTextColor(Color.BLACK)
            setTextIsSelectable(true)
            setPadding(24, 16, 24, 48)
            textDirection = View.TEXT_DIRECTION_LTR
            gravity = Gravity.START
        }
        root.addView(ScrollView(this).apply { addView(body) }, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
    }
}
