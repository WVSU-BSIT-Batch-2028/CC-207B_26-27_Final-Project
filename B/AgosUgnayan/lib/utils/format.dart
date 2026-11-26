// Small helpers that turn numbers and dates into text for the screen,
// e.g. 45 -> "₱45.00" and a date -> "Aug 21, 2026".

import 'package:intl/intl.dart';

/// Formats a price in pesos, e.g. 45 -> "₱45.00".
String formatPeso(double amount) {
  return NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(amount);
}

/// Formats a quantity without useless decimals, e.g. 50.0 -> "50", 2.5 -> "2.5".
String formatQuantity(double quantity) {
  if (quantity == quantity.roundToDouble()) return quantity.toInt().toString();
  return quantity.toString();
}

/// Formats a date like "Aug 21, 2026".
String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

/// Formats a short time for chat bubbles, e.g. "3:45 PM".
String formatTime(DateTime date) => DateFormat.jm().format(date);

/// Turns a month key like "2026-08" into "Aug 2026".
String formatMonthKey(String monthKey) {
  final date = DateTime.parse('$monthKey-01');
  return DateFormat.yMMM().format(date);
}

/// Turns a date into a month key like "2026-08". Prices are saved per month.
String monthKeyOf(DateTime date) => DateFormat('yyyy-MM').format(date);
