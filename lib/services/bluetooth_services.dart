import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:pixel_lights/models/packet.dart';

abstract class IBluetoothService {
  Stream<List<ScanResult>> get scanResults;
  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device);
  Future<bool> get isAvailable;
  Future<void> startScan({Duration? timeout});
  Future<void> stopScan();
  Future<bool> connect(BluetoothDevice device);
  Future<void> disconnect(BluetoothDevice device);
  Future<BluetoothCharacteristic?> discoverTxCharacteristic(
    BluetoothDevice device,
  );
  Future<void> writeCharacteristic(
    BluetoothCharacteristic? gattChar,
    Packet packet,
  );
  Stream<bool> get isScanningStream; //add this new stream.
  void dispose();
}

class PixelBluetoothService implements IBluetoothService {
  final StreamController<bool> _isScanningController =
      StreamController<bool>.broadcast(); //new stream controller.
  Timer? _scanTimer; // Add a timer variable.

  // *** CRUCIAL: Double-Check These UUIDs ***
  // These are the ones that MUST match your ESP32 code *exactly*.
  static const String UART_SERVICE =
      "6e400001-b5a3-f393-e0a9-e50e24dcca9e"; // Example
  static const String UART_TX =
      "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Example

  static const int DEFAULT_CHUNK_SIZE = 20;
  int maxChunkSize = DEFAULT_CHUNK_SIZE;
  bool _isScanning = false; //add a new variable.

  //getter for isScanningStream
  @override
  Stream<bool> get isScanningStream => _isScanningController.stream;

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults; //use the real stream.

  @override
  Stream<BluetoothConnectionState> connectionState(BluetoothDevice device) =>
      device.connectionState;

  @override
  Future<bool> get isAvailable => FlutterBluePlus.isAvailable;

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
      await device.connect();
      // Wait for the connection to complete, or timeout.
      await device.connectionState.firstWhere(
        (state) => state == BluetoothConnectionState.connected,
      );
      debugPrint("Connected to device: ${device.platformName}");
      return true; // Return true when connection is successful.
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
      await device.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting: $e");
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

      // **HERE'S THE NEW DEBUGGING CODE**
      debugPrint("Discovered Services:");
      for (BluetoothService service in services) {
        debugPrint("  Service UUID: ${service.uuid.toString()}");
        // New: Print out the characteristics for each service.
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
  Future<void> writeCharacteristic(
    BluetoothCharacteristic? gattChar,
    Packet packet,
  ) async {
    if (gattChar == null) {
      debugPrint("BluetoothPacketSender: Tx Characteristic not found");
      return;
    }
    if (!gattChar.properties.writeWithoutResponse) {
      debugPrint(
        "PixelBluetoothService: TX characteristic does not support write without response.",
      );
      return;
    }
    Uint8List? bytesToSend = packet.createBytes();
    int bytesToSendPosition = 0;
    // Check to see if there is anything to write

    // Message to send
    final num = bytesToSendPosition ~/ maxChunkSize + 1;
    // Correct the sublist call.
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
    // **NEW DEBUG CODE HERE**
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
    } catch (e) {
      debugPrint("Error writing characteristic: $e");
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

  @override
  void dispose() {
    _isScanningController.close();
  }
}
