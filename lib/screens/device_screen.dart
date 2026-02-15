import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ble_manager.dart';

const _modeOptions = <String, String>{
  'off': 'Off',
  'steady': 'Steady',
  'blink_async': 'Blink Async',
  'blink_sync': 'Blink Sync',
  'blink_backlight': 'Blink Backlight',
};

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final _snController = TextEditingController();
  final _devIdController = TextEditingController();
  String? _selectedMode;

  @override
  void initState() {
    super.initState();
    bleManager.addListener(_onBleChanged);
    _populateFromInfo();
  }

  @override
  void dispose() {
    bleManager.removeListener(_onBleChanged);
    _snController.dispose();
    _devIdController.dispose();
    super.dispose();
  }

  void _onBleChanged() {
    _populateFromInfo();

    final ack = bleManager.lastAck;
    if (ack != null && mounted) {
      final error = bleManager.lastError;
      final msg = ack ? 'Konfiguration gespeichert' : 'Fehler: ${error ?? "unbekannt"}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      bleManager.lastAck = null;
      bleManager.lastError = null;
    }
  }

  void _populateFromInfo() {
    final info = bleManager.deviceInfo;
    if (info.containsKey('sn') && _snController.text.isEmpty) {
      _snController.text = info['sn'].toString();
    }
    if (info.containsKey('devId') && _devIdController.text.isEmpty) {
      _devIdController.text = info['devId'].toString();
    }
    if (info.containsKey('mode') && _selectedMode == null) {
      final m = info['mode'].toString();
      if (_modeOptions.containsKey(m)) {
        setState(() => _selectedMode = m);
      }
    }
  }

  Future<void> _sendConfig() async {
    final sn = _snController.text.trim();
    final devIdText = _devIdController.text.trim();
    final devId = int.tryParse(devIdText);

    try {
      await bleManager.sendSetConfig(
        sn: sn.isNotEmpty ? sn : null,
        devId: devId,
        mode: _selectedMode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfiguration gesendet…')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Senden fehlgeschlagen: $e')),
        );
      }
    }
  }

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

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Device: $devName', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(connected ? 'Status: connected' : 'Status: not connected'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    onPressed: connected ? bleManager.requestDeviceInfo : null,
                    child: const Text('Read Info (JSON via NUS)'),
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _kv('DeviceName', _s(info, 'devicename', '(waiting…)')),
                  _kv('Serial', _s(info, 'serial', '(waiting…)')),
                  _kv('Position', _s(info, 'position', '(waiting…)')),
                  _kv('Temperature', '${_s(info, 'temperature', '–')} °C'),
                  _kv('Humidity', '${_s(info, 'humidity', '–')} %'),
                  _kv('Time', _s(info, 'time', '(waiting…)')),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text('Konfiguration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _snController,
                    maxLength: 31,
                    decoration: const InputDecoration(
                      labelText: 'Seriennummer (sn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _devIdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Device-ID (0–255)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: _modeOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedMode = v),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    onPressed: connected ? _sendConfig : null,
                    child: const Text('Senden'),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    onPressed: bleManager.isConnected ? bleManager.disconnect : null,
                    child: const Text('Disconnect'),
                  ),
                ],
              ),
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
          Text(k,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
