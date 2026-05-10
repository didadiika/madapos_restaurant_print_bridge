import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class BluetoothService {
  // =============== (1) REQUEST PERMISSIONS ================
  static Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }
  // =============== (1) END REQUEST PERMISSIONS ================

  // =============== (2) CHECK BLUETOOTH STATUS ================
  static Future<bool> isBluetoothEnabled() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }
  // =============== (2) END CHECK BLUETOOTH STATUS ================

  // =============== (3) SCAN DEVICES ================
  static Future<List<BluetoothInfo>> scanDevices() async {
    final enabled = await isBluetoothEnabled();

    if (!enabled) {
      throw Exception('Bluetooth tidak aktif');
    }

    return await PrintBluetoothThermal.pairedBluetooths;
  }
  // =============== (3) END SCAN DEVICES ================

  // =============== (4) CONNECT TO PRINTER ================
  static Future<bool> connect(String macAddress) async {
    // Putuskan koneksi lama
    try {
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}

    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }
  // =============== (4) END CONNECT TO PRINTER ================

  // =============== (5) DISCONNECT FROM PRINTER ================
  static Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (_) {}
  }

  // =============== (5) END DISCONNECT FROM PRINTER ================
}
