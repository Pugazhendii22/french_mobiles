import 'package:flutter/material.dart';

import 'account_pages.dart';
import 'orders_page.dart';
import 'profile_widgets.dart';
import 'support_page.dart';
import 'wishlist_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/catalog_firebase.dart';
import '../screens/edit_profile_page.dart';
import '../widgets/app_back_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final user = catalogAuth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: kProfileSurface,
        appBar: AppBar(
          backgroundColor: kProfilePrimaryTheme,
          elevation: 0,
          leading: const AppBackButton.dark(),
          title: const Text(
            'My Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'You\'re not signed in. Please sign in to view your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
          ),
        ),
      );
    }

    

    return Scaffold(
      backgroundColor: kProfileSurface,
      appBar: AppBar(
        backgroundColor: kProfilePrimaryTheme,
        elevation: 0,
        leading: const AppBackButton.dark(),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: catalogFirestore.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: double.infinity,
                    color: kProfilePrimaryTheme,
                    padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                    child: Column(
                      children: const [
                        SizedBox(height: 24),
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 24),
                      ],
                    ),
                  );
                }

                final data = snapshot.data!.data() ?? {};
                final name = (data['name'] as String?)?.trim() ?? 'Not provided';
                final email = (data['email'] as String?)?.trim() ?? 'Not provided';
                final phone = (data['phone'] as String?)?.trim() ?? 'Not provided';
                final photoUrl = (data['photoUrl'] as String?) ?? '';

                return Container(
                  width: double.infinity,
                  color: kProfilePrimaryTheme,
                  padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.white,
                              child: photoUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(photoUrl, width: 76, height: 76, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: kProfilePrimaryTheme)),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: kProfilePrimaryTheme,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: kProfilePrimaryTheme,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$email  •  $phone',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFFCDD2),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    QuickActionButton(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Orders',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const OrdersPage()),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.favorite_border,
                      label: 'Wishlist',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const WishlistPage()),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.headset_mic_outlined,
                      label: 'Support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SupportPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'ACCOUNT SETTINGS'),
                  const SizedBox(height: 8),
                  MenuCard(
                    children: [
                      ProfileMenuItem(
                        icon: Icons.location_on_outlined,
                        title: 'Saved Addresses',
                        subtitle: 'Home, Office & other addresses',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavedAddressesPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Payment Methods',
                        subtitle: 'Saved cards & UPI details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PaymentMethodsPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileMenuItem(
                        icon: Icons.notifications_none,
                        title: 'Notification Preferences',
                        subtitle: 'Offers, orders & updates',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationPreferencesPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'GENERAL'),
                  const SizedBox(height: 8),
                  MenuCard(
                    children: [
                      ProfileMenuItem(
                        icon: Icons.security_outlined,
                        title: 'Privacy & Security',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacySecurityPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileMenuItem(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpCenterPage(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ProfileMenuItem(
                        icon: Icons.info_outline,
                        title: 'About Us',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutUsPage()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await catalogAuth.signOut();
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Log Out', style: TextStyle(color: kProfilePrimaryTheme)),
          ),
        ],
      ),
    );
  }
}
