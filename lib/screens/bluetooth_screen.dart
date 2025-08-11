import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/widgets/ble_device_list.dart';
import 'package:pixel_lights/models/ble_connection_state.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pixel_lights/models/connection_analytics.dart';
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
    if (_isScanning) {
      _stopBluetoothScan(viewModel);
      await Future.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) {
      // Use enhanced analytics-aware connection method for manual device selection
      final success = await viewModel.bluetoothService.connectToDeviceEnhanced(device);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connected to ${device.platformName}"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to connect to ${device.platformName}"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: "Retry",
              onPressed: () => _connectToDevice(device, viewModel),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Auto-connect successful!"),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.connectionState.message ?? "Auto-connect failed"),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: "Retry",
            onPressed: () => _startAutoConnect(viewModel),
          ),
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
          color: Colors.black.withOpacity(0.9),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: Colors.white24, width: 1),
          ),
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                // Header with card-consistent styling
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: Colors.white.withOpacity(0.9),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "CONNECTION ANALYTICS",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white.withOpacity(0.7)),
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
                    Tab(icon: Icon(Icons.bluetooth), text: "BLE"),
                    Tab(icon: Icon(Icons.hub), text: "Mesh"),
                    Tab(icon: Icon(Icons.info), text: "System"),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBleTab(viewModel),
                      _MeshTabWidget(viewModel: viewModel),
                      _buildSystemTab(viewModel),
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

  /// BLE connection analytics tab
  Widget _buildBleTab(PixelLightsViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (viewModel.currentAnalytics != null) ...[
            _buildAnalyticsCard(
              "Connection Health",
              "${viewModel.currentAnalytics!.connectionHealthScore.toStringAsFixed(1)}%",
              viewModel.currentAnalytics!.healthDescription,
              Colors.blue,
            ),
            _buildAnalyticsCard(
              "Signal Strength",
              "${viewModel.currentAnalytics!.signalStrength} dBm",
              viewModel.currentAnalytics!.signalQuality,
              Colors.green,
            ),
            _buildAnalyticsCard(
              "Packet Success",
              "${(viewModel.currentAnalytics!.packetSuccessRate * 100).toStringAsFixed(1)}%",
              "${viewModel.currentAnalytics!.packetsTransmitted} sent",
              Colors.orange,
            ),
            // Enhanced connection quality uptime
            if (viewModel.currentAnalytics!.connectionQuality != null)
              _buildAnalyticsCard(
                "Current Uptime",
                _formatUptime(viewModel.currentAnalytics!.connectionQuality!.currentUptime),
                viewModel.currentAnalytics!.connectionQuality!.statusSummary,
                Colors.purple,
              ),
          ] else
            const Center(
              child: Text(
                "No active BLE connection",
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  /// ESP32 mesh network analytics tab with real-time data
  Widget _buildMeshTab(PixelLightsViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<ConnectionAnalytics?>(
        stream: viewModel.currentSessionMetrics,
        initialData: viewModel.currentAnalytics,
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade300, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Connect to ESP32 with mesh health support to view real-time mesh analytics",
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                      const Expanded(
                        child: Text(
                          "Connected to ESP32 • Waiting for mesh health data (sent every 10 seconds)",
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
          final uptime = analytics.meshUptimeHours ?? 0;
          final role = analytics.meshRoleDescription;
          
          // Determine health color based on score
          Color healthColor;
          String healthDescription;
          if (healthScore >= 80) {
            healthColor = Colors.green;
            healthDescription = "Excellent mesh performance";
          } else if (healthScore >= 60) {
            healthColor = Colors.blue;
            healthDescription = "Good mesh performance";
          } else if (healthScore >= 40) {
            healthColor = Colors.orange;
            healthDescription = "Fair mesh performance";
          } else {
            healthColor = Colors.red;
            healthDescription = "Poor mesh performance";
          }
          
          return Column(
            children: [
              _buildAnalyticsCard(
                "Network Health",
                "${healthScore}%",
                healthDescription,
                healthColor,
              ),
              _buildAnalyticsCard(
                "Active Neighbors",
                "$neighbors",
                neighbors == 1 ? "ESP32 node in range" : "ESP32 nodes in range",
                Colors.blue,
              ),
              _buildAnalyticsCard(
                "Mesh Success Rate",
                "${successRate}%",
                "Network packet delivery",
                successRate >= 90 ? Colors.green : successRate >= 70 ? Colors.orange : Colors.red,
              ),
              _buildAnalyticsCard(
                "Signal Strength",
                "${rssi}dBm",
                "Average mesh RSSI",
                rssi > -60 ? Colors.green : rssi > -80 ? Colors.orange : Colors.red,
              ),
              _buildAnalyticsCard(
                "Uptime",
                "${uptime}h",
                "ESP32 system uptime",
                Colors.purple,
              ),
              _buildAnalyticsCard(
                "Mesh Role",
                role,
                "Current network role",
                Colors.indigo,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade300, size: 18),
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

  /// System information tab
  Widget _buildSystemTab(PixelLightsViewModel viewModel) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (viewModel.currentAnalytics != null) ...[
            _buildAnalyticsCard(
              "Connection Time",
              "${viewModel.currentAnalytics!.connectionTime.inSeconds}s",
              "Current session duration",
              Colors.cyan,
            ),
            _buildAnalyticsCard(
              "Device",
              viewModel.currentAnalytics!.deviceName,
              "Connected ESP32 node",
              Colors.green,
            ),
            // Enhanced connection quality display
            if (viewModel.currentAnalytics!.connectionQuality != null)
              _buildAnalyticsCard(
                "Quality",
                viewModel.currentAnalytics!.connectionQuality!.qualityRating,
                "${viewModel.currentAnalytics!.connectionQuality!.reliabilityScore.toStringAsFixed(1)}% reliability",
                _getQualityColor(viewModel.currentAnalytics!.connectionQuality!.qualityRating),
              )
            else
              _buildAnalyticsCard(
                "Quality",
                "Calculating...",
                "Connection quality assessment",
                Colors.grey,
              ),
            // TODO: Add ESP32 system info (uptime, role, memory)
          ] else
            const Center(
              child: Text(
                "No system information available",
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

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
      color: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCardHeader(viewModel),
            const SizedBox(height: 20),
            _buildEnhancedSearchBar(),
            const SizedBox(height: 20),
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
          color: Colors.white.withOpacity(0.9),
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          'BLUETOOTH CONNECTION',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.analytics, color: Colors.white.withOpacity(0.7)),
          onPressed: () => _showAnalytics(context, viewModel),
          tooltip: "View Analytics",
        ),
        IconButton(
          icon: Icon(Icons.auto_fix_high, color: Colors.white.withOpacity(0.7)),
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
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: 'Search devices...',
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          hintText: 'ESP32, Pixel, LED...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
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
  
  /// Get appropriate color for connection quality rating
  Color _getQualityColor(String qualityRating) {
    switch (qualityRating.toLowerCase()) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.lightGreen;
      case 'fair':
        return Colors.orange;
      case 'poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  /// Format uptime duration for display
  String _formatUptime(Duration duration) {
    if (duration.inDays > 0) {
      return "${duration.inDays}d ${duration.inHours % 24}h";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m";
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade300, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Connect to ESP32 with mesh health support to view real-time mesh analytics",
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                      const Expanded(
                        child: Text(
                          "Connected to ESP32 • Waiting for mesh health data (sent every 10 seconds)",
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade300, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Real-time ESP32 mesh analytics active • Updates every 60 seconds",
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

  /// Build analytics card helper method
  Widget _buildAnalyticsCard(String title, String value, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.7),
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
                    color: Colors.white.withOpacity(0.5),
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
