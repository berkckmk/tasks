import 'habit.dart';

/// Whether a habit is scheduled on a given date, read off its
/// [Habit.frequencyLabel].
///
/// The dashboard used to count *every* habit against today, regardless of
/// schedule — so a Weekly habit inflated "today's" denominator six days out of
/// seven and the number on the ring was quietly wrong. This is the derivation
/// the redesign's "Today's habits" section needs and the code did not compute.
///
/// `frequencyLabel` is a free-text field on the Firestore document, and the
/// picker offers exactly five values. Only two of them name specific days:
///
///  - **Daily** — every day.
///  - **Weekdays** — Monday to Friday.
///
/// The other three (**Weekly**, **3x / week**, **5x / week**) state a *count*
/// per week and no days at all. There is nowhere in the data model that
/// records which days those fall on, so this cannot invent one: a
/// count-per-week habit is treated as schedulable on any day, which is the
/// honest reading of "3 times a week" and matches how the user would
/// interpret an unticked row. What it must not do is silently drop them from
/// today's list, since the user may well intend to do one now.
///
/// An unrecognised label — an older document, or a value typed before the
/// picker existed — also counts as scheduled. Hiding a habit because its
/// frequency string is unfamiliar is the worse failure.
extension HabitSchedule on Habit {
  bool isScheduledOn(DateTime date) => _isScheduled(frequencyLabel, date);

  /// True only for the labels that pin a habit to particular days —
  /// i.e. where "scheduled on other days" is a meaningful thing to say.
  bool get hasFixedDays => _hasFixedDays(frequencyLabel);
}

bool _hasFixedDays(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized == 'weekdays';
}

bool _isScheduled(String label, DateTime date) {
  switch (label.trim().toLowerCase()) {
    case 'daily':
      return true;
    case 'weekdays':
      return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
    default:
      // Weekly, 3x / week, 5x / week and anything unrecognised. See the doc
      // above: no day information exists to filter on.
      return true;
  }
}
