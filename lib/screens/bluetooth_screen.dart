import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  State<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  List<ScanResult> _scanResults = []; // Change to ScanResult
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  late PixelLightsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<PixelLightsViewModel>();
    if (_viewModel.bluetoothDevice == null) {
      // Added to make sure we aren't running if already connected.
      // Call the new method to check permissions before starting the scan.
      _checkAndStartBluetoothScan(_viewModel);
    }
    _isScanningSubscription = _viewModel.bluetoothService.isScanningStream
        .listen((value) {
          setState(() {
            _isScanning = value;
          });
        });

    _scanSubscription = _viewModel.bluetoothService.scanResults.listen((
      results,
    ) {
      if (!mounted) return;
      setState(() {
        //_scanResults = results;
        _scanResults.clear();
        for (ScanResult result in results) {
          if (result.device.name.isNotEmpty) {
            _scanResults.add(result);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    super.dispose();
  }

  // New method to check and request permissions.
  Future<void> _checkAndStartBluetoothScan(
    PixelLightsViewModel viewModel,
  ) async {
    if (Platform.isAndroid) {
      // Check for Bluetooth permissions on Android.
      bool hasPermissions = await _requestBluetoothPermissions();
      if (!hasPermissions) {
        // Permissions were not granted, handle accordingly (e.g., show an error).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bluetooth permissions are required."),
            ),
          );
        }
        return;
      }
    }
    // If permissions are granted or not on Android, start the scan.
    _startBluetoothScan(viewModel);
  }

  // New method to request Bluetooth permissions.
  Future<bool> _requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetooth,
          Permission.location, // required for bluetooth scan
        ].request();

    bool allGranted = true;
    for (var status in statuses.values) {
      if (!status.isGranted) {
        allGranted = false;
        break;
      }
    }

    if (!allGranted) {
      if (await Permission.location.request().isGranted) {
        if (await Permission.bluetooth.request().isGranted) {
          if (await Permission.bluetoothScan.request().isGranted) {
            if (await Permission.bluetoothConnect.request().isGranted) {
              return true;
            }
          }
        }
      }
    }

    return allGranted;
  }

  void _startBluetoothScan(PixelLightsViewModel viewModel) async {
    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    viewModel.bluetoothService.isAvailable.then((value) {
      if (!value) {
        debugPrint("Bluetooth not available");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bluetooth is not available")),
          );
        }
      }
    });
    await viewModel.startBluetoothScan();
  }

  void _stopBluetoothScan(PixelLightsViewModel viewModel) {
    viewModel.stopBluetoothScan();
  }

  Future<void> _connectToDevice(
    BluetoothDevice device,
    PixelLightsViewModel viewModel,
  ) async {
    if (_isScanning) return;
    _stopBluetoothScan(viewModel);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) {
      viewModel.connectToDevice(device);
    }
  }

  void _disconnectDevice(PixelLightsViewModel viewModel) async {
    viewModel.disconnectDevice();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: BackgroundMesh(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    viewModel.bluetoothDevice != null
                        ? "Connected to ${viewModel.bluetoothDevice?.name}"
                        : "Not connected.",
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 20.0,
                        bottom: 20.0,
                        left: 20,
                        right: 20,
                      ),
                      child: ListView.builder(
                        itemCount: _scanResults.length,
                        itemBuilder: (context, index) {
                          ScanResult result = _scanResults[index];
                          BluetoothDevice device = result.device;
                          int rssi = result.rssi; // Get RSSI here
                          Color backgroundColor =
                              index % 2 == 0
                                  ? Colors.grey[300]!.withOpacity(0.8)
                                  : Colors.grey[200]!.withOpacity(0.8);
                          return Container(
                            color: backgroundColor,
                            child: ListTile(
                              title: Text(
                                device.name.isNotEmpty
                                    ? device.name
                                    : device.remoteId.str,
                              ),
                              subtitle: Text(
                                '${device.remoteId.str} | RSSI: $rssi dBm',
                              ), // Display RSSI
                              trailing:
                                  viewModel.bluetoothDevice != null &&
                                          device == viewModel.bluetoothDevice
                                      ? const Icon(
                                        Icons.bluetooth_connected,
                                        color: Color(0xFF1B5E20),
                                      )
                                      : const Icon(Icons.bluetooth),
                              onTap: () => _connectToDevice(device, viewModel),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        viewModel.bluetoothDevice != null
                            ? () => _disconnectDevice(viewModel)
                            : null,
                    child: const Text("Disconnect"),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isScanning
                            ? () => _stopBluetoothScan(viewModel)
                            : () => _checkAndStartBluetoothScan(viewModel),
                    child: Text(_isScanning ? "Stop" : "Scan"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
