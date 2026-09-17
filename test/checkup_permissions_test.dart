// The checkup asks for everything it needs once, up front.
//
// Before this, each test requested its own permission on its first frame, so
// a full run interrupted the user five separate times — several tests deep,
// with no explanation attached to any of them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/screens/checkup/checkup_entry_page.dart';
import 'package:french_mobiles/screens/checkup/checkup_permissions.dart';
import 'package:french_mobiles/screens/checkup/multitouch_test_page.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'support/fake_permission_handler.dart';

const _stand = [
  CheckupTestSpec(
    key: 'stand',
    title: 'Stand-in test',
    description: 'Drives no hardware',
    icon: Icons.check,
    pageBuilder: _standIn,
  ),
];

Widget _standIn(BuildContext context) => const MultitouchTestPage();

Future<void> _boot(WidgetTester t) async {
  t.view.physicalSize = const Size(400, 800);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(const MaterialApp(home: CheckupEntryPage(tests: _stand)));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  group('what the checkup asks for', () {
    test('every need carries a label and a reason the user can act on', () {
      expect(CheckupPermissions.needs, isNotEmpty);
      for (final need in CheckupPermissions.needs) {
        expect(need.label, isNotEmpty);
        expect(need.reason, isNotEmpty,
            reason: '${need.label} needs a why; Android gives none');
      }
    });

    test('no permission is listed twice', () {
      final permissions =
          CheckupPermissions.needs.map((n) => n.permission).toList();
      expect(permissions.toSet().length, permissions.length);
    });

    test('covers every permission the test pages request', () {
      final asked = CheckupPermissions.needs.map((n) => n.permission).toSet();
      // Gathered by reading the request() calls in the test pages.
      for (final required in [
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.nearbyWifiDevices,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.phone,
      ]) {
        expect(asked, contains(required));
      }
    });
  });

  group('asking up front', () {
    testWidgets('nothing outstanding means no sheet and a straight start',
        (t) async {
      final permissions = FakePermissionHandler();
      PermissionHandlerPlatform.instance = permissions;

      await _boot(t);
      await t.tap(find.text('Start Checkup'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      expect(find.text('Before we start'), findsNothing,
          reason: 'explaining permissions already granted is just a nag');
      expect(find.byType(MultitouchTestPage), findsOneWidget);
    });

    testWidgets('outstanding permissions are explained before being asked for',
        (t) async {
      PermissionHandlerPlatform.instance =
          FakePermissionHandler(initial: PermissionStatus.denied);

      await _boot(t);
      await t.tap(find.text('Start Checkup'));
      await t.pumpAndSettle();

      expect(find.text('Before we start'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Microphone'), findsOneWidget);
      expect(find.byType(MultitouchTestPage), findsNothing,
          reason: 'the run waits until the user has answered');
    });

    testWidgets('continuing asks for all of them in one go', (t) async {
      final permissions =
          FakePermissionHandler(initial: PermissionStatus.denied);
      PermissionHandlerPlatform.instance = permissions;

      await _boot(t);
      await t.tap(find.text('Start Checkup'));
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));

      expect(permissions.requests, hasLength(1),
          reason: 'one batch, not one prompt per test');
      expect(permissions.requests.single,
          hasLength(CheckupPermissions.needs.length));
      expect(find.byType(MultitouchTestPage), findsOneWidget,
          reason: 'the run starts once the prompts are done');
    });

    testWidgets('Not now abandons the run without asking for anything',
        (t) async {
      final permissions =
          FakePermissionHandler(initial: PermissionStatus.denied);
      PermissionHandlerPlatform.instance = permissions;

      await _boot(t);
      await t.tap(find.text('Start Checkup'));
      await t.pumpAndSettle();
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();

      expect(permissions.requests, isEmpty);
      expect(find.byType(MultitouchTestPage), findsNothing);
      expect(find.text('Start Checkup'), findsOneWidget,
          reason: 'backing out should leave the list ready to start again');
    });

    testWidgets('a permanently denied permission is not promised a prompt',
        (t) async {
      PermissionHandlerPlatform.instance = FakePermissionHandler(
        initial: PermissionStatus.permanentlyDenied,
      );

      final outstanding = await CheckupPermissions.outstanding();
      expect(outstanding, isEmpty,
          reason: 'asking again shows nothing; the test itself offers '
              'settings instead');
    });

    testWidgets('running a single test does not trigger the sheet', (t) async {
      final permissions =
          FakePermissionHandler(initial: PermissionStatus.denied);
      PermissionHandlerPlatform.instance = permissions;

      await _boot(t);
      await t.tap(find.text('Drives no hardware'));
      await t.pumpAndSettle();

      expect(find.text('Before we start'), findsNothing);
      expect(find.byType(MultitouchTestPage), findsOneWidget,
          reason: 'one test asks for its own, as it always did');
    });
  });
}
