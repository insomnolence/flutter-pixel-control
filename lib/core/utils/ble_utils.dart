/// BLE-related utility functions

library;

/// Convert RSSI (signal strength) to a percentage value
/// RSSI typically ranges from -100 (weak) to -50 (strong)
/// Returns 0-100 percentage
double rssiToPercentage(int rssi) {
  if (rssi >= -50) return 100;
  if (rssi <= -100) return 0;
  return ((rssi + 100) * 2).toDouble();
}
