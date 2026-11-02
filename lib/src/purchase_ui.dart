import 'package:flutter/material.dart';

import 'about.dart';
import 'controller.dart';
import 'palette.dart';
import 'purchases.dart';

/// One-time non-consumable unlock for 5×5 and 6×6.
Future<void> showJellyUnlockSheet(
  BuildContext context,
  JellyCubeController controller,
) {
  if (controller.storeStatus == JellyStoreStatus.idle) {
    controller.initializeStore();
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: JellyPalette.plum.withValues(alpha: 0.32),
    builder: (context) => _UnlockSheet(controller: controller),
  );
}

class _UnlockSheet extends StatelessWidget {
  const _UnlockSheet({required this.controller});
  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final unlocked = controller.extraTypesUnlocked;
        final busy =
            controller.storeStatus == JellyStoreStatus.purchasing ||
            controller.storeStatus == JellyStoreStatus.restoring;
        return SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFBF7FD),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: JellyPalette.plum.withValues(alpha: 0.22),
                  blurRadius: 48,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: JellyPalette.inkFaint.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? const Color(0xFF4D9A42).withValues(alpha: 0.12)
                              : JellyPalette.lemonInk.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          unlocked
                              ? Icons.check_rounded
                              : Icons.lock_open_rounded,
                          color: unlocked
                              ? const Color(0xFF3F8735)
                              : JellyPalette.plum,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              unlocked ? 'EXTRA TYPES' : 'JELLY PASS',
                              style: JellyPalette.monoSmall.copyWith(
                                fontSize: 7.5,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              unlocked
                                  ? 'More cube, more wobble.'
                                  : 'Unlock 5×5 & 6×6',
                              style: JellyPalette.displaySmall.copyWith(
                                fontSize: 26,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    unlocked
                        ? 'Extra Cube Types is unlocked on this device. It restores on any device signed into the same store account.'
                        : 'Two bigger cubes, one small unlock. 5×5 and 6×6 join the free 2×2, 3×3 and 4×4 sizes, with future extra types included.',
                    style: JellyPalette.body.copyWith(
                      fontSize: 12.5,
                      height: 1.45,
                      color: JellyPalette.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: JellyPalette.cream.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: JellyPalette.hairline),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 17,
                          color: JellyPalette.berry,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '5×5  ·  6×6  ·  FUTURE TYPES',
                            style: JellyPalette.monoSmall.copyWith(
                              fontSize: 7.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (!unlocked)
                          Text(
                            controller.extraTypesPrice,
                            style: JellyPalette.displaySmall.copyWith(
                              fontSize: 20,
                              color: JellyPalette.berry,
                            ),
                          )
                        else
                          Text(
                            'OWNED',
                            style: JellyPalette.monoSmall.copyWith(
                              fontSize: 7.5,
                              color: const Color(0xFF3F8735),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (controller.storeStatus == JellyStoreStatus.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (controller.storeMessage != null &&
                      controller.storeStatus != JellyStoreStatus.loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        controller.storeMessage!,
                        style: JellyPalette.body.copyWith(
                          fontSize: 11,
                          height: 1.35,
                          color:
                              controller.storeStatus == JellyStoreStatus.error
                              ? JellyPalette.berry
                              : JellyPalette.inkSoft,
                        ),
                      ),
                    ),
                  if (unlocked) ...<Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SizeChoice(
                            label: '5×5',
                            onTap: () {
                              controller.setSize(5);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SizeChoice(
                            label: '6×6',
                            onTap: () {
                              controller.setSize(6);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed:
                            busy ||
                                controller.storeStatus != JellyStoreStatus.ready
                            ? null
                            : controller.buyExtraTypes,
                        style: FilledButton.styleFrom(
                          backgroundColor: JellyPalette.plum,
                          disabledBackgroundColor: JellyPalette.ink.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        child:
                            controller.storeStatus ==
                                JellyStoreStatus.purchasing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                controller.storeStatus == JellyStoreStatus.ready
                                    ? 'Unlock for ${controller.extraTypesPrice}'
                                    : 'Store unavailable',
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: busy ? null : controller.restorePurchases,
                        child:
                            controller.storeStatus == JellyStoreStatus.restoring
                            ? const Text('Restoring…')
                            : const Text('Restore Purchases'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'One-time purchase. Payment is handled by the store. No subscription. '
                    'Restore any time with the same store account.',
                    style: JellyPalette.body.copyWith(
                      fontSize: 9.5,
                      height: 1.4,
                      color: JellyPalette.inkFaint,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => showJellyAbout(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(48, 36),
                      ),
                      child: const Text('Privacy & support'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SizeChoice extends StatelessWidget {
  const _SizeChoice({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        side: BorderSide(color: JellyPalette.plum.withValues(alpha: 0.28)),
        foregroundColor: JellyPalette.plum,
      ),
      child: Text(label),
    );
  }
}
