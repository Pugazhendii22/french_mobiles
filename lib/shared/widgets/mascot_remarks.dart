import 'dart:math';

/// What the mascot has to say for itself.
///
/// Kept apart from the widget and free of any state of its own, so the lines
/// can be read, argued about and tested without pumping a frame.
///
/// The voice is one thing throughout: a small creature with two rectangles
/// for legs, obliged to walk along the bottom of someone else's app, who has
/// noticed what time it is and would like that acknowledged. It is funnier
/// when it is put upon than when it is cheerful, and funnier still when it is
/// occasionally, grudgingly useful.
class MascotRemarks {
  const MascotRemarks._();

  /// Practical things worth saying, mixed in so it is not only a comedian.
  static const List<String> advice = [
    'Answer the questions honestly. The agent checks the phone at pickup '
        'anyway, and surprises there slow your money down.',
    'Run the automatic checkup. It takes a few minutes and it proves the '
        'phone works, which is worth more than you saying it does.',
    'The box and the charger are real money. Go and look in the drawer. '
        'I will wait. I am always here.',
    'A cracked screen still sells. Say so up front and nobody has to have an '
        'awkward conversation on your doorstep.',
    'Your quote is held for a week. No rush. I have nowhere to be either.',
  ];

  /// Everything it could reasonably say right now.
  ///
  /// Returned as a list rather than a single line so the choice stays with
  /// the caller — and so a test can check that a Sunday actually produces
  /// something about Sundays, without depending on a dice roll.
  static List<String> candidates({
    required DateTime now,
    required Duration walked,
    required int thrown,
    required int bumps,
  }) {
    final lines = <String>[];
    final time = clockOf(now);

    // --- what time it is ---------------------------------------------------
    if (now.hour >= 23 || now.hour < 5) {
      lines.addAll([
        'It is $time. You are valuing a phone at $time. I am not judging. '
            'I am also awake.',
        'Everyone sensible is asleep. I am walking along a bar. This is fine.',
        'Nothing good is decided at $time. Except possibly this. Carry on.',
      ]);
    } else if (now.hour < 8) {
      lines.addAll([
        'You are up early. I never went to bed. There is no bed.',
        'I watched the sun come up. From here. While walking.',
      ]);
    } else if (now.hour < 12) {
      lines.addAll([
        'Morning. I have already done about forty laps of this bar.',
        'You have had a coffee. I have had a wall.',
      ]);
    } else if (now.hour < 17) {
      lines.addAll([
        'Afternoon. Still walking. Still nobody has offered me a chair.',
        'It is $time and I have been going since you opened this.',
      ]);
    } else {
      lines.addAll([
        'Evening. My legs are two small rectangles and they are done.',
        'It is $time. Sell the phone. Go and eat something.',
      ]);
    }

    // --- what day it is ----------------------------------------------------
    switch (now.weekday) {
      case DateTime.saturday:
        lines.addAll([
          'It is Saturday. Weekends are for people whose legs stop.',
          'Saturday. You get one of these. I get the bar.',
        ]);
      case DateTime.sunday:
        lines.addAll([
          'Sunday. Everybody gets a day off except the one drawn into the app.',
          'It is Sunday. A day of rest, for some of us. Not for me. I am here.',
        ]);
      case DateTime.monday:
        lines.add(
            'Monday. I worked the whole weekend so that you would not have to.');
      case DateTime.friday:
        lines.add(
            'Friday. You will go out. I will be here. On this bar. Walking.');
      default:
        break;
    }

    // --- how long it has been at it ---------------------------------------
    final minutes = walked.inMinutes;
    if (minutes >= 2) {
      lines.add('I have been walking for $minutes minutes. At my size that is '
          'a respectable distance. Possibly a record. Nobody is measuring.');
    }
    if (minutes >= 10) {
      lines.add('$minutes minutes. Do you know how far that is? Neither do I. '
          'There is no map of this app.');
    }

    // --- how it has been treated ------------------------------------------
    if (thrown == 1) {
      lines.add('You threw me. I saw you do it. We both know.');
    } else if (thrown >= 2) {
      lines.add('That is $thrown times you have thrown me. I am counting. '
          'I have nothing else to count.');
    }
    if (bumps >= 2) {
      lines.add('I have hit that wall $bumps times now. It has not moved. '
          'I keep checking.');
    }

    lines.addAll(advice);
    return lines;
  }

  /// One remark, avoiding [previous] so it never says the same thing twice
  /// in a row.
  static String pick({
    required DateTime now,
    required Duration walked,
    required int thrown,
    required int bumps,
    required Random random,
    String? previous,
  }) {
    final all = candidates(
      now: now,
      walked: walked,
      thrown: thrown,
      bumps: bumps,
    );
    final fresh = all.where((line) => line != previous).toList();
    final from = fresh.isEmpty ? all : fresh;
    return from[random.nextInt(from.length)];
  }

  /// "2am", "11pm" — how a person says the time out loud.
  static String clockOf(DateTime now) {
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    return '$hour${now.hour < 12 ? 'am' : 'pm'}';
  }
}
