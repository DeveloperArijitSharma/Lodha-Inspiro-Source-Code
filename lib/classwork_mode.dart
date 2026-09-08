import 'package:flutter/foundation.dart';

/// True while a student is completing a monitored classwork session.
/// AI entry points must refuse requests while this is enabled.
final ValueNotifier<bool> classworkModeNotifier = ValueNotifier<bool>(false);

void setClassworkMode(bool enabled) {
  classworkModeNotifier.value = enabled;
}
