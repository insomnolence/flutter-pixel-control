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
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  late PixelLightsViewModel _viewModel;

  // Search-related variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<PixelLightsViewModel>();
    if (_viewModel.bluetoothDevice == null) {
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
        _scanResults.clear();
        for (ScanResult result in results) {
          if (result.device.name.isNotEmpty) {
            _scanResults.add(result);
          }
        }
      });
    });

    // Listen for changes in the search box
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged); // Remove listener
    _searchController.dispose(); // Dispose controller
    super.dispose();
  }

  // Method to handle search query changes
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _checkAndStartBluetoothScan(
    PixelLightsViewModel viewModel,
  ) async {
    if (Platform.isAndroid) {
      bool hasPermissions = await _requestBluetoothPermissions();
      if (!hasPermissions) {
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
    _startBluetoothScan(viewModel);
  }

  Future<bool> _requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetooth,
          Permission.location,
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
    // Filter the scan results based on the search query
    final filteredResults =
        _scanResults.where((result) {
          final deviceName = result.device.name.toLowerCase();
          return deviceName.contains(_searchQuery);
        }).toList();

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
                  // Search box
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: const InputDecoration(
                        labelText: 'Search for devices',
                        labelStyle: TextStyle(color: Colors.white),
                        prefixIcon: Icon(Icons.search, color: Colors.white),
                        enabledBorder: const OutlineInputBorder(
                          // Set border color when not focused
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          // Set border color when focused
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
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
                        itemCount:
                            filteredResults.length, // Use filtered results
                        itemBuilder: (context, index) {
                          ScanResult result =
                              filteredResults[index]; // Use filtered results
                          BluetoothDevice device = result.device;
                          int rssi = result.rssi;
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
                              ),
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
