import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class BaseUrlSettingDialog extends StatefulWidget {
  const BaseUrlSettingDialog({super.key});

  @override
  State<BaseUrlSettingDialog> createState() =>
      _BaseUrlSettingDialogState();
}

class _BaseUrlSettingDialogState
    extends State<BaseUrlSettingDialog> {
  final TextEditingController _controller =
      TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final url = await SettingsService.getBaseUrl();
    _controller.text = url;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final url = _controller.text.trim();

    if (url.isEmpty) {
      _showMessage('Base URL tidak boleh kosong.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await SettingsService.saveBaseUrl(url);

      if (!mounted) return;

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Base URL berhasil disimpan'),
        ),
      );
    } catch (e) {
      _showMessage('Gagal menyimpan URL: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _reset() async {
    await SettingsService.resetBaseUrl();
    await _loadBaseUrl();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Base URL dikembalikan ke default'),
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Base URL'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Contoh:\n'
              'https://k24.madapos.cloud/load-struk/',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Base URL',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _reset,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}