import 'dart:ui';

import 'package:flutter/foundation.dart';

mixin AvesEntryBase {
  int get id;

  String get uri;

  int? get pageId;

  int? get sizeBytes;

  int? get durationMillis;

  int get rotationDegrees;

  Size get displaySize;

  double get displayAspectRatio;

  Listenable get visualChangeNotifier;
}
