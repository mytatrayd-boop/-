package com.rased.app;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

// راصد: نفس واجهة الويب من assets/index.html. طلبات الأسعار تمر من هنا (Java) لأن WebView
// يمنع طلبات الصفحة المحلية لمواقع ثانية (CORS). المفاتيح تبقى على الجوال.
public class MainActivity extends Activity {
    // الجسر يرد فقط على مواقع الأسعار — أي رابط ثاني يُرفض
    private static final Set<String> ALLOWED_HOSTS = new HashSet<>(Arrays.asList(
            "api.polygon.io", "api.massive.com", "www.alphavantage.co",
            "raw.githubusercontent.com"));  // نتائج مختبر الاتجاهات (top5.json / backtest.json)

    private WebView web;
    private final ExecutorService pool = Executors.newFixedThreadPool(3);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        web.setBackgroundColor(0xFF0A0D12);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        web.addJavascriptInterface(new Bridge(), "RasedNative");
        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri u = request.getUrl();
                if ("file".equals(u.getScheme())) return false;
                // روابط يقين و Yahoo تنفتح في المتصفح
                try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) { }
                return true;
            }
        });
        setContentView(web);
        web.loadUrl("file:///android_asset/index.html");
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    @Override
    protected void onDestroy() {
        pool.shutdownNow();
        web.destroy();
        super.onDestroy();
    }

    private static String readAll(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[16384];
        int n;
        while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
        in.close();
        return out.toString("UTF-8");
    }

    private class Bridge {
        // يجلب url ويرد على window.__rasedHttp(id, status, body) — status=0 يعني فشل الاتصال
        @JavascriptInterface
        public void get(final String id, final String url) {
            pool.execute(() -> {
                int status = 0;
                String body;
                HttpURLConnection c = null;
                try {
                    URL u = new URL(url);
                    if (!"https".equals(u.getProtocol()) || !ALLOWED_HOSTS.contains(u.getHost())) {
                        throw new IOException("host not allowed");
                    }
                    c = (HttpURLConnection) u.openConnection();
                    c.setConnectTimeout(20000);
                    c.setReadTimeout(90000);
                    c.setRequestProperty("Accept", "application/json");
                    status = c.getResponseCode();
                    InputStream in = status >= 400 ? c.getErrorStream() : c.getInputStream();
                    body = in == null ? "" : readAll(in);
                } catch (Exception e) {
                    status = 0;
                    body = String.valueOf(e.getMessage());
                } finally {
                    if (c != null) c.disconnect();
                }
                final String js = "window.__rasedHttp(" + JSONObject.quote(id) + "," + status + "," + JSONObject.quote(body) + ")";
                web.post(() -> web.evaluateJavascript(js, null));
            });
        }

        // الشاشة تبقى شغالة أثناء التعبئة الأولى (~15 دقيقة) عشان ما يوقف الجلب
        @JavascriptInterface
        public void keepAwake(final boolean on) {
            runOnUiThread(() -> {
                if (on) getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                else getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            });
        }
    }
}
