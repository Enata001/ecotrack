import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/role_gate_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/collector/presentation/screens/active_route_screen.dart';
import '../../features/collector/presentation/screens/collector_history_screen.dart';
import '../../features/collector/presentation/screens/collector_home_screen.dart';
import '../../features/collector/presentation/screens/complete_pickup_screen.dart';
import '../../features/collector/presentation/screens/incoming_requests_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/startup_gate_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/saved_addresses_screen.dart';
import '../../features/user/presentation/screens/new_request_screen.dart';
import '../../features/user/presentation/screens/receipt_screen.dart';
import '../../features/user/presentation/screens/request_history_screen.dart';
import '../../features/user/presentation/screens/request_tracking_screen.dart';
import '../../features/user/presentation/screens/scheduled_pickup_screens.dart';
import '../../features/user/presentation/screens/user_home_screen.dart';
import 'route_args.dart';
import 'route_names.dart';

class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static BuildContext? get context => navigatorKey.currentContext;

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case RouteNames.startup:
        page = const StartupGateScreen();
        break;
      case RouteNames.onboarding:
        page = const OnboardingScreen();
        break;
      case RouteNames.roleGate:
        page = const RoleGateScreen();
        break;
      case RouteNames.login:
        page = const LoginScreen();
        break;
      case RouteNames.signup:
        page = const SignupScreen();
        break;
      case RouteNames.forgotPassword:
        page = const ForgotPasswordScreen();
        break;
      case RouteNames.profile:
        page = const ProfileScreen();
        break;
      case RouteNames.editProfile:
        final args = settings.arguments as EditProfileArgs;
        page = EditProfileScreen(user: args.user);
        break;
      case RouteNames.savedAddresses:
        page = const SavedAddressesScreen();
        break;
      case RouteNames.userHome:
        page = const UserHomeScreen();
        break;
      case RouteNames.newRequest:
        page = const NewRequestScreen();
        break;
      case RouteNames.requestHistory:
        page = const RequestHistoryScreen();
        break;
      case RouteNames.scheduledPickups:
        page = const ScheduledPickupsScreen();
        break;
      case RouteNames.requestTracking:
        final args = settings.arguments as RequestTrackingArgs;
        page = RequestTrackingScreen(requestId: args.requestId);
        break;
      case RouteNames.receipt:
        final args = settings.arguments as ReceiptArgs;
        page = ReceiptScreen(requestId: args.requestId);
        break;
      case RouteNames.collectorHome:
        page = const CollectorHomeScreen();
        break;
      case RouteNames.incomingRequests:
        page = const IncomingRequestsScreen();
        break;
      case RouteNames.activeRoute:
        page = const ActiveRouteScreen();
        break;
      case RouteNames.completePickup:
        final args = settings.arguments as CompletePickupArgs;
        page = CompletePickupScreen(requestId: args.requestId);
        break;
      case RouteNames.collectorHistory:
        page = const CollectorHistoryScreen();
        break;
      default:
        page = const _UnknownRouteScreen();
    }

    return CupertinoPageRoute(builder: (_) => page, settings: settings);
  }

  static Future<T?> push<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed<T>(
      routeName,
      arguments: arguments,
    );
  }

  static void pop<T>([T? result]) {
    navigatorKey.currentState!.pop<T>(result);
  }

  static Future<T?> pushReplacement<T>(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
      routeName,
      arguments: arguments,
    );
  }

  static Future<T?> pushAndRemoveUntil<T>(
      String routeName, {
        Object? arguments,
      }) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
      routeName,
          (route) => false,
      arguments: arguments,
    );
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Page not found')));
  }
}