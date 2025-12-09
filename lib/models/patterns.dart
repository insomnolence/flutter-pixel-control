import 'package:pixel_lights/models/packet.dart';
import 'package:flutter/material.dart';
import 'package:pixel_lights/core/constants/app_colors.dart';
import 'package:pixel_lights/core/constants/led_config.dart';

// Helper function to convert Flutter ARGB color to ESP32 RGB format
int colorToRGB(int flutterColorValue) {
  return flutterColorValue & 0x00FFFFFF; // Strip alpha channel
}

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
          LedConfig.brightnessNormal,  // Flash
          100,
          255,
          Pattern.Flash,
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
        );
        steps.addStep(
          60,
          LedConfig.brightnessNormal,  // March
          40,
          34,
          Pattern.March,
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
        );
        steps.addStep(
          60,
          LedConfig.brightnessNormal,  // MiniTwinkle
          100,
          75,
          Pattern.MiniTwinkle,
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(Color(0xFFFFFC40).toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
        );
        steps.addStep(
          0,
          LedConfig.brightnessNormal,  // Gradient
          75,
          75,
          Pattern.Gradient,
          colorToRGB(AppColors.pureYellow.toARGB32()),
          colorToRGB(Color(0xFFFFFC40).toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
        );
        return steps;
      })(),
  "Exit":
      (() {
        final steps = Steps();
        steps.addStep(
          4,
          LedConfig.brightnessNormal,  // Flash
          100,
          255,
          Pattern.Flash,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
        );
        steps.addStep(
          60,
          LedConfig.brightnessNormal,  // March
          40,
          34,
          Pattern.March,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
        );
        steps.addStep(
          60,
          LedConfig.brightnessNormal,  // MiniTwinkle
          100,
          75,
          Pattern.MiniTwinkle,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(Color(0xFFFF4040).toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
        );
        steps.addStep(
          0,
          LedConfig.brightnessNormal,  // Gradient
          75,
          75,
          Pattern.Gradient,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(Color(0xFFFF4040).toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
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
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedSlow,
          17,
          Pattern.Gradient,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedMedium,
          75,
          Pattern.Gradient,
          colorToRGB(AppColors.pureBlue.toARGB32()),
          colorToRGB(Color(0xFF8080FF).toARGB32()),
          colorToRGB(AppColors.pureBlue.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          160,
          160,
          Pattern.MiniTwinkle,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureBlue.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          65,
          255,
          Pattern.CandyCane,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureGreen.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedFast,
          255,
          Pattern.CandyCane,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureRed.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedFast,
          255,
          Pattern.Fixed,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureGreen.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          127,
          8,
          Pattern.March,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureGreen.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          127,
          8,
          Pattern.Wipe,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureGreen.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          255,
          9,
          Pattern.MiniSparkle,
          colorToRGB(AppColors.pureRed.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureGreen.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedFast,
          128,
          Pattern.MiniTwinkle,
          colorToRGB(Color(0xFF00FFFF).toARGB32()),
          colorToRGB(Color(0xFFFF00FF).toARGB32()),
          colorToRGB(AppColors.pureYellow.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          LedConfig.speedFast,
          255,
          Pattern.Rainbow,
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
          LedConfig.brightnessNormal,
          128,
          255,
          Pattern.Strobe,
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
          colorToRGB(AppColors.pureWhite.toARGB32()),
        );
        steps.addStepClass(
          Step(
            0,
            Packet(
              PixelCommand.HC_PATTERN,
              LedConfig.brightnessIdle,
              LedConfig.speedSlow,
              Pattern.Gradient,
              colorToRGB(AppColors.pureRed.toARGB32()),
              colorToRGB(AppColors.pureWhite.toARGB32()),
              colorToRGB(AppColors.pureGreen.toARGB32()),
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
  "RWR Subtle": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureRed],
  "Blue Smooth": const [
    AppColors.pureBlue,
    AppColors.pureWhite,  // White in the middle
    Color(0xFF80C0FF),    // Light blue
  ],
  "RWB Paris": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureBlue],
  "RWG Candy": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureGreen],
  "RWR Candy": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureRed],
  "RWG Tree": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureGreen],
  "RWG March": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureGreen],
  "RWG Wipe": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureGreen],
  "RWG Flicker": const [AppColors.pureRed, AppColors.pureWhite, AppColors.pureGreen],
  "Strobe": const [Color(0xFFFFFFFF), Color(0xFF787878), Color(0xFFFFFFFF)],
  "Rainbow": const [AppColors.pureRed, Color(0xFFFFEB3B), AppColors.pureBlue],
  "CGA": const [Color(0xFF00FFFF), Color(0xFFFF00FF), AppColors.pureYellow],
};
