import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pixel_lights/models/ble_connection_state.dart';

/// Professional BLE device list with card-based design and enhanced UX
class BleDeviceList extends StatefulWidget {
  final List<ScanResult> devices;
  final BluetoothDevice? connectedDevice;
  final BleConnectionState connectionState;
  final Function(BluetoothDevice) onDeviceSelected;
  final VoidCallback onRefresh;
  final VoidCallback onAutoConnect;
  final bool isScanning;

  const BleDeviceList({
    super.key,
    required this.devices,
    this.connectedDevice,
    required this.connectionState,
    required this.onDeviceSelected,
    required this.onRefresh,
    required this.onAutoConnect,
    required this.isScanning,
  });

  @override
  State<BleDeviceList> createState() => _BleDeviceListState();
}

class _BleDeviceListState extends State<BleDeviceList> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        // Wait for scan to complete
        await Future.delayed(const Duration(seconds: 2));
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Connection status header
          SliverToBoxAdapter(
            child: _buildConnectionStatusCard(),
          ),
          
          // Scanning indicator
          if (widget.isScanning)
            SliverToBoxAdapter(
              child: _buildScanningIndicator(),
            ),
          
          // Device list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDeviceCard(widget.devices[index], index),
              childCount: widget.devices.length,
            ),
          ),
          
          // Empty state
          if (widget.devices.isEmpty && !widget.isScanning)
            SliverFillRemaining(
              child: _buildEmptyState(),
            ),
        ],
      ),
    );
  }

  /// Connection status card at the top - informational display only
  Widget _buildConnectionStatusCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      color: const Color(0xFF424242), // Explicit dark gray background
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildConnectionStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.connectionState.statusTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.connectionState.message != null)
                        Text(
                          widget.connectionState.message!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.connectionState.canRetry)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => _retryConnection(),
                  ),
              ],
            ),
            if (widget.connectionState.progress > 0 && 
                widget.connectionState.progress < 1)
              Column(
                children: [
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: widget.connectionState.progress,
                    backgroundColor: Colors.grey[600],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.connectionState.hasError 
                          ? Colors.red 
                          : Colors.blue,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Connection status icon based on current state
  Widget _buildConnectionStatusIcon() {
    switch (widget.connectionState.phase) {
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

  /// Scanning indicator when actively scanning
  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Scanning for devices...",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Individual device card with enhanced design
  Widget _buildDeviceCard(ScanResult result, int index) {
    final device = result.device;
    final isConnected = device == widget.connectedDevice;
    final isConnecting = widget.connectionState.device == device &&
        (widget.connectionState.phase == BleConnectionPhase.connecting ||
         widget.connectionState.phase == BleConnectionPhase.discoveringServices);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: isConnected ? 8 : 2,
        color: isConnected 
            ? const Color(0xFF1B5E20) // Dark green for connected
            : const Color(0xFF424242), // Dark gray for devices
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tileColor: Colors.transparent, // Ensure ListTile doesn't override
          leading: _buildDeviceIcon(result),
          title: Text(
            device.platformName.isNotEmpty 
                ? device.platformName 
                : "Unknown Device",
            style: TextStyle(
              color: Colors.white,
              fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.remoteId.str,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 4),
              _buildSignalStrengthRow(result.rssi),
            ],
          ),
          trailing: _buildDeviceTrailing(device, isConnected, isConnecting),
          onTap: isConnecting ? null : () => widget.onDeviceSelected(device),
        ),
      ),
    );
  }

  /// Device icon with signal strength and status indicators
  Widget _buildDeviceIcon(ScanResult result) {
    final strength = _getSignalStrength(result.rssi);
    Color color = Colors.grey;
    
    if (strength > 75) {
      color = Colors.green;
    } else if (strength > 50) {
      color = Colors.orange;
    } else if (strength > 25) {
      color = Colors.red;
    }
    
    return Stack(
      children: [
        Icon(
          _getDeviceIcon(result.device),
          color: color,
          size: 32,
        ),
        if (result.device == widget.connectedDevice)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  /// Get appropriate device icon based on name
  IconData _getDeviceIcon(BluetoothDevice device) {
    final name = device.platformName.toLowerCase();
    if (name.contains('esp32') || name.contains('pixel') || name.contains('led')) {
      return Icons.lightbulb;
    }
    return Icons.bluetooth;
  }

  /// Signal strength indicator with visual bars and text
  Widget _buildSignalStrengthRow(int rssi) {
    final strength = _getSignalStrength(rssi);
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

  /// Convert RSSI to percentage (rough approximation)
  double _getSignalStrength(int rssi) {
    if (rssi >= -50) return 100;
    if (rssi <= -100) return 0;
    return ((rssi + 100) * 2).toDouble();
  }

  /// Trailing widget for device cards (connect button, status, etc.)
  Widget _buildDeviceTrailing(BluetoothDevice device, bool isConnected, bool isConnecting) {
    if (isConnecting) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }
    
    if (isConnected) {
      return const Icon(Icons.bluetooth_connected, color: Colors.green);
    }
    
    return const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70);
  }

  /// Empty state when no devices are found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            "No devices found",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Pull down to refresh or tap scan",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  /// Handle retry connection button
  void _retryConnection() {
    // This will be implemented when we integrate with the view model
    debugPrint("Retry connection requested");
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}