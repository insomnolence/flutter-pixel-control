import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/widgets/ble_device_list.dart';
import 'package:pixel_lights/models/ble_connection_state.dart';
import 'package:pixel_lights/core/utils/ble_utils.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixel_lights/models/connection_analytics.dart';
import 'package:pixel_lights/widgets/styled_snack_bar.dart';
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
          if (result.device.platformName.isNotEmpty) {
            _scanResults.add(result);
          }
        }
      });
    });

    // Listen for changes in the search box
    _searchController.addListener(_onSearchChanged);

    // Set up callback for root transfer (BLE displacement) notifications
    _viewModel.onRootTransferred = (message) {
      if (!mounted) return;
      _showRootTransferredDialog(message);
    };
  }

  /// Show dialog when another device takes over control
  void _showRootTransferredDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.orange),
              SizedBox(width: 8),
              Text('Control Transferred'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged); // Remove listener
    _searchController.dispose(); // Dispose controller
    _viewModel.onRootTransferred = null; // Clear callback
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
          showStyledSnackBar(
            context,
            message: "Bluetooth permissions are required.",
            icon: Icons.error,
            backgroundColor: Colors.red,
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
          showStyledSnackBar(
            context,
            message: "Bluetooth is not available",
            icon: Icons.bluetooth_disabled,
            backgroundColor: Colors.red,
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
    if (_isScanning) {
      _stopBluetoothScan(viewModel);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) {
      // Use enhanced analytics-aware connection method for manual device selection
      final success = await viewModel.bluetoothService.connectToDeviceEnhanced(device);
      if (success && mounted) {
        showStyledSnackBar(
          context,
          message: "Connected to ${device.platformName}",
          icon: Icons.bluetooth_connected,
          backgroundColor: Colors.green,
        );
      } else if (mounted) {
        showStyledSnackBar(
          context,
          message: "Failed to connect to ${device.platformName}",
          icon: Icons.error,
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: "Retry",
            onPressed: () => _connectToDevice(device, viewModel),
          ),
        );
      }
    }
  }

  void _disconnectDevice(PixelLightsViewModel viewModel) async {
    await viewModel.disconnectDevice();
  }

  /// Start auto-connect workflow
  Future<void> _startAutoConnect(PixelLightsViewModel viewModel) async {
    final success = await viewModel.autoConnect(
      preferredDeviceName: "ESP32", // Customize as needed
    );
    
    if (success && mounted) {
      showStyledSnackBar(
        context,
        message: "Auto-connect successful!",
        icon: Icons.check_circle,
        backgroundColor: Colors.green,
      );
    } else if (mounted) {
      showStyledSnackBar(
        context,
        message: viewModel.connectionState.message ?? "Auto-connect failed",
        icon: Icons.error,
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: "Retry",
          onPressed: () => _startAutoConnect(viewModel),
        ),
      );
    }
  }

  /// Show tabbed analytics modal with card-consistent styling
  void _showAnalytics(BuildContext context, PixelLightsViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Card(
          elevation: 8,
          margin: const EdgeInsets.only(top: 50),
          color: Colors.black.withValues(alpha: 0.9),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: Colors.white24, width: 1),
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Header with card-consistent styling
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "CONNECTION ANALYTICS",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Tab bar
                const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.blue,
                  tabs: [
                    Tab(icon: Icon(Icons.analytics), text: "Device Stats"),
                    Tab(icon: Icon(Icons.hub), text: "Mesh Network"),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDeviceStatsTab(viewModel),
                      _MeshTabWidget(viewModel: viewModel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Device Stats tab - shows connection quality, signal, and session metrics
  Widget _buildDeviceStatsTab(PixelLightsViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (viewModel.currentAnalytics != null) ...[
            _buildAnalyticsCard(
              "Connection Stability",
              "${viewModel.currentAnalytics!.connectionHealthScore.toStringAsFixed(1)}%",
              viewModel.currentAnalytics!.healthDescription,
              _getStabilityColor(viewModel.currentAnalytics!.connectionHealthScore),
            ),
            _buildAnalyticsCard(
              "Signal Strength",
              "${viewModel.currentAnalytics!.signalStrength} dBm",
              viewModel.currentAnalytics!.signalQuality,
              _getSignalStrengthColor(viewModel.currentAnalytics!.signalStrength),
            ),
            _buildAnalyticsCard(
              "Packet Success Rate",
              "${(viewModel.currentAnalytics!.packetSuccessRate * 100).toStringAsFixed(1)}%",
              "${viewModel.currentAnalytics!.packetsTransmitted} packets transmitted",
              _getPacketSuccessColor(viewModel.currentAnalytics!.packetSuccessRate),
            ),
            _buildAnalyticsCard(
              "Connected Device",
              viewModel.currentAnalytics!.deviceName,
              "ESP32 LED Controller",
              Colors.cyan,
            ),
            _buildAnalyticsCard(
              "Session Duration",
              _formatDuration(viewModel.currentAnalytics!.connectionTime),
              "Active connection time",
              Colors.purple,
            ),
          ] else
            const Center(
              child: Text(
                "No active connection",
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  /// Analytics card with Card-based styling (used in connection info section)
  Widget _buildAnalyticsCard(String title, String value, String subtitle, Color color) {
    return Card(
      color: const Color(0xFF424242), // Explicit dark background
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.analytics, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get filtered scan results based on search query
  List<ScanResult> _getFilteredResults() {
    return _scanResults.where((result) {
      final deviceName = result.device.platformName.toLowerCase();
      return deviceName.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      builder: (context, viewModel, child) {
        return BackgroundMesh(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildMainCard(viewModel),
              ),
            ),
            floatingActionButton: _buildSmartFAB(viewModel),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          ),
        );
      },
    );
  }

  /// Main card container following Manual/Presets screen pattern
  Widget _buildMainCard(PixelLightsViewModel viewModel) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      color: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCardHeader(viewModel),
            const SizedBox(height: 20),
            _buildEnhancedSearchBar(),
            const SizedBox(height: 12),
            _buildConnectedDeviceStatusStrip(viewModel),
            const SizedBox(height: 8),
            Expanded(
              child: BleDeviceList(
                devices: _getFilteredResults(),
                connectedDevice: viewModel.bluetoothDevice,
                connectionState: viewModel.connectionState,
                onDeviceSelected: (device) => _connectToDevice(device, viewModel),
                onRefresh: () => _startBluetoothScan(viewModel),
                onAutoConnect: () => _startAutoConnect(viewModel),
                isScanning: _isScanning,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card header with integrated actions (replaces AppBar)
  Widget _buildCardHeader(PixelLightsViewModel viewModel) {
    return Row(
      children: [
        Icon(
          Icons.bluetooth,
          color: Colors.white.withValues(alpha: 0.9),
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          'BLUETOOTH CONNECTION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.analytics, color: Colors.white.withValues(alpha: 0.7)),
          onPressed: () => _showAnalytics(context, viewModel),
          tooltip: "View Analytics",
        ),
        IconButton(
          icon: Icon(Icons.auto_fix_high, color: Colors.white.withValues(alpha: 0.7)),
          onPressed: () => _startAutoConnect(viewModel),
          tooltip: "Auto Connect",
        ),
      ],
    );
  }

  /// Enhanced search bar integrated within card styling
  Widget _buildEnhancedSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: 'Search devices...',
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          hintText: 'ESP32, Pixel, LED...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }



  /// Smart floating action button that adapts to connection state
  Widget _buildSmartFAB(PixelLightsViewModel viewModel) {
    if (viewModel.hasConnectionError) {
      return FloatingActionButton.extended(
        onPressed: () => viewModel.retryConnection(),
        icon: const Icon(Icons.refresh),
        label: const Text("Retry"),
        backgroundColor: Colors.orange,
      );
    }
    
    if (viewModel.bluetoothDevice != null) {
      return FloatingActionButton.extended(
        onPressed: () => _disconnectDevice(viewModel),
        icon: const Icon(Icons.bluetooth_disabled),
        label: const Text("Disconnect"),
        backgroundColor: Colors.red,
      );
    }
    
    if (_isScanning) {
      return FloatingActionButton.extended(
        onPressed: () => _stopBluetoothScan(viewModel),
        icon: const Icon(Icons.stop),
        label: const Text("Stop Scan"),
        backgroundColor: Colors.orange,
      );
    }
    
    return FloatingActionButton.extended(
      onPressed: () => _startAutoConnect(viewModel),
      icon: const Icon(Icons.auto_fix_high),
      label: const Text("Auto Connect"),
      backgroundColor: Colors.green,
    );
  }
  
  /// Helper color functions for Device Stats tab
  Color _getStabilityColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }
  
  Color _getSignalStrengthColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    return Colors.red;
  }
  
  Color _getPacketSuccessColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.85) return Colors.orange;
    return Colors.red;
  }
  
  
  /// Connected device status card (full card design, shows only when connected/connecting)
  Widget _buildConnectedDeviceStatusStrip(PixelLightsViewModel viewModel) {
    final isConnected = viewModel.bluetoothDevice != null;
    final isConnecting = viewModel.connectionState.phase == BleConnectionPhase.connecting ||
                        viewModel.connectionState.phase == BleConnectionPhase.discoveringServices;
    
    if (!isConnected && !isConnecting) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        elevation: 4,
        color: const Color(0xFF424242), // Explicit dark gray background matching device cards
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildConnectionStatusIcon(viewModel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected 
                            ? "Connected to ${viewModel.bluetoothDevice!.platformName}"
                            : "Connecting...",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isConnected) ...[
                          Text(
                            viewModel.bluetoothDevice!.remoteId.str,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildSignalStrengthRow(viewModel.currentAnalytics?.signalStrength ?? -70),
                          if ((viewModel.currentAnalytics?.batteryVoltageMv ?? -1) > 0) ...[
                            const SizedBox(height: 4),
                            _buildBatteryVoltageRow(
                              viewModel.currentAnalytics!.batteryVoltageMv,
                              viewModel.currentAnalytics!.isBatteryCharging,
                            ),
                          ],
                        ] else
                          Text(
                            viewModel.connectionState.message ?? "Establishing connection...",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isConnected)
                    IconButton(
                      icon: const Icon(Icons.bluetooth_disabled, color: Colors.red),
                      onPressed: () => _disconnectDevice(viewModel),
                      tooltip: "Disconnect",
                    )
                  else if (viewModel.connectionState.canRetry)
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: () => viewModel.retryConnection(),
                      tooltip: "Retry Connection",
                    ),
                ],
              ),
              if (viewModel.connectionState.progress > 0 && 
                  viewModel.connectionState.progress < 1)
                Column(
                  children: [
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: viewModel.connectionState.progress,
                      backgroundColor: Colors.grey[600],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        viewModel.connectionState.hasError 
                            ? Colors.red 
                            : Colors.blue,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Connection status icon based on current state
  Widget _buildConnectionStatusIcon(PixelLightsViewModel viewModel) {
    switch (viewModel.connectionState.phase) {
      case BleConnectionPhase.ready:
        return const Icon(Icons.bluetooth_connected, color: Colors.green, size: 28);
      case BleConnectionPhase.connecting:
      case BleConnectionPhase.discoveringServices:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case BleConnectionPhase.error:
        return const Icon(Icons.error, color: Colors.red, size: 28);
      case BleConnectionPhase.scanning:
        return const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
      default:
        return const Icon(Icons.bluetooth, color: Colors.grey, size: 28);
    }
  }

  /// Signal strength indicator row for the connection card
  Widget _buildSignalStrengthRow(int rssi) {
    final strength = _getSignalStrengthPercentage(rssi);
    final signalColor = strength > 50 ? Colors.green : 
                       strength > 25 ? Colors.orange : Colors.red;
    
    return Row(
      children: [
        // Signal strength bars
        Row(
          children: List.generate(5, (index) {
            final barStrength = (index + 1) * 20;
            return Container(
              width: 3,
              height: 8 + (index * 2),
              margin: const EdgeInsets.only(right: 1),
              decoration: BoxDecoration(
                color: strength >= barStrength ? signalColor : Colors.grey[600],
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          "$rssi dBm (${strength.toInt()}%)",
          style: TextStyle(
            fontSize: 12,
            color: signalColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Convert RSSI to percentage
  double _getSignalStrengthPercentage(int rssi) => rssiToPercentage(rssi);

  /// Battery voltage indicator row for the connection card
  /// Uses voltage-based categories since LED load causes voltage sag making percentage unreliable
  Widget _buildBatteryVoltageRow(int voltageMv, bool isCharging) {
    // Voltage-based categories:
    // - Green (≥3700mV) - Good/Full
    // - Yellow (≥3500mV) - Medium
    // - Orange (≥3200mV) - Low
    // - Red (<3200mV) - Critical

    Color batteryColor;
    IconData batteryIcon;
    String category;

    if (isCharging) {
      batteryColor = Colors.lightBlue;
      batteryIcon = Icons.battery_charging_full;
      category = "Charging";
    } else if (voltageMv >= 3700) {
      batteryColor = Colors.green;
      batteryIcon = Icons.battery_full;
      category = "Good";
    } else if (voltageMv >= 3500) {
      batteryColor = Colors.yellow.shade600;
      batteryIcon = Icons.battery_5_bar;
      category = "Medium";
    } else if (voltageMv >= 3200) {
      batteryColor = Colors.orange;
      batteryIcon = Icons.battery_2_bar;
      category = "Low";
    } else {
      batteryColor = Colors.red;
      batteryIcon = Icons.battery_alert;
      category = "Critical";
    }

    // Format voltage as X.XXV
    final voltageV = (voltageMv / 1000.0).toStringAsFixed(2);

    return Row(
      children: [
        Icon(
          batteryIcon,
          size: 18,
          color: batteryColor,
        ),
        const SizedBox(width: 6),
        Text(
          "${voltageV}V",
          style: TextStyle(
            fontSize: 12,
            color: batteryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "($category)",
          style: TextStyle(
            fontSize: 10,
            color: batteryColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return "${duration.inDays}d ${duration.inHours % 24}h";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${duration.inSeconds % 60}s";
    } else {
      return "${duration.inSeconds}s";
    }
  }
}

/// Dedicated StatefulWidget for Mesh tab to prevent widget disposal during tab switching
class _MeshTabWidget extends StatefulWidget {
  final PixelLightsViewModel viewModel;
  
  const _MeshTabWidget({required this.viewModel});
  
  @override
  State<_MeshTabWidget> createState() => _MeshTabWidgetState();
}

class _MeshTabWidgetState extends State<_MeshTabWidget> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true; // Keep widget alive during tab switches
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // MUST call super.build() for AutomaticKeepAliveClientMixin
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<ConnectionAnalytics?>(
        stream: widget.viewModel.currentSessionMetrics,
        initialData: widget.viewModel.currentAnalytics,
        builder: (context, snapshot) {
          final analytics = snapshot.data;
          final hasMeshData = analytics?.hasMeshAnalytics ?? false;
          final isConnected = analytics != null && analytics.deviceId.isNotEmpty;
          
          if (!hasMeshData && !isConnected) {
            // Not connected to any device
            return Column(
              children: [
                _buildAnalyticsCard(
                  "Network Health",
                  "--",
                  "Not connected",
                  Colors.grey,
                ),
                _buildAnalyticsCard(
                  "Active Neighbors",
                  "--", 
                  "Not connected",
                  Colors.grey,
                ),
                _buildAnalyticsCard(
                  "Mesh Success Rate",
                  "--",
                  "Not connected", 
                  Colors.grey,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade300, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Connect to ESP32 with mesh health support to view real-time mesh analytics",
                          style: TextStyle(
                            color: Colors.orange.shade100,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else if (!hasMeshData && isConnected) {
            // Connected but waiting for ESP32 health data
            return Column(
              children: [
                _buildAnalyticsCard(
                  "Network Health",
                  "⏳",
                  "Waiting for ESP32 data...",
                  Colors.blue,
                ),
                _buildAnalyticsCard(
                  "Active Neighbors", 
                  "⏳",
                  "Waiting for ESP32 data...",
                  Colors.blue,
                ),
                _buildAnalyticsCard(
                  "Mesh Success Rate",
                  "⏳",
                  "Waiting for ESP32 data...",
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Connected to ESP32 • Waiting for mesh health data (sent every 10 seconds)",
                          style: TextStyle(
                            color: Colors.blue.shade100,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          
          // Display real ESP32 mesh analytics
          final healthScore = analytics!.meshHealthScore ?? 0;
          final neighbors = analytics.meshNeighbors ?? 0;
          final successRate = analytics.meshSuccessRate ?? 0;
          final rssi = analytics.meshRSSI ?? -70;
          final uptimeHours = analytics.meshUptimeHours ?? 0;
          final role = analytics.meshRoleDescription;
          
          // Health score color coding
          Color healthColor;
          if (healthScore >= 80) {
            healthColor = Colors.green;
          } else if (healthScore >= 60) {
            healthColor = Colors.blue;
          } else if (healthScore >= 40) {
            healthColor = Colors.orange;
          } else {
            healthColor = Colors.red;
          }
          
          return Column(
            children: [
              _buildAnalyticsCard(
                "Network Health",
                "$healthScore%",
                "Overall mesh network performance",
                healthColor,
              ),
              _buildAnalyticsCard(
                "Active Neighbors",
                neighbors.toString(),
                "Connected mesh nodes nearby",
                neighbors > 0 ? Colors.green : Colors.orange,
              ),
              _buildAnalyticsCard(
                "Total Nodes",
                "${analytics.totalNodes ?? 0}",
                "Total nodes in the mesh network",
                Colors.teal,
              ),
              _buildAnalyticsCard(
                "Mesh Success Rate",
                "$successRate%",
                "Packet transmission reliability",
                successRate >= 90 ? Colors.green : 
                successRate >= 70 ? Colors.blue : Colors.orange,
              ),
              _buildAnalyticsCard(
                "Signal Strength",
                "${rssi}dBm",
                "Average mesh communication quality",
                rssi > -60 ? Colors.green :
                rssi > -80 ? Colors.blue : Colors.orange,
              ),
              _buildAnalyticsCard(
                "Node Uptime",
                "${uptimeHours}h",
                "Hours since mesh node started",
                Colors.cyan,
              ),
              _buildAnalyticsCard(
                "Mesh Role",
                role,
                "Function in mesh network topology",
                Colors.purple,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade300, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Real-time ESP32 mesh analytics active • Updates every 60 seconds",
                        style: TextStyle(
                          color: Colors.green.shade100,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Analytics card with accent border styling (used in mesh analytics tab)
  /// Note: Intentionally different visual style from _BluetoothScreenState._buildAnalyticsCard
  Widget _buildAnalyticsCard(String title, String value, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
