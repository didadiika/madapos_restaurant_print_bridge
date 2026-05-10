import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _baseUrlKey = 'api_base_url';

  /// Default URL jika user belum pernah menyimpan setting
  static const String _defaultBaseUrl =
      'https://k24.madapos.cloud/load-struk/';

  /// Ambil base URL dari SharedPreferences
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  /// Simpan base URL baru
  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();

    // Pastikan URL selalu diakhiri dengan slash
    final normalized = url.endsWith('/') ? url : '$url/';

    await prefs.setString(_baseUrlKey, normalized);
  }

  /// Reset ke default
  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
  }
}