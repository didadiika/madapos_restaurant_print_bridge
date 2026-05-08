import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';

import '../models/printer_model.dart';
import 'printer_storage_service.dart';

class PrintService {

  static Future<void> printReceipt(dynamic data, PrinterModel printer) async {

    try {

      
      // =========================
      // PAPER SIZE
      // =========================

      PaperSize paperSize =
          printer.paper == '58'
              ? PaperSize.mm58
              : PaperSize.mm80;

      final profile =
          await CapabilityProfile.load();

      final generator = Generator(
        paperSize,
        profile,
      );

      List<int> bytes = [];

      // =========================
      // STORE
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

      bytes += generator.text(
        "Invoice : ${data['receipt']['sale_uid']}",
      );

      bytes += generator.hr();

      // =========================
      // CARTS
      // =========================

      final carts = data['carts'];

      carts.forEach((key, item) {

        final name =
            item['product']['name'];

        final qty =
            item['qty'];

        final subtotal =
            item['sub_total'];

        bytes += generator.text(
          "$name x$qty",
        );

        bytes += generator.text(

          subtotal.toString(),

          styles: const PosStyles(
            align: PosAlign.right,
          ),

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

      await PrintBluetoothThermal.writeBytes(
        bytes,
      );

    } catch (e) {

      debugPrint(e.toString());

    }

  }



  static Future<void> printTest(PrinterModel printer,) async {

    try {
      PaperSize paperSize =
          printer.paper == '58'
              ? PaperSize.mm58
              : PaperSize.mm80;

      final profile = await CapabilityProfile.load();

      final generator = Generator(
        paperSize,
        profile,
      );

      List<int> bytes = [];

      bytes += generator.text(

        "Berhasil terhubung\nke Printer via Bluetooth",

        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),

      );

      bytes += generator.emptyLines(1);

      bytes += generator.text(

        printer.address,

        styles: const PosStyles(
          align: PosAlign.center,
        ),

      );

      bytes += generator.feed(3);

      // AUTO CUT
      if (printer.autoCut) {

        bytes += generator.cut();

      }

      // CASH DRAWER
      if (printer.cashDrawer) {

        bytes += generator.drawer();

      }

      await PrintBluetoothThermal.writeBytes(
        bytes,
      );

    } catch (e) {

      debugPrint(e.toString());

    }

  }
}