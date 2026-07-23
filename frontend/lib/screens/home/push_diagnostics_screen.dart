import 'package:flutter/material.dart';

import '../../services/push_notifications_service.dart';
import 'home_constants.dart';

/// Pantalla de diagnóstico de push notifications: corre el mismo flujo de
/// registro de token paso a paso y muestra el resultado en texto plano.
/// Pensada para diagnosticar en dispositivos reales (TestFlight) sin acceso
/// a una Mac/Xcode, donde no hay forma de ver los logs de consola.
class PushDiagnosticsScreen extends StatefulWidget {
  const PushDiagnosticsScreen({super.key});

  @override
  State<PushDiagnosticsScreen> createState() => _PushDiagnosticsScreenState();
}

class _PushDiagnosticsScreenState extends State<PushDiagnosticsScreen> {
  bool _running = false;
  String? _result;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _result = null;
    });
    final r = await PushNotificationsService().runDiagnostics();
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = r;
    });
  }

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dialogBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Diagnóstico de notificaciones'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Esto revisa, paso a paso, por qué este dispositivo puede o no '
                'recibir notificaciones push, y muestra el resultado aquí mismo.',
                style: TextStyle(color: textSoft, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_running)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: homeAccent),
                ))
              else if (_result != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: SelectableText(
                    _result!,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                        color: Colors.white,
                        height: 1.6),
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _running ? null : _run,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Volver a probar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: homeAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
