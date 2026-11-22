import 'package:flutter_riverpod/flutter_riverpod.dart';

// Which tab the customer shell is showing: 0 home, 1 search, 2 reservations, 3 profile
class CustomerTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) {
    state = index;
  }
}

final customerTabProvider = NotifierProvider<CustomerTabNotifier, int>(
  CustomerTabNotifier.new,
);
