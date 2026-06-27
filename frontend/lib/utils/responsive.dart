import 'package:flutter/material.dart';

extension Resp on BuildContext {
  double get sw => MediaQuery.of(this).size.width;
  double get sh => MediaQuery.of(this).size.height;

  // Scale a value designed for a 375px-wide screen
  double sp(double v) => v * (sw / 375).clamp(0.80, 1.35);
  // Fraction of screen width
  double w(double frac) => sw * frac;
  // Fraction of screen height
  double h(double frac) => sh * frac;
}
