import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Enhanced connection phases for comprehensive state management
enum BleConnectionPhase {
  idle,
  scanning,
  deviceFound,
  connecting,
  discoveringServices,
  ready,
  disconnected,
  error
}

/// Comprehensive BLE connection state with progress and analytics
class BleConnectionState {
  final BleConnectionPhase phase;
  final BluetoothDevice? device;
  final String? message;
  final double progress;
  final Duration? elapsed;
  final int? signalStrength;
  final String? errorCode;
  final bool canRetry;
  final DateTime timestamp;

  BleConnectionState({
    required this.phase,
    this.device,
    this.message,
    this.progress = 0.0,
    this.elapsed,
    this.signalStrength,
    this.errorCode,
    this.canRetry = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Factory constructor for idle state
  factory BleConnectionState.idle() {
    return BleConnectionState(
      phase: BleConnectionPhase.idle,
      message: "Tap Auto Connect to find and connect to your ESP32 LED device",
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for scanning state
  factory BleConnectionState.scanning({String? message}) {
    return BleConnectionState(
      phase: BleConnectionPhase.scanning,
      message: message ?? "Searching for devices...",
      progress: 0.1,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for device found state
  factory BleConnectionState.deviceFound({
    required BluetoothDevice device,
    required int signalStrength,
  }) {
    return BleConnectionState(
      phase: BleConnectionPhase.deviceFound,
      device: device,
      message: "Found ${device.platformName}",
      progress: 0.3,
      signalStrength: signalStrength,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for connecting state
  factory BleConnectionState.connecting({
    required BluetoothDevice device,
  }) {
    return BleConnectionState(
      phase: BleConnectionPhase.connecting,
      device: device,
      message: "Connecting to ${device.platformName}...",
      progress: 0.5,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for discovering services state
  factory BleConnectionState.discoveringServices({
    required BluetoothDevice device,
  }) {
    return BleConnectionState(
      phase: BleConnectionPhase.discoveringServices,
      device: device,
      message: "Setting up connection...",
      progress: 0.8,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for ready state
  factory BleConnectionState.ready({
    required BluetoothDevice device,
  }) {
    return BleConnectionState(
      phase: BleConnectionPhase.ready,
      device: device,
      message: "Connected successfully",
      progress: 1.0,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for error state
  factory BleConnectionState.error({
    BluetoothDevice? device,
    required String message,
    required String errorCode,
    bool canRetry = true,
  }) {
    return BleConnectionState(
      phase: BleConnectionPhase.error,
      device: device,
      message: message,
      errorCode: errorCode,
      canRetry: canRetry,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for disconnected state
  factory BleConnectionState.disconnected() {
    return BleConnectionState(
      phase: BleConnectionPhase.disconnected,
      message: "Disconnected from device",
      timestamp: DateTime.now(),
    );
  }

  /// Copy with method for state updates
  BleConnectionState copyWith({
    BleConnectionPhase? phase,
    BluetoothDevice? device,
    String? message,
    double? progress,
    Duration? elapsed,
    int? signalStrength,
    String? errorCode,
    bool? canRetry,
    DateTime? timestamp,
  }) {
    return BleConnectionState(
      phase: phase ?? this.phase,
      device: device ?? this.device,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      elapsed: elapsed ?? this.elapsed,
      signalStrength: signalStrength ?? this.signalStrength,
      errorCode: errorCode ?? this.errorCode,
      canRetry: canRetry ?? this.canRetry,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Check if connection is in progress
  bool get isConnecting => 
      phase == BleConnectionPhase.connecting ||
      phase == BleConnectionPhase.discoveringServices;

  /// Check if connection is successful
  bool get isConnected => phase == BleConnectionPhase.ready;

  /// Check if there's an error
  bool get hasError => phase == BleConnectionPhase.error;

  /// Check if scanning
  bool get isScanning => phase == BleConnectionPhase.scanning;

  /// Get connection status title for UI
  String get statusTitle {
    switch (phase) {
      case BleConnectionPhase.ready:
        return "Connected to ${device?.platformName ?? 'Device'}";
      case BleConnectionPhase.connecting:
        return "Connecting...";
      case BleConnectionPhase.discoveringServices:
        return "Setting up connection...";
      case BleConnectionPhase.scanning:
        return "Searching for devices...";
      case BleConnectionPhase.error:
        return "Connection Error";
      case BleConnectionPhase.disconnected:
        return "Disconnected";
      default:
        return "Ready for Auto Connect";
    }
  }

  @override
  String toString() {
    return 'BleConnectionState{phase: $phase, device: ${device?.platformName}, message: $message, progress: $progress}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BleConnectionState &&
        other.phase == phase &&
        other.device == device &&
        other.message == message &&
        other.progress == progress;
  }

  @override
  int get hashCode {
    return phase.hashCode ^
        device.hashCode ^
        message.hashCode ^
        progress.hashCode;
  }
}