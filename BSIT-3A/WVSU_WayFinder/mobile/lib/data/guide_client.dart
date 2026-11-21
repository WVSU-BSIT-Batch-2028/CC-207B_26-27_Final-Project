import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

enum Lang { en, tl, hil }

class Citation {
  const Citation(this.type, this.id, this.label);
  final String type, id, label; // type: place | process | faculty
}

class GuideAnswer {
  const GuideAnswer(this.answer, this.citations, this.grounded);
  final String answer;
  final List<Citation> citations;
  final bool grounded;
}

class GuideUnavailable implements Exception {
  GuideUnavailable(this.reason);
  final String reason;
}

/// Calls the server-side ai-guide Edge Function. The provider key stays in Supabase function secrets.
class GuideClient {
  GuideClient(this.config, {http.Client? client}) : _client = client ?? http.Client();
  final AppConfig config;
  final http.Client _client;

  Future<GuideAnswer> ask(String q, Lang lang) async {
    if (!config.isLive) throw GuideUnavailable('not-configured');
    final base = config.supabaseUrl.replaceAll(RegExp(r'/+$'), '');
    final http.Response res;
    try {
      res = await _client.post(Uri.parse('$base/functions/v1/ai-guide'),
          headers: {'apikey': config.supabasePublishableKey, 'Content-Type': 'application/json'},
          body: jsonEncode({'q': q, 'lang': lang.name}));
    } catch (_) {
      throw GuideUnavailable('network');
    }
    if (res.statusCode != 200) throw GuideUnavailable('HTTP ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['answer'] is! String || j['citations'] is! List) throw GuideUnavailable('bad-response');
    final cites = (j['citations'] as List).cast<Map<String, dynamic>>().map((c) => Citation(c['type'], c['id'], c['label'])).toList();
    final grounded = j['grounded'] == true && cites.isNotEmpty;
    return GuideAnswer(j['answer'] as String, grounded ? cites : const [], grounded);
  }
}

const _stop = {'the', 'a', 'an', 'is', 'are', 'where', 'what', 'how', 'do', 'does', 'i', 'my', 'to', 'of', 'in', 'on', 'for', 'and', 'or', 'can', 'find', 'get', 'go',
  'saan', 'ang', 'ng', 'sa', 'mga', 'ko', 'ako', 'paano', 'asa', 'diin', 'ano', 'sang', 'paagi', 'ka', 'kag', 'please', 'po'};

/// Same keyword rule as the server (drops EN/TL/HIL question words).
List<String> keywords(String q) =>
    q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((w) => w.length >= 2 && !_stop.contains(w)).toList();

const guideStrings = {
  // Tagalog and Hiligaynon drafts need review by a native-speaker teammate before release.
  Lang.en: (
    greeting: 'Hi! Where do you need to go or what do you need to process?',
    placeholder: 'Ask about a place, room or process',
    suggestions: ['Where is the Registrar?', 'How do I process my clearance?', 'Where can I request my transcript?', 'Where is CB 203?'],
    noInfo: 'I don’t have verified information on that yet. Try the Directory or Processes.',
    fallback: 'AI answers are unavailable. Here are matching directory and process results:',
    none: 'No matching place, teacher or process was found.',
  ),
  Lang.tl: (
    greeting: 'Kumusta! Saan ka pupunta o ano ang kailangan mong asikasuhin?',
    placeholder: 'Magtanong tungkol sa lugar, silid o proseso',
    suggestions: ['Saan ang Registrar?', 'Paano mag-process ng clearance?', 'Saan puwedeng humingi ng transcript?', 'Saan ang CB 203?'],
    noInfo: 'Wala pa akong beripikadong impormasyon tungkol diyan. Subukan ang Directory o Processes.',
    fallback: 'Hindi available ang AI. Narito ang mga tugmang resulta sa directory at proseso:',
    none: 'Walang nakitang tugmang lugar, guro o proseso.',
  ),
  Lang.hil: (
    greeting: 'Maayong adlaw! Diin ka makadto ukon ano ang kinahanglan mo i-proseso?',
    placeholder: 'Pamangkot parte sa lugar, kwarto ukon proseso',
    suggestions: ['Diin ang Registrar?', 'Paano ko ma-proseso ang clearance?', 'Diin ako makapangayo sang transcript?', 'Diin ang CB 203?'],
    noInfo: 'Wala pa ako sang beripikado nga impormasyon parte sina. Tilawi ang Directory ukon Processes.',
    fallback: 'Indi available ang AI. Ari ang nagakaangay nga resulta sa directory kag proseso:',
    none: 'Wala sang nakita nga nagakaangay nga lugar, maestro ukon proseso.',
  ),
};
