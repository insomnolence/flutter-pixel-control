import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/models/patterns.dart';
import 'package:pixel_lights/screens/background.dart';
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child:
                  patterns.isEmpty
                      ? const SizedBox()
                      : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 40.0,
                              mainAxisSpacing: 40.0,
                              childAspectRatio: 1.0, // Make the buttons square
                            ),
                        itemBuilder: (context, index) {
                          final patternName = patterns.keys.elementAt(index);
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
                          );
                        },
                        itemCount: patterns.length,
                      ),
            ),
          ),
        );
      },
    );
  }
}

// Button Widget:
class PresetButton extends StatelessWidget {
  final String patternName;
  final String? imagePath;
  final VoidCallback onPressed;
  final List<Color> gradientColors;

  const PresetButton({
    super.key,
    required this.patternName,
    required this.imagePath,
    required this.onPressed,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16.0),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.all(10.0), // Increased padding
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 20, // Set to 60 for a square
                maxWidth: 50,
                minHeight: 20, // Set to 60 for a square
                maxHeight: 50, //increased size.
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imagePath != null)
                    Padding(
                      padding: const EdgeInsets.all(4.0), // Increased padding
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: SizedBox(
                          width: 40, // Set to 40 for a square
                          height: 40, // Set to 40 for a square
                          child: Image.asset(imagePath!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  const SizedBox(height: 2.0),
                  Text(
                    patternName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16, // Increased font size
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
