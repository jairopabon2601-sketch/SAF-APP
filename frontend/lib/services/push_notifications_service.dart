import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  static const _channel = AndroidNotificationChannel(
    'cuotas_atrasadas',
    'Cuotas atrasadas',
    description: 'Avisos de cuotas de crédito vencidas y créditos pendientes',
    importance: Importance.high,
  );

  bool _listenersReady = false;
  bool _pendingRetry = false;

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
  Future<void> init() async {
    await requestPermissionAndListen();
    await _registerToken();
  }

  /// Se llama cuando la app vuelve a foreground (ver didChangeAppLifecycleState
  /// en main.dart). Si un intento anterior no logró obtener el token FCM
  /// (red lenta durante el login, registro APNs aún no completado por iOS),
  /// esto le da una segunda oportunidad sin esperar a que el usuario cierre
  /// sesión.
  Future<void> retryIfPending() async {
    if (!_pendingRetry) return;
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
        // cuando la app vuelva a foreground (ver retryIfPending).
        _pendingRetry = token == null;
        return;
      }
      _pendingRetry = false;
      final r = await ApiService().post('/ajax/registrar_token_push.php', {
        'codigo_usuario': codigoUsuario,
        'fcm_token': token,
        'plataforma': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint(
          '[Push] registrar_token_push respuesta: ${r.statusCode} ${r.body}');
    } catch (e) {
      debugPrint('[Push] Error registrando token: $e');
      _pendingRetry = true;
    }
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
