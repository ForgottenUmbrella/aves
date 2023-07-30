import 'dart:async';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/settings/enums/video_loop_mode.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves_model/aves_model.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:aves_video/aves_video.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ExoPlayerAvesVideoController extends AvesVideoController
  implements ExoPlayerListener {
  final ExoPlayer _instance;
  final List<StreamSubscription> _subscriptions = [];
  final StreamController<VideoStatus> _statusStreamController = StreamController.broadcast();
  final StreamController<double> _volumeStreamController = StreamController.broadcast();
  final StreamController<double> _speedStreamController = StreamController.broadcast();
  final StreamController<int> _positionStreamController = StreamController.broadcast();
  final StreamController<String?> _timedTextStreamController = StreamController.broadcast();
  final AChangeNotifier _completedNotifier = AChangeNotifier();
  static const positionPollInterval = Duration(milliseconds: 500);

  @override
  final AvesEntry entry;

  ExoPlayerAvesVideoController(
    this.entry, {
    required super.playbackStateHandler,
  }) : _instance = ExoPlayer(Uri.parse(entry.uri)),
       super(entry) {
    _instance.addListener(this);
    _subscriptions.add(settings.updateStream
        .where((event) => event.key == Settings.videoLoopModeKey)
        .listen((_) => setRepeat()));
  }

  @override
  Future<void> dispose() async {
    await super.dispose();
    _instance.removeListener(this);
    _subscriptions
      ..forEach((sub) => sub.cancel())
      ..clear();
    await _statusStreamController.close();
    await _timedTextStreamController.close();
    await _volumeStreamController.close();
    await _speedStreamController.close();
    await _instance.dispose();
  }

  @override
  void onCue(String? cue) => _timedTextStreamController.add(cue);

  @override
  void onCurrentPositionChanged(Duration position) {
    _positionStreamController.add(position.inMilliseconds);
  }

  @override
  void onPlaybackStateChanged(ExoPlayerState state) {
    _statusStreamController.add(_instance.videoStatus);

    switch (state) {
      case ExoPlayerState.ready:
        if (streams.isEmpty) {
          streams.addAll(_instance.trackInfo);
          canSelectStreamNotifier.value = streams.isNotEmpty;
        }
        break;
      case ExoPlayerState.ended:
        _completedNotifier.notify();
        break;
    }
  }

  @override
  void onPlayerErrorChanged(bool hasError) {
    if (hasError) {
      _statusStreamController.add(VideoStatus.error);
    }
  }

  @override
  void onRenderedFirstFrame() => canCaptureFrameNotifier.value = true;

  Future<void> _init({int startMillis = 0}) async {
    sarNotifier.value = 1;
    streams.clear();
    // XXX: Do we need to do the re-init/reapply-settings dance when it rotates?
    await _instance.prepare();
    canMuteNotifier.value = true;
    canSetSpeedNotifier.value = true;
    setRepeat();
    await seekTo(startMillis);
    await play();
  }

  void setRepeat() {
    _instance.repeat = settings.videoLoopMode.shouldLoop(entry.durationMillis);
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
  VideoStatus get status => _instance.videoStatus;

  @override
  Stream<VideoStatus> get statusStream => _statusStreamController.stream;

  @override
  Stream<double> get volumeStream => _volumeStreamController.stream;

  @override
  Stream<double> get speedStream => _speedStreamController.stream;

  @override
  bool get isReady => _instance.playbackState == ExoPlayerState.ready;

  @override
  int get duration {
    final controllerDuration = _instance.duration.inMilliseconds;
    // use expected duration when controller duration is not set yet
    return controllerDuration == 0 ? (entry.durationMillis ?? 0) : controllerDuration;
  }

  @override
  int get currentPosition => _instance.currentPosition.inMilliseconds;

  @override
  Stream<int> get positionStream => _positionStreamController.stream;

  @override
  Stream<String?> get timedTextStream => _timedTextStreamController.stream;

  @override
  final ValueNotifier<bool> canCaptureFrameNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> canMuteNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> canSetSpeedNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<bool> canSelectStreamNotifier = ValueNotifier(false);

  @override
  final ValueNotifier<double> sarNotifier = ValueNotifier(1);

  @override
  bool get isMuted => _instance.isDeviceMuted;

  @override
  double get speed => _instance.playbackSpeed;

  @override
  final double minSpeed = .25;

  @override
  final double maxSpeed = 4;

  @override
  set speed(double speed) {
    if (speed <= 0) return;
    _speedStreamController.add(speed);
    _instance.playbackSpeed = speed;
  }

  @override
  Future<void> selectStream(MediaStreamType type, MediaStreamSummary? selected) async {
    final current = await getSelectedStream(type);
    if (selected != null) {
      final index = selected.index;
      if (index != null) {
        await _instance.selectTrack(index);
        final width = selected.width;
        final height = selected.height;
        if (type == MediaStreamType.video && width != null && height != null) {
          sarNotifier.value = width / height;
        }
      }
    } else {
        final index = current?.index;
        if (index != null) {
            await _instance.deselectTrack(index);
        }
    }

    if (type == MediaStreamType.text && selected != current) {
      // Flush the text stream(?)
      _timedTextStreamController.add(null);
    }
  }

  @override
  Future<MediaStreamSummary?> getSelectedStream(MediaStreamType type) {
    return Future.value(_instance.getSelectedTrack(type));
  }

  @override
  final List<MediaStreamSummary> streams = [];

  @override
  Future<Uint8List> captureFrame() => _instance.pixelCopy();

  @override
  Future<void> mute(bool muted) async {
    final volume = muted ? 0.0 : 1.0;
    _volumeStreamController.add(volume);
    await _instance.setDeviceMuted(muted);
  }

  @override
  Widget buildPlayerWidget(BuildContext context) => _instance.build(context);
}

extension on ExoPlayer {
  VideoStatus get videoStatus {
    if (hasError) {
      return VideoStatus.error;
    }
    if (isPlaying) {
      return VideoStatus.playing;
    }
    switch (playbackState) {
      case ExoPlayerState.ended:
        return VideoStatus.completed;
      case ExoPlayerState.buffering:
        return VideoStatus.initialized;
      case ExoPlayerState.idle:
        return VideoStatus.idle;
      default:
        return VideoStatus.paused;
    }
  }
}
