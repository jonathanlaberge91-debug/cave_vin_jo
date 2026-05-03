import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wish_wine.dart';

class WishlistService {
  static final _db = FirebaseFirestore.instance;
  static final _wishes = _db.collection('wishlist');

  static Stream<List<WishWine>> wishes() {
    return _wishes.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(WishWine.fromDoc).toList(),
        );
  }

  static Future<String> addWish(WishWine wish) async {
    final ref = await _wishes.add(wish.toMap());
    return ref.id;
  }

  static Future<void> updateWish(String id, Map<String, dynamic> data) =>
      _wishes.doc(id).update(data);

  static Future<void> deleteWish(String id) => _wishes.doc(id).delete();
}
