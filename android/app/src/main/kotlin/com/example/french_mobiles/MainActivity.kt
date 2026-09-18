package com.example.french_mobiles

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.KeyEvent
import java.net.HttpURLConnection
import java.net.URL
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hideNavigationBar()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        // Android puts the bars back after a dialog, a permission prompt or
        // the keyboard, so the request has to be made again every time the
        // window comes back to the foreground.
        if (hasFocus) hideNavigationBar()
    }

    /// Hides the 3-button navigation bar, leaving the status bar alone.
    ///
    /// BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE is what makes it behave the way
    /// other apps do: a swipe up from the bottom edge floats the buttons over
    /// the content, and they hide again on their own.
    ///
    /// Done here rather than with Flutter's SystemUiMode.immersiveSticky
    /// because that hides the status bar too, taking the clock, battery and
    /// signal with it. Only the navigation bar is meant to go.
    ///
    /// This also takes over edge-to-edge from Dart: asking Flutter for
    /// SystemUiMode.edgeToEdge explicitly shows every bar, which would undo
    /// the hide on startup.
    private fun hideNavigationBar() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        val controller = WindowInsetsControllerCompat(window, window.decorView)
        controller.hide(WindowInsetsCompat.Type.navigationBars())
        controller.systemBarsBehavior =
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
    }

    private lateinit var channel: MethodChannel
    private lateinit var audioChannel: MethodChannel
    private lateinit var proximityChannel: MethodChannel
    private lateinit var powerChannel: MethodChannel
    private lateinit var internetChannel: MethodChannel
    private var volumeListening = false
    private var screenReceiver: BroadcastReceiver? = null
    private var proximityWakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/volume_keys"
        )
        channel.setMethodCallHandler { call, _ ->
            when (call.method) {
                "setVolumeListening" -> {
                    volumeListening = call.argument<Boolean>("enabled") ?: false
                }
            }
        }

        // Whether this device has a receiver at all. Tablets and some
        // handsets have only a loudspeaker, and the earpiece test needs to
        // say so rather than ask the user to listen for a sound that has
        // nowhere to come out.
        //
        // Routing itself is NOT done here. It used to be — setting
        // MODE_IN_COMMUNICATION with the speakerphone off — but that reroutes
        // the voice-call stream, while the audio being played was on the
        // media stream and stayed on the loudspeaker regardless. audioplayers
        // declares the usage on the player, which is what actually reaches
        // the receiver, so the Kotlin side no longer touches the audio mode.
        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/audio_route"
        )
        audioChannel.setMethodCallHandler { call, result ->
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "hasEarpiece" -> {
                    val devices =
                        manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
                    val found = devices.any {
                        it.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                    }
                    result.success(found)
                }
                else -> result.notImplemented()
            }
        }

        // Blanks the screen while the proximity sensor is covered, which is
        // what the phone app does during a call. PROXIMITY_SCREEN_OFF_WAKE_LOCK
        // is the same mechanism; the OS drives the screen directly from the
        // sensor, so Flutter never has to.
        proximityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/proximity_screen"
        )
        proximityChannel.setMethodCallHandler { call, result ->
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            val supported = power.isWakeLockLevelSupported(
                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK
            )
            when (call.method) {
                "isSupported" -> result.success(supported)
                "enable" -> {
                    if (!supported) {
                        result.success(false)
                    } else {
                        if (proximityWakeLock == null) {
                            proximityWakeLock = power.newWakeLock(
                                PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
                                "french_mobiles:proximity"
                            )
                        }
                        val lock = proximityWakeLock
                        if (lock != null && !lock.isHeld) {
                            // Timed, as a backstop: if anything fails to
                            // release it, the OS does after two minutes
                            // rather than leaving the screen dark.
                            lock.acquire(2 * 60 * 1000L)
                        }
                        result.success(true)
                    }
                }
                "disable" -> {
                    releaseProximityWakeLock()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        powerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/power_button"
        )
        powerChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startWatching" -> {
                    startWatchingScreen()
                    result.success(true)
                }
                "stopWatching" -> {
                    stopWatchingScreen()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        internetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/internet"
        )
        internetChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "probeCellular" -> probeCellularInternet(result)
                else -> result.notImplemented()
            }
        }
    }

    /// Watches the screen going off and coming back.
    ///
    /// Android reserves the power key — KEYCODE_POWER never reaches an app, so
    /// the press itself cannot be observed. What can be observed is its
    /// effect: the screen turning off, and then coming back on. A test that
    /// sees both has watched the button do its job, which is a great deal
    /// better than asking the user whether it worked.
    ///
    /// Registered at runtime rather than in the manifest: ACTION_SCREEN_OFF
    /// and ACTION_SCREEN_ON are not delivered to manifest-declared receivers.
    private fun startWatchingScreen() {
        if (screenReceiver != null) return

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val event = when (intent?.action) {
                    Intent.ACTION_SCREEN_OFF -> "screen_off"
                    Intent.ACTION_SCREEN_ON -> "screen_on"
                    Intent.ACTION_USER_PRESENT -> "user_present"
                    else -> return
                }
                powerChannel.invokeMethod("screenEvent", mapOf("event" to event))
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(receiver, filter)
        screenReceiver = receiver
    }

    private fun stopWatchingScreen() {
        val receiver = screenReceiver ?: return
        screenReceiver = null
        try {
            unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Already gone; nothing to undo.
        }
    }

    /// Checks whether the cellular radio can actually reach the internet.
    ///
    /// The point of doing this natively: an HTTP request from Dart goes out
    /// over whatever route Android picks, which is Wi-Fi whenever Wi-Fi is
    /// connected. A phone with a registered SIM and dead mobile data
    /// therefore passes an ordinary connectivity check — the exact failure
    /// this is meant to catch.
    ///
    /// requestNetwork with TRANSPORT_CELLULAR asks for the cellular network
    /// specifically, and Network.openConnection sends the probe over that
    /// network whatever else the phone is connected to.
    private fun probeCellularInternet(result: MethodChannel.Result) {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE)
            as ConnectivityManager
        val main = Handler(Looper.getMainLooper())
        var replied = false

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        lateinit var callback: ConnectivityManager.NetworkCallback

        fun reply(outcome: Map<String, Any?>) {
            main.post {
                if (replied) return@post
                replied = true
                try {
                    manager.unregisterNetworkCallback(callback)
                } catch (_: Exception) {
                    // Already gone.
                }
                result.success(outcome)
            }
        }

        callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                // Networking is forbidden on the main thread.
                Thread { reply(probeThrough(network)) }.start()
            }

            override fun onUnavailable() {
                reply(mapOf("status" to "no_cellular"))
            }
        }

        try {
            manager.requestNetwork(request, callback)
        } catch (e: Exception) {
            result.success(
                mapOf("status" to "error", "message" to (e.message ?: "\$e"))
            )
            return
        }

        // The two-argument requestNetwork never times out by itself, so the
        // deadline is ours. Without it a phone with no cellular coverage
        // would leave the test waiting forever.
        main.postDelayed({ reply(mapOf("status" to "no_cellular")) }, 20_000)
    }

    /// Runs the captive-portal probe over one specific network.
    private fun probeThrough(network: Network): Map<String, Any?> {
        var connection: HttpURLConnection? = null
        return try {
            val url = URL("https://connectivitycheck.gstatic.com/generate_204")
            connection = network.openConnection(url) as HttpURLConnection
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.instanceFollowRedirects = false
            connection.useCaches = false

            val startedAt = System.currentTimeMillis()
            connection.connect()
            val code = connection.responseCode
            val millis = System.currentTimeMillis() - startedAt

            mapOf(
                // 204 with no body is the whole point of this endpoint: any
                // other reply means something answered instead of the
                // internet, which is a portal, not a connection.
                "status" to if (code == 204) "ok" else "captive",
                "code" to code,
                "ms" to millis
            )
        } catch (e: Exception) {
            mapOf("status" to "unreachable", "message" to (e.message ?: "\$e"))
        } finally {
            connection?.disconnect()
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel.setMethodCallHandler(null)
        audioChannel.setMethodCallHandler(null)
        // A receiver outliving the engine would fire into a dead channel.
        stopWatchingScreen()
        powerChannel.setMethodCallHandler(null)
        internetChannel.setMethodCallHandler(null)
        // A leaked proximity wake lock leaves the screen dark whenever the
        // sensor is covered, with no way back. Release it unconditionally.
        releaseProximityWakeLock()
        proximityChannel.setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onStop() {
        // Backgrounding the app while the lock is held would let it keep
        // blanking the screen outside the test that asked for it.
        //
        // onStop rather than onPause: a proximity blank does not background
        // the activity, but onPause fires for transient things that should
        // not end the test.
        releaseProximityWakeLock()
        super.onStop()
    }

    private fun releaseProximityWakeLock() {
        val lock = proximityWakeLock ?: return
        proximityWakeLock = null
        if (!lock.isHeld) return
        // WAIT_FOR_NO_PROXIMITY, so the screen does not snap back on while
        // the phone is still against the user's ear.
        lock.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY)
    }

    // Intercept hardware volume keys while the checkup's side-button test is
    // active so the device volume is left untouched and presses can be reported
    // to Flutter via the method channel.
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val isVolumeKey = keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (volumeListening && isVolumeKey) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                channel.invokeMethod(
                    "volumeKey",
                    mapOf(
                        "key" to if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                            "volume_up"
                        } else {
                            "volume_down"
                        }
                    )
                )
            }
            // Consume the event so the system volume stays unchanged.
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}