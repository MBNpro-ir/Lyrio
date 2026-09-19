package com.mbn.lyrio
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LyrioCore.init(this)
        NativeBridge.attach(flutterEngine, this, this)
    }
    override fun onResume() {
        super.onResume()
        LyrioCore.activityVisible = true
        LyrioCore.init(this)
        if (LyrioCore.lyrics.optString("status") == "idle") LyrioCore.fetch()
    }
    override fun onStop() {
        LyrioCore.activityVisible = false
        super.onStop()
    }
}
