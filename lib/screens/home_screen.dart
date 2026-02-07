import 'package:flutter/material.dart';

import 'scan_connect_screen.dart';
import 'device_screen.dart';

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
