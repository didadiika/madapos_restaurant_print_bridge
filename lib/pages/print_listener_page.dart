import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../constants/printer_connection.dart';
import '../models/printer_model.dart';
import '../services/bluetooth_service.dart';
import '../services/print_service.dart';
import '../services/printer_storage_service.dart';
import '../widgets/printer_setting_dialog.dart';

// =========================
// KELAS UNTUK MENGHANDLE BACKGROUND
// =========================
class AppBackground {
  static const MethodChannel _channel = MethodChannel('madapos/background');

  static Future<void> minimize() async {
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (e) {
      debugPrint('Gagal minimize app: $e');
    }
  }
}
// =========================
// KELAS UNTUK MENGHANDLE BACKGROUND
// =========================

// =========================
// PRINT LISTENER PAGE
// =========================
class PrintListenerPage extends StatefulWidget {
  const PrintListenerPage({super.key});

  @override
  State<PrintListenerPage> createState() => _PrintListenerPageState();
}

class _PrintListenerPageState extends State<PrintListenerPage> {
  // MENAMPUNG DAFTAR PRINTER BLUETOOTH YANG TERDETEKSI
  List<BluetoothInfo> bluetoothDevices = [];
  // MENAMPUNG DAFTAR PRINTER YANG PERNAH DISIMPAN
  List<PrinterModel> savedPrinters = [];

  bool isLoading = false;
  bool isConnected = false;
  bool isConnectingPrinter = false;

  Future<void> showPrinterSettingDialog(
    BluetoothInfo device, {
    PrinterModel? existingPrinter,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => PrinterSettingDialog(
        device: device,
        existingPrinter: existingPrinter,
        onSave: (printer) async {
          await PrinterStorageService.savePrinter(printer);

          if (!mounted) return;

          setState(() {
            savedPrinters.removeWhere((e) => e.address == printer.address);

            savedPrinters.add(printer);

            if (selectedPrinter?.address == printer.address) {
              selectedPrinter = printer;
            }
          });

          // Jika printer baru, langsung connect
          if (existingPrinter == null) {
            await connectPrinter(
              device,
              printerName: printer.name,
              paper: printer.paper,
              cashDrawer: printer.cashDrawer,
              autoCut: printer.autoCut,
            );
          }
        },
      ),
    );
  }

  // =========================
  // SCAN BLUETOOTH PRINTER
  // =========================

  Future<void> scanBluetooth() async {
    setState(() {
      isLoading = true;
      message = "Scanning Bluetooth...";
    });

    try {
      final devices = await BluetoothService.scanDevices();

      setState(() {
        bluetoothDevices = devices;
        message = "${devices.length} printer ditemukan";
      });
    } catch (e) {
      setState(() {
        message = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // =========================
  // CONNECT PRINTER
  // =========================
  Future<void> connectPrinter(
    BluetoothInfo device, {
    required String printerName,
    required String paper,
    required bool cashDrawer,
    required bool autoCut,
  }) async {
    try {
      setState(() {
        message = "Menghubungkan printer...";
      });

      final connected = await BluetoothService.connect(device.macAdress);

      if (connected) {
        final printer = PrinterModel(
          name: printerName,
          connection: PrinterConnection.bluetooth,
          address: device.macAdress,
          paper: paper,
          cashDrawer: cashDrawer,
          autoCut: autoCut,
        );

        await PrinterStorageService.savePrinter(printer);

        setState(() {
          selectedPrinter = printer;
          isConnected = true;
          connectedAddress = device.macAdress;
          message = "Printer ${device.name} terhubung";
        });
      } else {
        setState(() {
          isConnected = false;
          message = "Gagal connect printer";
        });
      }
    } catch (e) {
      setState(() {
        message = "Error connect printer";
      });
    }
  }

  // =========================
  // DISCONNECT PRINTER
  // =========================

  Future<void> disconnectPrinter() async {
    await BluetoothService.disconnect();

    setState(() {
      isConnected = false;
      selectedPrinter = null;
      message = "Printer disconnected";
    });
  }

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String message = "Menunggu Print";
  String? connectedAddress;
  PrinterModel? selectedPrinter;

  // =========================
  // FETCH TRANSACTION
  // =========================

  Future<void> fetchTransaction(String trxId, String userId) async {
    try {
      setState(() {
        message = "Mengambil data transaksi...";
      });

      final url = 'https://k24.madapos.cloud/load-struk/$trxId/user/$userId';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        setState(() {
          message = "Gagal ambil data (${response.statusCode})";
        });
        return;
      }

      final data = jsonDecode(response.body);

      final storeName = data['store']?['name'] ?? '';
      final invoice = data['receipt']?['sale_uid'] ?? '';
      final total = data['receipt']?['grand_total'] ?? '';

      debugPrint("Store: $storeName");
      debugPrint("Invoice: $invoice");
      debugPrint("Total: $total");

      // =====================================================
      // DEBUG CARTS
      // carts bisa berupa List atau Map
      // =====================================================
      final carts = data['carts'];

      // Jika carts adalah List (banyak item)
      if (carts is List) {
        for (final item in carts) {
          final productName = item['product']?['name'] ?? '';
          final qty = item['qty'] ?? 0;
          final subtotal = item['sub_total'] ?? 0;

          debugPrint("$productName x$qty = $subtotal");
        }
      }
      // Jika carts adalah Map (hanya 1 item)
      else if (carts is Map) {
        carts.forEach((key, item) {
          final productName = item['product']?['name'] ?? '';
          final qty = item['qty'] ?? 0;
          final subtotal = item['sub_total'] ?? 0;

          debugPrint("$productName x$qty = $subtotal");
        });
      }

      if (!mounted) return;
      setState(() {
        message = "Invoice $invoice berhasil dimuat";
      });

      // =========== Ambil data printer yang dipilih user atau default printer jika belum ada yang dipilih ===========
      PrinterModel? printer = selectedPrinter;
      printer ??= await PrinterStorageService.getDefaultPrinter();
      // =========== End Ambil data printer yang dipilih user atau default printer jika belum ada yang dipilih ===========

      if (printer == null) {
        if (!mounted) return;
        setState(() {
          message = "Tidak ada printer yang dipilih";
        });
        return;
      }

      try {
        // ===== Disconnect koneksi untuk mencegah koneksi masih aktif sebelumnya ======

        await BluetoothService.disconnect();

        // ===== End Disconnect koneksi untuk mencegah koneksi masih aktif sebelumnya ======

        // ===== Connect koneksi Printer dengan address ======
        final connected = await BluetoothService.connect(printer.address);
        // ===== End Connect koneksi Printer dengan address ======

        if (!connected) {
          if (!mounted) return;
          setState(() {
            message = "Gagal connect printer";
          });
          return;
        }

        if (!mounted) return;
        setState(() {
          selectedPrinter = printer;
          connectedAddress = printer!.address;
          isConnected = true;
          message = "Mencetak invoice...";
        });

        // Print struk
        await PrintService.printReceipt(data, printer);

        // Tunggu sebentar
        // await Future.delayed(const Duration(milliseconds: 500));

        // ===== Disconnect koneksi karena sudah selesai ======

        await BluetoothService.disconnect();

        // ===== End Disconnect koneksi karena sudah selesai ======

        // ===== Minimize Aplikasi di Background ======
        await AppBackground.minimize();
        // ===== End Minimize Aplikasi di Background ======

        if (!mounted) return;
        setState(() {
          isConnected = false;
          message = "Print job selesai";
        });
      } catch (e) {
        debugPrint("Print error: $e");

        if (!mounted) return;
        setState(() {
          message = "Gagal mencetak";
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        message = "Timeout koneksi server";
      });
    } catch (e) {
      debugPrint("Fetch transaction error: $e");

      if (!mounted) return;
      setState(() {
        message = "Error: $e";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initDeepLink();
    startBluetooth();
  }

  Future<void> startBluetooth() async {
    await BluetoothService.requestPermissions();

    final printers = await PrinterStorageService.loadPrinters();
    final defaultPrinter = await PrinterStorageService.getDefaultPrinter();

    setState(() {
      savedPrinters = printers;
      selectedPrinter = defaultPrinter;

      if (defaultPrinter != null) {
        connectedAddress = defaultPrinter.address;
      }
    });

    await scanBluetooth();
  }

  Future<void> initDeepLink() async {
    // Saat app dibuka pertama kali
    final Uri? initialUri = await _appLinks.getInitialLink();

    if (initialUri != null) {
      handleUri(initialUri);
    }

    // Saat app sudah terbuka
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      handleUri(uri);
    });
  }

  void handleUri(Uri uri) async {
    // Ambil parameter dari deep link, misalnya: madapos://print?id=12345
    final trxId = uri.queryParameters['id'];
    final userId = uri.queryParameters['userId'];

    setState(() {
      message = "Loading transaksi...";
    });

    if (trxId != null && userId != null) {
      await fetchTransaction(trxId, userId);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Madapos Restaurant Print Bridge"),
        centerTitle: true,
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await startBluetooth();
        },

        child: ListView(
          padding: const EdgeInsets.all(16),

          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.print, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (selectedPrinter != null)
                      Text(
                        "${selectedPrinter!.name}\n${selectedPrinter!.paper}mm",
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Daftar Printer",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                IconButton(
                  onPressed: () async {
                    await scanBluetooth();
                  },
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (isLoading) const Center(child: CircularProgressIndicator()),

            ...bluetoothDevices.map((device) {
              bool selected = selectedPrinter?.address == device.macAdress;

              return Card(
                elevation: 3,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(selected ? Icons.check : Icons.print),
                  ),

                  title: Text(device.name),
                  subtitle: Text(device.macAdress),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // =========================
                      // TEST PRINT
                      // =========================
                      if (savedPrinters.any(
                        (e) => e.address == device.macAdress,
                      ))
                        InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () async {
                            if (isConnectingPrinter) {
                              debugPrint("MASIH CONNECTING...");
                              return;
                            }
                            isConnectingPrinter = true;
                            try {
                              final printer =
                                  await PrinterStorageService.findPrinterByAddress(
                                    device.macAdress,
                                  );
                              if (printer == null) {
                                return;
                              }
                              setState(() {
                                message = "Menghubungkan printer...";
                                isConnectingPrinter = true;
                              });

                              // =========================
                              // 1. Pastikan koneksi lama ditutup
                              // =========================

                              await BluetoothService.disconnect();

                              // =========================
                              // 2. Buka Koneksi ke printer yang dipilih
                              // =========================

                              bool connected = await BluetoothService.connect(
                                printer.address,
                              );
                              debugPrint("result status connect: $connected");
                              if (!connected) {
                                setState(() {
                                  message = "Gagal connect printer";
                                  isConnected = false;
                                });
                                return;
                              }

                              // Simpan status UI
                              connectedAddress = printer.address;

                              setState(() {
                                selectedPrinter = printer;
                                isConnected = true;
                                message = "Printer ${printer.name} terhubung";
                              });

                              // =========================
                              // 3. Print test
                              // =========================

                              await PrintService.printTest(printer);
                              // Beri jeda kecil agar data benar-benar terkirim
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              // ==========================================
                              // 4. Tutup koneksi setelah selesai print
                              // ==========================================

                              await BluetoothService.disconnect();

                              // Update status UI
                              setState(() {
                                isConnected = false;
                                message = "Test print selesai";
                              });
                            } catch (e) {
                              debugPrint(e.toString());
                              setState(() {
                                message = "Error connect printer";
                              });
                            } finally {
                              isConnectingPrinter = false;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Icon(Icons.receipt_long, size: 20),
                          ),
                        ),

                      if (savedPrinters.any(
                        (e) => e.address == device.macAdress,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(100),
                            onTap: () async {
                              final printer =
                                  await PrinterStorageService.findPrinterByAddress(
                                    device.macAdress,
                                  );
                              if (printer != null) {
                                await showPrinterSettingDialog(
                                  device,
                                  existingPrinter: printer,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Icon(
                                Icons.settings,
                                size: 20,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(width: 10),
                      // =========================
                      // CONNECT BUTTON
                      // =========================
                      if (!savedPrinters.any(
                        (e) => e.address == device.macAdress,
                      ))
                        InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: () async {
                            await showPrinterSettingDialog(device);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bluetooth, size: 18),
                                const SizedBox(width: 6),
                                const Text(
                                  'Connect',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
