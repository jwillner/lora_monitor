import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const HeltecApp());

class HeltecApp extends StatelessWidget {
  const HeltecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Heltec Master',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

/* =======================
   BLE / NUS manager
   ======================= */

final Guid nusServiceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
final Guid nusRxUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'); // write
final Guid nusTxUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e'); // notify

class BleRow {
  final BluetoothDevice device;
  final String id;
  final String name;
  final int rssi;

  const BleRow({
    required this.device,
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class BleManager extends ChangeNotifier {
  BluetoothDevice? connectedDevice;
  String? connectedId;
  String? connectedName;

  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;

  StreamSubscription<List<int>>? _txSub;
  final StringBuffer _lineBuf = StringBuffer();

  // Device parameters (from JSON)
  Map<String, dynamic> deviceInfo = {};

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

    await disconnect();

    isConnecting = true;
    notifyListeners();

    try {
      await row.device.connect(timeout: const Duration(seconds: 10));
      final services = await row.device.discoverServices();

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

      // enable notifications
      await tx.setNotifyValue(true);

      // subscribe to notifications
      await _txSub?.cancel();
      _txSub = tx.onValueReceived.listen((bytes) {
        _onTxBytes(bytes);
      });

      connectedDevice = row.device;
      connectedId = row.id;
      connectedName = row.name;
      _rx = rx;
      _tx = tx;

      isConnected = true;
      isConnecting = false;

      // Optional: sofort Info abfragen
      // await requestDeviceInfo();

      notifyListeners();
    } catch (e) {
      isConnecting = false;
      isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  void _onTxBytes(List<int> bytes) {
    // We expect JSON per line (newline terminated)
    final text = utf8.decode(bytes, allowMalformed: true);
    _lineBuf.write(text);

    final all = _lineBuf.toString();
    final lines = all.split('\n');

    // keep last partial line
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
          deviceInfo = {...deviceInfo, ...obj};
          notifyListeners();
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
    // Device should respond with JSON line, e.g.:
    // {"devicename":"HeltecMaster","serial":"ABC123","battery":87,...}\n
    await sendLine('{"cmd":"get_info"}');
  }
}

final bleManager = BleManager();

/* =======================
   Home screen
   ======================= */

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _tile(BuildContext context, String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        ),
        onPressed: onTap,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Heltec Master')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tile(context, 'Scan+Connect', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanConnectScreen()),
              );
            }),
            const SizedBox(height: 12),
            _tile(context, 'Device', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeviceScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/* =======================
   Scan + Connect screen
   ======================= */

class ScanConnectScreen extends StatefulWidget {
  const ScanConnectScreen({super.key});

  @override
  State<ScanConnectScreen> createState() => _ScanConnectScreenState();
}

class _ScanConnectScreenState extends State<ScanConnectScreen> {
  final Map<String, BleRow> _found = {};
  List<BleRow> _devices = [];
  int? _selectedIndex;

  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _stopTimer;
  int _scanEpoch = 0;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return (statuses[Permission.bluetoothScan]?.isGranted ?? false);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _startScan() async {
    final ok = await _ensurePermissions();
    if (!ok) {
      _snack('BLE Scan Permission fehlt');
      return;
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _snack('Bluetooth ist aus');
      return;
    }

    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _stopTimer?.cancel();

    _scanEpoch++;
    final epoch = _scanEpoch;

    setState(() {
      _found.clear();
      _devices = [];
      _selectedIndex = null;
      _isScanning = true;
    });

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      if (epoch != _scanEpoch) return;
      bool changed = false;

      for (final r in results) {
        final id = r.device.remoteId.str;
        final advName = r.advertisementData.advName.trim();
        final platName = r.device.platformName.trim();
        final name = advName.isNotEmpty
            ? advName
            : (platName.isNotEmpty ? platName : 'Unnamed');

        _found[id] = BleRow(device: r.device, id: id, name: name, rssi: r.rssi);
        changed = true;
      }

      if (changed) {
        final list = _found.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        setState(() => _devices = list);
      }
    });

    await FlutterBluePlus.startScan();

    _stopTimer = Timer(const Duration(seconds: 6), () async {
      if (epoch != _scanEpoch) return;
      await FlutterBluePlus.stopScan();
      if (mounted) setState(() => _isScanning = false);
    });
  }

  Future<void> _connectSelected() async {
    if (_selectedIndex == null) return;
    final row = _devices[_selectedIndex!];

    try {
      await bleManager.connectNus(row);
      if (!mounted) return;
      _snack('Connected: ${row.name}');
    } catch (e) {
      _snack('Connect failed (NUS?)');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fenster größer wie besprochen
    return Scaffold(
      appBar: AppBar(title: const Text('Scan+Connect')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final windowHeight = constraints.maxHeight * 0.75;
          final windowWidth = constraints.maxWidth * 0.9;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: SizedBox(
                    height: windowHeight,
                    width: windowWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.zero,
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _isScanning ? 'Scanning…' : 'Found: ${_devices.length}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isScanning ? null : _startScan,
                                  child: const Text('Rescan'),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: _devices.isEmpty
                                ? Center(
                                    child: Text(
                                      _isScanning ? 'Scanning…' : 'Keine Geräte',
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _devices.length,
                                    itemBuilder: (context, index) {
                                      final d = _devices[index];
                                      final selected = index == _selectedIndex;
                                      return Container(
                                        color: selected ? const Color(0xFFB9F6CA) : null,
                                        child: ListTile(
                                          dense: true,
                                          title: Text(d.name),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('MAC/ID: ${d.id}', style: const TextStyle(fontSize: 12)),
                                              Text('RSSI: ${d.rssi} dBm', style: const TextStyle(fontSize: 12)),
                                            ],
                                          ),
                                          onTap: () => setState(() => _selectedIndex = index),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: ListenableBuilder(
                                listenable: bleManager,
                                builder: (context, _) {
                                  final busy = bleManager.isConnecting;
                                  return ElevatedButton(
                                    onPressed: (_selectedIndex == null || busy) ? null : _connectSelected,
                                    child: Text(busy ? 'Connecting…' : 'Connect (NUS)'),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: bleManager,
                builder: (context, _) {
                  final s = bleManager.isConnected
                      ? 'Connected: ${bleManager.connectedName ?? bleManager.connectedId}'
                      : 'Not connected';
                  return Text(s);
                },
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

/* =======================
   Device screen
   ======================= */

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  String _s(Map<String, dynamic> m, String key, String fallback) {
    final v = m[key];
    if (v == null) return fallback;
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: ListenableBuilder(
          listenable: bleManager,
          builder: (context, _) {
            final info = bleManager.deviceInfo;

            final connected = bleManager.isConnected;
            final devName = bleManager.connectedName ?? '(none)';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Device: $devName', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text(connected ? 'Status: connected' : 'Status: not connected'),
                const SizedBox(height: 16),

                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: connected ? bleManager.requestDeviceInfo : null,
                  child: const Text('Read Info (JSON via NUS)'),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1),

                const SizedBox(height: 12),
                _kv('DeviceName', _s(info, 'devicename', '(waiting…)')),
                _kv('Serial', _s(info, 'serial', '(waiting…)')),
                _kv('Battery', _s(info, 'battery', '(waiting…)')),
                _kv('Position', _s(info, 'position', '(waiting…)')),
                _kv('Brightness', _s(info, 'brightness', '(waiting…)')),
                _kv('Temperature', _s(info, 'temperature', '(waiting…)')),
                const Spacer(),

                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: bleManager.isConnected ? bleManager.disconnect : null,
                  child: const Text('Disconnect'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
