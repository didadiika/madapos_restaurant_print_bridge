import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_model.dart';

class PrinterStorageService {
  static const String printerKey =
      'printers';
  // =========================
  // LOAD ALL PRINTERS
  // =========================
  static Future<List<PrinterModel>>
      loadPrinters() async {
    final prefs = await SharedPreferences.getInstance();

    final String? data = prefs.getString(printerKey);
    if (data == null) {
      return [];
    }

    final List decoded = jsonDecode(data);
    return decoded
        .map(
          (e) => PrinterModel.fromJson(e),
        )
        .toList();
  }

  // =========================
  // SAVE / UPDATE PRINTER
  // =========================

  static Future<void> savePrinter(PrinterModel printer,) async {

    final prefs = await SharedPreferences.getInstance();

    List<PrinterModel> printers = await loadPrinters();

    // REMOVE DUPLICATE ADDRESS
    printers.removeWhere((e) => e.address == printer.address,);

    printers.add(printer);
    final json =
        jsonEncode(
          printers
              .map((e) => e.toJson())
              .toList(),
        );

    await prefs.setString(
      printerKey,
      json,
    );
  }

  // =========================
  // FIND PRINTER
  // =========================

  static Future<PrinterModel?>
      findPrinterByAddress(
    String address,
  ) async {
    List<PrinterModel> printers =
        await loadPrinters();
    try {
      return printers.firstWhere(
        (e) => e.address == address,
      );
    } catch (e) {
      return null;
    }
  }

  // =========================
  // REMOVE PRINTER
  // =========================

  static Future<void> removePrinter(String address,) async {

    final prefs = await SharedPreferences.getInstance();

    List<PrinterModel> printers = await loadPrinters();

    printers.removeWhere((e) => e.address == address,);

    final json =
        jsonEncode(
          printers
              .map((e) => e.toJson())
              .toList(),
        );

    await prefs.setString(
      printerKey,
      json,
    );
  }
}