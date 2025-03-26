import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/models/packet.dart';
import "package:pixel_lights/models/color_wheel.dart";

class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  String? selectedPattern;
  bool _isSliderChanging = false;

  // Helper function to convert a percentage (0-100) to a value in the 0-255 range
  int _percentageToValue(double percentage) {
    return (percentage / 100 * 255).round();
  }

  // Helper function to convert a value (0-255) to a percentage (0-100)
  double _valueToPercentage(int value) {
    return (value / 255 * 100);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      builder: (context, viewModel, child) {
        return BackgroundMesh(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(flex: 2, child: _buildColorColumn(viewModel)),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSliderSection(
                              "Intensity",
                              0,
                              100,
                              _valueToPercentage(viewModel.intensityValue),
                              (percentage) => setState(() {
                                viewModel.intensityValue = _percentageToValue(
                                  percentage,
                                );
                              }),
                              () => viewModel.processPacketInformation(
                                controlPacket: true,
                              ), // onSliderEnd
                            ),
                            _buildSliderSection(
                              "Rate",
                              0,
                              100,
                              _valueToPercentage(viewModel.rateValue),
                              (percentage) => setState(() {
                                viewModel.rateValue = _percentageToValue(
                                  percentage,
                                );
                              }),
                              () => viewModel.processPacketInformation(
                                controlPacket: true,
                              ), // onSliderEnd
                            ),
                            _buildSliderSection(
                              "Level",
                              0,
                              100,
                              _valueToPercentage(viewModel.levelValue),
                              (percentage) => setState(() {
                                viewModel.levelValue = _percentageToValue(
                                  percentage,
                                );
                              }),
                              () => viewModel.processPacketInformation(
                                controlPacket: true,
                              ), // onSliderEnd
                            ),
                            const SizedBox(height: 16),
                            _buildPatternDropdown(viewModel),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorColumn(PixelLightsViewModel viewModel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildColorSection(
          "Color 1",
          viewModel.color1,
          (color) => setState(() {
            viewModel.color1 = color;
          }),
          (color, shouldProcessPacket) {
            // onColorChangeEnd
            viewModel.color1 = color;
            if (shouldProcessPacket) {
              viewModel.processPacketInformation(controlPacket: false);
            }
          },
        ),
        const SizedBox(height: 40),
        _buildColorSection(
          "Color 2",
          viewModel.color2,
          (color) => setState(() {
            viewModel.color2 = color;
          }),
          (color, shouldProcessPacket) {
            // onColorChangeEnd
            viewModel.color2 = color;
            if (shouldProcessPacket) {
              viewModel.processPacketInformation(controlPacket: false);
            }
          },
        ),
        const SizedBox(height: 40),
        _buildColorSection(
          "Color 3",
          viewModel.color3,
          (color) => setState(() {
            viewModel.color3 = color;
          }),
          (color, shouldProcessPacket) {
            // onColorChangeEnd
            viewModel.color3 = color;
            if (shouldProcessPacket) {
              viewModel.processPacketInformation(controlPacket: false);
            }
          },
        ),
      ],
    );
  }

  Widget _buildColorSection(
    String title,
    Color currentColor,
    Function(Color) onColorChanged,
    Function(Color, bool) onColorChangeEnd, // callback with boolean
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CustomHuePicker(
            color: currentColor,
            onColorChanged: onColorChanged,
            onColorChangeEnd: onColorChangeEnd, // Pass the callback
            width: 120,
            textStyle: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderSection(
    String title,
    double min,
    double max,
    double percentage,
    Function(double) onPercentageChanged,
    Function() onSliderEnd, // callback
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            Expanded(
              child: Slider(
                min: min,
                max: max,
                value: percentage,
                onChanged: (newPercentage) {
                  onPercentageChanged(newPercentage);
                  if (!_isSliderChanging) {
                    setState(() {
                      _isSliderChanging = true;
                    });
                  }
                },
                onChangeEnd: (newPercentage) {
                  onSliderEnd();
                  setState(() {
                    _isSliderChanging = false;
                  });
                },
                activeColor: Colors.white.withOpacity(0.8),
                inactiveColor: Colors.grey.withOpacity(0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Text(
                '${percentage.round()}%',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPatternDropdown(PixelLightsViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[200],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<Pattern>(
        value: viewModel.patternValue,
        dropdownColor: Colors.blue[200],
        onChanged: (Pattern? newValue) {
          if (newValue != null) {
            setState(() {
              viewModel.patternValue = newValue;
            });

            viewModel.processPacketInformation(controlPacket: false);
            viewModel.usePattern(newValue.name);
          }
        },
        items:
            Pattern.values.map<DropdownMenuItem<Pattern>>((Pattern value) {
              return DropdownMenuItem<Pattern>(
                value: value,
                child: Text(value.name),
              );
            }).toList(),
        style: const TextStyle(color: Colors.black),
        isExpanded: true,
        underline: const SizedBox(),
      ),
    );
  }
}
