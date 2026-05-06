class DriveOAuthWeb {
  static String? get cachedEmail => null;
  static String? get cachedToken => null;
  static bool get isGisLoaded => false;

  static Future<String?> requestToken({
    required String clientId,
    required String scope,
    bool silent = false,
  }) async {
    throw UnsupportedError(
        'Drive OAuth via GIS n\'est implémenté que sur le web pour l\'instant.');
  }

  static Future<String?> fetchEmail(String accessToken) async => null;
  static Future<void> revoke() async {}
}
