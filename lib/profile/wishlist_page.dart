import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../firebase/catalog_firebase.dart';
import '../firebase/wishlist_service.dart';
import '../screens/inventory_detail_page.dart';
import '../screens/login_page.dart';
import '../widgets/app_back_button.dart';
import 'profile_widgets.dart';

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  Future<void> _openItem(BuildContext context, WishlistItem item) async {
    Map<String, dynamic> data = {
      'id': item.productId,
      'brand': item.brand,
      'model': item.title,
      'salePrice': item.price,
      'photo1Url': item.imageUrl,
      if (item.snapshot != null) ...item.snapshot!,
    };

    try {
      final doc = await FirebaseFirestore.instance
          .collection('second_hand_mobiles')
          .doc(item.productId)
          .get();
      if (doc.exists && doc.data() != null) {
        data = doc.data()!;
      }
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryDetailPlaceholder(
          documentId: item.productId,
          data: data,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        title: const Text(
          'My Wishlist',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const AppBackButton.dark(),
      ),
      body: StreamBuilder<User?>(
        stream: catalogAuth.authStateChanges(),
        builder: (context, authSnap) {
          final user = authSnap.data;
          if (user == null) {
            return _SignInPrompt(
              onSignIn: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            );
          }
          return StreamBuilder<List<WishlistItem>>(
              stream: WishlistService.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load wishlist. ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <WishlistItem>[];
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Your Wishlist is Empty',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap the heart on a phone to save it here.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () => _openItem(context, item),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kProfileBorder),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: item.imageUrl.isEmpty
                                          ? const Center(
                                              child: Icon(
                                                Icons.phone_android,
                                                size: 54,
                                                color: kProfilePrimaryTheme,
                                              ),
                                            )
                                          : Image.network(
                                              item.imageUrl,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Center(
                                                child: Icon(
                                                  Icons.phone_android,
                                                  size: 54,
                                                  color: kProfilePrimaryTheme,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.brand.isNotEmpty ? item.brand : item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.price,
                                    style: const TextStyle(
                                      color: kProfilePrimaryTheme,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                icon: const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () =>
                                    WishlistService.remove(item.productId),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
        },
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignIn;

  const _SignInPrompt({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Sign in to see your wishlist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Saved phones stay in your account so you can come back later.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onSignIn,
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
