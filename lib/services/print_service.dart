import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

import '../models/printer_model.dart';
import 'printer_storage_service.dart';

class PrintService {
  static Future<void> printReceipt(dynamic data, PrinterModel printer) async {
  try {
    // =========================================================
    // SETUP
    // =========================================================
    final paperSize =
        printer.paper == '58' ? PaperSize.mm58 : PaperSize.mm80;

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);

    List<int> bytes = [];

    // =========================================================
    // HELPERS
    // =========================================================
    String safe(dynamic value) => value?.toString() ?? '';

    String formatCurrency(dynamic value) {
      final number = double.tryParse(value.toString()) ?? 0;
      final intValue = number.round();

      final chars = intValue.toString().split('').reversed.toList();
      final buffer = StringBuffer();

      for (int i = 0; i < chars.length; i++) {
        if (i > 0 && i % 3 == 0) buffer.write('.');
        buffer.write(chars[i]);
      }

      return buffer.toString().split('').reversed.join();
    }

    // =========================================================
    // PARSE DATA
    // =========================================================
    final store = data['store'] ?? {};
    final receipt = data['receipt'] ?? {};
    final desks = data['desks'] ?? {};
    final carts = data['carts'] ?? {};
    final printSetting = data['print_setting'] ?? {};

    // Kasir
    final cashier = receipt['cashier'] ?? {};

    // =========================================================
    // HEADER TOKO
    // =========================================================
    bytes += generator.text(
      safe(store['name']),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      '${safe(store['address'])}',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      safe(store['city']),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      safe(store['phone']),
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.emptyLines(1);

    // =========================================================
    // NOMOR MEJA / DINE TYPE
    // =========================================================
    //
    // JSON Take Away:
    // - Tidak memiliki key "desks"
    // - receipt.dine_type = "Take Away"
    // - receipt.dine_uid  = "TA"
    //
    // JSON Dine In:
    // - Memiliki key "desks"
    // - desks.numb_desk = 3
    // - desks.area = "Lantai 1"

    final dineType = safe(receipt['dine_type']);
    final dineUid = safe(receipt['dine_uid']);

    // Cek apakah desks benar-benar berisi data
    final hasDesk = desks is Map &&
        safe(desks['numb_desk']).isNotEmpty;
    
    // =========================
    // DINE IN
    // =========================
    if (hasDesk) {
      bytes += generator.text(
        '#${safe(desks['numb_desk'])}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size3,
          width: PosTextSize.size3,
        ),
      );

      if (safe(desks['area']).isNotEmpty) {
        bytes += generator.text(
          safe(desks['area']),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
      }
    }

    // =========================
    // TAKE AWAY / DELIVERY / DLL
    // =========================
    else {
      // Prioritas:
      // 1. dine_type => "Take Away"
      // 2. dine_uid  => "TA"
      // 3. default   => "Take Away"

      final label = dineType.isNotEmpty
          ? dineType
          : (dineUid.isNotEmpty ? dineUid : 'Take Away');

      bytes += generator.text(
        '#$label',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size3,
          width: PosTextSize.size3,
        ),
      );
    }

    bytes += generator.hr(ch: '=');

    // =========================================================
    // BARCODE SALE UID
    // =========================================================
    final saleUid = safe(receipt['sale_uid']);

    if (saleUid.isNotEmpty) {
      try {
        // esc_pos_utils_plus membutuhkan List<int>, bukan String
        bytes += generator.barcode(
          Barcode.code128(saleUid.codeUnits),
          width: 2,
          height: 60,
          font: BarcodeFont.fontA,
        );
      } catch (e) {
        debugPrint('Barcode error: $e');
      }

      bytes += generator.emptyLines(1);
    }

    // =========================================================
    // INFO TRANSAKSI
    // =========================================================
    bytes += generator.text(
      'UID'.padRight(10) + ': $saleUid',
    );

    bytes += generator.text(
      'Pelanggan'.padRight(10) +
          ': ${safe(receipt['customer_name'])}',
    );

    bytes += generator.text(
      'Tanggal'.padRight(10) +
          ': ${safe(receipt['date'])}',
    );

    bytes += generator.text(
      'Kasir'.padRight(10) +
          ': ${safe(cashier['name'])}',
    );

    bytes += generator.hr();

    // =========================================================
    // HEADER ITEM
    // =========================================================
    bytes += generator.row([
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Item',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Sub Total',
        width: 4,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.hr();

    // =========================================================
    // ITEMS
    // =========================================================
    final Iterable<dynamic> cartItems =
    carts is Map ? carts.values : (carts as List);

    for (final item in cartItems) {
      final qty = item['qty'] ?? 0;
      final name = safe(item['product']?['name']);
      final note = safe(item['note']);
      final price = item['price_after_disc'] ?? 0;
      final subtotal = item['sub_total'] ?? 0;

      // -------------------------
      // Baris 1: Qty + Nama Item
      // -------------------------
      bytes += generator.row([
        PosColumn(
          text: qty.toString(),
          width: 2,
        ),
        PosColumn(
          text: name,
          width: 10,
        ),
      ]);

      // -------------------------
      // Baris 2: Note
      // -------------------------
      if (note.isNotEmpty) {
        bytes += generator.row([
          PosColumn(
            text: '',
            width: 2,
          ),
          PosColumn(
            text: '*$note',
            width: 10,
          ),
        ]);
      }

      // -------------------------
      // Baris 3: Harga + Subtotal
      // -------------------------
      bytes += generator.row([
        PosColumn(
          text: '',
          width: 2,
        ),
        PosColumn(
          text: formatCurrency(price),
          width: 6,
        ),
        PosColumn(
          text: formatCurrency(subtotal),
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right,
          ),
        ),
      ]);
    }

    bytes += generator.hr();

    // =========================================================
    // SUMMARY
    // =========================================================
    final disc = receipt['disc_number'] ?? 0;
    final total = receipt['grand_total'] ?? 0;
    final paid = receipt['paid'] ?? data['paid'] ?? 0;
    final changed = receipt['changed'] ?? 0;
    final payment = safe(data['payments']);

    // DISC
    if ((double.tryParse(disc.toString()) ?? 0) > 0) {
      bytes += generator.row([
        PosColumn(text: 'DISC', width: 8),
        PosColumn(
          text: formatCurrency(disc),
          width: 4,
          styles: const PosStyles(
            align: PosAlign.right,
          ),
        ),
      ]);
    }

    // TOTAL
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: formatCurrency(total),
        width: 4,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);

    // BAYAR
    bytes += generator.row([
      PosColumn(text: 'BAYAR', width: 8),
      PosColumn(
        text: formatCurrency(paid),
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      ),
    ]);

    // KEMBALI
    bytes += generator.row([
      PosColumn(text: 'KEMBALI', width: 8),
      PosColumn(
        text: formatCurrency(changed),
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      ),
    ]);

    // PAYMENT
    bytes += generator.row([
      PosColumn(text: 'PAYMENT', width: 8),
      PosColumn(
        text: payment,
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.hr(ch: '=');

    // =========================================================
    // FOOTER INFO
    // =========================================================
    final footerInfo =
        safe(printSetting['printer_cashier_footer_info']);

    if (footerInfo.isNotEmpty) {
      final lines = footerInfo.split('\n');

      for (final line in lines) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(
            line.trim(),
            styles: const PosStyles(
              align: PosAlign.left,
            ),
          );
        }
      }
    }

    bytes += generator.emptyLines(1);

    // TERIMA KASIH
    bytes += generator.text(
      'TERIMA KASIH',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    final ByteData dataFooter = await rootBundle.load('assets/images/footer.png');
    final Uint8List bytesImageFooter = dataFooter.buffer.asUint8List();
    final img.Image? imageFooter = img.decodeImage(bytesImageFooter);
    if (imageFooter != null) {
      final resizedFooter = img.copyResize(imageFooter, width: 200);
      bytes += generator.image(resizedFooter, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    bytes += generator.feed(1);

    // =========================================================
    // CUT PAPER
    // =========================================================
    if (printer.autoCut) {
      bytes += generator.cut();
    }

    // =========================================================
    // OPEN CASH DRAWER
    // =========================================================
    if (printer.cashDrawer) {
      bytes += generator.drawer();
    }

    // =========================================================
    // PRINT
    // =========================================================
    await PrintBluetoothThermal.writeBytes(bytes);
  } catch (e) {
    debugPrint('Print error: $e');
    rethrow;
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

      final ByteData dataLogo = await rootBundle.load('assets/images/store-default.png');
      final Uint8List bytesLogo = dataLogo.buffer.asUint8List();
      final img.Image? imageLogo = img.decodeImage(bytesLogo);
      if (imageLogo != null) {
        final resizedLogo = img.copyResize(imageLogo, height: 175);
        bytes += generator.image(resizedLogo, align: PosAlign.center);
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
