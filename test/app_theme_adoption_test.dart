// The design system has to be applied by MaterialApp, not by each screen.
//
// Screens that wrap themselves in AppTheme.light look right either way; the
// ones that never did — the whole checkup flow — inherit whatever MaterialApp
// carries, which is what made them look like a different app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/main.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';

void main() {
  testWidgets('MyApp applies the design system theme globally', (t) async {
    await t.pumpWidget(const MyApp(home: SizedBox.shrink()));

    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, isNotNull);
    expect(app.theme!.scaffoldBackgroundColor, AppColors.background,
        reason: 'the page ground is #F7F8F8, not white');
    expect(app.theme!.colorScheme.onPrimary, AppColors.onPrimary,
        reason: 'buttons carry white on brand green, not black');
    expect(app.theme!.colorScheme.primary, AppColors.primary);
  });

  testWidgets('a screen with no local Theme wrapper inherits it', (t) async {
    await t.pumpWidget(
      MyApp(
        home: Builder(
          builder: (context) => Text(
            '${Theme.of(context).scaffoldBackgroundColor.toARGB32()}',
          ),
        ),
      ),
    );

    expect(find.text('${AppColors.background.toARGB32()}'), findsOneWidget,
        reason: 'the checkup pages carry no wrapper of their own');
  });
}
