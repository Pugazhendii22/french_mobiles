import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_badge.dart';

/// Where a pickup order has got to.
///
/// The orders list and the tracker both need this and each used to carry its
/// own copy — one mapping the status to a label and a tone, the other to a
/// step number. Two tables describing the same four states will eventually
/// disagree, and the place that shows a seller their order is a bad place for
/// that to happen.
enum OrderStage {
  placed,
  agentAssigned,
  inspection,
  paid;

  /// Reads the `status` field written on the order document.
  ///
  /// An unrecognised value — a status added on the server before the app
  /// knows about it — reads as [placed] rather than throwing, because the
  /// order still exists and still has to be shown.
  static OrderStage fromStatus(String? status) {
    switch (status) {
      case 'agent_assigned':
        return OrderStage.agentAssigned;
      case 'inspection':
        return OrderStage.inspection;
      case 'paid':
        return OrderStage.paid;
      case 'placed':
      default:
        return OrderStage.placed;
    }
  }

  /// How many stages there are, for a progress indicator.
  static int get count => OrderStage.values.length;

  /// 1-based position, matching the tracker's own numbering.
  int get step => index + 1;

  bool get isComplete => this == OrderStage.paid;

  String get label {
    switch (this) {
      case OrderStage.placed:
        return 'Order placed';
      case OrderStage.agentAssigned:
        return 'Agent assigned';
      case OrderStage.inspection:
        return 'Under inspection';
      case OrderStage.paid:
        return 'Completed & paid';
    }
  }

  /// Amber while something is still owed, green once it is not.
  ///
  /// The distinction that matters to a seller is "is my money here yet", so
  /// the three stages before payment share a colour rather than each having
  /// their own — a palette of four tells them nothing extra.
  Color get color =>
      isComplete ? AppColors.success : AppColors.warning;

  AppBadgeTone get tone =>
      isComplete ? AppBadgeTone.success : AppBadgeTone.warning;
}
