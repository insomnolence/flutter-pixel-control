import 'package:flutter/material.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/screens/bluetooth_screen.dart';
import 'package:pixel_lights/screens/manual_screen.dart';
import 'package:pixel_lights/screens/presets_screen.dart';
import 'package:pixel_lights/services/bluetooth_services.dart';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:pixel_lights/widgets/styled_snack_bar.dart';
import 'package:provider/provider.dart';

// Smart PageView that can disable scrolling for protected gesture zones
class SmartGesturePageView extends StatefulWidget {
  final List<Widget> children;
  final PageController controller;
  final Function(int)? onPageChanged;
  final List<GlobalKey> protectedZoneKeys;
  
  const SmartGesturePageView({
    super.key,
    required this.children,
    required this.controller,
    this.onPageChanged,
    this.protectedZoneKeys = const [],
  });

  @override
  State<SmartGesturePageView> createState() => _SmartGesturePageViewState();
}

class _SmartGesturePageViewState extends State<SmartGesturePageView> {
  final ValueNotifier<bool> _scrollEnabled = ValueNotifier<bool>(true);
  bool _isCurrentlyInProtectedZone = false;
  
  bool _isPointInProtectedZone(Offset globalPoint) {
    for (final key in widget.protectedZoneKeys) {
      final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final localPoint = renderBox.globalToLocal(globalPoint);
        final size = renderBox.size;
        
        // Minimal padding - only protect the actual color wheel, not the whole card
        const padding = 5.0;
        if (localPoint.dx >= -padding && localPoint.dx <= size.width + padding &&
            localPoint.dy >= -padding && localPoint.dy <= size.height + padding) {
          return true;
        }
      }
    }
    return false;
  }
  
  void _updateScrollState(bool inProtectedZone) {
    _isCurrentlyInProtectedZone = inProtectedZone;
    _scrollEnabled.value = !inProtectedZone;
  }
  
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        // Immediately check and disable on pointer down
        final isInProtectedZone = _isPointInProtectedZone(event.position);
        _updateScrollState(isInProtectedZone);
      },
      onPointerMove: (event) {
        // Double-check during movement for quick gestures
        if (!_isCurrentlyInProtectedZone) {
          final isInProtectedZone = _isPointInProtectedZone(event.position);
          if (isInProtectedZone) {
            _updateScrollState(true);
          }
        }
      },
      onPointerUp: (event) {
        // Re-enable scrolling when touch ends
        _updateScrollState(false);
      },
      onPointerCancel: (event) {
        // Re-enable scrolling if touch is cancelled
        _updateScrollState(false);
      },
      child: GestureDetector(
        // Add aggressive gesture blocking for protected zones
        onPanStart: (details) {
          final isInProtectedZone = _isPointInProtectedZone(details.globalPosition);
          if (isInProtectedZone) {
            _updateScrollState(true);
          }
        },
        behavior: HitTestBehavior.translucent,
        child: ValueListenableBuilder<bool>(
          valueListenable: _scrollEnabled,
          builder: (context, isEnabled, child) {
            return PageView(
              controller: widget.controller,
              onPageChanged: widget.onPageChanged,
              physics: isEnabled ? null : const NeverScrollableScrollPhysics(),
              children: widget.children,
            );
          },
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollEnabled.dispose();
    super.dispose();
  }
}

void main() {
  runApp(const PixelLightsApp()); // No more ProviderScope
}

class PixelLightsApp extends StatelessWidget {
  const PixelLightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PixelLightsViewModel>(
      // ChangeNotifierProvider at the top
      create:
          (context) =>
              PixelLightsViewModel(bluetoothService: PixelBluetoothService()),
      child: MaterialApp(
        title: 'Pixel Lights',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  final GlobalKey _colorPickerKey = GlobalKey();

  List<Widget> _widgetOptions() => <Widget>[
    const PresetsScreen(),
    BackgroundMesh(child: ManualScreen(colorPickerKey: _colorPickerKey)),
    const BackgroundMesh(child: BluetoothScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Set up write error callback after first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<PixelLightsViewModel>();
      viewModel.onWriteError = _showWriteErrorSnackBar;
    });
  }

  void _showWriteErrorSnackBar(String message) {
    if (!mounted) return;
    showStyledSnackBar(
      context,
      message: message,
      icon: Icons.error_outline,
      backgroundColor: Colors.red[700],
    );
  }

  @override
  void dispose() {
    // Clear the callback before disposing
    final viewModel = context.read<PixelLightsViewModel>();
    viewModel.onWriteError = null;
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildConnectionStatus(PixelLightsViewModel viewModel) {
    final isConnected = viewModel.bluetoothDevice != null && viewModel.txCharacteristic != null;
    
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              color: isConnected ? Colors.green : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Pixel Lights'),
            backgroundColor: const Color(0xFF121212),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
            actions: [
              _buildConnectionStatus(viewModel),
            ],
          ),
          body: SmartGesturePageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            protectedZoneKeys: [_colorPickerKey],
            children: _widgetOptions(),
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_input_component),
                label: 'Presets',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.palette),
                label: 'Manual',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bluetooth),
                label: 'Bluetooth',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF121212), // Dark gray background
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey[600],
          ),
        );
      },
    );
  }
}
