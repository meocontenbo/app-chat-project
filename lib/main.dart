import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';

import 'models/room_info.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/room_api.dart';
import 'state/auth_provider.dart';
import 'state/deep_link.dart';

void main() {
  usePathUrlStrategy();
  final path = Uri.base.path;
  if (path.startsWith('/join/')) pendingJoinCode.value = RoomInfo.parseCode(path);

  final api = ApiClient();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api)..init()),
        Provider(create: (_) => RoomApi(api)),
      ],
      child: const App(),
    ),
  );
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    Route<void> root(_) => MaterialPageRoute(builder: (_) => const AuthGate());
    return MaterialApp(
      title: 'App Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true),
      // Deep links (/join/...) are handled via pendingJoinCode, so every URL starts at the auth gate.
      onGenerateInitialRoutes: (_) => [root(null)],
      onGenerateRoute: root,
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<AuthProvider, AuthStatus>((a) => a.status);
    return switch (status) {
      AuthStatus.unknown =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.authenticated => const HomeScreen(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}
