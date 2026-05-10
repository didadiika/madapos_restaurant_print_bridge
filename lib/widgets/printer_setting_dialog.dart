import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../constants/printer_connection.dart';
import '../models/printer_model.dart';

class PrinterSettingDialog extends StatefulWidget {
  final BluetoothInfo device;
  final PrinterModel? existingPrinter;
  final Function(PrinterModel printer) onSave;

  const PrinterSettingDialog({
    super.key,
    required this.device,
    required this.onSave,
    this.existingPrinter,
  });

  @override
  State<PrinterSettingDialog> createState() => _PrinterSettingDialogState();
}

class _PrinterSettingDialogState extends State<PrinterSettingDialog> {
  late TextEditingController nameController;
  late String selectedPaper;
  late bool cashDrawer;
  late bool autoCut;

  @override
  void initState() {
    super.initState();

    final printer = widget.existingPrinter;

    nameController = TextEditingController(
      text: printer?.name ?? widget.device.name,
    );

    selectedPaper = printer?.paper ?? '80';
    cashDrawer = printer?.cashDrawer ?? true;
    autoCut = printer?.autoCut ?? true;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  void save() {
    final printer = PrinterModel(
      name: nameController.text.trim().isEmpty
          ? widget.device.name
          : nameController.text.trim(),
      connection: PrinterConnection.bluetooth,
      address: widget.device.macAdress,
      paper: selectedPaper,
      cashDrawer: cashDrawer,
      autoCut: autoCut,
    );

    widget.onSave(printer);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setting Printer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Printer',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Paper Size',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            RadioListTile<String>(
              title: const Text('58mm'),
              value: '58',
              groupValue: selectedPaper,
              onChanged: (value) {
                setState(() {
                  selectedPaper = value!;
                });
              },
            ),

            RadioListTile<String>(
              title: const Text('80mm'),
              value: '80',
              groupValue: selectedPaper,
              onChanged: (value) {
                setState(() {
                  selectedPaper = value!;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Open Cash Drawer'),
              value: cashDrawer,
              onChanged: (value) {
                setState(() {
                  cashDrawer = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('Auto Cut'),
              value: autoCut,
              onChanged: (value) {
                setState(() {
                  autoCut = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
