// lib/widgets/ethernet_printer_dialog.dart

import 'package:flutter/material.dart';

import '../constants/printer_connection.dart';
import '../models/printer_model.dart';

class EthernetPrinterDialog extends StatefulWidget {
  final PrinterModel? existingPrinter;
  final Function(PrinterModel printer)? onSave;

  const EthernetPrinterDialog({
    super.key,
    this.existingPrinter,
    this.onSave,
  });

  @override
  State<EthernetPrinterDialog> createState() =>
      _EthernetPrinterDialogState();
}

class _EthernetPrinterDialogState
    extends State<EthernetPrinterDialog> {
  late TextEditingController nameController;
  late TextEditingController ipController;
  late TextEditingController portController;

  late String selectedPaper;
  late bool cashDrawer;
  late bool autoCut;
  late bool beep;

  @override
  void initState() {
    super.initState();

    final printer = widget.existingPrinter;

    nameController = TextEditingController(
      text: printer?.name ?? '',
    );

    ipController = TextEditingController(
      text: printer?.address ?? '',
    );

    portController = TextEditingController(
      text: (printer?.port ?? 9100).toString(),
    );

    // Setting sama seperti PrinterSettingDialog
    selectedPaper = printer?.paper ?? '80';
    cashDrawer = printer?.cashDrawer ?? true;
    autoCut = printer?.autoCut ?? true;
    beep = printer?.beep ?? false;
  }

  @override
  void dispose() {
    nameController.dispose();
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  void _save() {
    final name = nameController.text.trim();
    final ip = ipController.text.trim();
    final port =
        int.tryParse(portController.text.trim()) ?? 9100;

    if (name.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nama printer dan IP wajib diisi',
          ),
        ),
      );
      return;
    }

    final printer = PrinterModel(
      name: name,
      connection: PrinterConnection.network,
      address: ip,
      port: port,
      paper: selectedPaper,
      cashDrawer: cashDrawer,
      autoCut: autoCut,
      beep: beep,
    );

    // Jika memakai callback
    if (widget.onSave != null) {
      widget.onSave!(printer);
      Navigator.pop(context);
      return;
    }

    // Jika memakai result dialog
    Navigator.pop(context, printer);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit =
        widget.existingPrinter != null;

    return AlertDialog(
      title: Text(
        isEdit
            ? 'Edit Printer Ethernet'
            : 'Tambah Printer Ethernet',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Nama Printer
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Printer',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // IP Address
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Port
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Paper Size
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Paper Size',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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

            // Open Cash Drawer
            SwitchListTile(
              title: const Text('Open Cash Drawer'),
              value: cashDrawer,
              onChanged: (value) {
                setState(() {
                  cashDrawer = value;
                });
              },
            ),

            // Auto Cut
            SwitchListTile(
              title: const Text('Auto Cut'),
              value: autoCut,
              onChanged: (value) {
                setState(() {
                  autoCut = value;
                });
              },
            ),

            // Beep
            SwitchListTile(
              title: const Text('Beep'),
              subtitle: const Text(
                'Bunyikan buzzer setelah print selesai',
              ),
              value: beep,
              onChanged: (value) {
                setState(() {
                  beep = value;
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
        ElevatedButton(
          onPressed: _save,
          child: Text(
            isEdit ? 'Update' : 'Save',
          ),
        ),
      ],
    );
  }
}