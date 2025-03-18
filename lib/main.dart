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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions() => <Widget>[
    const PresetsScreen(),
    const BackgroundMesh(child: ManualScreen()),
    const BackgroundMesh(child: BluetoothScreen()),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PixelLightsViewModel>(
      // Consumer here
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pixel Lights')),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.blue),
                  child: Text(
                    'Pixel Lights',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_input_component),
                  title: const Text('Presets'),
                  selected: _selectedIndex == 0,
                  onTap: () {
                    _onItemTapped(0);
                    Navigator.pop(context); // Close the drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text('Manual Control'),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    _onItemTapped(1);
                    Navigator.pop(context); // Close the drawer
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('Bluetooth'),
                  selected: _selectedIndex == 2,
                  onTap: () {
                    _onItemTapped(2);
                    Navigator.pop(context); // Close the drawer
                  },
                ),
              ],
            ),
          ),
          body: Center(child: _widgetOptions().elementAt(_selectedIndex)),
        );
      },
    );
  }
}
