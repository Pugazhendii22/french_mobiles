import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:french_mobiles/firebase/catalog_firebase.dart';

import 'home_models.dart';

/// Every Firebase read the home screen performs, in one place.
///
/// The queries, collection paths, field names and Firestore *instances* are
/// carried over verbatim from the previous home screen. Two details are
/// deliberate and must not be "tidied up":
///
///  * [watchAvailableMobiles] and [loadAvailableMobiles] use
///    `FirebaseFirestore.instance` — the **default** app — whereas everything
///    else uses `catalogFirestore`, the `catalogApp` secondary. Both are
///    configured from the same options today, but they are distinct
///    [FirebaseApp] instances and switching one would be a behaviour change.
///  * Address ordering is `createdAt` descending, with the default address
///    picked out in Dart rather than by a `where` clause, because documents
///    written before the `isDefault` field existed do not carry it.
class HomeRepository {
  const HomeRepository();

  // --- Auth --------------------------------------------------------------

  User? get currentUser => catalogAuth.currentUser;

  Stream<User?> watchAuthState() => catalogAuth.authStateChanges();

  // --- Profile -----------------------------------------------------------

  /// The signed-in user's profile document, used for the greeting name.
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserDoc(String uid) {
    return catalogFirestore.collection('users').doc(uid).snapshots();
  }

  // --- Addresses ---------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAddresses(String uid) {
    return catalogFirestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Marks [docId] as the default address and clears the flag on all others,
  /// in a single batch.
  Future<void> setDefaultAddress({
    required String uid,
    required String docId,
  }) async {
    final batch = catalogFirestore.batch();
    final addrSnap = await catalogFirestore
        .collection('users')
        .doc(uid)
        .collection('addresses')
        .get();
    for (final d in addrSnap.docs) {
      batch.update(d.reference, {'isDefault': d.id == docId});
    }
    await batch.commit();
  }

  /// Picks the address to show in the location strip: the one flagged
  /// `isDefault`, else the first of the `createdAt`-descending stream.
  ///
  /// Field names and the label-then-first-line-of-fullAddress precedence are
  /// carried over from the previous home screen, and match what
  /// `AddEditAddressSheet` writes.
  static String? resolveDisplayAddress(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) return null;

    QueryDocumentSnapshot<Map<String, dynamic>> chosen = docs.first;
    for (final doc in docs) {
      if (doc.data()['isDefault'] == true) {
        chosen = doc;
        break;
      }
    }

    final data = chosen.data();
    final label = (data['label'] as String?)?.trim() ?? '';
    if (label.isNotEmpty) return label;

    final fullAddress = (data['fullAddress'] as String?)?.trim() ?? '';
    if (fullAddress.isNotEmpty) return fullAddress.split(',').first.trim();

    return null;
  }

  // --- Inventory ---------------------------------------------------------

  /// Available second-hand mobiles.
  ///
  /// Uses the **default** Firestore app; see the class doc.
  Future<List<HomeProduct>> loadAvailableMobiles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('second_hand_mobiles')
        .where('status', isEqualTo: 'available')
        .get();

    return snapshot.docs.map(_mapProduct).toList();
  }

  /// Products for [categoryId]. Only `mobile` has a catalog behind it; the
  /// other categories resolve to an empty list, as they did before.
  Future<List<HomeProduct>> loadProducts(String categoryId) async {
    if (categoryId != 'mobile') return const [];
    return loadAvailableMobiles();
  }

  /// Firestore stores prices as either a number or a formatted string.
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  static HomeProduct _mapProduct(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final brand = (data['brand'] ?? '').toString();
    final model = (data['model'] ?? '').toString();
    final photo1Url = (data['photo1Url'] ?? '').toString();
    final rawPrice = data['salePrice'];

    // Same original-price fallback chain the detail page uses, so a card and
    // the page it opens never disagree about the discount.
    final originalPrice = _asInt(
        data['originalPrice'] ?? data['mrp'] ?? data['basePrice']);
    final salePrice = _asInt(rawPrice);
    final storage = (data['storage'] ?? '').toString().trim();
    final condition =
        (data['condition'] ?? data['grade'] ?? '').toString().trim();
    final warrantyMonths =
        _asInt(data['warrantyMonths'] ?? data['warranty_months']);

    // Price formatting copied verbatim: Firestore holds either a number or an
    // already-formatted string that may or may not carry the rupee sign.
    final priceValue = rawPrice is num
        ? '₹ ${rawPrice.toStringAsFixed(0)}'
        : (rawPrice == null
            ? ''
            : rawPrice.toString().startsWith('₹')
                ? rawPrice.toString()
                : '₹ $rawPrice');

    return HomeProduct(
      id: doc.id,
      categoryId: 'mobile',
      brand: brand,
      title: '$brand $model'.trim(),
      imageUrl: photo1Url,
      price: priceValue,
      model: model,
      storage: storage,
      condition: condition,
      warrantyMonths: warrantyMonths,
      salePriceValue: salePrice,
      originalPriceValue: originalPrice,
      documentId: doc.id,
      firestoreData: data,
    );
  }
}
