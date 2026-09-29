// Where a pickup order has got to.
//
// The orders list and the tracker each carried their own copy of this — one
// mapping the status to a label and a tone, the other to a step number. Two
// tables describing the same four states will eventually disagree, and the
// screen that tells a seller where their money is is a bad place for that.
import 'package:flutter_test/flutter_test.dart';
import 'package:french_mobiles/models/order_status.dart';
import 'package:french_mobiles/shared/theme/app_colors.dart';
import 'package:french_mobiles/shared/widgets/app_badge.dart';

void main() {
  test('each stored status maps to its stage', () {
    expect(OrderStage.fromStatus('placed'), OrderStage.placed);
    expect(OrderStage.fromStatus('agent_assigned'), OrderStage.agentAssigned);
    expect(OrderStage.fromStatus('inspection'), OrderStage.inspection);
    expect(OrderStage.fromStatus('paid'), OrderStage.paid);
  });

  test('an unknown status shows the order rather than losing it', () {
    // A status added on the server before the app knows about it.
    expect(OrderStage.fromStatus('awaiting_courier'), OrderStage.placed);
    expect(OrderStage.fromStatus(null), OrderStage.placed);
    expect(OrderStage.fromStatus(''), OrderStage.placed);
  });

  test('the steps match the tracker numbering', () {
    expect(OrderStage.placed.step, 1);
    expect(OrderStage.agentAssigned.step, 2);
    expect(OrderStage.inspection.step, 3);
    expect(OrderStage.paid.step, 4);
    expect(OrderStage.count, 4);
  });

  test('only paid counts as complete', () {
    for (final stage in OrderStage.values) {
      expect(stage.isComplete, stage == OrderStage.paid);
    }
  });

  test('amber until the money arrives, then green', () {
    // The question a seller is asking is whether they have been paid, so the
    // three stages before payment share a colour — four different ones would
    // say nothing extra.
    expect(OrderStage.placed.color, AppColors.warning);
    expect(OrderStage.agentAssigned.color, AppColors.warning);
    expect(OrderStage.inspection.color, AppColors.warning);
    expect(OrderStage.paid.color, AppColors.success);

    expect(OrderStage.paid.tone, AppBadgeTone.success);
    expect(OrderStage.placed.tone, AppBadgeTone.warning);
  });

  test('every stage has a label a seller can read', () {
    for (final stage in OrderStage.values) {
      expect(stage.label, isNotEmpty);
      expect(stage.label, isNot(stage.name),
          reason: 'agentAssigned is not something to show anyone');
    }
  });
}
