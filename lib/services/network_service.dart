import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'dart:typed_data';

class NetworkService {
  static Future<PosPrintResult> printBytes({
    required String ip,
    required Uint8List bytes,
    int port = 9100,
    required PaperSize paperSize,
  }) async {
    final profile = await CapabilityProfile.load();

    final printer = NetworkPrinter(
      paperSize,
      profile,
    );

    final result = await printer.connect(
      ip,
      port: port,
    );

    if (result != PosPrintResult.success) {
      return result;
    }

    printer.rawBytes(Uint8List.fromList(bytes));
    printer.disconnect();

    return PosPrintResult.success;
  }
}