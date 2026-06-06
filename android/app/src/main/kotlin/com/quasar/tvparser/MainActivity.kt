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
                val isLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
                val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                val isTelevision = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                result.success(isLeanback || isTelevision)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun forceCorrectOrientationBeforeFlutter() {
        val isLeanback = packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        val isTelevision = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION

        if (isLeanback || isTelevision) {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            android.util.Log.d("OrientationGuard", "NATIVE BOOT platform=tv applied=landscape")
        } else {
            requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            android.util.Log.d("OrientationGuard", "NATIVE BOOT platform=mobile applied=portrait")
        }

        android.util.Log.d(
            "OrientationGuard",
            "features leanback=$isLeanback television=$isTelevision mode=${uiModeManager.currentModeType}"
        )
    }
}

