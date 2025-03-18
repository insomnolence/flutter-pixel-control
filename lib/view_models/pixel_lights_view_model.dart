import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pixel_lights/models/packet.dart';
import 'package:pixel_lights/models/patterns.dart' as pixel_patterns;
import 'package:pixel_lights/services/bluetooth_services.dart';

class PixelLightsViewModel extends ChangeNotifier {
  // --- Data for Manual Fragment ---
  int? colorPoint1;
  int? colorPoint2;
  int? colorPoint3;
  Completer? completer;
  bool _isDisposed = false;
  StreamSubscription? packetStream;
  pixel_patterns.Steps packetToSend = pixel_patterns.Steps();

  // Set up the values being tracked across the fragments.
  Color color1 = Colors.red;
  Color color2 = Colors.white;
  Color color3 = Colors.green;

  Pattern patternValue = Pattern.MiniTwinkle;

  int intensityValue = 128;
  int rateValue = 100;
  int levelValue = 128;

  final IBluetoothService _bluetoothService;

  PixelLightsViewModel({IBluetoothService? bluetoothService})
    : _bluetoothService = bluetoothService ?? PixelBluetoothService();

  IBluetoothService get bluetoothService => _bluetoothService;

  // --- Bluetooth ---
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;
  BluetoothCharacteristic? get txCharacteristic => _txCharacteristic;

  // New method to start scanning.
  Future<void> startBluetoothScan() async {
    await _bluetoothService.startScan(timeout: const Duration(seconds: 15));
    notifyListeners();
  }

  // New method to stop scanning.
  Future<void> stopBluetoothScan() async {
    await _bluetoothService.stopScan();
    notifyListeners();
  }

  // New method to connect to a device.
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      _connectionStateSubscription
          ?.cancel(); // Cancel any existing subscriptions
      //Listen to the connection state
      _connectionStateSubscription = _bluetoothService
          .connectionState(device)
          .listen(
            (BluetoothConnectionState state) {
              debugPrint("Connection State: $state");
              if (state == BluetoothConnectionState.disconnected) {
                debugPrint("Device Disconnected.");
                // Clear device and characteristic
                _bluetoothDevice = null;
                _txCharacteristic = null;
                notifyListeners(); // Update UI
              } else if (state == BluetoothConnectionState.connected) {
                _bluetoothDevice = device;
                _discoverTxCharacteristic(device);
                notifyListeners();
              }
            },
            onError: (Object error) {
              debugPrint("Connection State Error: $error");
              disconnectDevice();
            },
          );
      await _bluetoothService.connect(device);
    } on FlutterBluePlusException catch (e) {
      debugPrint("FlutterBluePlusException Error connecting: $e");
      disconnectDevice(); // try to disconnect on errors.
    } catch (e) {
      debugPrint("Error connecting: $e");
      // Handle error
      disconnectDevice(); // try to disconnect on errors.
    }
  }

  Future<void> _discoverTxCharacteristic(BluetoothDevice device) async {
    // Add a delay here:
    await Future.delayed(
      const Duration(milliseconds: 1000),
    ); // Adjust as needed
    _txCharacteristic = await _bluetoothService.discoverTxCharacteristic(
      device,
    );
    if (_txCharacteristic == null) {
      // Handle error
      debugPrint("Error discovering Tx characteristic");
    } else {
      notifyListeners();
    }
  }

  // New method to disconnect from a device.
  Future<void> disconnectDevice() async {
    if (_bluetoothDevice != null) {
      await _bluetoothService.disconnect(_bluetoothDevice!);
    }
  }

  // Use a pattern on the device.
  Future<void> usePattern(String patternName) async {
    final patternSteps = pixel_patterns.patterns[patternName];
    if (_bluetoothDevice == null) {
      debugPrint("usePattern: Bluetooth device is null");
    }
    if (patternSteps != null) {
      await sendPattern(patternSteps);
    }
  }

  Future<void> sendPattern(pixel_patterns.Steps steps) async {
    if (completer != null) {
      debugPrint("sendPattern: completer is not null. Stopping.");
      completer?.complete();
      completer = null;
    }
    completer = Completer();
    final iterator = steps.iterator; // get the iterator
    while (iterator.moveNext()) {
      // use the while loop, and moveNext()
      final i = iterator.current; // get the value.
      if (_isDisposed) {
        debugPrint("sendPattern: is disposed.");
        return;
      }

      final packet = i.pattern;

      debugPrint(
        "UsePattern: Pattern step duration: ${i.duration}, command: ${packet.command}, speed: ${packet.speed} , brightness: ${packet.brightness}, pattern: ${packet.pattern}, level: ${packet.level}, color: ${packet.color}",
      );

      await _bluetoothService.writeCharacteristic(_txCharacteristic, packet);
      debugPrint("UsePattern: writing packet");
      await Future.delayed(Duration(milliseconds: i.duration * 1000));
      if (_isDisposed) {
        debugPrint("sendPattern: is disposed.");
        return;
      }
    }
    completer?.complete();
    completer = null;
  }

  Future<void> processPacketInformation({bool controlPacket = false}) async {
    packetToSend = pixel_patterns.Steps();

    if (controlPacket) {
      // Create the Packet for HC_CONTROL
      final controlPacketToSend = Packet(
        PixelCommand.HC_CONTROL,
        intensityValue,
        rateValue,
        patternValue,
        color1.value,
        color2.value,
        color3.value,
        levelValue,
      );

      final controlStep = pixel_patterns.Step(0, controlPacketToSend);

      packetToSend.addStepClass(controlStep);
    } else {
      packetToSend.addStep(
        0,
        intensityValue,
        rateValue,
        levelValue,
        patternValue,
        color1.value,
        color2.value,
        color3.value,
      );
    }

    await sendPattern(packetToSend);
  }

  //dispose the class
  @override
  void dispose() {
    _isDisposed = true;
    packetStream?.cancel();
    completer?.complete();
    completer = null;
    _connectionStateSubscription?.cancel();
    _bluetoothService.dispose(); // Call the dispose on the bluetoothService
    super.dispose();
  }
}
