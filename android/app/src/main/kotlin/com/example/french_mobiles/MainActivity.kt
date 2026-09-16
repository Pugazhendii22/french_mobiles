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
    private var previousAudioMode: Int? = null

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

        // Earpiece routing for the checkup's earpiece test. flutter_tts has no
        // API for this on Android: TTS goes to STREAM_MUSIC (the loudspeaker)
        // unless the audio mode is switched to in-communication and the
        // speakerphone is turned off, which is only reachable from native.
        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "french_mobiles/audio_route"
        )
        audioChannel.setMethodCallHandler { call, result ->
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "routeToEarpiece" -> {
                    if (previousAudioMode == null) {
                        previousAudioMode = manager.mode
                    }
                    manager.mode = AudioManager.MODE_IN_COMMUNICATION
                    @Suppress("DEPRECATION")
                    manager.isSpeakerphoneOn = false
                    result.success(true)
                }
                "routeToSpeaker" -> {
                    manager.mode = previousAudioMode ?: AudioManager.MODE_NORMAL
                    @Suppress("DEPRECATION")
                    manager.isSpeakerphoneOn = true
                    previousAudioMode = null
                    result.success(true)
                }
                "hasEarpiece" -> {
                    // Tablets and some devices have no receiver at all.
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
        // Leaving the device in MODE_IN_COMMUNICATION would keep every later
        // sound routed to the earpiece, so restore it unconditionally.
        previousAudioMode?.let {
            val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.mode = it
            @Suppress("DEPRECATION")
            manager.isSpeakerphoneOn = true
            previousAudioMode = null
        }
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