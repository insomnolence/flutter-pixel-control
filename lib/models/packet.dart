import 'dart:typed_data';

// --- Data Structures ---
enum PixelCommand {
  HC_NONE(0), // No Command
  HC_CONTROL(1), // Brightness and Speed
  HC_PATTERN(2); // Patterns

  final int code;
  const PixelCommand(this.code);
}

enum Pattern {
  MiniTwinkle(0),
  MiniSparkle(1),
  Sparkle(2),
  Rainbow(3),
  Flash(4),
  March(5),
  Wipe(6),
  Gradient(7),
  Fixed(8),
  Strobe(9),
  CandyCane(10);

  final int code;
  const Pattern(this.code);
}

class Packet {
  PixelCommand command;
  int brightness; //UByte in kotlin.
  int speed; //UByte in kotlin.
  Pattern pattern;
  List<int> color = List.filled(3, 0); // UIntArray in kotlin.
  List<int> level = List.filled(3, 0); // UByteArray in kotlin.

  Packet(
    this.command,
    this.brightness,
    this.speed,
    this.pattern,
    int color1,
    int color2,
    int color3,
    int level1,
  ) {
    color[0] = color1;
    color[1] = color2;
    color[2] = color3;
    level[0] = level1;
    level[1] = 255; //255u
    level[2] = 255; //255u
  }

  Uint8List createBytes() {
    // ESP32 expects exactly 19 bytes: 4 bytes header + 12 bytes colors + 3 bytes levels
    final buffer = Uint8List(19);
    
    // Header (4 bytes)
    buffer[0] = command.code;
    buffer[1] = brightness;
    buffer[2] = speed;
    buffer[3] = pattern.code;
    
    // Colors (12 bytes: 3 × uint32_t in little endian)
    int offset = 4;
    for (int i = 0; i < 3; i++) {
      final colorValue = color[i];
      buffer[offset] = colorValue & 0xFF;           // Byte 0 (LSB)
      buffer[offset + 1] = (colorValue >> 8) & 0xFF;  // Byte 1
      buffer[offset + 2] = (colorValue >> 16) & 0xFF; // Byte 2
      buffer[offset + 3] = (colorValue >> 24) & 0xFF; // Byte 3 (MSB)
      offset += 4;
    }
    
    // Levels (3 bytes)
    buffer[16] = level[0];
    buffer[17] = level[1];  
    buffer[18] = level[2];
    
    return buffer;
  }
}
