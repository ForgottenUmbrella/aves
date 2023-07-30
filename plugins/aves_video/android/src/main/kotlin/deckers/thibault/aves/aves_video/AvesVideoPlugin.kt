package deckers.thibault.aves.aves_video

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding

class AvesVideoPlugin : FlutterPlugin {
    private lateinit var viewFactory: ExoPlayerViewFactory

    override fun onAttachedToEngine(@NonNull binding: FlutterPluginBinding) {
        viewFactory = ExoPlayerViewFactory(binding)
        binding.platformViewRegistry.registerViewFactory("exoplayer", viewFactory)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
        viewFactory.detachBindings()
    }
}
