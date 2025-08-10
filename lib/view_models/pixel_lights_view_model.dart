import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pixel_lights/models/packet.dart';
import 'package:pixel_lights/core/constants/app_colors.dart';
import 'package:pixel_lights/models/patterns.dart' as pixel_patterns;
import 'package:pixel_lights/services/bluetooth_services.dart';

enum PatternState {
  idle,
  loading,
  active,
  error,
  completing
}

// Class to hold pattern execution information
class PatternExecution {
  final String patternName;
  final PatternState state;
  final int totalDurationSeconds;
  final int elapsedSeconds;
  final String? errorMessage;
  final DateTime? startTime;
  
  PatternExecution({
    required this.patternName,
    required this.state,
    this.totalDurationSeconds = 0,
    this.elapsedSeconds = 0,
    this.errorMessage,
    this.startTime,
  });
  
  double get progress {
    if (totalDurationSeconds == 0) return 0.0;
    return (elapsedSeconds / totalDurationSeconds).clamp(0.0, 1.0);
  }
  
  bool get isInfinite => totalDurationSeconds == 0;
  
  PatternExecution copyWith({
    String? patternName,
    PatternState? state,
    int? totalDurationSeconds,
    int? elapsedSeconds,
    String? errorMessage,
    DateTime? startTime,
  }) {
    return PatternExecution(
      patternName: patternName ?? this.patternName,
      state: state ?? this.state,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
    );
  }
}

class PixelLightsViewModel extends ChangeNotifier {
  // --- Data for Manual Fragment ---
  int? colorPoint1;
  int? colorPoint2;
  int? colorPoint3;
  Completer? completer;
  bool _isDisposed = false;
  StreamSubscription? packetStream;
  pixel_patterns.Steps packetToSend = pixel_patterns.Steps();
  
  // Pattern execution state management
  PatternExecution? _currentExecution;
  Timer? _progressTimer;
  Timer? _completionTimer;
  
  // Simplified approach - patterns either run and auto-return to Idle, or are Idle
  // No manual timing needed since ESP32 handles pattern timing and auto-return
  
  // Custom pattern ordering (Idle first, then Warning/Exit, then others)
  static const List<String> _patternOrder = [
    'Idle',
    'Warning', 
    'Exit',
    'RWR Subtle',
    'Blue Smooth', 
    'RWB Paris',
    'RWG Candy',
    'RWR Candy',
    'RWG Tree',
    'RWG March',
    'RWG Wipe', 
    'RWG Flicker',
    'CGA',
    'Rainbow',
    'Strobe'
  ];

  // Set up the values being tracked across the fragments.
  Color color1 = AppColors.pureRed;
  Color color2 = AppColors.pureWhite;
  Color color3 = AppColors.pureGreen;

  Pattern patternValue = Pattern.MiniTwinkle;

  int intensityValue = 128;
  int rateValue = 100;
  int levelValue = 128;

  final IBluetoothService _bluetoothService;

  PixelLightsViewModel({IBluetoothService? bluetoothService})
    : _bluetoothService = bluetoothService ?? PixelBluetoothService() {
    // Initialize with Idle pattern as default
    _currentExecution = PatternExecution(
      patternName: 'Idle',
      state: PatternState.active,
      totalDurationSeconds: 0,
    );
  }

  IBluetoothService get bluetoothService => _bluetoothService;
  
  // Getters for pattern state
  PatternExecution? get currentExecution => _currentExecution;
  String? get activePatternName => _currentExecution?.patternName;
  PatternState get activePatternState => _currentExecution?.state ?? PatternState.idle;
  double get patternProgress => _currentExecution?.progress ?? 0.0;
  
  // Get ordered pattern list
  List<String> get orderedPatterns => _patternOrder;
  
  // Check if a specific pattern is currently active
  bool isPatternActive(String patternName) {
    return _currentExecution?.patternName == patternName && 
           _currentExecution?.state == PatternState.active;
  }
  
  // Check if a specific pattern is loading
  bool isPatternLoading(String patternName) {
    return _currentExecution?.patternName == patternName && 
           _currentExecution?.state == PatternState.loading;
  }
  
  // Check if a specific pattern has an error
  bool hasPatternError(String patternName) {
    return _currentExecution?.patternName == patternName && 
           _currentExecution?.state == PatternState.error;
  }
  
  // Calculate total duration of timed steps (excluding infinite duration steps)
  int _calculatePatternDuration(pixel_patterns.Steps steps) {
    int totalDuration = 0;
    for (final step in steps.steps) {
      // Add duration, but stop at infinite steps (duration 0)
      if (step.duration == 0) break;
      totalDuration += step.duration;
    }
    debugPrint("Calculated pattern duration: ${totalDuration}s");
    return totalDuration;
  }
  
  // Simplified - no manual duration tracking needed  
  int getPatternDuration(String patternName) {
    return 0; // ESP32 handles timing
  }

  // Helper method to convert Flutter ARGB color to ESP32 RGB format
  static int colorToRGB(int flutterColorValue) {
    return flutterColorValue & 0x00FFFFFF; // Strip alpha channel
  }

  // --- Bluetooth ---
  BluetoothDevice? _bluetoothDevice;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BluetoothDevice? get bluetoothDevice => _bluetoothDevice;
  BluetoothCharacteristic? get txCharacteristic => _txCharacteristic;

  // Method to start scanning.
  Future<void> startBluetoothScan() async {
    await _bluetoothService.startScan(timeout: const Duration(seconds: 15));
    notifyListeners();
  }

  // Method to stop scanning.
  Future<void> stopBluetoothScan() async {
    await _bluetoothService.stopScan();
    notifyListeners();
  }

  // Method to connect to a device.
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

  // Method to disconnect from a device.
  Future<void> disconnectDevice() async {
    if (_bluetoothDevice != null) {
      await _bluetoothService.disconnect(_bluetoothDevice!);
    }
  }

  // Use a pattern on the device with enhanced state management
  Future<void> usePattern(String patternName) async {
    final patternSteps = pixel_patterns.patterns[patternName];
    
    if (_bluetoothDevice == null) {
      debugPrint("usePattern: Bluetooth device is null");
      return;
    }
    
    if (patternSteps == null) {
      debugPrint("usePattern: Pattern not found: $patternName");
      return;
    }
    
    // Immediately set as active pattern
    _setPatternActive(patternName);
    
    try {
      await sendPattern(patternSteps, patternName);
      
      // For non-Idle patterns, calculate when to return to Idle
      if (patternName != 'Idle') {
        final totalDuration = _calculatePatternDuration(patternSteps);
        if (totalDuration > 0) {
          Timer(Duration(seconds: totalDuration), () {
            debugPrint("Pattern $patternName completed, returning to Idle");
            _setPatternActive('Idle');
          });
        }
      }
    } catch (e) {
      debugPrint("usePattern error: $e");
      // On error, set back to Idle
      _setPatternActive('Idle');
    }
  }
  
  // Set pattern to loading state
  void _setPatternLoading(String patternName) {
    _clearTimers();
    _currentExecution = PatternExecution(
      patternName: patternName,
      state: PatternState.loading,
      totalDurationSeconds: 0,
      startTime: DateTime.now(),
    );
    notifyListeners();
  }
  
  // Set pattern to active state (simplified)
  void _setPatternActive(String patternName) {
    debugPrint("Setting pattern active: $patternName");
    _clearTimers();
    _currentExecution = PatternExecution(
      patternName: patternName,
      state: PatternState.active,
      totalDurationSeconds: 0, // ESP32 handles timing
      startTime: DateTime.now(),
    );
    
    notifyListeners();
    debugPrint("Pattern active set to: ${_currentExecution?.patternName}");
  }
  
  // Set pattern to error state
  void _setPatternError(String patternName, String error) {
    _clearTimers();
    _currentExecution = PatternExecution(
      patternName: patternName,
      state: PatternState.error,
      errorMessage: error,
    );
    notifyListeners();
    
    // Auto-clear error after 3 seconds and return to Idle
    Timer(const Duration(seconds: 3), () {
      if (_currentExecution?.state == PatternState.error) {
        _returnToIdle();
      }
    });
  }
  
  // Start progress tracking
  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentExecution?.state == PatternState.active) {
        final startTime = _currentExecution!.startTime!;
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        _currentExecution = _currentExecution!.copyWith(elapsedSeconds: elapsed);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }
  
  // Schedule automatic return to Idle
  void _scheduleCompletion(int durationSeconds) {
    _completionTimer?.cancel();
    _completionTimer = Timer(Duration(seconds: durationSeconds), () {
      if (_currentExecution?.state == PatternState.active) {
        _returnToIdle();
      }
    });
  }
  
  // Return to Idle pattern
  void _returnToIdle() {
    _clearTimers();
    usePattern('Idle'); // This will trigger the normal pattern execution flow
  }
  
  // Clear all timers
  void _clearTimers() {
    _progressTimer?.cancel();
    _completionTimer?.cancel();
    _progressTimer = null;
    _completionTimer = null;
  }

  Future<void> sendPattern(pixel_patterns.Steps steps, [String? patternName]) async {
    if (completer != null && !completer!.isCompleted) {
      completer!.complete();
    }
    completer = Completer();
    final currentCompleter = completer;
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
      
      // Set pattern to active after first packet is sent successfully
      if (patternName != null && _currentExecution?.state == PatternState.loading) {
        _setPatternActive(patternName);
      }
      if (currentCompleter!.isCompleted) {
        debugPrint("sendPattern: completer completed. Stopping.");
        return;
      }
      await Future.delayed(Duration(milliseconds: i.duration * 1000));
      if (_isDisposed) {
        debugPrint("sendPattern: is disposed.");
        return;
      }
      if (currentCompleter!.isCompleted) {
        debugPrint("sendPattern: completer completed. Stopping.");
        return;
      }
    }
    if (!currentCompleter!.isCompleted) {
      currentCompleter.complete();
    }
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
        colorToRGB(color1.value),
        colorToRGB(color2.value),
        colorToRGB(color3.value),
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
        colorToRGB(color1.value),
        colorToRGB(color2.value),
        colorToRGB(color3.value),
      );
    }

    await sendPattern(packetToSend);
  }

  // Force return to Idle (manual override)
  void forceReturnToIdle() {
    _returnToIdle();
  }
  
  // Clear pattern error state
  void clearPatternError() {
    if (_currentExecution?.state == PatternState.error) {
      _returnToIdle();
    }
  }

  //dispose the class
  @override
  void dispose() {
    _isDisposed = true;
    _clearTimers();
    packetStream?.cancel();
    if (completer != null && !completer!.isCompleted) {
      completer!.complete();
    }
    completer = null;
    _connectionStateSubscription?.cancel();
    _bluetoothService.dispose(); // Call the dispose on the bluetoothService
    super.dispose();
  }
}
