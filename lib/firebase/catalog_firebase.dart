import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

const FirebaseOptions catalogFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCV6pjsYpstL1sKCcPgemIEt6iAjZw-dBg',
  appId: '1:1086357315686:android:1f43282812dc89095c4da7',
  messagingSenderId: '1086357315686',
  projectId: 'french-mobiles-marketplace',
  storageBucket: 'french-mobiles-marketplace.firebasestorage.app',
);

Future<void> initializeCatalogApp() async {
  await Firebase.initializeApp(
    name: 'catalogApp',
    options: catalogFirebaseOptions,
  );
}

FirebaseFirestore get catalogFirestore =>
    FirebaseFirestore.instanceFor(app: Firebase.app('catalogApp'));

FirebaseAuth get catalogAuth =>
  FirebaseAuth.instanceFor(app: Firebase.app('catalogApp'));
