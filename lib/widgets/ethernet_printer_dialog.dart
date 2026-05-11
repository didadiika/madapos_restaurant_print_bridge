// lib/widgets/ethernet_printer_dialog.dart
// Pastikan constructor EthernetPrinterDialog mendukung parameter existingPrinter.

import 'package:flutter/material.dart';
import '../constants/printer_connection.dart';
import '../models/printer_model.dart';

class EthernetPrinterDialog extends StatefulWidget {
  final PrinterModel? existingPrinter;

  const EthernetPrinterDialog({
    super.key,
    this.existingPrinter,
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
      paper:
          widget.existingPrinter?.paper ?? '80',
      cashDrawer:
          widget.existingPrinter?.cashDrawer ??
              false,
      autoCut:
          widget.existingPrinter?.autoCut ?? true,
    );

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
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Printer',
              ),
            ),
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
              ),
            ),
            TextField(
              controller: portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(
            isEdit ? 'Update' : 'Simpan',
          ),
        ),
      ],
    );
  }
}