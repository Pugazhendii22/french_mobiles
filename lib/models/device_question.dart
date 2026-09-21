/// One yes/no question asked before the physical checklist.
///
/// Read from `deduction_rules/device_questions` rather than written into the
/// app, so the wording and the price of each fault stay editable without a
/// release — the same arrangement as every other deduction rule.
class DeviceQuestion {
  const DeviceQuestion({
    required this.question,
    required this.help,
    required this.label,
    required this.percent,
    required this.deductOnYes,
  });

  /// What the seller is asked.
  final String question;

  /// The smaller line underneath, explaining how to check.
  final String help;

  /// How the fault is named on the quote — "Network / SIM Issue". Kept
  /// separate from [question] because a question reads as a question and a
  /// receipt line has to read as a fault.
  final String label;

  final int percent;

  /// Which answer costs money. Almost every question is phrased so that "no"
  /// is the bad answer, but "has this phone ever had water damage?" inverts
  /// it, and phrasing every question negatively to avoid the flag would be
  /// worse to read.
  final bool deductOnYes;

  double get fraction => percent / 100;

  /// Whether [answer] is the one that costs money.
  bool isFaultFor(bool answer) => answer == deductOnYes;

  static DeviceQuestion? fromMap(Map<String, dynamic> raw) {
    final question = (raw['question'] ?? '').toString().trim();
    final label = (raw['label'] ?? '').toString().trim();
    if (question.isEmpty || label.isEmpty) return null;

    final rawPercent = raw['percent'];
    final percent = rawPercent is num
        ? rawPercent.round()
        : int.tryParse('$rawPercent') ?? 0;

    return DeviceQuestion(
      question: question,
      help: (raw['help'] ?? '').toString(),
      label: label,
      percent: percent,
      deductOnYes: (raw['deduct_on'] ?? 'no').toString().toLowerCase() == 'yes',
    );
  }
}

/// A question together with what the seller said.
class DeviceAnswer {
  const DeviceAnswer({required this.question, required this.answeredYes});

  final DeviceQuestion question;
  final bool answeredYes;

  bool get isFault => question.isFaultFor(answeredYes);
}
