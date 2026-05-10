import '../models/printer_model.dart';
import 'bluetooth_service.dart';
import 'network_service.dart';
import 'printer_connection_service.dart';

/// ===============================================================
/// PRINTER CONNECTION FACTORY
/// ===============================================================
///
/// Factory ini bertugas membuat service koneksi printer
/// berdasarkan jenis koneksi yang tersimpan pada PrinterModel.
///
/// Supported connection:
/// - bluetooth
/// - network
///
/// Dengan factory ini, PrintService tidak perlu mengetahui
/// detail implementasi koneksi printer.
///
/// Contoh penggunaan:
///
/// final connection =
///     PrinterConnectionFactory.create(printer);
///
/// await connection.connect();
/// await connection.writeBytes(bytes);
/// await connection.disconnect();
/// ===============================================================
class PrinterConnectionFactory {
  /// Membuat instance service koneksi printer sesuai tipe.
  static PrinterConnectionService create(
    PrinterModel printer,
  ) {
    switch (printer.connection.toLowerCase()) {
      case 'bluetooth':
        return BluetoothService(printer);

      case 'network':
        return NetworkService(printer);

      default:
        throw Exception(
          'Jenis koneksi printer tidak didukung: '
          '${printer.connection}',
        );
    }
  }
}