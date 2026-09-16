import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase/catalog_firebase.dart';
import 'firebase/wishlist_service.dart';
import 'profile/account_pages.dart';
import 'profile/profile_screen.dart';
import 'screens/login_page.dart';
import 'screens/inventory_detail_page.dart';
import 'screens/sell_mobile_page.dart';
import 'screens/checkup/checkup_entry_page.dart';

// ==========================================
// GLOBAL COLOR CONFIGURATION (home)
// Brand: Lime Green #32CD32 + Black
// ==========================================
class AppColors {
  static const Color primaryTheme = Color(0xFF32CD32);
  static const Color limeDeep = Color(0xFF1E9B1E);
  static const Color ink = Color(0xFF101910);
  static const Color bodyBackground = Color(0xFFF2F6F2);
  static const Color primaryText = Color(0xFF101910);
  static const Color secondaryText = Color(0xFF1C2A1C);
  static const Color mutedText = Color(0xFF4A5A4A);

  // Search Bar Styling
  static const Color searchBarBackground = Colors.white;
  static const Color searchBarIcon = Color(0xFF1A1A1A);
  static const Color searchBarHint = Color(0xFF667066);

  // Category Bar & Product Styling
  static const Color categoryBarBackground = Color(0xFFF2F6F2);
  static const Color activeTabIndicator = Color(0xFF32CD32);
  static const Color activeTabText = Color(0xFF101910);
  static const Color inactiveTabText = Color(0xFF9AA8A0);
  static const Color profileIconColor = Color(0xFF101910);
  static const Color accentBorder = Color(0xFF32CD32);
  static const Color darkTickerBg = Color(0xFF101910);

  /// Soft green tint for chips / badges on white surfaces.
  static const Color primarySoft = Color(0xFFDFF8DF);
  static const Color onPrimarySoft = Color(0xFF0B5A0B);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategoryId = 'mobile';

  String? _cleanDisplayName(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isEmpty) return null;
    final words =
        name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final unique = words.toSet().toList();
    final cleaned = unique.join(' ');
    if (cleaned.isEmpty) return null;
    if (cleaned.toLowerCase() == 'hello') return null;
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = catalogAuth.currentUser;
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.bodyBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          onPanDown: (_) => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Green fills under the camera / status bar — no white SafeArea strip.
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4AE04A),
                      Color(0xFF32CD32),
                      Color(0xFF1FA81F),
                    ],
                  ),
                  borderRadius: BorderRadius.zero,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33008A00),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(top: topInset),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StreamBuilder<User?>(
                                  stream: catalogAuth.authStateChanges(),
                                  builder: (context, authSnapshot) {
                                    final user = authSnapshot.data;
                                    if (user == null) {
                                      return const Text(
                                        'Hello, Guest',
                                        style: TextStyle(
                                            color: AppColors.primaryText,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      );
                                    }
                                    return StreamBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: catalogFirestore
                                          .collection('users')
                                          .doc(user.uid)
                                          .snapshots(),
                                      builder: (context, userSnapshot) {
                                        String displayName = 'Guest';
                                        if (userSnapshot.hasData &&
                                            userSnapshot.data!.exists) {
                                          final name = (userSnapshot.data!
                                                      .data()?['name']
                                                  as String?) ??
                                              '';
                                          final cleaned = _cleanDisplayName(
                                              name);
                                          if (cleaned != null) {
                                            displayName = cleaned;
                                          }
                                        }
                                        return Text(
                                          'Hello, $displayName',
                                          style: const TextStyle(
                                              color: AppColors.primaryText,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold),
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 2),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    if (currentUser == null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()),
                                      );
                                      return;
                                    }
                                    final result = await Navigator.push<
                                        Map<String, dynamic>>(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const SavedAddressesPage(
                                                  selectMode: true)),
                                    );
                                    if (result != null && mounted) {
                                      final docId = result['id'] as String?;
                                      if (docId == null) return;
                                      try {
                                        final batch = catalogFirestore.batch();
                                        final addrSnap = await catalogFirestore
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .collection('addresses')
                                            .get();
                                        for (final d in addrSnap.docs) {
                                          batch.update(d.reference, {
                                            'isDefault': d.id == docId,
                                          });
                                        }
                                        await batch.commit();
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Failed to set address: $e')));
                                        }
                                      }
                                    }
                                  },
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: currentUser == null
                                            ? const Text(
                                                'Select delivery address',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500),
                                              )
                                            : StreamBuilder<
                                                QuerySnapshot<
                                                    Map<String, dynamic>>>(
                                                stream: catalogFirestore
                                                    .collection('users')
                                                    .doc(currentUser.uid)
                                                    .collection('addresses')
                                                    .orderBy('createdAt',
                                                        descending: true)
                                                    .snapshots(),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasError) {
                                                    return Text(
                                                        'Error: ${snapshot.error}');
                                                  }
                                                  String displayText =
                                                      'Add delivery address';
                                                  if (snapshot.hasData &&
                                                      snapshot.data!.docs
                                                          .isNotEmpty) {
                                                    final docs =
                                                        snapshot.data!.docs;
                                                    final sorted = List<
                                                        QueryDocumentSnapshot<
                                                            Map<String,
                                                                dynamic>>>.from(docs);
                                                    sorted.sort((a, b) {
                                                      final aDef = a.data()[
                                                              'isDefault'] ==
                                                          true;
                                                      final bDef = b.data()[
                                                              'isDefault'] ==
                                                          true;
                                                      if (aDef && !bDef) {
                                                        return -1;
                                                      }
                                                      if (!aDef && bDef) {
                                                        return 1;
                                                      }
                                                      return 0;
                                                    });
                                                    final addressData =
                                                        sorted.first.data();
                                                    final label =
                                                        (addressData['label']
                                                                    as String?)
                                                                ?.trim() ??
                                                            '';
                                                    final fullAddress =
                                                        (addressData['fullAddress']
                                                                    as String?)
                                                                ?.trim() ??
                                                            '';
                                                    if (label.isNotEmpty) {
                                                      displayText = label;
                                                    } else if (fullAddress
                                                        .isNotEmpty) {
                                                      final firstLine = fullAddress
                                                          .split(',')
                                                          .first
                                                          .trim();
                                                      displayText = firstLine;
                                                    }
                                                  }
                                                  return Text(
                                                    displayText,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  );
                                                },
                                              ),
                                      ),
                                      const Icon(Icons.keyboard_arrow_down,
                                          color: Colors.white, size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.person_outline,
                                    color: AppColors.profileIconColor,
                                    size: 26),
                                onPressed: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const ProfilePage()));
                                  if (!mounted) return;
                                  SystemChrome.setSystemUIOverlayStyle(
                                      const SystemUiOverlayStyle(
                                    statusBarColor: Colors.transparent,
                                    statusBarIconBrightness: Brightness.dark,
                                    statusBarBrightness: Brightness.light,
                                  ));
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AnimatedSearchBar(),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  color: AppColors.bodyBackground,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildCheckupEntryButton(),
                        const SizedBox(height: 16),
                        const PromoBannerSlider(),
                        const SizedBox(height: 16),
                        const HomeTrustStrip(),
                        const SizedBox(height: 16),
                        const ScrollingTickerBar(),
                        const SizedBox(height: 12),
                        TopCategoryBar(
                          categories: sampleCategories,
                          selectedCategoryId: selectedCategoryId,
                          onCategorySelect: (id) {
                            setState(() {
                              selectedCategoryId = id;
                            });
                          },
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              Text(
                                'Available phones',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Divider(color: Color(0xFFD7E6D7)),
                              ),
                              SizedBox(width: 12),
                              Row(
                                children: [
                                  Text(
                                    'View all',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.limeDeep,
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(Icons.chevron_right,
                                      size: 16, color: AppColors.limeDeep),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ProductHorizontalList(categoryId: selectedCategoryId),
                        const SizedBox(height: 24),
                        const HomeFooter(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              _buildSellBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckupEntryButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF32CD32).withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const CheckupEntryPage(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF32CD32),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.build_circle_outlined,
                      color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Auto Checkup',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Run 7 hardware tests',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF32CD32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: AppColors.primaryTheme,
            borderRadius: BorderRadius.circular(9999),
            child: InkWell(
              borderRadius: BorderRadius.circular(9999),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SellMobilePage()),
                );
                if (!mounted) return;
                SystemChrome.setSystemUIOverlayStyle(
                    const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.currency_rupee, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Sell your phone',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, color: Colors.black, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// DATA MODELS & CATEGORY-SPECIFIC PRODUCTS
// ==========================================
class CategoryModel {
  final String id;
  final String title;
  final String iconUrl;

  CategoryModel({
    required this.id,
    required this.title,
    required this.iconUrl,
  });
}

class ProductModel {
  final String id;
  final String categoryId;
  final String brand;
  final String title;
  final String imageUrl;
  final String featureTag;
  final String discount;
  final String price;
  final String originalPrice;
  final String couponPrice;
  final String rating;
  final String reviewsCount;
  final String? documentId;
  final Map<String, dynamic>? firestoreData;

  ProductModel({
    required this.id,
    required this.categoryId,
    required this.brand,
    required this.title,
    required this.imageUrl,
    required this.featureTag,
    required this.discount,
    required this.price,
    required this.originalPrice,
    required this.couponPrice,
    required this.rating,
    required this.reviewsCount,
    this.documentId,
    this.firestoreData,
  });
}

final List<CategoryModel> sampleCategories = [
  CategoryModel(
    id: 'mobile',
    title: 'Mobile',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788426580/images-removebg-preview_gzons0.png',
  ),
  CategoryModel(
    id: 'laptops',
    title: 'Laptops',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430704/mbp-14-digitalmat-gallery-6-202410-removebg-preview_xmqnvh.png',
  ),
  CategoryModel(
    id: 'earparts',
    title: 'Earbuds',
    iconUrl:
        'https://res.cloudinary.com/dvsnmkgwx/image/upload/v1788430875/airpods-pro-3-hero-select-202509_FMT_WHH-removebg-preview_lnjjup.png',
  ),
];

// ==========================================
// TICKER WIDGET
// ==========================================
class ScrollingTickerBar extends StatefulWidget {
  const ScrollingTickerBar({Key? key}) : super(key: key);

  @override
  State<ScrollingTickerBar> createState() => _ScrollingTickerBarState();
}

class _ScrollingTickerBarState extends State<ScrollingTickerBar> {
  late ScrollController _scrollController;
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startContinuousScroll();
    });
  }

  void _startContinuousScroll() {
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + 1.2);
        }
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildTickerItem(
      IconData icon, String title, Color iconColor,
      {bool showDivider = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          if (showDivider) ...[
            Container(
              width: 1,
              height: 18,
              color: Colors.white24,
            ),
            const SizedBox(width: 20),
          ],
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      color: AppColors.darkTickerBg,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Row(
            children: [
              _buildTickerItem(Icons.verified_user_outlined,
                  'Doorstep Verification', Colors.lightGreenAccent),
              _buildTickerItem(Icons.autorenew, 'Easy Replacement',
                  Colors.white,
                  showDivider: true),
              _buildTickerItem(Icons.calendar_today_outlined,
                  'No Cost EMI available', Colors.lightGreenAccent,
                  showDivider: true),
            ],
          );
        },
      ),
    );
  }
}

class HomeTrustStrip extends StatefulWidget {
  const HomeTrustStrip({Key? key}) : super(key: key);

  @override
  State<HomeTrustStrip> createState() => _HomeTrustStripState();
}

class _HomeTrustStripState extends State<HomeTrustStrip>
    with SingleTickerProviderStateMixin {
  static const _items = [
    (Icons.verified_outlined, 'Certified'),
    (Icons.local_shipping_outlined, 'Doorstep'),
    (Icons.payments_outlined, 'Fair price'),
  ];

  static const double _cardHeight = 56;
  // One loop = an initial rest, then 3 identical jump-groups. Each group moves
  // ALL three contents at the exact same instant (simultaneous position-swap
  // jump):
  //   card 1 -> card 2  (slides right one card)
  //   card 2 -> card 3  (slides right one card)
  //   card 3 -> card 1  (slides left across the whole row, on-screen)
  // Timings are explicit so the cycle visibly starts from container 1: the app
  // first holds Certified/Doorstep/Fair price in cards 1/2/3 (_restMs), then
  // jumps, then pauses ("train stop"), repeated 3x, after which every content
  // is back home and the loop restarts seamlessly.
  static const double _restMs = 1250; // initial hold before the first jump
  static const double _jumpMs = 500; // duration of one simultaneous jump
  static const double _pauseMs = 1250; // "train stop" after each jump

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // True slot (0 .. cardCount) of `home`'s content at cycle time v in [0, 1).
  // One cycle = initial rest + 3 jump-groups; each group is one synchronized
  // jump followed by a "train stop" pause. Only the wrapping content
  // (card 3 -> card 1) travels left across the row; the other two shift right
  // by exactly one card. All three move during the same jump (nothing ever
  // waits or empties a card). During the initial rest every content holds at
  // its home slot, so on load the strip starts from container 1.
  double _itemSlot(int home, double v) {
    const totalMs = _restMs + 3 * (_jumpMs + _pauseMs);
    const groupMs = _jumpMs + _pauseMs;
    const jumpInGroup = _jumpMs / groupMs;
    final s = ((v * totalMs - _restMs) / groupMs).clamp(0.0, 3.0);
    final n = s.floor();
    final uRaw = s - n;
    final eased = uRaw < jumpInGroup
        ? Curves.easeInOutCubic.transform(uRaw / jumpInGroup)
        : 1.0;
    final start = (home + n) % _items.length;
    final end = (start + 1) % _items.length;
    if (end < start) {
      return _items.length - 1 - eased * (_items.length - 1);
    }
    return start + eased;
  }

  Widget _buildContent(int index) {
    final item = _items[index % _items.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.$1, size: 18, color: AppColors.limeDeep),
        const SizedBox(height: 4),
        Text(
          item.$2,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowWidth = constraints.maxWidth;
          const gap = 8.0;
          final cardWidth = (rowWidth - gap * 3) / 3;
          final pitch = cardWidth + gap;
          const edgeInset = 4.0;

          return Stack(
            children: [
              // Simultaneous position-swap layer: each content travels inside
              // its OWN card container, so the full card (background + border)
              // slides between slots instead of the text moving over a static
              // container. Non-positioned + explicit height/width so this stays
              // bounded even though the strip sits inside a vertical scroll
              // view (absolutely-positioned children would inherit an infinite
              // maxHeight here and crash layout).
              SizedBox(
                width: rowWidth,
                height: _cardHeight,
                child: IgnorePointer(
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final v = _controller.value;
                        final seg = (v * _items.length).floor();
                        // The wrapping content is drawn first (behind) so its
                        // leftward return pass slides under the two rightward
                        // movers instead of visually colliding with them.
                        final order = [
                          for (var h = 0; h < _items.length; h++)
                            if (((h + seg) % _items.length) ==
                                _items.length - 1)
                              h,
                          for (var h = 0; h < _items.length; h++)
                            if (((h + seg) % _items.length) !=
                                _items.length - 1)
                              h,
                        ];
                        return Stack(
                          children: [
                            for (final h in order)
                              Positioned(
                                left: edgeInset + _itemSlot(h, v) * pitch,
                                top: 0,
                                width: cardWidth,
                                height: _cardHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFD7E6D7)),
                                  ),
                                  child: Center(
                                    child: _buildContent(h),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// CATEGORY BAR
// ==========================================
class TopCategoryBar extends StatefulWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final Function(String) onCategorySelect;

  const TopCategoryBar({
    Key? key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelect,
  }) : super(key: key);

  @override
  State<TopCategoryBar> createState() => _TopCategoryBarState();
}

class _TopCategoryBarState extends State<TopCategoryBar> {
  final ScrollController _scrollController = ScrollController();

  double _iconScaleFor(String id) {
    // Fine-tune these multipliers when assets differ in visible padding.
    const mapping = {
      'laptops': 1.5,
      'earparts': 1.08,
      'mobile': 1.0,
    };
    return mapping[id] ?? 1.0;
  }

  void _onCategorySelected(int index, String id) {
    widget.onCategorySelect(id);

    double itemWidth = 100.0; // Increased to match larger item width
    double screenWidth = MediaQuery.of(context).size.width;
    double targetOffset =
        (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    double maxScroll = _scrollController.position.maxScrollExtent;
    double minScroll = _scrollController.position.minScrollExtent;
    double clampedOffset = targetOffset.clamp(minScroll, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120, // Increased height to prevent overflow with larger icons
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: widget.categories.length,
            itemBuilder: (context, index) {
              final item = widget.categories[index];
              final isSelected = item.id == widget.selectedCategoryId;

              return InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => _onCategorySelected(index, item.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 95, // Increased width per category item
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        transform: Matrix4.translationValues(
                            0, isSelected ? -6.0 : 0.0, 0),
                        child: Builder(builder: (context) {
                          final iconScaleFactor = _iconScaleFor(item.id);
                          final baseScale = isSelected ? 1.12 : 1.0;
                          // Compensate the per-category scale so the fallback
                          // glyph renders at a uniform visual size everywhere.
                          final dummyIconSize = 40 / iconScaleFactor;
                          return AnimatedScale(
                            scale: baseScale * iconScaleFactor,
                            duration: const Duration(milliseconds: 250),
                            child: AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.45,
                              duration: const Duration(milliseconds: 200),
                              child: CachedNetworkImage(
                              imageUrl: item.iconUrl,
                              height: 56,
                              width: 56,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => SizedBox(
                                width: 56,
                                height: 56,
                                child: Icon(Icons.devices,
                                    size: dummyIconSize,
                                    color: const Color(0xFFCCCCCC)),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                  Icons.devices,
                                  size: dummyIconSize,
                                  color: Colors.grey),
                            ),
                            ),
                          );
                        }),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? AppColors.activeTabText
                              : AppColors.inactiveTabText,
                        ),
                        child: Text(item.title),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: isSelected ? 95.0 : 0.0,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.activeTabIndicator
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

// ==========================================
// PRODUCT HORIZONTAL LIST (With Physics)
// ==========================================
class ProductHorizontalList extends StatefulWidget {
  final String categoryId;

  const ProductHorizontalList({Key? key, required this.categoryId})
      : super(key: key);

  @override
  State<ProductHorizontalList> createState() => _ProductHorizontalListState();
}

class _ProductHorizontalListState extends State<ProductHorizontalList> {
  late Future<List<ProductModel>> _futureProducts;

  @override
  void initState() {
    super.initState();
    _futureProducts = _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductHorizontalList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _futureProducts = _loadProducts();
    }
  }

  Future<List<ProductModel>> _loadProducts() async {
    if (widget.categoryId == 'mobile') {
      return _loadAvailableMobileProducts();
    }
    return const [];
  }

  Future<List<ProductModel>> _loadAvailableMobileProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('second_hand_mobiles')
        .where('status', isEqualTo: 'available')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final brand = (data['brand'] ?? '').toString();
      final model = (data['model'] ?? '').toString();
      final photo1Url = (data['photo1Url'] ?? '').toString();
      final rawPrice = data['salePrice'];
      final priceValue = rawPrice is num
          ? '₹ ${rawPrice.toStringAsFixed(0)}'
          : (rawPrice == null
              ? ''
              : rawPrice.toString().startsWith('₹')
                  ? rawPrice.toString()
                  : '₹ $rawPrice');

      return ProductModel(
        id: doc.id,
        categoryId: 'mobile',
        brand: brand,
        title: '$brand $model'.trim(),
        imageUrl: photo1Url,
        featureTag: '',
        discount: '',
        price: priceValue,
        originalPrice: '',
        couponPrice: '',
        rating: '',
        reviewsCount: '',
        documentId: doc.id,
        firestoreData: data,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryId == 'laptops' || widget.categoryId == 'earparts') {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text('Coming soon'),
        ),
      );
    }

    return FutureBuilder<List<ProductModel>>(
      future: _futureProducts,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: Text('No products available in this category'),
            ),
          );
        }

        final products = snapshot.data!;

        // Split products into two rows
        final row1 = <ProductModel>[];
        final row2 = <ProductModel>[];
        for (var i = 0; i < products.length; i++) {
          if (i.isEven) {
            row1.add(products[i]);
          } else {
            row2.add(products[i]);
          }
        }

        const double rowHeight = 310; // Slightly increased for 3D card layout

        return Column(
          children: [
            SizedBox(
              height: rowHeight,
              child: _TiltedProductRow(products: row1),
            ),
            if (row2.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: rowHeight,
                child: _TiltedProductRow(products: row2),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ==========================================
// PHYSICS-DRIVEN SCROLL ROW
// ==========================================
class _TiltedProductRow extends StatefulWidget {
  final List<ProductModel> products;

  const _TiltedProductRow({required this.products});

  @override
  State<_TiltedProductRow> createState() => _TiltedProductRowState();
}

class _TiltedProductRowState extends State<_TiltedProductRow>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  // Physics constraints
  static const double _tiltSensitivity = 0.022;
  static const double _maxTiltDeg = 19.0;
  static const double _springElasticity = 0.40;

  double _currentTiltDeg = 0.0;
  double _tiltVelocity = 0.0;
  double _scrollVelocity = 0.0;

  double _prevOffset = 0.0;
  DateTime _prevTime = DateTime.now();

  // Initialized lazily on first access so it survives hot reload
  // (initState is not re-run by hot reload; State objects are reused).
  late final AnimationController _tiltController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 16),
  )
    ..addListener(_stepPhysics)
    ..repeat();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final now = DateTime.now();
    final dt = now.difference(_prevTime).inMicroseconds / 1e6;

    if (dt > 0.001) {
      final dx = _scrollController.offset - _prevOffset;
      _scrollVelocity = dx / dt;
    }

    _prevOffset = _scrollController.offset;
    _prevTime = now;
  }

  void _stepPhysics() {
    final targetTiltDeg = (-_scrollVelocity * _tiltSensitivity * 0.01)
        .clamp(-_maxTiltDeg, _maxTiltDeg);

    final springForce =
        (targetTiltDeg - _currentTiltDeg) * (_springElasticity * 40);
    _tiltVelocity += springForce * 0.016;
    _tiltVelocity *= 0.82; // damping
    _currentTiltDeg += _tiltVelocity * 0.016;

    if (_scrollController.hasClients &&
        !_scrollController.position.isScrollingNotifier.value) {
      _scrollVelocity *= 0.90; // Decay scroll velocity
    }
  }

  @override
  void dispose() {
    _tiltController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double get _tiltRad => _currentTiltDeg * math.pi / 180.0;

  @override
  Widget build(BuildContext context) {
    // The ListView lives OUTSIDE any animated builder: it is built once.
    // Each visible card wraps its (pre-built) ProductCard child in a
    // ListenableBuilder so only the tiny Transform repaints per frame,
    // keeping images/StreamBuilders untouched during scrolling.
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: widget.products.length,
      itemBuilder: (context, index) {
        return ListenableBuilder(
          listenable: _tiltController,
          child: ProductCard(product: widget.products[index]),
          builder: (context, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(_tiltRad), // physical tilt
              child: child,
            );
          },
        );
      },
    );
  }
}

// ==========================================
// 3D GLOSSY PRODUCT CARD
// ==========================================
class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    Key? key,
    required this.product,
  }) : super(key: key);

  Future<void> _toggleWishlist(BuildContext context) async {
    if (catalogAuth.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }
    try {
      await WishlistService.toggle(
        WishlistItem(
          productId: product.documentId ?? product.id,
          brand: product.brand,
          title: product.title,
          imageUrl: product.imageUrl,
          price: product.price,
          categoryId: product.categoryId,
          snapshot: product.firestoreData,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update wishlist')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFeatureTag = product.featureTag.isNotEmpty;
    final hasDiscount = product.discount.isNotEmpty;
    final hasCoupon = product.couponPrice.isNotEmpty;
    final hasOriginalPrice = product.originalPrice.isNotEmpty;
    final hasRating =
        product.rating.isNotEmpty || product.reviewsCount.isNotEmpty;
    final productId = product.documentId ?? product.id;

    // Apply the 3D Rotation from the physics row (done by the row widget).
    return GestureDetector(
      onTap: () {
        if (product.documentId != null || product.firestoreData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryDetailPlaceholder(
                documentId: product.documentId,
                data: product.firestoreData ??
                    {
                      'id': product.documentId,
                      'brand': product.brand,
                      'model': product.title,
                      'salePrice': product.price,
                    },
              ),
            ),
          );
        }
      },
      child: Container(
        width: 168,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryTheme.withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTheme.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- IMAGE SECTION WITH 3D GLOSSY LIP ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 168,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4FBF4),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      topRight: Radius.circular(19),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(19),
                      topRight: Radius.circular(19),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                  child: Icon(Icons.devices,
                                      size: 50, color: Colors.grey)),
                        ),
                        // THE 3D GLOSSY LIP GRADIENT
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60, // Height of the lip effect
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.65, 0.95, 1.0],
                                colors: [
                                  Colors.transparent,
                                  AppColors.primaryTheme.withOpacity(0.04),
                                  AppColors.primaryTheme.withOpacity(0.25),
                                  AppColors.primaryTheme
                                      .withOpacity(0.65), // Sharp edge
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Wishlist Button
                Positioned(
                  top: 8,
                  right: 8,
                  child: StreamBuilder<User?>(
                    stream: catalogAuth.authStateChanges(),
                    builder: (context, authSnap) {
                      final signedIn = authSnap.data != null;
                      return StreamBuilder<bool>(
                        stream: signedIn
                            ? WishlistService.watchIsSaved(productId)
                            : Stream.value(false),
                        builder: (context, wishSnap) {
                          final saved = wishSnap.data == true;
                          return Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _toggleWishlist(context),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  saved
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color: saved
                                      ? const Color(0xFFE11D48)
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // --- TEXT CONTENT SECTION ---
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF4A5A4A), fontSize: 12),
                  ),
                  if (hasFeatureTag) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.featureTag,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black87),
                      ),
                    ),
                  ],
                  if (hasDiscount) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.discount,
                      style: const TextStyle(
                        color: AppColors.limeDeep,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.price,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (hasOriginalPrice) ...[
                        const SizedBox(width: 4),
                        Text(
                          product.originalPrice,
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasCoupon) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.couponPrice,
                            style: const TextStyle(
                              color: AppColors.onPrimarySoft,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.local_offer,
                              size: 10, color: AppColors.onPrimarySoft),
                        ],
                      ),
                    ),
                  ],
                  if (hasRating) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 12, color: AppColors.primaryTheme),
                        const SizedBox(width: 2),
                        Text(
                          product.rating,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' (${product.reviewsCount})',
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HOME FOOTER
// ==========================================
class HomeFooter extends StatelessWidget {
  const HomeFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryTheme,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android,
                    color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CellCycle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Certified Pre-Owned Devices',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _footerLink(Icons.call_outlined, 'Contact'),
              _footerLink(Icons.chat_bubble_outline, 'WhatsApp'),
              _footerLink(Icons.email_outlined, 'Email'),
              _footerLink(Icons.policy_outlined, 'Policy'),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              '© 2026 CellCycle. All rights reserved.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _footerLink(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primaryTheme, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// ANIMATED SEARCH BAR & BANNER SLIDER
// ==========================================
// ==========================================
// ANIMATED SEARCH BAR
// ==========================================
class AnimatedSearchBar extends StatefulWidget {
  const AnimatedSearchBar({Key? key}) : super(key: key);

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<String> _searchKeywords = [
    'phones',
    'laptops',
    'earbuds',
    'iPhone',
    'Samsung',
  ];

  String _currentDisplayedText = '';
  int _keywordIndex = 0;
  int _characterIndex = 0;
  bool _isDeleting = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _startTypewriterAnimation();

    _searchController.addListener(() {
      setState(() {});
    });

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  void _startTypewriterAnimation() {
    _animationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_searchController.text.isNotEmpty || _focusNode.hasFocus) {
        return;
      }

      final currentFullWord = _searchKeywords[_keywordIndex];

      if (mounted) {
        setState(() {
          if (!_isDeleting) {
            _currentDisplayedText =
                currentFullWord.substring(0, _characterIndex);
            _characterIndex++;

            if (_characterIndex > currentFullWord.length) {
              _isDeleting = true;
              _animationTimer?.cancel();
              Timer(const Duration(seconds: 2), () {
                if (mounted) _startTypewriterAnimation();
              });
            }
          } else {
            _characterIndex--;
            _currentDisplayedText =
                currentFullWord.substring(0, _characterIndex);

            if (_characterIndex == 0) {
              _isDeleting = false;
              _keywordIndex = (_keywordIndex + 1) % _searchKeywords.length;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool showAnimatedHint =
        _searchController.text.isEmpty && !_focusNode.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.searchBarBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33008A00)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.black, fontSize: 14),
          decoration: InputDecoration(
            hintText: showAnimatedHint
                ? 'Search for "$_currentDisplayedText"'
                : 'Search...',
            hintStyle: TextStyle(
              color:
                  showAnimatedHint ? Colors.black87 : AppColors.searchBarHint,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.searchBarIcon,
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

class PromoBannerSlider extends StatefulWidget {
  const PromoBannerSlider({Key? key}) : super(key: key);

  @override
  State<PromoBannerSlider> createState() => _PromoBannerSliderState();
}

class _PromoBannerSliderState extends State<PromoBannerSlider> {
  int _currentIndex = 0;
  Timer? _timer;
  final PageController _pageController = PageController(viewportFraction: 0.92);

  final List<_PromoSlideData> banners = const [
    _PromoSlideData(
      eyebrow: 'Certified pre-owned',
      title: 'Phones you can trust',
      subtitle: 'Checked battery, display & body.',
      start: Color(0xFF101910),
      end: Color(0xFF1F3A1F),
      accent: Color(0xFF32CD32),
    ),
    _PromoSlideData(
      eyebrow: 'Sell in minutes',
      title: 'Get a fair quote',
      subtitle: 'Doorstep pickup after you accept.',
      start: Color(0xFF1FA81F),
      end: Color(0xFF32CD32),
      accent: Color(0xFF101910),
    ),
    _PromoSlideData(
      eyebrow: 'Save for later',
      title: 'Wishlist a phone',
      subtitle: 'Come back when you are ready.',
      start: Color(0xFF163016),
      end: Color(0xFF0E1A0E),
      accent: Color(0xFF7CFF7C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_pageController.hasClients) {
        int nextIndex = (_currentIndex + 1) % banners.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final slide = banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [slide.start, slide.end],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -18,
                          bottom: -24,
                          child: Icon(
                            Icons.smartphone,
                            size: 110,
                            color: slide.accent.withOpacity(0.30),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: slide.accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                slide.eyebrow,
                                style: TextStyle(
                                  color: slide.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              slide.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              slide.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 8,
              width: _currentIndex == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? AppColors.limeDeep
                    : const Color(0xFF9AB59A),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoSlideData {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color start;
  final Color end;
  final Color accent;

  const _PromoSlideData({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.start,
    required this.end,
    required this.accent,
  });
}
