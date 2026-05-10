/// Kontrak untuk semua jenis koneksi printer.
///
/// Implementasi:
/// - BluetoothService
/// - NetworkService
/// - USBService (jika nanti diperlukan)
abstract class PrinterConnectionService {
  /// Membuka koneksi ke printer.
  Future<void> connect();

  /// Mengirim data ESC/POS ke printer.
  Future<void> writeBytes(List<int> bytes);

  /// Menutup koneksi.
  Future<void> disconnect();

  /// Status koneksi saat ini.
  Future<bool> isConnected();
}