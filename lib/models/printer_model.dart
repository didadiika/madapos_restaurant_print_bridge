import '../constants/printer_connection.dart';
import 'order_per_category_model.dart';
import 'printer_job_model.dart';

class PrinterModel {
  final String name;
  final String connection;
  final String address;
  final String paper;
  final bool cashDrawer;
  final bool autoCut;
  final int port;
  final bool beep;

  // Jobs printer (Receipt, Order, Bill, dll)
  final List<PrinterJobModel> jobs;

  // Data order per kategori untuk kitchen/bar printer
  final List<OrderPerCategoryModel> orderPerCategory;

  PrinterModel({
    required this.name,
    required this.connection,
    required this.address,
    required this.paper,
    required this.cashDrawer,
    required this.autoCut,
    this.beep = false,
    this.port = 9100,
    this.jobs = const [],
    this.orderPerCategory = const [],
  });

  bool get isBluetooth =>
      connection == PrinterConnection.bluetooth;

  bool get isNetwork =>
      connection == PrinterConnection.network;

  bool get isUsb =>
      connection == PrinterConnection.usb;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'connection': connection,
      'address': address,
      'paper': paper,
      'cash_drawer': cashDrawer,
      'auto_cut': autoCut,
      'port': port,
      'beep': beep,

      // Simpan jobs
      'jobs': jobs.map((e) => e.toJson()).toList(),

      // Simpan order per category
      'order_per_category':
          orderPerCategory.map((e) => e.toJson()).toList(),
    };
  }

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    // =====================================================
    // Normalize Connection
    // JSON API:
    // - printer_conn = Bluetooth / Ethernet
    // JSON Local:
    // - connection = bluetooth / network
    // =====================================================
    String connection =
        json['connection'] ??
        json['printer_conn'] ??
        PrinterConnection.bluetooth;

    if (connection.toLowerCase() == 'bluetooth') {
      connection = PrinterConnection.bluetooth;
    } else if (connection.toLowerCase() == 'ethernet' ||
        connection.toLowerCase() == 'network') {
      connection = PrinterConnection.network;
    }

    // =====================================================
    // Parse boolean helper
    // =====================================================
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return false;
    }

    return PrinterModel(
      // API menggunakan printer_name
      // Local storage menggunakan name
      name: json['name'] ?? json['printer_name'] ?? '',

      connection: connection,

      // API menggunakan printer_address
      // Local storage menggunakan address
      address:
          json['address'] ?? json['printer_address'] ?? '',

      // API menggunakan printer_type = 80
      // Local storage menggunakan paper
      paper:
          (json['paper'] ?? json['printer_type'] ?? '80')
              .toString(),

      // API menggunakan printer_cash_drawer = 0/1
      // Local storage menggunakan cash_drawer = bool
      cashDrawer: parseBool(
        json['cash_drawer'] ??
            json['printer_cash_drawer'] ??
            false,
      ),

      // Local storage
      autoCut: parseBool(
        json['auto_cut'] ?? true,
      ),

      // API biasanya tidak mengirim port
      port: int.tryParse(
            (json['port'] ?? '9100').toString(),
          ) ??
          9100,

      beep: parseBool(json['beep'] ?? false),

      // Parse jobs[]
      jobs: (json['jobs'] as List? ?? [])
          .map(
            (e) => PrinterJobModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),

      // Parse order_per_category[]
      orderPerCategory:
          (json['order_per_category'] as List? ?? [])
              .map(
                (e) => OrderPerCategoryModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}