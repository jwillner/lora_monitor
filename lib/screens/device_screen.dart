import 'package:flutter/material.dart';

import '../services/ble_manager.dart';

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
                _kv('Battery', _s(info, 'battery', '(waiting…)')),
                _kv('Position', _s(info, 'position', '(waiting…)')),
                _kv('Brightness', _s(info, 'brightness', '(waiting…)')),
                _kv('Temperature', _s(info, 'temperature', '(waiting…)')),
                const Spacer(),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero),
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
