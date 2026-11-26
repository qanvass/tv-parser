package com.quasar.tvparser

import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "main_activity_channel"
    private val WATCH_CHANNEL = "tvparser/watch"
    private val WATCH_TAG = "TVParserWatch"
    private val EXTRA_WATCH_QUERY = "tvp_watch_query"
    private val EXTRA_WATCH_KIND = "tvp_watch_kind"
    private val EXTRA_WATCH_ID = "tvp_watch_id"
    private val EXTRA_WATCH_SEASON = "tvp_watch_season"
    private val EXTRA_WATCH_EPISODE = "tvp_watch_episode"

    private val ACTION_WATCH = "com.quasar.tvparser.WATCH"

    // While the app is on screen a request comes as a broadcast: starting the
    // activity again would pause and resume it, which shuts the Live preview
    // down at the same moment the request wants to hand playback over.
    private val watchReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            deliverWatch(readWatchCommand(intent) ?: return)
        }
    }
    private var watchReceiverOn = false

    private var watchChannel: MethodChannel? = null
    private var pendingWatch: HashMap<String, String>? = null
    private var dartWatchReady = false

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

        // "Play this by name" from the home assistant (see remote_watch_service.dart).
        val watch = MethodChannel(flutterEngine!!.dartExecutor, WATCH_CHANNEL)
        watchChannel = watch
        watch.setMethodCallHandler { call, result ->
            when (call.method) {
                "take" -> {
                    dartWatchReady = true
                    result.success(pendingWatch)
                    pendingWatch = null
                }
                "report" -> {
                    // Names only: never a stream address.
                    android.util.Log.i(
                        WATCH_TAG,
                        "id=${(call.argument<String>("id") ?: "").take(40)} " +
                            "status=${call.argument<String>("status") ?: ""} " +
                            "kind=${call.argument<String>("kind") ?: ""} " +
                            "title=${(call.argument<String>("title") ?: "").take(80)} " +
                            "alts=${(call.argument<String>("alts") ?: "").take(200)}"
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        if (savedInstanceState == null) {
            pendingWatch = readWatchCommand(intent)
        }
        try {
            val filter = IntentFilter(ACTION_WATCH)
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(watchReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(watchReceiver, filter)
            }
            watchReceiverOn = true
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        if (watchReceiverOn) {
            try {
                unregisterReceiver(watchReceiver)
            } catch (_: Exception) {
            }
            watchReceiverOn = false
        }
        super.onDestroy()
    }

    private fun deliverWatch(cmd: HashMap<String, String>) {
        val channel = watchChannel
        if (dartWatchReady && channel != null) {
            channel.invokeMethod("watch", cmd)
        } else {
            pendingWatch = cmd
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        deliverWatch(readWatchCommand(intent) ?: return)
    }

    /// Reads and removes the watch extras so the same command cannot run twice.
    private fun readWatchCommand(intent: Intent?): HashMap<String, String>? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val query = intent.getStringExtra(EXTRA_WATCH_QUERY)?.trim() ?: return null
        val kind = intent.getStringExtra(EXTRA_WATCH_KIND)?.trim() ?: "any"
        val id = intent.getStringExtra(EXTRA_WATCH_ID)?.trim() ?: ""
        intent.removeExtra(EXTRA_WATCH_QUERY)
        intent.removeExtra(EXTRA_WATCH_KIND)
        val season = intent.getStringExtra(EXTRA_WATCH_SEASON)?.trim() ?: ""
        val episode = intent.getStringExtra(EXTRA_WATCH_EPISODE)?.trim() ?: ""
        intent.removeExtra(EXTRA_WATCH_ID)
        intent.removeExtra(EXTRA_WATCH_SEASON)
        intent.removeExtra(EXTRA_WATCH_EPISODE)
        if (query.isEmpty() || query.length > 120) return null
        return hashMapOf(
            "query" to query,
            "kind" to kind,
            "id" to id,
            "season" to season.take(4),
            "episode" to episode.take(4),
        )
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

