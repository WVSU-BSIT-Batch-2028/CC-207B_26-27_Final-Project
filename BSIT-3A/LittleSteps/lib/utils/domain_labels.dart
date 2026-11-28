/// Canonical API keys and display labels for developmental domains.
abstract final class AppDomains {
  /// Problem-solving and exploration domain key.
  static const String cognitive = 'cognitive';

  /// Gross and fine movement domain key.
  static const String motor = 'motor';

  /// Receptive and expressive communication domain key.
  static const String language = 'language';

  /// Social connection and emotional expression domain key.
  static const String socioEmotional = 'socioEmotional';

  /// Map of API domain keys to caregiver-friendly display labels.
  static const Map<String, String> labels = <String, String>{
    cognitive: 'Thinking',
    motor: 'Moving',
    language: 'Talking',
    socioEmotional: 'Feelings',
  };

  /// Map initialized with zero activity counts for every developmental domain.
  static const Map<String, int> emptyCounts = <String, int>{
    cognitive: 0,
    motor: 0,
    language: 0,
    socioEmotional: 0,
  };
}

/// Canonical API keys and display labels for play settings.
abstract final class PlaySetting {
  /// Wire value for indoor play activities.
  static const String indoor = 'indoor';

  /// Wire value for outdoor play activities.
  static const String outdoor = 'outdoor';

  /// Wire value for activities suitable indoors or outdoors.
  static const String either = 'either';

  /// Filterable setting keys mapped to their display labels.
  static const Map<String, String> filterLabels = <String, String>{
    indoor: 'Indoor',
    outdoor: 'Outdoor',
  };
}

/// Canonical ISO-639 language codes and labels supported across the catalog.
abstract final class AppLanguages {
  /// English language code.
  static const String english = 'en';

  /// Filipino language code.
  static const String filipino = 'fil';

  /// Hiligaynon language code.
  static const String hiligaynon = 'hil';

  /// Supported catalog language codes mapped to caregiver-facing labels.
  static const Map<String, String> labels = <String, String>{
    english: 'English',
    filipino: 'Filipino',
    hiligaynon: 'Hiligaynon',
  };
}

/// Ordered `(key, label)` pairs for the four early-learning developmental domains.
const List<(String, String)> developmentalDomains = [
  (AppDomains.cognitive, 'Thinking'),
  (AppDomains.motor, 'Moving'),
  (AppDomains.language, 'Talking'),
  (AppDomains.socioEmotional, 'Feelings'),
];

/// Maps a backend developmental [domain] key to its caregiver-friendly label.
String friendlyDomainLabel(String domain) {
  switch (domain.toLowerCase()) {
    case AppDomains.cognitive:
      return 'Thinking';
    case AppDomains.motor:
      return 'Moving';
    case AppDomains.language:
      return 'Talking';
    case 'socioemotional':
    case 'socio_emotional':
    case 'socio-emotional':
      return 'Feelings';
    default:
      return 'Talking';
  }
}

/// Maps a backend developmental [domain] key to its formal display label.
String formalDomainLabel(String domain) {
  switch (domain.toLowerCase()) {
    case 'socioemotional':
    case 'socio_emotional':
    case 'socio-emotional':
      return 'Socio-emotional';
    case AppDomains.cognitive:
      return 'Cognitive';
    case AppDomains.motor:
      return 'Motor';
    case AppDomains.language:
      return 'Language';
    default:
      return domain.isEmpty
          ? domain
          : '${domain[0].toUpperCase()}${domain.substring(1)}';
  }
}

/// Maps a backend play [setting] key to its display label.
String formatSettingLabel(String setting) {
  switch (setting.toLowerCase()) {
    case PlaySetting.indoor:
      return 'Indoor';
    case PlaySetting.outdoor:
      return 'Outdoor';
    case PlaySetting.either:
      return 'Indoor or outdoor';
    default:
      return setting;
  }
}
