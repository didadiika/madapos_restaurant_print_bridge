import '../constants/printer_connection.dart';

class PrinterModel {
  final String name;
  final String connection;
  final String address;
  final String paper;
  final bool cashDrawer;
  final bool autoCut;
  final int port;
  final bool beep;

  PrinterModel({
    required this.name,
    required this.connection,
    required this.address,
    required this.paper,
    required this.cashDrawer,
    required this.autoCut,
    this.beep = false,
    this.port = 9100,
  });

  bool get isBluetooth => connection == PrinterConnection.bluetooth;
  bool get isNetwork => connection == PrinterConnection.network;
  bool get isUsb => connection == PrinterConnection.usb;

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
    };
  }

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    return PrinterModel(
      name: json['name'] ?? '',
      connection:
          json['connection'] ?? PrinterConnection.bluetooth,
      address: json['address'] ?? '',
      paper: json['paper'] ?? '80',
      cashDrawer: json['cash_drawer'] ?? false,
      autoCut: json['auto_cut'] ?? false,
      port: json['port'] ?? 9100,
      beep: json['beep'] ?? false,
    );
  }
}