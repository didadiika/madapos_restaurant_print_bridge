import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

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

class PrintListenerPage extends StatefulWidget {
  const PrintListenerPage({super.key});

  @override
  State<PrintListenerPage> createState() => _PrintListenerPageState();
}

class _PrintListenerPageState extends State<PrintListenerPage> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;

  String message = "Menunggu Print";


  Future<void> fetchTransaction(String trxId) async {

  try {

    final response = await http.get(
      Uri.parse(
        'https://irons-cafe.madapos.cloud/load-struk/$trxId/user/24b95afb-8455-4911-902a-dfd2c954d274',
      ),
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      // Ambil data store
      final storeName = data['store']['name'];

      // Ambil invoice
      final invoice = data['receipt']['sale_uid'];

      // Ambil grand total
      final total = data['receipt']['grand_total'];

      // Ambil carts
      final carts = data['carts'];

      debugPrint("Store: $storeName");
      debugPrint("Invoice: $invoice");
      debugPrint("Total: $total");

      // looping cart
      carts.forEach((key, item) {

        final productName = item['product']['name'];
        final qty = item['qty'];
        final subtotal = item['sub_total'];

        debugPrint("$productName x$qty = $subtotal");

      });

      setState(() {
        message = "Invoice $invoice berhasil dimuat";
      });

    } else {

      setState(() {
        message = "Gagal ambil data";
      });

    }

  } catch (e) {

    debugPrint(e.toString());

    setState(() {
      message = "Error koneksi";
    });

  }
}

  @override
  void initState() {
    super.initState();
    initDeepLink();
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

  void handleUri(Uri uri) async{
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
        title: const Text("Flutter Bridge Printer"),
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}