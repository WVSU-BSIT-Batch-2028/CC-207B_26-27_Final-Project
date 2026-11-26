import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/staff_claims_screen.dart';
import 'services/auth_service.dart';
import 'theme/paper_theme.dart';
import 'widgets/home_parts.dart';
import 'widgets/home_sections.dart';
import 'widgets/paper_widgets.dart';

/// Turn this on only for local rule tests:
/// flutter run -d chrome --dart-define=USE_FIREBASE_EMULATOR=true
const _useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (_useFirebaseEmulator) {
    // These local endpoints are started by `firebase emulators:start`.
    // They keep every security-rule test separate from the live Firebase data.
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  } else {
    // App Check: the debug provider is for local development only. Its token
    // is printed in the browser console and must be registered in Firebase
    // console > App Check > Apps. A real deployment needs a production provider.
    await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
  }

  runApp(const MatchBackApp());
}

class MatchBackApp extends StatelessWidget {
  const MatchBackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatchBack | Campus Lost and Found',
      debugShowCheckedModeBanner: false,
      theme: Paper.theme(),
      home: const AuthGate(),
    );
  }
}

/// Shows the login page until someone signs in, then the home page.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  AppSession? _session;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _authService.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _checking = false;
    });
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _session = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session == null) {
      return LoginScreen(
        authService: _authService,
        onLoggedIn: (newSession) {
          setState(() {
            _session = newSession;
          });
        },
      );
    }

    return MatchBackHomePage(session: session, onLogout: _logout);
  }
}

class MatchBackHomePage extends StatefulWidget {
  const MatchBackHomePage({
    required this.session,
    required this.onLogout,
    super.key,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<MatchBackHomePage> createState() => _MatchBackHomePageState();
}

class _MatchBackHomePageState extends State<MatchBackHomePage> {
  static const _labels = [
    'Home',
    'How it works',
    'Get started',
    'AI match',
    'Contact',
  ];

  HomeSections get _sections =>
      HomeSections(_open, isStaff: widget.session.isStaff);
  final _scroll = ScrollController();
  final _keys = List.generate(_labels.length, (_) => GlobalKey());

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final target = _keys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeInOutCubic,
    );
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _section(
    int index,
    PaperKind kind,
    int seed,
    Widget child, {
    double top = 96,
  }) {
    return KeyedSubtree(
      key: _keys[index],
      child: PaperSection(
        kind: kind,
        seed: seed,
        padding: EdgeInsets.fromLTRB(20, top, 20, 72),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final sections = _sections;
    final session = widget.session;

    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _section(0, PaperKind.graph, 3, sections.hero(wide), top: 120),
                _section(1, PaperKind.ruled, 8, sections.how(wide)),
                _section(2, PaperKind.graph, 12, sections.actions(wide)),
                _section(3, PaperKind.plain, 21, sections.ai(wide)),
                _section(4, PaperKind.ruled, 34, sections.contact(wide)),
                sections.footer(),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NavBar(
              labels: _labels,
              wide: wide,
              onSelect: _goTo,
              onStaff: () => _open(const StaffClaimsScreen()),
              isStaff: session.isStaff,
              userLabel: session.isStaff ? 'Staff' : (session.studentId ?? ''),
              onLogout: widget.onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
