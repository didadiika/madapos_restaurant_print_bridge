import 'dart:collection';

class PrintQueueService {
  static final Queue<Future<void> Function()> _queue = Queue();
  static bool _isProcessing = false;

  /// Tambahkan job ke antrian.
  static Future<void> enqueue(Future<void> Function() job) async {
    _queue.add(job);
    await _processQueue();
  }

  /// Proses job satu per satu.
  static Future<void> _processQueue() async {
    if (_isProcessing) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();

      try {
        await job().timeout(const Duration(seconds: 5));
        print('Queue length: ${_queue.length}');
      } catch (e) {
        // Error job tidak menghentikan queue.
        print('Print queue error: $e');
      }
    }

    _isProcessing = false;
  }
}