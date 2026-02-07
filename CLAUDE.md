# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Heltec Master is a Flutter BLE (Bluetooth Low Energy) application for discovering and communicating with Heltec devices via the Nordic UART Service (NUS). The app scans for nearby BLE devices, connects via NUS, and exchanges JSON-based commands/data.

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

**Project structure**:
```
lib/
├── main.dart              # Entry point
├── app.dart               # HeltecApp MaterialApp widget
├── constants/
│   └── nus_uuids.dart     # NUS service UUIDs
├── models/
│   └── ble_row.dart       # BleRow data class
├── services/
│   └── ble_manager.dart   # BleManager (NUS connection, JSON parsing)
└── screens/
    ├── home_screen.dart
    ├── scan_connect_screen.dart
    └── device_screen.dart
```

**State management**:
- `BleManager` (ChangeNotifier) - Global singleton (`bleManager`) for BLE connection state and NUS communication
- `StatefulWidget` for screen-local state (scan results, selection)

**Screens**:
- `HomeScreen` - Main menu with navigation tiles
- `ScanConnectScreen` - BLE scanning, device list, NUS connection
- `DeviceScreen` - Device info display, JSON commands, disconnect

## NUS (Nordic UART Service) Protocol

**UUIDs**:
- Service: `6e400001-b5a3-f393-e0a9-e50e24dcca9e`
- RX (write): `6e400002-b5a3-f393-e0a9-e50e24dcca9e`
- TX (notify): `6e400003-b5a3-f393-e0a9-e50e24dcca9e`

**Communication**: JSON lines over NUS. Send commands like `{"cmd":"get_info"}`, receive device info as JSON (devicename, serial, battery, position, brightness, temperature).

## Core Functionality

1. **BLE Scanning** - Requests permissions, scans for 6 seconds, sorts devices by RSSI
2. **NUS Connection** - Connects to device, discovers NUS service, sets up RX/TX characteristics with notifications
3. **JSON Communication** - Sends commands via RX, receives newline-terminated JSON via TX notifications
4. **Permission Handling** - Uses `permission_handler` for bluetoothScan, bluetoothConnect, locationWhenInUse

## Key Dependencies

- `flutter_blue_plus` (v1.31.17) - BLE scanning and connectivity
- `permission_handler` (v11.3.1) - Runtime permission management

## Platform Configuration

- **Android**: minSdkVersion 21 (Android 5.0+)
- **iOS**: Configured in `ios/Runner/Info.plist`
- Also supports: Web, Windows, macOS, Linux

## Notes

- UI strings are in German ("Scanning…", "Keine Geräte gefunden", etc.)
