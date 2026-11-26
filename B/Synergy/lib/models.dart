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

// One partnership between two startups
class Exchange {
  Exchange({
    String? id,
    required this.senderId,
    required this.recipientId,
    required this.note,
    this.stage = 'pending',
    this.goal = '',
    this.testerCount = 0,
    this.testingWindow = '',
    this.deliverables = '',
    List<String>? termsAgreedBy,
    List<String>? step1ConfirmedBy,
    List<String>? step2ConfirmedBy,
    this.feedbackNote = '',
    Map<String, int>? ratings,
    Map<String, String>? reviewNotes,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       termsAgreedBy = termsAgreedBy ?? [],
       step1ConfirmedBy = [...?step1ConfirmedBy],
       step2ConfirmedBy = [...?step2ConfirmedBy],
       ratings = {...?ratings},
       reviewNotes = {...?reviewNotes};

  String id;
  String senderId;
  String recipientId;
  String note;
  // pending, declined, withdrawn, accepted, termsAgreed, launched or reviewed
  String stage;

  // Terms (empty until someone proposes them)
  String goal;
  int testerCount;
  String testingWindow;
  String deliverables;
  List<String> termsAgreedBy; // IDs of startups that agreed
  List<String> step1ConfirmedBy;
  List<String> step2ConfirmedBy;
  String feedbackNote;
  Map<String, int> ratings;
  Map<String, String> reviewNotes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'recipientId': recipientId,
    'note': note,
    'stage': stage,
    'goal': goal,
    'testerCount': testerCount,
    'testingWindow': testingWindow,
    'deliverables': deliverables,
    'termsAgreedBy': termsAgreedBy,
    'step1ConfirmedBy': step1ConfirmedBy,
    'step2ConfirmedBy': step2ConfirmedBy,
    'feedbackNote': feedbackNote,
    'ratings': ratings,
    'reviewNotes': reviewNotes,
  };

  // Older saves use defaults for missing fields
  factory Exchange.fromJson(Map<String, dynamic> json) => Exchange(
    id: json['id'] as String,
    senderId: json['senderId'] as String,
    recipientId: json['recipientId'] as String,
    note: json['note'] as String,
    stage: json['stage'] as String,
    goal: json['goal'] as String? ?? '',
    testerCount: json['testerCount'] as int? ?? 0,
    testingWindow: json['testingWindow'] as String? ?? '',
    deliverables: json['deliverables'] as String? ?? '',
    termsAgreedBy: List<String>.from(json['termsAgreedBy'] as List? ?? []),
    step1ConfirmedBy: (json['step1ConfirmedBy'] as List?)?.cast<String>(),
    step2ConfirmedBy: (json['step2ConfirmedBy'] as List?)?.cast<String>(),
    feedbackNote: json['feedbackNote'] as String? ?? '',
    ratings: Map<String, int>.from(json['ratings'] ?? {}),
    reviewNotes: Map<String, String>.from(json['reviewNotes'] ?? {}),
  );
}
