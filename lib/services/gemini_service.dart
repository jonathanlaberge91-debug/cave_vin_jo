import '../models/wine.dart';

class GeminiService {
  static String? apiKey;

  static bool get isConfigured => apiKey != null && apiKey!.isNotEmpty;

  static Future<Wine?> searchByText({
    required String name,
    String? domaine,
    String? vintage,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }
    throw UnimplementedError('Gemini API call à implémenter');
  }

  static Future<Wine?> searchByPhoto(List<int> imageBytes) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }
    throw UnimplementedError('Gemini vision API call à implémenter');
  }
}
