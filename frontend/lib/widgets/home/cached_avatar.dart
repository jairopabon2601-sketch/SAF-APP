import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../repositories/home_repository.dart';

/// Avatar con caché en disco: muestra de inmediato la última foto guardada
/// (si existe) mientras la refresca en segundo plano contra la red. Sin
/// esto, `Image.network` volvía a descargar la foto de perfil desde cero
/// cada vez que se abría la app, aunque no hubiera cambiado — la carga más
/// lenta que notaba el cliente frente al resto de la pantalla.
class CachedAvatarImage extends StatefulWidget {
  final String url;
  // Clave estable (p.ej. codigo_usuario) — no debe cambiar con el `?v=` de
  // cache-bust del URL, para que main() pueda precargarla antes de runApp().
  final String cacheKey;
  final Widget fallback;
  final BoxFit fit;

  const CachedAvatarImage({
    super.key,
    required this.url,
    required this.cacheKey,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<CachedAvatarImage> createState() => _CachedAvatarImageState();
}

class _CachedAvatarImageState extends State<CachedAvatarImage> {
  final _repository = HomeRepository();
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    // Chequeo síncrono contra el mapa en memoria (poblado en main() antes de
    // runApp()) — si ya está ahí, el primer build() sale directo con la foto
    // real, sin ningún frame mostrando el fallback de por medio.
    if (widget.cacheKey.isNotEmpty) {
      _bytes = _repository.getMemImageCache(widget.cacheKey);
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant CachedAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.cacheKey != widget.cacheKey) {
      _bytes = _repository.getMemImageCache(widget.cacheKey);
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty || widget.cacheKey.isEmpty) return;
    final key = widget.cacheKey;
    if (_bytes == null) {
      final cached = await _repository.loadImageCache(key);
      if (cached != null && mounted) {
        setState(() => _bytes = cached);
      }
    }
    try {
      final r = await http
          .get(Uri.parse(widget.url))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        unawaited(_repository.saveImageCache(key, r.bodyBytes));
        if (mounted) setState(() => _bytes = r.bodyBytes);
      }
    } catch (_) {
      // Si falla y ya se mostró la versión en caché, se queda con esa. Si
      // no había caché, build() sigue mostrando el fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (widget.url.isEmpty || bytes == null) return widget.fallback;
    return Image.memory(
      bytes,
      fit: widget.fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
