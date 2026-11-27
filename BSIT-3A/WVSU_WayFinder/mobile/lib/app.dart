import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/app_scope.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'core/time.dart';
import 'data/campus.dart';
import 'data/class_notifications.dart';
import 'data/faculty_repository.dart';
import 'data/guide_client.dart';
import 'data/location_service.dart';
import 'data/places_repository.dart';
import 'data/processes_repository.dart';
import 'data/schedule.dart';
import 'data/schedule_documents.dart';
import 'screens/directory_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/home_screen.dart';
import 'screens/import_schedule_screen.dart';
import 'screens/map_screen.dart';
import 'screens/place_screen.dart';
import 'screens/processes_screens.dart';
import 'screens/schedule_screens.dart';
import 'screens/search_screen.dart';
import 'screens/shell.dart';

GoRouter buildRouter(String initial) => GoRouter(initialLocation: initial, routes: [
      ShellRoute(
        builder: (context, state, child) => Shell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/search', builder: (_, s) => SearchScreen(query: s.uri.queryParameters['q'] ?? '')),
          GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
          GoRoute(path: '/schedule/import', builder: (_, s) => ImportScheduleScreen(uploadId: s.uri.queryParameters['upload'])),
          GoRoute(path: '/schedule/new', builder: (_, __) => const ClassFormScreen()),
          GoRoute(path: '/schedule/:id', builder: (_, s) => ClassFormScreen(classId: s.pathParameters['id'])),
          GoRoute(path: '/place/:id', builder: (_, s) => PlaceScreen(placeId: s.pathParameters['id']!)),
          GoRoute(
            path: '/map',
            builder: (_, s) => MapScreen(
              to: s.uri.queryParameters['to'] ?? s.uri.queryParameters['place'] ?? '',
              from: s.uri.queryParameters['from'] ?? '',
            ),
          ),
          GoRoute(path: '/processes', builder: (_, s) => ProcessListScreen(query: s.uri.queryParameters['q'] ?? '')),
          GoRoute(path: '/processes/:id', builder: (_, s) => ProcessDetailScreen(processId: s.pathParameters['id']!)),
          GoRoute(path: '/directory', builder: (_, s) => DirectoryScreen(query: s.uri.queryParameters['q'] ?? '', category: s.uri.queryParameters['cat'] ?? 'all')),
          GoRoute(path: '/directory/faculty/:id', builder: (_, s) => FacultyDetailScreen(recordId: s.pathParameters['id']!)),
          GoRoute(path: '/guide', builder: (_, __) => const GuideScreen()),
        ],
      ),
    ]);

class WayFinderApp extends StatefulWidget {
  WayFinderApp({
    super.key,
    AppConfig? config,
    this.places,
    this.faculty,
    this.processes,
    this.campus,
    this.guide,
    ScheduleStore? schedule,
    LocationService? location,
    this.initialLocation = '/',
    this.now,
    this.notifications,
    this.documents,
  })  : config = config ?? AppConfig.fromEnvironment(),
        schedule = schedule ?? ScheduleStore(),
        location = location ?? GeolocatorLocationService();

  final AppConfig config;
  final PlacesRepository? places;
  final FacultyRepository? faculty;
  final ProcessesRepository? processes;
  final CampusRepository? campus;
  final GuideClient? guide;
  final ScheduleStore schedule;
  final LocationService location;
  final String initialLocation;
  final DateTime Function()? now;
  final ClassNotifications? notifications;
  final ScheduleDocumentStore? documents;

  @override
  State<WayFinderApp> createState() => _WayFinderAppState();
}

class _WayFinderAppState extends State<WayFinderApp> with WidgetsBindingObserver {
  late final _documents = widget.documents ?? ScheduleDocumentStore();
  late final _notifications = widget.notifications ?? ClassNotifications(now: widget.now);
  late final _router = buildRouter(widget.initialLocation);
  late final _places = widget.places ?? createPlacesRepository(widget.config);
  late final _faculty = widget.faculty ?? createFacultyRepository(widget.config);
  late final _processes = widget.processes ?? createProcessesRepository(widget.config);
  late final _campus = widget.campus ?? createCampusRepository(widget.config);
  late final _guide = widget.guide ?? GuideClient(widget.config);
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final ReminderScheduler _reminders = ReminderScheduler(
    now: widget.now ?? appClock,
    timer: Timer.new,
    notify: (c) => _messenger.currentState?.showSnackBar(SnackBar(
      duration: const Duration(seconds: 12),
      content: Text('Class reminder: ${c.subject} at ${formatClock(c.start)} · Room ${c.roomCodeRaw}${c.professor != null ? ' · ${c.professor}' : ''}'),
    )),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.schedule.addListener(_syncReminders);
    _notifications.initialize();
    _documents.loadForDisplay();
    if (!widget.schedule.loaded) {
      widget.schedule.load();
    } else {
      _syncReminders();
    }
  }

  void _syncReminders() {
    if (!_notifications.supported) _reminders.sync(widget.schedule.classes);
    _notifications.sync(widget.schedule.classes);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.schedule.removeListener(_syncReminders);
    if (widget.notifications == null) _notifications.dispose();
    if (widget.documents == null) _documents.dispose();
    _reminders.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        config: widget.config,
        places: _places,
        faculty: _faculty,
        processes: _processes,
        campus: _campus,
        guide: _guide,
        schedule: widget.schedule,
        notifications: _notifications,
        documents: _documents,
        progress: ProgressStore(),
        location: widget.location,
        child: MaterialApp.router(
          title: 'WVSU WayFinder',
          theme: buildTheme(),
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messenger,
          routerConfig: _router,
        ),
      );
}
