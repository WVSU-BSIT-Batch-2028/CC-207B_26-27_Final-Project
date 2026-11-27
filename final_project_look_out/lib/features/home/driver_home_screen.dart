//added poking system ETA and real time PUV tracking - Joshua

import 'dart:async';

//screens
import 'package:final_project_look_out/widgets/popup_notif.dart';

import '../../services/auth_service.dart';
import '../../widgets/confirmation_dialog.dart';

import '../about/about_screen.dart';
import '../analytics/analytics_screen.dart';
import '../announcements/announcements_screen.dart';
import '../driver_exclusive/start_ride/start_ride_screen.dart';
import '../driver_exclusive/trips/trips_screen.dart';
import '../driver_exclusive/vehicles/vehicles_screen.dart';
import '../faqs/faqs_screen.dart';
import '../landing/landing_screen.dart';
import '../profile/profile_screen.dart';

//reusable widgets
import '../../widgets/floating_button.dart';
import '../../widgets/lookout_app_bar.dart';
import '../../widgets/lookout_bottom_nav.dart';
import '../../widgets/lookout_drawer.dart';
import '../../widgets/congestion_map_layers.dart';
import '../../widgets/marker_status_floating_button.dart';

//services and packages
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/local_bus_tracking_service.dart';
import '../../services/firestore_poke_service.dart';
import '../../services/congestion_predictor_service.dart';

//styling
import '../../app/themes/app_colors.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final MapController _mapController = MapController();
  final LocalBusTrackingService _busTracking = LocalBusTrackingService.instance;
  final FirestorePokeService _pokeService = FirestorePokeService.instance;
  String _activePlate = '';
  bool _isRideActive = false;
  bool _hasFocusedOnActiveRide = false;
  String? _profileError;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;

  // Iloilo City Proper coordinates
  static const LatLng _iloiloCenter = LatLng(10.6969, 122.5644);

  // Sample LPTRP route coordinates
  final List<LatLng> _sampleRoutePoints = const [
    LatLng(10.7253, 122.5568),
    LatLng(10.7120, 122.5605),
    LatLng(10.6969, 122.5644),
  ];

  final CongestionPredictorService _predictor = CongestionPredictorService();
  List<CorridorPrediction> _predictions = [];

  @override
  void initState() {
    super.initState();
    _watchDriverProfile();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _isRideActive =
        uid != null &&
        _busTracking.activeBuses.value.any(
          (bus) => bus.driverId == uid && bus.isActive,
        );
    _busTracking.activeBuses.addListener(_syncRideState);
    _syncRideState();
    _loadTrafficForecast();
  }

  Future<void> _loadTrafficForecast() async {
    final results = await _predictor.predictAllCorridors();
    if (!mounted) return;
    setState(() => _predictions = results);
  }

  void _watchDriverProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _profileSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _activePlate = snapshot.data()?['activePlate'] as String? ?? '';
              _profileError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() => _profileError = error.toString());
          },
        );
  }

  void _syncRideState() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isActive =
        uid != null &&
        _busTracking.activeBuses.value.any(
          (bus) => bus.driverId == uid && bus.isActive,
        );
    if (isActive && !_hasFocusedOnActiveRide) {
      _hasFocusedOnActiveRide = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final bus in _busTracking.activeBuses.value) {
          if (bus.driverId == uid && bus.isActive) {
            _mapController.move(bus.position, 15);
            break;
          }
        }
      });
    } else if (!isActive) {
      _hasFocusedOnActiveRide = false;
    }
    if (_isRideActive != isActive && mounted) {
      setState(() => _isRideActive = isActive);
    }
  }

  ActiveBus? _activeDriverPuv() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    for (final bus in _busTracking.activeBuses.value) {
      if (bus.driverId == uid && bus.isActive) return bus;
    }
    return null;
  }

  void _toggleDriverPuvAvailability() {
    final bus = _activeDriverPuv();
    if (bus == null) return;
    _busTracking.setDriverAvailability(
      driverId: bus.driverId,
      isFull: !bus.isFull,
    );
    setState(() {});
  }

  void _centerOnDriverPuv() {
    final bus = _activeDriverPuv();
    if (bus != null) {
      _mapController.move(bus.position, 15.0);
      return;
    }

    PopupNotif(
      message: 'Start a ride to center on your PUV.',
      title: 'Info',
      type: NotifType.info,
    ).show(context);

  }

  Future<void> _toggleRide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_isRideActive) {
      try {
        await _busTracking.stopRide(uid);
        if (mounted) setState(() => _isRideActive = false);
      } catch (error) {
        if (!mounted) return;
        PopupNotif(
          message: error is DriverTripSyncException
              ? error.toString()
              : 'Unable to stop sharing location: $error',
          title: error is DriverTripSyncException
              ? 'Analytics sync failed'
              : 'Error',
          type: NotifType.error,
        ).show(context);
      }
      return;
    }
    if (_activePlate.isEmpty) {
      PopupNotif(
        message: 'Active plate is not set',
        title: 'Warning',
        type: NotifType.warning,
      ).show(context);
      return;
    }
    try {
      final hasLocationAccess = await _busTracking.startRide(
        driverId: uid,
        plateNumber: _activePlate,
        routeName: 'Iloilo Route 4',
      );
      if (!mounted) return;
      setState(() => _isRideActive = true);
      PopupNotif(
        message: hasLocationAccess
            ? 'Ride started. '
                  '${_busTracking.serverConnectionStatus.value}.'
            : 'Ride started locally, but GPS is unavailable and your '
                  'vehicle location is not being shared.',
      ).show(context);
    } catch (error) {
      if (!mounted) return;
      PopupNotif(
        message: 'Unable to start ride: $error',
        title: 'Error',
        type: NotifType.error,
      ).show(context);
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _busTracking.activeBuses.removeListener(_syncRideState);
    _mapController.dispose();
    super.dispose();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // App Bar
      appBar: selectedIndex == 0
          ? LookOutAppBar(
              title: 'Driver Dashboard',
              actions: [
                IconButton(
                  tooltip: 'FAQs',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FaqsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.help_outline),
                ),
              ],
            )
          : null,

      key: _scaffoldKey,
      drawer: LookOutDrawer(
        header: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.asset('assets/images/lookoutBanner.png', height: 60),
        ),
        items: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(
                    name: 'Driver',
                    email: 'driver@lookout.ph',
                    role: 'driver',
                  ),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Start Ride'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StartRideScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.route),
            title: const Text('Trips'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TripsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.directions_bus),
            title: const Text('Vehicles'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VehiclesScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.campaign),
            title: const Text('Announcements'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnnouncementsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('FAQs'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FaqsScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Analytics'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log Out'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => const ConfirmationDialog(
                  title: 'Log Out',
                  content: 'Are you sure you want to log out?',
                  confirmText: 'Log Out',
                ),
              );

              if (confirmed != true || !context.mounted) return;

              Navigator.pop(context); // Close drawer

              try {
                await AuthService().signOut();

                if (!context.mounted) return;

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LandingScreen(),
                  ),
                  (route) => false,
                );

                // Show success notification on LandingScreen
                PopupNotif(
                  title: 'Success',
                  message: 'You have successfully logged out.',
                  type: NotifType.success,
                ).show(context);
              } catch (e) {
                if (!context.mounted) return;

                PopupNotif(
                  title: 'Error',
                  message: 'Failed to log out. Please try again.',
                  type: NotifType.error,
                ).show(context);
              }
            },
          ),
        ],
      ),

      // Bottom Navigation
      bottomNavigationBar: LookOutBottomNav(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_arrow_outlined),
            selectedIcon: Icon(Icons.play_arrow),
            label: 'Start Ride',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_bus_filled_outlined),
            selectedIcon: Icon(Icons.directions_bus),
            label: 'Vehicles',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Announcements',
          ),
        ],
      ),

      // Dashboard Body
      body: IndexedStack(
        index: selectedIndex,
        children: [
          Stack(
            children: [
              // Interactive Map
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _iloiloCenter,
                  initialZoom: 14.0,
                  minZoom: 11.0,
                  maxZoom: 18.0,
                ),
                children: [
                  // 1. Base Map Tiles
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.undeciders.lookout',
                  ),

                  if (_predictions.isNotEmpty) ...[
                    CongestionMapLayers.buildZones(_predictions),
                    CongestionMapLayers.buildPolylines(_predictions),
                    CongestionMapLayers.buildBadges(
                      predictions: _predictions,
                      isDriverView:
                          false, // Set to true in driver_home_screen.dart!
                      onTapCorridor: (corridor) {
                        PopupNotif(
                          message:
                              '${corridor.name}: ${corridor.label} '
                              '(${(corridor.confidence * 100).toStringAsFixed(0)}% AI confidence, '
                              'Rain: ${_predictor.currentRainMm} mm)',
                          title: 'Info',
                          type: NotifType.info,
                        ).show(context);
                      },
                    ),
                  ],

                  // 2. LPTRP Route Polyline
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _sampleRoutePoints,
                        strokeWidth: 4.0,
                        color: AppColor.primaryBlue,
                      ),
                    ],
                  ),

                  // 3. Live PUV Markers
                  ValueListenableBuilder<List<ActiveBus>>(
                    valueListenable: _busTracking.activeBuses,
                    builder: (context, buses, child) {
                      return MarkerLayer(
                        markers: buses.where((bus) => bus.isActive).map((bus) {
                          return Marker(
                            point: bus.position,
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.directions_bus,
                              size: 32,
                              color: bus.isFull ? Colors.red : Colors.green,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  if (_activePlate.isNotEmpty)
                    StreamBuilder<
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    >(
                      stream: _pokeService.streamIncomingPokes(_activePlate),
                      builder: (context, snapshot) {
                        final pokes = snapshot.data ?? const [];
                        return MarkerLayer(
                          markers: pokes
                              .map((poke) {
                                final data = poke.data();
                                final lat = data['lat'];
                                final lng = data['lng'];
                                if (lat is! num || lng is! num) return null;
                                return Marker(
                                  point: LatLng(lat.toDouble(), lng.toDouble()),
                                  width: 40,
                                  height: 40,
                                  child: IconButton(
                                    tooltip:
                                        data['message'] as String? ?? 'Poke',
                                    onPressed: () =>
                                        _pokeService.acknowledgePoke(
                                          activePlate: _activePlate,
                                          pokeId: poke.id,
                                        ),
                                    icon: const Icon(Icons.push_pin),
                                  ),
                                );
                              })
                              .whereType<Marker>()
                              .toList(),
                        );
                      },
                    ),

                  // 4. OpenStreetMap Attribution
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),

              // Driver Information Card
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 3,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.directions_bus,
                                color: Colors.green,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Your Route Overview',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isRideActive
                                          ? '$_activePlate is on an active ride.'
                                          : 'View your route and vehicle position.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_profileError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Unable to load your driver profile: $_profileError',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _toggleRide,
                                child: Text(
                                  _isRideActive ? 'End Ride' : 'Start Ride',
                                ),
                              ),
                              if (_activePlate.isNotEmpty)
                                StreamBuilder<int>(
                                  stream: _pokeService.streamPokeCount(
                                    _activePlate,
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasError) {
                                      return Text(
                                        'Unable to load pokes: ${snapshot.error}',
                                      );
                                    }
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      );
                                    }
                                    final count = snapshot.data ?? 0;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.notifications_active_outlined,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 8),
                                        Text('$count'),
                                        const SizedBox(width: 16),
                                        ElevatedButton(
                                          onPressed: count == 0
                                              ? null
                                              : () async {
                                                  try {
                                                    await _pokeService
                                                        .clearAllPokesForPlate(
                                                          _activePlate,
                                                        );
                                                  } catch (error) {
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    PopupNotif(
                                                      message: 'Unable to clear pokes: $error',
                                                      title: 'Error',
                                                      type: NotifType.error,
                                                    ).show(context);
                                                  }
                                                },
                                          child: const Text('Clear'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          StartRideScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          TripsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          VehiclesScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          AnnouncementsScreen(
            onMenuPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
        ],
      ),
      // Floating Location Button
      floatingActionButton: selectedIndex == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isRideActive) ...[
                  MarkerStatusFloatingButton(
                    heroTag: 'driver-puv-status',
                    isFull: _activeDriverPuv()?.isFull ?? false,
                    onPressed: _toggleDriverPuvAvailability,
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingButton(
                  heroTag: 'driver-home-location',
                  onPressed: _centerOnDriverPuv,
                  icon: Icons.my_location,
                ),
              ],
            )
          : null,
    );
  }
}
