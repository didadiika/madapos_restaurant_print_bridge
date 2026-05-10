import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

import 'services/print_service.dart';
import 'services/printer_storage_service.dart';
import 'models/printer_model.dart';
import 'constants/printer_connection.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

// =========================
// MAIN APP
// =========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PrintListenerPage(),
    );
  }
}

class AppBackground {
  static const MethodChannel _channel =
      MethodChannel('madapos/background');

  static Future<void> minimize() async {
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (e) {
      debugPrint('Gagal minimize app: $e');
    }
  }
}

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

  // =========================
  // BLUETOOTH PERMISSION
  // =========================
  Future<void> requestBluetoothPermission() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // =========================
  // PRINTER SETTING DIALOG
  // =========================
  Future<void> showPrinterSettingDialog(
    BluetoothInfo device, {
    PrinterModel? existingPrinter,
  }) async {
    String selectedPaper = existingPrinter?.paper ?? '80';
    bool cashDrawer = existingPrinter?.cashDrawer ?? true;
    bool autoCut = existingPrinter?.autoCut ?? true;
    TextEditingController nameController = TextEditingController(
      text: existingPrinter?.name ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text("Setting Printer"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Printer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  // =========================
                  // PAPER SIZE
                  // =========================
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Paper Size",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  RadioListTile(
                    title: const Text("58mm"),
                    value: '58',
                    groupValue: selectedPaper,
                    onChanged: (value) {
                      setModalState(() {
                        selectedPaper = value!;
                      });
                    },
                  ),

                  RadioListTile(
                    title: const Text("80mm"),
                    value: '80',
                    groupValue: selectedPaper,
                    onChanged: (value) {
                      setModalState(() {
                        selectedPaper = value!;
                      });
                    },
                  ),

                  // =========================
                  // CASH DRAWER
                  // =========================
                  SwitchListTile(
                    title: const Text("Open Cash Drawer"),

                    value: cashDrawer,
                    onChanged: (value) {
                      setModalState(() {
                        cashDrawer = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text("Auto Cut"),
                    value: autoCut,
                    onChanged: (value) {
                      setModalState(() {
                        autoCut = value;
                      });
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final printer = PrinterModel(
                      name: nameController.text,
                      connection: PrinterConnection.bluetooth,
                      address: device.macAdress,
                      paper: selectedPaper,
                      cashDrawer: cashDrawer,
                      autoCut: autoCut,
                    );
                    await PrinterStorageService.savePrinter(printer);

                    // =========================
                    // UPDATE LOCAL STATE
                    // =========================

                    setState(() {
                      savedPrinters.removeWhere(
                        (e) => e.address == printer.address,
                      );

                      savedPrinters.add(printer);
                      // UPDATE ACTIVE PRINTER
                      if (selectedPrinter?.address == printer.address) {
                        selectedPrinter = printer;
                      }
                    });

                    // =========================
                    // CONNECT HANYA UNTUK
                    // PRINTER BARU
                    // =========================

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
                  child: const Text("Save"),
                ),
              ],
            );
          },
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
    });

    try {
      bool isBluetoothOn = await PrintBluetoothThermal.bluetoothEnabled;

      debugPrint("Bluetooth ON: $isBluetoothOn");
      if (!isBluetoothOn) {
        setState(() {
          isLoading = false;
          message = "Bluetooth tidak aktif";
        });
        return;
      }

      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;

      setState(() {
        bluetoothDevices = list;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
    setState(() {
      isLoading = false;
    });
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

      // DISCONNECT DULU
      await PrintBluetoothThermal.disconnect;

      await Future.delayed(const Duration(seconds: 1));

      bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress,
      );

      debugPrint("CONNECTED: $connected");

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

        ///TEST PRINT
      } else {
        setState(() {
          isConnected = false;
          message = "Gagal connect printer";
        });
      }
    } catch (e) {
      debugPrint(e.toString());

      setState(() {
        message = "Error connect printer";
      });
    }
  }

  // =========================
  // DISCONNECT PRINTER
  // =========================

  Future<void> disconnectPrinter() async {
    try {
      await PrintBluetoothThermal.disconnect;

      setState(() {
        isConnected = false;
        selectedPrinter = null;
        message = "Printer disconnected";
      });

      debugPrint("PRINTER DISCONNECTED");
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String message = "Menunggu Print";
  String? connectedAddress;
  PrinterModel? selectedPrinter;

  // =========================
  // FETCH TRANSACTION
  // =========================

Future<void> fetchTransaction(String trxId) async {
  try {
    setState(() {
      message = "Mengambil data transaksi...";
    });

    final url =
        'https://k24.madapos.cloud/load-struk/$trxId/user/24b95afb-8455-4911-902a-dfd2c954d274';

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

    if (carts is List) {
      for (final item in carts) {
        final productName = item['product']?['name'] ?? '';
        final qty = item['qty'] ?? 0;
        final subtotal = item['sub_total'] ?? 0;

        debugPrint("$productName x$qty = $subtotal");
      }
    } else if (carts is Map) {
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

    // =====================================================
    // AMBIL PRINTER
    // =====================================================
    PrinterModel? printer = selectedPrinter;
    printer ??= await PrinterStorageService.getDefaultPrinter();

    if (printer == null) {
      if (!mounted) return;
      setState(() {
        message = "Tidak ada printer yang dipilih";
      });
      return;
    }

    try {
      // Disconnect koneksi sebelumnya
      try {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) {}

      // Connect ke printer
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );

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
      await Future.delayed(const Duration(milliseconds: 500));

      // Disconnect setelah print
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      // Minimalkan aplikasi ke background tanpa menutup proses
      await AppBackground.minimize();

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
    await requestBluetoothPermission();

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

  static Future<void> moveAppToBackground() async {
  try {
    await SystemChannels.platform.invokeMethod('SystemNavigator.pop', false);
  } catch (e) {
    debugPrint('Failed to move app to background: $e');
  }
  }

  void handleUri(Uri uri) async {
    final trxId = uri.queryParameters['id'];

    setState(() {
      message = "Loading transaksi...";
    });

    if (trxId != null) {
      await fetchTransaction(trxId);
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

                              try {
                                await PrintBluetoothThermal.disconnect;
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                              } catch (_) {}

                              // =========================
                              // 2. Buka Koneksi ke printer yang dipilih
                              // =========================

                              bool connected =
                                  await PrintBluetoothThermal.connect(
                                    macPrinterAddress: printer.address,
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
                              try {
                                await PrintBluetoothThermal.disconnect;
                              } catch (_) {}
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
