import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/navigation/route_args.dart';
import 'core/navigation/route_names.dart';
import 'core/providers.dart';
import 'core/services/firebase/fcm_service.dart';
import 'core/services/local_storage_service.dart';
import 'core/utils/enums.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await firebaseBackgroundMessageHandler(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await AppConfig().load();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(LocalStorageService(prefs)),
      ],
      child: const WastePickupApp(),
    ),
  );
}

class WastePickupApp extends ConsumerStatefulWidget {
  const WastePickupApp({super.key});

  @override
  ConsumerState<WastePickupApp> createState() => _WastePickupAppState();
}

class _WastePickupAppState extends ConsumerState<WastePickupApp> {
  @override
  void initState() {
    super.initState();
    _setUpNotifications();
  }

  Future<void> _setUpNotifications() async {
    final fcm = ref.read(fcmServiceProvider);

  await fcm.initialize(
      onNotificationTap: (payload) {
        if (payload == null) return;
        try {
          _routeFromNotificationData(
            (jsonDecode(payload) as Map).cast<String, dynamic>(),
          );
        } catch (_) {
          // Malformed/legacy payload — nothing sensible to route to.
        }
      },
    );

   fcm.onMessageOpenedApp.listen((message) {
      _routeFromNotificationData(message.data);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _routeFromNotificationData(initialMessage.data);
    }
  }
  Future<void> _routeFromNotificationData(Map<String, dynamic> data) async {
    final requestId = data['requestId'] as String?;
    final type = data['type'] as String?;
    if (requestId == null) return;

    switch (type) {
      case 'request_created':
        AppRouter.push(RouteNames.incomingRequests);
        return;
      case 'request_cancelled':
        AppRouter.push(RouteNames.activeRoute);
        return;
      case 'request_accepted':
      case 'collector_enroute':
      case 'collector_arrived':
      case 'collector_approaching':
      case 'schedule_activated':
        AppRouter.push(
          RouteNames.requestTracking,
          arguments: RequestTrackingArgs(requestId: requestId),
        );
        return;
      case 'pickup_completed':
    final role = await _currentUserRole();
        if (role == UserRole.collector) {
          AppRouter.push(RouteNames.collectorHistory);
        } else {
          AppRouter.push(RouteNames.receipt, arguments: ReceiptArgs(requestId: requestId));
        }
        return;
      default:
        final role = await _currentUserRole();
        if (role == UserRole.collector) {
          AppRouter.push(RouteNames.activeRoute);
        } else {
          AppRouter.push(
            RouteNames.requestTracking,
            arguments: RequestTrackingArgs(requestId: requestId),
          );
        }
    }
  }

  Future<UserRole?> _currentUserRole() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return null;
    final appUser = await ref.read(authRepositoryProvider).fetchAppUser(uid);
    return appUser?.role;
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: 'Waste Pickup',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        navigatorKey: AppRouter.navigatorKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: RouteNames.startup,
      ),
    );
  }
}