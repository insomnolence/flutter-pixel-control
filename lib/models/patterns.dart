import 'package:pixel_lights/models/packet.dart';
import 'package:flutter/material.dart';

class Step {
  final int duration;
  final Packet pattern;

  Step(this.duration, this.pattern);
}

class Steps {
  final List<Step> _steps = [];

  // Helper method to add a step.
  void addStep(
    int duration,
    int brightness,
    int speed,
    int level1,
    Pattern pattern,
    int color1,
    int color2,
    int color3,
  ) {
    _steps.add(
      Step(
        duration,
        Packet(
          PixelCommand.HC_PATTERN,
          brightness,
          speed,
          pattern,
          color1,
          color2,
          color3,
          level1,
        ),
      ),
    );
  }

  // Helper to add a Step.
  void addStepClass(Step step) {
    _steps.add(step);
  }

  // Expose a read-only view of the steps
  List<Step> get steps => _steps;

  // Getter to get the length of the list
  int get length => _steps.length;

  // iterator to loop through steps.
  Iterator<Step> get iterator => _steps.iterator;
}

// --- Pattern Definitions ---

Map<String, Steps> patterns = {
  "Warning":
      (() {
        final steps = Steps();
        steps.addStep(
          4,
          255,
          100,
          255,
          Pattern.Flash,
          Colors.yellow.value,
          Colors.yellow.value,
          Colors.yellow.value,
        );
        steps.addStep(
          60,
          255,
          40,
          34,
          Pattern.March,
          Colors.yellow.value,
          Colors.yellow.value,
          Colors.yellow.value,
        );
        steps.addStep(
          60,
          255,
          100,
          75,
          Pattern.MiniTwinkle,
          Colors.yellow.value,
          Color(0xFFFFFC40).value,
          Colors.yellow.value,
        );
        steps.addStep(
          0,
          127,
          75,
          75,
          Pattern.Gradient,
          Colors.yellow.value,
          Color(0xFFFFFC40).value,
          Colors.yellow.value,
        );
        return steps;
      })(),
  "Exit":
      (() {
        final steps = Steps();
        steps.addStep(
          4,
          255,
          100,
          255,
          Pattern.Flash,
          Colors.red.value,
          Colors.red.value,
          Colors.red.value,
        );
        steps.addStep(
          60,
          255,
          40,
          34,
          Pattern.March,
          Colors.red.value,
          Colors.red.value,
          Colors.red.value,
        );
        steps.addStep(
          60,
          255,
          100,
          75,
          Pattern.MiniTwinkle,
          Colors.red.value,
          Color(0xFFFF4040).value,
          Colors.red.value,
        );
        steps.addStep(
          0,
          127,
          75,
          75,
          Pattern.Gradient,
          Colors.red.value,
          Color(0xFFFF4040).value,
          Colors.red.value,
        );
        return steps;
      })(),
  "Idle":
      (() {
        final steps = Steps();
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWR Subtle":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          255,
          35,
          17,
          Pattern.Gradient,
          Colors.red.value,
          Colors.white.value,
          Colors.red.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "Blue Smooth":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          255,
          75,
          75,
          Pattern.Gradient,
          Colors.blue.value,
          Color(0xFF8080FF).value,
          Colors.blue.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWB Paris":
      (() {
        final steps = Steps();
        steps.addStep(
          10,
          255,
          160,
          160,
          Pattern.MiniTwinkle,
          Colors.red.value,
          Colors.white.value,
          Colors.blue.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWG Candy":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          127,
          65,
          255,
          Pattern.CandyCane,
          Colors.red.value,
          Colors.white.value,
          Colors.green.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWR Candy":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          127,
          100,
          255,
          Pattern.CandyCane,
          Colors.red.value,
          Colors.white.value,
          Colors.red.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWG Tree":
      (() {
        final steps = Steps();
        steps.addStep(
          10,
          255,
          100,
          255,
          Pattern.Fixed,
          Colors.red.value,
          Colors.white.value,
          Colors.green.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWG March":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          255,
          127,
          8,
          Pattern.March,
          Colors.red.value,
          Colors.white.value,
          Colors.green.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWG Wipe":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          255,
          127,
          8,
          Pattern.Wipe,
          Colors.red.value,
          Colors.white.value,
          Colors.green.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "RWG Flicker":
      (() {
        final steps = Steps();
        steps.addStep(
          10,
          255,
          255,
          9,
          Pattern.MiniSparkle,
          Colors.red.value,
          Colors.white.value,
          Colors.green.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "CGA":
      (() {
        final steps = Steps();
        steps.addStep(
          30,
          255,
          100,
          128,
          Pattern.MiniTwinkle,
          Color(0xFF00FFFF).value,
          Color(0xFFFF00FF).value,
          Colors.yellow.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "Rainbow":
      (() {
        final steps = Steps();
        steps.addStep(
          10,
          255,
          100,
          255,
          Pattern.Rainbow,
          Colors.white.value,
          Colors.white.value,
          Colors.white.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
  "Strobe":
      (() {
        final steps = Steps();
        steps.addStep(
          10,
          255,
          128,
          255,
          Pattern.Strobe,
          Colors.white.value,
          Colors.white.value,
          Colors.white.value,
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              20,
              35,
              Pattern.Gradient,
              Colors.red.value,
              Colors.white.value,
              Colors.green.value,
              17,
            ),
          ),
        );
        return steps;
      })(),
};

// Create a map of pattern names to gradients
final Map<String, List<Color>> patternGradients = {
  "Warning": const [
    Color(0xFFFFEB3B), // Red
    Color(0xFFFFF7B3), // Yellow
    Color(0xFFFFFFFF), // Blue
  ],
  "Exit": const [
    Color(0xFFFF0000), // Blue
    Color(0xFFFA6D6D), // Yellow
    Color(0xFFFFFFFF), // Red
  ],
  "Idle": const [
    Color.fromARGB(255, 179, 0, 255), // purple
    Color.fromARGB(255, 0, 255, 242), // aqua
    Color.fromARGB(255, 255, 102, 0), // orange
  ],
  "RWR Subtle": const [Colors.red, Colors.white, Colors.red],
  "Blue Smooth": const [
    Colors.blue,
    Color.fromARGB(255, 167, 181, 255),
    Color.from(alpha: 255, red: 218, green: 218, blue: 255),
  ],
  "RWB Paris": const [Colors.red, Colors.white, Colors.blue],
  "RWG Candy": const [Colors.red, Colors.white, Colors.green],
  "RWR Candy": const [Colors.red, Colors.white, Colors.red],
  "RWG Tree": const [Colors.red, Colors.white, Colors.green],
  "RWG March": const [Colors.red, Colors.white, Colors.green],
  "RWG Wipe": const [Colors.red, Colors.white, Colors.green],
  "RWG Flicker": const [Colors.red, Colors.white, Colors.green],
  "Strobe": const [Color(0xFFFFFFFF), Color(0xFF787878), Color(0xFFFFFFFF)],
  "Rainbow": const [Colors.red, Color(0xFFFFEB3B), Colors.blue],
  "CGA": const [Color(0xFF00FFFF), Color(0xFFFF00FF), Colors.yellow],
};
