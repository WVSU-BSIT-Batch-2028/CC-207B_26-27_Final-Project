// Test version (no browser): keeps the signed-in ID in memory
String? _founderId;

String? readFounderId() => _founderId;

void writeFounderId(String? id) => _founderId = id;
