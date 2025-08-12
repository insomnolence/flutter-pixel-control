import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/models/patterns.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/widgets/styled_snack_bar.dart';
import 'package:provider/provider.dart';

// --- Preset Screen ---
class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  Map<String, String> presetImages = {};

  @override
  void initState() {
    super.initState();
    loadPresetImages();
  }

  void usePattern(String patternName, PixelLightsViewModel viewModel) {
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();
    viewModel.usePattern(patternName);
  }

  Future<void> loadPresetImages() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    List<String> imagePaths = [];
    for (String key in manifestMap.keys) {
      if (key.startsWith('assets/images/')) {
        imagePaths.add(key);
      }
    }
    Map<String, String> loadedImages = {};
    for (String imagePath in imagePaths) {
      String imageName = imagePath.split('/').last.split('.').first;
      loadedImages[imageName] = imagePath;
    }
    setState(() {
      presetImages = loadedImages;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      builder: (context, viewModel, child) {
        return BackgroundMesh(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: viewModel.orderedPatterns.isEmpty
                ? const SizedBox()
                : Card(
                    elevation: 8,
                    margin: EdgeInsets.zero,
                    color: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          Expanded(child: _buildPresetsGrid(viewModel)),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.auto_awesome,
          color: Colors.white.withOpacity(0.9),
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          'PRESETS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPresetsGrid(PixelLightsViewModel viewModel) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final patternName = viewModel.orderedPatterns[index];
        final List<Color> gradientColors =
            patternGradients[patternName] ??
            [Colors.grey, Colors.black];
        final presetImage = presetImages[patternName];

        return PresetButton(
          patternName: patternName,
          imagePath: presetImage,
          onPressed: () {
            usePattern(patternName, viewModel);
          },
          gradientColors: gradientColors,
          viewModel: viewModel,
        );
      },
      itemCount: viewModel.orderedPatterns.length,
    );
  }
}

// Button Widget:
class PresetButton extends StatefulWidget {
  final String patternName;
  final String? imagePath;
  final VoidCallback onPressed;
  final List<Color> gradientColors;
  final PixelLightsViewModel viewModel;

  const PresetButton({
    super.key,
    required this.patternName,
    required this.imagePath,
    required this.onPressed,
    required this.gradientColors,
    required this.viewModel,
  });

  @override
  State<PresetButton> createState() => _PresetButtonState();
}

class _PresetButtonState extends State<PresetButton> {

  @override
  Widget build(BuildContext context) {
    final isActive = widget.viewModel.isPatternActive(widget.patternName);
    final isBluetoothConnected = widget.viewModel.bluetoothDevice != null; // Explicitly declare here

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.0),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.0),
          border: isActive
              ? Border.all(color: Colors.white, width: 3.0)
              : Border.all(color: Colors.transparent, width: 3.0),
        ),
        child: Opacity( // Apply opacity for visual disabled state
          opacity: isBluetoothConnected ? 1.0 : 0.5,
          child: InkWell(
            onTap: isBluetoothConnected // Only enable tap if connected
                ? widget.onPressed
                : () {
                    showStyledSnackBar(
                      context,
                      message: 'Bluetooth not connected. Please connect to a device first.',
                      icon: Icons.bluetooth_disabled,
                      backgroundColor: Colors.red,
                    );
                  },
            borderRadius: BorderRadius.circular(16.0),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.imagePath != null)
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Image.asset(widget.imagePath!,
                                fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    const SizedBox(height: 2.0),
                    Text(
                      widget.patternName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
