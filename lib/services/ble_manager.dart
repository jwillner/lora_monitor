import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/nus_uuids.dart';
import '../models/ble_row.dart';

class BleManager extends ChangeNotifier {
  BluetoothDevice? connectedDevice;
  String? connectedId;
  String? connectedName;

  BluetoothCharacteristic? _rx;
  // ignore: unused_field
  BluetoothCharacteristic? _tx; // stored for future use

  StreamSubscription<List<int>>? _txSub;
  final StringBuffer _lineBuf = StringBuffer();

  /// Device parameters (from JSON)
  Map<String, dynamic> deviceInfo = {};

  /// Tracks set_config response
  bool? lastAck;
  String? lastError;

  bool isConnecting = false;
  bool isConnected = false;

  Future<void> disconnect() async {
    try {
      await _txSub?.cancel();
      _txSub = null;
      _rx = null;
      _tx = null;

      if (connectedDevice != null) {
        await connectedDevice!.disconnect();
      }
    } catch (_) {
      // ignore
    } finally {
      connectedDevice = null;
      connectedId = null;
      connectedName = null;
      isConnected = false;
      isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> connectNus(BleRow row) async {
    if (isConnecting) return;

    // Wichtig: Scan stoppen vor Connect
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));

    await disconnect();

    isConnecting = true;
    notifyListeners();

    try {
      // 1) Connect
      await row.device.connect(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(milliseconds: 300));

      // 2) (Optional) MTU
      try {
        await row.device.requestMtu(255);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));

      // 3) Discover services
      final services = await row.device.discoverServices();
      await Future.delayed(const Duration(milliseconds: 250));

      BluetoothCharacteristic? rx;
      BluetoothCharacteristic? tx;

      for (final s in services) {
        if (s.uuid != nusServiceUuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid == nusRxUuid) rx = c;
          if (c.uuid == nusTxUuid) tx = c;
        }
      }

      if (rx == null || tx == null) {
        await row.device.disconnect();
        throw Exception('NUS RX/TX nicht gefunden');
      }

      // 4) Enable notifications with retry
      Future<void> enableNotifyWithRetry() async {
        try {
          await tx!.setNotifyValue(true);
        } catch (_) {
          await Future.delayed(const Duration(milliseconds: 700));
          await tx!.setNotifyValue(true);
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }

      await enableNotifyWithRetry();

      // 5) Subscribe to notifications
      await _txSub?.cancel();
      _txSub = tx.onValueReceived.listen(_onTxBytes);

      // 6) Store
      connectedDevice = row.device;
      connectedId = row.id;
      connectedName = row.name;
      _rx = rx;
      _tx = tx;

      isConnected = true;
      isConnecting = false;
      notifyListeners();
    } catch (e) {
      try {
        await row.device.disconnect();
      } catch (_) {}

      isConnecting = false;
      isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _onTxBytes(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    _lineBuf.write(text);

    final all = _lineBuf.toString();
    final lines = all.split('\n');

    _lineBuf.clear();
    if (!all.endsWith('\n')) {
      _lineBuf.write(lines.removeLast());
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final obj = json.decode(trimmed);
        if (obj is Map<String, dynamic>) {
          if (obj.containsKey('ack')) {
            lastAck = obj['ack'] == true;
            lastError = obj['error']?.toString();
            notifyListeners();
          } else {
            deviceInfo = {...deviceInfo, ...obj};
            notifyListeners();
          }
        }
      } catch (_) {
        // not valid json line -> ignore
      }
    }
  }

  Future<void> sendLine(String line) async {
    if (_rx == null) throw Exception('Nicht verbunden (RX fehlt)');
    final data = utf8.encode(line.endsWith('\n') ? line : '$line\n');
    await _rx!.write(Uint8List.fromList(data), withoutResponse: true);
  }

  Future<void> requestDeviceInfo() async {
    await sendLine('{"cmd":"get_info"}');
  }

  Future<void> sendSetConfig({String? sn, int? devId, String? mode}) async {
    lastAck = null;
    lastError = null;
    final map = <String, dynamic>{'cmd': 'set_config'};
    if (sn != null) map['sn'] = sn;
    if (devId != null) map['devId'] = devId;
    if (mode != null) map['mode'] = mode;
    await sendLine(json.encode(map));
  }
}

/// Global singleton instance
final bleManager = BleManager();
