import 'dart:async';
import 'dart:io';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/enums/video_loop_mode.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/video/metadata.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:aves_video/aves_video.dart';
import 'package:collection/collection.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerAvesVideoController extends AvesVideoController {
  /* No need to handle plugin events. */

  final VideoPlayerController _instance;
  final List<StreamSubscription> _subscriptions = [];
  final StreamController<VideoPlayerValue> _valueStreamController = StreamController.broadcast();
  final StreamController<String?> _timedTextStreamController = StreamController.broadcast();
  final StreamController<double> _volumeStreamController = StreamController.broadcast();
  final StreamController<double> _speedStreamController = StreamController.broadcast();
  final AChangeNotifier _completedNotifier = AChangeNotifier();
  /* No need to offset. The 16x-dimension bug has been fixed:
   * https://github.com/flutter/flutter/issues/34642 */
  final List<MediaStreamSummary> _streams = [];
  /* No need for initial play timer workaround. */
  double _speed = 1;
  double _volume = 1;
  // For some reason the superclass only exposes an AvesEntryBase instance,
  // despite all usages passing an AvesEntry into the constructor --- which
  // then gets downcast into an AvesEntryBase. We need the added properties of
  // the full entry, so capture it ourselves.
  final AvesEntry _entry;

  @override
  AvesEntry get entry => _entry;

  // Actual min is zero exclusive.
  // Copying VLC's min.
  @override
  final double minSpeed = .25;

  // Actual max is theoretically non-existent. Copying VLC's max.
  @override
  final double maxSpeed = 4;

  // Don't need to wait for it to load since we use FFmpeg separately.
  @override
  final ValueNotifier<bool> canCaptureFrameNotifier = ValueNotifier(true);

  @override
  final ValueNotifier<bool> canMuteNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> canSetSpeedNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> canSelectStreamNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<double> sarNotifier = ValueNotifier(1);

  Stream<VideoPlayerValue> get _valueStream => _valueStreamController.stream;

  /* No need to disable hardware acceleration for short videos.
   * (In fact, we can't.) */
  // wsrgs: Intentional break from compatibility, because I prefer it this way.
  static final options = VideoPlayerOptions(mixWithOthers: true);

  VideoPlayerAvesVideoController(
    this._entry, {
    required super.playbackStateHandler,
  }) : _instance = VideoPlayerController.contentUri(
          Uri.parse(_entry.uri),
          videoPlayerOptions: options,
       ),
       super(_entry) {
    _valueStream.any((value) => value.isInitialized).then((_) {
      canCaptureFrameNotifier.value = true;
      canMuteNotifier.value = true;
      canSetSpeedNotifier.value = true;
    });
    _startListening();
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _stopListening();
    await _valueStreamController.close();
    await _timedTextStreamController.close();
    await _instance.dispose();
  }

  void _startListening() {
    _instance.addListener(_onValueChanged);
    _subscriptions.add(_valueStream
        // The notifier must only fire when not looping, else the video will
        // manually seek to zero, which isn't seamless.
        .where((value) => value.position > value.duration && !_instance.value.isLooping)
        .listen((_) => _completedNotifier.notify()));
    /* No need to manually implement CC. Closed captions support is built-in.
     * (Except for the fact that track support is missing so actually we have
     * no CC support.) */
    _subscriptions.add(settings.updateStream
        .where((event) => event.key == Settings.videoLoopModeKey)
        .listen((_) => _applyOptions()));
  }

  void _stopListening() {
    _instance.removeListener(_onValueChanged);
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
  }

  Future<void> _init({int startMillis = 0}) async {
    /* No need to reset and reinitialise. */

    sarNotifier.value = 1;
    _streams.clear();
    // Can't apply options until we have an initialised instance.
    await _instance.initialize();
    await _applyOptions(startMillis);

    await _applyVolume();
    await _applySpeed();
    await play();
  }

  Future<void> _applyOptions([int? startMillis]) async {
    final loopEnabled = settings.videoLoopMode.shouldLoop(entry.durationMillis);
    await _instance.setLooping(loopEnabled);
    if (startMillis != null) {
      await seekTo(startMillis);
    }
  }

  void _fetchStreams() async {
    final mediaInfo = await VideoMetadataFormatter.getVideoMetadata(entry);
    if (!mediaInfo.containsKey(Keys.streams)) return;

    var videoStreamCount = 0, audioStreamCount = 0, textStreamCount = 0;

    _streams.clear();
    final allStreams = (mediaInfo[Keys.streams] as List).cast<Map>();
    allStreams.forEach((stream) {
      final type = ExtraStreamType.fromTypeString(stream[Keys.streamType]);
      if (type != null) {
        final width = stream[Keys.width] as int?;
        final height = stream[Keys.height] as int?;
        _streams.add(MediaStreamSummary(
          type: type,
          index: stream[Keys.index],
          codecName: stream[Keys.codecName],
          language: stream[Keys.language],
          title: stream[Keys.title],
          width: width,
          height: height,
        ));
        switch (type) {
          case MediaStreamType.video:
            // check width/height to exclude image streams (that are included among video streams)
            if (width != null && height != null) {
              videoStreamCount++;
            }
            break;
          case MediaStreamType.audio:
            audioStreamCount++;
            break;
          case MediaStreamType.text:
            textStreamCount++;
            break;
        }
      }
    });

    // XXX: Stream support not implemented.
    // canSelectStreamNotifier.value = videoStreamCount > 1 || audioStreamCount > 1 || textStreamCount > 0;

    final selectedVideo = await getSelectedStream(MediaStreamType.video);
    if (selectedVideo != null) {
      final streamIndex = selectedVideo.index;
      final streamInfo = allStreams.firstWhereOrNull((stream) => stream[Keys.index] == streamIndex);
      if (streamInfo != null) {
        final num = streamInfo[Keys.sarNum] ?? 0;
        final den = streamInfo[Keys.sarDen] ?? 0;
        sarNotifier.value = (num != 0 ? num : 1) / (den != 0 ? den : 1);
      }
    }
  }

  void _onValueChanged() {
    if (_streams.isEmpty) {
      _fetchStreams();
    }
    _valueStreamController.add(_instance.value);
  }

  @override
  void onVisualChanged() => _init(startMillis: currentPosition);

  @override
  Future<void> play() async {
    if (isReady) {
      await _instance.play();
    } else {
      await _init();
    }
  }

  @override
  Future<void> pause() => _instance.pause();

  @override
  Future<void> seekTo(int targetMillis) async {
    if (isReady) {
      await _instance.seekTo(Duration(milliseconds: targetMillis));
    } else {
      // Load and seek the player if resuming playback.
      await _init(startMillis: targetMillis);
    }
  }

  @override
  Listenable get playCompletedListenable => _completedNotifier;

  @override
  VideoStatus get status => _instance.value.toAves;

  @override
  Stream<VideoStatus> get statusStream => _valueStream.map((value) => value.toAves);

  @override
  Stream<double> get volumeStream => _volumeStreamController.stream;

  @override
  Stream<double> get speedStream => _speedStreamController.stream;

  @override
  bool get isReady => _instance.value.isInitialized && !_instance.value.hasError;

  @override
  int get duration {
    final controllerDuration = _instance.value.duration.inMilliseconds;
    // use expected duration when controller duration is not set yet
    return controllerDuration == 0 ? (entry.durationMillis ?? 0) : controllerDuration;
  }

  @override
  int get currentPosition => _instance.value.position.inMilliseconds;

  @override
  Stream<int> get positionStream => _valueStream.map((value) => value.position.inMilliseconds);

  @override
  Stream<String?> get timedTextStream => _timedTextStreamController.stream;

  @override
  bool get isMuted => _volume == 0;

  @override
  Future<void> mute(bool muted) async {
    _volume = muted ? 0 : 1;
    _volumeStreamController.add(_volume);
    await _applyVolume();
  }

  Future<void> _applyVolume() => _instance.setVolume(_volume);

  @override
  double get speed => _speed;

  @override
  set speed(double speed) {
    if (speed <= 0 || _speed == speed) return;
    _speed = speed;
    _speedStreamController.add(_speed);

    /* No need to handle SoundTouch. */
    _applySpeed();
  }

  Future<void> _applySpeed() => _instance.setPlaybackSpeed(speed);

  @override
  Future<void> selectStream(MediaStreamType type, MediaStreamSummary? selected) async {
    debugPrint('XXX: selectStream not implemented');
  }

  @override
  Future<MediaStreamSummary?> getSelectedStream(MediaStreamType type) async {
    debugPrint('XXX: getSelectedStream not implemented');
    return null;
  }

  @override
  List<MediaStreamSummary> get streams => _streams;

  @override
  Future<Uint8List> captureFrame() async {
    // XXX: Frame-perfect captures require https://github.com/flutter/flutter/issues/38509
    final position = _instance.value.position;
    final tempDir = await Directory.systemTemp.createTemp();
    final outPath = '$tempDir/frame.jpeg';
    await FFmpegKit.execute('-i ${entry.path!} -ss $position -frames:v 1 $outPath');
    final outFile = File(outPath);
    final bytes = await outFile.readAsBytes();
    await tempDir.delete(recursive: true);
    return bytes;
  }

  @override
  Widget buildPlayerWidget(BuildContext context) => VideoPlayer(_instance);
}

extension ExtraVideoPlayerValue on VideoPlayerValue {
  VideoStatus get toAves {
    if (hasError) return VideoStatus.error;
    if (!isInitialized) return VideoStatus.idle;
    if (isPlaying) return VideoStatus.playing;
    return VideoStatus.paused;
  }
}

extension ExtraStreamType on MediaStreamType {
  static MediaStreamType? fromTypeString(String? type) {
    switch (type) {
      case MediaStreamTypes.video:
        return MediaStreamType.video;
      case MediaStreamTypes.audio:
        return MediaStreamType.audio;
      case MediaStreamTypes.subtitle:
      case MediaStreamTypes.timedText:
        return MediaStreamType.text;
      default:
        return null;
    }
  }
}
