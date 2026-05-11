import 'package:flutter/material.dart';

class BluetoothPrinterPage extends StatelessWidget {
  const BluetoothPrinterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Printer Bluetooth')),
      body: const Center(
        child: Text('Gunakan halaman Bluetooth yang sudah ada.'),
      ),
    );
  }
}