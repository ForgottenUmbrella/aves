package deckers.thibault.aves.channel.streams

import android.content.Context
import android.database.ContentObserver
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import deckers.thibault.aves.utils.LogUtils
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

class ContentChangeStreamHandler(private val context: Context) : EventChannel.StreamHandler {
    private val contentObserver = object : ContentObserver(null) {
        override fun onChange(selfChange: Boolean) {
            this.onChange(selfChange, null)
        }

        override fun onChange(selfChange: Boolean, uri: Uri?) {
            // warning: querying the content resolver right after a change
            // sometimes yields obsolete results
            success(uri?.toString())
        }
    }
    private lateinit var eventSink: EventSink
    private lateinit var handler: Handler

    init {
        context.contentResolver.apply {
            registerContentObserver(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true, contentObserver)
            registerContentObserver(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true, contentObserver)
        }
    }

    override fun onListen(arguments: Any?, eventSink: EventSink) {
        this.eventSink = eventSink
        handler = Handler(Looper.getMainLooper())
    }

    override fun onCancel(arguments: Any?) {}

    fun dispose() {
        context.contentResolver.unregisterContentObserver(contentObserver)
    }

    private fun success(uri: String?) {
        handler.post {
            try {
                eventSink.success(uri)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "failed to use event sink", e)
            }
        }
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag(ContentChangeStreamHandler::class.java)
        const val CHANNEL = "deckers.thibault/aves/contentchange"
    }
}