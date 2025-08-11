import 'dart:convert';
import 'dart:math' as math;

/// Represents a service interruption that impacts user experience
class ServiceInterruption {
  final DateTime startTime;
  final DateTime? endTime;
  final Duration duration;
  final ServiceInterruptionCause cause;
  final bool wasUserNoticed;
  final int recoveryAttempts;
  final String? errorMessage;
  
  ServiceInterruption({
    required this.startTime,
    this.endTime,
    required this.duration,
    required this.cause,
    required this.wasUserNoticed,
    this.recoveryAttempts = 0,
    this.errorMessage,
  });
  
  bool get isResolved => endTime != null;
  
  ServiceInterruption copyWith({
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    ServiceInterruptionCause? cause,
    bool? wasUserNoticed,
    int? recoveryAttempts,
    String? errorMessage,
  }) {
    return ServiceInterruption(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      cause: cause ?? this.cause,
      wasUserNoticed: wasUserNoticed ?? this.wasUserNoticed,
      recoveryAttempts: recoveryAttempts ?? this.recoveryAttempts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration.inMilliseconds,
      'cause': cause.name,
      'wasUserNoticed': wasUserNoticed,
      'recoveryAttempts': recoveryAttempts,
      'errorMessage': errorMessage,
    };
  }
  
  static ServiceInterruption fromJson(Map<String, dynamic> json) {
    return ServiceInterruption(
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: Duration(milliseconds: json['duration']),
      cause: ServiceInterruptionCause.values.firstWhere(
        (e) => e.name == json['cause'],
        orElse: () => ServiceInterruptionCause.unknown,
      ),
      wasUserNoticed: json['wasUserNoticed'] ?? true,
      recoveryAttempts: json['recoveryAttempts'] ?? 0,
      errorMessage: json['errorMessage'],
    );
  }
}

/// Categories of service interruptions
enum ServiceInterruptionCause {
  initialConnectionFailure,  // Device discovery/pairing issues
  userInitiatedRetry,        // Manual retry button press  
  signalLoss,                // Range/interference causing extended outage
  deviceError,               // ESP32 hardware/firmware error
  appError,                  // Flutter app error
  unknown,                   // Unclassified interruption
}

/// Comprehensive connection quality metrics focused on user experience
class ConnectionQuality {
  final double reliabilityScore;        // 0-100 overall quality score
  final double serviceAvailability;     // 0-100 percentage uptime  
  final Duration currentUptime;          // Current stable connection time
  final Duration totalDowntime;          // Total service interruption time
  final String qualityRating;           // "Excellent", "Good", "Fair", "Poor"
  final DateTime? lastInterruption;      // When user last experienced issues
  final List<ServiceInterruption> recentInterruptions; // Last 24h interruptions
  
  // Technical metrics (for debugging, not user-facing)
  final int transparentRecoveries;       // Auto-recovery events
  final int userInitiatedRetries;        // Manual retry attempts
  final double signalConsistency;        // RSSI variance (0-100, higher = more stable)
  final Duration averageRecoveryTime;    // Time to recover from failures
  
  ConnectionQuality({
    required this.reliabilityScore,
    required this.serviceAvailability, 
    required this.currentUptime,
    required this.totalDowntime,
    required this.qualityRating,
    this.lastInterruption,
    this.recentInterruptions = const [],
    this.transparentRecoveries = 0,
    this.userInitiatedRetries = 0,
    required this.signalConsistency,
    required this.averageRecoveryTime,
  });
  
  /// Determine quality rating from reliability score
  static String _calculateQualityRating(double reliabilityScore) {
    if (reliabilityScore >= 95) return "Excellent";
    if (reliabilityScore >= 85) return "Good"; 
    if (reliabilityScore >= 70) return "Fair";
    return "Poor";
  }
  
  /// Create ConnectionQuality from raw metrics
  static ConnectionQuality fromMetrics({
    required Duration sessionDuration,
    required Duration totalDowntime,
    required List<ServiceInterruption> interruptions,
    required int transparentRecoveries,
    required int userRetries,
    required List<int> rssiReadings,
    required DateTime sessionStart,
  }) {
    // Calculate service availability percentage
    final totalSessionTime = sessionDuration.inMilliseconds;
    final downTimeMs = totalDowntime.inMilliseconds;
    final serviceAvailability = totalSessionTime > 0 
        ? ((totalSessionTime - downTimeMs) / totalSessionTime) * 100
        : 100.0;
    
    // Calculate reliability score (weighted composite)
    double reliabilityScore = serviceAvailability * 0.6; // 60% weight on uptime
    
    // Factor in interruption frequency (40% weight)
    final interruptionPenalty = interruptions.length * 5.0; // 5 points per interruption
    reliabilityScore += (40 - interruptionPenalty.clamp(0, 40)); // Max 40 points
    reliabilityScore = reliabilityScore.clamp(0, 100);
    
    // Calculate signal consistency from RSSI variance
    double signalConsistency = 50.0; // Default if no readings
    if (rssiReadings.isNotEmpty) {
      final avgRssi = rssiReadings.reduce((a, b) => a + b) / rssiReadings.length;
      final variance = rssiReadings.map((rssi) => 
        (rssi - avgRssi) * (rssi - avgRssi)
      ).reduce((a, b) => a + b) / rssiReadings.length;
      final standardDev = math.sqrt(variance);
      
      // Convert to 0-100 scale (lower deviation = higher consistency)
      signalConsistency = (20 - standardDev.clamp(0, 20)) * 5; // 0-20 dB std dev -> 100-0 score
    }
    
    // Calculate average recovery time
    final recoveryTimes = interruptions.where((i) => i.isResolved).map((i) => i.duration);
    final averageRecoveryTime = recoveryTimes.isNotEmpty
        ? Duration(milliseconds: (recoveryTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / recoveryTimes.length).round())
        : Duration.zero;
    
    // Current uptime (time since last interruption)
    final now = DateTime.now();
    final lastInterruptionTime = interruptions.isNotEmpty 
        ? interruptions.map((i) => i.endTime ?? i.startTime).reduce((a, b) => a.isAfter(b) ? a : b)
        : sessionStart;
    final currentUptime = now.difference(lastInterruptionTime);
    
    return ConnectionQuality(
      reliabilityScore: reliabilityScore,
      serviceAvailability: serviceAvailability,
      currentUptime: currentUptime,
      totalDowntime: totalDowntime,
      qualityRating: _calculateQualityRating(reliabilityScore),
      lastInterruption: interruptions.isNotEmpty ? interruptions.last.startTime : null,
      recentInterruptions: interruptions.where((i) => 
        now.difference(i.startTime).inHours < 24
      ).toList(),
      transparentRecoveries: transparentRecoveries,
      userInitiatedRetries: userRetries,
      signalConsistency: signalConsistency,
      averageRecoveryTime: averageRecoveryTime,
    );
  }
  
  /// Get user-friendly status summary
  String get statusSummary {
    if (currentUptime.inMinutes < 1) {
      return "Connected - Establishing stability";
    } else if (currentUptime.inHours < 1) {
      return "Connected - $qualityRating (${currentUptime.inMinutes}m uptime)";
    } else {
      return "Connected - $qualityRating (${_formatDuration(currentUptime)} uptime)";
    }
  }
  
  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return "${duration.inDays}d ${duration.inHours % 24}h";
    } else if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else {
      return "${duration.inMinutes}m";
    }
  }
  
  Map<String, dynamic> toJson() {
    return {
      'reliabilityScore': reliabilityScore,
      'serviceAvailability': serviceAvailability,
      'currentUptime': currentUptime.inMilliseconds,
      'totalDowntime': totalDowntime.inMilliseconds,
      'qualityRating': qualityRating,
      'lastInterruption': lastInterruption?.toIso8601String(),
      'recentInterruptions': recentInterruptions.map((i) => i.toJson()).toList(),
      'transparentRecoveries': transparentRecoveries,
      'userInitiatedRetries': userInitiatedRetries,
      'signalConsistency': signalConsistency,
      'averageRecoveryTime': averageRecoveryTime.inMilliseconds,
    };
  }
  
  static ConnectionQuality fromJson(Map<String, dynamic> json) {
    return ConnectionQuality(
      reliabilityScore: json['reliabilityScore']?.toDouble() ?? 0.0,
      serviceAvailability: json['serviceAvailability']?.toDouble() ?? 0.0,
      currentUptime: Duration(milliseconds: json['currentUptime'] ?? 0),
      totalDowntime: Duration(milliseconds: json['totalDowntime'] ?? 0),
      qualityRating: json['qualityRating'] ?? "Unknown",
      lastInterruption: json['lastInterruption'] != null 
          ? DateTime.parse(json['lastInterruption']) 
          : null,
      recentInterruptions: (json['recentInterruptions'] as List?)
          ?.map((i) => ServiceInterruption.fromJson(i))
          .toList() ?? [],
      transparentRecoveries: json['transparentRecoveries'] ?? 0,
      userInitiatedRetries: json['userInitiatedRetries'] ?? 0,
      signalConsistency: json['signalConsistency']?.toDouble() ?? 50.0,
      averageRecoveryTime: Duration(milliseconds: json['averageRecoveryTime'] ?? 0),
    );
  }
}