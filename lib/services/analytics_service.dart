import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pixel_lights/models/connection_analytics.dart';
import 'package:pixel_lights/models/connection_quality.dart';
import 'package:pixel_lights/services/bluetooth_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking and managing connection analytics
class AnalyticsService {
  static const String _storageKey = 'connection_analytics_history';
  static const int _maxHistoryEntries = 50;

  final StreamController<ConnectionAnalytics?> _currentMetricsController = 
      StreamController<ConnectionAnalytics?>.broadcast();
  
  final List<ConnectionAnalytics> _sessionHistory = [];
  Timer? _metricsTimer;
  DateTime? _sessionStart;
  DateTime? _connectionStart;
  BluetoothDevice? _currentDevice;
  int _packetsSent = 0;
  int _packetsDropped = 0;
  int _lastSignalStrength = -70;
  final List<String> _sessionErrors = [];
  
  // Enhanced connection quality tracking
  final List<ServiceInterruption> _serviceInterruptions = [];
  final List<int> _rssiReadings = [];
  int _userInitiatedRetries = 0;
  int _transparentRecoveries = 0;
  
  // ESP32 Mesh Health Analytics
  Map<String, dynamic>? _latestHealthData;
  StreamSubscription<Map<String, dynamic>>? _healthSubscription;

  // Battery level monitoring
  int? _latestBatteryLevel;
  StreamSubscription<int>? _batterySubscription;

  /// Stream of current session metrics (updates every 5 seconds)
  Stream<ConnectionAnalytics?> get currentSessionMetrics => 
      _currentMetricsController.stream;

  /// Get current session analytics snapshot
  ConnectionAnalytics? get currentSession => _getCurrentMetrics();

  /// Get session history
  List<ConnectionAnalytics> get sessionHistory => List.from(_sessionHistory);

  /// Initialize analytics service
  Future<void> initialize() async {
    await _loadSessionHistory();
  }

  /// Start a new analytics session
  Future<void> startSession(BluetoothDevice device, int signalStrength, 
      {IBluetoothService? bluetoothService}) async {
    // Only end session if connecting to a different device
    bool differentDevice = _currentDevice?.remoteId.str != device.remoteId.str;
    
    if (differentDevice) {
      await endSession(); // End session for different device
      _latestHealthData = null; // Clear health data only for new device
      _latestBatteryLevel = null; // Clear battery level for new device
    } else {
      // Same device - preserve health data but restart session tracking
      _stopMetricsTimer(); // Stop existing timer
    }
    
    _sessionStart = DateTime.now();
    _connectionStart = DateTime.now();
    _currentDevice = device;
    _packetsSent = 0;
    _packetsDropped = 0;
    _lastSignalStrength = signalStrength;
    _sessionErrors.clear();
    
    // Reset enhanced quality tracking
    _serviceInterruptions.clear();
    _rssiReadings.clear();
    _userInitiatedRetries = 0;
    _transparentRecoveries = 0;
    
    // Initialize with first signal reading
    _rssiReadings.add(signalStrength);
    
    // Subscribe to ESP32 health data if available (and not already subscribed)
    if (bluetoothService != null && _healthSubscription == null) {
      _subscribeToHealthData(bluetoothService);
    }

    // Subscribe to battery level updates if available (and not already subscribed)
    if (bluetoothService != null && _batterySubscription == null) {
      _subscribeToBatteryData(bluetoothService);
    }
    
    debugPrint("AnalyticsService: Started session for ${device.platformName} (same device: ${!differentDevice})");
    
    // Start periodic metrics updates
    _startMetricsTimer();
  }

  /// Update signal strength from scan results
  void updateSignalStrength(int rssi) {
    _lastSignalStrength = rssi;
    _rssiReadings.add(rssi);
    
    // Keep only recent readings (last 50 readings for efficiency)
    if (_rssiReadings.length > 50) {
      _rssiReadings.removeAt(0);
    }
  }

  /// Record successful packet transmission
  void recordPacketSent() {
    _packetsSent++;
  }

  /// Record failed packet transmission
  void recordPacketDropped() {
    _packetsDropped++;
  }

  /// Record user-initiated retry attempt (manual retry button press)
  void recordUserRetry() {
    _userInitiatedRetries++;
    debugPrint("AnalyticsService: User-initiated retry #$_userInitiatedRetries");
  }
  
  /// Record transparent recovery event (automatic background recovery)
  void recordTransparentRecovery(String recoveryType) {
    _transparentRecoveries++;
    debugPrint("AnalyticsService: Transparent recovery: $recoveryType (#$_transparentRecoveries)");
  }
  
  /// Record service interruption start
  void recordServiceInterruption(ServiceInterruptionCause cause, {String? errorMessage}) {
    final interruption = ServiceInterruption(
      startTime: DateTime.now(),
      duration: Duration.zero,
      cause: cause,
      wasUserNoticed: cause != ServiceInterruptionCause.unknown, // Assume visible unless specified
      errorMessage: errorMessage,
    );
    _serviceInterruptions.add(interruption);
    debugPrint("AnalyticsService: Service interruption started: ${cause.name}");
  }
  
  /// Record service interruption resolution
  void recordServiceInterruptionResolved({int recoveryAttempts = 1}) {
    if (_serviceInterruptions.isNotEmpty) {
      final lastInterruption = _serviceInterruptions.last;
      if (!lastInterruption.isResolved) {
        final endTime = DateTime.now();
        final duration = endTime.difference(lastInterruption.startTime);
        
        // Update the interruption with resolution info
        final resolvedInterruption = lastInterruption.copyWith(
          endTime: endTime,
          duration: duration,
          recoveryAttempts: recoveryAttempts,
        );
        
        _serviceInterruptions[_serviceInterruptions.length - 1] = resolvedInterruption;
        debugPrint("AnalyticsService: Service interruption resolved after ${duration.inSeconds}s");
      }
    }
  }

  /// Record session error
  void recordError(String error) {
    _sessionErrors.add(error);
    debugPrint("AnalyticsService: Recorded error: $error");
  }

  /// End current session and store analytics
  Future<void> endSession({bool clearHealthData = true}) async {
    if (_sessionStart != null && _currentDevice != null) {
      final analytics = _getCurrentMetrics();
      if (analytics != null) {
        _sessionHistory.add(analytics.copyWith(isCurrentSession: false));
        await _saveSessionHistory();
        debugPrint("AnalyticsService: Ended session - Health: ${analytics.connectionHealthScore.toStringAsFixed(1)}%");
      }
    }
    
    _stopMetricsTimer();
    _unsubscribeFromHealthData();
    _unsubscribeFromBatteryData();
    _sessionStart = null;
    _connectionStart = null;
    _currentDevice = null;

    // Only clear health/battery data if explicitly requested (true disconnection)
    if (clearHealthData) {
      _latestHealthData = null;
      _latestBatteryLevel = null;
      debugPrint("AnalyticsService: Cleared health and battery data (full disconnection)");
    } else {
      debugPrint("AnalyticsService: Preserved health and battery data (temporary state change)");
    }
    
    // *** CRITICAL FIX: Emit null to signal UI should clear analytics ***
    _currentMetricsController.add(null);
    debugPrint("AnalyticsService: Emitted null to clear UI analytics");
  }

  /// Get current session metrics with enhanced connection quality
  ConnectionAnalytics? _getCurrentMetrics() {
    if (_sessionStart == null || _currentDevice == null) return null;
    
    final now = DateTime.now();
    final sessionDuration = now.difference(_sessionStart!);
    final connectionTime = _connectionStart != null 
        ? now.difference(_connectionStart!)
        : Duration.zero;

    // Calculate total downtime from resolved interruptions
    final totalDowntime = _serviceInterruptions
        .where((i) => i.isResolved)
        .fold<Duration>(Duration.zero, (sum, interruption) => sum + interruption.duration);
    
    // Generate enhanced connection quality metrics
    final connectionQuality = ConnectionQuality.fromMetrics(
      sessionDuration: sessionDuration,
      totalDowntime: totalDowntime,
      interruptions: List.from(_serviceInterruptions),
      transparentRecoveries: _transparentRecoveries,
      userRetries: _userInitiatedRetries,
      rssiReadings: List.from(_rssiReadings),
      sessionStart: _sessionStart!,
    );

    return ConnectionAnalytics(
      timestamp: now,
      deviceId: _currentDevice!.remoteId.str,
      deviceName: _currentDevice!.platformName.isNotEmpty
          ? _currentDevice!.platformName
          : "Unknown Device",
      signalStrength: _lastSignalStrength,
      connectionTime: connectionTime,
      reconnectionAttempts: 0, // Legacy field kept for backward compatibility with stored sessions
      errors: List.from(_sessionErrors),
      packetsTransmitted: _packetsSent,
      packetsDropped: _packetsDropped,
      sessionDuration: sessionDuration,
      isCurrentSession: true,
      // Enhanced connection quality
      connectionQuality: connectionQuality,
      // Battery level (if available, otherwise -1)
      batteryLevel: _latestBatteryLevel?.toDouble() ?? -1,
      // ESP32 Mesh Health Analytics (if available)
      meshHealthScore: _latestHealthData?['overall_score'],
      meshNeighbors: _latestHealthData?['active_neighbors'],
      meshSuccessRate: _latestHealthData?['packet_success_rate'],
      meshRSSI: _latestHealthData?['avg_signal_strength'],
      meshUptimeHours: _latestHealthData?['uptime_hours'],
      meshRole: _latestHealthData?['mesh_role'],
      totalNodes: _latestHealthData?['total_nodes'],
    );
  }

  /// Start metrics timer for periodic updates
  void _startMetricsTimer() {
    _stopMetricsTimer();
    
    // Emit initial metrics immediately
    final initialMetrics = _getCurrentMetrics();
    if (initialMetrics != null) {
      _currentMetricsController.add(initialMetrics);
      debugPrint("AnalyticsService: Emitted initial metrics - Health: ${initialMetrics.connectionHealthScore.toStringAsFixed(1)}%");
    }
    
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final metrics = _getCurrentMetrics();
      if (metrics != null) {
        _currentMetricsController.add(metrics);
        debugPrint("AnalyticsService: Emitted periodic metrics - Health: ${metrics.connectionHealthScore.toStringAsFixed(1)}%");
      }
    });
  }

  /// Stop metrics timer
  void _stopMetricsTimer() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
  }

  /// Calculate average connection health from history
  double get averageConnectionHealth {
    if (_sessionHistory.isEmpty) return 0.0;
    
    final totalHealth = _sessionHistory
        .fold<double>(0, (sum, analytics) => sum + analytics.connectionHealthScore);
    return totalHealth / _sessionHistory.length;
  }

  /// Get most recent successful connection
  ConnectionAnalytics? get lastSuccessfulConnection {
    return _sessionHistory
        .where((analytics) => analytics.connectionHealthScore > 50)
        .lastOrNull;
  }

  /// Get connection success rate (sessions with health > 50%)
  double get connectionSuccessRate {
    if (_sessionHistory.isEmpty) return 1.0;
    
    final successfulSessions = _sessionHistory
        .where((analytics) => analytics.connectionHealthScore > 50)
        .length;
    return successfulSessions / _sessionHistory.length;
  }

  /// Get average signal strength from recent sessions
  double get averageSignalStrength {
    if (_sessionHistory.isEmpty) return -70.0;
    
    final recentSessions = _sessionHistory.take(10);
    final totalRssi = recentSessions
        .fold<int>(0, (sum, analytics) => sum + analytics.signalStrength);
    return totalRssi / recentSessions.length;
  }

  /// Save session history to persistent storage
  Future<void> _saveSessionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keep only the most recent entries
      final historyToSave = _sessionHistory.length > _maxHistoryEntries
          ? _sessionHistory.sublist(_sessionHistory.length - _maxHistoryEntries)
          : _sessionHistory;
      
      final jsonList = historyToSave.map((analytics) => analytics.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      
      debugPrint("AnalyticsService: Saved ${historyToSave.length} analytics entries");
    } catch (e) {
      debugPrint("AnalyticsService: Error saving analytics: $e");
    }
  }

  /// Load session history from persistent storage
  Future<void> _loadSessionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _sessionHistory.clear();
        _sessionHistory.addAll(
          jsonList.map((json) => ConnectionAnalytics.fromJson(json))
        );
        
        debugPrint("AnalyticsService: Loaded ${_sessionHistory.length} analytics entries");
      }
    } catch (e) {
      debugPrint("AnalyticsService: Error loading analytics: $e");
    }
  }

  /// Clear all analytics data
  Future<void> clearAnalytics() async {
    _sessionHistory.clear();
    await endSession();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    
    debugPrint("AnalyticsService: Cleared all analytics data");
  }

  /// Subscribe to ESP32 health data updates
  void _subscribeToHealthData(IBluetoothService bluetoothService) {
    try {
      _healthSubscription = bluetoothService.healthDataStream.listen(
        (healthData) {
          _latestHealthData = healthData;
          debugPrint("AnalyticsService: Received ESP32 health data - "
                    "Score: ${healthData['overall_score']}%, "
                    "Neighbors: ${healthData['active_neighbors']}, "
                    "Role: ${healthData['mesh_role']}");
          
          // Immediately emit updated metrics when health data arrives
          final metrics = _getCurrentMetrics();
          if (metrics != null) {
            _currentMetricsController.add(metrics);
            debugPrint("AnalyticsService: Emitted immediate metrics update with ESP32 health data");
          }
        },
        onError: (error) {
          debugPrint("AnalyticsService: ESP32 health data error: $error");
        },
      );
      
      debugPrint("AnalyticsService: Subscribed to ESP32 health data");
    } catch (e) {
      debugPrint("AnalyticsService: Error subscribing to ESP32 health data: $e");
    }
  }
  
  /// Unsubscribe from ESP32 health data
  void _unsubscribeFromHealthData() {
    _healthSubscription?.cancel();
    _healthSubscription = null;
    debugPrint("AnalyticsService: Unsubscribed from ESP32 health data");
  }

  /// Subscribe to battery level updates
  void _subscribeToBatteryData(IBluetoothService bluetoothService) {
    try {
      _batterySubscription = bluetoothService.batteryLevelStream.listen(
        (batteryLevel) {
          _latestBatteryLevel = batteryLevel;
          debugPrint("AnalyticsService: Received battery level: $batteryLevel%");

          // Immediately emit updated metrics when battery data arrives
          final metrics = _getCurrentMetrics();
          if (metrics != null) {
            _currentMetricsController.add(metrics);
            debugPrint("AnalyticsService: Emitted immediate metrics update with battery level");
          }
        },
        onError: (error) {
          debugPrint("AnalyticsService: Battery level stream error: $error");
        },
      );

      debugPrint("AnalyticsService: Subscribed to battery level updates");
    } catch (e) {
      debugPrint("AnalyticsService: Error subscribing to battery level: $e");
    }
  }

  /// Unsubscribe from battery level updates
  void _unsubscribeFromBatteryData() {
    _batterySubscription?.cancel();
    _batterySubscription = null;
    debugPrint("AnalyticsService: Unsubscribed from battery level updates");
  }

  /// Dispose of the service
  void dispose() {
    endSession();
    _currentMetricsController.close();
  }
}