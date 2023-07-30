package deckers.thibault.aves.aves_video

import android.content.Context
import android.graphics.Bitmap
import android.view.PixelCopy
import android.view.PixelCopy.OnPixelCopyFinishedListener
import android.view.SurfaceView
import android.view.View
import androidx.annotation.NonNull
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C.AUDIO_CONTENT_TYPE_SPEECH
import androidx.media3.common.C.TRACK_TYPE_AUDIO
import androidx.media3.common.C.TRACK_TYPE_TEXT
import androidx.media3.common.C.TRACK_TYPE_VIDEO
import androidx.media3.common.Format
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.Player.REPEAT_MODE_OFF
import androidx.media3.common.Player.REPEAT_MODE_ONE
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.text.CueGroup
import androidx.media3.exoplayer.ExoPlayer
import java.nio.ByteBuffer

import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

internal class ExoPlayerView(
    context: Context,
    viewId: Int,
    creationParams: Map<String?, Any?>?,
    binding: FlutterPluginBinding,
) : PlatformView, MethodCallHandler, Player.Listener {
    private val view = SurfaceView(context)
    private val id = creationParams?.get("id")!! as Int
    private val player = players.getOrPut(id) { ExoPlayer.Builder(context).build() }
        .apply {
            setVideoSurfaceView(view)
            addListener(this@ExoPlayerView)
            setHandleAudioBecomingNoisy(true)
            setAudioAttributes(
                // Personal preference. Allow multiple simultaneous audio streams.
                AudioAttributes.Builder()
                    .setContentType(AUDIO_CONTENT_TYPE_SPEECH)
                    .build(),
                true
            )
        }
    private val channel = MethodChannel(binding.binaryMessenger, "deckers.thibault/aves/aves_video/exoplayer/$id")
        .apply { setMethodCallHandler(this@ExoPlayerView) }

    override fun dispose() {}

    override fun getView(): View = view

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "prepare" -> {
                val uri = call.arguments as String
                player.setMediaItem(MediaItem.fromUri(uri))
                player.prepare()
                result.success(
                    mapOf(
                        "durationMs" to player.duration,
                        "isDeviceMuted" to player.isDeviceMuted,
                    )
                )
            }
            "release" -> {
                player.release()
                result.success(null)
            }
            "pause" -> {
                player.pause()
                result.success(null)
            }
            "play" -> {
                player.play()
                result.success(null)
            }
            "seekTo" -> {
                val positionMs = call.arguments as Long
                player.seekTo(positionMs)
                result.success(null)
            }
            "pixelCopy" -> {
                val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
                val listener = OnPixelCopyFinishedListener { copyResult ->
                    when (copyResult) {
                        PixelCopy.SUCCESS -> {
                            val buffer = ByteBuffer.allocate(bitmap.byteCount)
                            bitmap.copyPixelsToBuffer(buffer)
                            result.success(buffer.array())
                        }
                        else -> result.error(copyResult.toString(), null, null)
                    }
                }
                PixelCopy.request(view, bitmap, listener, view.handler)
            }
            "setDeviceMuted" -> {
                val muted = call.arguments as Boolean
                player.setDeviceMuted(muted)
                result.success(null)
            }
            "setPlaybackSpeed" -> {
                val speed = call.arguments as Double
                player.setPlaybackSpeed(speed.toFloat())
                result.success(null)
            }
            "setRepeat" -> {
                val enabled = call.arguments as Boolean
                player.repeatMode = if (enabled) REPEAT_MODE_ONE else REPEAT_MODE_OFF
                result.success(null)
            }
            "selectTrack" -> {
                val args = call.arguments as List<Int>
                val groupIndex = args[0]
                val trackIndex = args[1]
                selectTrack(groupIndex, listOf(trackIndex))
                result.success(null)
            }
            "deselectTrack" -> {
                val groupIndex = call.arguments as Int
                selectTrack(groupIndex, listOf())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onCues(cueGroup: CueGroup) {
        channel.invokeMethod("onCue", cueGroup.cues.last().text.toString())
    }

    private fun onCurrentPositionChanged() {
        channel.invokeMethod("onCurrentPositionChanged", player.currentPosition)
        if (player.isPlaying()) {
            view.postDelayed(this::onCurrentPositionChanged, POLL_INTERVAL_MS)
        }
    }

    override fun onDeviceVolumeChanged(volume: Int, muted: Boolean) {
        channel.invokeMethod("onDeviceMutedChanged", muted)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        channel.invokeMethod("onIsPlayingChanged", isPlaying)
        if (isPlaying) {
            view.postDelayed(this::onCurrentPositionChanged, POLL_INTERVAL_MS)
        }
    }

    override fun onPlaybackStateChanged(@Player.State state: Int) {
        channel.invokeMethod("onPlaybackStateChanged", state)
    }

    override fun onPlayerErrorChanged(error: PlaybackException?) {
        channel.invokeMethod("onPlayerErrorChanged", error != null)
    }

    override fun onRenderedFirstFrame() {
        channel.invokeMethod("onRenderedFirstFrame", null)
    }

    override fun onTracksChanged(tracks: Tracks) {
        val trackInfo = mutableListOf<Map<String, Any?>>()
        val selected = arrayOfNulls<Map<String, Any?>>(MEDIA_STREAM_TYPES.size)
        var count = 0
        for ((groupIndex, group) in tracks.groups.withIndex()) {
            val type = MEDIA_STREAM_TYPES[group.type]
            if (type == null) continue
            for (trackIndex in 0 until group.length) {
                val format = group.getTrackFormat(trackIndex)
                val info = mapOf(
                    "type" to type,
                    "index" to count++,
                    "codecName" to format.codecs,
                    "language" to format.language,
                    "title" to format.label,
                    "width" to (if (format.width != Format.NO_VALUE) format.width else null),
                    "height" to (if (format.height != Format.NO_VALUE) format.height else null),
                    "groupIndex" to groupIndex,
                    "trackIndex" to trackIndex,
                )
                trackInfo.add(info)
                if (group.isTrackSelected(trackIndex)) {
                    selected[type] = info
                }
            }
        }
        channel.invokeMethod("onTracksChanged", mapOf("trackInfo" to trackInfo, "selected" to selected))
    }

    fun detachBinding() {
        channel.setMethodCallHandler(null)
    }

    private fun selectTrack(groupIndex: Int, trackIndices: List<Int>) {
        val trackGroup = player.currentTracks.groups[groupIndex].mediaTrackGroup
        player.trackSelectionParameters = player.trackSelectionParameters
            .buildUpon()
            .setOverrideForType(TrackSelectionOverride(trackGroup, trackIndices))
            .build()
    }

    companion object {
        private val players = mutableMapOf<Int, ExoPlayer>()
        private val POLL_INTERVAL_MS = 500L
        // Mapping of Android track types to Aves stream types.
        private val MEDIA_STREAM_TYPES = listOf(TRACK_TYPE_VIDEO, TRACK_TYPE_AUDIO, TRACK_TYPE_TEXT)
            .mapIndexed{ i, type -> Pair(type, i) }
            .toMap()
    }
}

class ExoPlayerViewFactory(val binding: FlutterPluginBinding)
    : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableListOf<ExoPlayerView>()

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val creationParams = args as Map<String?, Any?>?
        val view = ExoPlayerView(context, viewId, creationParams, binding)
        views.add(view)
        return view
    }

    fun detachBindings() {
        views.forEach(ExoPlayerView::detachBinding)
    }
}
