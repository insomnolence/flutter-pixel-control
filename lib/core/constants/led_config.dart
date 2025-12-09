/// Centralized LED brightness and pattern configuration
///
/// All brightness values and LED-related constants should be defined here
/// for easy adjustment. This keeps values consistent with the ESP32 firmware
/// (see esp32-firmware/components/led/include/led/led_config.h)
class LedConfig {
  LedConfig._(); // Prevent instantiation

  // ===========================================================================
  // BRIGHTNESS CONFIGURATION
  // ===========================================================================

  /// Maximum brightness for any active pattern
  ///
  /// This should match LED_BRIGHTNESS_MAX in the ESP32 firmware.
  /// Note: Values above ~79 have caused hardware crashes on some devices.
  static const int brightnessMax = 35;

  /// Brightness for idle/standby patterns
  ///
  /// Lower brightness for subtle ambient effects when no active pattern is running.
  static const int brightnessIdle = 17;

  /// Brightness for normal active patterns
  ///
  /// Standard brightness for regular pattern playback.
  static const int brightnessNormal = 35;

  /// Brightness for alert/attention patterns
  static const int brightnessAlert = 35;

  // ===========================================================================
  // DEFAULT CONTROL VALUES
  // ===========================================================================

  /// Default intensity value for manual control
  static const int defaultIntensity = brightnessNormal;

  /// Default level value for manual control
  static const int defaultLevel = 128;

  /// Default speed value for patterns
  static const int defaultSpeed = 100;

  // ===========================================================================
  // SPEED PRESETS
  // ===========================================================================

  /// Slow animation speed (for subtle idle patterns)
  static const int speedSlow = 35;

  /// Medium animation speed
  static const int speedMedium = 75;

  /// Fast animation speed
  static const int speedFast = 100;

  // ===========================================================================
  // PACKET STRUCTURE CONSTANTS
  // ===========================================================================

  /// Total packet size in bytes
  static const int packetSize = 19;

  /// Header size in bytes (command, brightness, speed, pattern)
  static const int headerSize = 4;

  /// Color data size in bytes (3 x uint32)
  static const int colorSize = 12;

  /// Level data size in bytes
  static const int levelSize = 3;
}
