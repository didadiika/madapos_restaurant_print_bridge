import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';

class PrinterStorageService {
  static const String printerKey = 'printers';

  static Future<PrinterModel?> getDefaultPrinter() async {
    final printers = await loadPrinters();

    if (printers.isEmpty) {
      return null;
    }

    // Ambil printer pertama sebagai default
    return printers.first;
  }

  // =========================
  // LOAD ALL PRINTERS
  // =========================
  static Future<List<PrinterModel>> loadPrinters() async {
    final prefs = await SharedPreferences.getInstance();

    final String? data = prefs.getString(printerKey);
    if (data == null) {
      return [];
    }

    final List decoded = jsonDecode(data);
    return decoded.map((e) => PrinterModel.fromJson(e)).toList();
  }

  // =========================
  // SAVE / UPDATE PRINTER
  // =========================

  static Future<void> savePrinter(PrinterModel printer) async {
    final prefs = await SharedPreferences.getInstance();
    final printers = await loadPrinters();

    printers.removeWhere(
      (e) =>
          e.connection == printer.connection &&
          e.address == printer.address,
    );

    printers.add(printer);

    final json = jsonEncode(
      printers.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(printerKey, json);
  }

  // =========================
  // FIND PRINTER
  // =========================

  static Future<PrinterModel?> findPrinterByAddress(
    String connection,
    String address,
  ) async {
    final printers = await loadPrinters();

    try {
      return printers.firstWhere(
        (e) =>
            e.connection == connection &&
            e.address == address,
      );
    } catch (_) {
      return null;
    }
  }

  // =========================
  // REMOVE PRINTER
  // =========================

  static Future<void> removePrinter(
    String connection,
    String address,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final printers = await loadPrinters();

    printers.removeWhere(
      (e) =>
          e.connection == connection &&
          e.address == address,
    );

    final json = jsonEncode(
      printers.map((e) => e.toJson()).toList(),
    );

    await prefs.setString(printerKey, json);
  }
}
