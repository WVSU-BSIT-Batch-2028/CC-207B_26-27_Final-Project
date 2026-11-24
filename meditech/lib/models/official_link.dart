// Configurable external link (e.g. FDA LTO verification), stored in Supabase
class OfficialPortalLink {
  const OfficialPortalLink({required this.label, required this.url});

  final String label;
  final String url;

  factory OfficialPortalLink.fromJson(Map<String, dynamic> json) => OfficialPortalLink(
        label: json['label'] as String,
        url: json['url'] as String,
      );
}