import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

/// Maneja el ciclo completo de notificaciones push (FCM): permisos, captura
/// y registro del token en el backend, y despliegue de la notificación
/// mientras la app está en foreground (Android/iOS no la muestran solos en
/// ese caso — solo lo hacen automáticamente en background/cerrada).
class PushNotificationsService {
  static final PushNotificationsService _instance =
      PushNotificationsService._();
  factory PushNotificationsService() => _instance;
  PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const _apnsChannel = MethodChannel('saf/apns_diagnostics');

  static const _channel = AndroidNotificationChannel(
    'cuotas_atrasadas',
    'Cuotas atrasadas',
    description: 'Avisos de cuotas de crédito vencidas y créditos pendientes',
    importance: Importance.high,
  );

  bool _listenersReady = false;
  // Token ya confirmado registrado en el backend en esta sesión de la app.
  // Distinto de "hubo un intento fallido": cubre también el caso en que el
  // PRIMER intento nunca llegó a correr (condición de carrera en el arranque
  // de un dispositivo nuevo) — sin esta bandera, ese caso nunca se reintentaba.
  bool _tokenConfirmed = false;

  /// Pide el permiso del sistema y arma los listeners de FCM. Se llama al
  /// entrar por primera vez a la app (fin del onboarding), ANTES del login,
  /// para que el diálogo "SAF quiere enviarte notificaciones" salga apenas
  /// el usuario entra, no después de iniciar sesión. Es seguro llamarlo más
  /// de una vez: si el usuario ya respondió el permiso, el sistema no
  /// vuelve a preguntar, y los listeners solo se registran una vez.
  Future<void> requestPermissionAndListen() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // En iOS, sin esto, el sistema NO presenta el banner/sonido nativo
    // mientras la app está en foreground (a diferencia de background/killed,
    // que sí funcionan por defecto) — se necesita habilitarlo explícitamente.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    if (_listenersReady) return;
    _listenersReady = true;

    _messaging.onTokenRefresh.listen((_) => _registerToken());

    // App abierta en primer plano: FCM no muestra nada solo, así que se
    // despliega manualmente con flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Usuario tocó la notificación con la app en background (no cerrada).
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] Abierta desde background: ${message.data}');
    });
  }

  /// Registra/actualiza el token en el backend — requiere sesión iniciada
  /// (codigo_usuario), así que se llama después del login.
  ///
  /// En dispositivos nuevos, iOS puede tardar en completar el registro
  /// remoto de APNs (necesario antes de que getToken() de FCM devuelva
  /// algo) más de lo que tarda este primer intento — sin depender solo del
  /// reintento en el próximo "resumed" (que requiere que el usuario minimice
  /// y reabra la app), se reintenta unas pocas veces aquí mismo, en el
  /// momento del login, con espera corta entre intentos.
  Future<void> init() async {
    await requestPermissionAndListen();
    for (var intento = 0; intento < 5 && !_tokenConfirmed; intento++) {
      if (intento > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
      await _registerToken();
    }
  }

  /// Se llama cuando la app vuelve a foreground (ver didChangeAppLifecycleState
  /// en main.dart). Reintenta SIEMPRE mientras no haya token confirmado —no
  /// solo si un intento anterior falló explícitamente— porque en un
  /// dispositivo nuevo el PRIMER intento puede no haber corrido nunca (la
  /// app se puso en background/se cerró antes de que iOS completara el
  /// registro remoto de APNs), y sin este reintento incondicional el
  /// registro se perdía para siempre en ese dispositivo.
  Future<void> syncTokenIfNeeded() async {
    if (_tokenConfirmed) return;
    await _registerToken();
  }

  Future<void> _registerToken() async {
    try {
      // getToken() ya espera internamente a que iOS tenga el APNs token
      // nativo listo (el plugin lo maneja) — no hace falta ni conviene
      // hacer polling manual de getAPNSToken() aquí: en dispositivos reales
      // eso se ha visto expirar antes de que iOS complete el registro.
      final token = await _messaging.getToken();
      final codigoUsuario = ApiService().user?['codigo_usuario']?.toString();
      debugPrint('[Push] fcmToken=$token codigoUsuario=$codigoUsuario');
      if (token == null || codigoUsuario == null || codigoUsuario.isEmpty) {
        // token null: iOS aún no completó el registro remoto. Se reintenta
        // en cada resumed (ver syncTokenIfNeeded) hasta que se confirme.
        return;
      }
      final r = await ApiService().post('/ajax/registrar_token_push.php', {
        'codigo_usuario': codigoUsuario,
        'fcm_token': token,
        'plataforma': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint(
          '[Push] registrar_token_push respuesta: ${r.statusCode} ${r.body}');
      if (r.statusCode == 200) _tokenConfirmed = true;
    } catch (e) {
      debugPrint('[Push] Error registrando token: $e');
    }
  }

  /// Ejecuta el mismo flujo de registro paso a paso, pero devolviendo un
  /// reporte en texto plano de cada etapa — pensado para diagnosticar en
  /// dispositivos reales (TestFlight) sin acceso a Xcode/Console. Temporal:
  /// se usa para encontrar la causa raíz en un caso puntual y luego se quita.
  Future<String> runDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Plataforma: ${Platform.isIOS ? "iOS" : "Android"}');
    buffer.writeln('Token ya confirmado antes: $_tokenConfirmed');

    try {
      final settings = await _messaging.getNotificationSettings();
      buffer.writeln('Permiso del sistema: ${settings.authorizationStatus}');
    } catch (e) {
      buffer.writeln('Error leyendo permiso: $e');
    }

    if (Platform.isIOS) {
      try {
        final apnsToken = await _messaging.getAPNSToken();
        buffer.writeln(apnsToken == null
            ? 'APNs token: null (iOS aún no lo entrega)'
            : 'APNs token: OK (${apnsToken.substring(0, 12)}...)');
      } catch (e) {
        buffer.writeln('Error obteniendo APNs token: $e');
      }

      // Motivo exacto que dio iOS si rechazó el registro remoto de forma
      // explícita (capturado en AppDelegate.swift) — sin esto, un fallo
      // real de iOS se ve idéntico a un simple timeout.
      try {
        final nativeError = await _apnsChannel
            .invokeMethod<String>('getRegistrationError');
        buffer.writeln(nativeError == null
            ? 'Error nativo de registro APNs: ninguno reportado'
            : 'Error nativo de registro APNs: $nativeError');
      } catch (e) {
        buffer.writeln('No se pudo leer el error nativo: $e');
      }
    }

    String? fcmToken;
    try {
      fcmToken = await _messaging.getToken();
      buffer.writeln(fcmToken == null
          ? 'FCM token: null'
          : 'FCM token: OK (${fcmToken.substring(0, 20)}...)');
    } catch (e) {
      buffer.writeln('Error obteniendo FCM token: $e');
    }

    final codigoUsuario = ApiService().user?['codigo_usuario']?.toString();
    buffer.writeln('codigo_usuario: ${codigoUsuario ?? "null"}');

    if (fcmToken != null && codigoUsuario != null && codigoUsuario.isNotEmpty) {
      try {
        final r = await ApiService().post('/ajax/registrar_token_push.php', {
          'codigo_usuario': codigoUsuario,
          'fcm_token': fcmToken,
          'plataforma': Platform.isIOS ? 'ios' : 'android',
        });
        buffer.writeln('Backend: HTTP ${r.statusCode} — ${r.body}');
        if (r.statusCode == 200) _tokenConfirmed = true;
      } catch (e) {
        buffer.writeln('Error llamando al backend: $e');
      }
    } else {
      buffer.writeln('Backend: no llamado (falta token o usuario)');
    }

    return buffer.toString();
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}
