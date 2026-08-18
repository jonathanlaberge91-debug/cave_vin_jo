import 'dart:async';

/// Flux Firestore partagé et mémorisé.
///
/// Sans ça, chaque `build()` d'écran ouvrait un NOUVEL abonnement Firestore :
/// le `StreamBuilder` repassait en état « waiting » et la roulette de
/// chargement réapparaissait à chaque `setState` (frappe dans la recherche,
/// changement de filtre, changement de page).
///
/// Ici : un seul abonnement pour toute l'app, et tout nouvel écouteur reçoit
/// immédiatement la dernière valeur connue avant de recevoir les suivantes.
class CachedStream<T> {
  CachedStream(this._source);

  final Stream<T> Function() _source;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  StreamSubscription<T>? _sub;
  T? _last;
  bool _hasLast = false;

  void _start() {
    _sub ??= _source().listen(
      (value) {
        _last = value;
        _hasLast = true;
        _controller.add(value);
      },
      onError: _controller.addError,
    );
  }

  Stream<T> get stream => Stream<T>.multi((out) {
        _start();
        // On s'abonne AVANT de rejouer la dernière valeur : aucune mise à jour
        // ne peut se perdre entre les deux.
        final sub = _controller.stream.listen(
          out.add,
          onError: out.addError,
        );
        if (_hasLast) out.add(_last as T);
        out.onCancel = sub.cancel;
      });

  /// Coupe l'écoute et oublie la dernière valeur (déconnexion, changement de
  /// compte). Le prochain écouteur repartira sur une lecture fraîche.
  void reset() {
    _sub?.cancel();
    _sub = null;
    _last = null;
    _hasLast = false;
  }
}
