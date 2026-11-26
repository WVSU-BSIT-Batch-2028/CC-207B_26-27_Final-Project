class Startup {
  Startup({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.description,
    required this.industry,
    required this.stage,
    required this.teamSize,
    required this.offerText,
    required this.needText,
    required this.offers,
    required this.needs,
    required this.savedIds,
  });

  String id;
  String email;
  String password;
  String name;
  String description;
  String industry;
  String stage;
  int teamSize;
  String offerText;
  String needText;
  List<String> offers;
  List<String> needs;
  List<String> savedIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'password': password,
    'name': name,
    'description': description,
    'industry': industry,
    'stage': stage,
    'teamSize': teamSize,
    'offerText': offerText,
    'needText': needText,
    'offers': offers,
    'needs': needs,
    'savedIds': savedIds,
  };

  factory Startup.fromJson(Map<String, dynamic> json) => Startup(
    id: json['id'] as String,
    email: json['email'] as String,
    password: json['password'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    industry: json['industry'] as String,
    stage: json['stage'] as String,
    teamSize: json['teamSize'] as int,
    offerText: json['offerText'] as String,
    needText: json['needText'] as String,
    offers: List<String>.from(json['offers'] as List),
    needs: List<String>.from(json['needs'] as List),
    savedIds: List<String>.from(json['savedIds'] as List),
  );
}
