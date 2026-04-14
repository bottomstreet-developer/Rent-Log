import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static Future<String> getCurrencySymbol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('currency_symbol') ?? '\$';
    } catch (_) {
      return '\$';
    }
  }
}
