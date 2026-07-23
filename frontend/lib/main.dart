import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home/home_constants.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/push_notifications_service.dart';
import 'widgets/home/app_dialogs.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// FCM invoca este handler en un isolate separado cuando llega un mensaje con
// la app en background o cerrada — debe ser una función top-level (no un
// método de clase) y reinicializar Firebase, porque corre fuera del árbol de
// widgets normal de la app.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
  await ApiService().init();
  await loadThemePreference();
  // Precarga la foto de perfil en memoria antes de runApp(): leer el disco
  // (SharedPreferences) sigue siendo async, así que sin esto el primer
  // build() del avatar no tenía los bytes listos y se veía un parpadeo del
  // fallback (la inicial) — muy notorio justo después de un hot restart.
  final codigoUsuario = ApiService().user?['codigo_usuario']?.toString();
  if (codigoUsuario != null && codigoUsuario.isNotEmpty) {
    await ApiService().preloadImageCache(codigoUsuario);
  }

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;

  // Clear any stale background timestamp on cold start.
  // Session timeout is only checked when resuming from background (see didChangeAppLifecycleState).
  await ApiService().clearBackgroundTimestamp();

  String initialRoute;
  if (!onboardingDone) {
    initialRoute = '/onboarding';
  } else if (ApiService().token != null) {
    initialRoute = '/home';
    // Sesión ya activa (no pasó por el login screen en este arranque):
    // registra/refresca el token push igual.
    unawaited(PushNotificationsService().init());
  } else {
    initialRoute = '/login';
  }

  runApp(SafApp(initialRoute: initialRoute));
}

class SafApp extends StatefulWidget {
  final String initialRoute;
  const SafApp({super.key, required this.initialRoute});

  @override
  State<SafApp> createState() => _SafAppState();
}

class _SafAppState extends State<SafApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      await ApiService().saveBackgroundTimestamp();
    } else if (state == AppLifecycleState.resumed) {
      final expired = await ApiService().checkAndHandleSessionTimeout();
      if (expired) {
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (_) => false);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _showInactivityDialog());
      } else {
        unawaited(PushNotificationsService().syncTokenIfNeeded());
      }
    }
  }

  void _showInactivityDialog() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AppAnimatedDialog(
        child: Dialog(
          backgroundColor: dialogBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF8B2FC9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('💤', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sesión cerrada por inactividad',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Estuviste más de 5 minutos inactivo. Por favor inicia sesión nuevamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: textSoft),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8B2FC9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF6C63FF).withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Entendido',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return ValueListenableBuilder<bool>(
      valueListenable: appThemeDark,
      builder: (_, dark, __) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'SAF',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(false),
        darkTheme: _buildTheme(true),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es'), Locale('en')],
        locale: const Locale('es'),
        initialRoute: widget.initialRoute,
        routes: {
          '/onboarding': (_) => const OnboardingScreen(),
          '/login': (_) => const LoginScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6C63FF),
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      surface: dark ? const Color(0xFF10162F) : Colors.white,
      onSurface: dark ? const Color(0xFFE9EDFF) : const Color(0xFF0D1B4B),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'SF Pro Display',
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF070A1C) : const Color(0xFFF0F2FA),
      cardColor: dark ? const Color(0xFF10162F) : Colors.white,
      canvasColor: dark ? const Color(0xFF070A1C) : const Color(0xFFF0F2FA),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF121838) : Colors.white,
      ),
    );
  }
}
