import 'package:cloud_firestore/cloud_firestore.dart';
import 'catalog_firebase.dart';

Future<void> ensureUserProfileExists() async {
  final user = catalogAuth.currentUser;
  if (user == null) return;
  final docRef = catalogFirestore.collection('users').doc(user.uid);
  final doc = await docRef.get();
  if (doc.exists) return;

  await docRef.set({
    'name': user.displayName ?? '',
    'photoUrl': user.photoURL,
    'email': user.email,
    'phone': user.phoneNumber,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
