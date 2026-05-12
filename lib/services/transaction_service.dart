import 'dart:convert';
import 'package:http/http.dart' as http;

class TransactionService {
  static Future<dynamic> fetchTransaction(
    String trxId,
    String userId, {
    String? receipt,
    String? order,
    String? bill,
    String? pushDrawer,
  }) async {
    final queryParams = <String, String>{};

    if (receipt == '1') queryParams['receipt'] = '1';
    if (order == '1') queryParams['order'] = '1';
    if (bill == '1') queryParams['bill'] = '1';
    if (pushDrawer == '1') queryParams['push_drawer'] = '1';

    final uri = Uri.parse(
      'https://k24.madapos.cloud/load-struk/$trxId/user/$userId',
    ).replace(queryParameters: queryParams);

    print('Request URL: $uri');

    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 30));

      print('Status Code: ${response.statusCode}');
      print('Response Length: ${response.body.length}');
      print('Response Body: ${response.body.substring(
        0,
        response.body.length > 500 ? 500 : response.body.length,
      )}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
          'Server error ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, stack) {
      print('HTTP Error: $e');
      print(stack);
      rethrow;
    }
  }
}