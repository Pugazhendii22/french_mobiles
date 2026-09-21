// Verifies the navigation contract after an order is placed.
//
// OrderTrackingPage itself reads catalogFirestore during build, so it cannot
// be pumped without a configured Firebase app. What matters for this bug is
// the STACK behaviour, which is exercised here against real routes using the
// exact call pickup_checkout_page makes: pushAndRemoveUntil with
// (route) => route.isFirst.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/shared/motion/motion.dart';

class _Screen extends StatelessWidget {
  const _Screen(this.name, {this.onNext});
  final String name;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            if (onNext != null)
              TextButton(onPressed: onNext, child: const Text('next')),
          ],
        ),
      ),
    );
  }
}

/// Stands in for the confirmation screen: same PopScope contract.
class _Confirmation extends StatelessWidget {
  const _Confirmation();

  @override
  Widget build(BuildContext context) {
    void goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goHome();
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Order confirmed'),
              TextButton(onPressed: goHome, child: const Text('Go to home')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds Home -> Sell -> Checkout, the real depth at order placement.
Future<void> _buildCheckoutStack(WidgetTester t) async {
  await t.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => _Screen(
        'Home',
        onNext: () => context.pushScreen(
          Builder(
            builder: (context) => _Screen(
              'Sell',
              onNext: () => context.pushScreen(
                Builder(
                  builder: (context) => _Screen(
                    'Checkout',
                    // The exact call pickup_checkout_page makes.
                    onNext: () => Navigator.of(context).pushAndRemoveUntil(
                      AppPageRoute<void>(
                        builder: (_) => const _Confirmation(),
                        transition: AppTransition.fadeThrough,
                      ),
                      (route) => route.isFirst,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.pumpAndSettle();

  await t.tap(find.text('next')); // Home -> Sell
  await t.pumpAndSettle();
  await t.tap(find.text('next')); // Sell -> Checkout
  await t.pumpAndSettle();
  expect(find.text('Checkout'), findsOneWidget);
}

void main() {
  testWidgets('placing an order removes the whole checkout flow', (t) async {
    await _buildCheckoutStack(t);

    await t.tap(find.text('next')); // place order
    await t.pumpAndSettle();

    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
    expect(find.text('Sell'), findsNothing);
  });

  testWidgets('system back from confirmation goes to home, not checkout',
      (t) async {
    await _buildCheckoutStack(t);
    await t.tap(find.text('next'));
    await t.pumpAndSettle();

    // The hardware / gesture back.
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
  });

  testWidgets('repeated back never reaches checkout', (t) async {
    await _buildCheckoutStack(t);
    await t.tap(find.text('next'));
    await t.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Checkout'), findsNothing,
          reason: 'checkout reachable again after ${i + 1} back press(es)');
      expect(find.text('Sell'), findsNothing,
          reason: 'sell flow reachable again after ${i + 1} back press(es)');
    }

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Go to home button lands on home', (t) async {
    await _buildCheckoutStack(t);
    await t.tap(find.text('next'));
    await t.pumpAndSettle();

    await t.tap(find.text('Go to home'));
    await t.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);
  });
}
