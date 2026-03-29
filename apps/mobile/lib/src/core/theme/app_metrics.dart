import 'package:flutter/material.dart';

abstract final class AppMetrics {
  static const pagePadding = EdgeInsets.fromLTRB(24, 18, 24, 120);
  static const pagePaddingWide = EdgeInsets.fromLTRB(24, 28, 24, 32);
  static const modalPadding = EdgeInsets.all(24);
  static const panelPadding = EdgeInsets.all(20);
  static const compactPanelPadding = EdgeInsets.all(16);

  static const double panelRadius = 24;
  static const double tileRadius = 20;
  static const double chipRadius = 16;
  static const double pillRadius = 999;

  static const double sectionGap = 16;
  static const double contentGap = 18;
  static const double denseGap = 12;

  static const double maxReadableWidth = 760;
  static const double minTouchTarget = 48;

  static const Duration quickDuration = Duration(milliseconds: 180);
  static const Duration standardDuration = Duration(milliseconds: 260);
  static const Duration emphasizedDuration = Duration(milliseconds: 420);
}
