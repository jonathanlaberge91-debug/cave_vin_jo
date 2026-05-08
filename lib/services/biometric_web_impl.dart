import 'dart:js_interop';

@JS('cvBiometricSupported')
external JSPromise<JSBoolean> _jsSupported();

@JS('cvBiometricRegister')
external JSPromise<JSAny?> _jsRegister();

@JS('cvBiometricAuthenticate')
external JSPromise<JSBoolean> _jsAuthenticate(JSString credIdBase64Csv);

Future<bool> webIsSupported() async {
  try {
    final result = await _jsSupported().toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}

Future<String?> webRegister() async {
  try {
    final result = await _jsRegister().toDart;
    if (result == null) return null;
    return (result as JSString).toDart;
  } catch (_) {
    return null;
  }
}

Future<bool> webAuthenticate(List<String> credIdsBase64) async {
  if (credIdsBase64.isEmpty) return false;
  try {
    final csv = credIdsBase64.join(',');
    final result = await _jsAuthenticate(csv.toJS).toDart;
    return result.toDart;
  } catch (_) {
    return false;
  }
}
