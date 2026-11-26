// Shared state of the buyer AI assistant: whether it is on (only while a
// buyer is logged in), what page the buyer is looking at, and the chat in
// this session. Screens tell it their page through AssistantScope; the
// floating button and panel (widgets/assistant_layer.dart) listen to it.

import 'package:flutter/material.dart';

import '../models/assistant.dart';
import '../utils/assistant_facts.dart';
import '../widgets/home_nav.dart';
import 'buyer_assistant_service.dart';

/// Use `--dart-define=FAKE_AI=true` to try the assistant without Gemini
/// (e.g. on the emulator).
const bool kFakeAi = bool.fromEnvironment('FAKE_AI');

/// One shared controller for the whole app (see [instance]).
class AssistantController extends ChangeNotifier {
  AssistantController({BuyerAssistantService? service})
    : _service =
          service ??
          BuyerAssistantService(ai: kFakeAi ? FakeAssistantAi() : null);

  static final AssistantController instance = AssistantController();

  final BuyerAssistantService _service;
  final AssistantLimits limits = AssistantLimits();

  /// The navigator above the whole app, so answer cards can open pages.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Opens a tab of the buyer's main screen (set by HomeScreen).
  void Function(HomeTab tab)? _openTab;

  AssistantPage _tabPage = const AssistantPage(AssistantScreen.home);

  /// Pages pushed on top of the tabs (listing, chat, price detail...),
  /// newest last. Each AssistantScope adds itself and removes itself.
  final List<(Object, AssistantPage)> _pushed = [];

  /// How many pop-up routes (bottom sheets, dialogs) are open: the round
  /// button hides then, so it never covers their buttons.
  int _popups = 0;

  final List<AssistantMessage> messages = [];
  bool isOpen = false;
  bool isThinking = false;
  String? notice; // e.g. "Please wait a few seconds…"

  /// The page the buyer sees now.
  AssistantPage get page => _pushed.isEmpty ? _tabPage : _pushed.last.$2;

  /// True when the buyer is on a tab (the phone shows the bottom bar).
  bool get onTab => _pushed.isEmpty;

  bool get showButton =>
      _enabled && !isOpen && _popups == 0 && !page.hideButton;

  /// Called by the buyer's HomeScreen when it opens.
  void enable(void Function(HomeTab tab) openTab) {
    _enabled = true;
    _openTab = openTab;
    notifyListeners();
  }

  /// Called when the buyer's HomeScreen closes (log out): forget the chat.
  void disable() {
    _enabled = false;
    _openTab = null;
    isOpen = false;
    messages.clear();
    limits.reset();
    _pushed.clear();
    notifyListeners();
  }

  void setTab(AssistantScreen screen) {
    _tabPage = AssistantPage(screen);
    notifyListeners();
  }

  void pushPage(Object key, AssistantPage page) {
    _pushed.removeWhere((entry) => entry.$1 == key);
    _pushed.add((key, page));
    _notifyLater();
  }

  void removePage(Object key) {
    _pushed.removeWhere((entry) => entry.$1 == key);
    _notifyLater();
  }

  void popupOpened() {
    _popups++;
    _notifyLater();
  }

  void popupClosed() {
    if (_popups > 0) _popups--;
    _notifyLater();
  }

  /// Screens report their page while building, so tell listeners after
  /// the frame (changing state during a build is not allowed).
  void _notifyLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  void open() {
    isOpen = true;
    notifyListeners();
  }

  void close() {
    isOpen = false;
    notifyListeners();
  }

  /// "New chat": clears the conversation (the session limit stays).
  void newChat() {
    messages.clear();
    notice = null;
    notifyListeners();
  }

  /// Opens a tab (e.g. Market) from an answer.
  void openTab(HomeTab tab) {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _openTab?.call(tab);
    close();
  }

  /// The suggested questions for the current page.
  List<SuggestedQuestion> get suggestions => suggestionsFor(page);

  /// Asks a question. [intent] comes from a chip; typed questions are
  /// sorted by [detectIntent].
  Future<void> ask(String question, {AssistantIntent? intent}) async {
    final text = question.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final reason = limits.whyNot(now);
    if (reason != null) {
      notice = reason;
      notifyListeners();
      return;
    }
    final useAi = limits.aiAllowed;
    final currentPage = page; // the page when the question was asked
    limits.started(now, usesAi: useAi);
    notice = null;
    isThinking = true;
    // The chat so far (before this question), for follow-ups.
    final history = List<AssistantMessage>.of(messages);
    messages.add(AssistantMessage.fromBuyer(text));
    notifyListeners();
    try {
      final reply = await _service.answer(
        text,
        currentPage,
        intent ?? detectIntent(text, currentPage),
        useAi: useAi,
        history: history,
      );
      messages.add(reply);
    } catch (_) {
      messages.add(
        const AssistantMessage.answer(
          text: 'Something went wrong. Please try again.',
          isFallback: true,
        ),
      );
    } finally {
      isThinking = false;
      limits.finished();
      notifyListeners();
    }
  }
}

/// Tells the assistant what page this is while [child] is shown. Wrap a
/// pushed screen in it (listing, price detail, chat, a form).
class AssistantScope extends StatefulWidget {
  const AssistantScope({super.key, required this.page, required this.child});

  final AssistantPage page;
  final Widget child;

  @override
  State<AssistantScope> createState() => _AssistantScopeState();
}

class _AssistantScopeState extends State<AssistantScope> {
  final _key = Object();

  @override
  void initState() {
    super.initState();
    AssistantController.instance.pushPage(_key, widget.page);
  }

  @override
  void didUpdateWidget(AssistantScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    AssistantController.instance.pushPage(_key, widget.page);
  }

  @override
  void dispose() {
    AssistantController.instance.removePage(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Counts open bottom sheets and dialogs so the round button can hide.
class AssistantRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) AssistantController.instance.popupOpened();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) AssistantController.instance.popupClosed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) AssistantController.instance.popupClosed();
  }
}
