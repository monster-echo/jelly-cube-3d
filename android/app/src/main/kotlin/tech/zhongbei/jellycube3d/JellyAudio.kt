package tech.zhongbei.jellycube3d

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Plays the Dart-synthesised 44.1 kHz mono PCM buffers without any audio
 * assets. Each voice is a short static AudioTrack and is released when the
 * sample has finished. Failures degrade to silence.
 */
class JellyAudio(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val tracks = mutableListOf<AudioTrack>()

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "init" -> result.success(null)
                "play" -> {
                    val pcm = toFloats(call.argument<Any>("pcm"))
                    if (pcm == null || pcm.isEmpty()) {
                        result.success(null)
                        return
                    }
                    val volume = ((call.argument<Number>("volume") ?: 1.0).toFloat())
                        .coerceIn(0f, 1f)
                    play(pcm, volume)
                    result.success(null)
                }
                "dispose" -> {
                    dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) {
            result.success(null)
        }
    }

    private fun play(samples: FloatArray, volume: Float) {
        if (tracks.size >= MAX_VOICES) return
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(samples.size * 4)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        val written = track.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
        if (written <= 0) {
            track.release()
            return
        }
        track.setVolume(volume)
        track.play()
        tracks.add(track)
        val lifeMs = (samples.size / 44.1f).toLong() + 260L
        mainHandler.postDelayed({
            try {
                track.stop()
            } catch (_: Throwable) {
            }
            try {
                track.release()
            } catch (_: Throwable) {
            }
            tracks.remove(track)
        }, lifeMs)
    }

    private fun toFloats(value: Any?): FloatArray? = when (value) {
        is FloatArray -> value
        is DoubleArray -> FloatArray(value.size) { value[it].toFloat() }
        is ByteArray -> {
            val buffer = ByteBuffer.wrap(value).order(ByteOrder.LITTLE_ENDIAN)
            FloatArray(value.size / 4) { buffer.float }
        }
        else -> null
    }

    fun dispose() {
        mainHandler.removeCallbacksAndMessages(null)
        for (track in tracks) {
            try {
                track.stop()
            } catch (_: Throwable) {
            }
            try {
                track.release()
            } catch (_: Throwable) {
            }
        }
        tracks.clear()
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val CHANNEL_NAME = "tech.zhongbei/jellycube3d_audio"
        private const val SAMPLE_RATE = 44_100
        private const val MAX_VOICES = 16
    }
}
