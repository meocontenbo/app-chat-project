import 'package:flutter/foundation.dart';

/// Room code from a /join/<code> link the app was opened with (web), consumed once by HomeScreen.
final pendingJoinCode = ValueNotifier<String?>(null);
