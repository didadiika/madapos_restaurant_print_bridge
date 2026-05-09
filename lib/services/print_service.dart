import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../models/printer_model.dart';
import 'printer_storage_service.dart';

class PrintService {
  static Future<void> printReceipt(dynamic data, PrinterModel printer) async {
    try {
      PaperSize paperSize = printer.paper == '58'
          ? PaperSize.mm58
          : PaperSize.mm80;

      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);

      List<int> bytes = [];

      // =========================
      // Ambil data nama toko dari payload
      // =========================
      bytes += generator.text(
        data['store']['name'],
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.emptyLines(1);

      // =========================
      // INVOICE
      // =========================
      bytes += generator.text("Invoice : ${data['receipt']['sale_uid']}");
      bytes += generator.hr();

      // =========================
      // CARTS
      // =========================

      final carts = data['carts'];

      carts.forEach((key, item) {
        final name = item['product']['name'];
        final qty = item['qty'];
        final subtotal = item['sub_total'];
        bytes += generator.text("$name x$qty");
        bytes += generator.text(
          subtotal.toString(),
          styles: const PosStyles(align: PosAlign.right),
        );
      });
      bytes += generator.hr();

      // =========================
      // TOTAL
      // =========================

      bytes += generator.text(
        "TOTAL : ${data['receipt']['grand_total']}",

        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.feed(3);
      if (printer.autoCut) {
        bytes += generator.cut();
      }

      // =========================
      // CASH DRAWER
      // =========================

      if (printer.cashDrawer) {
        bytes += generator.drawer();
      }

      // =========================
      // PRINT
      // =========================

      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // =========================
  // PRINT TEST
  // =========================
  static Future<void> printTest(PrinterModel printer) async {
    try {
      PaperSize paperSize = printer.paper == '58'
          ? PaperSize.mm58
          : PaperSize.mm80;

      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
            
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.hr();
      bytes += generator.feed(1);

      final ByteData dataLogo = await rootBundle.load(
        'assets/images/store-logo.png',
      );
      final Uint8List bytesLogo = dataLogo.buffer.asUint8List();
      final img.Image? imageLogo = img.decodeImage(bytesLogo);
      if (imageLogo != null) {
        final resized = img.copyResize(imageLogo, width: 200);
        bytes += generator.image(resized, align: PosAlign.center);
        bytes += generator.feed(1);
      }
      bytes += generator.text(
        "TEST PRINT",
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(1);
      bytes += generator.text(
        "Berhasil terhubung\nke Printer via Bluetooth",
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.emptyLines(1);
      bytes += generator.text(
        printer.address,
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(3);

      final ByteData dataFooter = await rootBundle.load('assets/images/footer.png');
      final Uint8List bytesImageFooter = dataFooter.buffer.asUint8List();
      final img.Image? imageFooter = img.decodeImage(bytesImageFooter);
      if (imageFooter != null) {
        final resizedFooter = img.copyResize(imageFooter, width: 200);
        bytes += generator.image(resizedFooter, align: PosAlign.center);
        bytes += generator.feed(1);
      }

      // AUTO CUT
      if (printer.autoCut) {
        bytes += generator.cut();
      }

      // CASH DRAWER
      if (printer.cashDrawer) {
        bytes += generator.drawer();
      }
      bytes += generator.reset();

      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // =========================
  // PRINT TEST
  // =========================
}
