import 'dart:convert';

import 'package:http/http.dart' as http;

class TransactionService {
  static Future<dynamic> fetchTransaction(
    String trxId,
    String userId,
  ) async {
    final url =
        'https://k24.madapos.cloud/load-struk/$trxId/user/$userId';

    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Gagal ambil data (${response.statusCode})',
      );
    }

    return jsonDecode(response.body);
  }
}