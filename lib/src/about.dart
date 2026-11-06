import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

import 'palette.dart';

/// The canonical hosted policy served by the legal tenant. Opened in the
/// system browser only: the app itself stays offline, keeping every "no
/// network / no developer-operated server" store disclosure literally true.
const String _kPrivacyUrl =
    'https://auth.zhongbei.tech/legal/privacy?app=jellycube3d&locale=en-US';

/// Local, offline About / legal entry. The full policy link opens externally.
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
          border: Border.all(color: jellyGlassEdge(0.9)),
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
                L.of(context).aboutTagline,
                style: JellyPalette.displaySmall.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 18),
              _Section(
                title: L.of(context).sectionPrivacy,
                body:
                    '${L.of(context).privacyBody} '
                    'Optional Extra Cube Types purchases are processed by Apple, Google or Huawei; '
                    'the app receives only the unlock status and keeps it on your device.',
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(_kPrivacyUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 13),
                  label: Text(L.of(context).viewFullPolicy),
                  style: TextButton.styleFrom(
                    foregroundColor: JellyPalette.berry,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: L.of(context).sectionPurchases,
                body:
                    '2×2, 3×3 and 4×4 are free. Extra Cube Types is a one-time unlock for 5×5, 6×6 '
                    'and future cube types. If the unlock is missing, use Restore Purchases in the '
                    'purchase sheet or contact support with the store and approximate purchase time.',
              ),
              const SizedBox(height: 14),
              _Section(
                title: L.of(context).sectionSupport,
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
                          SnackBar(content: Text(L.of(context).supportEmailCopied)),
                        );
                      },
                      child: Text(L.of(context).copySupportEmail),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: JellyPalette.plum,
                      ),
                      child: Text(L.of(context).close),
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
                  child: Text(L.of(context).openSourceLicenses),
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
          style: jellyBody().copyWith(fontSize: 12, height: 1.45),
        ),
      ],
    );
  }
}
