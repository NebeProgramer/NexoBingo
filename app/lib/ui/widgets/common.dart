import 'package:flutter/material.dart';

import '../theme.dart';

/// Botón redondeado de color sólido (port de `RoundButton.java`).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.height = 48,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: AppColors.textLight,
          disabledBackgroundColor: color.withValues(alpha: 0.28),
          disabledForegroundColor: AppColors.textLight.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// Contenedor redondeado con título dorado (port de `CardPanel.java`).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16)});

  final String? title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: AppColors.bgPanel, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!.toUpperCase(),
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
            const SizedBox(height: 10),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Banda que avisa que se perdió la conexión y se está reintentando.
class ReconnectingBanner extends StatelessWidget {
  const ReconnectingBanner({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? Container(
              width: double.infinity,
              color: AppColors.red.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: const Text('Conexión perdida, reconectando...',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textLight, fontSize: 13)),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// Balota redonda grande para anunciar la última que salió.
class BallotBadge extends StatelessWidget {
  const BallotBadge({super.key, required this.letter, required this.number, this.size = 72});

  final String letter;
  final int number;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.letter(letter);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.bgCard,
        border: Border.all(color: color, width: size * 0.07),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(letter, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.24, height: 1)),
            Text('$number',
                style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold, fontSize: size * 0.36, height: 1.1)),
          ]),
        ),
      ),
    );
  }
}
