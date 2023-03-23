import 'package:aves/model/settings/enums/enums.dart';

extension ExtraVideoLoopMode on VideoLoopMode {
  static const shortVideoThreshold = Duration(seconds: 30);

  bool shouldLoop(int? durationMillis) {
    switch (this) {
      case VideoLoopMode.never:
        return false;
      case VideoLoopMode.shortOnly:
        return durationMillis != null ? durationMillis < shortVideoThreshold.inMilliseconds : false;
      case VideoLoopMode.always:
        return true;
    }
  }
}
