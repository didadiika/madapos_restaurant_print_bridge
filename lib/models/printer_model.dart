class PrinterModel {
  final String name;
  final String connection;
  final String address;
  final String paper;
  final bool cashDrawer;
  final bool autoCut;

  PrinterModel({
    required this.name,
    required this.connection,
    required this.address,
    required this.paper,
    required this.cashDrawer,
    required this.autoCut,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'connection': connection,
      'address': address,
      'paper': paper,
      'cash_drawer': cashDrawer,
      'auto_cut': autoCut,
    };
  }

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    return PrinterModel(
      name: json['name'] ?? '',
      connection: json['connection'] ?? 'bluetooth',
      address: json['address'] ?? '',
      paper: json['paper'] ?? '80',
      cashDrawer: json['cash_drawer'] ?? false,
      autoCut: json['auto_cut'] ?? false,
    );
  }
}
