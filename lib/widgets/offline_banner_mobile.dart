import 'dart:async';
import 'dart:io';

class ConnectivityChecker {
  final void Function(bool offline) onChanged;
  bool _offline = false;
  Timer? _timer;

  bool get isOffline => _offline;

  ConnectivityChecker({required this.onChanged}) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final wasOffline = _offline;
      _offline = result.isEmpty;
      if (_offline != wasOffline) onChanged(_offline);
    } on SocketException {
      if (!_offline) {
        _offline = true;
        onChanged(true);
      }
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
