/// "cb 203", "CB-203", " cb203 " -> "CB203" (same rule as the web app).
String normalizeRoomCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Letters followed by digits (optionally one trailing letter), e.g. CB203, LIB1, LAB2A.
bool looksLikeRoomCode(String input) =>
    RegExp(r'^[A-Z]{1,5}\d{1,4}[A-Z]?$').hasMatch(normalizeRoomCode(input));
