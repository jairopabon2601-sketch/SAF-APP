import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/portal_service.dart';
import 'portal_home_screen.dart';
import 'portal_widgets.dart';

enum _Modo { login, registro, vincular }

/// Ingreso / registro del portal de clientes. Solo pueden crear cuenta los
/// deudores con un crédito activo (documento + últimos 4 del celular).
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  final _portal = PortalService();
  _Modo _modo = _Modo.login;
  bool _loading = false;
  bool _ok = false;
  bool _showPass = false;
  String _error = '';
  String? _googleToken;
  String _googleEmail = '';
  String _googleNombre = '';

  final _email = TextEditingController();
  final _clave = TextEditingController();
  final _clave2 = TextEditingController();
  final _doc = TextEditingController();
  final _tel = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _clave, _clave2, _doc, _tel]) {
      c.dispose();
    }
    super.dispose();
  }

  void _cambiarModo(_Modo m) {
    FocusScope.of(context).unfocus();
    setState(() {
      _modo = m;
      _error = '';
    });
  }

  Future<void> _manejar(Map<String, dynamic> r) async {
    if (r['success'] == true && _portal.isLoggedIn) {
      HapticFeedback.mediumImpact();
      setState(() => _ok = true);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 550),
          pageBuilder: (_, __, ___) => const PortalHomeScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween(begin: 1.04, end: 1.0).animate(
                  CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
        (_) => false,
      );
      return;
    }
    setState(() =>
        _error = (r['mensaje'] ?? 'No fue posible continuar.').toString());
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() fn,
      {Future<void> Function(Map<String, dynamic>)? onResult}) async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await fn();
      if (!mounted) return;
      if (onResult != null) {
        await onResult(r);
      } else {
        await _manejar(r);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Error de conexión. Revisa tu internet e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submit() {
    switch (_modo) {
      case _Modo.login:
        if (_email.text.trim().isEmpty || _clave.text.isEmpty) {
          setState(() => _error = 'Escribe tu correo y tu contraseña.');
          return;
        }
        _run(() => _portal.login(_email.text, _clave.text));
        break;
      case _Modo.registro:
        if (_clave.text != _clave2.text) {
          setState(() => _error = 'Las contraseñas no coinciden.');
          return;
        }
        _run(() => _portal.registro(
              documento: _doc.text,
              telefono: _tel.text,
              email: _email.text,
              clave: _clave.text,
            ));
        break;
      case _Modo.vincular:
        final t = _googleToken;
        if (t == null) return;
        _run(() => _portal.google(t, documento: _doc.text, telefono: _tel.text));
        break;
    }
  }

  Future<void> _google() async {
    String? idToken;
    try {
      idToken = await _portal.obtenerIdTokenGoogle();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo abrir Google. Intenta de nuevo.');
      }
      return;
    }
    if (idToken == null || !mounted) return;
    final token = idToken;
    await _run(() => _portal.google(token), onResult: (r) async {
      if (r['requiere_documento'] == true) {
        setState(() {
          _googleToken = token;
          _googleEmail = (r['email'] ?? '').toString();
          _googleNombre = (r['nombre'] ?? '').toString();
          _modo = _Modo.vincular;
          _error = '';
        });
        return;
      }
      await _manejar(r);
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  InputDecoration _deco(String label, IconData icon,
          {Widget? suffix, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35), letterSpacing: 2),
        floatingLabelBehavior:
            hint != null ? FloatingLabelBehavior.always : null,
        labelStyle: const TextStyle(color: portalTextSoft, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: portalCyan, fontSize: 13),
        prefixIcon: Icon(icon, color: portalTextSoft, size: 19),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        counterText: '',
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: portalCyan, width: 1.4),
        ),
      );

  Widget _campo(
    TextEditingController c,
    String label,
    IconData icon, {
    bool pass = false,
    TextInputType? type,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    TextInputAction action = TextInputAction.next,
  }) =>
      TextField(
        controller: c,
        obscureText: pass && !_showPass,
        keyboardType: type,
        maxLength: maxLength,
        inputFormatters: formatters,
        textInputAction: action,
        onSubmitted: action == TextInputAction.done ? (_) => _submit() : null,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: portalCyan,
        decoration: _deco(
          label,
          icon,
          hint: pass ? '••••••••' : null,
          suffix: pass
              ? IconButton(
                  onPressed: () => setState(() => _showPass = !_showPass),
                  icon: Icon(
                      _showPass
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: portalTextSoft,
                      size: 19),
                )
              : null,
        ),
      );

  Widget _tabs() {
    final esLogin = _modo == _Modo.login;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          alignment: esLogin ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                    colors: [Color(0xFF5B54F5), Color(0xFF3B82F6), Color(0xFF00C6FF)]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5B54F5).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final m in [_Modo.login, _Modo.registro])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _cambiarModo(m),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 220),
                    style: TextStyle(
                      color: _modo == m ? Colors.white : portalTextSoft,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    child: Text(m == _Modo.login ? 'Ingresar' : 'Crear cuenta'),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _formulario() {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    final ident = <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF5B54F5).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: portalCyan.withValues(alpha: 0.25)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: portalCyan, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verificamos tu documento y los últimos 4 dígitos del celular que registraste con tu asesor. Si no tienes un crédito activo no podrás crear la cuenta.',
              style: TextStyle(
                  color: Color(0xFFB8CBFF), fontSize: 12, height: 1.4),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          flex: 3,
          child: _campo(_doc, 'Documento', Icons.badge_outlined,
              type: TextInputType.number, formatters: digits),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _campo(_tel, 'Últ. 4 cel.', Icons.smartphone_rounded,
              type: TextInputType.number,
              maxLength: 4,
              formatters: digits,
              action: _modo == _Modo.vincular
                  ? TextInputAction.done
                  : TextInputAction.next),
        ),
      ]),
      const SizedBox(height: 14),
    ];

    final children = <Widget>[
      if (_modo != _Modo.login) ...ident,
      if (_modo != _Modo.vincular) ...[
        _campo(_email, 'Correo', Icons.mail_outline_rounded,
            type: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _campo(_clave, 'Contraseña', Icons.lock_outline_rounded,
            pass: true,
            action: _modo == _Modo.login
                ? TextInputAction.done
                : TextInputAction.next),
      ],
      if (_modo == _Modo.registro) ...[
        const SizedBox(height: 14),
        _campo(_clave2, 'Confirmar contraseña', Icons.lock_outline_rounded,
            pass: true, action: TextInputAction.done),
      ],
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: Column(
        key: ValueKey(_modo),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _boton() {
    final label = switch (_modo) {
      _Modo.login => 'Ingresar',
      _Modo.registro => 'Crear mi cuenta',
      _Modo.vincular => 'Vincular y entrar',
    };
    return GestureDetector(
      onTap: _loading || _ok ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: _ok
                ? const [Color(0xFF059669), Color(0xFF10B981)]
                : const [Color(0xFF5B54F5), Color(0xFF3B82F6), Color(0xFF00C6FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: (_ok ? const Color(0xFF10B981) : const Color(0xFF5B54F5))
                  .withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: PortalShine(
          borderRadius: 16,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) =>
                  ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
              child: _ok
                  ? const Row(
                      key: ValueKey('ok'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('¡Listo!',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    )
                  : _loading
                      ? const SizedBox(
                          key: ValueKey('load'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(label,
                          key: ValueKey(label),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = switch (_modo) {
      _Modo.login => 'Consulta tu crédito',
      _Modo.registro => 'Crea tu cuenta',
      _Modo.vincular => 'Confirma tu identidad',
    };
    final primerNombre =
        _googleNombre.isNotEmpty ? ', ${_googleNombre.split(' ').first}' : '';
    final subtitulo = switch (_modo) {
      _Modo.login =>
        'Revisa el estado de tu crédito, tus cuotas y tu próximo pago.',
      _Modo.registro => 'Solo para clientes con un crédito activo en SAF.',
      _Modo.vincular =>
        'Hola$primerNombre. Vincula $_googleEmail a tu crédito.',
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF020714),
        body: PortalBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
                          if (_modo == _Modo.vincular) {
                            _cambiarModo(_Modo.login);
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context)
                                .pushReplacementNamed('/login');
                          }
                        },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                    PortalEntrance(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF080C22).withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: portalCyan.withValues(alpha: 0.28)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5B54F5)
                                  .withValues(alpha: 0.22),
                              blurRadius: 50,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 900),
                                curve: Curves.elasticOut,
                                builder: (_, v, c) =>
                                    Transform.scale(scale: 0.5 + 0.5 * v, child: c),
                                child: const PortalLogo(size: 84),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text('PORTAL DE CLIENTES',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFF9DA8FF),
                                    fontSize: 10.5,
                                    letterSpacing: 2.6,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: Column(
                                key: ValueKey('t_$_modo'),
                                children: [
                                  Text(titulo,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 6),
                                  Text(subtitulo,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: portalTextSoft,
                                          fontSize: 13.5,
                                          height: 1.35)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (_modo != _Modo.vincular) ...[
                              _tabs(),
                              const SizedBox(height: 20),
                            ],
                            _formulario(),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              child: _error.isEmpty
                                  ? const SizedBox(width: double.infinity)
                                  : Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 14),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444)
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFEF4444)
                                                .withValues(alpha: 0.32)),
                                      ),
                                      child: Text(_error,
                                          style: const TextStyle(
                                              color: Color(0xFFFECACA),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500)),
                                    ),
                            ),
                            const SizedBox(height: 18),
                            _boton(),
                            if (_modo != _Modo.vincular &&
                                PortalService.googleHabilitado) ...[
                              const SizedBox(height: 18),
                              Row(children: [
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.10))),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text('o',
                                      style: TextStyle(
                                          color: portalTextSoft, fontSize: 12)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Colors.white
                                            .withValues(alpha: 0.10))),
                              ]),
                              const SizedBox(height: 18),
                              _GoogleButton(
                                  onTap: _loading || _ok ? null : _google),
                            ],
                            const SizedBox(height: 18),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user_rounded,
                                    color: Color(0xFF34D399), size: 15),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                      'Acceso de solo consulta · tus datos están protegidos',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: portalTextSoft, fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('G',
                  style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              SizedBox(width: 10),
              Text('Continuar con Google',
                  style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
