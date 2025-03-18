import 'package:flutter/material.dart';
import 'dart:math';

class CustomHuePicker extends StatefulWidget {
  final double width; // Add width parameter
  final Function(Color) onColorChanged;
  final TextStyle textStyle;
  final HSVColor hsvColor;

  CustomHuePicker({
    super.key,
    required Color color,
    required this.width, // Make width required
    required this.onColorChanged,
    this.textStyle = const TextStyle(fontSize: 16),
  }) : hsvColor = HSVColor.fromColor(color);

  @override
  State<CustomHuePicker> createState() => _CustomHuePickerState();
}

class _CustomHuePickerState extends State<CustomHuePicker> {
  Color get _color {
    return widget.hsvColor.toColor();
  }

  // in _CustomHuePickerState
  void _updateColorFromOffset(Offset localOffset, double size) {
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
    widget.hsvColor.withHue(hue).withSaturation(dist);

    setState(() {
      final color = HSVColor.fromAHSV(1.0, hue, dist, 1.0).toColor();
      widget.onColorChanged(color);
    });
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
            child: GestureDetector(
              onPanUpdate: (details) {
                _updateColorFromOffset(details.localPosition, widget.width);
              },
              onTapDown: (details) {
                _updateColorFromOffset(details.localPosition, widget.width);
              },
              child: CustomPaint(
                painter: HUEColorWheelPainter(widget.hsvColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'R: ${_color.red}, G: ${_color.green}, B: ${_color.blue}',
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
      Paint()..color = Colors.black.withOpacity(1 - hsvColor.value),
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
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

bool useWhiteForeground(Color backgroundColor, {double bias = 0.0}) {
  // Old:
  // return 1.05 / (color.computeLuminance() + 0.05) > 4.5;

  // New:
  int v =
      sqrt(
        pow(backgroundColor.red, 2) * 0.299 +
            pow(backgroundColor.green, 2) * 0.587 +
            pow(backgroundColor.blue, 2) * 0.114,
      ).round();
  return v < 130 + bias ? true : false;
}
