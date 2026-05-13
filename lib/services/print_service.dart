import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:http/http.dart' as http;

import '../models/printer_model.dart';

class PrintService {

  // =========================================================
  // LOAD IMAGE FROM URL (store.photo_link)
  // =========================================================
  static Future<img.Image?> _loadNetworkImage(
    String url, {
    int? width,
  }) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('Gagal download logo: ${response.statusCode}');
        return null;
      }

      final Uint8List bytes = response.bodyBytes;
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        debugPrint('Gagal decode logo');
        return null;
      }

      // Resize agar ukuran logo sesuai
      if (width != null) {
        image = img.copyResize(image, width: width);
      }

      return image;
    } catch (e) {
      debugPrint('Error load network image: $e');
      return null;
    }
  }

  // =========================================================
  // PUBLIC METHODS
  // =========================================================

  static Future<void> printTest(PrinterModel printer) async {
    final bytes = await _buildTestBytes(printer);
    await _sendToPrinter(bytes, printer);
  }

  static Future<void> printReceipt(
    dynamic data,
    PrinterModel printer,
  ) async {
    final bytes = await _buildReceiptBytes(data, printer);
    await _sendToPrinter(bytes, printer);
  }

  static Future<void> printOrder(
    dynamic data,
    PrinterModel printer,
  ) async {
    final bytes = await _buildOrderBytes(data, printer);
    await _sendToPrinter(bytes, printer);
  }

  static Future<void> pushDrawer(PrinterModel printer) async {
    final bytes = await _buildDrawerBytes(printer);
    await _sendToPrinter(bytes, printer);
  }

  // =========================================================
  // CORE SEND METHOD
  // =========================================================

  static Future<void> _sendToPrinter(
    List<int> bytes,
    PrinterModel printer,
  ) async {
    try {
      if (printer.connection == 'bluetooth') {
        await PrintBluetoothThermal.writeBytes(bytes);
        return;
      }

      if (printer.connection == 'network') {
        final socket = await Socket.connect(
          printer.address,
          printer.port,
          timeout: const Duration(seconds: 5),
        );

        socket.add(Uint8List.fromList(bytes));
        await socket.flush();
        await socket.close();
        return;
      }

      throw Exception(
        'Unsupported printer connection: ${printer.connection}',
      );
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
    // Beep printer (ESC/POS)
    // ESC B m n
    // m = jumlah beep
    // n = durasi beep (50 ms × n)
    if (printer.beep) {
      bytes += _beep(times: 4, duration: 1);
    }
    // 4 kali beep, durasi masing-masing 100 ms
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
    bytes += generator.reset();
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
    // LOGO TOKO DARI API (store.photo_link)
    // =========================================================
    final photoLink = safe(store['photo_link']);

    if (photoLink.isNotEmpty) {
      final logo = await _loadNetworkImage(
        photoLink,
        width: 215,
      );

      if (logo != null) {
        bytes += generator.image(
          logo,
          align: PosAlign.center,
        );

        bytes += generator.emptyLines(1);
      }
    }

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
          height: PosTextSize.size2,
          width: PosTextSize.size2,
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
        // Jika jumlah digit ganjil, tambahkan 0 di depan
        final barcodeValue =
            saleUid.length.isOdd ? '0$saleUid' : saleUid;

        // Prefix {C = Code Set C (khusus angka)
        final code128Data = '{C$barcodeValue';

        bytes += generator.setStyles(
          const PosStyles(align: PosAlign.center),
        );

        bytes += generator.barcode(
          Barcode.code128(
            utf8.encode(code128Data), // List<int>
          ),
          width: 2,
          height: 60,
          font: BarcodeFont.fontA,
          textPos: BarcodeText.none,
        );

        // Cetak teks asli di bawah barcode
        bytes += generator.text(
          saleUid,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
          ),
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
    if(printer.footerSpace > 0) {
      bytes += generator.feed(printer.footerSpace);
    }

    bytes += _finalize(generator, printer);

    return bytes;
  }

static Future<List<int>> _buildOrderBytes(
  dynamic data,
  PrinterModel printer,
) async {
  final generator = await _createGenerator(printer);

  List<int> bytes = [];
  bytes += generator.reset();
  
  String safe(dynamic value) => value?.toString() ?? '';

  // Helper format tanggal:
  // 2026-05-10T03:19:22.000000Z -> 2026-05-10 03:19:22
  // 2026-05-10 10:19:22 -> tetap
  String formatDateTime(String value) {
    if (value.isEmpty) return '';

    try {
      final dt = DateTime.parse(value).toLocal();

      String two(int n) => n.toString().padLeft(2, '0');

      return '${dt.year}-'
          '${two(dt.month)}-'
          '${two(dt.day)} '
          '${two(dt.hour)}:'
          '${two(dt.minute)}:'
          '${two(dt.second)}';
    } catch (_) {
      return value;
    }
  }

  final receipt = data['receipt'] ?? {};
  final waiting = data['waiting'] ?? {};
  final desks = data['desks'] ?? {};
  final store = data['store'] ?? {};

  // Nama outlet dari store.name
  final outletName = safe(
    store['name'] ??
        receipt['company'] ??
        receipt['outlet_name'] ??
        'MadaPOS',
  );

  // Nomor antrian (jika ada)
  final queueNumber = safe(
    waiting['queue'] ??
        waiting['queue_number'] ??
        waiting['number'],
  );

  // Tipe dine-in / take away
  final dineType = safe(receipt['dine_type']).toLowerCase();

  // Apakah take away?
  final isTakeAway =
      dineType == 'take away' ||
      dineType == 'takeaway' ||
      receipt['dine_uid']?.toString().toUpperCase() == 'TA';

  // Nomor meja
  final deskNumber = safe(
    desks['numb_desk'] ??
        desks['desk_number'],
  );

  // Nama area / lantai
  final areaName = isTakeAway
      ? '#Take Away'
      : safe(
          desks['area'] ??
              desks['floor'] ??
              desks['floor_name'] ??
              desks['name_floor'],
        );

  // Tanggal
  final createdAt = formatDateTime(
    safe(
      receipt['date'] ??
          receipt['created_at'] ??
          receipt['datetime'],
    ),
  );

  // Nama pelanggan
  final customerName = safe(
    receipt['customer_name'],
  );

  // Nama kasir/waiter
  final cashier = safe(
    receipt['cashier']?['name'] ??
        receipt['created_name'] ??
        receipt['cashier_name'] ??
        receipt['user_name'],
  );

  // =========================
  // LOOP PER KATEGORI
  // =========================
  for (final category in printer.orderPerCategory) {
    final orders = category.orders;
    if (orders.isEmpty) continue;

    // Nama kategori kiri atas
    bytes += generator.text(
      '#${category.categoryName}',
      styles: const PosStyles(
        align: PosAlign.left,
      ),
    );

    // Nama outlet (di atas nomor meja)
    bytes += generator.text(
      outletName,
      styles: const PosStyles(
        align: PosAlign.center,
      ),
    );

    // Nomor meja (#3)
    if (deskNumber.isNotEmpty) {
      bytes += generator.text(
        '#$deskNumber',
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size3,
        ),
      );
    }

    // Nama area / lantai (di bawah nomor meja)
    if (areaName.isNotEmpty) {
      bytes += generator.text(
        areaName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }

    bytes += generator.hr(ch: '=');

    // Tanggal
    if (createdAt.isNotEmpty) {
      bytes += generator.text('Tanggal : $createdAt');
    }

    // Nama pelanggan (di bawah tanggal)
    if (customerName.isNotEmpty) {
      bytes += generator.text(
        customerName.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size2,
        ),
      );
    }

    // Jika customer kosong, fallback ke nama kasir
    else if (cashier.isNotEmpty) {
      bytes += generator.text(
        cashier.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }

    bytes += generator.hr();

    // Header item
    bytes += generator.text(
      'Qty Item',
    );

    bytes += generator.hr();

    // =========================
    // DETAIL ITEM
    // =========================
    int totalItems = 0;

    for (final order in orders) {
      totalItems++;

      // Contoh: 2 Chicken Wings
      bytes += generator.text(
        '${order.qty} ${order.productName}',
      );

      // Catatan
      if (order.note.trim().isNotEmpty) {
        bytes += generator.text(
          '   **${order.note}',
        );
      }
    }

    bytes += generator.hr();

    // Total item
    bytes += generator.text(
      '$totalItems ITEM(S)',
    );

    bytes += generator.hr(ch: '=');

    // Footer
    bytes += generator.text(
      'Powered by MadaPOS',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );
    
    if(printer.footerSpace > 0) {
      bytes += bytes += generator.feed(printer.footerSpace);
    }
    
    if (printer.beep) {
      bytes += _beep(times: 4, duration: 1);
    }

    // Cut per kategori
    bytes += _finalize(generator, printer);
  }

  return bytes;
}

  static Future<List<int>> _buildDrawerBytes(
    PrinterModel printer,
  ) async {
    final generator = await _createGenerator(printer);

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.drawer();

    return bytes;
  }

// =========================================================
// GENERATOR METHODS
// Tambahkan di dalam class PrintService,
// tepat di bawah PUBLIC METHODS.
// =========================================================
  static Future<List<int>> generateReceipt(
    dynamic data,
    PrinterModel printer,
    ) async {
      return await _buildReceiptBytes(data, printer);
  }

  static Future<List<int>> generateOrder(
    dynamic data,
    PrinterModel printer,
  ) async {
    return await _buildOrderBytes(data, printer);
  }

  // =========================================================
// CONNECTION METHODS
// Tambahkan juga agar handlePrintData() dapat memanggil:
// - PrintService.connect()
// - PrintService.write()
// - PrintService.disconnect()
// - PrintService.openCashDrawer()
// =========================================================

static Socket? _socket;
static PrinterModel? _currentPrinter;

/// Untuk Bluetooth tidak perlu melakukan apa-apa,
/// karena koneksi sudah dibuka sebelumnya menggunakan
/// BluetoothService.connect().
///
/// Untuk Ethernet kita buka socket dan simpan ke _socket.
static Future<void> connect(PrinterModel printer) async {
  _currentPrinter = printer;

  if (printer.connection == 'bluetooth') {
    // Putuskan koneksi lama terlebih dahulu
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}

    final connected =
        await PrintBluetoothThermal.connect(
      macPrinterAddress: printer.address,
    );

    if (connected != true) {
      throw Exception(
        'Gagal connect Bluetooth ke ${printer.address}',
      );
    }

    return;
  }

  if (printer.connection == 'network') {
    _socket = await Socket.connect(
      printer.address,
      printer.port,
      timeout: const Duration(seconds: 5),
    );
    return;
  }

  throw Exception(
    'Unsupported printer connection: ${printer.connection}',
  );
}

/// Menulis bytes ke printer yang sedang aktif.
static Future<void> write(List<int> bytes) async {
  if (_currentPrinter == null) {
    throw Exception('Printer belum terkoneksi.');
  }

  if (_currentPrinter!.connection == 'bluetooth') {
    await PrintBluetoothThermal.writeBytes(bytes);
    return;
  }

  if (_currentPrinter!.connection == 'network') {
    if (_socket == null) {
      throw Exception('Socket network belum terbuka.');
    }

    _socket!.add(Uint8List.fromList(bytes));
    await _socket!.flush();
    return;
  }
}

  /// Membuka cash drawer.
static Future<void> openCashDrawer() async {
  if (_currentPrinter == null) return;

  final generator = await _createGenerator(_currentPrinter!);
  final bytes = generator.drawer();

  await write(bytes);
}

  /// Menutup koneksi network.
  /// Untuk Bluetooth tidak perlu karena handlePrintData()
  /// memanggil disconnect() setelah setiap printer.
static Future<void> disconnect() async {
  if (_currentPrinter?.connection == 'network') {
    if (_socket != null) {
      await _socket!.close();
      _socket = null;
    }
  } else if (_currentPrinter?.connection == 'bluetooth') {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  _currentPrinter = null;
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

  static List<int> _beep({
    int times = 4,
    int duration = 1,
  }) {
    return [0x1B, 0x42, times, duration];
  }

  static List<int> _finalize(
    Generator generator,
    PrinterModel printer,
  ) {
    List<int> bytes = [];
    bytes += generator.reset();

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