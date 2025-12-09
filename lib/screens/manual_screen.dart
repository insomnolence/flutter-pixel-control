import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/models/packet.dart';
import "package:pixel_lights/models/color_wheel.dart";

class ManualScreen extends StatefulWidget {
  final GlobalKey? colorPickerKey;
  
  const ManualScreen({super.key, this.colorPickerKey});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
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
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: isWide
                            ? _buildWideLayout(viewModel)
                            : _buildNarrowLayout(viewModel),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(PixelLightsViewModel viewModel) {
    return Row(
      children: [
        Expanded(child: _buildColorsCard(viewModel)),
        const SizedBox(width: 16),
        Expanded(child: _buildControlsCard(viewModel)),
      ],
    );
  }

  Widget _buildNarrowLayout(PixelLightsViewModel viewModel) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildColorsCard(viewModel),
          const SizedBox(height: 16),
          _buildControlsCard(viewModel),
        ],
      ),
    );
  }

  Widget _buildColorsCard(PixelLightsViewModel viewModel) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      color: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'COLORS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildColorSwatchRow(viewModel),
            const SizedBox(height: 20),
            _buildInlineColorPicker(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatchRow(PixelLightsViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildColorSwatch('Color 1', viewModel.color1, 0),
        _buildColorSwatch('Color 2', viewModel.color2, 1),
        _buildColorSwatch('Color 3', viewModel.color3, 2),
      ],
    );
  }

  int _selectedColorIndex = 0;

  Widget _buildColorSwatch(String label, Color color, int index) {
    final isSelected = _selectedColorIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColorIndex = index;
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.white 
                    : Colors.white.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected 
                  ? Colors.white 
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineColorPicker(PixelLightsViewModel viewModel) {
    Color currentColor;
    Function(Color) onColorChanged;
    Function(Color, bool) onColorChangeEnd;

    switch (_selectedColorIndex) {
      case 0:
        currentColor = viewModel.color1;
        onColorChanged = (color) => setState(() { viewModel.color1 = color; });
        onColorChangeEnd = (color, shouldProcessPacket) {
          viewModel.color1 = color;
          if (shouldProcessPacket) {
            viewModel.processPacketInformation(controlPacket: false);
          }
        };
        break;
      case 1:
        currentColor = viewModel.color2;
        onColorChanged = (color) => setState(() { viewModel.color2 = color; });
        onColorChangeEnd = (color, shouldProcessPacket) {
          viewModel.color2 = color;
          if (shouldProcessPacket) {
            viewModel.processPacketInformation(controlPacket: false);
          }
        };
        break;
      case 2:
      default:
        currentColor = viewModel.color3;
        onColorChanged = (color) => setState(() { viewModel.color3 = color; });
        onColorChangeEnd = (color, shouldProcessPacket) {
          viewModel.color3 = color;
          if (shouldProcessPacket) {
            viewModel.processPacketInformation(controlPacket: false);
          }
        };
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Adjust Selected Color',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          RepaintBoundary(
            child: Container(
              key: widget.colorPickerKey, // GlobalKey for bounds detection
              child: CustomHuePicker(
                color: currentColor,
                onColorChanged: onColorChanged,
                onColorChangeEnd: onColorChangeEnd,
                width: 200,
                textStyle: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildControlsCard(PixelLightsViewModel viewModel) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      color: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'PATTERN & CONTROLS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildEnhancedPatternDropdown(viewModel),
            const SizedBox(height: 24),
            _buildEnhancedSlider(
              "Intensity",
              Icons.brightness_7,
              Colors.yellow,
              _valueToPercentage(viewModel.intensityValue),
              (percentage) => setState(() {
                viewModel.intensityValue = _percentageToValue(percentage);
              }),
              () => viewModel.processPacketInformation(controlPacket: true),
            ),
            const SizedBox(height: 16),
            _buildEnhancedSlider(
              "Rate",
              Icons.speed,
              Colors.blue,
              _valueToPercentage(viewModel.rateValue),
              (percentage) => setState(() {
                viewModel.rateValue = _percentageToValue(percentage);
              }),
              () => viewModel.processPacketInformation(controlPacket: true),
            ),
            const SizedBox(height: 16),
            _buildEnhancedSlider(
              "Level",
              Icons.equalizer,
              Colors.green,
              _valueToPercentage(viewModel.levelValue),
              (percentage) => setState(() {
                viewModel.levelValue = _percentageToValue(percentage);
              }),
              () => viewModel.processPacketInformation(controlPacket: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPatternDropdown(PixelLightsViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.pattern,
              color: Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Pattern',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Pattern>(
              value: viewModel.patternValue,
              dropdownColor: Colors.black.withValues(alpha: 0.95),
              elevation: 12,
              borderRadius: BorderRadius.circular(12),
              onChanged: (Pattern? newValue) {
                if (newValue != null) {
                  setState(() {
                    viewModel.patternValue = newValue;
                  });
                  viewModel.processPacketInformation(controlPacket: false);
                  viewModel.usePattern(newValue.name);
                }
              },
              items: Pattern.values.map<DropdownMenuItem<Pattern>>((Pattern value) {
                return DropdownMenuItem<Pattern>(
                  value: value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        _getPatternIcon(value.name),
                        const SizedBox(width: 12),
                        Text(
                          value.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              selectedItemBuilder: (BuildContext context) {
                return Pattern.values.map<Widget>((Pattern value) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _getPatternIcon(value.name),
                        const SizedBox(width: 12),
                        Text(
                          value.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              isExpanded: true,
              icon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _getPatternIcon(String patternName) {
    switch (patternName.toLowerCase()) {
      case 'solid':
        return Icon(Icons.circle, size: 18, color: Colors.amber.withValues(alpha: 0.8));
      case 'gradient':
        return Icon(Icons.gradient, size: 18, color: Colors.purple.withValues(alpha: 0.8));
      case 'rainbow':
        return Icon(Icons.color_lens, size: 18, color: Colors.red.withValues(alpha: 0.8));
      case 'strobe':
        return Icon(Icons.flash_on, size: 18, color: Colors.yellow.withValues(alpha: 0.8));
      case 'march':
        return Icon(Icons.trending_up, size: 18, color: Colors.blue.withValues(alpha: 0.8));
      case 'wipe':
        return Icon(Icons.cleaning_services, size: 18, color: Colors.cyan.withValues(alpha: 0.8));
      case 'twinkle':
      case 'minitwinkle':
        return Icon(Icons.star, size: 18, color: Colors.pink.withValues(alpha: 0.8));
      case 'sparkle':
      case 'minisparkle':
        return Icon(Icons.auto_awesome, size: 18, color: Colors.orange.withValues(alpha: 0.8));
      case 'candycane':
        return Icon(Icons.cake, size: 18, color: Colors.red.withValues(alpha: 0.8));
      case 'flash':
        return Icon(Icons.flash_auto, size: 18, color: Colors.white.withValues(alpha: 0.8));
      case 'fixed':
        return Icon(Icons.lock, size: 18, color: Colors.grey.withValues(alpha: 0.8));
      default:
        return Icon(Icons.lightbulb_outline, size: 18, color: Colors.white.withValues(alpha: 0.6));
    }
  }

  Widget _buildEnhancedSlider(
    String title,
    IconData icon,
    Color accentColor,
    double percentage,
    Function(double) onPercentageChanged,
    Function() onSliderEnd,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: accentColor.withValues(alpha: 0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${percentage.round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6,
            thumbShape: RoundSliderThumbShape(
              enabledThumbRadius: 12,
            ),
            overlayShape: RoundSliderOverlayShape(
              overlayRadius: 20,
            ),
            thumbColor: accentColor,
            activeTrackColor: accentColor.withValues(alpha: 0.8),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            overlayColor: accentColor.withValues(alpha: 0.3),
          ),
          child: Slider(
            min: 0,
            max: 100,
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
          ),
        ),
      ],
    );
  }

}
