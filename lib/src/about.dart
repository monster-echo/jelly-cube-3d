import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Local, offline About / legal entry. No network, no URL launcher package.
Future<void> showJellyAbout(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: JellyPalette.plum.withValues(alpha: 0.28),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7FD),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: JellyPalette.plum.withValues(alpha: 0.22),
              blurRadius: 44,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'JELLY CUBE 3D',
                    style: JellyPalette.mono.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'v1.0.0',
                    style: JellyPalette.monoSmall.copyWith(fontSize: 7.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'A small, glossy puzzle.',
                style: JellyPalette.displaySmall.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 18),
              _Section(
                title: 'PRIVACY',
                body:
                    'No account. No ads. No analytics. No personal data is collected by the app. '
                    'Optional Extra Cube Types purchases are processed by Apple, Google or Huawei; '
                    'the app receives only the unlock status and keeps it on your device.',
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'PURCHASES',
                body:
                    '2×2, 3×3 and 4×4 are free. Extra Cube Types is a one-time unlock for 5×5, 6×6 '
                    'and future cube types. If the unlock is missing, use Restore Purchases in the '
                    'purchase sheet or contact support with the store and approximate purchase time.',
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'SUPPORT',
                body: 'support@zhongbei.tech\nTypical response: 2–3 business days.',
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(text: 'support@zhongbei.tech'),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support email copied')),
                        );
                      },
                      child: const Text('Copy support email'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: JellyPalette.plum,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Jelly Cube 3D',
                    applicationVersion: '1.0.0+1',
                  ),
                  child: const Text('Open source licenses'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: JellyPalette.monoSmall.copyWith(
            fontSize: 7.5,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: JellyPalette.body.copyWith(fontSize: 12, height: 1.45),
        ),
      ],
    );
  }
}
