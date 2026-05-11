import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../constants/printer_connection.dart';
import '../models/printer_model.dart';
import '../services/bluetooth_service.dart';
import '../services/print_service.dart';
import '../services/printer_storage_service.dart';
import '../services/transaction_service.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import '../widgets/base_url_setting_dialog.dart';
import '../widgets/ethernet_printer_dialog.dart';
import 'bluetooth_printer_page.dart';

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

  Future<void> showBluetoothPrinterDialog(
    BluetoothInfo device, {
    PrinterModel? existingPrinter,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => BluetoothPrinterDialog(
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


// ============================================================
// (1) CONNECT TO PRINTER
// ============================================================
  Future<void> _showAddPrinterDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Bluetooth'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BluetoothPrinterPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.lan),
                title: const Text('Ethernet'),
                onTap: () async {
                  Navigator.pop(context);

                  final PrinterModel? printer = await showDialog<PrinterModel>(
                    context: context,
                    builder: (_) => const EthernetPrinterDialog(),
                  );

                  if (printer != null) {
                    // Simpan ke local storage
                    await PrinterStorageService.savePrinter(printer);

                    // Reload daftar printer dari storage
                    final printers = await PrinterStorageService.loadPrinters();
                    final defaultPrinter =
                        await PrinterStorageService.getDefaultPrinter();

                    if (!mounted) return;

                    setState(() {
                      savedPrinters = printers;

                      // Jika belum ada printer yang dipilih, gunakan printer baru
                      selectedPrinter ??= defaultPrinter ?? printer;

                      // Jika printer baru adalah default, tampilkan sebagai selected
                      if (defaultPrinter?.address == printer.address) {
                        selectedPrinter = defaultPrinter;
                      }

                      connectedAddress = selectedPrinter?.address;

                      message = 'Printer Ethernet ${printer.name} berhasil disimpan';
                    });

                    debugPrint('Printer Ethernet disimpan: ${printer.name}');
                  }
                },
              ),
            ],
          ),
        );
      },
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
      message = 'Mengambil data transaksi...';
    });

    final data = await TransactionService.fetchTransaction(
      trxId,
      userId,
    );

    final invoice = data['receipt']?['sale_uid'] ?? '';

    if (!mounted) return;
    setState(() {
      message = 'Invoice $invoice berhasil dimuat';
    });

    // Ambil printer aktif atau default
    PrinterModel? printer = selectedPrinter;
    printer ??= await PrinterStorageService.getDefaultPrinter();

    if (printer == null) {
      if (!mounted) return;
      setState(() {
        message = 'Tidak ada printer yang dipilih';
      });
      return;
    }

    try {
      await BluetoothService.disconnect();

      final connected =
          await BluetoothService.connect(printer.address);

      if (!connected) {
        if (!mounted) return;
        setState(() {
          message = 'Gagal connect printer';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        selectedPrinter = printer;
        connectedAddress = printer!.address;
        isConnected = true;
        message = 'Mencetak invoice...';
      });

      await PrintService.printReceipt(data, printer);

      await BluetoothService.disconnect();
      await AppBackground.minimize();

      if (!mounted) return;
      setState(() {
        isConnected = false;
        message = 'Print job selesai';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Gagal mencetak';
      });
    }
  } on Exception catch (e) {
    if (!mounted) return;
    setState(() {
      message = e.toString();
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
        actions: [
            IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Setting Endpoint',
            onPressed: () async {
                await showDialog(
                context: context,
                builder: (_) => const BaseUrlSettingDialog(),
                );
            },
            ),
            
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPrinterDialog,
        child: const Icon(Icons.add),
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

// ======================================================
// 1. PRINTER BLUETOOTH YANG BELUM DISIMPAN
// ======================================================
...bluetoothDevices
    .where(
      (device) => !savedPrinters.any(
        (p) =>
            p.connection == PrinterConnection.bluetooth &&
            p.address == device.macAdress,
      ),
    )
    .map((device) {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.bluetooth),
      ),
      title: Text(device.name),
      subtitle: Text(device.macAdress),
      trailing: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () async {
          await showBluetoothPrinterDialog(device);
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
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.link, size: 18),
              SizedBox(width: 6),
              Text(
                'Connect',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}).toList(),

// ======================================================
// 2. PRINTER TERSIMPAN (BLUETOOTH + ETHERNET)
// ======================================================
...savedPrinters.map((printer) {
  final bool selected =
      selectedPrinter?.address == printer.address &&
      selectedPrinter?.connection == printer.connection;

  final bool isBluetooth =
      printer.connection == PrinterConnection.bluetooth;

  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          selected
              ? Icons.check
              : (isBluetooth
                    ? Icons.bluetooth
                    : Icons.lan),
        ),
      ),
      title: Text(printer.name),
      subtitle: Text(
        isBluetooth
            ? printer.address
            : '${printer.address}:${printer.port}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TEST PRINT
InkWell(
  borderRadius: BorderRadius.circular(100),
  onTap: () async {
    try {
      setState(() {
        message = 'Mencetak test page...';
      });

      // ======================================================
      // KHUSUS BLUETOOTH: connect manual terlebih dahulu
      // ======================================================
      if (printer.connection == PrinterConnection.bluetooth) {
        await BluetoothService.disconnect();

        final connected = await BluetoothService.connect(
          printer.address,
        );

        if (!connected) {
          if (!mounted) return;
          setState(() {
            message = 'Gagal connect printer Bluetooth';
          });
          return;
        }

        // Beri jeda agar koneksi stabil
        await Future.delayed(
          const Duration(milliseconds: 500),
        );
      }

      // ======================================================
      // CETAK TEST
      // PrintService akan:
      // - Bluetooth -> kirim ke plugin print_bluetooth_thermal
      // - Network   -> socket TCP/IP ke IP:PORT
      // ======================================================
      await PrintService.printTest(
        printer
      );

      // ======================================================
      // KHUSUS BLUETOOTH: disconnect setelah print
      // ======================================================
      if (printer.connection == PrinterConnection.bluetooth) {
        await Future.delayed(
          const Duration(milliseconds: 500),
        );
        await BluetoothService.disconnect();
      }

      if (!mounted) return;
      setState(() {
        selectedPrinter = printer;
        connectedAddress = printer.address;
        isConnected = false;
        message = 'Test print selesai';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = 'Gagal test print: $e';
      });
    }
  },
  child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(100),
    ),
    child: const Icon(
      Icons.receipt_long,
      size: 20,
    ),
  ),
),
          const SizedBox(width: 8),

          // SETTING
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () async {
              if (isBluetooth) {
                final device = bluetoothDevices.firstWhere(
                  (d) => d.macAdress == printer.address,
                  orElse: () => BluetoothInfo(
                    name: printer.name,
                    macAdress: printer.address,
                  ),
                );

                await showBluetoothPrinterDialog(
                  device,
                  existingPrinter: printer,
                );
              } else {
                final updated =
                    await showDialog<PrinterModel>(
                  context: context,
                  builder: (_) =>
                      EthernetPrinterDialog(
                    existingPrinter: printer,
                  ),
                );

                if (updated != null) {
                  await PrinterStorageService
                      .savePrinter(updated);

                  final printers =
                      await PrinterStorageService
                          .loadPrinters();

                  if (!mounted) return;
                  setState(() {
                    savedPrinters = printers;

                    if (selectedPrinter?.address ==
                        printer.address) {
                      selectedPrinter = updated;
                    }

                    message =
                        'Printer ${updated.name} diperbarui';
                  });
                }
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
        ],
      ),
      onTap: () {
        setState(() {
          selectedPrinter = printer;
          connectedAddress = printer.address;
          message =
              'Printer ${printer.name} dipilih';
        });
      },
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
