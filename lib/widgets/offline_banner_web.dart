import 'dart:js_interop';
import 'package:web/web.dart' as web;

class ConnectivityChecker {
  final void Function(bool offline) onChanged;
  late final void Function(web.Event) _onOnline;
  late final void Function(web.Event) _onOffline;
  bool _offline;

  bool get isOffline => _offline;

  ConnectivityChecker({required this.onChanged})
      : _offline = !web.window.navigator.onLine {
    _onOnline = (web.Event _) {
      _offline = false;
      onChanged(false);
    };
    _onOffline = (web.Event _) {
      _offline = true;
      onChanged(true);
    };
    web.window.addEventListener('online', _onOnline.toJS);
    web.window.addEventListener('offline', _onOffline.toJS);
  }

  void dispose() {
    web.window.removeEventListener('online', _onOnline.toJS);
    web.window.removeEventListener('offline', _onOffline.toJS);
  }
}
