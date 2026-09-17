package com.example.french_mobiles

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.os.PowerManager
import android.view.KeyEvent
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
    private var volumeListening = false
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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel.setMethodCallHandler(null)
        audioChannel.setMethodCallHandler(null)
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