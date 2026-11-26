// Data for the buyer AI assistant: what page the buyer is on, what kind of
// question it is, and what the assistant answers. See
// docs/buyer-ai-assistant-design.md.

import 'listing.dart';
import 'order.dart';
import 'price_record.dart';

/// Which buyer page is open (decides the suggested questions).
enum AssistantScreen {
  home,
  market,
  prices,
  priceDetail,
  listing,
  requests,
  orders,
  following,
  messages,
  chat,
}

/// What is on the page right now. Screens fill in what they have; the
/// assistant never has to ask the buyer to retype it.
class AssistantPage {
  const AssistantPage(
    this.screen, {
    this.listing,
    this.crop,
    this.history = const [],
    this.order,
    this.hideButton = false,
  });

  final AssistantScreen screen;
  final Listing? listing; // the listing page's listing
  final String? crop; // the crop of a price page
  final List<PriceRecord> history; // that crop's prices (price page)
  final CropOrder? order; // the newest order in an open chat

  /// True on forms, so the round button never covers their buttons.
  final bool hideButton;

  /// The crop this page is about, if any.
  String? get pageCrop => listing?.crop ?? order?.crop ?? crop;
}

/// The kinds of questions the assistant can answer.
enum AssistantIntent {
  priceCheck,
  trend,
  search,
  offerMath,
  orderStatus,
  howTo,
  outOfScope, // answered by the app itself, never sent to the AI
  about, // what AgosUgnayan is (answered by the app)
  ranking, // "top 3 prices", "cheapest fruit" (computed by the app)
  compare, // "compare tomato and cabbage"
  changes, // "what changed since last month?"
  general, // anything else: a friendly answer from general knowledge
}

/// A suggested question chip: its words and what kind of question it is.
class SuggestedQuestion {
  const SuggestedQuestion(this.text, this.intent);

  final String text;
  final AssistantIntent intent;
}

/// One line in the "Facts from AgosUgnayan" box, e.g. "Asking price" /
/// "₱54.40/kg".
class FactRow {
  const FactRow(this.label, this.value);

  final String label;
  final String value;
}

/// One message in the assistant chat.
class AssistantMessage {
  const AssistantMessage.fromBuyer(this.text)
    : isBuyer = true,
      isFallback = false,
      facts = const [],
      listings = const [],
      marketCrop = null,
      fromApp = false,
      isGeneral = false,
      suggestions = const [];

  const AssistantMessage.answer({
    required this.text,
    this.isFallback = false,
    this.facts = const [],
    this.listings = const [],
    this.marketCrop,
    this.fromApp = false,
    this.isGeneral = false,
    this.suggestions = const [],
  }) : isBuyer = false;

  final bool isBuyer;

  /// The AI's words (or, in a fallback, the app's own words).
  final String text;

  /// True when the AI was not used (busy, offline, limit reached).
  final bool isFallback;

  /// Numbers computed by the app, shown apart from the AI text.
  final List<FactRow> facts;

  /// Real listings to tap (search results), never made up by the AI.
  final List<Listing> listings;

  /// When set, an "Open the Market" link is shown (the crop searched).
  final String? marketCrop;

  /// True when the app answered by itself (no AI needed): labeled
  /// "From AgosUgnayan" instead of "AI suggestion".
  final bool fromApp;

  /// True when (part of) the answer is general knowledge, not
  /// AgosUgnayan data: labeled "General answer, not from AgosUgnayan data".
  final bool isGeneral;

  /// Questions the buyer can tap next (after "I can't help with that").
  final List<SuggestedQuestion> suggestions;
}

/// The question chips for [page]: they change with the screen.
List<SuggestedQuestion> suggestionsFor(AssistantPage page) {
  const howRequest = SuggestedQuestion(
    'How do I request a crop?',
    AssistantIntent.howTo,
  );
  final crop = page.pageCrop?.toLowerCase();
  return switch (page.screen) {
    AssistantScreen.market => const [
      SuggestedQuestion('Find the cheapest tomato', AssistantIntent.search),
      SuggestedQuestion('What is available near me?', AssistantIntent.search),
      SuggestedQuestion('How do I store tomatoes?', AssistantIntent.general),
    ],
    AssistantScreen.prices => const [
      SuggestedQuestion('Explain PSA farmgate prices', AssistantIntent.howTo),
      SuggestedQuestion('Find the cheapest pechay', AssistantIntent.search),
    ],
    AssistantScreen.priceDetail => [
      SuggestedQuestion('Is this price going up?', AssistantIntent.trend),
      SuggestedQuestion('Explain this price', AssistantIntent.priceCheck),
      if (crop != null)
        SuggestedQuestion('Find $crop for sale', AssistantIntent.search),
    ],
    AssistantScreen.listing => const [
      SuggestedQuestion('Is this price fair?', AssistantIntent.priceCheck),
      SuggestedQuestion('How much for 5 kg?', AssistantIntent.offerMath),
      SuggestedQuestion('How do I buy this?', AssistantIntent.howTo),
    ],
    AssistantScreen.chat =>
      page.order == null
          ? const [
              SuggestedQuestion(
                'What does Reserved mean?',
                AssistantIntent.howTo,
              ),
              howRequest,
            ]
          : const [
              SuggestedQuestion(
                'What does this offer total?',
                AssistantIntent.offerMath,
              ),
              SuggestedQuestion(
                'What does this status mean?',
                AssistantIntent.orderStatus,
              ),
              SuggestedQuestion(
                'Is this price fair?',
                AssistantIntent.priceCheck,
              ),
            ],
    AssistantScreen.orders || AssistantScreen.messages => const [
      SuggestedQuestion('What does Reserved mean?', AssistantIntent.howTo),
      SuggestedQuestion('Why did my request expire?', AssistantIntent.howTo),
    ],
    _ => const [
      SuggestedQuestion('Find the cheapest tomato', AssistantIntent.search),
      SuggestedQuestion('Top 5 vegetable prices', AssistantIntent.ranking),
      SuggestedQuestion('How do I store tomatoes?', AssistantIntent.general),
      howRequest,
    ],
  };
}
