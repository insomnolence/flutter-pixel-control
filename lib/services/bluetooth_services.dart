import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:pixel_lights/models/packet.dart';
import 'package:pixel_lights/models/ble_connection_state.dart';

/// Event types for ESP32 notifications
enum Esp32NotificationType {
  rootTransferred,  // Another node took over as BLE root (0xFE, 0x01)
  unknown,
}

/// Notification event from ESP32
class Esp32Notification {
  final Esp32NotificationType type;
  final List<int> rawData;

  Esp32Notification({required this.type, required this.rawData});

  /// Parse notification data from ESP32
  factory Esp32Notification.fromData(List<int> data) {
    if (data.length >= 2 && data[0] == 0xFE) {
      switch (data[1]) {
        case 0x01:
          return Esp32Notification(type: Esp32NotificationType.rootTransferred, rawData: data);
      }
    }
    return Esp32Notification(type: Esp32NotificationType.unknown, rawData: data);
  }
}

abstract class IBluetoothService {
  Stream<List<ScanResult>> get scanResults;
  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device);
  Stream<BleConnectionState> get enhancedConnectionStateStream;
  Stream<Map<String, dynamic>> get healthDataStream;
  Stream<Esp32Notification> get esp32NotificationStream;
  Stream<int> get batteryLevelStream;
  BleConnectionState get currentConnectionState;
  Future<bool> get isAvailable;
  Future<void> startScan({Duration? timeout});
  Future<void> stopScan();
  Future<bool> connect(BluetoothDevice device);
  Future<bool> connectToDeviceEnhanced(BluetoothDevice device);
  Future<void> disconnect(BluetoothDevice device);
  Future<BluetoothCharacteristic?> discoverTxCharacteristic(
    BluetoothDevice device,
  );
  Future<bool> writeCharacteristic(
    BluetoothCharacteristic? gattChar,
    Packet packet,
  );
  Stream<bool> get isScanningStream;
  Future<bool> autoConnect({
    String? preferredDeviceName,
    Duration scanTimeout,
    Duration connectionTimeout,
  });
  Future<bool> retryConnection();
  void dispose();
}

class PixelBluetoothService implements IBluetoothService {
  final StreamController<bool> _isScanningController =
      StreamController<bool>.broadcast();
  final StreamController<BleConnectionState> _enhancedConnectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _healthDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Esp32Notification> _esp32NotificationController =
      StreamController<Esp32Notification>.broadcast();
  final StreamController<int> _batteryLevelController =
      StreamController<int>.broadcast();

  Timer? _scanTimer;
  Timer? _connectionTimeout;
  BleConnectionState _currentState = BleConnectionState.idle();
  String? _preferredDeviceName;
  String? _lastConnectedDeviceId;
  BluetoothCharacteristic? _healthCharacteristic;
  StreamSubscription<List<int>>? _healthSubscription;

  // Battery characteristic for receiving battery level updates
  BluetoothCharacteristic? _batteryCharacteristic;
  StreamSubscription<List<int>>? _batterySubscription;

  // TX characteristic for receiving ESP32 notifications (root transfer, etc.)
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _txNotificationSubscription;

  // Enhanced connection monitoring
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Timer? _connectionDebounceTimer;
  Timer? _healthDataWatchdog;
  DateTime? _lastHealthDataReceived;
  
  // Cache discovered services to avoid calling discoverServices() multiple times
  List<BluetoothService>? _cachedServices;

  // BLE UUIDs - Must match ESP32 firmware exactly (verified against esp32-firmware/main/main.cpp)
  // UART Service: Nordic UART Service (NUS) standard for BLE serial communication
  static const String UART_SERVICE = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String UART_TX = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  
  // Health Analytics Service: Custom UUIDs for ESP32 mesh network health monitoring
  static const String HEALTH_SERVICE = "12345678-1234-1234-1234-123456789abc";
  static const String HEALTH_CHARACTERISTIC = "87654321-4321-4321-4321-cba987654321";

  // Battery Service: Standard BLE Battery Service UUIDs (Bluetooth SIG)
  // Note: Use short 16-bit UUIDs as flutter_blue_plus returns them in short form
  static const String BATTERY_SERVICE = "180f";
  static const String BATTERY_CHARACTERISTIC = "2a19";

  static const int DEFAULT_CHUNK_SIZE = 20;
  int maxChunkSize = DEFAULT_CHUNK_SIZE;
  bool _isScanning = false; //add a new variable.

  //getter for isScanningStream
  @override
  Stream<bool> get isScanningStream => _isScanningController.stream;

  @override
  Stream<BleConnectionState> get enhancedConnectionStateStream => _enhancedConnectionStateController.stream;

  @override
  Stream<Map<String, dynamic>> get healthDataStream => _healthDataController.stream;

  @override
  Stream<Esp32Notification> get esp32NotificationStream => _esp32NotificationController.stream;

  @override
  Stream<int> get batteryLevelStream => _batteryLevelController.stream;

  @override
  BleConnectionState get currentConnectionState => _currentState;

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device) =>
      device.connectionState;

  @override
  Future<bool> get isAvailable => FlutterBluePlus.isSupported;

  void enableVerboseLogs() async {
    await FlutterBluePlus.setLogLevel(LogLevel.verbose);
  }

  @override
  Future<void> startScan({Duration? timeout}) async {
    _isScanning = true;
    _isScanningController.add(_isScanning); //update the controller.
    //await stopScan();
    debugPrint("Starting scan");
    enableVerboseLogs();
    try {
      if (timeout != null) {
        _scanTimer = Timer(timeout, () async {
          debugPrint('Bluetooth scan timed out');
          await stopScan();
        });
      }
      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      debugPrint("Error starting scan: $e");
      await stopScan();
    }
  }

  @override
  Future<void> stopScan() async {
    _scanTimer?.cancel(); // Cancel the timer.
    _scanTimer = null;
    _isScanning = false;
    _isScanningController.add(_isScanning); //update the controller.
    debugPrint("Stopping Scan.");
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint("Error stopping scan: $e");
    }
  }

  @override
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      // Wait for the connection to complete, or timeout after 15 seconds.
      await device.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint("Connection timeout: Device did not connect within 15 seconds");
          throw TimeoutException("Connection timed out after 15 seconds");
        },
      );
      debugPrint("Connected to device: ${device.platformName}");
      return true; // Return true when connection is successful.
    } on TimeoutException catch (e) {
      debugPrint("Connection timeout: $e");
      try {
        await device.disconnect();
      } catch (_) {}
      return false;
    } on FlutterBluePlusException catch (e) {
      debugPrint("FlutterBluePlusException Error connecting: $e");
      return false; // return false if there's an error.
    } catch (e) {
      debugPrint("Error connecting: $e");
      return false; // Return false if there's an error.
    }
  }

  @override
  Future<void> disconnect(BluetoothDevice device) async {
    try {
      // Stop enhanced monitoring
      _stopConnectionMonitoring();
      _stopHealthDataWatchdog();

      // Unsubscribe from all notifications before disconnecting
      _unsubscribeFromHealth();
      _unsubscribeFromBattery();
      _unsubscribeFromTxNotifications();

      // Clear cached services
      _cachedServices = null;
      _healthSubscriptionRetryCount = 0;

      await device.disconnect();
      // Update enhanced connection state to trigger analytics cleanup
      _updateConnectionState(BleConnectionState.disconnected());

      debugPrint("✅ Clean disconnection from ${device.platformName}");
    } catch (e) {
      debugPrint("Error disconnecting: $e");
      // Still update state and cleanup even if disconnect fails
      _stopConnectionMonitoring();
      _stopHealthDataWatchdog();
      _unsubscribeFromBattery();
      _unsubscribeFromTxNotifications();
      _cachedServices = null;
      _healthSubscriptionRetryCount = 0;
      _updateConnectionState(BleConnectionState.disconnected());
    }
  }

  @override
  Future<BluetoothCharacteristic?> discoverTxCharacteristic(
    BluetoothDevice device,
  ) async {
    try {
      // **Wait for the connection to be stable.**
      await Future.delayed(const Duration(seconds: 1)); // Adjust if needed
      // Add a retry mechanism
      int retries = 3;
      bool success = false;
      List<BluetoothService> services = [];

      if (!device.isConnected) {
        return null;
      }

      while (retries > 0 && !success && device.isConnected) {
        try {
          services = await device.discoverServices(
            subscribeToServicesChanged: false,
            timeout: 50,
          ); // Increased timeout
          success = true;
        } catch (e) {
          debugPrint("Error discovering services on retry $retries: $e");
          retries--;
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }

      if (!success) {
        debugPrint(
          "PixelBluetoothService: Failed to discover services after retries",
        );
        return null;
      }
      
      // Cache services for later use (e.g., health characteristic discovery)
      _cachedServices = services;

      // Debugging prints
      debugPrint("Discovered Services:");
      for (BluetoothService service in services) {
        debugPrint("  Service UUID: ${service.uuid.toString()}");
        // Print out the characteristics for each service.
        debugPrint("    Characteristics:");
        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          debugPrint(
            "      Characteristic UUID: ${characteristic.uuid.toString()}",
          );
          debugPrint(
            "        Properties: ${characteristic.properties.toString()}",
          );
        }
      }

      BluetoothService? uartService;
      for (BluetoothService service in services) {
        //added debug print here to see what the service uuid is.
        debugPrint(
          "Checking for service with UUID: ${service.uuid.toString()}",
        );
        if (service.uuid.toString() == UART_SERVICE) {
          uartService = service;
          break;
        }
      }

      if (uartService == null) {
        debugPrint("PixelBluetoothService: UART Service not found");
        return null;
      } else {
        debugPrint("Found UART Service!");
      }

      BluetoothCharacteristic? txCharacteristic;
      for (BluetoothCharacteristic char in uartService.characteristics) {
        //added debug print here to see what characteristics are being checked.
        debugPrint(
          "Checking for TX characteristic with UUID: ${char.uuid.toString()}",
        );
        if (char.uuid.toString() == UART_TX) {
          if (char.properties.writeWithoutResponse) {
            // Only return the characteristic if it supports writeWithoutResponse
            txCharacteristic = char;
            break;
          } else {
            debugPrint(
              "PixelBluetoothService: TX characteristic does not support write without response.",
            );
          }
        }
      }
      if (txCharacteristic != null) {
        debugPrint("Found TX Characteristic!");
        updateMaxChunkSize(txCharacteristic);

        // Store and subscribe to TX notifications for ESP32 events (root transfer, etc.)
        _txCharacteristic = txCharacteristic;
        await _subscribeToTxNotifications();
      } else {
        debugPrint("PixelBluetoothService: TX Characteristic not found");
      }
      return txCharacteristic;
    } catch (e) {
      debugPrint("Error discovering characteristics: $e");
      return null;
    }
  }

  void updateMaxChunkSize(BluetoothCharacteristic? characteristic) {
    // removed static
    if (characteristic == null) {
      maxChunkSize = DEFAULT_CHUNK_SIZE;
      return;
    }
    maxChunkSize = DEFAULT_CHUNK_SIZE;
  }

  @override
  Future<bool> writeCharacteristic(
    BluetoothCharacteristic? gattChar,
    Packet packet,
  ) async {
    if (gattChar == null) {
      debugPrint("BluetoothPacketSender: Tx Characteristic not found");
      return false;
    }
    if (!gattChar.properties.writeWithoutResponse) {
      debugPrint(
        "PixelBluetoothService: TX characteristic does not support write without response.",
      );
      return false;
    }
    Uint8List? bytesToSend = packet.createBytes();
    int bytesToSendPosition = 0;
    // Check to see if there is anything to write

    // Message to send
    final num = bytesToSendPosition ~/ maxChunkSize + 1;

    final bytesRemaining = bytesToSend.length - bytesToSendPosition;
    final chunkSize =
        bytesRemaining < maxChunkSize ? bytesRemaining : maxChunkSize;
    final sendByte = bytesToSend.sublist(
      bytesToSendPosition,
      bytesToSendPosition + chunkSize,
    );

    bytesToSendPosition += chunkSize;

    if (bytesToSendPosition >= bytesToSend.length) {
      // Clear out the information
      bytesToSend = null;
      bytesToSendPosition = 0;
    }

    // Print the raw bytes being sent
    debugPrint("BluetoothPacketSender: Sending raw bytes: $sendByte");

    // Print the formatted UUIDs (if applicable). Currently this section will not show anything since you are not sending a UUID, just data.
    debugPrint("BluetoothPacketSender: Sending formatted UUIDs:");
    for (int i = 0; i < sendByte.length; i++) {
      if (sendByte.length - i >= 16) {
        // Attempt to parse as a 128-bit UUID (16 bytes)
        try {
          // Convert bytes to a UUID
          List<int> uuidBytes = sendByte.sublist(i, i + 16);

          // Ensure the UUID is long enough.
          if (uuidBytes.length == 16) {
            String uuidString = bytesToUuidString(uuidBytes);
            debugPrint("    UUID: $uuidString");
          }
          i += 15; // Skip over the UUID bytes
        } catch (e) {
          debugPrint("    Could not parse bytes as UUID: $e");
        }
      }
    }

    debugPrint(
      "BluetoothPacketSender: Sending packet $num with ${sendByte.length}",
    );

    // The new way to set the characteristic value:
    try {
      await gattChar.write(sendByte, withoutResponse: true);
      return true;
    } catch (e) {
      debugPrint("Error writing characteristic: $e");
      return false;
    }
  }

  // New function to convert bytes to a UUID string
  String bytesToUuidString(List<int> bytes) {
    if (bytes.length != 16) {
      throw ArgumentError("UUID must be 16 bytes long");
    }

    // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    String uuid = "";

    for (int i = 0; i < 16; i++) {
      uuid += bytes[i].toRadixString(16).padLeft(2, '0');
      if (i == 3 || i == 5 || i == 7 || i == 9) {
        uuid += "-";
      }
    }
    return uuid;
  }

  /// Auto-connect workflow implementation
  @override
  Future<bool> autoConnect({
    String? preferredDeviceName,
    Duration scanTimeout = const Duration(seconds: 10),
    Duration connectionTimeout = const Duration(seconds: 15),
  }) async {
    _preferredDeviceName = preferredDeviceName;
    
    StreamSubscription<List<ScanResult>>? scanSubscription;
    
    try {
      // Phase 1: Start scanning
      _updateConnectionState(BleConnectionState.scanning(
        message: "Searching for devices...",
      ));
      
      await startScan(timeout: scanTimeout);
      
      // Phase 2: Monitor scan results for preferred device
      final deviceCompleter = Completer<BluetoothDevice>();
      
      scanSubscription = scanResults.listen((results) {
        // Guard against double-completion if multiple devices match
        if (deviceCompleter.isCompleted) return;
        
        for (var result in results) {
          if (_shouldAutoConnectToDevice(result)) {
            _updateConnectionState(BleConnectionState.deviceFound(
              device: result.device,
              signalStrength: result.rssi,
            ));
            
            deviceCompleter.complete(result.device);
            return;
          }
        }
      });
      
      // Wait for device or timeout
      final device = await deviceCompleter.future.timeout(scanTimeout);
      
      // Phase 3: Connect to device
      return await _performAutoConnect(device, connectionTimeout);
      
    } catch (e) {
      _updateConnectionState(BleConnectionState.error(
        message: "Auto-connect failed: ${e.toString()}",
        errorCode: "AUTO_CONNECT_FAILED",
        canRetry: true,
      ));
      return false;
    } finally {
      // Ensure subscription is always cleaned up
      await scanSubscription?.cancel();
      await stopScan();
    }
  }

  /// Check if device should be auto-connected to
  bool _shouldAutoConnectToDevice(ScanResult result) {
    if (result.device.platformName.isEmpty) return false;
    
    // Priority 1: Previously connected device
    if (_lastConnectedDeviceId != null && 
        result.device.remoteId.str == _lastConnectedDeviceId) {
      return true;
    }
    
    // Priority 2: Preferred device name
    if (_preferredDeviceName != null && 
        result.device.platformName.toLowerCase().contains(_preferredDeviceName!.toLowerCase())) {
      return true;
    }
    
    // Priority 3: Strong signal device with pixel-related name
    if (result.rssi > -60 && 
        (result.device.platformName.toLowerCase().contains('pixel') ||
         result.device.platformName.toLowerCase().contains('esp32') ||
         result.device.platformName.toLowerCase().contains('led'))) {
      return true;
    }
    
    return false;
  }

  /// Perform the actual auto-connect process
  Future<bool> _performAutoConnect(BluetoothDevice device, Duration timeout) async {
    try {
      // Phase 3: Connecting
      _updateConnectionState(BleConnectionState.connecting(device: device));
      
      _connectionTimeout = Timer(timeout, () {
        // Only set error if still in connecting state (avoid race with successful connection)
        if (_currentState.phase == BleConnectionPhase.connecting ||
            _currentState.phase == BleConnectionPhase.discoveringServices) {
          _updateConnectionState(BleConnectionState.error(
            device: device,
            message: "Connection timeout",
            errorCode: "CONNECTION_TIMEOUT",
            canRetry: true,
          ));
        }
      });
      
      final connected = await connect(device);
      _connectionTimeout?.cancel();
      
      if (!connected) {
        throw Exception("Connection failed");
      }
      
      // Phase 4: Discovering services
      _updateConnectionState(BleConnectionState.discoveringServices(device: device));
      
      final characteristic = await discoverTxCharacteristic(device);
      
      if (characteristic != null) {
        // Also discover health characteristic for mesh analytics
        _healthCharacteristic = await discoverHealthCharacteristic(device);
        if (_healthCharacteristic != null) {
          // Subscribe to health updates
          await subscribeToHealthUpdates();
          debugPrint("PixelBluetoothService: ESP32 health analytics enabled");
        } else {
          debugPrint("PixelBluetoothService: ESP32 health analytics not available (older firmware?)");
        }

        // Discover battery characteristic for battery level monitoring
        _batteryCharacteristic = await discoverBatteryCharacteristic(device);
        if (_batteryCharacteristic != null) {
          // Subscribe to battery updates
          await subscribeToBatteryUpdates();
          debugPrint("PixelBluetoothService: Battery monitoring enabled");
        } else {
          debugPrint("PixelBluetoothService: Battery monitoring not available");
        }

        _lastConnectedDeviceId = device.remoteId.str;
        
        // Start enhanced connection monitoring
        await _startConnectionMonitoring(device);
        
        _updateConnectionState(BleConnectionState.ready(device: device));
        return true;
      } else {
        throw Exception("Failed to discover characteristics");
      }
      
    } catch (e) {
      _connectionTimeout?.cancel();
      _updateConnectionState(BleConnectionState.error(
        device: device,
        message: "Connection failed: ${e.toString()}",
        errorCode: "CONNECTION_ERROR",
        canRetry: true,
      ));
      return false;
    }
  }

  /// Enhanced connect method with analytics integration (for manual device selection)
  @override
  Future<bool> connectToDeviceEnhanced(BluetoothDevice device) async {
    try {
      return await _performAutoConnect(device, const Duration(seconds: 15));
    } catch (e) {
      _updateConnectionState(BleConnectionState.error(
        device: device,
        message: "Connection failed: ${e.toString()}",
        errorCode: "MANUAL_CONNECT_FAILED",
        canRetry: true,
      ));
      return false;
    }
  }

  /// Retry connection with the last device
  @override
  Future<bool> retryConnection() async {
    if (_currentState.phase != BleConnectionPhase.error) return false;
    
    final device = _currentState.device;
    if (device != null) {
      return await _performAutoConnect(device, const Duration(seconds: 15));
    } else {
      return await autoConnect(
        preferredDeviceName: _preferredDeviceName,
      );
    }
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(BleConnectionState newState) {
    _currentState = newState;
    _enhancedConnectionStateController.add(newState);
    debugPrint("BLE Connection State: ${newState.phase} - ${newState.message}");
  }

  /// Discover ESP32 health characteristic for mesh analytics
  /// Uses cached services if available to avoid redundant discoverServices() calls
  Future<BluetoothCharacteristic?> discoverHealthCharacteristic(BluetoothDevice device) async {
    try {
      // Use cached services if available, otherwise discover
      final services = _cachedServices ?? await device.discoverServices();
      
      // DEBUG: Log services (only if we had to discover them fresh)
      if (_cachedServices == null) {
        debugPrint("PixelBluetoothService: Discovered ${services.length} services:");
        for (BluetoothService service in services) {
          debugPrint("  Service UUID: ${service.uuid.toString().toLowerCase()}");
        }
      } else {
        debugPrint("PixelBluetoothService: Using cached services (${services.length} services)");
      }
      debugPrint("PixelBluetoothService: Looking for health service: ${HEALTH_SERVICE.toLowerCase()}");
      
      // Find health service
      BluetoothService? healthService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == HEALTH_SERVICE.toLowerCase()) {
          healthService = service;
          break;
        }
      }
      
      if (healthService == null) {
        debugPrint("PixelBluetoothService: Health service not found");
        return null;
      }
      
      // Find health characteristic
      for (BluetoothCharacteristic char in healthService.characteristics) {
        if (char.uuid.toString().toLowerCase() == HEALTH_CHARACTERISTIC.toLowerCase()) {
          debugPrint("PixelBluetoothService: Health characteristic found!");
          
          // Check if characteristic supports notifications
          if (char.properties.notify) {
            return char;
          } else {
            debugPrint("PixelBluetoothService: Health characteristic does not support notifications.");
            return null;
          }
        }
      }
      
      debugPrint("PixelBluetoothService: Health characteristic not found in service");
      return null;
      
    } catch (e) {
      debugPrint("Error discovering health characteristic: $e");
      return null;
    }
  }
  
  /// Subscribe to ESP32 health notifications with automatic recovery
  Future<void> subscribeToHealthUpdates() async {
    await _subscribeToHealthWithRecovery();
    _startHealthDataWatchdog();
  }

  /// Discover ESP32 battery characteristic for battery level monitoring
  /// Uses cached services if available to avoid redundant discoverServices() calls
  Future<BluetoothCharacteristic?> discoverBatteryCharacteristic(BluetoothDevice device) async {
    try {
      // Use cached services if available, otherwise discover
      final services = _cachedServices ?? await device.discoverServices();

      debugPrint("PixelBluetoothService: Looking for battery service: ${BATTERY_SERVICE.toLowerCase()}");

      // Find battery service
      BluetoothService? batteryService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == BATTERY_SERVICE.toLowerCase()) {
          batteryService = service;
          break;
        }
      }

      if (batteryService == null) {
        debugPrint("PixelBluetoothService: Battery service not found");
        return null;
      }

      // Find battery characteristic
      for (BluetoothCharacteristic char in batteryService.characteristics) {
        if (char.uuid.toString().toLowerCase() == BATTERY_CHARACTERISTIC.toLowerCase()) {
          debugPrint("PixelBluetoothService: Battery characteristic found!");

          // Check if characteristic supports read or notify
          if (char.properties.notify || char.properties.read) {
            return char;
          } else {
            debugPrint("PixelBluetoothService: Battery characteristic does not support read or notify.");
            return null;
          }
        }
      }

      debugPrint("PixelBluetoothService: Battery characteristic not found in service");
      return null;

    } catch (e) {
      debugPrint("Error discovering battery characteristic: $e");
      return null;
    }
  }

  /// Subscribe to battery level notifications
  Future<void> subscribeToBatteryUpdates() async {
    if (_batteryCharacteristic == null) {
      debugPrint("PixelBluetoothService: No battery characteristic to subscribe to");
      return;
    }

    try {
      // Enable notifications if supported
      if (_batteryCharacteristic!.properties.notify) {
        await _batteryCharacteristic!.setNotifyValue(true);

        // Cancel existing subscription
        _batterySubscription?.cancel();

        // Subscribe to battery level updates
        _batterySubscription = _batteryCharacteristic!.lastValueStream.listen(
          (data) {
            if (data.isNotEmpty) {
              final batteryLevel = data[0]; // Battery level is a single byte (0-100)
              debugPrint("🔋 Battery level: $batteryLevel%");
              _batteryLevelController.add(batteryLevel);
            }
          },
          onError: (error) {
            debugPrint("🔶 Battery subscription error: $error");
          },
          cancelOnError: false,
        );

        debugPrint("✅ PixelBluetoothService: Subscribed to battery level notifications");

        // Also do an initial read to get current value
        if (_batteryCharacteristic!.properties.read) {
          final readData = await _batteryCharacteristic!.read();
          if (readData.isNotEmpty) {
            debugPrint("🔋 Battery level (initial read): ${readData[0]}%");
            _batteryLevelController.add(readData[0]);
          }
        }
      } else if (_batteryCharacteristic!.properties.read) {
        // If only read is supported, read once
        final data = await _batteryCharacteristic!.read();
        if (data.isNotEmpty) {
          final batteryLevel = data[0];
          debugPrint("🔋 Battery level (read): $batteryLevel%");
          _batteryLevelController.add(batteryLevel);
        }
      }
    } catch (e) {
      debugPrint("❌ Error subscribing to battery updates: $e");
    }
  }

  /// Unsubscribe from battery updates
  void _unsubscribeFromBattery() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
    _batteryCharacteristic = null;
  }

  /// Subscribe to TX characteristic for ESP32 notifications (root transfer, etc.)
  Future<void> _subscribeToTxNotifications() async {
    if (_txCharacteristic == null) {
      debugPrint("PixelBluetoothService: No TX characteristic to subscribe to for notifications");
      return;
    }

    // Check if the TX characteristic supports notifications
    if (!_txCharacteristic!.properties.notify) {
      debugPrint("PixelBluetoothService: TX characteristic does not support notifications");
      return;
    }

    try {
      // Enable notifications on TX characteristic
      await _txCharacteristic!.setNotifyValue(true);

      // Cancel existing subscription
      _txNotificationSubscription?.cancel();

      // Subscribe to TX notifications
      _txNotificationSubscription = _txCharacteristic!.lastValueStream.listen(
        (data) {
          debugPrint("📥 Received ESP32 notification: ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(', ')}");
          _parseEsp32Notification(data);
        },
        onError: (error) {
          debugPrint("🔶 TX notification subscription error: $error");
        },
        cancelOnError: false,
      );

      debugPrint("✅ PixelBluetoothService: Subscribed to TX notifications for ESP32 events");
    } catch (e) {
      debugPrint("❌ Error subscribing to TX notifications: $e");
    }
  }

  /// Parse and handle ESP32 notification data
  void _parseEsp32Notification(List<int> data) {
    if (data.isEmpty) return;

    final notification = Esp32Notification.fromData(data);

    switch (notification.type) {
      case Esp32NotificationType.rootTransferred:
        debugPrint("🔄 ESP32: Root transferred to another node - disconnection imminent");
        _esp32NotificationController.add(notification);
        break;
      case Esp32NotificationType.unknown:
        // Ignore unknown notifications (could be other data)
        debugPrint("📥 ESP32: Unknown notification type, ignoring");
        break;
    }
  }

  /// Unsubscribe from TX notifications
  void _unsubscribeFromTxNotifications() {
    _txNotificationSubscription?.cancel();
    _txNotificationSubscription = null;
    _txCharacteristic = null;
  }
  
  // Track health subscription retry attempts
  int _healthSubscriptionRetryCount = 0;
  static const int _maxHealthSubscriptionRetries = 3;

  /// Internal health subscription with recovery capability
  Future<void> _subscribeToHealthWithRecovery() async {
    if (_healthCharacteristic == null) {
      debugPrint("PixelBluetoothService: No health characteristic to subscribe to");
      return;
    }
    
    try {
      // Reset retry count on successful setup
      _healthSubscriptionRetryCount = 0;
      
      // Enable notifications
      await _healthCharacteristic!.setNotifyValue(true);
      
      // Cancel existing subscription
      _healthSubscription?.cancel();
      
      // Subscribe to health data updates with timeout and recovery
      _healthSubscription = _healthCharacteristic!.lastValueStream
          .timeout(Duration(seconds: 180)) // ESP32 sends every 10s, timeout at 3 minutes
          .listen(
        (data) {
          _lastHealthDataReceived = DateTime.now();
          _healthSubscriptionRetryCount = 0; // Reset on successful data
          _parseHealthData(data);
        },
        onError: (error) async {
          debugPrint("🔶 Health subscription lost: $error");
          // Auto-recover if still connected and under retry limit
          if (_currentState.isConnected && _healthSubscriptionRetryCount < _maxHealthSubscriptionRetries) {
            _healthSubscriptionRetryCount++;
            debugPrint("🔄 Recovering health subscription (attempt $_healthSubscriptionRetryCount/$_maxHealthSubscriptionRetries)...");
            await Future.delayed(Duration(seconds: 2));
            await _subscribeToHealthWithRecovery();
          } else if (_healthSubscriptionRetryCount >= _maxHealthSubscriptionRetries) {
            debugPrint("❌ Health subscription recovery failed after $_maxHealthSubscriptionRetries attempts");
          }
        },
        cancelOnError: false, // Keep trying to reconnect
      );
      
      debugPrint("✅ PixelBluetoothService: Subscribed to ESP32 health updates");
    } catch (e) {
      debugPrint("❌ Error subscribing to health updates: $e");
      // Retry after delay if still connected and under retry limit
      if (_currentState.isConnected && _healthSubscriptionRetryCount < _maxHealthSubscriptionRetries) {
        _healthSubscriptionRetryCount++;
        debugPrint("🔄 Retrying health subscription (attempt $_healthSubscriptionRetryCount/$_maxHealthSubscriptionRetries)...");
        await Future.delayed(Duration(seconds: 5));
        await _subscribeToHealthWithRecovery();
      } else if (_healthSubscriptionRetryCount >= _maxHealthSubscriptionRetries) {
        debugPrint("❌ Health subscription failed after $_maxHealthSubscriptionRetries attempts");
      }
    }
  }
  
  /// Start health data watchdog to detect stuck subscriptions
  void _startHealthDataWatchdog() {
    _healthDataWatchdog?.cancel();
    _healthDataWatchdog = Timer.periodic(Duration(minutes: 3), (timer) {
      if (_currentState.isConnected && _lastHealthDataReceived != null) {
        final timeSinceLastHealth = DateTime.now().difference(_lastHealthDataReceived!);
        if (timeSinceLastHealth.inMinutes > 5) { // 5 minute timeout - much more conservative
          debugPrint("🔶 Health data timeout (${timeSinceLastHealth.inMinutes}m) - recovering subscription");
          _subscribeToHealthWithRecovery();
        }
      }
    });
  }
  
  /// Start enhanced connection monitoring with automatic recovery
  Future<void> _startConnectionMonitoring(BluetoothDevice device) async {
    // Cancel any existing monitoring
    _stopConnectionMonitoring();
    
    try {
      _connectionStateSubscription = device.connectionState
          .distinct() // Avoid duplicate events
          .listen(
            (state) => _handleConnectionStateChange(state, device),
            onError: (error) => _handleConnectionStreamError(error, device),
            cancelOnError: false,
          );
      
      debugPrint("✅ Enhanced connection monitoring started for ${device.platformName}");
    } catch (e) {
      debugPrint("❌ Failed to start connection monitoring: $e");
    }
  }
  
  /// Handle connection state changes with debouncing
  void _handleConnectionStateChange(BluetoothConnectionState state, BluetoothDevice device) {
    debugPrint("🔵 Connection state: $state for ${device.platformName}");
    
    if (state == BluetoothConnectionState.disconnected) {
      // Debounce disconnection events to avoid UI flicker - increased to 2 seconds
      _connectionDebounceTimer?.cancel();
      _connectionDebounceTimer = Timer(Duration(seconds: 2), () {
        debugPrint("🔴 Confirmed disconnection: ${device.platformName}");
        _updateConnectionState(BleConnectionState.disconnected());
        _stopConnectionMonitoring();
        _stopHealthDataWatchdog();
      });
    } else if (state == BluetoothConnectionState.connected) {
      // Cancel any pending disconnection
      _connectionDebounceTimer?.cancel();
      debugPrint("✅ Connection confirmed: ${device.platformName}");
    }
  }
  
  /// Handle connection stream errors (often indicates disconnection)
  void _handleConnectionStreamError(dynamic error, BluetoothDevice device) {
    debugPrint("🔴 Connection stream error: $error");
    // Stream errors often indicate connection loss
    _updateConnectionState(BleConnectionState.error(
      device: device,
      message: "Connection monitoring failed",
      errorCode: "STREAM_ERROR",
      canRetry: true,
    ));
    _stopConnectionMonitoring();
  }
  
  /// Stop connection monitoring and cleanup timers
  void _stopConnectionMonitoring() {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _connectionDebounceTimer?.cancel();
    _connectionDebounceTimer = null;
  }
  
  /// Stop health data watchdog
  void _stopHealthDataWatchdog() {
    _healthDataWatchdog?.cancel();
    _healthDataWatchdog = null;
  }
  
  /// Parse ESP32 NetworkHealth data (7-byte packed struct)
  void _parseHealthData(List<int> data) {
    if (data.length != 8) {
      debugPrint("PixelBluetoothService: Invalid health data length: ${data.length} (expected 8)");
      return;
    }
    
    // Parse NetworkHealth struct (8 bytes total):
    // byte 0: overall_score (uint8_t - 1 byte)
    // byte 1: active_neighbors (uint8_t - 1 byte) 
    // byte 2: packet_success_rate (uint8_t - 1 byte)
    // byte 3: avg_signal_strength (int8_t - 1 byte)
    // byte 4-5: uptime_hours (uint16_t - 2 bytes, little endian)
    // byte 6: mesh_role (uint8_t - 1 byte)
    // byte 7: total_nodes (uint8_t - 1 byte)
    
    final healthData = {
      'overall_score': data[0],
      'active_neighbors': data[1], 
      'packet_success_rate': data[2],
      'avg_signal_strength': data[3] > 127 ? data[3] - 256 : data[3], // Convert to signed int8
      'uptime_hours': data[4] | (data[5] << 8), // Little endian uint16
      'mesh_role': data[6], // 0=client, 1=root_ble, 2=root_autonomous
      'total_nodes': data[7],
      'timestamp': DateTime.now(),
    };
    
    // Add role description for debugging
    String roleDescription;
    switch (healthData['mesh_role']) {
      case 0: roleDescription = 'client'; break;
      case 1: roleDescription = 'root_ble'; break;
      case 2: roleDescription = 'root_autonomous'; break;
      default: roleDescription = 'unknown'; break;
    }
    
    debugPrint("PixelBluetoothService: ESP32 Health Update - "
               "Score: ${healthData['overall_score']}%, "
               "Neighbors: ${healthData['active_neighbors']}, "
               "Total Nodes: ${healthData['total_nodes']}, "
               "Success: ${healthData['packet_success_rate']}%, "
               "RSSI: ${healthData['avg_signal_strength']}dBm, "
               "Uptime: ${healthData['uptime_hours']}h, "
               "Role: $roleDescription");
    
    _healthDataController.add(healthData);
  }
  
  /// Unsubscribe from health updates
  void _unsubscribeFromHealth() {
    _healthSubscription?.cancel();
    _healthSubscription = null;
    _healthCharacteristic = null;
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    _stopConnectionMonitoring();
    _stopHealthDataWatchdog();
    _unsubscribeFromHealth();
    _unsubscribeFromBattery();
    _unsubscribeFromTxNotifications();
    _isScanningController.close();
    _enhancedConnectionStateController.close();
    _healthDataController.close();
    _esp32NotificationController.close();
    _batteryLevelController.close();
    debugPrint("🧹 PixelBluetoothService disposed with full cleanup");
  }
}
