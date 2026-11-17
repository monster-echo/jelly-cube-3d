import 'dart:async';

import 'package:flutter/material.dart';

import 'jelly_cube_3d.dart';
import 'src/ads/jelly_banner_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Bottom banner ads: UMP consent → iOS ATT → SDK init. No-op on web/macOS.
  unawaited(JellyAds.instance.ensureInitialized());
  runApp(const JellyCubeApp());
}
