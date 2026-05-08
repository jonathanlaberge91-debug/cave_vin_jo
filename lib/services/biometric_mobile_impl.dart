// Stub for non-web platforms. Mobile uses local_auth directly in
// biometric_service.dart and never calls these.

Future<bool> webIsSupported() async => false;

Future<String?> webRegister() async => null;

Future<bool> webAuthenticate(List<String> credIdsBase64) async => false;
