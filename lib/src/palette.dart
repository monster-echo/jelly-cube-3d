import 'package:flutter/material.dart';

class JellyPalette {
  JellyPalette._();

  // Studio world: lilac plaster, blush light, warm ceramic.
  static const Color studioTop = Color(0xFFF2ECF7);
  static const Color studioMid = Color(0xFFE6DFF0);
  static const Color studioBottom = Color(0xFFD6CCE8);
  static const Color blush = Color(0xFFF6DDE8);
  static const Color cream = Color(0xFFFFF8EA);
  static const Color ceramic = Color(0xFFFDFBF8);
  static const Color ceramicShade = Color(0xFFE8DFEC);

  static const Color ink = Color(0xFF2A2137);
  static const Color inkSoft = Color(0xFF6F647E);
  static const Color inkFaint = Color(0xFF9A90A6);
  static const Color plum = Color(0xFF4C2D4B);
  static const Color plumDeep = Color(0xFF352035);
  static const Color berry = Color(0xFF8A3E60);
  static const Color lemonInk = Color(0xFFF2C84B);

  static const Color glass = Color(0xB3FFFFFF);
  static const Color glassStrong = Color(0xE6FFFFFF);
  static const Color glassBorder = Color(0xCCFFFFFF);
  static const Color hairline = Color(0x2E2A2137);

  // The six flavors. Values stay deliberately far apart.
  static const List<Color> flavor = <Color>[
    Color(0xFFFFF9EC), // U coconut milk
    Color(0xFFFFD42E), // D lemon
    Color(0xFF77D83C), // F lime
    Color(0xFF3157D8), // B blueberry
    Color(0xFFD51F3D), // R cherry
    Color(0xFFFF7A12), // L tangerine
  ];

  static const List<Color> flavorDeep = <Color>[
    Color(0xFFF0E0C2),
    Color(0xFFDCA800),
    Color(0xFF3C9B1F),
    Color(0xFF1C328F),
    Color(0xFF970A24),
    Color(0xFFCE5200),
  ];

  static const List<Color> flavorLight = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFFEB78),
    Color(0xFFB8F27C),
    Color(0xFF7F9CF4),
    Color(0xFFF15B70),
    Color(0xFFFFB05B),
  ];

  static const List<Color> flavorInk = <Color>[
    Color(0xFF7D6D50),
    Color(0xFF8A6A00),
    Color(0xFF276B10),
    Color(0xFFDDE5FF),
    Color(0xFFFFF1F3),
    Color(0xFF5C2A00),
  ];

  static Color flavorName(int index) => flavor[index % 6];

  static const TextStyle display = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: <String>['Times New Roman', 'serif'],
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.1,
    color: ink,
    decoration: TextDecoration.none,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: <String>['Times New Roman', 'serif'],
    fontSize: 22,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
    color: ink,
    decoration: TextDecoration.none,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: <String>['Roboto Mono', 'Courier New', 'monospace'],
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: inkSoft,
    decoration: TextDecoration.none,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: <String>['Roboto Mono', 'Courier New', 'monospace'],
    fontSize: 8.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: inkFaint,
    decoration: TextDecoration.none,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: inkSoft,
    decoration: TextDecoration.none,
  );

  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: ink,
    decoration: TextDecoration.none,
  );
}
