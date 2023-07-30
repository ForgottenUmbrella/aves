import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'stream.dart';

class ExoPlayer {
  final int _id;
  late final MethodChannel _channel;
  final Uri uri;
  final _listeners = <ExoPlayerListener>[];
  var _currentPosition = Duration.zero;
  var _duration = Duration.zero;
  var _isDeviceMuted = false;
  var _isPlaying = false;
  var _playbackSpeed = 1.0;
  var _playbackState = ExoPlayerState.idle;
  var _hasError = false;
  var _repeat = false;
  var _trackInfo = <ExoPlayerTrackInfo>[];
  var _selectedTracks = <ExoPlayerTrackInfo>[];
  static var _newId = 0;

  ExoPlayer(this.uri) : _id = _newId++ {
    _channel = MethodChannel('deckers.thibault/aves/aves_video/exoplayer/$_id');
    _channel.setMethodCallHandler((call) => onMethodCall(call));
  }

  Future<void> dispose() => _channel.invokeMethod('release');

  Future<void> prepare() async {
    final metadata = await _channel.invokeMapMethod<String, dynamic?>('prepare', uri.toString());
    if (metadata != null) {
      _duration = Duration(milliseconds: metadata['durationMs'] as int);
      _isDeviceMuted = metadata['isDeviceMuted'] as bool;
    }
  }

  void addListener(ExoPlayerListener listener) => _listeners.add(listener);

  void removeListener(ExoPlayerListener listener) => _listeners.remove(listener);

  Future<void> pause() => _channel.invokeMethod('pause');

  Future<void> play() => _channel.invokeMethod('play');

  Future<void> seekTo(Duration position) async {
    _currentPosition = position;
    await _channel.invokeMethod('seekTo', position.inMilliseconds);
  }

  Future<Uint8List> pixelCopy() => _channel.invokeMethod('pixelCopy') as Future<Uint8List>;

  Duration get currentPosition => _currentPosition;

  Duration get duration => _duration;

  Future<void> setDeviceMuted(bool muted) async {
    await _channel.invokeMethod('setDeviceMuted', muted);
  }

  bool get isDeviceMuted => _isDeviceMuted;

  bool get isPlaying => _isPlaying;

  set playbackSpeed(double speed) {
    _channel.invokeMethod('setPlaybackSpeed', speed)
      .then((_) => _playbackSpeed = speed)
      .catchError((err) {});
  }

  double get playbackSpeed => _playbackSpeed;

  ExoPlayerState get playbackState => _playbackState;

  bool get hasError => _hasError;

  set repeat(bool enabled) {
    _channel.invokeMethod('setRepeat', enabled)
      .then((_) => _repeat = enabled)
      .catchError((err) {});
  }

  bool get repeat => _repeat;

  List<ExoPlayerTrackInfo> get trackInfo => _trackInfo;

  MediaStreamSummary? getSelectedTrack(MediaStreamType type) {
    return _selectedTracks[type.index];
  }

  Future<void> selectTrack(int index) async {
    final info = trackInfo[index];
    if (info != null) {
      await _channel.invokeMethod('selectTrack', [info.groupIndex, info.trackIndex]);
    }
  }

  Future<void> deselectTrack(int index) async {
    final info = trackInfo[index];
    if (info != null) {
      await _channel.invokeMethod('deselectTrack', info.groupIndex);
    }
  }

  Widget build(BuildContext context) => AndroidView(
    viewType: 'exoplayer',  // Must match registered name on Kotlin side.
    creationParams: {
      'id': _id,
    },
  );

  Future<dynamic> onMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCue':
        final cue = call.arguments as String?;
        _listeners.forEach((listener) => listener.onCue(cue));
        return Future.value();
      case 'onCurrentPositionChanged':
        _currentPosition = Duration(milliseconds: call.arguments as int);
        _listeners.forEach((listener) => listener.onCurrentPositionChanged(currentPosition));
        return Future.value();
      case 'onDeviceMutedChanged':
        _isDeviceMuted = call.arguments as bool;
        return Future.value();
      case 'onIsPlayingChanged':
        _isPlaying = call.arguments as bool;
        return Future.value();
      case 'onPlaybackStateChanged':
        final stateIndex = call.arguments as int;
        _playbackState = ExoPlayerState.values[stateIndex];
        _listeners.forEach((listener) => listener.onPlaybackStateChanged(playbackState));
        return Future.value();
      case 'onPlayerErrorChanged':
        _hasError = call.arguments as bool;
        _listeners.forEach((listener) => listener.onPlayerErrorChanged(hasError));
        return Future.value();
      case 'onRenderedFirstFrame':
        _listeners.forEach((listener) => listener.onRenderedFirstFrame());
        return Future.value();
      case 'onTracksChanged':
        final response = call.arguments as Map<String, List<Map<String, dynamic?>>>;
        final trackInfoMaps = response['trackInfo']!;
        final selectedMaps = response['selected']!;
        ExoPlayerTrackInfo toTrackInfo(Map map) => ExoPlayerTrackInfo(
          type: MediaStreamType.values[map['type'] as int],
          index: map['index'] as int?,
          codecName: map['codecName'] as String?,
          language: map['language'] as String?,
          title: map['title'] as String?,
          width: map['width'] as int?,
          height: map['height'] as int?,
          groupIndex: map['groupIndex'] as int,
          trackIndex: map['trackIndex'] as int,
        );
        _trackInfo = trackInfoMaps.map(toTrackInfo).toList();
        _selectedTracks = selectedMaps.map(toTrackInfo).toList();
        return Future.value();
    }
  }
}

enum ExoPlayerState { _, idle, buffering, ready, ended }

abstract class ExoPlayerListener {
  void onCue(String? cue) {}
  void onCurrentPositionChanged(Duration position) {}
  void onPlaybackStateChanged(ExoPlayerState state) {}
  void onPlayerErrorChanged(bool hasError) {}
  void onRenderedFirstFrame() {}
}

class ExoPlayerTrackInfo extends MediaStreamSummary {
  final int groupIndex;
  final int trackIndex;

  const ExoPlayerTrackInfo({
    required super.type,
    required super.index,
    required super.codecName,
    required super.language,
    required super.title,
    required super.width,
    required super.height,
    required this.groupIndex,
    required this.trackIndex,
  });
}
