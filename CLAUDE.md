# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Heltec Master is a Flutter BLE (Bluetooth Low Energy) scanner application for discovering and inspecting Heltec devices. The app scans for nearby BLE devices, displays signal strength (RSSI), and can connect to read service UUIDs.

## Build and Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run on specific device
flutter run -d <device_id>

# Build Android APK
flutter build apk

# Build iOS
flutter build ios

# Run tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Format code
dart format lib/
```

## Architecture

**Single-file architecture**: The entire application lives in `lib/main.dart` (~336 lines). There is no modular separation.

**State management**: Uses Flutter's built-in `StatefulWidget` pattern with no external state management library.

**Widget hierarchy**:
- `BleScannerApp` - MaterialApp root with Material 3 theme
- `BleScannerHome` - Main stateful widget containing all UI and logic

**Key data structure**:
```dart
class BleRow {
  final BluetoothDevice device;
  final String id;           // MAC address
  final String name;
  final int rssi;            // Signal strength
  final List<Guid> services; // Discovered BLE services
}
```

## Core Functionality

1. **BLE Scanning** - Requests permissions, scans for 6 seconds, sorts devices by RSSI
2. **Permission Handling** - Uses `permission_handler` for bluetoothScan, bluetoothConnect, locationWhenInUse
3. **Service Discovery** - Connects to selected device, discovers services, displays UUIDs

## Key Dependencies

- `flutter_blue_plus` (v1.31.17) - BLE scanning and connectivity
- `permission_handler` (v11.3.1) - Runtime permission management

## Platform Configuration

- **Android**: minSdkVersion 21 (Android 5.0+)
- **iOS**: Configured in `ios/Runner/Info.plist`
- Also supports: Web, Windows, macOS, Linux

## Notes

- UI strings are in German ("Scanning…", "Keine Geräte gefunden", etc.)
- The test file `test/widget_test.dart` contains Flutter boilerplate, not actual tests for this app
