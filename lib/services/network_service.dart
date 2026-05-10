import 'dart:io';

import '../models/printer_model.dart';
import 'printer_connection_service.dart';

/// ===============================================================
/// NETWORK SERVICE
/// ===============================================================
///
/// Service ini digunakan untuk printer yang terhubung melalui
/// jaringan TCP/IP (LAN/WiFi).
///
/// Umumnya thermal printer network menerima data ESC/POS pada:
/// - Port 9100 (default)
///
/// Address pada PrinterModel akan berisi IP Address printer.
/// Contoh:
/// - 192.168.1.100
///
/// Contoh konfigurasi PrinterModel:
///
/// PrinterModel(
///   name: 'Kitchen Printer',
///   connection: 'network',
///   address: '192.168.1.100',
///   port: 9100,
///   paper: '80',
///   cashDrawer: false,
///   autoCut: true,
/// )
///
/// Alur kerja:
/// 1. connect()    -> membuka Socket TCP
/// 2. writeBytes() -> mengirim bytes ESC/POS
/// 3. disconnect() -> menutup socket
/// ===============================================================
class NetworkService implements PrinterConnectionService {
  final PrinterModel printer;

  /// Socket TCP yang digunakan untuk komunikasi.
  Socket? _socket;

  NetworkService(this.printer);

  // ============================================================
  // (1) CONNECT TO PRINTER
  // ============================================================
  @override
  Future<void> connect() async {
    // Validasi jenis koneksi
    if (!printer.isNetwork) {
      throw Exception(
        'Printer connection harus network.',
      );
    }

    // Validasi IP address
    if (printer.address.trim().isEmpty) {
      throw Exception(
        'IP address printer tidak boleh kosong.',
      );
    }

    // Tutup socket lama jika masih ada
    await disconnect();

    try {
      _socket = await Socket.connect(
        printer.address,
        printer.effectivePort,
        timeout: const Duration(seconds: 5),
      );
    } on SocketException catch (e) {
      throw Exception(
        'Tidak dapat terhubung ke '
        '${printer.address}:${printer.effectivePort}\n'
        '$e',
      );
    }
  }
  // ============================================================
  // (1) END CONNECT TO PRINTER
  // ============================================================

  // ============================================================
  // (2) WRITE BYTES
  // ============================================================
  @override
  Future<void> writeBytes(List<int> bytes) async {
    if (_socket == null) {
      throw Exception(
        'Printer network belum terhubung.',
      );
    }

    try {
      _socket!.add(bytes);
      await _socket!.flush();
    } on SocketException catch (e) {
      throw Exception(
        'Gagal mengirim data ke printer network.\n$e',
      );
    }
  }
  // ============================================================
  // (2) END WRITE BYTES
  // ============================================================

  // ============================================================
  // (3) DISCONNECT
  // ============================================================
  @override
  Future<void> disconnect() async {
    if (_socket == null) return;

    try {
      await _socket!.flush();
    } catch (_) {
      // Abaikan jika flush gagal
    }

    try {
      await _socket!.close();
    } catch (_) {
      // Abaikan jika close gagal
    }

    _socket = null;
  }
  // ============================================================
  // (3) END DISCONNECT
  // ============================================================

  // ============================================================
  // (4) CHECK CONNECTION STATUS
  // ============================================================
  @override
  Future<bool> isConnected() async {
    return _socket != null;
  }
  // ============================================================
  // (4) END CHECK CONNECTION STATUS
  // ============================================================

  // ============================================================
  // (5) TEST CONNECTION
  // ============================================================
  /// Digunakan untuk mengecek apakah printer dapat diakses.
  static Future<bool> testConnection(
    String ip, {
    int port = 9100,
  }) async {
    Socket? socket;

    try {
      socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 3),
      );

      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }
  // ============================================================
  // (5) END TEST CONNECTION
  // ============================================================
}