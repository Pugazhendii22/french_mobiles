/// Maps a measured battery health percentage onto one of the wizard's bands.
///
/// The bands come from `deduction_rules/battery_health` in Firestore and are
/// meant to be editable — "95-100%+ Battery Health", "70-79% Battery Health",
/// "Below 70% Health". So the match is made by reading the numbers out of the
/// label rather than by position: an index would break the moment somebody
/// reordered the list in the admin panel, and it would break silently, on the
/// figure that decides up to a third of what a seller is paid.
///
/// Returns the index of the matching label, or null when nothing covers
/// [health] — in which case the seller is left to choose, as before.
int? batteryBandFor(int health, List<String> labels) {
  final digits = RegExp(r'\d+');

  for (var i = 0; i < labels.length; i++) {
    final label = labels[i];
    final numbers =
        digits.allMatches(label).map((m) => int.parse(m.group(0)!)).toList();
    if (numbers.isEmpty) continue;

    final lower = label.toLowerCase();

    // "Below 70% Health" — everything under the single number.
    if (lower.contains('below') || lower.contains('under')) {
      if (health < numbers.first) return i;
      continue;
    }

    // "70-79% Battery Health" — an inclusive range. Read as min and max
    // rather than first and second, so "100-95%" works as well as "95-100%".
    if (numbers.length >= 2) {
      final low = numbers.reduce((a, b) => a < b ? a : b);
      final high = numbers.reduce((a, b) => a > b ? a : b);
      if (health >= low && health <= high) return i;
      continue;
    }

    // A single number with no qualifier, as in "95%+" — treated as a floor.
    if (health >= numbers.first) return i;
  }

  return null;
}

/// A rough capacity estimate from the charge cycle count.
///
/// Android exposes no state-of-health figure at any API level, but from
/// Android 14 it does report cycles — and cycles are what actually wear a
/// cell out. Lithium-ion cells are specified by their manufacturers to retain
/// about 80% of capacity after 500 full cycles, which is the line this
/// follows: 100% at zero, sliding to 80% at 500 and onwards from there.
///
/// This is an **estimate from a real measurement**, not a measurement of
/// health. Anything built on it has to say so — the number moves money, and a
/// cell that has been fast-charged hot for 400 cycles is in worse shape than
/// one gently cycled 600 times. Treated as a starting point for the seller to
/// correct, never as a verdict.
int estimatedHealthFromCycles(int cycles) {
  if (cycles <= 0) return 100;
  final estimate = 100 - (cycles / 500 * 20);
  return estimate.round().clamp(1, 100);
}
