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
    // Create a ByteBuffer (equivalent) with the specified size and endianness.
    final buffer = BytesBuilder();

    // Add the command byte.
    buffer.addByte(command.code);

    // Add the brightness byte.
    buffer.addByte(brightness);

    // Add the speed byte.
    buffer.addByte(speed);

    // Add the pattern code byte.
    buffer.addByte(pattern.code);

    // Add the color int to the buffer.
    for (int a in color) {
      buffer.add(Int32List.fromList([a]).buffer.asUint8List());
    }

    // Add the level bytes.
    for (int a in level) {
      buffer.addByte(a);
    }

    return buffer.toBytes();
  }
}
