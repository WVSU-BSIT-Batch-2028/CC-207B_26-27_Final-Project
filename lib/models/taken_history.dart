/// The days on which a patient marked one prescription as taken.
///
/// Plain data: no widgets and no storage code. Used by the "Doses taken" card
/// on the History Details screen.
class TakenHistory {
  /// Creates the history from [days]: dates only, newest first, no duplicates
  /// (the service prepares the list that way).
  const TakenHistory(this.days);

  final List<DateTime> days;

  /// How many different days a dose was marked as taken.
  int get takenCount => days.length;

  /// The most recent [count] days (the list is already newest first).
  List<DateTime> recent([int count = 5]) => days.take(count).toList();
}
