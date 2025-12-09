import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math';

// Custom pan gesture recognizer that wins against parent scroll widgets
class _ColorWheelPanGestureRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Win the gesture arena immediately to prevent parent scroll widgets from interfering
    resolve(GestureDisposition.accepted);
  }

}

class CustomHuePicker extends StatefulWidget {
  final double width;
  final Function(Color) onColorChanged;
  final Function(Color, bool)
  onColorChangeEnd; // Callback with color and boolean
  final TextStyle textStyle;
  final HSVColor hsvColor;

  CustomHuePicker({
    super.key,
    required Color color,
    required this.width,
    required this.onColorChanged,
    required this.onColorChangeEnd,
    this.textStyle = const TextStyle(fontSize: 16),
  }) : hsvColor = HSVColor.fromColor(color);

  @override
  State<CustomHuePicker> createState() => _CustomHuePickerState();
}

class _CustomHuePickerState extends State<CustomHuePicker> {
  late HSVColor _currentHsvColor;

  @override
  void initState() {
    super.initState();
    _currentHsvColor = widget.hsvColor;
  }

  @override
  void didUpdateWidget(covariant CustomHuePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hsvColor != oldWidget.hsvColor) {
      _currentHsvColor = widget.hsvColor;
    }
  }

  Color get _color => _currentHsvColor.toColor();

  void _updateColorFromOffset(Offset localOffset, double size, bool isFinal) {
    RenderBox? getBox = context.findRenderObject() as RenderBox?;
    if (getBox == null) {
      return;
    }

    double width = size;
    double height = size;

    double horizontal = localOffset.dx.clamp(0.0, width);
    double vertical = localOffset.dy.clamp(0.0, height);

    Offset center = Offset(width / 2, height / 2);
    double radio = width <= height ? width / 2 : height / 2;
    double dist =
        sqrt(pow(horizontal - center.dx, 2) + pow(vertical - center.dy, 2)) /
        radio;
    dist = dist.clamp(0.0, 1.0);
    double rad =
        (atan2(horizontal - center.dx, vertical - center.dy) / pi + 1) /
        2 *
        360;

    double hue = ((rad + 90) % 360).clamp(0, 360);

    _currentHsvColor = _currentHsvColor.withHue(hue).withSaturation(dist);
    final color = HSVColor.fromAHSV(1.0, hue, dist, 1.0).toColor();

    setState(() {
      // Update the indicator circle immediately
    });

    // Call onColorChanged during dragging for real-time updates
    widget.onColorChanged(color);

    if (isFinal) {
      widget.onColorChangeEnd(color, true); // Send the final color and true
    }
  }

  @override
  Widget build(BuildContext context) {
    double size = widget.width;
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: AspectRatio(
            aspectRatio: 1.0,
            child: RawGestureDetector(
              gestures: {
                // Custom pan recognizer that blocks parent scrolling
                _ColorWheelPanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_ColorWheelPanGestureRecognizer>(
                  () => _ColorWheelPanGestureRecognizer(),
                  (_ColorWheelPanGestureRecognizer instance) {
                    instance
                      ..onStart = (details) {
                        _updateColorFromOffset(
                          details.localPosition,
                          widget.width,
                          false,
                        );
                      }
                      ..onUpdate = (details) {
                        _updateColorFromOffset(
                          details.localPosition,
                          widget.width,
                          false,
                        );
                      }
                      ..onEnd = (details) {
                        widget.onColorChangeEnd(_currentHsvColor.toColor(), true);
                      };
                  },
                ),
                TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance
                      ..onTapDown = (details) {
                        _updateColorFromOffset(
                          details.localPosition,
                          widget.width,
                          false,
                        );
                      }
                      ..onTapUp = (details) {
                        _updateColorFromOffset(
                          details.localPosition,
                          widget.width,
                          true,
                        );
                      };
                  },
                ),
              },
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: HUEColorWheelPainter(_currentHsvColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'R: ${(_color.r * 255).round()}, G: ${(_color.g * 255).round()}, B: ${(_color.b * 255).round()}',
          style: widget.textStyle,
        ),
      ],
    );
  }
}

/// Painter for hue color wheel.
class HUEColorWheelPainter extends CustomPainter {
  const HUEColorWheelPainter(this.hsvColor, {this.pointerColor});

  final HSVColor hsvColor;
  final Color? pointerColor;

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    Offset center = Offset(size.width / 2, size.height / 2);
    double radio = size.width <= size.height ? size.width / 2 : size.height / 2;

    final List<Color> colors = [
      const HSVColor.fromAHSV(1.0, 360.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 300.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 240.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 180.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 120.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 60.0, 1.0, 1.0).toColor(),
      const HSVColor.fromAHSV(1.0, 0.0, 1.0, 1.0).toColor(),
    ];
    final Gradient gradientS = SweepGradient(colors: colors);
    const Gradient gradientR = RadialGradient(
      colors: [Colors.white, Color(0x00FFFFFF)],
    );
    canvas.drawCircle(
      center,
      radio,
      Paint()..shader = gradientS.createShader(rect),
    );
    canvas.drawCircle(
      center,
      radio,
      Paint()..shader = gradientR.createShader(rect),
    );
    canvas.drawCircle(
      center,
      radio,
      Paint()..color = Colors.black.withValues(alpha: 1 - hsvColor.value),
    );

    canvas.drawCircle(
      Offset(
        center.dx +
            hsvColor.saturation * radio * cos((hsvColor.hue * pi / 180)),
        center.dy -
            hsvColor.saturation * radio * sin((hsvColor.hue * pi / 180)),
      ),
      size.height * 0.04,
      Paint()
        ..color =
            pointerColor ??
            (useWhiteForeground(hsvColor.toColor())
                ? Colors.white
                : Colors.black)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

bool useWhiteForeground(Color backgroundColor, {double bias = 0.0}) {
  final r = (backgroundColor.r * 255).round();
  final g = (backgroundColor.g * 255).round();
  final b = (backgroundColor.b * 255).round();
  int v = sqrt(pow(r, 2) * 0.299 + pow(g, 2) * 0.587 + pow(b, 2) * 0.114).round();
  return v < 130 + bias;
}
