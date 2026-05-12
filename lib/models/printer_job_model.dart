class PrinterJobModel {
  final String id;
  final String printerId;
  final String job;
  final int autoprint;
  final int autoprintQuantity;
  final int printWithLogo;

  PrinterJobModel({
    required this.id,
    required this.printerId,
    required this.job,
    required this.autoprint,
    required this.autoprintQuantity,
    required this.printWithLogo,
  });

  factory PrinterJobModel.fromJson(
    Map<String, dynamic> json,
  ) {
    int parseInt(dynamic value, [int defaultValue = 0]) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ??
          defaultValue;
    }

    return PrinterJobModel(
      id: json['id']?.toString() ?? '',
      printerId: json['printer_id']?.toString() ?? '',
      job: json['job']?.toString() ?? '',
      autoprint: parseInt(json['autoprint']),
      autoprintQuantity: parseInt(
        json['autoprint_quantity'],
        1,
      ),
      printWithLogo: parseInt(
        json['print_with_logo'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'printer_id': printerId,
      'job': job,
      'autoprint': autoprint,
      'autoprint_quantity': autoprintQuantity,
      'print_with_logo': printWithLogo,
    };
  }
}