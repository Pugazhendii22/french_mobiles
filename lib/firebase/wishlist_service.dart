import 'package:cloud_firestore/cloud_firestore.dart';
import 'catalog_firebase.dart';

class WishlistItem {
  final String productId;
  final String brand;
  final String title;
  final String imageUrl;
  final String price;
  final String categoryId;
  final Map<String, dynamic>? snapshot;

  const WishlistItem({
    required this.productId,
    required this.brand,
    required this.title,
    required this.imageUrl,
    required this.price,
    this.categoryId = '',
    this.snapshot,
  });

  factory WishlistItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WishlistItem(
      productId: data['productId'] as String? ?? doc.id,
      brand: data['brand'] as String? ?? '',
      title: data['title'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      price: data['price'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? '',
      snapshot: data['snapshot'] as Map<String, dynamic>?,
    );
  }
}

class WishlistService {
  static CollectionReference<Map<String, dynamic>> _collection() {
    final user = catalogAuth.currentUser;
    return catalogFirestore.collection('wishlist').doc(user!.uid).collection('items');
  }

  static Future<void> toggle(WishlistItem item) async {
    final user = catalogAuth.currentUser;
    if (user == null) return;
    final ref = _collection().doc(item.productId);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'productId': item.productId,
        'brand': item.brand,
        'title': item.title,
        'imageUrl': item.imageUrl,
        'price': item.price,
        'categoryId': item.categoryId,
        'snapshot': item.snapshot,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> remove(String productId) async {
    final user = catalogAuth.currentUser;
    if (user == null) return;
    await _collection().doc(productId).delete();
  }

  static Stream<bool> watchIsSaved(String productId) {
    final user = catalogAuth.currentUser;
    if (user == null) return Stream.value(false);
    return _collection()
        .doc(productId)
        .snapshots()
        .map((doc) => doc.exists)
        .distinct();
  }

  static Stream<List<WishlistItem>> watchAll() {
    final user = catalogAuth.currentUser;
    if (user == null) return Stream.value(const <WishlistItem>[]);
    return _collection()
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WishlistItem.fromDoc(doc))
            .toList());
  }
}
