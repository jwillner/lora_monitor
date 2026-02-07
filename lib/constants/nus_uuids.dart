import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Nordic UART Service UUIDs
final Guid nusServiceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
final Guid nusRxUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write
final Guid nusTxUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify
