package com.example.french_mobiles

import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private lateinit var channel: MethodChannel
    private lateinit var audioChannel: MethodChannel
    private var volumeListening = false

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
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel.setMethodCallHandler(null)
        audioChannel.setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
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