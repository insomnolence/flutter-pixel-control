
import 'connection_quality.dart';

/// Connection session analytics data
class ConnectionAnalytics {
  final DateTime timestamp;
  final String deviceId;
  final String deviceName;
  final int signalStrength;
  final Duration connectionTime;
  /// Legacy field - kept for backward compatibility with stored sessions.
  /// New code should use connectionQuality instead.
  final int reconnectionAttempts;
  final List<String> errors;
  final double batteryLevel;
  final int packetsTransmitted;
  final int packetsDropped;
  final Duration sessionDuration;
  final bool isCurrentSession;
  
  // Enhanced connection quality metrics
  final ConnectionQuality? connectionQuality;
  
  // ESP32 Mesh Health Analytics
  final int? meshHealthScore;      // 0-100 mesh health percentage from ESP32
  final int? meshNeighbors;        // Active mesh neighbors
  final int? meshSuccessRate;      // Mesh packet success rate 0-100%
  final int? meshRSSI;             // Average mesh RSSI 
  final int? meshUptimeHours;      // ESP32 uptime in hours
  final int? meshRole;             // 0=client, 1=root_ble, 2=root_autonomous
  final int? totalNodes;           // Total nodes detected in mesh network

  ConnectionAnalytics({
    required this.timestamp,
    required this.deviceId,
    required this.deviceName,
    required this.signalStrength,
    required this.connectionTime,
    this.reconnectionAttempts = 0,
    this.errors = const [],
    this.batteryLevel = -1,
    this.packetsTransmitted = 0,
    this.packetsDropped = 0,
    this.sessionDuration = Duration.zero,
    this.isCurrentSession = false,
    // Enhanced connection quality
    this.connectionQuality,
    // ESP32 Mesh Health Analytics (optional)
    this.meshHealthScore,
    this.meshNeighbors,
    this.meshSuccessRate,
    this.meshRSSI,
    this.meshUptimeHours,
    this.meshRole,
    this.totalNodes,
  });

  /// Calculate success rate based on transmitted vs dropped packets
  double get packetSuccessRate {
    final total = packetsTransmitted + packetsDropped;
    if (total == 0) return 1.0;
    return packetsTransmitted / total;
  }

  /// Get signal strength as percentage (rough approximation)
  double get signalStrengthPercentage {
    if (signalStrength >= -50) return 100;
    if (signalStrength <= -100) return 0;
    return ((signalStrength + 100) * 2).toDouble();
  }

  /// Get signal quality description
  String get signalQuality {
    final percentage = signalStrengthPercentage;
    if (percentage > 75) return "Excellent";
    if (percentage > 50) return "Good";
    if (percentage > 25) return "Fair";
    return "Poor";
  }

  /// Calculate connection health score (0-100) - Uses enhanced quality metrics when available
  double get connectionHealthScore {
    // Use enhanced connection quality if available
    if (connectionQuality != null) {
      return connectionQuality!.reliabilityScore;
    }
    
    // Fallback to legacy calculation for backward compatibility
    double score = 0;
    
    // Signal strength contributes 40%
    score += signalStrengthPercentage * 0.4;
    
    // Packet success rate contributes 35%
    score += packetSuccessRate * 100 * 0.35;
    
    // Low reconnection attempts contribute 15%
    final reconnectPenalty = (reconnectionAttempts * 10).clamp(0, 100);
    score += (100 - reconnectPenalty) * 0.15;
    
    // Error rate contributes 10%
    final errorPenalty = (errors.length * 20).clamp(0, 100);
    score += (100 - errorPenalty) * 0.1;
    
    return score.clamp(0, 100);
  }

  /// Get connection health description
  String get healthDescription {
    final score = connectionHealthScore;
    if (score >= 80) return "Excellent";
    if (score >= 60) return "Good";
    if (score >= 40) return "Fair";
    return "Poor";
  }

  /// Get mesh role description
  String get meshRoleDescription {
    if (meshRole == null) return "Unknown";
    switch (meshRole) {
      case 0: return "Mesh Client";
      case 1: return "BLE Root";
      case 2: return "Autonomous Root";
      default: return "Unknown Role";
    }
  }

  /// Check if ESP32 mesh analytics are available
  bool get hasMeshAnalytics => meshHealthScore != null;

  /// Copy with method for updates
  ConnectionAnalytics copyWith({
    DateTime? timestamp,
    String? deviceId,
    String? deviceName,
    int? signalStrength,
    Duration? connectionTime,
    int? reconnectionAttempts,
    List<String>? errors,
    double? batteryLevel,
    int? packetsTransmitted,
    int? packetsDropped,
    Duration? sessionDuration,
    bool? isCurrentSession,
    // Enhanced quality metrics
    ConnectionQuality? connectionQuality,
    // ESP32 Mesh Health fields
    int? meshHealthScore,
    int? meshNeighbors,
    int? meshSuccessRate,
    int? meshRSSI,
    int? meshUptimeHours,
    int? meshRole,
    int? totalNodes,
  }) {
    return ConnectionAnalytics(
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      signalStrength: signalStrength ?? this.signalStrength,
      connectionTime: connectionTime ?? this.connectionTime,
      reconnectionAttempts: reconnectionAttempts ?? this.reconnectionAttempts,
      errors: errors ?? this.errors,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      packetsTransmitted: packetsTransmitted ?? this.packetsTransmitted,
      packetsDropped: packetsDropped ?? this.packetsDropped,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      isCurrentSession: isCurrentSession ?? this.isCurrentSession,
      // Enhanced quality metrics
      connectionQuality: connectionQuality ?? this.connectionQuality,
      // ESP32 Mesh Health fields
      meshHealthScore: meshHealthScore ?? this.meshHealthScore,
      meshNeighbors: meshNeighbors ?? this.meshNeighbors,
      meshSuccessRate: meshSuccessRate ?? this.meshSuccessRate,
      meshRSSI: meshRSSI ?? this.meshRSSI,
      meshUptimeHours: meshUptimeHours ?? this.meshUptimeHours,
      meshRole: meshRole ?? this.meshRole,
      totalNodes: totalNodes ?? this.totalNodes,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'deviceId': deviceId,
    'deviceName': deviceName,
    'signalStrength': signalStrength,
    'connectionTime': connectionTime.inMilliseconds,
    'reconnectionAttempts': reconnectionAttempts,
    'errors': errors,
    'batteryLevel': batteryLevel,
    'packetsTransmitted': packetsTransmitted,
    'packetsDropped': packetsDropped,
    'sessionDuration': sessionDuration.inMilliseconds,
    'isCurrentSession': isCurrentSession,
    // Enhanced quality metrics
    'connectionQuality': connectionQuality?.toJson(),
    // ESP32 Mesh Health fields
    'meshHealthScore': meshHealthScore,
    'meshNeighbors': meshNeighbors,
    'meshSuccessRate': meshSuccessRate,
    'meshRSSI': meshRSSI,
    'meshUptimeHours': meshUptimeHours,
    'meshRole': meshRole,
    'totalNodes': totalNodes,
  };

  /// Create from JSON
  factory ConnectionAnalytics.fromJson(Map<String, dynamic> json) {
    return ConnectionAnalytics(
      timestamp: DateTime.parse(json['timestamp']),
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      signalStrength: json['signalStrength'],
      connectionTime: Duration(milliseconds: json['connectionTime']),
      reconnectionAttempts: json['reconnectionAttempts'] ?? 0,
      errors: List<String>.from(json['errors'] ?? []),
      batteryLevel: json['batteryLevel']?.toDouble() ?? -1,
      packetsTransmitted: json['packetsTransmitted'] ?? 0,
      packetsDropped: json['packetsDropped'] ?? 0,
      sessionDuration: Duration(milliseconds: json['sessionDuration'] ?? 0),
      isCurrentSession: json['isCurrentSession'] ?? false,
      // Enhanced quality metrics
      connectionQuality: json['connectionQuality'] != null 
          ? ConnectionQuality.fromJson(json['connectionQuality'])
          : null,
      // ESP32 Mesh Health fields (optional for backward compatibility)
      meshHealthScore: json['meshHealthScore'],
      meshNeighbors: json['meshNeighbors'],
      meshSuccessRate: json['meshSuccessRate'],
      meshRSSI: json['meshRSSI'],
      meshUptimeHours: json['meshUptimeHours'],
      meshRole: json['meshRole'],
      totalNodes: json['totalNodes'],
    );
  }

  @override
  String toString() {
    return 'ConnectionAnalytics{device: $deviceName, health: ${connectionHealthScore.toStringAsFixed(1)}%, rssi: $signalStrength dBm}';
  }
}