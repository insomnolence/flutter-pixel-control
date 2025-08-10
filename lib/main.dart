import 'package:flutter/material.dart';
import 'package:pixel_lights/screens/background.dart';
import 'package:pixel_lights/screens/bluetooth_screen.dart';
import 'package:pixel_lights/screens/manual_screen.dart';
import 'package:pixel_lights/screens/presets_screen.dart';
import 'package:pixel_lights/services/bluetooth_services.dart';
import 'package:pixel_lights/view_models/pixel_lights_view_model.dart';
import 'package:provider/provider.dart';

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

  static List<Widget> _widgetOptions() => <Widget>[
    const PresetsScreen(),
    const BackgroundMesh(child: ManualScreen()),
    const BackgroundMesh(child: BluetoothScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
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
            actions: [
              _buildConnectionStatus(viewModel),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
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
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
          ),
        );
      },
    );
  }
}
