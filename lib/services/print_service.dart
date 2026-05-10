import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/printer_model.dart';

class PrintService {
  // =========================================================
  // PUBLIC METHODS
  // =========================================================

  static Future<void> printTest(PrinterModel printer) async {
    final bytes = await _buildTestBytes(printer);
    await _sendToPrinter(bytes);
  }

  static Future<void> printReceipt(
    dynamic data,
    PrinterModel printer,
  ) async {
    final bytes = await _buildReceiptBytes(data, printer);
    await _sendToPrinter(bytes);
  }

  static Future<void> printOrder(
    dynamic data,
    PrinterModel printer,
  ) async {
    final bytes = await _buildOrderBytes(data, printer);
    await _sendToPrinter(bytes);
  }

  static Future<void> pushDrawer(PrinterModel printer) async {
    final bytes = await _buildDrawerBytes(printer);
    await _sendToPrinter(bytes);
  }

  // =========================================================
  // CORE SEND METHOD
  // =========================================================

  static Future<void> _sendToPrinter(List<int> bytes) async {
    try {
      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('Print error: $e');
      rethrow;
    }
  }

  // =========================================================
  // BYTE BUILDERS
  // =========================================================

  static Future<List<int>> _buildTestBytes(
    PrinterModel printer,
  ) async {
    final generator = await _createGenerator(printer);

    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.hr();
    bytes += generator.feed(1);

    // Logo
    final logo = await _loadAssetImage(
      'assets/images/store-default.png',
      height: 175,
    );
    if (logo != null) {
      bytes += generator.image(logo, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    bytes += generator.text(
      'TEST PRINT',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);

    bytes += generator.text(
      'Berhasil terhubung\nke Printer via Bluetooth',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.emptyLines(1);

    bytes += generator.text(
      printer.address,
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);

    // Footer image
    final footer = await _loadAssetImage(
      'assets/images/footer.png',
      width: 200,
    );
    if (footer != null) {
      bytes += generator.image(footer, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    bytes += _finalize(generator, printer);

    return bytes;
  }

  static Future<List<int>> _buildReceiptBytes(
    dynamic data,
    PrinterModel printer,
  ) async {
    final generator = await _createGenerator(printer);

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
      safe(store['address']),
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
    // MEJA / TAKE AWAY
    // =========================================================
    final dineType = safe(receipt['dine_type']);
    final dineUid = safe(receipt['dine_uid']);
    final hasDesk =
        desks is Map && safe(desks['numb_desk']).isNotEmpty;

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
    } else {
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
    // BARCODE
    // =========================================================
    final saleUid = safe(receipt['sale_uid']);

    if (saleUid.isNotEmpty) {
      try {
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
    bytes += generator.text('UID'.padRight(10) + ': $saleUid');
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
    final Iterable<dynamic> cartItems = carts is Map
        ? carts.values
        : (carts as List);

    for (final item in cartItems) {
      final qty = item['qty'] ?? 0;
      final name = safe(item['product']?['name']);
      final note = safe(item['note']);
      final price = item['price_after_disc'] ?? 0;
      final subtotal = item['sub_total'] ?? 0;

      bytes += generator.row([
        PosColumn(text: qty.toString(), width: 2),
        PosColumn(text: name, width: 10),
      ]);

      if (note.isNotEmpty) {
        bytes += generator.row([
          PosColumn(text: '', width: 2),
          PosColumn(text: '*$note', width: 10),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: '', width: 2),
        PosColumn(text: formatCurrency(price), width: 6),
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

    // Footer text
    final footerInfo =
        safe(printSetting['printer_cashier_footer_info']);

    if (footerInfo.isNotEmpty) {
      for (final line in footerInfo.split('\n')) {
        if (line.trim().isNotEmpty) {
          bytes += generator.text(line.trim());
        }
      }
    }

    bytes += generator.emptyLines(1);

    bytes += generator.text(
      'TERIMA KASIH',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    // Footer image
    final footer = await _loadAssetImage(
      'assets/images/footer.png',
      width: 200,
    );
    if (footer != null) {
      bytes += generator.image(footer, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    bytes += generator.feed(1);

    bytes += _finalize(generator, printer);

    return bytes;
  }

  static Future<List<int>> _buildOrderBytes(
    dynamic data,
    PrinterModel printer,
  ) async {
    // Sementara gunakan layout sederhana.
    // Nanti bisa Anda sesuaikan untuk kitchen order.
    final generator = await _createGenerator(printer);

    List<int> bytes = [];

    bytes += generator.text(
      'ORDER DAPUR',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.hr();

    final items = data['items'] as List? ?? [];
    for (final item in items) {
      bytes += generator.text(
        '${item['qty']}x ${item['name']}',
        styles: const PosStyles(bold: true),
      );
    }

    bytes += generator.feed(3);
    bytes += _finalize(generator, printer);

    return bytes;
  }

  static Future<List<int>> _buildDrawerBytes(
    PrinterModel printer,
  ) async {
    final generator = await _createGenerator(printer);

    List<int> bytes = [];
    bytes += generator.drawer();

    return bytes;
  }

  // =========================================================
  // HELPERS
  // =========================================================

  static Future<Generator> _createGenerator(
    PrinterModel printer,
  ) async {
    final paperSize =
        printer.paper == '58'
            ? PaperSize.mm58
            : PaperSize.mm80;

    final profile = await CapabilityProfile.load();

    return Generator(paperSize, profile);
  }

  static List<int> _finalize(
    Generator generator,
    PrinterModel printer,
  ) {
    List<int> bytes = [];

    if (printer.autoCut) {
      bytes += generator.cut();
    }

    if (printer.cashDrawer) {
      bytes += generator.drawer();
    }

    bytes += generator.reset();

    return bytes;
  }

  static Future<img.Image?> _loadAssetImage(
    String assetPath, {
    int? width,
    int? height,
  }) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      if (width != null || height != null) {
        return img.copyResize(
          decoded,
          width: width,
          height: height,
        );
      }

      return decoded;
    } catch (e) {
      debugPrint('Image load error ($assetPath): $e');
      return null;
    }
  }
}