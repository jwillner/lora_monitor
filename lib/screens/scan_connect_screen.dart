import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/ble_row.dart';
import '../services/ble_manager.dart';

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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _isScanning
                                        ? 'Scanning…'
                                        : 'Found: ${_devices.length}',
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
                                        color: selected
                                            ? const Color(0xFFB9F6CA)
                                            : null,
                                        child: ListTile(
                                          dense: true,
                                          title: Text(d.name),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('MAC/ID: ${d.id}',
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                              Text('RSSI: ${d.rssi} dBm',
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            ],
                                          ),
                                          onTap: () => setState(
                                              () => _selectedIndex = index),
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
                                    onPressed: (_selectedIndex == null || busy)
                                        ? null
                                        : _connectSelected,
                                    child: Text(
                                        busy ? 'Connecting…' : 'Connect (NUS)'),
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
