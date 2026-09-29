import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/widgets/app_badge.dart';

/// Where a pickup order has got to.
///
/// The orders list and the tracker both need this and each used to carry its
/// own copy — one mapping the status to a label and a tone, the other to a
/// step number. Two tables describing the same states will eventually
/// disagree, and the place that shows a seller their order is a bad place for
/// that to happen.
enum OrderStage {
  placed,
  agentAssigned,
  inspection,
  paid,

  /// The seller refused the amount the agent settled on, so the phone was not
  /// collected.
  ///
  /// Deliberately last, and deliberately not part of the progression: it is
  /// where an order stops, not a step it passes through. Everything below that
  /// counts or numbers stages skips it, or a perfectly ordinary order would
  /// show a five-step timeline it can never finish.
  declined;

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
      case 'declined':
        return OrderStage.declined;
      case 'placed':
      default:
        return OrderStage.placed;
    }
  }

  /// The stages an order passes through, in order. [declined] is not one.
  static List<OrderStage> get journey =>
      const [placed, agentAssigned, inspection, paid];

  /// How many stages there are, for a progress indicator.
  static int get count => journey.length;

  /// 1-based position, matching the tracker's own numbering.
  ///
  /// A declined order stopped at inspection — that is where the disagreement
  /// happened — so it reports that step rather than an index past the end of
  /// the tracker.
  int get step =>
      this == declined ? inspection.index + 1 : index + 1;

  /// Whether the order is finished, either way.
  bool get isFinished => this == paid || this == declined;

  bool get isComplete => this == OrderStage.paid;

  /// Finished without the seller being paid.
  bool get isDeclined => this == declined;

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
      case OrderStage.declined:
        return 'Offer declined';
    }
  }

  /// Green when paid, red when declined, amber while something is still owed.
  ///
  /// The distinction that matters to a seller is "is my money here yet", so
  /// the stages before payment share a colour rather than each having their
  /// own — a palette of four tells them nothing extra.
  ///
  /// Declined earns its own colour where the other three do not: amber says
  /// "still going", and an order that has stopped must not look like one that
  /// is merely waiting.
  Color get color {
    if (isComplete) return AppColors.success;
    if (isDeclined) return AppColors.error;
    return AppColors.warning;
  }

  AppBadgeTone get tone {
    if (isComplete) return AppBadgeTone.success;
    if (isDeclined) return AppBadgeTone.error;
    return AppBadgeTone.warning;
  }
}
