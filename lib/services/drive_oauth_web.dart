import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

@JS('google')
external _Google? get _google;

extension type _Google._(JSObject _) implements JSObject {
  external _Accounts get accounts;
}

extension type _Accounts._(JSObject _) implements JSObject {
  external _OAuth2 get oauth2;
}

extension type _OAuth2._(JSObject _) implements JSObject {
  external _TokenClient initTokenClient(_TokenClientConfig config);
  external void revoke(String token, JSFunction? callback);
}

extension type _TokenClient._(JSObject _) implements JSObject {
  external void requestAccessToken([_TokenRequestOverrides? overrides]);
}

extension type _TokenClientConfig._(JSObject _) implements JSObject {
  external factory _TokenClientConfig({
    String client_id,
    String scope,
    JSFunction callback,
    JSFunction? error_callback,
    String? prompt,
  });
}

extension type _TokenRequestOverrides._(JSObject _) implements JSObject {
  external factory _TokenRequestOverrides({String? prompt});
}

extension type _TokenResponse._(JSObject _) implements JSObject {
  external String? get access_token;
  external String? get error;
  external String? get error_description;
  external String? get scope;
  external num? get expires_in;
}

extension type _ErrorResponse._(JSObject _) implements JSObject {
  external String? get type;
  external String? get message;
}

class DriveOAuthWeb {
  static String? _clientId;
  static String? _scope;
  static _TokenClient? _client;

  static String? _cachedToken;
  static DateTime? _cachedExpiry;
  static String? _cachedEmail;

  static String? get cachedEmail => _cachedEmail;
  static String? get cachedToken {
    if (_cachedToken == null || _cachedExpiry == null) return null;
    if (DateTime.now().isAfter(_cachedExpiry!)) return null;
    return _cachedToken;
  }

  static bool get isGisLoaded => _google != null;

  static void _ensureClient(String clientId, String scope) {
    if (_client != null && _clientId == clientId && _scope == scope) {
      return;
    }
    if (_google == null) {
      throw StateError(
          'Le SDK Google Identity Services n\'est pas chargé. Recharge la page.');
    }
    _clientId = clientId;
    _scope = scope;
  }

  /// Demande un token OAuth via popup GIS. [silent]=true tente sans
  /// afficher de fenêtre de consentement (utile pour refresh).
  static Future<String?> requestToken({
    required String clientId,
    required String scope,
    bool silent = false,
  }) async {
    _ensureClient(clientId, scope);
    final completer = Completer<String?>();
    Timer? timeout;

    void successCb(JSAny resp) {
      timeout?.cancel();
      final r = resp as _TokenResponse;
      if (r.error != null) {
        if (!completer.isCompleted) {
          completer.completeError(StateError(
              'GIS error: ${r.error} ${r.error_description ?? ''}'));
        }
        return;
      }
      final tok = r.access_token;
      if (tok == null) {
        if (!completer.isCompleted) {
          completer.completeError(
              StateError('Aucun access_token dans la réponse GIS'));
        }
        return;
      }
      _cachedToken = tok;
      final exp = (r.expires_in ?? 3300).toInt();
      _cachedExpiry =
          DateTime.now().add(Duration(seconds: exp - 60));
      if (!completer.isCompleted) completer.complete(tok);
    }

    void errorCb(JSAny err) {
      timeout?.cancel();
      final e = err as _ErrorResponse;
      if (!completer.isCompleted) {
        completer.completeError(StateError(
            '${e.type ?? "popup_error"}: ${e.message ?? "no message"}'));
      }
    }

    final cb = successCb.toJS;
    final eb = errorCb.toJS;

    final tokenClient = _google!.accounts.oauth2.initTokenClient(
      _TokenClientConfig(
        client_id: clientId,
        scope: scope,
        callback: cb,
        error_callback: eb,
        prompt: silent ? 'none' : '',
      ),
    );

    timeout = Timer(const Duration(seconds: 90), () {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('Timeout : le popup Google ne répond pas (90s)'));
      }
    });

    try {
      tokenClient.requestAccessToken();
    } catch (e) {
      timeout.cancel();
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future;
  }

  static Future<String?> fetchEmail(String accessToken) async {
    try {
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cachedEmail = data['email'] as String?;
        return _cachedEmail;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> revoke() async {
    final t = _cachedToken;
    _cachedToken = null;
    _cachedExpiry = null;
    _cachedEmail = null;
    if (t == null || _google == null) return;
    final completer = Completer<void>();
    void cb(JSAny _) {
      if (!completer.isCompleted) completer.complete();
    }
    _google!.accounts.oauth2.revoke(t, cb.toJS);
    await completer.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});
  }

  // Évite l'avertissement "unused" sur l'import web.
  static void _unused() => web.window;
}
