package com.quasar.tvparser

import android.app.UiModeManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "main_activity_channel"

    override fun onCreate(savedInstanceState: Bundle?) {
        forceCorrectOrientationBeforeFlutter()
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine!!.dartExecutor, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getData") {
                val dd = resources.getString(R.string.unique_key)
                result.success(dd)
            } else if (call.method == "isTvDevice") {
                result.success(shouldUseTvLayout())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun forceCorrectOrientationBeforeFlutter() {
        val isTv = shouldUseTvLayout()

        requestedOrientation = if (isTv) {
            ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        }

        android.util.Log.d(
            "OrientationGuard",
            "NATIVE BOOT platform=${if (isTv) "tv" else "mobile"}"
        )
    }

    private fun shouldUseTvLayout(): Boolean {
        val isLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        val isTelevision = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION

        // A landscape phone emulator may exercise the TV UI in debug builds only.
        // Release builds rely exclusively on Android's native TV capability flags.
        val isDebugLandscapeEmulator = BuildConfig.DEBUG && isEmulator() &&
            resources.displayMetrics.widthPixels > resources.displayMetrics.heightPixels

        return isLeanback || isTelevision || isDebugLandscapeEmulator
    }

    private fun isEmulator(): Boolean {
        return android.os.Build.FINGERPRINT.startsWith("generic")
            || android.os.Build.FINGERPRINT.startsWith("unknown") 
            || android.os.Build.MODEL.contains("google_sdk") 
            || android.os.Build.MODEL.contains("Emulator") 
            || android.os.Build.MODEL.contains("Android SDK built for x86")
            || android.os.Build.MODEL.contains("sdk")
            || android.os.Build.HARDWARE.contains("ranchu")
            || android.os.Build.HARDWARE.contains("goldfish")
    }
}

