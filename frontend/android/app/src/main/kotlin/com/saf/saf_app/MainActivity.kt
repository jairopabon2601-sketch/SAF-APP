package com.saf.saf_app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (Face ID/huella) requiere FragmentActivity, no la FlutterActivity
// simple — sin este cambio el plugin lanza una excepción al autenticar.
class MainActivity: FlutterFragmentActivity()
