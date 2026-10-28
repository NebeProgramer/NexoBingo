import 'package:flutter/material.dart';

import '../theme.dart';

/// Etiqueta pequeña de candado para las funciones premium bloqueadas.
class PremiumTag extends StatelessWidget {
  const PremiumTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.goldDark),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock, size: 11, color: AppColors.gold),
        SizedBox(width: 3),
        Text('Premium', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Aviso al tocar una función premium que todavía no está disponible.
Future<void> showPremiumDialog(BuildContext context, String feature) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.workspace_premium, color: AppColors.gold),
        SizedBox(width: 8),
        Text('Función premium', style: TextStyle(color: AppColors.gold)),
      ]),
      content: Text('$feature estará disponible en NexoBingo Premium. ¡Muy pronto!'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
    ),
  );
}
